enum SocialPlatform {
  tiktok('TikTok'),
  instagram('Instagram'),
  facebook('Facebook'),
  x('X'),
  unknown('Video');

  const SocialPlatform(this.label);
  final String label;

  static const supported = [tiktok, instagram, facebook, x];

  static SocialPlatform detect(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    bool on(String domain) => host == domain || host.endsWith('.$domain');

    if (on('tiktok.com')) return tiktok;
    if (on('instagram.com') || on('instagr.am')) return instagram;
    if (on('facebook.com') || on('fb.watch') || on('fb.com')) return facebook;
    if (on('x.com') || on('twitter.com')) return x;
    return unknown;
  }

  static SocialPlatform fromName(String? name) =>
      values.firstWhere((p) => p.name == name, orElse: () => unknown);
}
