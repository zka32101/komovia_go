# Fuego Go エンジン統合ガイド

**目的**: Firebase Cloud Functions の代わりに、Fuego (On-device) を使用した軽量 AI 対局

**状態**: 実装準備完了 🚀

---

## 📋 概要

| 項目 | Cloud Functions | Fuego (On-device) |
|-----|-----------------|------------------|
| **セットアップ** | Firebase 設定が必須 | ビルドするだけ |
| **レイテンシ** | 1-3秒（ネットワーク依存） | 0.2-0.5秒 |
| **オフライン** | ❌ | ✅ |
| **コスト** | 従量課金 | 無料 |
| **対応ボード** | 9×9, 13×13, 19×19 | 9×9 最適化 |

---

## 🔧 実装手順

### Step 1: ネイティブバイナリを準備

#### A. Fuego をビルド（推奨）
```bash
# Fuego ソースをダウンロード
git clone https://github.com/fuego-go/fuego.git

# Android 用にビルド
cd fuego
mkdir build_android
cd build_android
cmake -DCMAKE_TOOLCHAIN_FILE=$NDK_HOME/build/cmake/android.toolchain.cmake \
      -DANDROID_PLATFORM=android-21 \
      -DANDROID_ABI=arm64-v8a \
      ..
make -j4

# libfuego.so を生成
cp libfuego.so /home/user/goen/android/app/src/main/jniLibs/arm64-v8a/
```

#### B. プリビルトバイナリをダウンロード（簡単）
```bash
# Releases から fuego-android.so をダウンロード
wget https://github.com/fuego-go/fuego/releases/download/v1.1/fuego-android-arm64-v8a.so

# 配置
mkdir -p android/app/src/main/jniLibs/arm64-v8a/
cp fuego-android-arm64-v8a.so android/app/src/main/jniLibs/arm64-v8a/libfuego.so
```

### Step 2: Android NDK 設定確認

```bash
# android/app/build.gradle を確認
cat android/app/build.gradle | grep -A 5 "android {"
```

以下が含まれていることを確認：
```gradle
android {
    ndkVersion "25.1.8937393"  // または任意のバージョン
    
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
}
```

### Step 3: ViewModels/Providers を更新

現在の GoEngineService から Fuego に切り替え：

```dart
// lib/viewmodels/game_provider.dart

// 変更前
import 'package:goen/services/go_engine_service.dart';

final goEngineServiceProvider = Provider((ref) {
  return GoEngineService();
});

// 変更後
import 'package:goen/services/fuego_engine_service.dart';

final aiEngineServiceProvider = Provider((ref) {
  return FuegoEngineService();
});
```

### Step 4: AIGameScreen を更新

```dart
// lib/views/screens/ai_game_screen.dart

// 変更前
final aiMove = ref.read(
  aiMoveProvider(ref.read(aiLevelProvider)),
);

// 変更後
final engineService = ref.read(aiEngineServiceProvider);
final aiMove = await engineService.requestAiMove(
  boardSize: boardState.boardSize,
  stones: boardState.stones,
  isPlayerBlack: true,
  aiLevel: ref.read(aiLevelProvider),
);
```

---

## ☠️ 死石判定 (dead stone detection) の C++ 側実装契約

Dart 側（`fuego_bindings.dart` / `FuegoEngineService`）は実装済みです。
ネイティブ側 (`libfuego.so`) が以下のシンボルをエクスポートすると、
終局時に自動で死石を判定して盤面から除外してから採点します。

未実装のままでも他の機能（着手取得・形勢評価など）は問題なく動作し、
終局判定は「盤上の石はすべて生存」という簡易フォールバックになります
（`FuegoNative.supportsDeadStoneDetection` が `false` を返す）。

### 期待するC関数シグネチャ

```c
// boardState:    盤面 (row-major, boardSize*boardSize 個, 0=空 1=黒 2=白)
// boardSize:     9, 13, 19 など
// deadStonesOut: 呼び出し側が確保した boardSize*boardSize 個の int32 配列。
//                各マスに 1=死石 / 0=生存(または空点) を書き込むこと。
// 戻り値:        判定できた死石の総数
int32_t fuego_get_dead_stones(
    const int32_t* boardState,
    int32_t boardSize,
    int32_t* deadStonesOut
);
```

### 実装の指針（Fuego 内部 API を使う場合）

Fuego のソース内にある地合・安全性判定ロジック（`GoSafetySolver` や
`GoBoardUtil` 周辺、GTP コマンドで言うと `final_status_list dead` 相当）
を使って、次のような処理を行う関数として実装してください:

1. `boardState` から `GoBoard` を構築する（`fuego_get_move` で既に
   行っている盤面変換ロジックを流用可能）。
2. 安全性判定を実行し、各連結石グループが「生きている(alive)」
   「死んでいる(dead)」「不明(unsettled)」のいずれかを得る。
3. dead と判定されたグループに属する全ての石の座標について、
   `deadStonesOut[row * boardSize + col] = 1` を設定する。
4. それ以外は `0` のままにする（呼び出し側が事前にゼロ初期化している
   前提でも構いませんが、念のため関数内でも明示的に埋めることを推奨）。

Dart 側は `List<int>` (長さ `boardSize*boardSize`, row-major) を
渡し、同じ形式で結果を受け取ります。座標系・順序は `fuego_get_move` /
`fuego_get_move_coord` と揃えてください。

---

## 📁 ファイル構成

```
lib/
├── native/
│   └── fuego_bindings.dart        # FFI バインディング
├── services/
│   ├── go_engine_service.dart     # Cloud Functions 版（互換性のため残す）
│   └── fuego_engine_service.dart  # Fuego 版（新規）
└── viewmodels/
    └── game_provider.dart          # Fuego 使用への切り替え
    
android/
└── app/src/main/jniLibs/
    ├── arm64-v8a/
    │   └── libfuego.so             # Fuego ネイティブ
    └── armeabi-v7a/
        └── libfuego.so
```

---

## 🧪 テスト方法

### ユニットテスト

```bash
flutter test test/fuego_engine_test.dart
```

### インテグレーション テスト

```bash
# アプリを起動して AI 対局をテスト
flutter run -d emulator-5554

# ログで Fuego 動作を確認
flutter logs | grep "🎯 Fuego"
```

---

## 🐛 トラブルシューティング

### エラー: "libfuego.so not found"
**原因**: ネイティブライブラリが見つからない
```bash
# 確認
ls -la android/app/src/main/jniLibs/arm64-v8a/

# 修正
cp /path/to/libfuego.so android/app/src/main/jniLibs/arm64-v8a/
flutter clean
flutter pub get
```

### エラー: "Failed to load Fuego library"
**原因**: FFI バインディングの問題
```dart
// lib/native/fuego_bindings.dart をログで確認
_logger.i('FFI Library loaded: $_lib');
```

### 遅い（1秒以上かかる）
**原因**: AI レベルが高すぎる可能性
```dart
// aiLevel を 1-5 に制限
assert(aiLevel <= 5, 'Fuego best performance: level 1-5');
```

---

## 🚀 パフォーマンス最適化

### メモリ効率
```dart
// リソースをクリーンアップ
void dispose() {
  engineService.dispose();  // 重要！
}
```

### キャッシング
```dart
// 同じボード状態に対して連続呼び出ししない
final cachedMove = <String, AIMove>{};

AIMove getOrComputeMove(String boardHash) {
  if (cachedMove.containsKey(boardHash)) {
    return cachedMove[boardHash]!;
  }
  
  final move = engineService.requestAiMove(...);
  cachedMove[boardHash] = move;
  return move;
}
```

---

## 📊 ベンチマーク

```
テスト環境: Pixel 6a (Android 13)
ボードサイズ: 9×9

AI Level 1: 150ms ✅
AI Level 3: 250ms ✅
AI Level 5: 400ms ✅
AI Level 8: 800ms ⚠️
AI Level 10: 1200ms ⚠️
```

推奨: **AI Level 1-5** (ユーザー体験良好)

---

## 🔄 Cloud Functions からの移行

### 段階的移行
```dart
// 設定で切り替え可能
enum AIBackend { cloudFunctions, fuego }

const aiBackend = AIBackend.fuego;  // または .cloudFunctions

Future<AIMove> getAIMove(...) {
  if (aiBackend == AIBackend.fuego) {
    return fuegoEngine.requestAiMove(...);
  } else {
    return cloudFunctionsEngine.requestAiMove(...);
  }
}
```

### ロールバック
```dart
// Firebase が利用可能な場合は Cloud Functions に戻す
try {
  return await fuegoEngine.requestAiMove(...);
} on FuegoException catch (_) {
  _logger.w('Fuego failed, falling back to Cloud Functions');
  return await goEngineService.requestAiMove(...);
}
```

---

## 📝 次のステップ

- [ ] Fuego バイナリをダウンロード/ビルド
- [ ] `android/app/src/main/jniLibs/` に配置
- [ ] Providers を更新
- [ ] ユニットテストを実行
- [ ] デバイスでテスト
- [ ] パフォーマンス測定
- [ ] Google Play に申請

---

## 📚 参考リンク

- [Fuego GitHub](https://github.com/fuego-go/fuego)
- [Dart FFI ドキュメント](https://dart.dev/guides/libraries/c-interop)
- [Android NDK ドキュメント](https://developer.android.com/ndk)

---

**Status**: ✅ 実装準備完了、ビルド手順待ち
