import 'social_platform.dart';

class VideoOption {
  const VideoOption({
    required this.label,
    required this.badge,
    required this.quality,
    this.sizeBytes,
    this.directUrl,
  });

  /// e.g. "720p (HD)".
  final String label;

  /// Short tag shown in the coloured square, e.g. "HD" / "SD".
  final String badge;

  /// Backend-specific quality key (Cobalt `videoQuality`, or a TikWM variant).
  final String quality;

  final int? sizeBytes;

  /// Set when the backend already returned a file URL; otherwise it is
  /// resolved right before downloading.
  final String? directUrl;
}

class VideoInfo {
  const VideoInfo({
    required this.sourceUrl,
    required this.platform,
    required this.title,
    required this.options,
    this.author,
    this.thumbnailUrl,
    this.duration,
    this.previewUrl,
  });

  final String sourceUrl;
  final SocialPlatform platform;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final Duration? duration;
  final String? previewUrl;
  final List<VideoOption> options;
}
