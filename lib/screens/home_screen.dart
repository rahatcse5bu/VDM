import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/social_platform.dart';
import '../services/video_api.dart';
import '../state/settings_controller.dart';
import '../widgets/common.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } catch (_) {}
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      // iOS returns nothing if "Allow Paste" was denied, and the simulator
      // doesn't always sync the Mac clipboard — fall back to the system menu.
      _focus.requestFocus();
      showSnack(context, "Couldn't read the clipboard. Long-press the field and tap Paste.");
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Paste a video link first');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final info = await context.read<VideoApi>().fetch(text);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreviewScreen(info: info)));
    } on VideoApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleTheme() {
    final settings = context.read<SettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const VdmLogo(size: 34),
              const Spacer(),
              Material(
                color: p.soft,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _toggleTheme,
                  icon: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SoftCard(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Text(
                  'Paste a video link\nto download',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  'Supports Facebook, Instagram,\nX (Twitter) and TikTok',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Paste video link here...',
                    prefixIcon: Icon(Icons.link_rounded, color: p.muted),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, value, _) => value.text.isEmpty
                          ? IconButton(
                              tooltip: 'Paste',
                              onPressed: _paste,
                              icon: const Icon(Icons.content_paste_rounded, color: AppColors.primary),
                            )
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: _controller.clear,
                              icon: Icon(Icons.close_rounded, color: p.muted),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_loading ? 'Fetching...' : 'Download'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final platform in SocialPlatform.supported) ...[
                Expanded(
                  child: _PlatformTile(
                    platform: platform,
                    onTap: () {
                      _focus.requestFocus();
                      showSnack(context, 'Copy a link from ${platform.label} and paste it above');
                    },
                  ),
                ),
                if (platform != SocialPlatform.supported.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const _HowItWorks(),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({required this.platform, required this.onTap});

  final SocialPlatform platform;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              PlatformLogo(platform, size: 42),
              const SizedBox(height: 8),
              Text(platform.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Paste the video link', const Color(0xFF22B573)),
      ('Click Download', AppColors.primary),
      ('Save to your device', const Color(0xFFE85D8E)),
    ];

    return SoftCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: steps[i].$2.withValues(alpha: 0.15),
                          child: Text('${i + 1}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: steps[i].$2)),
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: Text(steps[i].$1, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const _PhoneArt(),
        ],
      ),
    );
  }
}

class _PhoneArt extends StatelessWidget {
  const _PhoneArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 100,
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 4,
            child: Container(
              width: 60,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7FB2FF), width: 3),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(color: Color(0xFFB9A4F7), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFE85D8E), size: 22),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.soft, width: 3),
              ),
              child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
