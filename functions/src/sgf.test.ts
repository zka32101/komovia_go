import assert from "node:assert/strict";
import {test} from "node:test";
import {parseSgfBoardSize, parseSgfMoves} from "./sgf";

test("parseSgfBoardSize reads SZ[n]", () => {
  assert.equal(parseSgfBoardSize("(;GM[1]FF[4]SZ[9];B[ee])"), 9);
  assert.equal(parseSgfBoardSize("(;GM[1]FF[4];B[ee])"), 19); // default
});

test("parseSgfMoves reads moves in order with 0-indexed row/col", () => {
  // 'e' = index 4. This app's dialect writes ;COLOR[col][row] as two
  // consecutive characters (see generateSgfFromMoves in
  // lib/utils/sgf_parser.dart), same as real Go SGF coordinate order.
  const moves = parseSgfMoves("(;GM[1]FF[4]SZ[9];B[ee];W[dc];B[])");
  assert.equal(moves.length, 3);

  assert.equal(moves[0].moveNumber, 1);
  assert.equal(moves[0].color, "black");
  assert.equal(moves[0].col, 4); // 'e'
  assert.equal(moves[0].row, 4); // 'e'
  assert.equal(moves[0].isPass, false);

  assert.equal(moves[1].moveNumber, 2);
  assert.equal(moves[1].color, "white");
  assert.equal(moves[1].col, 3); // 'd'
  assert.equal(moves[1].row, 2); // 'c'

  assert.equal(moves[2].moveNumber, 3);
  assert.equal(moves[2].color, "black");
  assert.equal(moves[2].isPass, true);
  assert.equal(moves[2].row, -1);
  assert.equal(moves[2].col, -1);
});

test("parseSgfMoves returns an empty list for a snapshot-only sgf (no moves)", () => {
  // BoardState.toSgf()'s dialect uses comma-separated coordinates
  // (";B[col,row]"), which this real-move-order parser must NOT match —
  // confirms the two dialects can't be silently confused server-side.
  const moves = parseSgfMoves("(;GM[1]SZ[9];B[a,a];W[b,b])");
  assert.equal(moves.length, 0);
});
