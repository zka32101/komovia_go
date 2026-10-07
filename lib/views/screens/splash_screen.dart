import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/utils/wa_decorations.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/widgets/org_logo_footer.dart';

final _logger = Logger();

/// SplashScreen - App initialization and authentication routing
///
/// Displays loading animation while Firebase initializes and checks auth state.
/// Routes to:
/// - OnboardingScreen if first-time user
/// - HomeScreen if authenticated
/// - AuthScreen if not authenticated
class SplashScreen extends ConsumerWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building SplashScreen');

    final l10n = AppLocalizations.of(context)!;
    // Watch authentication state
    final authState = ref.watch(authStateProvider);

    return authState.when(
      // Loading state
      loading: () {
        _logger.i('Auth state loading...');
        return _buildBackground(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(context, l10n),
              const SizedBox(height: 60),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.splashLoadingLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey300,
                ),
              ),
            ],
          ),
        );
      },

      // Error state
      error: (error, stack) {
        _logger.e('Auth state error: $error\n$stack');
        return _buildBackground(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.shuLight,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.splashInitErrorTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.washi,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey300,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () {
                  // Retry by refreshing auth state
                  ref.refresh(authStateProvider);
                },
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        );
      },

      // Data state - user authenticated or not
      data: (user) {
        _logger.i('Auth state resolved: user=${user?.uid ?? "null"}');

        // If user is logged in, route to Home
        if (user != null) {
          _logger.i('User authenticated, routing to HomeScreen');
          Future.microtask(() {
            _routeToHome(context);
          });
        } else {
          _logger.i('User not authenticated, routing to OnboardingScreen');
          Future.microtask(() {
            _routeToOnboarding(context);
          });
        }

        // Show loading screen while navigation happens
        return _buildBackground(
          child: _buildLogo(context, l10n),
        );
      },
    );
  }

  /// 全ステート共通の背景（墨色のグラデーション）。
  Widget _buildBackground({required Widget child}) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ),
        ),
        // 中央にアプリロゴ等、下部に組織ロゴ
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            const OrgLogoFooter(),
          ],
        ),
      ),
    );
  }

  /// 円相（一筆書きの円）を背景に、アプリ名を筆文字風の大きな明朝体で
  /// 重ねたロゴ。以前の汎用的な肉球アイコンから、和のモチーフに差し替えた。
  Widget _buildLogo(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: EnsoPainter(color: AppColors.accent.withOpacity(0.85)),
              ),
              Text(
                '碁',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '碁縁',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppColors.washi,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.splashTagline,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.accent,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Route to HomeScreen
  void _routeToHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// Route to OnboardingScreen
  void _routeToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }
}
