import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// GoEn's avatar frame catalog. Frames are earned through play only —
/// there is no IAP surface for them (unlike the board/stone skin shop).
///
/// Never rename or reuse an id once shipped (stored in `users/{uid}.frameId`
/// and `users/{uid}.earnedFrameIds`).
///
/// Unlock derivation (see [computeUnlockedFrameIds]):
/// - Rank frames (shodan/godan/kudan) are LIVE from the current allTime
///   rating — losing the rank stops the frame rendering (the stored
///   selection is kept but ignored, so it reappears if the rank returns).
/// - Count frames (games/wins/tournament) are LIVE from monotonic counters,
///   so they can never be lost.
/// - Streak / En score frames are STICKY: once met they're persisted to
///   `User.earnedFrameIds`, because the underlying value can go down
///   (a broken streak, a recalculated En score).
class FrameIds {
  static const shodan = 'rank_shodan';
  static const godan = 'rank_godan';
  static const kudan = 'rank_kudan';
  static const games10 = 'games_10';
  static const games100 = 'games_100';
  static const games1000 = 'games_1000';
  static const wins100 = 'wins_100';
  static const tournamentChampion = 'tournament_champion';
  static const tsumegoStreak3 = 'tsumego_streak_3';
  static const tsumegoStreak30 = 'tsumego_streak_30';
  static const enScore100 = 'en_score_100';
}

const List<AvatarFrame> kGoAvatarFrames = [
  AvatarFrame(id: FrameIds.shodan, name: '初段', tier: FrameTier.bronze),
  AvatarFrame(id: FrameIds.games10, name: '10局達成', tier: FrameTier.bronze),
  AvatarFrame(id: FrameIds.tsumegoStreak3, name: '詰碁3日連続', tier: FrameTier.bronze),
  AvatarFrame(id: FrameIds.godan, name: '五段', tier: FrameTier.silver),
  AvatarFrame(id: FrameIds.games100, name: '100局達成', tier: FrameTier.silver),
  AvatarFrame(id: FrameIds.tournamentChampion, name: 'トーナメント優勝', tier: FrameTier.silver),
  AvatarFrame(id: FrameIds.tsumegoStreak30, name: '詰碁30日連続', tier: FrameTier.silver),
  AvatarFrame(id: FrameIds.kudan, name: '九段', tier: FrameTier.gold),
  AvatarFrame(id: FrameIds.wins100, name: '100勝', tier: FrameTier.gold),
  AvatarFrame(id: FrameIds.enScore100, name: '縁スコア100', tier: FrameTier.gold),
  AvatarFrame(id: FrameIds.games1000, name: '1000局達成', tier: FrameTier.platinum),
];

/// Frames whose unlock is persisted once met (see class doc above).
const Set<String> kStickyFrameIds = {
  FrameIds.tsumegoStreak3,
  FrameIds.tsumegoStreak30,
  FrameIds.enScore100,
};

AvatarFrame? avatarFrameById(String? id) {
  if (id == null) return null;
  for (final f in kGoAvatarFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// Snapshot of the already-tracked stats frame unlocks derive from.
class FrameStats {
  const FrameStats({
    this.rating,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.tournamentWins = 0,
    this.tsumegoStreak = 0,
    this.maxEnScore = 0,
    this.earnedFrameIds = const {},
  });

  /// allTime rating leaderboard rating; null = never rated.
  final int? rating;
  final int gamesPlayed;
  final int wins;
  final int tournamentWins;
  final int tsumegoStreak;
  final int maxEnScore;
  final Set<String> earnedFrameIds;
}

/// Pure unlock derivation: live-derived frames plus persisted sticky ones.
Set<String> computeUnlockedFrameIds(FrameStats s) {
  final r = s.rating ?? 0;
  return {
    ...s.earnedFrameIds.where((id) => kStickyFrameIds.contains(id)),
    if (r >= 2000) FrameIds.shodan, // 初段 (go_rank.dart boundary)
    if (r >= 2400) FrameIds.godan, // 五段
    if (r >= 2800) FrameIds.kudan, // 九段
    if (s.gamesPlayed >= 10) FrameIds.games10,
    if (s.gamesPlayed >= 100) FrameIds.games100,
    if (s.gamesPlayed >= 1000) FrameIds.games1000,
    if (s.wins >= 100) FrameIds.wins100,
    if (s.tournamentWins >= 1) FrameIds.tournamentChampion,
    if (s.tsumegoStreak >= 3) FrameIds.tsumegoStreak3,
    if (s.tsumegoStreak >= 30) FrameIds.tsumegoStreak30,
    if (s.maxEnScore >= 100) FrameIds.enScore100,
  };
}

/// The frame to actually draw: the selection only if it's a known
/// catalog frame that is still unlocked, otherwise null (no frame).
AvatarFrame? resolveDisplayedFrame(String? selectedId, Set<String> unlocked) {
  final frame = avatarFrameById(selectedId);
  if (frame == null) return null;
  return AvatarFrame.isUnlocked(frame.id, unlocked) ? frame : null;
}

Color frameTierColor(FrameTier tier) {
  switch (tier) {
    case FrameTier.bronze:
      return const Color(0xFFCD7F32);
    case FrameTier.silver:
      return const Color(0xFFC0C0C0);
    case FrameTier.gold:
      return const Color(0xFFFFD700);
    case FrameTier.platinum:
      return const Color(0xFFB8E6F0);
  }
}

String localizedFrameName(AppLocalizations l10n, String id) {
  switch (id) {
    case FrameIds.shodan:
      return l10n.frameNameShodan;
    case FrameIds.godan:
      return l10n.frameNameGodan;
    case FrameIds.kudan:
      return l10n.frameNameKudan;
    case FrameIds.games10:
      return l10n.frameNameGames(10);
    case FrameIds.games100:
      return l10n.frameNameGames(100);
    case FrameIds.games1000:
      return l10n.frameNameGames(1000);
    case FrameIds.wins100:
      return l10n.frameNameWins(100);
    case FrameIds.tournamentChampion:
      return l10n.frameNameTournamentChampion;
    case FrameIds.tsumegoStreak3:
      return l10n.frameNameTsumegoStreak(3);
    case FrameIds.tsumegoStreak30:
      return l10n.frameNameTsumegoStreak(30);
    case FrameIds.enScore100:
      return l10n.frameNameEnScore100;
  }
  return id;
}

String localizedFrameCondition(AppLocalizations l10n, String id) {
  switch (id) {
    case FrameIds.shodan:
      return l10n.frameConditionRank(l10n.frameNameShodan);
    case FrameIds.godan:
      return l10n.frameConditionRank(l10n.frameNameGodan);
    case FrameIds.kudan:
      return l10n.frameConditionRank(l10n.frameNameKudan);
    case FrameIds.games10:
      return l10n.frameConditionGames(10);
    case FrameIds.games100:
      return l10n.frameConditionGames(100);
    case FrameIds.games1000:
      return l10n.frameConditionGames(1000);
    case FrameIds.wins100:
      return l10n.frameConditionWins(100);
    case FrameIds.tournamentChampion:
      return l10n.frameConditionTournament;
    case FrameIds.tsumegoStreak3:
      return l10n.frameConditionTsumegoStreak(3);
    case FrameIds.tsumegoStreak30:
      return l10n.frameConditionTsumegoStreak(30);
    case FrameIds.enScore100:
      return l10n.frameConditionEnScore;
  }
  return '';
}

/// An avatar emoji with an optional tier-colored ring around it.
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    required this.emoji,
    this.frame,
    this.size = 56,
    this.background,
  });

  final String emoji;
  final AvatarFrame? frame;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    return Container(
      key: f == null ? null : ValueKey('avatar-frame-${f.id}'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: f == null
            ? null
            : Border.all(color: frameTierColor(f.tier), width: size / 14),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
