import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/video_info.dart';
import '../services/video_api.dart';
import '../state/downloads_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.info});
  final VideoInfo info;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _video;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    final preview = widget.info.previewUrl;
    if (preview != null) {
      final c = VideoPlayerController.networkUrl(Uri.parse(preview));
      _video = c;
      c.initialize().then((_) {
        if (!mounted) return;
        c.setLooping(true);
        setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _videoFailed = true);
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Duration? get _duration {
    final v = _video;
    if (v != null && v.value.isInitialized) return v.value.duration;
    return widget.info.duration;
  }

  Future<void> _download(VideoOption option) async {
    final downloads = context.read<DownloadsController>();
    final settings = context.read<SettingsController>();
    final nav = context.read<NavController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final result = await downloads.download(
        info: widget.info,
        option: option,
        api: context.read<VideoApi>(),
        saveToGallery: settings.saveToGallery,
        duration: _duration,
      );
      if (result == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(result.savedToGallery ? 'Saved to your gallery 🎉' : 'Download complete'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              nav.value = 1;
              navigator.popUntil((r) => r.isFirst);
            },
          ),
        ));
    } on VideoApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final info = widget.info;
    final height = MediaQuery.sizeOf(context).height * 0.42;

    return Scaffold(
      backgroundColor: p.card,
      body: Column(
        children: [
          SizedBox(height: height, child: _buildVideo(context)),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  children: [
                    _SourceCard(info: info),
                    const SizedBox(height: 18),
                    Text('Download Options',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < info.options.length; i++)
                      _OptionRow(
                        info: info,
                        option: info.options[i],
                        index: i,
                        onDownload: () => _download(info.options[i]),
                      ),
                    const SizedBox(height: 12),
                    const _QualityBanner(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    final v = _video;
    final ready = v != null && v.value.isInitialized && !_videoFailed;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: v.value.size.width,
              height: v.value.size.height,
              child: VideoPlayer(v),
            ),
          )
        else
          VideoThumb(
            platform: widget.info.platform,
            url: widget.info.thumbnailUrl,
            width: double.infinity,
            height: double.infinity,
          ),
        // Bottom gradient for legibility.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        if (ready)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => v.value.isPlaying ? v.pause() : v.play(),
            ),
          ),
        if (v != null && !_videoFailed)
          IgnorePointer(
            child: Center(
              child: ready
                  ? ValueListenableBuilder(
                      valueListenable: v,
                      builder: (context, value, _) => AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: value.isPlaying ? 0.0 : 1.0,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 34,
          child: ready
              ? ValueListenableBuilder(
                  valueListenable: v,
                  builder: (context, value, _) => Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${formatShort(value.position)} / ${formatShort(value.duration)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              v.pause();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PlayerScreen.network(widget.info.previewUrl!, title: widget.info.title),
                              ));
                            },
                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: VideoProgressIndicator(
                          v,
                          allowScrubbing: true,
                          padding: EdgeInsets.zero,
                          colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.info});
  final VideoInfo info;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        PlatformLogo(info.platform, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 2),
              Text(info.sourceUrl,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ),
        Material(
          color: p.soft,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Copy link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: info.sourceUrl));
              showSnack(context, 'Link copied');
            },
            icon: Icon(Icons.copy_rounded, size: 20, color: p.text),
          ),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.info, required this.option, required this.index, required this.onDownload});

  final VideoInfo info;
  final VideoOption option;
  final int index;
  final VoidCallback onDownload;

  static const _badgeColors = [AppColors.success, AppColors.primary, AppColors.purple, Color(0xFFFF9F43)];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = _badgeColors[index % _badgeColors.length];
    final key = DownloadsController.keyFor(info, option);
    final task = context.select<DownloadsController, ActiveDownload?>((d) => d.active[key]);
    // Rebuild on progress ticks while this option downloads.
    if (task != null) context.watch<DownloadsController>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: Text(option.badge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  task != null
                      ? (task.progress == null
                          ? 'Downloading… ${formatBytes(task.received)}'
                          : 'Downloading… ${(task.progress! * 100).round()}%')
                      : (option.sizeBytes != null ? formatBytes(option.sizeBytes) : 'Best available'),
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: task == null
                ? ElevatedButton.icon(
                    onPressed: onDownload,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => context.read<DownloadsController>().cancel(key),
                    style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    icon: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, value: task.progress),
                    ),
                    label: const Text('Cancel'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QualityBanner extends StatelessWidget {
  const _QualityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No watermark • High quality',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Enjoy your video, clean and clear.',
                    style: TextStyle(color: context.palette.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
