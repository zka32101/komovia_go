/**
 * Cloud Functions for 碁縁 (GoEn).
 *
 * Implements `generateGameAnalysis`, the one callable Cloud Function the
 * Flutter app actually calls today (see
 * lib/services/ai_explanation_service.dart / lib/viewmodels/ai_review_provider.dart,
 * wired into GameResultScreen's "AIで振り返る" button). The client also
 * declares `generateMoveExplanation`/`generateQuickMoveComment` callables
 * in the same service file, but nothing in the app calls them yet — left
 * unimplemented here until a real caller exists, rather than guessing at
 * a shape nothing will ever invoke.
 *
 * Also re-exports `weeklyTournamentScheduler` (see ./weeklyTournament.ts),
 * a scheduled (not callable) function that auto-runs a weekly tournament,
 * and `sendPushOnNotificationCreated` (see ./pushNotifications.ts), a
 * Firestore-triggered function that actually delivers a push notification.
 */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import Anthropic from "@anthropic-ai/sdk";
import {parseSgfBoardSize, parseSgfMoves, movesToPromptText, SgfMove} from "./sgf";

export {weeklyTournamentScheduler} from "./weeklyTournament";
export {sendPushOnNotificationCreated} from "./pushNotifications";

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const MODEL = "claude-sonnet-5";
// A full 19-line game can run 200+ moves; explaining every single one
// would blow past a reasonable response size/latency/cost budget, so the
// model is asked to pick the handful that actually mattered instead of
// commenting on every move (matches the "premium, unhurried" tone the
// app aims for elsewhere — a wall of per-move text isn't more useful).
const MAX_MOVES_TO_EXPLAIN = 10;

interface MoveExplanationOut {
  moveNumber: number;
  row: number;
  col: number;
  playerColor: "black" | "white";
  basicExplanation: string;
  advancedExplanation?: string;
  strategicNote?: string;
  confidenceLevel?: number;
}

interface GameAnalysisOut {
  kifuId: string;
  overallTheme: string;
  keyTurningPoints: string;
  conclusion: string;
  moves: MoveExplanationOut[];
}

const ANALYSIS_TOOL = {
  name: "submit_game_analysis",
  description:
    "囲碁の対局に対する解説結果を提出する。moves には、対局全体を通じて特に重要だった" +
    `局面を最大${MAX_MOVES_TO_EXPLAIN}手まで選んで含めること。`,
  input_schema: {
    type: "object" as const,
    properties: {
      overallTheme: {
        type: "string",
        description: "この対局全体を通じた展開・特徴の要約（2〜4文程度）",
      },
      keyTurningPoints: {
        type: "string",
        description: "形勢が動いた分岐点についての説明",
      },
      conclusion: {
        type: "string",
        description: "最終的な総評",
      },
      moves: {
        type: "array",
        items: {
          type: "object",
          properties: {
            moveNumber: {type: "integer", description: "1始まりの手数"},
            row: {type: "integer"},
            col: {type: "integer"},
            playerColor: {type: "string", enum: ["black", "white"]},
            basicExplanation: {
              type: "string",
              description: "1〜2文程度の平易な説明",
            },
            advancedExplanation: {
              type: "string",
              description: "より詳しい戦術的な解説（任意）",
            },
            strategicNote: {
              type: "string",
              description: "この手の長期的な戦略上の意味（任意）",
            },
            confidenceLevel: {
              type: "number",
              description: "0.0〜1.0の自己評価の確信度（任意、省略時は0.8扱い）",
            },
          },
          required: ["moveNumber", "row", "col", "playerColor", "basicExplanation"],
        },
      },
    },
    required: ["overallTheme", "keyTurningPoints", "conclusion", "moves"],
  },
};

function buildPrompt(boardSize: number, moves: SgfMove[]): string {
  return [
    "あなたは囲碁の解説者です。以下は" + boardSize + "路盤での対局の、着手を順番に並べたものです。",
    "座標は0始まりの(row, col)で、盤の左上が(0,0)です。",
    "",
    movesToPromptText(moves),
    "",
    "この対局を振り返り、submit_game_analysis ツールを使って日本語で解説を提出してください。",
    `特に重要だった局面（形勢が動いた手、好手、疑問手など）を最大${MAX_MOVES_TO_EXPLAIN}手まで選んでください。`,
    "対局を打ったのはGo初心者〜中級の大人のプレイヤーなので、専門用語には簡単な補足を添え、わかりやすく解説してください。",
  ].join("\n");
}

export const generateGameAnalysis = onCall(
  {
    secrets: [anthropicApiKey],
    timeoutSeconds: 60,
    memory: "512MiB",
    region: "us-central1",
  },
  async (request): Promise<GameAnalysisOut> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です。");
    }

    const data = request.data as {
      sgfData?: unknown;
      kifuId?: unknown;
      focusMoves?: unknown;
    };

    if (typeof data.sgfData !== "string" || data.sgfData.length === 0) {
      throw new HttpsError("invalid-argument", "sgfData is required");
    }
    if (typeof data.kifuId !== "string" || data.kifuId.length === 0) {
      throw new HttpsError("invalid-argument", "kifuId is required");
    }

    const boardSize = parseSgfBoardSize(data.sgfData);
    let moves = parseSgfMoves(data.sgfData);
    if (moves.length === 0) {
      throw new HttpsError("invalid-argument", "sgfData contains no moves to analyze");
    }

    const focusMoves = Array.isArray(data.focusMoves)
      ? (data.focusMoves as unknown[]).filter((n): n is number => typeof n === "number")
      : undefined;
    if (focusMoves && focusMoves.length > 0) {
      const focusSet = new Set(focusMoves);
      moves = moves.filter((m) => focusSet.has(m.moveNumber));
      if (moves.length === 0) {
        throw new HttpsError("invalid-argument", "none of focusMoves matched sgfData");
      }
    }

    const anthropic = new Anthropic({apiKey: anthropicApiKey.value()});
    const prompt = buildPrompt(boardSize, moves);

    let message;
    try {
      message = await anthropic.messages.create({
        model: MODEL,
        max_tokens: 4096,
        tools: [ANALYSIS_TOOL],
        tool_choice: {type: "tool", name: ANALYSIS_TOOL.name},
        messages: [{role: "user", content: prompt}],
      });
    } catch (err) {
      logger.error("Anthropic API call failed", err);
      throw new HttpsError("internal", "AI解説の生成に失敗しました。しばらくしてから再度お試しください。");
    }

    const toolUse = message.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use"
    );
    if (!toolUse) {
      logger.error("No tool_use block in Anthropic response", message);
      throw new HttpsError("internal", "AI解説の生成に失敗しました。");
    }

    const parsed = toolUse.input as {
      overallTheme?: unknown;
      keyTurningPoints?: unknown;
      conclusion?: unknown;
      moves?: unknown;
    };

    if (
      typeof parsed.overallTheme !== "string" ||
      typeof parsed.keyTurningPoints !== "string" ||
      typeof parsed.conclusion !== "string" ||
      !Array.isArray(parsed.moves)
    ) {
      logger.error("Malformed tool_use input from Anthropic", parsed);
      throw new HttpsError("internal", "AI解説の生成に失敗しました。");
    }

    const outMoves: MoveExplanationOut[] = (parsed.moves as Record<string, unknown>[])
      .filter(
        (m) =>
          typeof m.moveNumber === "number" &&
          typeof m.row === "number" &&
          typeof m.col === "number" &&
          (m.playerColor === "black" || m.playerColor === "white") &&
          typeof m.basicExplanation === "string"
      )
      .slice(0, MAX_MOVES_TO_EXPLAIN)
      .map((m) => ({
        moveNumber: m.moveNumber as number,
        row: m.row as number,
        col: m.col as number,
        playerColor: m.playerColor as "black" | "white",
        basicExplanation: m.basicExplanation as string,
        advancedExplanation:
          typeof m.advancedExplanation === "string" ? m.advancedExplanation : undefined,
        strategicNote: typeof m.strategicNote === "string" ? m.strategicNote : undefined,
        confidenceLevel:
          typeof m.confidenceLevel === "number" ? m.confidenceLevel : undefined,
      }));

    return {
      kifuId: data.kifuId,
      overallTheme: parsed.overallTheme,
      keyTurningPoints: parsed.keyTurningPoints,
      conclusion: parsed.conclusion,
      moves: outMoves,
    };
  }
);
