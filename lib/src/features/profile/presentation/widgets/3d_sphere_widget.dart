import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThreeDSphereWidget extends StatefulWidget {
  const ThreeDSphereWidget({super.key, this.size = 200});

  final double size;

  @override
  State<ThreeDSphereWidget> createState() => _ThreeDSphereWidgetState();
}

class _ThreeDSphereWidgetState extends State<ThreeDSphereWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final floatY = math.sin(t * math.pi * 2) * 7;
        final pulse = (math.sin(t * math.pi * 2) + 1) * 0.5;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SpherePainter(pulse: pulse, time: t),
          ),
        );
      },
    );
  }
}

class _SpherePainter extends CustomPainter {
  const _SpherePainter({required this.pulse, required this.time});

  final double pulse;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.36;

    _paintParticles(canvas, center, radius);
    _paintOuterGlow(canvas, center, radius);
    _paintShadow(canvas, center, radius);
    _paintMainSphere(canvas, center, radius);
    _paintInnerShadow(canvas, center, radius);
    _paintSpecularHighlights(canvas, center, radius);
    _paintRimLight(canvas, center, radius);
  }

  void _paintParticles(Canvas canvas, Offset c, double r) {
    final particle = Paint()..style = PaintingStyle.fill;
    final seedAngles = <double>[0.2, 0.95, 1.85, 2.4, 3.2, 4.1, 5.0];

    for (var i = 0; i < seedAngles.length; i++) {
      final a = seedAngles[i] + (time * 0.9) + i * 0.12;
      final orbit = r * (1.45 + (i % 3) * 0.15);
      final dx = c.dx + math.cos(a) * orbit;
      final dy = c.dy + math.sin(a * 1.05) * orbit * 0.62;
      final k = ((math.sin((time + i * 0.08) * math.pi * 2) + 1) * 0.5);
      final pr = 1.7 + k * 1.8;

      particle.color = const Color(0xFFF98A62).withValues(alpha: 0.22 + k * 0.35);
      canvas.drawCircle(Offset(dx, dy), pr, particle);
    }
  }

  void _paintOuterGlow(Canvas canvas, Offset c, double r) {
    final glowStrength = 0.28 + pulse * 0.35;
    final rect = Rect.fromCircle(center: c, radius: r * 1.63);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF8B57).withValues(alpha: glowStrength * 0.65),
          const Color(0xFFFF8B57).withValues(alpha: glowStrength * 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);

    canvas.drawCircle(c, r * 1.62, glow);
  }

  void _paintShadow(Canvas canvas, Offset c, double r) {
    final shadowRect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + r + 22),
      width: r * 1.8,
      height: r * 0.52,
    );
    final shadow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.20),
          Colors.black.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(shadowRect);
    canvas.drawOval(shadowRect, shadow);
  }

  void _paintMainSphere(Canvas canvas, Offset c, double r) {
    final sphereRect = Rect.fromCircle(center: c, radius: r);
    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 1.0,
        colors: [
          const Color(0xFFFF9468),
          const Color(0xFFE6683A),
          const Color(0xFFBA431F),
          const Color(0xFF7F250F),
        ],
        stops: const [0.0, 0.45, 0.78, 1.0],
      ).createShader(sphereRect);
    canvas.drawCircle(c, r, sphere);
  }

  void _paintInnerShadow(Canvas canvas, Offset c, double r) {
    final inner = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, 0.68),
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..blendMode = BlendMode.multiply;

    canvas.drawCircle(c, r, inner);
  }

  void _paintSpecularHighlights(Canvas canvas, Offset c, double r) {
    final mainHighlightRect = Rect.fromCenter(
      center: Offset(c.dx - r * 0.27, c.dy - r * 0.30),
      width: r * 0.86,
      height: r * 0.62,
    );
    final mainHighlight = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.62),
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(mainHighlightRect);
    canvas.drawOval(mainHighlightRect, mainHighlight);

    final coatingRect = Rect.fromCenter(
      center: Offset(c.dx + r * 0.02, c.dy - r * 0.05),
      width: r * 1.2,
      height: r * 0.95,
    );
    final coating = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.07),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(coatingRect);
    canvas.drawCircle(c, r * 0.98, coating);

    final streakRect = Rect.fromCenter(
      center: Offset(c.dx - r * 0.06, c.dy - r * 0.55),
      width: r * 0.64,
      height: r * 0.20,
    );
    final streak = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.42),
          Colors.transparent,
        ],
      ).createShader(streakRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(streakRect, streak);
  }

  void _paintRimLight(Canvas canvas, Offset c, double r) {
    final rimRect = Rect.fromCircle(center: c, radius: r);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.02),
          Colors.black.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.2),
        ],
        stops: const [0.04, 0.42, 0.78, 1.0],
      ).createShader(rimRect);

    canvas.drawCircle(c, r * 0.992, rim);
  }

  @override
  bool shouldRepaint(covariant _SpherePainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.time != time;
  }
}
