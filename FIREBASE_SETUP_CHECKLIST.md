# Firebase 設定チェックリスト

**目的**: google_app_id 未設定エラーを解決し、Cloud Functions 連携を有効化

---

## 📋 確認・再設定手順

### Step 1: Firebase Console にアクセス
- [ ] https://console.firebase.google.com/ を開く
- [ ] Google アカウントでログイン
- [ ] プロジェクト **goen-project** を選択

### Step 2: プロジェクト設定を確認
1. 左メニュー → **プロジェクト設定**
2. **アプリ** タブを確認
3. 以下のアプリが表示されていることを確認：
   - [ ] Android アプリ (com.example.goen)
   - [ ] iOS アプリ (com.example.goen)

### Step 3: Android 設定の再確認

#### 3-1. Google Services JSON をダウンロード
```
プロジェクト設定 → アプリ → Android アプリ
↓
"google-services.json をダウンロード" ボタン
```

- [ ] ダウンロード完了
- [ ] ファイルを `android/app/` に配置

#### 3-2. JSON ファイルの内容を確認
```bash
cat android/app/google-services.json | jq '.client[0].client_info'
```

確認すべき値:
- [ ] `package_name`: `com.example.goen`
- [ ] `mobilesdk_app_id`: `1:XXXXXXXXX:android:XXXXX` (この値が google_app_id)
- [ ] `api_key`: (有効な API キーが存在)
- [ ] `sender_id`: (値が存在)

---

## 🔐 Firebase コンソール設定確認

### Authentication (認証)
- [ ] プロジェクト設定 → **Authentication**
- [ ] **Anonymous サインイン** が有効化されていることを確認

### Firestore Database
- [ ] プロジェクト設定 → **Firestore Database**
- [ ] データベースが作成されていることを確認
- [ ] ルール: **本番環境モード** または カスタムルール

### Cloud Functions
- [ ] プロジェクト設定 → **Cloud Functions**
- [ ] 以下の関数がデプロイされていることを確認：
  - [ ] `requestAiMove` (リージョン: us-central1)
  - [ ] `judgeGameEnd` (リージョン: us-central1)

---

## 🔧 ローカル環境での再設定

### Step 1: FlutterFire CLI を実行
```bash
cd /home/user/goen

# FlutterFire CLI をインストール（未インストールの場合）
dart pub global activate flutterfire_cli

# Firebase 設定を再生成
flutterfire configure
```

### Step 2: プロンプトに従って選択
```
? Which Firebase project do you want to use?
→ goen-project を選択

? Which platforms should be configured?
→ android, ios を選択
```

### Step 3: 生成されたファイルを確認
```bash
# firebase_options.dart が更新されたことを確認
git diff lib/firebase_options.dart

# 設定値が正しいことを確認
grep -E "apiKey|appId|messagingSenderId" lib/firebase_options.dart
```

---

## ✅ 検証手順

### Android ビルド検証
```bash
# 依存関係を更新
flutter clean
rm pubspec.lock
flutter pub get

# Android ビルドをテスト
flutter build apk --debug
```

### Firebase 接続確認
```bash
# アプリを起動してログを確認
flutter run -d <device_id>
flutter logs
```

ログに以下のメッセージが表示されることを確認：
```
✓ Firebase initialization successful
✓ Cloud Functions callable initialized
```

---

## 🚨 トラブルシューティング

### エラー: "google_app_id not found"
**原因**: firebase_options.dart にプレースホルダー値が残っている
```dart
// ❌ 間違い
appId: '1:000000000000:android:0000000000000000000000',

// ✅ 正しい例
appId: '1:123456789:android:abcdef1234567890abcd',
```
**対応**: FlutterFire CLI を再実行（Step 1 参照）

### エラー: "Cloud Functions endpoint not configured"
**原因**: Cloud Functions がデプロイされていない
**対応**: Firebase Console で Cloud Functions をデプロイ

### ビルドエラー: "Failed to resolve google-services-plugin"
**原因**: google-services.json が見つからない
**対応**: android/app/ に google-services.json を配置

---

## 📝 設定値メモ

実際の値を以下に記録してください（リポジトリにプッシュしないこと）:

```
Project ID: goen-project
Android App ID: ___________________________
Android API Key: __________________________
iOS App ID: ______________________________
Web API Key: ______________________________
```

---

## 🔄 次のステップ

設定完了後:
1. [ ] `flutter pub get` を実行
2. [ ] `flutter run` でアプリ起動テスト
3. [ ] Firebase logs を確認
4. [ ] AI move request をテスト

---

**Last Updated**: 2026-09-17  
**Status**: ⏳ Firebase 設定待ち
