import 'package:even_g1_ha/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        {
          'name': 'even_g1-v0.10.0.zip',
          'browser_download_url': '${prefix}v0.10.0/even_g1-v0.10.0.zip',
        },
        {
          'name': 'evil.apk',
          'browser_download_url': 'https://example.com/evil.apk',
        },
        {
          'name': 'even-g1-ha-v0.10.0.apk',
          'browser_download_url': '${prefix}v0.10.0/even-g1-ha-v0.10.0.apk',
        },
      ],
    });
    expect(update?.version, '0.10.0');
    expect(update?.apkUrl, endsWith('even-g1-ha-v0.10.0.apk'));
    expect(update?.notes, '### Added\n- Neu');
    expect(
      AppUpdater.parseRelease({
        'tag_name': 'v1.0.0',
        'prerelease': true,
        'assets': [],
      }),
      isNull,
    );
  });

  test('the preview channel takes only its pre-releases', () {
    const prefix = AppUpdater.downloadPrefix;
    Map<String, dynamic> release(String tag, {required bool pre}) => {
      'tag_name': tag,
      'prerelease': pre,
      'assets': [
        {
          'name': 'even-g1-ha-$tag.apk',
          'browser_download_url': '$prefix$tag/even-g1-ha-$tag.apk',
        },
      ],
    };
    final sk = AppUpdater.parseRelease(
      release('sk-v0.17.0.4', pre: true),
      channel: UpdateChannel.preview,
    );
    expect(sk?.version, '0.17.0.4');
    expect(sk?.channel, UpdateChannel.preview);
    expect(sk?.switchesChannel, isTrue); // from a stable build
    expect(
      AppUpdater.parseRelease(
        release('sk-v0.17.0.4', pre: true),
        channel: UpdateChannel.preview,
        installed: UpdateChannel.preview,
      )?.switchesChannel,
      isFalse,
    );
    expect(AppUpdater.isNewer('0.17.0.5', '0.17.0.4'), isTrue);
    expect(
      AppUpdater.parseRelease(
        release('v0.16.4', pre: false),
        channel: UpdateChannel.preview,
      ),
      isNull,
    );
    // The stable channel never takes a pre-release.
    expect(AppUpdater.parseRelease(release('sk-v0.17.0.4', pre: true)), isNull);
    expect(
      AppUpdater.parseRelease(release('sk-v0.17.0.4', pre: false)),
      isNull,
    );
  });

  test('tells the channel from the version', () {
    expect(AppUpdater.channelOf('0.17.0'), UpdateChannel.stable);
    expect(AppUpdater.channelOf('0.17.0+29000000'), UpdateChannel.stable);
    expect(AppUpdater.channelOf('0.17.0.12'), UpdateChannel.preview);
    expect(AppUpdater.channelOf(''), UpdateChannel.stable);
  });

  test('glasses with Even firmware get no version from 0.25.0 on', () {
    const u = AppUpdate(version: '0.25.0', apkUrl: 'x', notes: '');
    expect(AppUpdater.holdBackForEven(u, even: true).heldBack, isTrue);
    expect(AppUpdater.holdBackForEven(u, even: false).heldBack, isFalse);
    const old = AppUpdate(version: '0.24.3', apkUrl: 'x', notes: '');
    expect(AppUpdater.holdBackForEven(old, even: true).heldBack, isFalse);
    const preview = AppUpdate(version: '0.25.0.7', apkUrl: 'x', notes: '');
    expect(AppUpdater.holdBackForEven(preview, even: true).heldBack, isTrue);
  });

  test('only glasses stored as Even firmware are held back', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppUpdater.evenFirmware(), isFalse);
    SharedPreferences.setMockInitialValues({'glasses_firmware': 'even'});
    expect(await AppUpdater.evenFirmware(), isTrue);
    SharedPreferences.setMockInitialValues({'glasses_firmware': 'scouterkit'});
    expect(await AppUpdater.evenFirmware(), isFalse);
  });

  test('stable: releases with the integration and app-only pre-releases', () {
    const prefix = AppUpdater.downloadPrefix;
    Map<String, dynamic> release(String tag, {required bool pre}) => {
      'tag_name': tag,
      'prerelease': pre,
      'assets': [
        {
          'name': 'even-g1-ha-$tag.apk',
          'browser_download_url': '$prefix$tag/even-g1-ha-$tag.apk',
        },
      ],
    };
    final releases = [
      release('sk-v0.30.0.3', pre: true),
      release('app-v0.29.1', pre: true),
      release('v0.29.0', pre: false),
      release('app-v0.28.5', pre: true),
    ];
    final stable = AppUpdater.newest(releases, channel: UpdateChannel.stable);
    expect(stable?.version, '0.29.1');
    expect(stable?.apkUrl, endsWith('even-g1-ha-app-v0.29.1.apk'));
    final preview = AppUpdater.newest(releases, channel: UpdateChannel.preview);
    expect(preview?.version, '0.30.0.3');
    // An app-v tag that is not a pre-release, or a v tag that is: ignored.
    expect(AppUpdater.parseRelease(release('app-v1.0.0', pre: false)), isNull);
    expect(AppUpdater.parseRelease(release('v1.0.0', pre: true)), isNull);
  });
}
