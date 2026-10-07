/**
 * Weekly auto-tournament scheduler.
 *
 * Runs every Monday 00:00 JST. Each run does two things, in order:
 *
 * 1. Auto-starts LAST week's auto-created tournament if it's still
 *    'upcoming' (nobody manually started it already): generates its
 *    bracket/schedule the same way TournamentService.startTournament does
 *    client-side (lib/services/tournament_service.dart) — ported to
 *    TypeScript here since this has to run with no client open. A
 *    tournament with fewer than 2 participants is marked 'cancelled'
 *    instead of started.
 * 2. Creates THIS week's new auto tournament (status: 'upcoming',
 *    isAutoWeekly: true, a 7-day join window) for people to join.
 *
 * Tournament progress after auto-start (match results, round advancement,
 * champion determination) is still handled entirely by the existing
 * client-side TournamentService logic when players complete their
 * PvpGames — nothing here duplicates that.
 */
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const TOURNAMENTS_COLLECTION = "tournaments";
const PARTICIPANTS_COLLECTION = "participants";
const MATCHES_COLLECTION = "matches";

const DEFAULT_BOARD_SIZE = 19;
const DEFAULT_MAX_PARTICIPANTS = 16;
const DEFAULT_FORMAT = "single_elimination";
const JOIN_WINDOW_DAYS = 7;

interface TournamentData {
  format: string;
  status: string;
  participantUids: string[];
}

export const weeklyTournamentScheduler = onSchedule(
  {
    schedule: "0 0 * * 1", // every Monday 00:00
    timeZone: "Asia/Tokyo",
    region: "us-central1",
  },
  async () => {
    const db = admin.firestore();
    await autoStartPendingWeeklyTournament(db);
    await createNewWeeklyTournament(db);
  }
);

async function autoStartPendingWeeklyTournament(db: FirebaseFirestore.Firestore): Promise<void> {
  const snapshot = await db
    .collection(TOURNAMENTS_COLLECTION)
    .where("isAutoWeekly", "==", true)
    .where("status", "==", "upcoming")
    .get();

  for (const doc of snapshot.docs) {
    const tournament = doc.data() as TournamentData;

    if (tournament.participantUids.length < 2) {
      await doc.ref.update({status: "cancelled"});
      logger.info(`Cancelled weekly tournament ${doc.id}: fewer than 2 participants`);
      continue;
    }

    const participantsSnapshot = await doc.ref.collection(PARTICIPANTS_COLLECTION).get();
    const displayNames: Record<string, string> = {};
    for (const p of participantsSnapshot.docs) {
      displayNames[p.id] = (p.data().displayName as string | undefined) ?? "Player";
    }

    if (tournament.format === "round_robin") {
      await generateRoundRobinSchedule(db, doc.ref, tournament.participantUids, displayNames);
    } else {
      await generateSingleEliminationRound1(db, doc.ref, tournament.participantUids, displayNames);
    }

    await doc.ref.update({status: "active"});
    logger.info(`Auto-started weekly tournament ${doc.id} (format=${tournament.format})`);
  }
}

async function createNewWeeklyTournament(db: FirebaseFirestore.Firestore): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const endDate = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + JOIN_WINDOW_DAYS * 24 * 60 * 60 * 1000
  );
  const dateLabel = new Date(now.toMillis()).toLocaleDateString("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });

  const ref = await db.collection(TOURNAMENTS_COLLECTION).add({
    name: `週刊トーナメント ${dateLabel}`,
    description: "毎週自動開催されるトーナメントです。開始日までに参加してください。",
    startDate: now,
    endDate,
    maxParticipants: DEFAULT_MAX_PARTICIPANTS,
    format: DEFAULT_FORMAT,
    status: "upcoming",
    participantUids: [],
    winnerId: null,
    createdBy: null,
    boardSize: DEFAULT_BOARD_SIZE,
    lastAdvancedRound: 0,
    isAutoWeekly: true,
    createdAt: now,
  });

  logger.info(`Created new weekly tournament ${ref.id}`);
}

/** Mirrors TournamentService._generateRound in tournament_service.dart. */
async function generateSingleEliminationRound1(
  db: FirebaseFirestore.Firestore,
  tournamentRef: FirebaseFirestore.DocumentReference,
  playerUids: string[],
  displayNames: Record<string, string>
): Promise<void> {
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  for (let i = 0; i < playerUids.length; i += 2) {
    const player1Uid = playerUids[i];
    const hasOpponent = i + 1 < playerUids.length;
    const player2Uid = hasOpponent ? playerUids[i + 1] : null;
    const matchRef = tournamentRef.collection(MATCHES_COLLECTION).doc();

    batch.set(matchRef, {
      tournamentId: tournamentRef.id,
      player1Uid,
      player1DisplayName: displayNames[player1Uid] ?? "Player",
      player2Uid,
      player2DisplayName: player2Uid ? displayNames[player2Uid] ?? "Player" : null,
      round: 1,
      winnerUid: hasOpponent ? null : player1Uid,
      status: hasOpponent ? "pending" : "completed",
      gameId: null,
      scheduledAt: now,
      completedAt: hasOpponent ? null : now,
    });
  }

  await batch.commit();
}

/** Mirrors TournamentService._generateRoundRobinSchedule in tournament_service.dart. */
async function generateRoundRobinSchedule(
  db: FirebaseFirestore.Firestore,
  tournamentRef: FirebaseFirestore.DocumentReference,
  playerUids: string[],
  displayNames: Record<string, string>
): Promise<void> {
  const schedule = roundRobinPairings(playerUids);
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  schedule.forEach((roundPairs, index) => {
    const round = index + 1;
    for (const [a, b] of roundPairs) {
      const matchRef = tournamentRef.collection(MATCHES_COLLECTION).doc();
      batch.set(matchRef, {
        tournamentId: tournamentRef.id,
        player1Uid: a,
        player1DisplayName: displayNames[a] ?? "Player",
        player2Uid: b,
        player2DisplayName: displayNames[b] ?? "Player",
        round,
        winnerUid: null,
        status: "pending",
        gameId: null,
        scheduledAt: now,
        completedAt: null,
      });
    }
  });

  await batch.commit();
}

/**
 * Circle-method round-robin pairing, mirroring
 * TournamentService._roundRobinPairings exactly (same algorithm, same
 * odd-count bye handling) so both implementations produce the same
 * schedule shape for the same input. Exported for unit testing.
 */
export function roundRobinPairings(playerUids: string[]): [string, string][][] {
  const players: (string | null)[] = [...playerUids];
  if (players.length % 2 !== 0) players.push(null);
  const n = players.length;
  const rounds: [string, string][][] = [];

  for (let r = 0; r < n - 1; r++) {
    const roundPairs: [string, string][] = [];
    for (let i = 0; i < n / 2; i++) {
      const a = players[i];
      const b = players[n - 1 - i];
      if (a !== null && b !== null) roundPairs.push([a, b]);
    }
    rounds.push(roundPairs);
    const last = players.pop() ?? null;
    players.splice(1, 0, last);
  }
  return rounds;
}
