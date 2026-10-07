# Android Build & Release Signing Guide

## 概要

このガイドでは、GoEn(碁縁) の Android ビルドと署名設定について説明します。

## ビルド環境

- **Flutter**: 3.47.2 (stable)
- **Java**: 17 (Temurin)
- **Gradle**: 8.x (Flutter bundled)
- **Application ID**: `com.yourwish.goen`

---

## ローカルビルド

### 前提条件

```bash
# Flutter インストール
flutter --version  # 3.47.2 以上

# Android SDK インストール
# minSdk: 21 (Android 5.0)
# targetSdk: 34 (Android 14)
```

### Debug APK ビルド

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK ビルド (署名なし・テスト用)

```bash
# Debug keystore で署名（開発用）
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Release AAB ビルド (Google Play 配信用)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 署名設定

### 自動署名（CI/CD）

CI では以下のフローで自動署名します：

1. **GitHub Secrets が設定されている場合** → 本番 keystore を使用
2. **なければ** → Debug keystore 自動検出
3. **どちらもなければ** → Gradle auto-generated signing

### 手動署名設定（本番環境）

#### Step 1: Release Keystore 生成

```bash
keytool -genkey -v \
  -keystore android/app/goen-release.keystore \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10950 \
  -alias goen-key \
  -storepass YOUR_KEYSTORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=GoEn Developer, OU=Petit Works, O=GoEn, L=Tokyo, ST=Tokyo, C=JP"
```

**パラメータ説明**:
- `keystore`: キーストアファイル名
- `keyalg`: RSA アルゴリズム
- `keysize`: 4096 ビット暗号化強度
- `validity`: 30 年間有効（10950 日）
- `alias`: キーの識別子
- `storepass`: キーストア パスワード（安全に保管）
- `keypass`: キー パスワード（storepass と同じ可能）

#### Step 2: GitHub Secrets に登録

リポジトリ設定 → Settings → Secrets and variables → Actions で以下を追加：

| Secret 名 | 値 | 例 |
|----------|-----|-----|
| `ANDROID_KEYSTORE_BASE64` | keystore ファイル (base64 エンコード) | `MIIKKAIBAzCC... (1行)` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore パスワード | `your_secure_pass_123` |
| `ANDROID_KEY_ALIAS` | キーの識別子 | `goen-key` |
| `ANDROID_KEY_PASSWORD` | キー パスワード | `your_secure_pass_123` |

**Keystore を Base64 エンコード:**

```bash
base64 -w0 android/app/goen-release.keystore > keystore.b64
# Windows の場合: certutil -encode goen-release.keystore keystore.b64
cat keystore.b64  # コピーして ANDROID_KEYSTORE_BASE64 に貼り付け
```

#### Step 3: ローカル gradle.properties で署名（開発環境）

`android/gradle.properties` に以下を追加（**本番キーストアの場合のみ**）:

```properties
ANDROID_KEYSTORE_PATH=app/goen-release.keystore
ANDROID_KEYSTORE_PASSWORD=YOUR_PASSWORD
ANDROID_KEY_ALIAS=goen-key
ANDROID_KEY_PASSWORD=YOUR_PASSWORD
```

**⚠️ 注意**: パスワードをリポジトリにコミットしないこと。

---

## CI/CD ビルド フロー

### GitHub Actions Workflow

`.github/workflows/android-build.yml` が以下を自動実行：

```
1. チェックアウト
2. Java 17 セットアップ
3. Flutter 3.47.2 セットアップ
4. 依存解決 (pub get)
5. コード解析 (analyze)
6. ユニットテスト (test) [非ブロッキング]
7. Debug APK ビルド
8. Release APK ビルド (署名設定から自動)
9. Release AAB ビルド (署名設定から自動)
10. 成果物アップロード (7 日間保持)
11. ビルドステータス要約
```

### トリガー条件

- `push` → main, develop ブランチ
- `pull_request` → main, develop へのマージリクエスト
- Manual trigger (workflow_dispatch)

### 成果物確認

GitHub Actions → Artifacts タブで以下が出力されます：

- **apk-artifacts** (7 日間)
  - `app-debug.apk`
  - `app-release.apk`
- **aab-artifact** (7 日間)
  - `app-release.aab`
- **build-logs** (7 日間)
  - `pub_get.log`
  - `analyze.log`
  - `test.log`
  - `build_apk_*.log`
  - `build_aab_*.log`

---

## トラブルシューティング

### ビルド失敗: keystore not found

**原因**: Release keystore が見つからない

**解決法**:
```bash
# 1. Debug keystore を確認
ls ~/.android/debug.keystore

# 2. または本番 keystore を指定
export ANDROID_KEYSTORE_PATH="android/app/goen-release.keystore"
export ANDROID_KEYSTORE_PASSWORD="your_password"
export ANDROID_KEY_ALIAS="goen-key"
export ANDROID_KEY_PASSWORD="your_password"
flutter build apk --release
```

### ビルド失敗: pub get error

**原因**: パッケージ依存解決失敗（通常は network timeout）

**解決法**:
```bash
flutter pub cache clean
flutter pub get
```

### APK サイズが大きい (50MB+)

**最適化**:
```bash
# サイズ最適化ビルド
flutter build apk --release -t lib/main.dart \
  --split-per-abi
```

---

## セキュリティ考慮事項

### Keystore セキュリティ

1. **ローカル開発用 keystore**
   - Debug keystore は Git にコミットしない (.gitignore に含める)
   - `android/app/*.keystore` をルールに追加済み

2. **本番 keystore**
   - 絶対に Git にコミットしない
   - GitHub Secrets として安全に管理
   - Base64 エンコードで Secrets に登録

3. **パスワード管理**
   - 強力な パスワード (16 字以上)
   - 定期的に Secrets をローテーション
   - チーム全員での共有は避ける

### リリース前チェックリスト

- [ ] `build.gradle.kts` で release signing が設定済み
- [ ] GitHub Secrets に keystore が登録済み
- [ ] CI ビルドが APK/AAB を成功出力
- [ ] `versionCode`/`versionName` を更新済み (pubspec.yaml)
- [ ] PlayStore コンソールで リリース前設定完了
- [ ] 契約・法律文書の確認済み

---

## 参考資料

- [Flutter Official: Build and release an Android app](https://flutter.dev/to/review-gradle-config)
- [Android: Sign Your App](https://developer.android.com/studio/publish/app-signing)
- [Gradle: Android Signing](https://docs.gradle.org/current/userguide/signing_plugin.html)
