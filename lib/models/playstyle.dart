import 'package:cloud_firestore/cloud_firestore.dart';

/// プレイヤーの棋風プロファイル（過去の対局から算出）
class PlaystyleProfile {
  final String uid;
  final double aggressiveness; // 0.0(慎重) 〜 1.0(攻撃的) : 手数に対する石数密度から算出
  final double territoriality; // 0.0(戦闘型) 〜 1.0(地合い重視) : 盤の隅/辺の占有率から算出
  final double sacrificeRate; // 捨て石率 : 被captureとの相関
  final int gamesAnalyzed;
  final DateTime updatedAt;

  PlaystyleProfile({
    required this.uid,
    required this.aggressiveness,
    required this.territoriality,
    required this.sacrificeRate,
    required this.gamesAnalyzed,
    required this.updatedAt,
  });

  factory PlaystyleProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PlaystyleProfile(
      uid: doc.id,
      aggressiveness: (data['aggressiveness'] as num?)?.toDouble() ?? 0.5,
      territoriality: (data['territoriality'] as num?)?.toDouble() ?? 0.5,
      sacrificeRate: (data['sacrificeRate'] as num?)?.toDouble() ?? 0.5,
      gamesAnalyzed: data['gamesAnalyzed'] as int? ?? 0,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'aggressiveness': aggressiveness,
      'territoriality': territoriality,
      'sacrificeRate': sacrificeRate,
      'gamesAnalyzed': gamesAnalyzed,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static PlaystyleProfile empty(String uid) {
    return PlaystyleProfile(
      uid: uid,
      aggressiveness: 0.5,
      territoriality: 0.5,
      sacrificeRate: 0.5,
      gamesAnalyzed: 0,
      updatedAt: DateTime.now(),
    );
  }
}

/// 2人のプレイヤー間の棋風相性スコア
class PlaystyleCompatibility {
  final String uid;
  final String otherUid;
  final String otherDisplayName;
  final double compatibilityScore; // 0.0〜1.0、高いほど「補完し合う」相性
  final String compatibilityType; // 'complementary'（対照的で学び合える）, 'similar'（似た棋風で共感し合える）

  PlaystyleCompatibility({
    required this.uid,
    required this.otherUid,
    required this.otherDisplayName,
    required this.compatibilityScore,
    required this.compatibilityType,
  });
}
