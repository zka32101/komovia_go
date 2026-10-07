#!/bin/bash

# Firebase 設定検証スクリプト
# 用途: google_app_id と Cloud Functions の設定を確認

set -e

echo "🔍 Firebase 設定検証を開始します..."
echo

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0

# Helper functions
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 が見つかりました"
        return 0
    else
        echo -e "${RED}✗${NC} $1 が見つかりません"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_value() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $3"
        return 0
    else
        echo -e "${RED}✗${NC} $3"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# 1. Firebase options.dart 確認
echo -e "${BLUE}[1/3] Firebase オプションファイルの確認${NC}"
check_file "lib/firebase_options.dart"
echo

# 2. Google Services JSON 確認
echo -e "${BLUE}[2/3] Google Services JSON の確認${NC}"
if check_file "android/app/google-services.json"; then
    echo "  内容を解析中..."

    if command -v jq &> /dev/null; then
        # jq がインストールされている場合
        PACKAGE_NAME=$(jq -r '.client[0].client_info.package_name' android/app/google-services.json 2>/dev/null || echo "")
        APP_ID=$(jq -r '.client[0].client_info.mobilesdk_app_id' android/app/google-services.json 2>/dev/null || echo "")
        API_KEY=$(jq -r '.client[0].api_key[0].current_key' android/app/google-services.json 2>/dev/null || echo "")

        echo "  • Package Name: ${PACKAGE_NAME:0:30}..."
        echo "  • App ID (google_app_id): ${APP_ID:0:30}..."
        echo "  • API Key: ${API_KEY:0:30}..."

        # Validation checks
        if [[ "$APP_ID" == *"android"* ]]; then
            echo -e "  ${GREEN}✓${NC} google_app_id が正しい形式です"
        else
            echo -e "  ${RED}✗${NC} google_app_id が不正な値のようです: $APP_ID"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} jq がインストールされていません"
        echo "    手動で android/app/google-services.json を確認してください"
    fi
fi
echo

# 3. Firebase initialization code 確認
echo -e "${BLUE}[3/3] Firebase 初期化コードの確認${NC}"
check_value "lib/main.dart" "Firebase.initializeApp" "Firebase が初期化されている"
check_value "lib/services/go_engine_service.dart" "FirebaseFunctions" "Cloud Functions が設定されている"
echo

# Summary
echo -e "${BLUE}=== 検証結果 ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ すべての設定が正常です${NC}"
    echo
    echo "次のステップ:"
    echo "1. flutter clean && flutter pub get を実行"
    echo "2. flutter run でアプリを起動"
    echo "3. firebase logs でエラーを確認"
else
    echo -e "${RED}❌ $ERRORS 個の問題が見つかりました${NC}"
    echo
    echo "対応方法:"
    echo "1. FIREBASE_SETUP_CHECKLIST.md を参照"
    echo "2. Firebase Console で設定を再確認"
    echo "3. flutterfire configure を再実行"
fi
echo
