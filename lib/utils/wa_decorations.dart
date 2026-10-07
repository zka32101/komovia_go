import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';

/// 円相（えんそう）風の一筆書きの円。禅画・書道で悟りや無限を表す図案で、
/// 完全な円にせず、筆を持ち上げる際のかすれ・重なりを表現するために
/// 開始角より少し回り込ませて終わらせている。アプリのロゴ代わりに使う。
class EnsoPainter extends CustomPainter {
  final Color color;
  final double strokeWidthFactor;

  const EnsoPainter({required this.color, this.strokeWidthFactor = 0.09});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.82;
    final strokeWidth = size.width * strokeWidthFactor;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // 筆致に強弱をつけるため、円弧を数回に分けて太さを変えながら描く。
    const startAngle = -math.pi * 0.62;
    const sweepAngle = math.pi * 1.68; // 一周弱で、右上に筆を抜いた隙間を残す
    const segments = 5;
    for (int i = 0; i < segments; i++) {
      final segStart = startAngle + sweepAngle * i / segments;
      final segSweep = sweepAngle / segments;
      // 描き始めは太く、抜けるにつれ少し細くする。
      final widthScale = 1.0 - 0.35 * (i / segments);
      paint.strokeWidth = strokeWidth * widthScale;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segStart,
        segSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(EnsoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidthFactor != strokeWidthFactor;
}

/// 青海波（せいがいは）風の背景パターン。半円を規則的に重ねて描く、
/// 波を模した和柄。装飾用途なので、上に乗る文字や碁盤を邪魔しないよう
/// 低い不透明度で使うことを想定している。
class SeigaihaPatternPainter extends CustomPainter {
  final Color color;
  final double arcRadius;

  const SeigaihaPatternPainter({required this.color, this.arcRadius = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rowHeight = arcRadius * 0.75;
    final rows = (size.height / rowHeight).ceil() + 1;
    final cols = (size.width / arcRadius).ceil() + 2;

    for (int row = 0; row < rows; row++) {
      final y = row * rowHeight;
      final xOffset = (row.isOdd) ? arcRadius / 2 : 0.0;
      for (int col = -1; col < cols; col++) {
        final x = col * arcRadius + xOffset;
        // 同心円弧を3重に重ねるのが青海波の特徴。
        for (int ring = 1; ring <= 3; ring++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: arcRadius * ring / 3),
            math.pi,
            math.pi,
            false,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(SeigaihaPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.arcRadius != arcRadius;
}

/// 碁盤の木目を表現する、緩やかに波打つ縦筋のペインター。
/// 実写画像を使わず、少数の緩やかなベジェ曲線で「柾目」風の質感を出す。
class WoodGrainPainter extends CustomPainter {
  final Color color;
  final int lineCount;

  const WoodGrainPainter({required this.color, this.lineCount = 6});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final spacing = size.width / (lineCount + 1);
    for (int i = 1; i <= lineCount; i++) {
      final baseX = spacing * i;
      final path = Path()..moveTo(baseX, 0);
      // 数点の緩やかな揺らぎを与えて木目らしいカーブにする。
      final wiggle = spacing * 0.18 * (i.isEven ? 1 : -1);
      path.cubicTo(
        baseX + wiggle, size.height * 0.3,
        baseX - wiggle, size.height * 0.6,
        baseX + wiggle * 0.5, size.height,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WoodGrainPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lineCount != lineCount;
}

/// 落款（らっかん）風の朱印。装飾目的のワンポイント。
class HankoSeal extends StatelessWidget {
  final String character;
  final double size;

  const HankoSeal({super.key, required this.character, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFB33A3A), // 朱色 (shu-iro)
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF8C2A2A), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.sumi.withOpacity(0.3), blurRadius: 3, offset: const Offset(1, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        character,
        style: TextStyle(
          color: AppColors.washi.withOpacity(0.92),
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
