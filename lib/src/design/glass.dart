import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 18,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color alpha(Color c, double a) => c.withAlpha((a * 255).round());

    return Container(
      decoration: BoxDecoration(
        // [Fix] 블러 제거 (BackdropFilter 삭제) 및 배경 불투명도 상향 (0.08 -> 0.90)
        // 다크 모드에서도 가독성을 위해 surface 색상 사용
        color: alpha(scheme.surface, 0.90),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: alpha(isDark ? Colors.white : Colors.black, 0.10),
          width: 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
