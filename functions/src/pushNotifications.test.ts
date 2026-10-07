import assert from "node:assert/strict";
import {test} from "node:test";
import {shouldSendForType} from "./pushNotifications";

test("shouldSendForType sends when no preference doc exists", () => {
  assert.equal(shouldSendForType(undefined, "friend_request"), true);
});

test("shouldSendForType respects the allNotifications master switch", () => {
  assert.equal(shouldSendForType({allNotifications: false}, "friend_request"), false);
});

test("shouldSendForType defaults a missing category field to true", () => {
  assert.equal(shouldSendForType({}, "friend_request"), true);
});

test("shouldSendForType respects a false friendRequests category", () => {
  assert.equal(shouldSendForType({friendRequests: false}, "friend_request"), false);
});

test("shouldSendForType respects a false tournamentUpdates category", () => {
  assert.equal(shouldSendForType({tournamentUpdates: false}, "tournament_match"), false);
});

test("shouldSendForType respects a false gameInvitations category for a pvp challenge", () => {
  assert.equal(shouldSendForType({gameInvitations: false}, "pvp_challenge"), false);
});

test("shouldSendForType doesn't cross-apply an unrelated category's false flag", () => {
  assert.equal(shouldSendForType({friendRequests: false}, "tournament_match"), true);
});
