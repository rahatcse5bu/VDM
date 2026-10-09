import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/settings_controller.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final p = context.palette;

    return Scaffold(
      body: IndexedStack(
        index: nav.value,
        children: const [HomeScreen(), DownloadsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: nav.value,
          onTap: (i) => nav.value = i,
          type: BottomNavigationBarType.fixed,
          backgroundColor: p.card,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: p.muted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Downloads'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
