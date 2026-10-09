import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/theme.dart';
import '../models/social_platform.dart';

/// Brand tile for a social platform (TikTok, Instagram, Facebook, X).
class PlatformLogo extends StatelessWidget {
  const PlatformLogo(this.platform, {super.key, this.size = 44});

  final SocialPlatform platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final iconSize = size * 0.52;

    switch (platform) {
      case SocialPlatform.tiktok:
        return _tile(Colors.black, radius, FaIcon(FontAwesomeIcons.tiktok, color: Colors.white, size: iconSize));
      case SocialPlatform.x:
        return _tile(Colors.black, radius, FaIcon(FontAwesomeIcons.xTwitter, color: Colors.white, size: iconSize));
      case SocialPlatform.facebook:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
          alignment: Alignment.bottomCenter,
          child: FaIcon(FontAwesomeIcons.facebookF, color: Colors.white, size: size * 0.66),
        );
      case SocialPlatform.instagram:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
            ),
          ),
          alignment: Alignment.center,
          child: FaIcon(FontAwesomeIcons.instagram, color: Colors.white, size: iconSize * 1.1),
        );
      case SocialPlatform.unknown:
        return _tile(AppColors.primary, radius, Icon(Icons.play_arrow_rounded, color: Colors.white, size: iconSize));
    }
  }

  Widget _tile(Color color, BorderRadius radius, Widget icon) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, borderRadius: radius),
        alignment: Alignment.center,
        child: icon,
      );
}

/// "VDM" wordmark where the D contains a play triangle.
class VdmLogo extends StatelessWidget {
  const VdmLogo({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      color: AppColors.primary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('V', style: style),
        Stack(
          alignment: Alignment.center,
          children: [
            Text('D', style: style),
            Padding(
              padding: EdgeInsets.only(right: size * 0.06),
              child: Icon(Icons.play_arrow_rounded, color: context.palette.bg, size: size * 0.42),
            ),
          ],
        ),
        Text('M', style: style),
      ],
    );
  }
}

/// Rounded card used across screens.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.palette.soft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// Video thumbnail from a local file or network URL, with a gradient fallback.
class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    required this.platform,
    this.file,
    this.url,
    this.width = 88,
    this.height = 80,
    this.badge,
  });

  final SocialPlatform platform;
  final File? file;
  final String? url;
  final double width;
  final double height;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (file != null) {
      image = Image.file(file!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
    } else if (url != null) {
      image = Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
    } else {
      image = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (badge != null)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7FB2FF), Color(0xFF2F7BF5)],
          ),
        ),
        alignment: Alignment.center,
        child: PlatformLogo(platform, size: width * 0.34),
      );
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
