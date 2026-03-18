import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/map/presentation/map_home_screen.dart';
import 'core/session/session_controller.dart';

class RunApp extends ConsumerWidget {
  const RunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return MaterialApp(
      title: 'RunApp',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: session.isLoggedIn ? const MapHomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

