/**
 * Minimal parser for this app's own real move-order SGF dialect
 * (see lib/utils/sgf_parser.dart's generateSgfFromMoves): `;B[xx]`/`;W[xx]`
 * nodes with two-character coordinates (a-z, then A-Z for boards larger
 * than 26), in play order. `;B[]`/`;W[]` (empty coordinates) is a pass.
 *
 * This is intentionally the same encoding the Flutter app already writes
 * — not full SGF — so a client-generated sgfData string round-trips
 * without any conversion on either side.
 */

export interface SgfMove {
  moveNumber: number;
  row: number;
  col: number;
  color: "black" | "white";
  isPass: boolean;
}

function sgfCharToCoord(ch: string): number {
  const code = ch.charCodeAt(0);
  if (code >= 97 && code <= 122) return code - 97; // a-z
  return 26 + (code - 65); // A-Z
}

export function parseSgfBoardSize(sgf: string): number {
  const match = /SZ\[(\d+)\]/.exec(sgf);
  return match ? parseInt(match[1], 10) : 19;
}

export function parseSgfMoves(sgf: string): SgfMove[] {
  const moves: SgfMove[] = [];
  const re = /;([BW])\[([a-zA-Z]{0,2})\]/g;
  let match: RegExpExecArray | null;
  let moveNumber = 0;
  while ((match = re.exec(sgf)) !== null) {
    moveNumber++;
    const color: "black" | "white" = match[1] === "B" ? "black" : "white";
    const coord = match[2];
    if (!coord) {
      moves.push({moveNumber, row: -1, col: -1, color, isPass: true});
      continue;
    }
    const col = sgfCharToCoord(coord[0]);
    const row = sgfCharToCoord(coord[1]);
    moves.push({moveNumber, row, col, color, isPass: false});
  }
  return moves;
}

/** Renders a move list back into a short, human-readable move log for the
 * LLM prompt (e.g. "1. B(黒) at (row 3, col 4)"), 1-indexed to match how
 * the app numbers moves elsewhere (GameHistoryScreen's move chips). */
export function movesToPromptText(moves: SgfMove[]): string {
  return moves
    .map((m) => {
      const label = m.color === "black" ? "黒" : "白";
      if (m.isPass) return `${m.moveNumber}. ${label} パス`;
      return `${m.moveNumber}. ${label} (row=${m.row}, col=${m.col})`;
    })
    .join("\n");
}
