import assert from "node:assert/strict";
import {test} from "node:test";
import {roundRobinPairings} from "./weeklyTournament";

test("roundRobinPairings pairs every player with every other exactly once (even count)", () => {
  const players = ["p1", "p2", "p3", "p4"];
  const rounds = roundRobinPairings(players);

  const seen = new Set<string>();
  let total = 0;
  for (const round of rounds) {
    for (const [a, b] of round) {
      const key = [a, b].sort().join("-");
      assert.equal(seen.has(key), false, `pair ${key} scheduled twice`);
      seen.add(key);
      total++;
    }
  }
  assert.equal(total, 6); // C(4,2)
  assert.equal(rounds.length, 3); // n-1 rounds for even n
});

test("roundRobinPairings gives every player exactly one bye for an odd count", () => {
  const players = ["p1", "p2", "p3"];
  const rounds = roundRobinPairings(players);

  assert.equal(rounds.length, 3); // padded to 4 -> n-1 = 3 rounds
  const matchesPerPlayer: Record<string, number> = {};
  let total = 0;
  for (const round of rounds) {
    for (const [a, b] of round) {
      matchesPerPlayer[a] = (matchesPerPlayer[a] ?? 0) + 1;
      matchesPerPlayer[b] = (matchesPerPlayer[b] ?? 0) + 1;
      total++;
    }
  }
  assert.equal(total, 3); // C(3,2)
  for (const p of players) {
    assert.equal(matchesPerPlayer[p], 2, `${p} should play the other 2 exactly once`);
  }
});

test("roundRobinPairings handles the minimum case of 2 players", () => {
  const rounds = roundRobinPairings(["p1", "p2"]);
  assert.equal(rounds.length, 1);
  assert.deepEqual(rounds[0], [["p1", "p2"]]);
});
