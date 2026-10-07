import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/go_board_geometry.dart';

/// アタリの石（赤=自分の石が危ない／金=相手の石を取れる）と、打てない点の×を描く。
class GoHintPainter extends CustomPainter {
  final GoBoardGeometry geometry;
  final Map<(int, int), int> atari; // 座標 -> 色(1=黒,2=白)
  final Set<(int, int)> illegal;
  final int humanColor; // 自分の色

  GoHintPainter({
    required this.geometry,
    required this.atari,
    required this.illegal,
    this.humanColor = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringRadius = geometry.pitch * 0.46;
    for (final e in atari.entries) {
      final center = geometry.intersectionOffset(e.key.$1, e.key.$2);
      final mine = e.value == humanColor;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.pitch * 0.09
          ..color = mine ? const Color(0xFFE53935) : AppColors.kin,
      );
    }
    final cross = geometry.pitch * 0.16;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.pitch * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppColors.sumi.withOpacity(0.45);
    for (final pt in illegal) {
      final c = geometry.intersectionOffset(pt.$1, pt.$2);
      canvas.drawLine(c + Offset(-cross, -cross), c + Offset(cross, cross), p);
      canvas.drawLine(c + Offset(-cross, cross), c + Offset(cross, -cross), p);
    }
  }

  @override
  bool shouldRepaint(GoHintPainter old) =>
      old.atari != atari || old.illegal != illegal || old.geometry.size != geometry.size;
}
