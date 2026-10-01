import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// API keys live in the platform keystore, never in the app database or
/// backups.
class KeyVault {
  static const _store = FlutterSecureStorage();
  static final _cache = <Provider, String>{};

  static Future<String> read(Provider p) async {
    if (_cache.containsKey(p)) return _cache[p]!;
    final v = await _store.read(key: 'key_${p.name}') ?? '';
    return _cache[p] = v;
  }

  static Future<void> write(Provider p, String key) async {
    _cache[p] = key.trim();
    await _store.write(key: 'key_${p.name}', value: key.trim());
  }

  static Future<void> clear() async {
    _cache.clear();
    await _store.deleteAll();
  }
}
