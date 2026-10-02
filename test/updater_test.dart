import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/updater.dart';

void main() {
  test('versions compare by number, not text', () {
    expect(isNewer('2.7.0', '2.6.0'), isTrue);
    expect(isNewer('2.10.0', '2.9.3'), isTrue);
    expect(isNewer('3.0.0', '2.99.99'), isTrue);
    expect(isNewer('2.6.0', '2.6.0'), isFalse);
    expect(isNewer('2.6.0', '2.7.0'), isFalse);
    expect(isNewer('2.7', '2.6.9'), isTrue);
  });

  test('a release becomes an update with its APK, checksum and notes', () {
    final r = parseRelease({
      'tag_name': 'v2.7.0',
      'draft': false,
      'prerelease': false,
      'body':
          '## Download\n\n**[Download the APK](x)**\n\n## What\'s new\n\n- **Updates** from GitHub\n- Pantry fixes',
      'assets': [
        {'name': 'nomnom-v2.7.0.apk', 'browser_download_url': 'https://a/apk', 'size': 100},
        {'name': 'nomnom-v2.7.0.apk.sha256', 'browser_download_url': 'https://a/sha', 'size': 65},
      ],
    })!;
    expect(r.version, '2.7.0');
    expect(r.apkUrl, 'https://a/apk');
    expect(r.apkSize, 100);
    expect(r.shaUrl, 'https://a/sha');
    expect(r.notes, '- Updates from GitHub\n- Pantry fixes');
  });

  test('drafts, prereleases and releases without an APK are ignored', () {
    final apk = {'name': 'nomnom-v2.7.0.apk', 'browser_download_url': 'u', 'size': 1};
    expect(
      parseRelease({
        'tag_name': 'v2.7.0',
        'draft': true,
        'assets': [apk],
      }),
      isNull,
    );
    expect(
      parseRelease({
        'tag_name': 'v2.7.0',
        'prerelease': true,
        'assets': [apk],
      }),
      isNull,
    );
    expect(parseRelease({'tag_name': 'v2.7.0', 'assets': []}), isNull);
  });
}
