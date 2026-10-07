import 'package:flutter/material.dart';

/// A Go stone with a soft contact shadow and a small specular highlight.
/// Single source of truth for stone appearance across every board screen.
class GoStone extends StatelessWidget {
  const GoStone({
    super.key,
    required this.radius,
    required this.isBlack,
    this.child,
  });

  final double radius;
  final bool isBlack;

  /// Optional overlay centred on the stone (e.g. a dead-stone mark).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _GoStonePainter(isBlack: isBlack),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _GoStonePainter extends CustomPainter {
  _GoStonePainter({required this.isBlack});
  final bool isBlack;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Contact shadow, offset to the lower right.
    canvas.drawCircle(
      c + Offset(r * 0.10, r * 0.16),
      r * 0.98,
      Paint()
        ..color = Colors.black.withOpacity(0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
    );

    // Body: lit from the upper left.
    final rect = Rect.fromCircle(center: c, radius: r);
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.0,
        colors: isBlack
            ? const [Color(0xFF4A4A4A), Color(0xFF151515), Color(0xFF050505)]
            : const [Color(0xFFFFFFFF), Color(0xFFF1EDE2), Color(0xFFC9C3B3)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(c, r, body);

    // Thin rim so white stones read on a light board.
    if (!isBlack) {
      canvas.drawCircle(
        c,
        r - 0.4,
        Paint()
          ..color = const Color(0xFF8E8878).withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Specular highlight.
    canvas.drawCircle(
      c + Offset(-r * 0.36, -r * 0.40),
      r * 0.22,
      Paint()
        ..color = Colors.white.withOpacity(isBlack ? 0.20 : 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
  }

  @override
  bool shouldRepaint(_GoStonePainter old) => old.isBlack != isBlack;
}
