import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/social_platform.dart';
import '../services/video_api.dart';
import '../state/instagram_session.dart';
import '../state/settings_controller.dart';
import '../widgets/common.dart';
import 'instagram_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _key;
  bool _testing = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsController>();
    _url = TextEditingController(text: s.cobaltUrl);
    _key = TextEditingController(text: s.cobaltKey);
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final settings = context.read<SettingsController>();
    final api = context.read<VideoApi>();
    FocusScope.of(context).unfocus();
    await settings.setCobaltUrl(_url.text);
    await settings.setCobaltKey(_key.text);
    if (settings.cobaltUrl.isEmpty) {
      setState(() => _status = null);
      if (mounted) showSnack(context, 'Cobalt server removed');
      return;
    }
    setState(() => _testing = true);
    try {
      final version = await api.testCobalt();
      setState(() {
        _status = 'Connected · $version';
        _statusOk = true;
      });
    } on VideoApiException catch (e) {
      setState(() {
        _status = e.message;
        _statusOk = false;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _disconnectInstagram() async {
    final session = context.read<InstagramSession>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Instagram?'),
        content: const Text('Instagram videos will stop downloading until you log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (ok != true) return;
    await InstagramLoginScreen.logout(session);
    if (mounted) showSnack(context, 'Instagram disconnected');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final instagram = context.watch<InstagramSession>();
    final p = context.palette;
    final label = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: p.muted);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text('Appearance', style: label),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          const SizedBox(height: 28),
          Text('Instagram', style: label),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PlatformLogo(SocialPlatform.instagram, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Instagram account', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(instagram.isConnected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  size: 14, color: instagram.isConnected ? AppColors.success : p.muted),
                              const SizedBox(width: 4),
                              Text(instagram.isConnected ? 'Connected' : 'Not connected',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: instagram.isConnected ? AppColors.success : p.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Instagram only shows videos to logged-in accounts. You log in on '
                  "Instagram's own page; VDM never sees your password. Heavy downloading "
                  'can get an account rate-limited, so a secondary account is safer.',
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: instagram.isConnected
                      ? OutlinedButton(onPressed: _disconnectInstagram, child: const Text('Disconnect'))
                      : ElevatedButton(
                          onPressed: () => InstagramLoginScreen.open(context),
                          child: const Text('Connect Instagram'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Download servers', style: label),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('TikWM for TikTok', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Free public API · no key needed', style: TextStyle(color: p.muted, fontSize: 12)),
              value: s.useTikwm,
              onChanged: s.setUseTikwm,
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cobalt server', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Optional fallback for all platforms. Use your own instance '
                  '(github.com/imputnet/cobalt).',
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'https://cobalt.example.com',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'API key (optional)',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _testing ? null : _saveAndTest,
                    child: _testing
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : const Text('Save & test connection'),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(_statusOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          size: 18, color: _statusOk ? AppColors.success : Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_status!,
                            style: TextStyle(
                                fontSize: 12, color: _statusOk ? AppColors.success : Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Downloads', style: label),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save to gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Also copy finished videos to Photos', style: TextStyle(color: p.muted, fontSize: 12)),
              value: s.saveToGallery,
              onChanged: s.setSaveToGallery,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const VdmLogo(size: 24),
                const SizedBox(height: 6),
                Text('Version 1.0.0', style: TextStyle(color: p.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  'Only download content you own or have permission to use.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
