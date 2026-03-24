import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design/theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/map/presentation/main_screen.dart'; // MainScreen 임포트
import 'core/session/session_controller.dart';

class RunApp extends ConsumerWidget {
  const RunApp({super.key});

  @override
  // [수정] WidgetRef ref 인자가 반드시 포함되어야 합니다.
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return MaterialApp(
      title: 'RunApp',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // [수정] 로그인 성공 시 복잡한 위젯 대신 MainScreen 하나만 호출합니다.
      home: session.isLoggedIn ? const MainScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
