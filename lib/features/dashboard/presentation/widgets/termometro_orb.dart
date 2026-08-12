import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Orbe do Termômetro Sereno.
///
/// Recebe [percent] (0-999+) e reage com cor, ritmo de respiração e expressão.
/// Vibra sutilmente quando estoura (>100%).
///
/// Uso:
/// ```dart
/// TermometroOrb(percent: 65, size: 100)
/// ```
class TermometroOrb extends StatefulWidget {
  const TermometroOrb({
    super.key,
    required this.percent,
    this.size = 180,
    this.showFace = true,
  });

  final double percent;
  final double size;
  final bool showFace;

  @override
  State<TermometroOrb> createState() => _TermometroOrbState();
}

class _TermometroOrbState extends State<TermometroOrb>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: _breathDurationFor(widget.percent),
    )..repeat(reverse: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _syncCritical();
  }

  @override
  void didUpdateWidget(covariant TermometroOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.percent != oldWidget.percent) {
      _breathController.duration = _breathDurationFor(widget.percent);
      _breathController.repeat(reverse: true);
      _syncCritical();
    }
  }

  void _syncCritical() {
    if (widget.percent > 100) {
      _shakeController.repeat(reverse: true);
    } else {
      _shakeController.stop();
      _shakeController.reset();
    }
  }

  Duration _breathDurationFor(double percent) {
    if (percent <= 50) return const Duration(milliseconds: 4000);
    if (percent <= 75) return const Duration(milliseconds: 3000);
    if (percent <= 90) return const Duration(milliseconds: 2000);
    if (percent <= 100) return const Duration(milliseconds: 1200);
    return const Duration(milliseconds: 800);
  }

  @override
  void dispose() {
    _breathController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskFor(widget.percent);

    return AnimatedBuilder(
      animation: Listenable.merge([_breathController, _shakeController]),
      builder: (context, _) {
        final breathT = Curves.easeInOut.transform(_breathController.value);
        final scale = 1 + breathT * 0.05;

        // Vibração horizontal quando crítico
        double shakeDx = 0;
        if (widget.percent > 100) {
          shakeDx = math.sin(_shakeController.value * math.pi * 4) * 2;
        }

        return Transform.translate(
          offset: Offset(shakeDx, 0),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _OrbPainter(
                percent: widget.percent,
                color: color,
                breathValue: breathT,
                scale: scale,
                showFace: widget.showFace,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.percent,
    required this.color,
    required this.breathValue,
    required this.scale,
    required this.showFace,
  });

  final double percent;
  final Color color;
  final double breathValue;
  final double scale;
  final bool showFace;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width * 0.28;

    // Halos concêntricos
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.15 * (1 - breathValue));
    canvas.drawCircle(center, baseR * (1.25 + breathValue * 0.3), haloPaint);
    canvas.drawCircle(
      center,
      baseR * (1.45 + breathValue * 0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.08 * (1 - breathValue)),
    );

    // Sombra suave da orbe (drop shadow)
    final shadow = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(center, baseR * scale, shadow);

    // Corpo da orbe com gradiente radial
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        Colors.white.withValues(alpha: 0.6),
        color.withValues(alpha: 0.9),
        color,
      ],
      stops: const [0, 0.4, 1],
    );

    final orbPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: baseR * scale),
      );
    canvas.drawCircle(center, baseR * scale, orbPaint);

    // Rosto
    if (showFace) {
      _paintFace(canvas, center, baseR * scale);
    }
  }

  void _paintFace(Canvas canvas, Offset center, double r) {
    final eyePaint = Paint()..color = Colors.white;
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round;

    final eyeOffset = r * 0.27;
    final eyeY = center.dy - r * 0.13;
    final eyeR = r * 0.075;

    // Olhos
    canvas.drawCircle(Offset(center.dx - eyeOffset, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(center.dx + eyeOffset, eyeY), eyeR, eyePaint);

    // Boca — varia com o estado
    final mouthPath = Path();
    final mouthY = center.dy + r * 0.28;
    final mouthWidth = r * 0.55;
    final left = Offset(center.dx - mouthWidth / 2, mouthY);
    final right = Offset(center.dx + mouthWidth / 2, mouthY);

    if (percent <= 50) {
      // Sorriso grande
      mouthPath.moveTo(left.dx, left.dy - r * 0.03);
      mouthPath.quadraticBezierTo(center.dx, mouthY + r * 0.18, right.dx, right.dy - r * 0.03);
    } else if (percent <= 75) {
      // Sorriso suave
      mouthPath.moveTo(left.dx, left.dy);
      mouthPath.quadraticBezierTo(center.dx, mouthY + r * 0.08, right.dx, right.dy);
    } else if (percent <= 90) {
      // Linha reta
      mouthPath.moveTo(left.dx, mouthY);
      mouthPath.lineTo(right.dx, mouthY);
    } else if (percent <= 100) {
      // Triste
      mouthPath.moveTo(left.dx, left.dy + r * 0.05);
      mouthPath.quadraticBezierTo(center.dx, mouthY - r * 0.12, right.dx, right.dy + r * 0.05);
    } else {
      // Muito triste
      mouthPath.moveTo(left.dx, left.dy + r * 0.1);
      mouthPath.quadraticBezierTo(center.dx, mouthY - r * 0.22, right.dx, right.dy + r * 0.1);
    }
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.breathValue != breathValue ||
        oldDelegate.scale != scale;
  }
}
