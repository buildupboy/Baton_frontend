import 'package:flutter/material.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // lib/design/custom_bottom_bar.dart 수정본

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      // 높이를 명시적으로 주면 화면 밖으로 밀려나는 것을 방지할 수 있습니다.
      // 보통 70~90 사이가 적당합니다 (기기 하단 바 포함)
      height: 90,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5), // 위쪽으로 살짝 그림자 생성
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        // bottom: true가 기본값이므로 기기 하단 여백을 자동으로 잡아줍니다.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(context, Icons.directions_run_rounded, "러닝", 0),
            _buildItem(context, Icons.location_on_rounded, "스팟", 1),
            _buildItem(context, Icons.people_alt_rounded, "소셜", 2),
            _buildItem(context, Icons.person_rounded, "프로필", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = currentIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final color = isSelected ? scheme.primary : scheme.outline;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
