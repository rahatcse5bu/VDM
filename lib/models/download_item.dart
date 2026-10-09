import 'social_platform.dart';

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.title,
    required this.platform,
    required this.sourceUrl,
    required this.fileName,
    required this.sizeBytes,
    required this.quality,
    required this.createdAt,
    this.thumbName,
    this.duration,
  });

  final String id;
  final String title;
  final SocialPlatform platform;
  final String sourceUrl;

  /// Stored relative to the downloads folder, because the app container path
  /// changes between installs/updates on iOS.
  final String fileName;
  final String? thumbName;
  final int sizeBytes;
  final String quality;
  final Duration? duration;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'platform': platform.name,
        'sourceUrl': sourceUrl,
        'fileName': fileName,
        'thumbName': thumbName,
        'sizeBytes': sizeBytes,
        'quality': quality,
        'durationMs': duration?.inMilliseconds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Video',
        platform: SocialPlatform.fromName(json['platform'] as String?),
        sourceUrl: json['sourceUrl'] as String? ?? '',
        fileName: json['fileName'] as String,
        thumbName: json['thumbName'] as String?,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        quality: json['quality'] as String? ?? '',
        duration: json['durationMs'] == null
            ? null
            : Duration(milliseconds: json['durationMs'] as int),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
