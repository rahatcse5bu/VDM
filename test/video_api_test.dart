import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vdm/core/format.dart';
import 'package:vdm/models/social_platform.dart';
import 'package:vdm/services/video_api.dart';
import 'package:vdm/state/instagram_session.dart';
import 'package:vdm/state/settings_controller.dart';

void main() {
  group('normalizeUrl', () {
    test('extracts link from shared text', () {
      expect(normalizeUrl('Look at this! https://vm.tiktok.com/ZM123/ lol'), 'https://vm.tiktok.com/ZM123/');
    });
    test('adds missing scheme', () {
      expect(normalizeUrl('x.com/user/status/1'), 'https://x.com/user/status/1');
    });
  });

  test('detects platforms', () {
    expect(SocialPlatform.detect('https://www.tiktok.com/@a/video/1'), SocialPlatform.tiktok);
    expect(SocialPlatform.detect('https://vm.tiktok.com/abc'), SocialPlatform.tiktok);
    expect(SocialPlatform.detect('https://www.instagram.com/reel/abc/'), SocialPlatform.instagram);
    expect(SocialPlatform.detect('https://fb.watch/abc'), SocialPlatform.facebook);
    expect(SocialPlatform.detect('https://twitter.com/a/status/1'), SocialPlatform.x);
    expect(SocialPlatform.detect('https://nottiktok.com/a'), SocialPlatform.unknown);
  });

  test('formats sizes and durations', () {
    expect(formatBytes(15938355), '15.2 MB');
    expect(formatShort(const Duration(seconds: 15)), '0:15');
    expect(formatLong(const Duration(seconds: 75)), '01:15');
  });

  group('VideoApi', () {
    late VideoApi api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      api = VideoApi(SettingsController(await SharedPreferences.getInstance()));
    });

    test('rejects unsupported links', () {
      expect(api.fetch('https://example.com/video'), throwsA(isA<VideoApiException>()));
    });

    test('asks to connect Instagram when there is no session', () {
      expect(
        api.fetch('https://www.instagram.com/reel/abc/'),
        throwsA(predicate((e) => e is VideoApiException && e.message.contains('Connect your Instagram'))),
      );
    });

    test('converts Instagram shortcodes to media ids', () {
      expect(VideoApi.instagramMediaId('A'), '0');
      expect(VideoApi.instagramMediaId('BA'), '64');
      expect(VideoApi.instagramMediaId('Dd6t_qiRmIK'), '3997709906336965130');
      // Private-link shortcodes have extra characters after the first 11.
      expect(VideoApi.instagramMediaId('Dd6t_qiRmIKxyzPRIVATE'), '3997709906336965130');
    });

    test('reports an expired Instagram session (live network)', () async {
      final settings = SettingsController(await SharedPreferences.getInstance());
      final igApi = VideoApi(settings, InstagramSession.withCookies({'sessionid': 'invalid', 'csrftoken': 'x'}));
      expect(
        igApi.fetch('https://www.instagram.com/reel/Dd6t_qiRmIK/'),
        throwsA(predicate((e) =>
            e is VideoApiException && (e.message.contains('expired') || e.message.contains('limiting')))),
      );
    }, tags: 'live', timeout: const Timeout(Duration(seconds: 40)));

    // Needs a real session: IG_COOKIES='sessionid=…; csrftoken=…; ds_user_id=…' flutter test
    final igCookies = Platform.environment['IG_COOKIES'];
    test('fetches an Instagram reel with a logged-in session (live network)', () async {
      final cookies = {
        for (final part in igCookies!.split(';'))
          if (part.contains('=')) part.split('=').first.trim(): part.substring(part.indexOf('=') + 1).trim(),
      };
      final settings = SettingsController(await SharedPreferences.getInstance());
      final info = await VideoApi(settings, InstagramSession.withCookies(cookies))
          .fetch('https://www.instagram.com/reel/Dd6t_qiRmIK/?utm_source=ig_web_copy_link');
      expect(info.platform, SocialPlatform.instagram);
      expect(info.options, isNotEmpty);
      expect(info.options.first.directUrl, startsWith('https://'));
    },
        tags: 'live',
        skip: igCookies == null ? 'Set IG_COOKIES to run' : false,
        timeout: const Timeout(Duration(seconds: 40)));

    test('fetches a TikTok video via TikWM (live network)', () async {
      final info = await api.fetch('https://www.tiktok.com/@scout2015/video/6718335390845095173');
      expect(info.platform, SocialPlatform.tiktok);
      expect(info.title, isNotEmpty);
      expect(info.options, isNotEmpty);
      expect(info.options.first.directUrl, startsWith('http'));
      expect(info.duration, isNotNull);
    }, tags: 'live', timeout: const Timeout(Duration(seconds: 40)));

    test('fetches a Facebook reel directly from the page (live network)', () async {
      final info = await api.fetch('https://www.facebook.com/reel/2169559563983983');
      expect(info.platform, SocialPlatform.facebook);
      expect(info.options.map((o) => o.badge), contains('HD'));
      expect(info.options.first.directUrl, contains('fbcdn.net'));
      expect(info.duration, isNotNull);
      expect(info.thumbnailUrl, isNotNull);
    }, tags: 'live', timeout: const Timeout(Duration(seconds: 40)));

    test('fetches an X video via FxTwitter (live network)', () async {
      final info = await api.fetch('https://x.com/SpaceX/status/1732824684683784516?s=20');
      expect(info.platform, SocialPlatform.x);
      expect(info.options.length, greaterThan(1));
      expect(info.options.first.label, contains('p ('));
      expect(info.options.first.directUrl, contains('video.twimg.com'));
      expect(info.title, isNot(contains('t.co')));
    }, tags: 'live', timeout: const Timeout(Duration(seconds: 40)));

    test('reports X posts without video (live network)', () {
      expect(
        api.fetch('https://x.com/NASA/status/1801661375549853931'),
        throwsA(isA<VideoApiException>()),
      );
    }, tags: 'live', timeout: const Timeout(Duration(seconds: 40)));
  });
}
