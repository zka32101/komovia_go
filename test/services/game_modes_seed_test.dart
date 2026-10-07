import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/sns_models.dart';

void main() {
  test('scripts/seed/game_modes.json parses as GameMode documents', () {
    final raw = File('scripts/seed/game_modes.json').readAsStringSync();
    final docs = jsonDecode(raw) as Map<String, dynamic>;
    expect(docs, isNotEmpty);

    final types = <GameModeType>{};
    docs.forEach((id, data) {
      final mode = GameMode.fromJson({...(data as Map<String, dynamic>), 'id': id});
      expect(mode.id, id);
      expect(mode.name, isNotEmpty);
      expect(mode.timeLimit, greaterThanOrEqualTo(0));
      expect(
        ['easy', 'medium', 'hard', 'master'],
        contains(mode.difficulty),
      );
      types.add(mode.type);
    });

    // Every mode type the selector screen can route to has a document.
    expect(types, equals(GameModeType.values.toSet()));
  });
}
