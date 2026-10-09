import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/video_api.dart';
import 'state/downloads_controller.dart';
import 'state/instagram_session.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final downloads = DownloadsController(prefs);
  await downloads.load();
  final instagram = InstagramSession();
  await instagram.load();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: downloads),
      ChangeNotifierProvider.value(value: instagram),
      ChangeNotifierProvider(create: (_) => NavController()),
      Provider(create: (_) => VideoApi(settings, instagram)),
    ],
    child: const VdmApp(),
  ));
}

class VdmApp extends StatelessWidget {
  const VdmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'VDM',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: settings.onboarded ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }
}
