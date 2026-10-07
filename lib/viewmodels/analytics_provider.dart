import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

// ================== ANALYTICS SERVICE ==================

/// Singleton instance of Firebase Analytics
final analyticsProvider = Provider<FirebaseAnalytics>((ref) {
  final analytics = FirebaseAnalytics.instance;
  _logger.i('Analytics service initialized');
  return analytics;
});

// ================== AHA MOMENT EVENTS ==================

/// Log when user reaches the "aha moment" (capture stone on first move)
final logAhaMomentProvider = Provider<Future<void> Function()>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return () async {
    try {
      _logger.i('Logging aha moment event');
      await analytics.logEvent(
        name: 'aha_moment_reached',
        parameters: {
          'board_size': 9,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Aha moment event logged');
    } catch (e) {
      _logger.e('Error logging aha moment: $e');
    }
  };
});

// ================== GAME COMPLETION EVENTS ==================

/// Log when AI game is completed
final logGameCompletedProvider = Provider<
    Future<void> Function({
  required String result, // 'win', 'lose', 'draw'
  required int aiLevel,
  required int boardSize,
  required int movesCount,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required String result,
    required int aiLevel,
    required int boardSize,
    required int movesCount,
  }) async {
    try {
      _logger.i('Logging game completed event: result=$result, level=$aiLevel');
      await analytics.logEvent(
        name: 'ai_game_completed',
        parameters: {
          'result': result,
          'ai_level': aiLevel,
          'board_size': boardSize,
          'moves_count': movesCount,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Game completed event logged');
    } catch (e) {
      _logger.e('Error logging game completion: $e');
    }
  };
});

/// Log game resignation
final logGameResignationProvider = Provider<
    Future<void> Function({
  required int aiLevel,
  required int boardSize,
  required int movesCount,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required int aiLevel,
    required int boardSize,
    required int movesCount,
  }) async {
    try {
      _logger.i('Logging game resignation event: level=$aiLevel');
      await analytics.logEvent(
        name: 'game_resigned',
        parameters: {
          'ai_level': aiLevel,
          'board_size': boardSize,
          'moves_count': movesCount,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Resignation event logged');
    } catch (e) {
      _logger.e('Error logging resignation: $e');
    }
  };
});

// ================== TSUME-GO EVENTS ==================

/// Log when tsume-go puzzle is solved
final logTsumeGoSolvedProvider = Provider<
    Future<void> Function({
  required int difficulty,
  required int attempts,
  required int solvingTimeSeconds,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required int difficulty,
    required int attempts,
    required int solvingTimeSeconds,
  }) async {
    try {
      _logger.i('Logging tsume-go solved event: difficulty=$difficulty');
      await analytics.logEvent(
        name: 'tsumego_solved',
        parameters: {
          'difficulty': difficulty,
          'attempts': attempts,
          'solving_time_seconds': solvingTimeSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Tsume-go solved event logged');
    } catch (e) {
      _logger.e('Error logging tsume-go solved: $e');
    }
  };
});

/// Log when tsume-go puzzle is attempted (but not solved)
final logTsumeGoAttemptedProvider = Provider<
    Future<void> Function({
  required int difficulty,
  required int attemptNumber,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required int difficulty,
    required int attemptNumber,
  }) async {
    try {
      _logger.i('Logging tsume-go attempt event: difficulty=$difficulty');
      await analytics.logEvent(
        name: 'tsumego_attempted',
        parameters: {
          'difficulty': difficulty,
          'attempt_number': attemptNumber,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Tsume-go attempt event logged');
    } catch (e) {
      _logger.e('Error logging tsume-go attempt: $e');
    }
  };
});

// ================== KIFU OBSERVATION EVENTS ==================

/// Log when user starts watching a kifu
final logKifuObservationStartedProvider = Provider<
    Future<void> Function({
  required String kifuId,
  required String category, // 'copyright_free' or 'own_games'
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required String kifuId,
    required String category,
  }) async {
    try {
      _logger.i('Logging kifu observation started: $kifuId');
      await analytics.logEvent(
        name: 'kifu_observation_started',
        parameters: {
          'kifu_id': kifuId,
          'category': category,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Kifu observation started event logged');
    } catch (e) {
      _logger.e('Error logging kifu observation started: $e');
    }
  };
});

/// Log when user completes watching a kifu
final logKifuObservationCompletedProvider = Provider<
    Future<void> Function({
  required String kifuId,
  required double completedRate,
  required int watchDurationSeconds,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required String kifuId,
    required double completedRate,
    required int watchDurationSeconds,
  }) async {
    try {
      _logger.i('Logging kifu observation completed: $kifuId');
      await analytics.logEvent(
        name: 'kifu_observation_completed',
        parameters: {
          'kifu_id': kifuId,
          'completed_rate': completedRate,
          'watch_duration_seconds': watchDurationSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Kifu observation completed event logged');
    } catch (e) {
      _logger.e('Error logging kifu observation completed: $e');
    }
  };
});

// ================== PAYWALL EVENTS ==================

/// Log when paywall is viewed
final logPaywallViewedProvider = Provider<Future<void> Function()>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return () async {
    try {
      _logger.i('Logging paywall viewed event');
      await analytics.logEvent(
        name: 'paywall_viewed',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Paywall viewed event logged');
    } catch (e) {
      _logger.e('Error logging paywall viewed: $e');
    }
  };
});

/// Log when paywall is triggered (3rd game)
final logPaywallTriggeredProvider = Provider<
    Future<void> Function({
  required int gameNumber,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({required int gameNumber}) async {
    try {
      _logger.i('Logging paywall triggered event: game=$gameNumber');
      await analytics.logEvent(
        name: 'paywall_triggered',
        parameters: {
          'game_number': gameNumber,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Paywall triggered event logged');
    } catch (e) {
      _logger.e('Error logging paywall triggered: $e');
    }
  };
});

/// Log when user closes paywall without converting
final logPaywallDismissedProvider = Provider<
    Future<void> Function({
  required int gameNumber,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({required int gameNumber}) async {
    try {
      _logger.i('Logging paywall dismissed event: game=$gameNumber');
      await analytics.logEvent(
        name: 'paywall_dismissed',
        parameters: {
          'game_number': gameNumber,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Paywall dismissed event logged');
    } catch (e) {
      _logger.e('Error logging paywall dismissed: $e');
    }
  };
});

/// Log when user purchases subscription
final logPaywallConvertedProvider = Provider<
    Future<void> Function({
  required String plan, // 'monthly', 'annual', etc.
  required double price,
  required String currency,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required String plan,
    required double price,
    required String currency,
  }) async {
    try {
      _logger.i('Logging paywall converted event: plan=$plan, price=$price');
      await analytics.logEvent(
        name: 'paywall_converted',
        parameters: {
          'plan': plan,
          'price': price,
          'currency': currency,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Paywall converted event logged');
    } catch (e) {
      _logger.e('Error logging paywall conversion: $e');
    }
  };
});

// ================== ONBOARDING EVENTS ==================

/// Log when user completes onboarding tutorial
final logTutorialCompletedProvider = Provider<Future<void> Function()>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return () async {
    try {
      _logger.i('Logging tutorial completed event');
      await analytics.logEvent(
        name: 'tutorial_completed',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Tutorial completed event logged');
    } catch (e) {
      _logger.e('Error logging tutorial completion: $e');
    }
  };
});

/// Log when user skips onboarding
final logTutorialSkippedProvider = Provider<Future<void> Function()>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return () async {
    try {
      _logger.i('Logging tutorial skipped event');
      await analytics.logEvent(
        name: 'tutorial_skipped',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Tutorial skipped event logged');
    } catch (e) {
      _logger.e('Error logging tutorial skipped: $e');
    }
  };
});

// ================== SIGN-UP/LOGIN EVENTS ==================

/// Log when user signs up
final logSignUpProvider = Provider<
    Future<void> Function({
  required String signUpMethod, // 'email', 'anonymous', etc.
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({required String signUpMethod}) async {
    try {
      _logger.i('Logging sign up event: method=$signUpMethod');
      await analytics.logEvent(
        name: 'sign_up',
        parameters: {
          'sign_up_method': signUpMethod,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Sign up event logged');
    } catch (e) {
      _logger.e('Error logging sign up: $e');
    }
  };
});

/// Log when user logs in
final logLogInProvider = Provider<
    Future<void> Function({
  required String logInMethod, // 'email', 'anonymous', etc.
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({required String logInMethod}) async {
    try {
      _logger.i('Logging log in event: method=$logInMethod');
      await analytics.logEvent(
        name: 'log_in',
        parameters: {
          'log_in_method': logInMethod,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Log in event logged');
    } catch (e) {
      _logger.e('Error logging log in: $e');
    }
  };
});

// ================== CUSTOM EVENT LOGGING ==================

/// Log custom analytics event (for flexibility)
final logCustomEventProvider = Provider<
    Future<void> Function({
  required String eventName,
  Map<String, Object?>? parameters,
})>((ref) {
  final analytics = ref.watch(analyticsProvider);

  return ({
    required String eventName,
    Map<String, Object?>? parameters,
  }) async {
    try {
      _logger.i('Logging custom event: $eventName');
      await analytics.logEvent(
        name: eventName,
        parameters: {
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _logger.i('✅ Custom event logged: $eventName');
    } catch (e) {
      _logger.e('Error logging custom event: $e');
    }
  };
});
