import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../state/instagram_session.dart';
import '../widgets/common.dart';

/// Shows Instagram's own login page. The password goes straight to
/// Instagram; the app only keeps the session cookies once login succeeds.
class InstagramLoginScreen extends StatefulWidget {
  const InstagramLoginScreen({super.key});

  /// Opens the login page; resolves to true when an account was connected.
  static Future<bool> open(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InstagramLoginScreen(), fullscreenDialog: true),
    );
    return ok ?? false;
  }

  /// Removes the web view's Instagram cookies so the next login starts fresh.
  static Future<void> logout(InstagramSession session) async {
    await CookieManager.instance().deleteAllCookies();
    await session.clear();
  }

  @override
  State<InstagramLoginScreen> createState() => _InstagramLoginScreenState();
}

class _InstagramLoginScreenState extends State<InstagramLoginScreen> {
  static final _instagram = WebUri('https://www.instagram.com');

  InAppWebViewController? _web;
  Timer? _poll;
  double _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Instagram logs in without a full page load, so watch the cookie jar.
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkCookies());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _checkCookies() async {
    if (_done || _web == null) return;
    final session = context.read<InstagramSession>();
    final cookies = await CookieManager.instance().getCookies(url: _instagram, webViewController: _web);
    final jar = {for (final c in cookies) c.name: '${c.value}'};
    if ((jar['sessionid'] ?? '').isEmpty) return;

    _done = true;
    _poll?.cancel();
    await session.save(jar);
    if (!mounted) return;
    showSnack(context, 'Instagram connected');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in to Instagram'),
        bottom: _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://www.instagram.com/accounts/login/')),
        initialSettings: InAppWebViewSettings(
          incognito: false,
          sharedCookiesEnabled: true,
          thirdPartyCookiesEnabled: true,
        ),
        onWebViewCreated: (c) => _web = c,
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
        onLoadStop: (_, _) => _checkCookies(),
      ),
    );
  }
}
