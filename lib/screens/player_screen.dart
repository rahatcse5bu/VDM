import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';

/// Full-screen player for a downloaded file or a network preview.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen.file(File this.file, {super.key, required this.title}) : url = null;
  const PlayerScreen.network(String this.url, {super.key, required this.title}) : file = null;

  final File? file;
  final String? url;
  final String title;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _c;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _c = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: _failed
                  ? const Text('Could not play this video', style: TextStyle(color: Colors.white70))
                  : _c.value.isInitialized
                      ? AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))
                      : const CircularProgressIndicator(color: Colors.white),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      const Spacer(),
                      if (_c.value.isInitialized)
                        ValueListenableBuilder(
                          valueListenable: _c,
                          builder: (context, value, _) => Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 20, 16),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => value.isPlaying ? _c.pause() : _c.play(),
                                  icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white, size: 32),
                                ),
                                Text(formatShort(value.position),
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: VideoProgressIndicator(
                                    _c,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    colors: const VideoProgressColors(
                                      playedColor: Colors.white,
                                      bufferedColor: Colors.white38,
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(formatShort(value.duration),
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
