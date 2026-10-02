import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// A published GitHub release newer than the installed app.
class Release {
  const Release({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.shaUrl,
  });

  final String version;

  /// The "What's new" part of the release notes.
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String? shaUrl;
}

/// Updates from GitHub releases, for installs outside the Play Store. Checks
/// at most once a day, downloads the APK, checks it against its .sha256 and
/// hands it to the system installer, which asks the user to confirm.
class Updater extends ChangeNotifier {
  Updater._();
  static final i = Updater._();

  static const repo = 'BraxtonElmer/nomnom';
  static const _channel = MethodChannel('nomnom/updates');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String current = '';

  /// A newer release, unless the user skipped that version.
  Release? available;

  /// 0–1 while downloading.
  double? progress;
  String? error;

  Future<String> installed() async {
    if (current.isEmpty) current = (await PackageInfo.fromPlatform()).version;
    return current;
  }

  /// The once-a-day check run when the app opens.
  Future<void> checkDaily() async {
    if (!supported) return;
    final last = int.tryParse(Store.i.setting('updateCheckedAt') ?? '');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < const Duration(hours: 20).inMilliseconds) {
      // Still offer what the last check found.
      final cached = Store.i.setting('updateFound');
      if (cached != null) _offer(_fromJson(cached), await installed());
      return;
    }
    await check();
  }

  /// Asks GitHub for the latest published release. Returns it when newer
  /// than this install (whether or not it was skipped).
  Future<Release?> check() async {
    if (!supported) return null;
    final have = await installed();
    try {
      final r = await http
          .get(
            Uri.https('api.github.com', '/repos/$repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      await Store.i.putSetting('updateCheckedAt', '${DateTime.now().millisecondsSinceEpoch}');
      final release = r.statusCode == 200
          ? parseRelease(jsonDecode(r.body) as Map<String, dynamic>)
          : null;
      if (release == null || !isNewer(release.version, have)) {
        await Store.i.putSetting('updateFound', null);
        available = null;
        notifyListeners();
        return null;
      }
      await Store.i.putSetting('updateFound', jsonEncode(_toJson(release)));
      _offer(release, have);
      return release;
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  void _offer(Release? r, String have) {
    final skipped = Store.i.setting('updateSkipped');
    available = r != null && isNewer(r.version, have) && r.version != skipped ? r : null;
    notifyListeners();
  }

  Future<void> skip(Release r) async {
    await Store.i.putSetting('updateSkipped', r.version);
    available = null;
    notifyListeners();
  }

  /// Whether Android lets nomnom open the installer; asked once per app.
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  Future<void> allowInstalls() => _channel.invokeMethod('allowInstalls');

  /// Downloads, checks and opens the installer. Returns false on failure,
  /// with [error] saying why.
  Future<bool> install(Release r) async {
    error = null;
    progress = 0;
    notifyListeners();
    final client = http.Client();
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final file = File('${dir.path}/nomnom-${r.version}.apk');

      final res = await client.send(http.Request('GET', Uri.parse(r.apkUrl)));
      if (res.statusCode != 200) throw 'The download failed (${res.statusCode}).';
      final total = res.contentLength ?? r.apkSize;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) {
          progress = got / total;
          notifyListeners();
        }
      }
      await sink.close();

      if (r.apkSize > 0 && got != r.apkSize) throw 'The download was incomplete.';
      if (r.shaUrl != null) {
        final sum = (await client.get(Uri.parse(r.shaUrl!))).body;
        final want = sum.trim().split(RegExp(r'\s')).first.toLowerCase();
        final have = sha256.convert(await file.readAsBytes()).toString();
        if (want != have) throw 'The download didn’t match its checksum.';
      }
      progress = null;
      notifyListeners();
      await _channel.invokeMethod('install', {'path': file.path});
      return true;
    } catch (e) {
      progress = null;
      error = e is String ? e : 'Couldn’t download the update. Check your connection.';
      notifyListeners();
      return false;
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _toJson(Release r) => {
    'v': r.version,
    'n': r.notes,
    'a': r.apkUrl,
    's': r.apkSize,
    'h': r.shaUrl,
  };

  static Release? _fromJson(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Release(
        version: j['v'] as String,
        notes: j['n'] as String,
        apkUrl: j['a'] as String,
        apkSize: j['s'] as int,
        shaUrl: j['h'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A GitHub release as an update, or null if it has no APK.
@visibleForTesting
Release? parseRelease(Map<String, dynamic> j) {
  if (j['draft'] == true || j['prerelease'] == true) return null;
  final tag = (j['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
  final assets = (j['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final apk = assets.where((a) => (a['name'] as String).endsWith('.apk')).firstOrNull;
  if (tag.isEmpty || apk == null) return null;
  final sha = assets.where((a) => (a['name'] as String).endsWith('.apk.sha256')).firstOrNull;
  return Release(
    version: tag,
    notes: releaseNotes(j['body'] as String? ?? ''),
    apkUrl: apk['browser_download_url'] as String,
    apkSize: (apk['size'] as num?)?.toInt() ?? 0,
    shaUrl: sha?['browser_download_url'] as String?,
  );
}

/// The "What's new" section as plain lines: the download instructions above
/// it are for the release page, not the update prompt.
@visibleForTesting
String releaseNotes(String body) {
  const heading = "## What's new";
  final at = body.indexOf(heading);
  final text = at < 0 ? body : body.substring(at + heading.length);
  return text
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\*\*|__|`'), '').replaceFirst(RegExp(r'^#+\s*'), ''))
      .join('\n')
      .trim();
}

/// Whether version [a] ("2.7.0") is newer than [b].
@visibleForTesting
bool isNewer(String a, String b) {
  List<int> parts(String v) =>
      v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var k = 0; k < 3; k++) {
    final p = k < x.length ? x[k] : 0, q = k < y.length ? y[k] : 0;
    if (p != q) return p > q;
  }
  return false;
}
