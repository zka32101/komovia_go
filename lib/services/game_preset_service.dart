import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/extended_game_models.dart';

final _logger = Logger();

/// Service for managing game presets and handicap settings
class GamePresetService {
  final FirebaseFirestore _firestore;

  GamePresetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new game preset
  Future<bool> createPreset({
    required String userId,
    required String name,
    required String gameMode,
    required int boardSize,
    required int aiLevel,
    String? playerColor,
    HandicapSettings? handicap,
  }) async {
    try {
      _logger.i('Creating game preset: $name for user: $userId');

      final presetId = _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .doc()
          .id;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .doc(presetId)
          .set({
        'id': presetId,
        'userId': userId,
        'name': name,
        'gameMode': gameMode,
        'boardSize': boardSize,
        'aiLevel': aiLevel,
        'playerColor': playerColor ?? 'black',
        'handicap': handicap?.toJson(),
        // GamePreset.fromJson parses createdAt via DateTime.parse(json[...]
        // as String) - a raw DateTime would round-trip through Firestore
        // as a Timestamp and fail that cast on every later read.
        'createdAt': DateTime.now().toIso8601String(),
        'usageCount': 0,
      });

      return true;
    } catch (e) {
      _logger.e('Failed to create preset: $e');
      return false;
    }
  }

  /// Update an existing preset
  Future<bool> updatePreset({
    required String userId,
    required String presetId,
    required String name,
    required String gameMode,
    required int boardSize,
    required int aiLevel,
    String? playerColor,
    HandicapSettings? handicap,
  }) async {
    try {
      _logger.i('Updating preset: $presetId for user: $userId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .doc(presetId)
          .update({
        'name': name,
        'gameMode': gameMode,
        'boardSize': boardSize,
        'aiLevel': aiLevel,
        'playerColor': playerColor,
        'handicap': handicap?.toJson(),
      });

      return true;
    } catch (e) {
      _logger.e('Failed to update preset: $e');
      return false;
    }
  }

  /// Delete a preset
  Future<bool> deletePreset({
    required String userId,
    required String presetId,
  }) async {
    try {
      _logger.i('Deleting preset: $presetId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .doc(presetId)
          .delete();

      return true;
    } catch (e) {
      _logger.e('Failed to delete preset: $e');
      return false;
    }
  }

  /// Get all presets for a user
  Future<List<GamePreset>> getUserPresets({required String userId}) async {
    try {
      _logger.i('Getting presets for user: $userId');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .orderBy('createdAt', descending: true)
          .get();

      final presets = querySnapshot.docs
          .map((doc) => GamePreset.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return presets;
    } catch (e) {
      _logger.e('Failed to get presets: $e');
      return [];
    }
  }

  /// Get presets by game mode
  Future<List<GamePreset>> getPresetsByMode({
    required String userId,
    required String gameMode,
  }) async {
    try {
      _logger.i('Getting presets for mode: $gameMode');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .where('gameMode', isEqualTo: gameMode)
          .orderBy('usageCount', descending: true)
          .get();

      final presets = querySnapshot.docs
          .map((doc) => GamePreset.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return presets;
    } catch (e) {
      _logger.e('Failed to get presets by mode: $e');
      return [];
    }
  }

  /// Get most used presets
  Future<List<GamePreset>> getMostUsedPresets({
    required String userId,
    int limit = 5,
  }) async {
    try {
      _logger.i('Getting most used presets for: $userId');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .orderBy('usageCount', descending: true)
          .limit(limit)
          .get();

      final presets = querySnapshot.docs
          .map((doc) => GamePreset.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return presets;
    } catch (e) {
      _logger.e('Failed to get most used presets: $e');
      return [];
    }
  }

  /// Increment preset usage count
  Future<bool> incrementPresetUsage({
    required String userId,
    required String presetId,
  }) async {
    try {
      _logger.i('Incrementing usage for preset: $presetId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .doc(presetId)
          .update({
        'usageCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      _logger.e('Failed to increment preset usage: $e');
      return false;
    }
  }

  /// Stream user presets (real-time)
  Stream<List<GamePreset>> streamUserPresets({required String userId}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('gamePresets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GamePreset.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  /// Create default presets for new users
  Future<bool> createDefaultPresets({required String userId}) async {
    try {
      _logger.i('Creating default presets for user: $userId');

      final now = DateTime.now();
      final defaultPresets = [
        {
          'name': 'Quick Blitz 19×19',
          'gameMode': 'blitz',
          'boardSize': 19,
          'aiLevel': 5,
          'playerColor': 'black',
          'handicap': null,
        },
        {
          'name': 'Training 13×13',
          'gameMode': 'correspondence',
          'boardSize': 13,
          'aiLevel': 3,
          'playerColor': 'black',
          'handicap': null,
        },
        {
          'name': 'Handicap 3 stones (9×9)',
          'gameMode': 'blitz',
          'boardSize': 9,
          'aiLevel': 7,
          'playerColor': 'black',
          'handicap': {
            'handicapStones': 3,
            'komiAdjustment': '0.5',
            'handicapPositions': ['3-3', '3-15', '15-15', '15-3'],
          },
        },
      ];

      for (var i = 0; i < defaultPresets.length; i++) {
        final preset = defaultPresets[i];
        final presetId = _firestore
            .collection('users')
            .doc(userId)
            .collection('gamePresets')
            .doc()
            .id;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('gamePresets')
            .doc(presetId)
            .set({
          'id': presetId,
          'userId': userId,
          ...preset,
          'createdAt': now.toIso8601String(),
          'usageCount': 0,
        });
      }

      _logger.i('Default presets created successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to create default presets: $e');
      return false;
    }
  }

  /// Get total presets count
  Future<int> getPresetCount({required String userId}) async {
    try {
      final count = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gamePresets')
          .count()
          .get();

      return count.count ?? 0;
    } catch (e) {
      _logger.e('Failed to get preset count: $e');
      return 0;
    }
  }
}
