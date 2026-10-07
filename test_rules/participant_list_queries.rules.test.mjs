// 参加者2フィールドのルール(isParticipant([a,b]))が、クエリ where(a==自分) / where(b==自分) で通るかを検査する。
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, setDoc, collection, query, where, getDocs } from 'firebase/firestore';
const env = await initializeTestEnvironment({ projectId:'t', firestore:{ rules: readFileSync(process.argv[2],'utf8'), host:'127.0.0.1', port:8080 }});
const CASES = [
  ['match_results','player1Uid','player2Uid'], ['pvp_games','blackUid','whiteUid'],
  ['correspondenceGames','uid','opponentUid'], ['game_sessions','blackPlayerId','whitePlayerId'],
  ['games','blackPlayerId','whitePlayerId'], ['gameInvitations','fromUid','toUid'], ['game_invitations','fromUserId','toUserId'],
  ['sponsorships','sponsorUserId','sponsoredUserId'],
];
await env.withSecurityRulesDisabled(async ctx=>{ const d=ctx.firestore();
  for (const [c,f1,f2] of CASES) await setDoc(doc(d,`${c}/x`),{[f1]:'A',[f2]:'B'}); });
const a=env.authenticatedContext('A').firestore(), b=env.authenticatedContext('B').firestore(), x=env.authenticatedContext('C').firestore();
let ok=0,ng=0; const t=async(n,p)=>{try{await p;ok++;console.log('PASS',n)}catch(e){ng++;console.log('FAIL',n,e.message.slice(0,70))}};
for (const [c,f1,f2] of CASES) {
  await t(`${c}: A list where ${f1}==A`, assertSucceeds(getDocs(query(collection(a,c), where(f1,'==','A')))));
  await t(`${c}: B list where ${f2}==B`, assertSucceeds(getDocs(query(collection(b,c), where(f2,'==','B')))));
  if (c !== 'pvp_games') // pvp_games は観戦のため誰でも読める設計
  await t(`${c}: C cannot list A's`, assertFails(getDocs(query(collection(x,c), where(f1,'==','A')))));
}
console.log(`${ok} pass, ${ng} fail`); await env.cleanup(); process.exit(ng?1:0);
