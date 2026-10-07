import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'l10n/app_localizations.dart';
import 'models/index.dart';
import 'services/ad_service.dart';
import 'services/push_notification_service.dart';
import 'viewmodels/index.dart';
import 'views/screens/index.dart';
import 'widgets/startup_splash.dart';

final _logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初期化(await)の間、空白画面にならないよう先に起動画面を出す。
  // 初期化後の本来のrunAppで差し替わる。
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StartupSplash(),
  ));

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  _logger.i('Firebase initialized');

  // Best-effort: ads simply won't show if this fails, no need to block
  // startup on it.
  unawaited(AdService.initialize());

  // Must be registered before runApp: the platform can deliver a push
  // while the app is fully terminated, invoking this handler in its own
  // isolate before any of the app's own widget tree exists.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Route uncaught errors to Crashlytics (declared as a dependency but
  // never actually wired up before this) so production crashes are
  // visible instead of silently dropped.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    const ProviderScope(
      child: GoEnApp(),
    ),
  );
}

class GoEnApp extends ConsumerWidget {
  const GoEnApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps listening for purchase events for the app's whole lifetime, so
    // a transaction the store redelivers on launch (because a previous
    // session's Firestore write failed before it could be acknowledged)
    // gets recovered instead of leaving the user paid-but-not-entitled.
    ref.watch(purchaseRecoveryProvider);

    // Keeps the signed-in user's FCM token registered and the in-app
    // notification badge fresh for as long as the app is running (see
    // fcmSyncProvider's own doc comment).
    ref.watch(fcmSyncProvider);

    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'GoEn - 碁縁',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Dark mode only for premium adults
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
      navigatorObservers: [
        _AnalyticsNavigatorObserver(),
      ],
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/home': (_) => const HomeScreen(),
        '/ai-game': (_) => const AIGameScreen(),
        '/game-result': (_) => GameResultScreenRouter(),
        // Phase 63 Game Settings
        '/blitz-settings': (_) => const BlitzGameSettingsScreen(),
        '/correspondence-settings': (_) =>
            const CorrespondenceGameSettingsScreen(),
        '/team-settings': (_) => const TeamGameSettingsScreen(),
        '/puzzle-rush-settings': (_) => const PuzzleRushSettingsScreen(),
        '/handicap-settings': (_) => const HandicapGameSettingsScreen(),
        // Phase 61 Game Modes
        '/blitz-game': (_) => BlitzGameScreenRouter(),
        '/correspondence-game': (_) => CorrespondenceGameScreenRouter(),
        '/team-game': (_) => TeamGameScreenRouter(),
        '/puzzle-rush': (_) => PuzzleRushScreenRouter(),
        // Phase 5 screens
        '/tsume-go': (_) => const TsumeGoScreen(),
        '/kifu-observation': (_) => const KifuObservationScreen(),
        '/game-history': (_) => const GameHistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/paywall': (_) => const PaywallScreen(),
        // Phase 68-71: SNS Integration, Social Features, Analytics
        '/friends': (_) => const FriendsScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
        '/game-preset-manager': (_) => const GamePresetManagerScreen(),
        '/analytics-dashboard': (_) => const AnalyticsDashboardScreen(),
        '/tournament': (_) => const TournamentScreen(),
        '/pvp-games': (_) => const PvpGamesListScreen(),
        '/notifications': (_) => const NotificationScreen(),
        '/messages': (_) => const MessageThreadsScreen(),
        '/how-to-play': (_) => const HowToPlayScreen(),
        '/joseki': (_) => const JosekiScreen(),
        // 縁 (En) features
        '/en-hub': (_) => const EnHubScreen(),
        // Creator / sharing connections
        '/sponsorship': (_) => const SponsorshipScreen(),
        '/twitch-stream': (_) => const TwitchStreamScreen(),
        '/youtube-share': (_) => const YouTubeShareScreen(),
        '/privacy-policy': (_) => const LegalDocumentScreen(kind: LegalDocumentKind.privacyPolicy),
        '/terms-of-service': (_) => const LegalDocumentScreen(kind: LegalDocumentKind.termsOfService),
      },
      onUnknownRoute: (_) {
        return MaterialPageRoute(
          builder: (_) => _PlaceholderScreen('Not Found'),
        );
      },
    );
  }
}

/// Router for GameResultScreen - handles arguments
class GameResultScreenRouter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;

    return GameResultScreen(
      result: args?['result'] ?? 'unknown',
      blackScore: args?['blackScore'] as double?,
      whiteScore: args?['whiteScore'] as double?,
    );
  }
}

/// Router for BlitzGameScreen - the settings screen navigates here passing
/// the chosen BlitzGameSettings as route arguments; the screen itself needs
/// the current user's uid too, which route arguments don't carry.
class BlitzGameScreenRouter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final settings = args?['settings'] as BlitzGameSettings?;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return BlitzGameScreen(
      uid: uid,
      opponentUid: settings?.opponentUid,
      aiLevel: settings?.aiLevel.toString(),
      boardSize: int.tryParse(settings?.boardSize ?? '') ?? 19,
    );
  }
}

/// Router for CorrespondenceGameScreen - see BlitzGameScreenRouter.
class CorrespondenceGameScreenRouter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final settings = args?['settings'] as CorrespondenceGameSettings?;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return CorrespondenceGameScreen(
      uid: uid,
      opponentUid: settings?.opponentUid ?? '',
      boardSize: int.tryParse(settings?.boardSize ?? '') ?? 19,
    );
  }
}

/// Router for TeamGameScreen - see BlitzGameScreenRouter.
class TeamGameScreenRouter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final settings = args?['settings'] as TeamGameSettings?;

    return TeamGameScreen(
      team1Players: settings?.team1Uids ?? const [],
      team2Players: settings?.team2Uids ?? const [],
      boardSize: int.tryParse(settings?.boardSize ?? '') ?? 19,
    );
  }
}

/// Router for PuzzleRushScreen - see BlitzGameScreenRouter.
class PuzzleRushScreenRouter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final settings = args?['settings'] as PuzzleRushSettings?;
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return PuzzleRushScreen(
      uid: uid,
      difficulty: settings?.difficulty ?? 'normal',
    );
  }
}

/// Placeholder screen for features not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.sumi,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: AppColors.kin,
            ),
            const SizedBox(height: 24),
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.washi,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This screen is under development',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.washiDim,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Analytics observer for tracking screen views
class _AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.i('Screen pushed: ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.i('Screen popped: ${route.settings.name}');
  }
}
