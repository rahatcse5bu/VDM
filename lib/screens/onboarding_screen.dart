import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/social_platform.dart';
import '../state/settings_controller.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const VdmLogo(size: 64),
              const SizedBox(height: 14),
              Text('Video Downloader',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(
                'Download your favorite videos\nfrom social media — no watermark,\nno login, no hassle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 15, height: 1.5),
              ),
              const Spacer(),
              const _Illustration(),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.read<SettingsController>().completeOnboarding(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('Get Started'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded)],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Fast  •  Free  •  No Account Needed', style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget logo(SocialPlatform platform, double angle) => Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: PlatformLogo(platform, size: 54),
          ),
        );
    Widget confetti(Color c, double angle) => Transform.rotate(
          angle: angle,
          child: Container(width: 14, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        );

    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 260,
              height: 120,
              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(80)),
            ),
          ),
          // Box
          Positioned(
            bottom: 18,
            child: Column(
              children: [
                Container(
                  width: 168,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6EA6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  width: 150,
                  height: 96,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4A8EFA), AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 48),
                ),
              ],
            ),
          ),
          Positioned(left: 50, top: 22, child: logo(SocialPlatform.tiktok, -0.12)),
          Positioned(right: 54, top: 6, child: logo(SocialPlatform.instagram, 0.1)),
          Positioned(left: 82, top: 84, child: logo(SocialPlatform.facebook, -0.05)),
          Positioned(right: 70, top: 76, child: logo(SocialPlatform.x, 0.08)),
          Positioned(left: 22, top: 70, child: confetti(const Color(0xFFFFB547), 0.6)),
          Positioned(right: 30, top: 50, child: confetti(const Color(0xFF7FB2FF), -0.7)),
          Positioned(left: 36, top: 120, child: confetti(AppColors.primary, math.pi / 5)),
          Positioned(right: 26, top: 128, child: confetti(const Color(0xFFFFB547), -0.4)),
        ],
      ),
    );
  }
}
