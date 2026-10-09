String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(i < 2 ? 0 : 1)} ${units[i]}';
}

/// `0:15` style, used on video overlays.
String formatShort(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// `00:15` style, used in metadata rows.
String formatLong(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Pulls the first URL out of shared text such as
/// "Check this out! https://vm.tiktok.com/abc" and adds a scheme if missing.
String normalizeUrl(String input) {
  final text = input.trim();
  final match = RegExp(r'https?://\S+').firstMatch(text);
  final url = match?.group(0) ?? text.split(RegExp(r'\s+')).first;
  return url.startsWith('http') ? url : 'https://$url';
}
