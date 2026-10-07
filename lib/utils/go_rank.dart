/// レーティング数値を囲碁の級位・段位表示に変換する。
///
/// 変換式: rating 2000 を初段の境界とし、100刻みで1段/1級ずつ変動する。
/// 級位は30級を下限、段位は九段を上限とする（一般的なアマチュア表記に合わせる）。
String formatGoRank(int rating) {
  if (rating >= 2000) {
    final dan = ((rating - 2000) ~/ 100) + 1;
    return '${_danKanji(dan.clamp(1, 9).toInt())}段';
  }
  final kyu = ((2000 - rating) / 100).ceil().clamp(1, 30);
  return '$kyu級';
}

const _danKanjiNumbers = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

String _danKanji(int dan) {
  if (dan == 1) return '初';
  return _danKanjiNumbers[dan - 1];
}
