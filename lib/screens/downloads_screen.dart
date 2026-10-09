import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/download_item.dart';
import '../models/social_platform.dart';
import '../state/downloads_controller.dart';
import '../widgets/common.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  SocialPlatform? _filter;

  Future<void> _confirmClear() async {
    final downloads = context.read<DownloadsController>();
    if (downloads.items.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all downloads?'),
        content: const Text('This removes every video downloaded in VDM. Copies saved to your gallery are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok == true) await downloads.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsController>();
    final items = downloads.items.where((i) => _filter == null || i.platform == _filter).toList();
    final active = downloads.active.values.where((a) => _filter == null || a.platform == _filter).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text('Downloads',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete all',
                  onPressed: _confirmClear,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                for (final p in SocialPlatform.supported)
                  _FilterChip(label: p.label, selected: _filter == p, onTap: () => setState(() => _filter = p)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty && active.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 24),
                    children: [
                      for (final task in active) _ActiveTile(task: task),
                      for (final item in items) _DownloadTile(item: item),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: selected ? AppColors.primary : p.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    color: selected ? Colors.white : p.text,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.platform, required this.parts});
  final SocialPlatform platform;
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlatformLogo(platform, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            [platform.label, ...parts].join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final downloads = context.read<DownloadsController>();
    final file = downloads.fileOf(item);

    void play() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen.file(file, title: item.title)),
        );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: play,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            VideoThumb(
              platform: item.platform,
              file: downloads.thumbOf(item),
              badge: item.duration != null ? formatShort(item.duration!) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  _MetaRow(platform: item.platform, parts: [
                    formatBytes(item.sizeBytes),
                    if (item.duration != null) formatLong(item.duration!),
                  ]),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) async {
                switch (action) {
                  case 'play':
                    play();
                  case 'share':
                    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: item.title));
                  case 'gallery':
                    final ok = await downloads.saveItemToGallery(item);
                    if (context.mounted) {
                      showSnack(context, ok ? 'Saved to gallery' : 'Could not save — check photo permissions');
                    }
                  case 'delete':
                    await downloads.delete(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow_rounded), title: Text('Play'))),
                PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Share'))),
                PopupMenuItem(
                    value: 'gallery',
                    child: ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Save to gallery'))),
                PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.task});
  final ActiveDownload task;

  @override
  Widget build(BuildContext context) {
    final progress = task.progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          VideoThumb(platform: task.platform, url: task.thumbnailUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6),
                ),
                const SizedBox(height: 6),
                _MetaRow(platform: task.platform, parts: [
                  progress == null ? formatBytes(task.received) : '${(progress * 100).round()}%',
                  task.quality,
                ]),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            onPressed: () => context.read<DownloadsController>().cancel(task.key),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: p.soft,
              child: const Icon(Icons.download_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No downloads yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Videos you download will appear here.',
                textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          ],
        ),
      ),
    );
  }
}
