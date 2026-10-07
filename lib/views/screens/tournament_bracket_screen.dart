import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/tournament.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'pvp_game_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// トーナメントのブラケット画面 - ラウンドごとの対戦組み合わせと結果
class TournamentBracketScreen extends ConsumerStatefulWidget {
  final Tournament tournament;

  const TournamentBracketScreen({Key? key, required this.tournament}) : super(key: key);

  @override
  ConsumerState<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends ConsumerState<TournamentBracketScreen> {
  bool _isStarting = false;
  bool _isCreatingGame = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;
    final matchesAsync = ref.watch(
      tournamentMatchesProvider((tournamentId: widget.tournament.id, round: null)),
    );

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(widget.tournament.name),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: matchesAsync.when(
        data: (matches) => _buildContent(context, l10n, matches, uid, currentUser?.displayName),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          _logger.e('Tournament matches error: $err');
          return Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)));
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    List<TournamentMatch> matches,
    String? uid,
    String? myDisplayName,
  ) {
    if (widget.tournament.isUpcoming) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.bracketNotCreatedMessage,
                style: TextStyle(color: AppColors.washiDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.tournament.participantUids.length >= 2)
                ElevatedButton(
                  onPressed: _isStarting ? null : () => _startTournament(context, l10n),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.kin),
                  child: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.startTournamentButton, style: const TextStyle(color: AppColors.sumi)),
                )
              else
                Text(
                  l10n.needTwoParticipantsMessage,
                  style: TextStyle(color: AppColors.washiDim, fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    if (matches.isEmpty) {
      return Center(
        child: Text(l10n.noMatchDataMessage, style: TextStyle(color: AppColors.washiDim)),
      );
    }

    final byRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }
    final rounds = byRound.keys.toList()..sort();
    final isRoundRobin = widget.tournament.format == 'round_robin';
    final isSwiss = widget.tournament.format == 'swiss';
    // round_robinは全節を勝ち数で戦うため順位表が主な進行表示。swissも
    // 同じ理由（勝ち抜き無し、成績順ペアリング）で順位表を出す。
    // single_eliminationだけ勝者が1人に絞られる勝ち上がり式なので不要。
    final showsStandings = isRoundRobin || isSwiss;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.tournament.isCompleted) _buildChampionBanner(l10n, matches),
        if (showsStandings) ...[
          _buildStandingsSection(l10n),
          const SizedBox(height: 20),
        ],
        for (final round in rounds) ...[
          Text(
            isRoundRobin
                ? l10n.roundRobinRoundLabel(round)
                : isSwiss
                    ? (widget.tournament.totalRounds > 0
                        ? l10n.swissRoundOfTotalLabel(round, widget.tournament.totalRounds)
                        : l10n.swissRoundLabel(round))
                    : (round == rounds.last && widget.tournament.isCompleted
                        ? l10n.finalRoundLabel
                        : l10n.swissRoundLabel(round)),
            style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...byRound[round]!.map((match) => _buildMatchCard(context, l10n, match, uid, myDisplayName)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildStandingsSection(AppLocalizations l10n) {
    final standingsAsync = ref.watch(tournamentStandingsProvider(widget.tournament.id));
    return standingsAsync.when(
      data: (standings) {
        if (standings.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.sumiLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.standingsTitle,
                style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < standings.length; i++) _buildStandingRow(l10n, i + 1, standings[i]),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Standings error: $err');
        return Text(l10n.standingsFetchFailedMessage, style: TextStyle(color: AppColors.washiDim));
      },
    );
  }

  Widget _buildStandingRow(AppLocalizations l10n, int rank, TournamentStandingEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? AppColors.kin : AppColors.washiDim,
                fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(entry.displayName, style: const TextStyle(color: AppColors.washi)),
          ),
          Text(
            l10n.winsLossesLabel(entry.wins, entry.losses),
            style: TextStyle(color: AppColors.washiDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChampionBanner(AppLocalizations l10n, List<TournamentMatch> matches) {
    final winnerId = widget.tournament.winnerId;
    final championName = winnerId == null ? null : _resolveDisplayName(matches, winnerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.kin, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.kin.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: AppColors.kin, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              championName != null ? l10n.championLabel(championName) : l10n.tournamentEndedLabel,
              style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 試合一覧のplayer1/player2表示名から、指定uidの表示名を探す。
  String? _resolveDisplayName(List<TournamentMatch> matches, String uid) {
    for (final match in matches) {
      if (match.player1Uid == uid && match.player1DisplayName != null) {
        return match.player1DisplayName;
      }
      if (match.player2Uid == uid && match.player2DisplayName != null) {
        return match.player2DisplayName;
      }
    }
    return null;
  }

  Widget _buildMatchCard(
    BuildContext context,
    AppLocalizations l10n,
    TournamentMatch match,
    String? uid,
    String? myDisplayName,
  ) {
    final isMyMatch = uid != null && (match.player1Uid == uid || match.player2Uid == uid);
    final canStart = isMyMatch &&
        match.isPending &&
        !match.isBye &&
        match.gameId == null &&
        myDisplayName != null;

    return Card(
      color: isMyMatch ? AppColors.kin.withOpacity(0.08) : AppColors.sumiSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildPlayerLabel(l10n, match.player1Uid, match.player1DisplayName, match.winnerUid)),
                Text(match.isBye ? 'BYE' : 'vs', style: TextStyle(color: AppColors.washiDim)),
                Expanded(
                  child: _buildPlayerLabel(
                    l10n,
                    match.player2Uid,
                    match.player2DisplayName,
                    match.winnerUid,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            if (canStart || match.gameId != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: match.gameId != null
                      ? () => _openGame(context, match.gameId!, uid!)
                      : (_isCreatingGame ? null : () => _startMatch(context, l10n, match, uid!, myDisplayName!)),
                  child: Text(match.gameId != null ? l10n.watchGameButton : l10n.startGameButton),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerLabel(
    AppLocalizations l10n,
    String? uid,
    String? displayName,
    String? winnerUid, {
    bool alignEnd = false,
  }) {
    if (uid == null) {
      return Text(
        l10n.byeWaitingLabel,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(color: AppColors.washiDim, fontStyle: FontStyle.italic),
      );
    }
    final isWinner = winnerUid == uid;
    return Text(
      displayName ?? 'Player',
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: TextStyle(
        color: isWinner ? AppColors.kin : AppColors.washi,
        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<void> _startTournament(BuildContext context, AppLocalizations l10n) async {
    setState(() => _isStarting = true);
    try {
      await ref.read(startTournamentProvider)(widget.tournament.id);
      ref.invalidate(tournamentMatchesProvider((tournamentId: widget.tournament.id, round: null)));
      ref.invalidate(activeTournamentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tournamentStartedMessage)),
        );
      }
    } catch (e) {
      _logger.e('Error starting tournament: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tournamentStartFailedMessage('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _startMatch(
    BuildContext context,
    AppLocalizations l10n,
    TournamentMatch match,
    String uid,
    String myDisplayName,
  ) async {
    setState(() => _isCreatingGame = true);
    try {
      final opponentUid = match.player1Uid == uid ? match.player2Uid! : match.player1Uid!;
      final opponentName =
          (match.player1Uid == uid ? match.player2DisplayName : match.player1DisplayName) ?? 'Player';

      // 対戦カード内でUIDの小さい方を黒番にする（両対局者が同じ結果になるようにするため）。
      final amIBlack = uid.compareTo(opponentUid) < 0;
      // トランザクションで排他制御されるため、両対局者がほぼ同時にタップしても
      // 対局は1つしか作られず、後から来た方は同じgameIdを受け取る。
      final gameId = await ref.read(createTournamentGameProvider)(
        widget.tournament.id,
        match.id,
        widget.tournament.boardSize,
        amIBlack ? uid : opponentUid,
        amIBlack ? myDisplayName : opponentName,
        amIBlack ? opponentUid : uid,
        amIBlack ? opponentName : myDisplayName,
        uid,
      );

      ref.invalidate(tournamentMatchesProvider((tournamentId: widget.tournament.id, round: null)));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PvpGameScreen(gameId: gameId, uid: uid)),
      );
    } catch (e) {
      _logger.e('Error starting tournament match: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameStartFailedMessage('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingGame = false);
    }
  }

  void _openGame(BuildContext context, String gameId, String uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PvpGameScreen(gameId: gameId, uid: uid)),
    );
  }
}
