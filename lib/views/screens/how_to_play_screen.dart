import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// 遊び方説明 - オンボーディングと違い、いつでも開けるルールリファレンス。
/// 対局中に「これどうだったっけ」となったときに参照できることを意図している。
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({Key? key}) : super(key: key);

  List<_RuleSection> _buildSections(AppLocalizations l10n) => [
        _RuleSection(
          icon: Icons.dashboard_outlined,
          title: l10n.boardPartsTitle,
          body: l10n.boardPartsBody,
          diagram: _BoardAnatomyDiagram(l10n: l10n),
        ),
        _RuleSection(
          icon: Icons.grid_on,
          title: l10n.placingStonesTitle,
          body: l10n.placingStonesBody,
        ),
        _RuleSection(
          icon: Icons.hub_outlined,
          title: l10n.libertyAtariTitle,
          body: l10n.libertyAtariBody,
          diagram: _LibertyComparisonDiagram(l10n: l10n),
        ),
        _RuleSection(
          icon: Icons.remove_circle_outline,
          title: l10n.captureTitle,
          body: l10n.captureBody,
        ),
        _RuleSection(
          icon: Icons.block_outlined,
          title: l10n.suicideMoveTitle,
          body: l10n.suicideMoveBody,
          diagram: _SuicideMoveDiagram(l10n: l10n),
        ),
        _RuleSection(
          icon: Icons.map_outlined,
          title: l10n.territoryTitle,
          body: l10n.territoryBody,
        ),
        _RuleSection(
          icon: Icons.replay,
          title: l10n.koRuleTitle,
          body: l10n.koRuleBody,
        ),
        _RuleSection(
          icon: Icons.flag_outlined,
          title: l10n.endGameTitle,
          body: l10n.endGameBody,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sections = _buildSections(l10n);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.howToPlayTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildSectionCard(sections[index]),
      ),
    );
  }

  Widget _buildSectionCard(_RuleSection section) {
    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(section.icon, color: AppColors.kin),
        title: Text(
          section.title,
          style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
        ),
        collapsedBackgroundColor: AppColors.sumiSurface,
        backgroundColor: AppColors.sumiSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section.diagram != null) ...[
                  Center(child: section.diagram),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    section.body,
                    style: TextStyle(color: AppColors.washiDim, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSection {
  final IconData icon;
  final String title;
  final String body;
  final Widget? diagram;

  const _RuleSection({
    required this.icon,
    required this.title,
    required this.body,
    this.diagram,
  });
}

/// 盤の各部の名称（交点・辺・隅・天元・星）を示す簡易図。
class _BoardAnatomyDiagram extends StatelessWidget {
  final AppLocalizations l10n;

  const _BoardAnatomyDiagram({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(painter: _BoardAnatomyPainter(l10n: l10n)),
    );
  }
}

class _BoardAnatomyPainter extends CustomPainter {
  static const _lines = 7;
  final AppLocalizations l10n;

  const _BoardAnatomyPainter({required this.l10n});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.washiDim
      ..strokeWidth = 1;
    final step = size.width / (_lines - 1);

    for (var i = 0; i < _lines; i++) {
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), gridPaint);
      canvas.drawLine(Offset(0, i * step), Offset(size.width, i * step), gridPaint);
    }

    Offset pointAt(int col, int row) => Offset(col * step, row * step);

    void drawHoshi(Offset center) {
      canvas.drawCircle(center, 4, Paint()..color = AppColors.washi);
    }

    void drawLabel(String text, Offset anchor, Offset labelOffset) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: AppColors.kin, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = anchor + labelOffset;
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));

      final linePaint = Paint()
        ..color = AppColors.kin.withOpacity(0.6)
        ..strokeWidth = 1;
      canvas.drawLine(anchor, labelPos, linePaint);
    }

    // 隅 (corner)
    final corner = pointAt(0, 0);
    canvas.drawCircle(corner, 3, Paint()..color = AppColors.wakatake);
    drawLabel(l10n.diagramCornerLabel, corner, const Offset(-22, -18));

    // 辺 (side, middle of the top edge)
    final side = pointAt((_lines - 1) ~/ 2, 0);
    canvas.drawCircle(side, 3, Paint()..color = AppColors.aiLight);
    drawLabel(l10n.diagramSideLabel, side, const Offset(0, -22));

    // 天元 (center) - drawn as a hoshi point
    final center = pointAt((_lines - 1) ~/ 2, (_lines - 1) ~/ 2);
    drawHoshi(center);
    drawLabel(l10n.diagramCenterStarLabel, center, const Offset(0, 26));

    // 星 (corner-ish star point, offset from the true corner)
    final hoshi = pointAt(2, 2);
    drawHoshi(hoshi);
    drawLabel(l10n.diagramStarLabel, hoshi, const Offset(-26, 8));

    // 交点 (a plain, unremarkable intersection)
    final plainPoint = pointAt(4, 5);
    drawLabel(l10n.diagramIntersectionLabel, plainPoint, const Offset(28, 10));
  }

  @override
  bool shouldRepaint(_BoardAnatomyPainter oldDelegate) => false;
}

/// 呼吸点4つの通常の石と、呼吸点1つ(アタリ)の石を並べて見せる図。
class _LibertyComparisonDiagram extends StatelessWidget {
  final AppLocalizations l10n;

  const _LibertyComparisonDiagram({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(painter: _LibertyPainter(surroundedSides: const {})),
            ),
            const SizedBox(height: 4),
            Text(l10n.fourLibertiesLabel, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _LibertyPainter(surroundedSides: const {
                  _Side.left,
                  _Side.top,
                  _Side.right,
                }),
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.atariOneLibertyLabel, style: TextStyle(color: AppColors.shuLight, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

enum _Side { top, bottom, left, right }

class _LibertyPainter extends CustomPainter {
  final Set<_Side> surroundedSides;

  const _LibertyPainter({required this.surroundedSides});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.washiDim
      ..strokeWidth = 1;
    final step = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i <= 2; i++) {
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), gridPaint);
      canvas.drawLine(Offset(0, i * step), Offset(size.width, i * step), gridPaint);
    }

    final neighbors = {
      _Side.top: center - Offset(0, step),
      _Side.bottom: center + Offset(0, step),
      _Side.left: center - Offset(step, 0),
      _Side.right: center + Offset(step, 0),
    };

    // 中央の黒石
    canvas.drawCircle(center, 14, Paint()..color = AppColors.sumi);
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = AppColors.washi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (final entry in neighbors.entries) {
      if (surroundedSides.contains(entry.key)) {
        // 相手の石で塞がれている呼吸点
        canvas.drawCircle(entry.value, 12, Paint()..color = AppColors.washi);
      } else {
        // 開いている呼吸点を強調する輪
        canvas.drawCircle(
          entry.value,
          9,
          Paint()
            ..color = AppColors.wakatake
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LibertyPainter oldDelegate) =>
      oldDelegate.surroundedSides != surroundedSides;
}

/// 自殺手（呼吸点0になる着手）が禁止であることを示す図。
class _SuicideMoveDiagram extends StatelessWidget {
  final AppLocalizations l10n;

  const _SuicideMoveDiagram({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(painter: _LibertyPainter(surroundedSides: _Side.values.toSet())),
        ),
        const SizedBox(height: 4),
        Text(l10n.suicideMoveDiagramCaption, style: TextStyle(color: AppColors.shuLight, fontSize: 12)),
      ],
    );
  }
}
