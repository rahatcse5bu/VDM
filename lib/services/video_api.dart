import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../core/format.dart';
import '../models/social_platform.dart';
import '../models/video_info.dart';
import '../state/instagram_session.dart';
import '../state/settings_controller.dart';

class VideoApiException implements Exception {
  const VideoApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Resolves social media links into downloadable video files using
/// third-party backends:
///
/// * **TikWM** (https://www.tikwm.com) – free, keyless, TikTok only, returns
///   rich metadata (title, cover, duration, sizes).
/// * **Facebook** – read on-device: the public page HTML embeds direct
///   `browser_native_hd_url` / `browser_native_sd_url` video links.
/// * **FxTwitter** (https://api.fxtwitter.com) – free, keyless JSON API for X.
/// * **Instagram** – Instagram's web API, called with the user's own session
///   from the in-app login (Instagram hides videos from logged-out requests).
/// * **Cobalt** (https://github.com/imputnet/cobalt) – open-source downloader
///   API for TikTok, Instagram, Facebook and X. Point the app at any instance
///   (self-hosted or community) in Settings.
class VideoApi {
  VideoApi(this._settings, [this._instagram]);

  final SettingsController _settings;
  final InstagramSession? _instagram;

  final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/126.0 Mobile Safari/537.36',
    },
  ));

  static const _cobaltQualities = [
    ('1080', '1080p (Full HD)', 'FHD'),
    ('720', '720p (HD)', 'HD'),
    ('480', '480p (SD)', 'SD'),
    ('360', '360p (SD)', 'SD'),
  ];

  Future<VideoInfo> fetch(String rawUrl) async {
    final url = normalizeUrl(rawUrl);
    final platform = SocialPlatform.detect(url);
    if (platform == SocialPlatform.unknown) {
      throw const VideoApiException(
          'Unsupported link. Paste a TikTok, Instagram, Facebook or X video link.');
    }

    // Keyless, on-device sources first; Cobalt is the fallback.
    final direct = switch (platform) {
      SocialPlatform.tiktok when _settings.useTikwm => _fetchTikwm,
      SocialPlatform.facebook => _fetchFacebook,
      SocialPlatform.x => _fetchX,
      SocialPlatform.instagram when _instagram?.isConnected ?? false => _fetchInstagram,
      _ => null,
    };
    Object? directError;
    if (direct != null) {
      try {
        return await direct(url);
      } catch (e) {
        directError = e;
      }
    }

    if (_settings.cobaltUrl.isNotEmpty) {
      try {
        return await _fetchCobalt(url, platform);
      } catch (e) {
        throw _friendly(e);
      }
    }

    if (directError != null) throw _friendly(directError);
    if (platform == SocialPlatform.instagram) {
      throw const VideoApiException(
          'Connect your Instagram account in Settings to download Instagram videos.');
    }
    throw VideoApiException(
        '${platform.label} links need a Cobalt server. Add one in Settings → Download server.');
  }

  /// Returns a fresh, directly downloadable file URL for [option].
  Future<String> resolveDownloadUrl(VideoInfo info, VideoOption option) async {
    if (option.directUrl != null) return option.directUrl!;
    try {
      final result = await _cobaltRequest(info.sourceUrl, option.quality);
      return result.url;
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Checks the configured Cobalt instance and returns its version string.
  Future<String> testCobalt() async {
    try {
      final res = await dio.get(_cobaltBase, options: Options(headers: {'Accept': 'application/json'}));
      final body = _json(res.data);
      final cobalt = body['cobalt'] as Map?;
      if (cobalt == null) throw const VideoApiException('This URL is not a Cobalt API server.');
      final services = (cobalt['services'] as List?)?.length ?? 0;
      return 'Cobalt ${cobalt['version'] ?? ''} · $services services';
    } catch (e) {
      throw _friendly(e);
    }
  }

  // ---------------------------------------------------------------- TikWM

  Future<VideoInfo> _fetchTikwm(String url) async {
    final res = await dio.post(
      'https://www.tikwm.com/api/',
      data: {'url': url, 'hd': 1},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final body = _json(res.data);
    if (body['code'] != 0) {
      throw VideoApiException(body['msg']?.toString() ?? 'TikWM could not read this link.');
    }
    final d = body['data'] as Map<String, dynamic>;
    if (d['images'] is List && (d['images'] as List).isNotEmpty) {
      throw const VideoApiException('This TikTok is a photo slideshow, not a video.');
    }

    String? abs(Object? u) {
      final s = u?.toString() ?? '';
      if (s.isEmpty) return null;
      return s.startsWith('http') ? s : 'https://www.tikwm.com$s';
    }

    final hd = abs(d['hdplay']);
    final sd = abs(d['play']);
    final options = <VideoOption>[
      if (hd != null)
        VideoOption(
          label: 'HD (No watermark)',
          badge: 'HD',
          quality: 'hd',
          sizeBytes: _toInt(d['hd_size']),
          directUrl: hd,
        ),
      if (sd != null)
        VideoOption(
          label: 'SD (No watermark)',
          badge: 'SD',
          quality: 'sd',
          sizeBytes: _toInt(d['size']),
          directUrl: sd,
        ),
    ];
    if (options.isEmpty) throw const VideoApiException('No video found at this link.');

    final seconds = _toInt(d['duration']);
    final title = (d['title'] as String?)?.trim();
    final author = (d['author'] as Map?)?['nickname'] as String?;
    return VideoInfo(
      sourceUrl: url,
      platform: SocialPlatform.tiktok,
      title: (title == null || title.isEmpty) ? 'TikTok by ${author ?? 'unknown'}' : title,
      author: author,
      thumbnailUrl: abs(d['origin_cover']) ?? abs(d['cover']),
      duration: seconds != null && seconds > 0 ? Duration(seconds: seconds) : null,
      previewUrl: sd ?? hd,
      options: options,
    );
  }

  // ------------------------------------------------------------- Facebook

  static const _desktopHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
  };

  Future<VideoInfo> _fetchFacebook(String url) async {
    final res = await dio.get<String>(
      url,
      options: Options(headers: _desktopHeaders, responseType: ResponseType.plain),
    );
    final html = res.data ?? '';

    // Values are JSON string literals inside the page's inline scripts.
    String? jsonString(String pattern) {
      final m = RegExp(pattern).firstMatch(html);
      if (m == null) return null;
      try {
        final v = jsonDecode(m.group(1)!) as String;
        return v.isEmpty ? null : v;
      } catch (_) {
        return null;
      }
    }

    final hd = jsonString(r'"browser_native_hd_url":("(?:[^"\\]|\\.)*")');
    final sd = jsonString(r'"browser_native_sd_url":("(?:[^"\\]|\\.)*")');
    if (hd == null && sd == null) {
      throw const VideoApiException(
          "Couldn't find a video on this Facebook page. It may be private or need a login.");
    }

    final owner = jsonString(r'"video_owner":\{"__typename":"\w+","id":"\d+","name":("(?:[^"\\]|\\.)*")');
    final caption = jsonString(r'"message":\{"text":("(?:[^"\\]|\\.)*")');
    final thumb = jsonString(r'"preferred_thumbnail":\{"image":\{"uri":("(?:[^"\\]|\\.)*")');
    final ms = int.tryParse(RegExp(r'"playable_duration_in_ms":(\d+)').firstMatch(html)?.group(1) ?? '');

    var title = caption?.split('\n').first.trim() ?? '';
    if (title.length > 90) title = '${title.substring(0, 90)}…';
    if (title.isEmpty) title = owner != null ? 'Facebook video by $owner' : 'Facebook video';

    return VideoInfo(
      sourceUrl: url,
      platform: SocialPlatform.facebook,
      title: title,
      author: owner,
      thumbnailUrl: thumb,
      duration: ms != null && ms > 0 ? Duration(milliseconds: ms) : null,
      previewUrl: sd ?? hd,
      options: [
        if (hd != null) VideoOption(label: 'HD quality', badge: 'HD', quality: 'hd', directUrl: hd),
        if (sd != null) VideoOption(label: 'SD quality', badge: 'SD', quality: 'sd', directUrl: sd),
      ],
    );
  }

  // ------------------------------------------------------------ FxTwitter

  Future<VideoInfo> _fetchX(String url) async {
    final id = RegExp(r'/status(?:es)?/(\d+)').firstMatch(url)?.group(1);
    if (id == null) throw const VideoApiException('Paste a link to a specific X post.');

    final res = await dio.get('https://api.fxtwitter.com/i/status/$id');
    final body = _json(res.data);
    final tweet = body['tweet'] as Map<String, dynamic>?;
    if (body['code'] != 200 || tweet == null) {
      throw VideoApiException(body['message']?.toString() ?? 'Could not read this X post.');
    }

    final videos = ((tweet['media'] as Map?)?['videos'] as List?)?.cast<Map>() ?? const [];
    if (videos.isEmpty) throw const VideoApiException('This X post has no video.');
    final video = videos.first;

    // Progressive MP4 variants; the URL path contains the resolution (…/1280x720/…).
    final variants = ((video['variants'] as List?) ?? const [])
        .cast<Map>()
        .where((v) => v['content_type'] == 'video/mp4' || (v['url'] as String? ?? '').contains('.mp4'))
        .toList()
      ..sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));

    final options = <VideoOption>[];
    for (final v in variants) {
      final vUrl = v['url'] as String;
      final dims = RegExp(r'/(\d+)x(\d+)/').firstMatch(vUrl);
      final height = dims == null
          ? null
          : [int.parse(dims.group(1)!), int.parse(dims.group(2)!)].reduce((a, b) => a < b ? a : b);
      final hd = height != null && height >= 720;
      final label = height != null ? '${height}p (${hd ? 'HD' : 'SD'})' : 'Quality ${options.length + 1}';
      if (options.any((o) => o.label == label)) continue;
      options.add(VideoOption(label: label, badge: hd ? 'HD' : 'SD', quality: '${v['bitrate']}', directUrl: vUrl));
    }
    final fallback = video['url'] as String?;
    if (options.isEmpty && fallback != null) {
      options.add(VideoOption(label: 'Best quality', badge: 'HD', quality: 'best', directUrl: fallback));
    }
    if (options.isEmpty) throw const VideoApiException('No downloadable video in this X post.');

    final author = (tweet['author'] as Map?)?['name'] as String?;
    var title = (tweet['text'] as String? ?? '').replaceAll(RegExp(r'https://t\.co/\S+'), '').trim();
    title = title.split('\n').first;
    if (title.length > 90) title = '${title.substring(0, 90)}…';
    if (title.isEmpty) title = 'Video by ${author ?? 'X user'}';

    final seconds = video['duration'] as num?;
    return VideoInfo(
      sourceUrl: url,
      platform: SocialPlatform.x,
      title: title,
      author: author,
      thumbnailUrl: video['thumbnail_url'] as String?,
      duration: seconds != null ? Duration(milliseconds: (seconds * 1000).round()) : null,
      previewUrl: options.last.directUrl,
      options: options,
    );
  }

  // ------------------------------------------------------------ Instagram

  static const _igAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  /// Converts a post shortcode (the `Dd6t_qiRmIK` in /reel/Dd6t_qiRmIK/) to
  /// Instagram's numeric media id. Private-link shortcodes carry extra
  /// characters after the first 11, which are not part of the id.
  @visibleForTesting
  static String instagramMediaId(String shortcode) {
    var id = BigInt.zero;
    for (final ch in shortcode.substring(0, shortcode.length.clamp(0, 11)).split('')) {
      final v = _igAlphabet.indexOf(ch);
      if (v < 0) throw const VideoApiException('This Instagram link is not valid.');
      id = id * BigInt.from(64) + BigInt.from(v);
    }
    return id.toString();
  }

  Future<VideoInfo> _fetchInstagram(String url) async {
    final session = _instagram!;
    var link = url;
    // instagram.com/share/... links redirect to the real post.
    if (Uri.tryParse(link)?.path.startsWith('/share/') ?? false) {
      final res = await dio.get<String>(link,
          options: Options(headers: _desktopHeaders, responseType: ResponseType.plain));
      link = res.realUri.toString();
    }
    final shortcode = RegExp(r'/(?:p|reels?|tv)/([A-Za-z0-9_-]+)').firstMatch(link)?.group(1);
    if (shortcode == null) {
      throw const VideoApiException('Paste a link to an Instagram post or reel.');
    }

    final res = await dio.get(
      'https://www.instagram.com/api/v1/media/${instagramMediaId(shortcode)}/info/',
      options: Options(
        headers: {
          'User-Agent': _desktopHeaders['User-Agent'],
          'X-IG-App-ID': '936619743392459',
          'X-CSRFToken': session.csrfToken ?? '',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://www.instagram.com/',
          'Cookie': session.cookieHeader,
        },
        // Without a valid session Instagram redirects to its login page.
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );

    Map<String, dynamic>? body;
    try {
      body = _json(res.data);
    } catch (_) {}
    final status = res.statusCode ?? 0;
    if (body == null || (status >= 300 && status < 400) || body['require_login'] == true || body['message'] == 'login_required' ||
        res.statusCode == 401) {
      throw const VideoApiException(
          'Your Instagram login has expired. Reconnect Instagram in Settings.');
    }
    if (body['message'] == 'checkpoint_required' || body['message'] == 'challenge_required') {
      throw const VideoApiException(
          'Instagram wants you to confirm your account. Open Instagram, then reconnect in Settings.');
    }
    if (res.statusCode == 429 || '${body['message']}'.contains('wait a few minutes')) {
      throw const VideoApiException('Instagram is limiting requests. Try again in a few minutes.');
    }
    final items = (body['items'] as List?)?.cast<Map>() ?? const [];
    if (res.statusCode == 404 || items.isEmpty) {
      throw const VideoApiException('This Instagram post is private, removed, or not available.');
    }

    final media = items.first;
    // Carousel posts hold their photos/videos in carousel_media.
    final parts = (media['carousel_media'] as List?)?.cast<Map>() ?? [media];
    final videos = parts.where((m) => (m['video_versions'] as List?)?.isNotEmpty ?? false).toList();
    if (videos.isEmpty) throw const VideoApiException('This Instagram post is a photo, not a video.');

    final options = <VideoOption>[];
    for (final (i, video) in videos.indexed) {
      final versions = (video['video_versions'] as List).cast<Map>().toList()
        ..sort((a, b) => ((b['height'] as num?) ?? 0).compareTo((a['height'] as num?) ?? 0));
      final seen = <int>{};
      for (final v in versions) {
        final w = (v['width'] as num?)?.toInt() ?? 0;
        final h = (v['height'] as num?)?.toInt() ?? 0;
        final p = w > 0 && h > 0 ? (w < h ? w : h) : 0;
        if (!seen.add(p)) continue;
        final hd = p >= 720;
        final quality = p > 0 ? '${p}p (${hd ? 'HD' : 'SD'})' : 'Best quality';
        options.add(VideoOption(
          label: videos.length > 1 ? 'Video ${i + 1} · $quality' : quality,
          badge: hd ? 'HD' : 'SD',
          quality: '$i-$p',
          directUrl: v['url'] as String,
        ));
      }
    }

    String? cover(Map m) =>
        ((m['image_versions2'] as Map?)?['candidates'] as List?)?.cast<Map>().firstOrNull?['url'] as String?;

    final user = media['user'] as Map?;
    final username = user?['username'] as String?;
    var title = ((media['caption'] as Map?)?['text'] as String? ?? '').split('\n').first.trim();
    if (title.length > 90) title = '${title.substring(0, 90)}…';
    if (title.isEmpty) title = username != null ? 'Instagram video by @$username' : 'Instagram video';

    final seconds = (videos.first['video_duration'] ?? media['video_duration']) as num?;
    return VideoInfo(
      sourceUrl: url,
      platform: SocialPlatform.instagram,
      title: title,
      author: username != null ? '@$username' : null,
      thumbnailUrl: cover(videos.first) ?? cover(media),
      duration: seconds != null ? Duration(milliseconds: (seconds * 1000).round()) : null,
      // Smallest version of the first video.
      previewUrl: options.lastWhere((o) => o.quality.startsWith('0-')).directUrl,
      options: options,
    );
  }

  // --------------------------------------------------------------- Cobalt

  String get _cobaltBase {
    final base = _settings.cobaltUrl;
    return base.endsWith('/') ? base : '$base/';
  }

  Future<VideoInfo> _fetchCobalt(String url, SocialPlatform platform) async {
    final preview = await _cobaltRequest(url, '720');
    var title = preview.filename ?? '${platform.label} video';
    title = title.replaceAll(RegExp(r'\.(mp4|webm|mkv|mov)$'), '').replaceAll('_', ' ').trim();

    return VideoInfo(
      sourceUrl: url,
      platform: platform,
      title: title.isEmpty ? '${platform.label} video' : title,
      thumbnailUrl: preview.thumb,
      previewUrl: preview.url,
      options: [
        for (final (quality, label, badge) in _cobaltQualities)
          VideoOption(label: label, badge: badge, quality: quality),
      ],
    );
  }

  Future<_CobaltResult> _cobaltRequest(String url, String quality) async {
    final headers = {'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (_settings.cobaltKey.isNotEmpty) {
      headers['Authorization'] = 'Api-Key ${_settings.cobaltKey}';
    }
    final res = await dio.post(
      _cobaltBase,
      data: jsonEncode({
        'url': url,
        'videoQuality': quality,
        'downloadMode': 'auto',
        'filenameStyle': 'basic',
      }),
      options: Options(headers: headers, validateStatus: (_) => true),
    );
    final body = _json(res.data);

    switch (body['status']) {
      case 'tunnel':
      case 'redirect':
        final filename = body['filename'] as String?;
        // Instagram hides videos from logged-out requests, so Cobalt falls
        // back to the cover photo.
        if (filename != null && RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).hasMatch(filename)) {
          throw VideoApiException(_photoOnlyMessage(url));
        }
        return _CobaltResult(body['url'] as String, filename, null);
      case 'picker':
        final items = (body['picker'] as List).cast<Map>();
        final video = items.firstWhere((i) => i['type'] == 'video',
            orElse: () => throw VideoApiException(_photoOnlyMessage(url)));
        return _CobaltResult(video['url'] as String, null, video['thumb'] as String?);
      case 'error':
        throw VideoApiException(_cobaltError((body['error'] as Map?)?['code']?.toString()));
      default:
        throw VideoApiException('Unexpected server response (${body['status'] ?? res.statusCode}).');
    }
  }

  String _photoOnlyMessage(String url) {
    if (SocialPlatform.detect(url) == SocialPlatform.instagram) {
      return "Instagram only returned a photo for this post. If it's a video, "
          'connect your Instagram account in Settings.';
    }
    return 'This post is a photo, not a video.';
  }

  String _cobaltError(String? code) {
    if (code == null) return 'The server could not process this link.';
    if (code.contains('auth')) {
      return 'This Cobalt server requires an API key. Add it in Settings.';
    }
    if (code.contains('link.invalid') || code.contains('link.unsupported')) {
      return 'This link is not supported.';
    }
    if (code.contains('private')) return 'This post is private.';
    if (code.contains('age')) return 'This video is age-restricted.';
    if (code.contains('unavailable') || code.contains('empty')) {
      return 'Video is unavailable or was removed.';
    }
    if (code.contains('rate_exceeded')) return 'Too many requests. Try again in a minute.';
    if (code.contains('fetch')) return 'The server could not fetch this video. Try again later.';
    return 'Server error: $code';
  }

  // -------------------------------------------------------------- helpers

  /// TikWM returns numbers as either ints or strings.
  static int? _toInt(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  Map<String, dynamic> _json(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {}
    }
    throw const VideoApiException('The server returned an invalid response.');
  }

  VideoApiException _friendly(Object e) {
    if (e is VideoApiException) return e;
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const VideoApiException('The server took too long to respond.');
        case DioExceptionType.connectionError:
          return const VideoApiException('Could not connect. Check your internet or server URL.');
        default:
          return VideoApiException('Request failed (${e.response?.statusCode ?? e.message}).');
      }
    }
    return VideoApiException(e.toString());
  }
}

class _CobaltResult {
  const _CobaltResult(this.url, this.filename, this.thumb);
  final String url;
  final String? filename;
  final String? thumb;
}
