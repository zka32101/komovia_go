import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// OnboardingScreen - 3-card rule tutorial for new users
///
/// Teaches the fundamental "3-tap Aha" moment:
/// 1. Place black stone (player's first move)
/// 2. AI responds with white stone
/// 3. Capture the AI's stone with a second black stone
///
/// Routes to HomeScreen after completion
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _logger.i('OnboardingScreen initialized');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.sumi,
      body: Column(
        children: [
          // Header with skip button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.onboardingHeaderTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _handleSkipTutorial,
                  child: Text(
                    l10n.skipButton,
                    style: TextStyle(
                      color: AppColors.kin,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PageView for cards
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildCard1_Welcome(context, l10n),
                _buildCard2_YourMove(context, l10n),
                _buildCard3_Capture(context, l10n),
              ],
            ),
          ),

          // Dots indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? AppColors.kin
                        : AppColors.grey500,
                  ),
                ),
              ),
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text(l10n.backButton),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentPage < 2
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : _handleCompleteTutorial,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      _currentPage < 2 ? l10n.nextButton : l10n.startPlayingButton,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1: Welcome & motivation
  Widget _buildCard1_Welcome(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 120, color: AppColors.kin),
            const SizedBox(height: 32),
            Text(
              l10n.onboardingWelcomeTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.onboardingWelcomeSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.washiDim,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.kin, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.onboardingWelcomeSteps,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.kin,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 2: Your first move
  Widget _buildCard2_YourMove(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.onboardingCard2Title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Mini board visualization
            const _MiniBoard(stones: [_MiniStone(2, 2, highlight: true)]),
            const SizedBox(height: 32),

            Text(
              l10n.onboardingCard2Description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.washiDim,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Card 3: Capture the stone
  Widget _buildCard3_Capture(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.onboardingCard3Title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingCard3Subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.kin,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Mini board visualization
            _MiniBoard(stones: const [
              _MiniStone(2, 2, white: true),
              _MiniStone(1, 2),
              _MiniStone(2, 1, highlight: true),
            ]),
            const SizedBox(height: 32),

            Text(
              l10n.onboardingCard3Description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.washiDim,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSkipTutorial() {
    _logger.i('Tutorial skipped');
    ref.read(logTutorialSkippedProvider)();
    _navigateToHome();
  }

  void _handleCompleteTutorial() async {
    _logger.i('Tutorial completed');
    try {
      await ref.read(logTutorialCompletedProvider)();
      await ref.read(completeTutorialProvider)();
    } catch (e) {
      _logger.e('Error completing tutorial: $e');
    }
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await _ensureSignedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _ensureSignedIn() async {
    try {
      final authService = ref.read(authServiceProvider);
      if (authService.currentUser != null) return;
      await authService.signInAnonymously().timeout(const Duration(seconds: 8));
    } catch (e) {
      _logger.w('Anonymous sign-in failed, continuing as guest: $e');
    }
  }
}

class _MiniStone {
  const _MiniStone(this.col, this.row, {this.white = false, this.highlight = false});
  final int col;
  final int row;
  final bool white;
  final bool highlight;
}

/// 5x5-intersection illustration board; stones sit on line intersections.
class _MiniBoard extends StatelessWidget {
  const _MiniBoard({required this.stones});
  final List<_MiniStone> stones;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.kin, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.kinLight.withOpacity(0.1),
      ),
      child: CustomPaint(painter: _MiniBoardPainter(stones)),
    );
  }
}

class _MiniBoardPainter extends CustomPainter {
  _MiniBoardPainter(this.stones);
  final List<_MiniStone> stones;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 5;
    final pad = size.width * 0.12;
    final step = (size.width - pad * 2) / (n - 1);
    final line = Paint()
      ..color = AppColors.grey500
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      final v = pad + step * i;
      canvas.drawLine(Offset(pad, v), Offset(size.width - pad, v), line);
      canvas.drawLine(Offset(v, pad), Offset(v, size.height - pad), line);
    }
    for (final s in stones) {
      final c = Offset(pad + step * s.col, pad + step * s.row);
      final r = step * 0.46;
      canvas.drawCircle(c + const Offset(1.5, 2), r, Paint()..color = Colors.black45);
      canvas.drawCircle(c, r, Paint()..color = s.white ? AppColors.washi : AppColors.sumi);
      if (s.white) {
        canvas.drawCircle(c, r, Paint()
          ..color = AppColors.sumi
          ..style = PaintingStyle.stroke);
      }
      if (s.highlight) {
        canvas.drawCircle(c, r + 4, Paint()
          ..color = AppColors.kin
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBoardPainter old) => old.stones != stones;
}
