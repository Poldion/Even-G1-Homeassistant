import 'package:even_g1_ha/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares versions numerically', () {
    expect(AppUpdater.isNewer('0.10.0', '0.9.0'), isTrue);
    expect(AppUpdater.isNewer('v1.0.0', '0.9.9'), isTrue);
    expect(AppUpdater.isNewer('0.9.0', '0.9.0'), isFalse);
    expect(AppUpdater.isNewer('0.8.1', '0.9.0'), isFalse);
    expect(AppUpdater.isNewer('0.9.1', '0.9.0+9'), isTrue);
  });

  test('takes only our release APK', () {
    const prefix = AppUpdater.downloadPrefix;
    final update = AppUpdater.parseRelease({
      'tag_name': 'v0.10.0',
      'body': '### Added\n- Neu\n\n---\n**Installation:** …',
      'assets': [
        {'name': 'even_g1-v0.10.0.zip', 'browser_download_url': '${prefix}v0.10.0/even_g1-v0.10.0.zip'},
        {'name': 'evil.apk', 'browser_download_url': 'https://example.com/evil.apk'},
        {'name': 'even-g1-ha-v0.10.0.apk', 'browser_download_url': '${prefix}v0.10.0/even-g1-ha-v0.10.0.apk'},
      ],
    });
    expect(update?.version, '0.10.0');
    expect(update?.apkUrl, endsWith('even-g1-ha-v0.10.0.apk'));
    expect(update?.notes, '### Added\n- Neu');
    expect(
      AppUpdater.parseRelease({'tag_name': 'v1.0.0', 'prerelease': true, 'assets': []}),
      isNull,
    );
  });
}
