import 'package:flutter/material.dart';
import 'package:runapp/src/features/social/social_feed_screen.dart';
import 'package:runapp/src/features/profile/presentation/screens/profile_screen.dart';
import '../../../design/custom_bottom_bar.dart';
import 'map_home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 여기서 정의되어야 에러가 안 납니다.

  final List<Widget> _pages = [
    const MapHomeScreen(), // 0: 러닝
    const Center(child: Text("스팟")), // 1: 스팟
    const SocialFeedScreen(), // 2: 소셜
    const ProfileScreen(), // 3: 프로필
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 하단 바를 투명하게 쓸 경우 true
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // StatefulWidget 안에서만 setState를 쓸 수 있습니다.
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
