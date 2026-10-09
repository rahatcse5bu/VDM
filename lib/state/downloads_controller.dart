import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';
import '../models/social_platform.dart';
import '../models/video_info.dart';
import '../services/video_api.dart';

class ActiveDownload {
  ActiveDownload({
    required this.key,
    required this.title,
    required this.platform,
    required this.quality,
    this.thumbnailUrl,
  });

  final String key;
  final String title;
  final SocialPlatform platform;
  final String quality;
  final String? thumbnailUrl;
  final CancelToken cancelToken = CancelToken();
  int received = 0;
  int? total;

  double? get progress => total == null || total == 0 ? null : (received / total!).clamp(0, 1);
}

class DownloadResult {
  const DownloadResult(this.item, {this.savedToGallery = false});
  final DownloadItem item;
  final bool savedToGallery;
}

class DownloadsController extends ChangeNotifier {
  DownloadsController(this._prefs);

  static const _storeKey = 'downloads_v1';

  final SharedPreferences _prefs;
  late Directory _dir;

  List<DownloadItem> items = [];
  final Map<String, ActiveDownload> active = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory('${docs.path}/vdm_downloads');
    await _dir.create(recursive: true);

    final raw = _prefs.getString(_storeKey);
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => DownloadItem.fromJson(e as Map<String, dynamic>))
            .where((i) => fileOf(i).existsSync())
            .toList();
      } catch (_) {
        items = [];
      }
    }
    notifyListeners();
  }

  File fileOf(DownloadItem item) => File('${_dir.path}/${item.fileName}');

  File? thumbOf(DownloadItem item) {
    if (item.thumbName == null) return null;
    final f = File('${_dir.path}/${item.thumbName}');
    return f.existsSync() ? f : null;
  }

  static String keyFor(VideoInfo info, VideoOption option) => '${info.sourceUrl}|${option.quality}';

  /// Downloads [option] of [info]. Returns null if the download was cancelled
  /// or the same file is already downloading.
  Future<DownloadResult?> download({
    required VideoInfo info,
    required VideoOption option,
    required VideoApi api,
    required bool saveToGallery,
    Duration? duration,
  }) async {
    final key = keyFor(info, option);
    if (active.containsKey(key)) return null;

    final task = ActiveDownload(
      key: key,
      title: info.title,
      platform: info.platform,
      quality: option.label,
      thumbnailUrl: info.thumbnailUrl,
    );
    active[key] = task;
    notifyListeners();

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '${_safeName(info.title)}_$id.mp4';
    final file = File('${_dir.path}/$fileName');

    try {
      final url = await api.resolveDownloadUrl(info, option);
      await api.dio.download(
        url,
        file.path,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          task.received = received;
          task.total = total > 0 ? total : null;
          _throttledNotify();
        },
      );

      final size = await file.length();
      if (size < 1024) {
        throw const VideoApiException('The server returned an empty file. Try another quality.');
      }

      String? thumbName;
      if (info.thumbnailUrl != null) {
        thumbName = 'thumb_$id.jpg';
        try {
          await api.dio.download(info.thumbnailUrl!, '${_dir.path}/$thumbName');
        } catch (_) {
          thumbName = null;
        }
      }

      final item = DownloadItem(
        id: id,
        title: info.title,
        platform: info.platform,
        sourceUrl: info.sourceUrl,
        fileName: fileName,
        thumbName: thumbName,
        sizeBytes: size,
        quality: option.label,
        duration: info.duration ?? duration,
        createdAt: DateTime.now(),
      );
      items.insert(0, item);
      await _persist();

      final saved = saveToGallery && await saveItemToGallery(item);
      return DownloadResult(item, savedToGallery: saved);
    } on DioException catch (e) {
      if (file.existsSync()) await file.delete();
      if (CancelToken.isCancel(e)) return null;
      throw VideoApiException(
          'Download failed (${e.response?.statusCode ?? e.type.name}). Please try again.');
    } catch (_) {
      if (file.existsSync()) await file.delete();
      rethrow;
    } finally {
      active.remove(key);
      notifyListeners();
    }
  }

  void cancel(String key) => active[key]?.cancelToken.cancel();

  Future<bool> saveItemToGallery(DownloadItem item) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return false;
      }
      await Gal.putVideo(fileOf(item).path, album: 'VDM');
      return true;
    } catch (e) {
      debugPrint('Gallery save failed: $e');
      return false;
    }
  }

  Future<void> delete(DownloadItem item) async {
    items.removeWhere((i) => i.id == item.id);
    await _deleteFiles(item);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final item in items) {
      await _deleteFiles(item);
    }
    items = [];
    await _persist();
    notifyListeners();
  }

  Future<void> _deleteFiles(DownloadItem item) async {
    final f = fileOf(item);
    if (f.existsSync()) await f.delete();
    final t = thumbOf(item);
    if (t != null) await t.delete();
  }

  Future<void> _persist() =>
      _prefs.setString(_storeKey, jsonEncode(items.map((i) => i.toJson()).toList()));

  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds > 120) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  String _safeName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\w\- ]+'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    if (cleaned.isEmpty) return 'video';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}
