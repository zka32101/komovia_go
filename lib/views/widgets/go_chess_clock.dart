import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_go/config/theme.dart';

/// 項目5: オプションのタイマーモード用の簡易対局時計。
///
/// komovia_chess の `TimeClock`（lib/src/widgets/time_clock.dart）と同じ
/// `komovia_core.formatClock`/`warningLevelFor` を使って表示を揃えている
/// が、碁縁にはこれまでクロック表示が一切無かったため、ここでは
/// 最小限（MM:SS表示＋手番側の強調＋残り少ない時の色変化）のみを
/// 実装する。byoyomi等の延長時間は扱わない（スコープ外）。
class GoChessClock extends StatelessWidget {
  const GoChessClock({
    super.key,
    required this.blackRemaining,
    required this.whiteRemaining,
    required this.isBlackTurn,
    required this.blackLabel,
    required this.whiteLabel,
  });

  final Duration blackRemaining;
  final Duration whiteRemaining;
  final bool isBlackTurn;
  final String blackLabel;
  final String whiteLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ClockTile(
            label: blackLabel,
            remaining: blackRemaining,
            isActive: isBlackTurn,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ClockTile(
            label: whiteLabel,
            remaining: whiteRemaining,
            isActive: !isBlackTurn,
          ),
        ),
      ],
    );
  }
}

class _ClockTile extends StatelessWidget {
  const _ClockTile({
    required this.label,
    required this.remaining,
    required this.isActive,
  });

  final String label;
  final Duration remaining;
  final bool isActive;

  core.ClockWarningLevel get _warningLevel => core.warningLevelFor(remaining);

  Color _textColor() {
    switch (_warningLevel) {
      case core.ClockWarningLevel.critical:
        return AppColors.shuLight;
      case core.ClockWarningLevel.low:
        return AppColors.kin;
      case core.ClockWarningLevel.normal:
        return AppColors.washi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _textColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.transparent,
        border: Border.all(
          color: isActive ? color.withOpacity(0.6) : AppColors.sumiLine,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.washiDim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            core.formatClock(remaining, showCentiseconds: false),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
