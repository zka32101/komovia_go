import 'package:flutter/material.dart';

/// 障子を開けるように、左右のパネルがスライドして退きながら画面へ入る
/// トランジション。対局画面へ入る「さあ打ちましょう」という節目の演出用。
Route<T> shojiTransitionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 1400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
      // パネルが開ききる前にページがうっすら透けて見えると
      // 「開いている最中」の雰囲気が薄れるため、フェードは終盤だけにかける。
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      );
      return Stack(
        children: [
          FadeTransition(opacity: fade, child: child),
          // 左の障子パネル：左へスライドして退く
          Align(
            alignment: Alignment.centerLeft,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1, 0),
              ).animate(curved),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: _ShojiPanel(),
              ),
            ),
          ),
          // 右の障子パネル：右へスライドして退く
          Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(1, 0),
              ).animate(curved),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: _ShojiPanel(alignRight: true),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ShojiPanel extends StatelessWidget {
  final bool alignRight;

  const _ShojiPanel({this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF0), // 和紙色
      ),
      child: CustomPaint(
        painter: _ShojiGridPainter(alignRight: alignRight),
        size: Size.infinite,
      ),
    );
  }
}

/// 障子の格子（組子）模様。左右のパネルが同一パターンに見えないよう、
/// 右パネルは半セル分ずらして組子の位相を変える。
class _ShojiGridPainter extends CustomPainter {
  final bool alignRight;

  const _ShojiGridPainter({required this.alignRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B5A2B).withOpacity(0.5)
      ..strokeWidth = 3;

    const cellSize = 40.0;
    final xOffset = alignRight ? cellSize / 2 : 0.0;
    for (double x = xOffset; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 外枠を少し太く
    final framePaint = Paint()
      ..color = const Color(0xFF6B4423)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), framePaint);
  }

  @override
  bool shouldRepaint(_ShojiGridPainter oldDelegate) => false;
}
