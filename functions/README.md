# GoEn Cloud Functions

- `generateGameAnalysis` — 対局終了後の「AIで振り返る」機能（`GameResultScreen`）
  が呼ぶ、実際にアプリから呼ばれる唯一の callable Cloud Function。Anthropic API
  (Claude) を使って対局の解説を生成し、`GameAnalysis`
  （`lib/services/ai_explanation_service.dart`）と同じ JSON 形式で返す。
- `weeklyTournamentScheduler` — 毎週トーナメントを自動開催する scheduled
  function（`src/weeklyTournament.ts`）。callable ではなく、Cloud Scheduler
  から定期的に呼ばれる。詳細は下の「週刊トーナメントの自動開催」を参照。
- `sendPushOnNotificationCreated` — `notifications/{uid}/messages/{id}` が
  作成されたときに実際の FCM プッシュを送信する Firestore トリガー
  （`src/pushNotifications.ts`）。詳細は下の「プッシュ通知（FCM）」を参照。

このリポジトリにはまだ `functions/` の実デプロイ実績がない（このセッションで
初めて作成した）。以下は実際にデプロイする開発者向けの手順。

## 前提

- Node.js 20（`package.json` の `engines.node` と合わせる。ローカルの node
  バージョンが違っても、実際にデプロイされる Cloud Functions のランタイムは
  Node 20 になる）
- Firebase CLI (`npm install -g firebase-tools`)、対象プロジェクトへの
  デプロイ権限
- Anthropic API キー（[console.anthropic.com](https://console.anthropic.com/)）
  ※ `generateGameAnalysis` のみ必要。`weeklyTournamentScheduler` は不要
- Blaze（従量課金）プラン。scheduled function は内部的に Cloud Scheduler /
  Cloud Pub/Sub を使うため、無料の Spark プランではデプロイできない
- Cloud Scheduler API の有効化（初回デプロイ時に Firebase CLI が案内する）

## セットアップ

```bash
cd functions
npm install
```

## Anthropic API キーの設定（Secret Manager 経由）

コードは `defineSecret("ANTHROPIC_API_KEY")` で読み込む。`.env` ファイルや
`firebase functions:config:set`（レガシー方式）ではなく、Secret Manager に
保存する:

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
# プロンプトが出たらAPIキーを貼り付ける
```

## ローカルでの動作確認（エミュレータ）

```bash
npm run build
firebase emulators:start --only functions
```

エミュレータ実行時も Secret の値を読ませるには `.secret.local` に
`ANTHROPIC_API_KEY=sk-ant-...` を1行書いておく（`.gitignore` 済み、
絶対にコミットしないこと）。

## デプロイ

```bash
firebase deploy --only functions
```

初回デプロイ時、Firebase が Cloud Functions / Cloud Build / Artifact
Registry など必要な API の有効化を求めてくることがある（コンソールの案内に
従う）。

## 動作確認

デプロイ後、アプリの `GameResultScreen` で対局を1局保存し「AIで振り返る」を
押して解説が返ってくることを確認する。失敗した場合は:

```bash
firebase functions:log
```

でログを確認する（`generateGameAnalysis` 内の `logger.error` 呼び出しが
Anthropic API 呼び出し失敗時とレスポンス形式不正時の両方をログに残す）。

## 週刊トーナメントの自動開催

`weeklyTournamentScheduler`（`src/weeklyTournament.ts`）は毎週月曜 00:00
（Asia/Tokyo）に自動実行され、2つのことを行う:

1. 前週分の自動トーナメント（`isAutoWeekly: true`）がまだ `status: 'upcoming'`
   （＝誰も手動で開始していない）なら、参加者からブラケット/総当たり戦の
   全対戦カードを生成して `status: 'active'` にする（`TournamentService`
   の `startTournament` と同じロジックを TypeScript に移植したもの）。
   参加者が2人未満なら開始せず `status: 'cancelled'` にする
   （アプリ側は「中止（参加者不足）」と表示する）。
2. 今週分の新しいトーナメント（`status: 'upcoming'`, `isAutoWeekly: true`,
   参加受付期間7日間）を新規作成する。

対局開始後の進行（各対局の結果反映・次ラウンド生成・優勝確定）は、既存の
`TournamentService`（Flutter アプリ側、`lib/services/tournament_service.dart`）
がプレイヤーの対局完了時に行う処理そのままで、この Cloud Function が
重複して処理することはない。

デフォルト設定（`src/weeklyTournament.ts` 冒頭の定数で変更可能）:
`format: single_elimination` / `boardSize: 19` / `maxParticipants: 16`。

デプロイ:

```bash
firebase deploy --only functions:weeklyTournamentScheduler
```

スケジュールを変更したい場合は `onSchedule({schedule: "0 0 * * 1", ...})`
の cron 式（`0 0 * * 1` = 毎週月曜0時）と `timeZone` を編集して再デプロイする。

## プッシュ通知（FCM）

`sendPushOnNotificationCreated`（`src/pushNotifications.ts`）は
`notifications/{uid}/messages/{messageId}` ドキュメントが作成されるたびに
発火する Firestore トリガー。このドキュメント自体は以前から
`NotificationService.sendNotification`（`lib/services/notification_service.dart`）
がフレンド申請・PvP対戦申請・トーナメント試合開始などのたびに書き込んでいた
（アプリ内通知一覧の表示用）が、実際にプッシュとして届ける仕組みが無く、
アプリを閉じている間は気づけなかった。この function がその欠けていた配信
部分を担う。

動作:

1. `notifications/{uid}/notificationPreferences/settings` を読み、
   `allNotifications: false` なら送信しない。通知の `type`
   （`friend_request`/`tournament_match`/`pvp_challenge` など）に応じて
   `friendRequests`/`tournamentUpdates`/`achievements`/`gameInvitations`
   の該当カテゴリが `false` ならそれも送信しない（設定ドキュメントが無い
   場合やフィールドが無い場合はデフォルトで送信 — オプトアウト方式）。
2. `notifications/{uid}/fcmTokens/*` に登録されている全トークンへ
   `admin.messaging().sendEachForMulticast` で送信。
3. プラットフォームが「無効」と報告したトークン
   （`messaging/invalid-registration-token`/
   `messaging/registration-token-not-registered`）は自動的に削除する。

クライアント側（`lib/viewmodels/notification_provider.dart` の
`fcmSyncProvider`）はサインイン時・トークンリフレッシュ時に実トークンを
`registerFcmToken` 経由で登録し、フォアグラウンド中にプッシュを受信したら
（システムは自動でバナー表示しないため）アプリ内通知一覧/未読件数を
再取得する。バックグラウンド/終了時のプッシュ表示は
`firebase_messaging` プラグイン自体が処理する（`lib/main.dart` の
`FirebaseMessaging.onBackgroundMessage`）。

デプロイ:

```bash
firebase deploy --only functions:sendPushOnNotificationCreated
```

## 既知の制約 / 未実装

- `lib/services/ai_explanation_service.dart` は `generateMoveExplanation`
  （1手ごとのその場解説）と `generateQuickMoveComment`（対局中のクイック
  コメント）という2つの Cloud Function 呼び出しも宣言しているが、アプリの
  どの画面からも呼ばれていない（`GameResultScreen` が使うのは
  `generateGameAnalysis` のみ）。呼び出し元が実際にできてから実装する。
- 1局あたり最大 `MAX_MOVES_TO_EXPLAIN`（10手）までしか解説を生成しない
  （19路盤で200手を超える対局を全て解説すると応答サイズ・レイテンシ・
  コストが膨らみすぎるため）。AIに「特に重要だった局面」を選ばせている。
- レシート検証や課金プランによる呼び出し制限は無い（`request.auth` の
  有無しかチェックしていない）。将来的にサブスク会員限定機能にする場合は
  ここに `users/{uid}.subscriptionActive` のチェックを足す必要がある。
- `weeklyTournamentScheduler` は `round_robin`/`single_elimination` のみ
  対応（`swiss` は `TournamentService.startTournament` と同様に未対応）。
  優勝の同数タイブレークもuid昇順の簡易ロジックのまま。参加者を自動で
  誘う仕組みは無く、あくまで「毎週決まった枠を用意する」だけ — 実際に
  参加するにはユーザーがアプリの `TournamentScreen` から能動的に
  参加登録する必要がある。
- `sendPushOnNotificationCreated`: 同じユーザーが複数端末でトークンを
  登録していれば全端末に送る（重複排除は無い — 意図的な仕様）。iOS で
  実際にプッシュを受信するには、Firebase コンソール側で APNs 認証キー/
  証明書を別途設定する必要がある（このリポジトリのコードだけでは完結
  しない、Apple Developer 側の設定）。サインアウト時にそのデバイスの
  トークンを `fcmTokens` から削除する処理は無く、無効化されたトークンは
  実際に送信に失敗した時点で（`messaging/registration-token-not-registered`
  等を検出して）遅延削除されるのみ。
