import 'package:cloud_firestore/cloud_firestore.dart';

/// User's tsume-go attempt log
class UserTsumeGoLog {
  final String id;
  final String uid;
  final String problemId;
  final bool isCorrect;
  final DateTime solvedAt;
  final int attemptCount;
  final Duration? solvingTime;
  final String? userSolutionSgf;

  UserTsumeGoLog({
    required this.id,
    required this.uid,
    required this.problemId,
    required this.isCorrect,
    required this.solvedAt,
    required this.attemptCount,
    this.solvingTime,
    this.userSolutionSgf,
  });

  /// Create from Firestore document
  factory UserTsumeGoLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserTsumeGoLog(
      id: doc.id,
      uid: data['uid'] ?? '',
      problemId: data['problemId'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
      solvedAt: data['solvedAt'] is Timestamp
          ? (data['solvedAt'] as Timestamp).toDate()
          : DateTime.now(),
      attemptCount: data['attemptCount'] ?? 1,
      solvingTime: data['solvingTime'] != null
          ? Duration(seconds: data['solvingTime'] as int)
          : null,
      userSolutionSgf: data['userSolutionSgf'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'problemId': problemId,
      'isCorrect': isCorrect,
      'solvedAt': Timestamp.fromDate(solvedAt),
      'attemptCount': attemptCount,
      'solvingTime': solvingTime?.inSeconds,
      'userSolutionSgf': userSolutionSgf,
    };
  }

  @override
  String toString() =>
      'UserTsumeGoLog(uid: $uid, problemId: $problemId, isCorrect: $isCorrect, attemptCount: $attemptCount)';
}
