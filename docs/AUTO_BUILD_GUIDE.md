# GoEn 自動ビルド・デプロイガイド

**Status**: ✅ 実装完了  
**Date**: 2026-09-10  
**Pipeline**: GitHub Actions + Firebase Distribution

## 概要

このガイドは GoEn プロジェクトの完全自動化ビルド・デプロイパイプラインの設定と運用方法を説明します。

## パイプラインアーキテクチャ

```
Trigger (workflow_dispatch)
    ↓
[Build Job]
  - Java & Flutter セットアップ
  - 依存関係インストール
  - コード解析（flutter analyze）
  - ビルドバージョン更新
  - APK/AAB/iOS ビルド
  - アーティファクト保存
    ↓
[Test Job] (並行実行)
  - Unit テスト実行
  - Widget テスト実行
  - Coverage レポート生成
    ↓
[Quality Gate]
  - ビルド成功確認
  - アーティファクト検証
  - Slack 通知
```

## セットアップ手順

### 1. GitHub Actions ワークフロー設定

`.github/workflows/deploy.yml` は既に実装済みです。

**含まれるジョブ:**
- `build`: Flutter APK/AAB/iOS ビルド
- `test`: ユニット・ウィジェットテスト実行
- `quality_gate`: アーティファクト検証と通知

### 2. Branch Protection 設定

GitHub リポジトリ設定で以下を実施：

```
Settings → Branches → main
  ✓ Require status checks to pass before merging
    - build (選択)
    - test (選択)
    - quality_gate (選択)
  ✓ Require branches to be up to date
  ✓ Require code reviews before merging (1)
```

### 3. Secrets 設定

GitHub リポジトリの Secrets に以下を設定：

```
Settings → Secrets and variables → Actions
  SLACK_WEBHOOK_URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
  FIREBASE_DISTRIBUTION_KEY: (Firebase Distribution API key)
  PLAY_STORE_KEY: (Google Play API key - 将来用)
```

### 4. バージョン管理

`pubspec.yaml` の version フィールド：

```yaml
# フォーマット: {MAJOR}.{MINOR}.{PATCH}+{BUILD_NUMBER}
version: 1.0.0+1

# ビルド実行時に自動更新:
# 1.0.0+1 → 1.0.0+1234 (GitHub run_number)
```

## トリガー方法

### 方法 1: Web UI トリガー

GitHub リポジトリ:
```
Actions → "Automated Build & Deploy" 
  → Run workflow
    - Build type: apk / aab / ios / all
    → Run
```

### 方法 2: GitHub CLI トリガー

```bash
gh workflow run deploy.yml \
  -f build_type=apk \
  --ref main
```

### 方法 3: cURL トリガー

```bash
curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/zka32101/goen/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"main","inputs":{"build_type":"apk"}}'
```

### 方法 4: REST API (Node.js)

```javascript
const { Octokit } = require("@octokit/rest");
const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
});

await octokit.actions.createWorkflowDispatch({
  owner: "zka32101",
  repo: "goen",
  workflow_id: "deploy.yml",
  ref: "main",
  inputs: {
    build_type: "apk"
  }
});
```

## ビルド成果物

### 保存先

GitHub Actions Artifacts:
- `goen-apk-{run_number}`: Android APK
- `goen-aab-{run_number}`: Android App Bundle
- `goen-ios-{run_number}`: iOS IPA

**保持期限**: 30日

### ダウンロード

```bash
# Web UI から
Actions → Build #123 → Artifacts
  → goen-apk-123 をダウンロード

# GitHub CLI から
gh run download {run_id} \
  -n goen-apk-{run_number} \
  -D downloads/
```

## テストカバレッジ

自動テスト実行:

1. **Unit Tests**
   - Services, Models, Providers
   - Coverage: lib/ ディレクトリ

2. **Widget Tests**
   - Screens, Widgets
   - Phase 134 テストスイート統合

3. **Coverage Report**
   - Codecov に自動アップロード
   - PR に コメント追加

## CI/CD フロー

```
Push to main
    ↓
workflow_dispatch トリガー
    ↓
[並行実行]
├─ Build (15-20 min)
└─ Test (5-10 min)
    ↓
Quality Gate
    ↓
Release 作成
    ↓
Slack 通知
    ↓
✅ デプロイ完了
```

## トラブルシューティング

### ビルド失敗: "Flutter SDK not found"

```bash
# 解決策: アクション更新
- uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.16.x'
```

### APK ビルドエラー: "Java version mismatch"

```bash
# 解決策: Java バージョン指定
- uses: actions/setup-java@v3
  with:
    distribution: 'temurin'
    java-version: '11'
```

### テスト失敗: "Coverage file not found"

```bash
# 解決策: coverage オプション追加
flutter test --coverage test/
```

### Slack 通知が来ない

```bash
# 確認項目:
1. SLACK_WEBHOOK_URL が設定されているか
2. Webhook URL が有効か
3. Slack ワークスペースのアクセス権
```

## ベストプラクティス

### 1. 定期ビルド

毎週金曜日の夜間にビルド実行:

```yaml
schedule:
  - cron: '0 22 * * 5'  # 毎週金曜 22:00 UTC
```

### 2. セマンティックバージョニング

```
{MAJOR}.{MINOR}.{PATCH}+{BUILD_NUMBER}

例:
1.0.0+100  - 初期リリース
1.0.1+101  - バグ修正
1.1.0+105  - 新機能追加
2.0.0+150  - メジャーアップデート
```

### 3. リリースノート自動生成

```bash
# コミット履歴から生成
git log --oneline v1.0.0..HEAD
```

## Firebase Distribution 統合 (将来実装)

```yaml
- name: Distribute via Firebase
  uses: ChickenTIts/firebase-app-distribution-action@v1
  with:
    serviceCredentialsJson: ${{ secrets.FIREBASE_CREDENTIALS }}
    file: build/app/outputs/flutter-apk/app-release.apk
    groups: testers
```

## 監視とメトリクス

### GitHub Actions ダッシュボード

```
Actions → deploy.yml → All workflows
  - Total runs
  - Success rate
  - Average duration
  - Conclusion breakdown
```

### アーティファクト管理

```
Settings → Actions → Artifacts and logs
  - Artifact retention: 30日
  - Log retention: 90日
```

## 次のステップ

- [ ] Firebase Distribution 統合
- [ ] Play Store 自動デプロイ
- [ ] TestFlight (iOS) 統合
- [ ] Sentry エラートラッキング統合
- [ ] Performance monitoring 統合

## サポート

問題が発生した場合：

1. GitHub Actions ログを確認
2. `flutter doctor` で環境確認
3. Issue を作成（エラーログ含む）

---

**最終更新**: 2026-09-10  
**パイプラインステータス**: ✅ 実装完了・テスト中  
**次のフェーズ**: Phase 135 テスト実装
