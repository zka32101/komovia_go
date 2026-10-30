import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));

  test('英語は件数が1のとき単数形になる', () {
    expect(en.movesToSolveLabel(1), '1 move to solve');
    expect(en.gamesCountLabel(1), '1 game');
    expect(en.friendshipDaysLabel(1), '1 day');
    expect(en.stonesLabel(1), '1 stone');
    expect(en.stonesCountShortLabel(1), '1 stone');
    expect(en.gamesPlayedCountLabel(1), '1 game played');
  });

  test('英語は0件や2件以上では複数形のまま', () {
    expect(en.movesToSolveLabel(3), '3 moves to solve');
    expect(en.gamesCountLabel(0), '0 games');
    expect(en.friendshipDaysLabel(2), '2 days');
    expect(en.stonesLabel(12), '12 stones');
  });

  test('日本語は件数によらず従来の表記', () {
    expect(ja.movesToSolveLabel(1), '1手で解ける');
    expect(ja.movesToSolveLabel(3), '3手で解ける');
  });
}
