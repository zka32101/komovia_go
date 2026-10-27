/// フレンド間DMで送信できる内容を、固定フレーズと絵文字のみに制限する
/// ためのカタログ。相手を煽る・中傷するような自由入力を一切許さない方針
/// （ユーザー指示）に基づき、ChatScreenはこのカタログからの選択UIのみを
/// 提供し、DirectMessageService.sendMessageもこのカタログに含まれない
/// contentを拒否する（UIを経由しない直接呼び出しに対する防御）。
///
/// アプリ全体のl10n（AppLocalizations）はBuildContextが必要で
/// DirectMessageServiceからは参照できないため、プリセット文言はここに
/// 固定の日本語/英語ペアとして直接持つ（l10nのARBとは別管理）。
/// isAllowedDmContentは現在のロケールに関わらずどちらの言語の文言も
/// 許可する——送信側と検証側で見ているロケールが食い違っても、実際に
/// カタログに含まれるプリセットなら拒否されないようにするため。
class DmPreset {
  final String ja;
  final String en;

  const DmPreset({required this.ja, required this.en});
}

const List<DmPreset> dmPresetMessages = [
  DmPreset(ja: 'こんにちは', en: 'Hello!'),
  DmPreset(ja: 'お願いします', en: "Let's play!"),
  DmPreset(ja: 'ありがとうございました', en: 'Thank you!'),
  DmPreset(ja: 'いい手ですね', en: 'Nice move!'),
  DmPreset(ja: '強いですね', en: "You're strong!"),
  DmPreset(ja: '良い対局でした', en: 'Good game!'),
  DmPreset(ja: 'また対局しましょう', en: "Let's play again!"),
  DmPreset(ja: 'お疲れ様でした', en: 'Great job!'),
  DmPreset(ja: '棋譜を見てみます', en: "I'll review the game record."),
  DmPreset(ja: 'すみません、少し待ってください', en: 'Sorry, please wait a moment.'),
];

/// 送信可能な絵文字（煽り・中傷に使われにくい、ポジティブ/ニュートラルな
/// ものだけを厳選）。
const List<String> dmAllowedEmoji = [
  '👍',
  '😊',
  '🎉',
  '🙏',
  '😅',
  '👏',
  '🔥',
  '😢',
  '🤔',
  '❤️',
];

/// 現在の表示ロケールに合わせたプリセット文言一覧（表示順）。
List<String> dmPresetLabels({required bool japanese}) =>
    dmPresetMessages.map((p) => japanese ? p.ja : p.en).toList();

final Set<String> _allAllowedPresetTexts = {
  for (final p in dmPresetMessages) p.ja,
  for (final p in dmPresetMessages) p.en,
};

/// [content]が許可されたプリセット文言（どちらの言語でも）または絵文字か
/// どうか。DirectMessageService.sendMessageが送信前にこれで検証する。
bool isAllowedDmContent(String content) {
  return dmAllowedEmoji.contains(content) || _allAllowedPresetTexts.contains(content);
}
