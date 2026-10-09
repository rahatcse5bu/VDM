import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The user's own Instagram web session, captured from the in-app login
/// page. Instagram only serves videos to logged-in accounts, so these
/// cookies are sent with Instagram API requests. Stored in the
/// Keychain / Keystore, never in shared preferences.
class InstagramSession extends ChangeNotifier {
  InstagramSession([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  /// In-memory session for tests; never touches secure storage.
  @visibleForTesting
  InstagramSession.withCookies(Map<String, String> cookies)
      : _storage = null,
        _cookies = Map.of(cookies);

  static const _key = 'instagram_cookies';

  final FlutterSecureStorage? _storage;
  Map<String, String> _cookies = const {};

  bool get isConnected => (_cookies['sessionid'] ?? '').isNotEmpty;
  String? get csrfToken => _cookies['csrftoken'];
  String? get userId => _cookies['ds_user_id'];

  /// Value for a `Cookie` request header.
  String get cookieHeader => _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<void> load() async {
    try {
      final raw = await _storage?.read(key: _key);
      if (raw != null && raw.isNotEmpty) _cookies = _decode(raw);
    } catch (_) {
      // Unreadable keychain entry (e.g. after a restore): start logged out.
      _cookies = const {};
    }
    notifyListeners();
  }

  Future<void> save(Map<String, String> cookies) async {
    _cookies = Map.of(cookies);
    await _storage?.write(key: _key, value: cookieHeader);
    notifyListeners();
  }

  Future<void> clear() async {
    _cookies = const {};
    await _storage?.delete(key: _key);
    notifyListeners();
  }

  static Map<String, String> _decode(String header) {
    final out = <String, String>{};
    for (final part in header.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
    }
    return out;
  }
}
