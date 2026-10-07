import 'package:cloud_firestore/cloud_firestore.dart';

/// Log of user watching game observations/study
class ObservationLog {
  final String id;
  final String uid;
  final String kifuId;
  final DateTime watchedAt;
  final double completedRate; // 0.0-1.0 (percentage viewed)
  final Duration? watchDuration;

  ObservationLog({
    required this.id,
    required this.uid,
    required this.kifuId,
    required this.watchedAt,
    required this.completedRate,
    this.watchDuration,
  });

  /// Create from Firestore document
  factory ObservationLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ObservationLog(
      id: doc.id,
      uid: data['uid'] ?? '',
      kifuId: data['kifuId'] ?? '',
      watchedAt: data['watchedAt'] is Timestamp
          ? (data['watchedAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedRate: (data['completedRate'] ?? 0.0).toDouble(),
      watchDuration: data['watchDuration'] != null
          ? Duration(seconds: data['watchDuration'] as int)
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'kifuId': kifuId,
      'watchedAt': Timestamp.fromDate(watchedAt),
      'completedRate': completedRate,
      'watchDuration': watchDuration?.inSeconds,
    };
  }

  bool isCompleted() => completedRate >= 0.95; // 95% or more

  @override
  String toString() =>
      'ObservationLog(uid: $uid, kifuId: $kifuId, completedRate: ${(completedRate * 100).toStringAsFixed(1)}%)';
}
