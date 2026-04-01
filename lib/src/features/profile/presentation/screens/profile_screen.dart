import 'package:flutter/material.dart';

import '../widgets/3d_sphere_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _orange = Color(0xFFF7673B);
  static const Color _softGray = Color(0xFFF2F3F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD56F46), Color(0xFFA54A22)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _orange.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '바통',
              style: TextStyle(
                color: _orange,
                fontSize: 26 / 2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.notifications_rounded, color: Color(0xFF5E5E5E)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(
          children: [
            const SizedBox(height: 4),
            const SizedBox(
              width: 220,
              height: 220,
              child: ThreeDSphereWidget(),
            ),
            const SizedBox(height: 4),
            const Text(
              '바통 user 1',
              style: TextStyle(
                color: Color(0xFF181818),
                fontSize: 40 / 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pro Runner',
              style: TextStyle(
                color: Color(0xFF8A8E97),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    '러닝 지수',
                    style: TextStyle(
                      color: Color(0xFFAA4C31),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: '42.19',
                          style: TextStyle(
                            color: _orange,
                            fontSize: 56 / 2,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        TextSpan(
                          text: ' pts',
                          style: TextStyle(
                            color: Color(0xFFAF5A3F),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    icon: Icons.bolt_rounded,
                    title: '활동량',
                    value: '12.4 km',
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    icon: Icons.access_time_filled_rounded,
                    title: '시간',
                    value: '48 min',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '획득한 엠블럼',
                    style: TextStyle(
                      color: Color(0xFF1F1F1F),
                      fontSize: 23 / 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: _orange,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '전체보기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  _EmblemItem(
                    icon: Icons.wb_sunny_rounded,
                    title: '얼리버드',
                    isActive: true,
                  ),
                  SizedBox(width: 16),
                  _EmblemItem(
                    icon: Icons.workspace_premium_outlined,
                    title: '마라톤 완주',
                    isActive: true,
                  ),
                  SizedBox(width: 16),
                  _EmblemItem(
                    icon: Icons.local_fire_department_rounded,
                    title: '열정 레이서',
                  ),
                  SizedBox(width: 16),
                  _EmblemItem(
                    icon: Icons.nights_stay_rounded,
                    title: '야간 달리기',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _BottomItem(icon: Icons.directions_run_rounded, label: '러닝'),
              _BottomItem(icon: Icons.location_on_rounded, label: '스팟'),
              _BottomItem(icon: Icons.people_alt_rounded, label: '소셜'),
              _BottomItem(
                icon: Icons.person_rounded,
                label: '프로필',
                selected: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: ProfileScreen._softGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ProfileScreen._orange, size: 18),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8F949E),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 32 / 2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmblemItem extends StatelessWidget {
  const _EmblemItem({
    required this.icon,
    required this.title,
    this.isActive = false,
  });

  final IconData icon;
  final String title;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final base = isActive ? ProfileScreen._orange : const Color(0xFFCCCED3);
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1F2F4),
              border: isActive
                  ? Border.all(color: ProfileScreen._orange.withValues(alpha: 0.45))
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: ProfileScreen._orange.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Container(
                width: isActive ? 48 : 44,
                height: isActive ? 48 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? ProfileScreen._orange.withValues(alpha: 0.12) : null,
                ),
                child: Icon(icon, color: base, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? const Color(0xFF484B52) : const Color(0xFFB8BBC2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ProfileScreen._orange : const Color(0xFFA6AAB3);

    return Expanded(
      child: InkWell(
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? ProfileScreen._orange.withValues(alpha: 0.13) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
