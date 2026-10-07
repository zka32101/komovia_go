import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart' show SubscriptionPlan, PurchaseUnavailableException;
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// PaywallScreen - Premium subscription upgrade flow
///
/// Features:
/// - Display premium features and benefits
/// - Show subscription pricing plans (monthly, annual)
/// - Handle purchase via RevenueCat
/// - Track paywall view and conversion events
/// - Graceful handling of purchase failures
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _showAnnual = false;
  SubscriptionPlan _selectedPlan = SubscriptionPlan.monthly;

  @override
  void initState() {
    super.initState();
    _logger.i('PaywallScreen initialized');
    ref.read(logPaywallViewedProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final isSubscriptionActive = ref.watch(isSubscriptionActiveProvider);

    // If already subscribed, show success state
    if (isSubscriptionActive) {
      return _buildSubscribedState(context, l10n);
    }

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.paywallTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section
            _buildHeroSection(context, l10n),

            // Benefits section
            _buildBenefitsSection(context, l10n),

            // Pricing section
            _buildPricingSection(context, l10n),

            // FAQ section
            _buildFaqSection(context, l10n),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.kin,
                  AppColors.kin,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.star,
                size: 50,
                color: AppColors.washi,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.paywallHeroTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.paywallHeroSubtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context, AppLocalizations l10n) {
    final benefits = [
      (l10n.benefitUnlimitedGamesTitle, l10n.benefitUnlimitedGamesDesc),
      (l10n.benefitKifuLibraryTitle, l10n.benefitKifuLibraryDesc),
      (l10n.benefitNoAdsTitle, l10n.benefitNoAdsDesc),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.whatYouGetTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...benefits.map((benefit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.wakatake,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefit.$1,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.washi,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          benefit.$2,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Toggle between monthly and annual
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.sumiLine),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.washi.withOpacity(0.03),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showAnnual = false;
                      _selectedPlan = SubscriptionPlan.monthly;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: !_showAnnual
                            ? AppColors.kin.withOpacity(0.2)
                            : Colors.transparent,
                      ),
                      child: Text(
                        l10n.monthlyLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: !_showAnnual ? AppColors.kin : AppColors.washiDim,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showAnnual = true;
                      _selectedPlan = SubscriptionPlan.annual;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _showAnnual
                            ? AppColors.kin.withOpacity(0.2)
                            : Colors.transparent,
                      ),
                      child: Text(
                        l10n.annualLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _showAnnual ? AppColors.kin : AppColors.washiDim,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (!_showAnnual)
            _buildPricingCard(
              context,
              title: l10n.monthlyLabel,
              price: _priceLabel(SubscriptionPlan.monthly),
              period: l10n.pricePerMonthSuffix,
              description: l10n.monthlyPlanDescription,
            )
          else
            _buildPricingCard(
              context,
              title: l10n.annualLabel,
              price: _priceLabel(SubscriptionPlan.annual),
              period: l10n.pricePerYearSuffix,
              description: l10n.annualPlanDescription,
              isBestValue: true,
              l10n: l10n,
            ),

          const SizedBox(height: 16),

          Text(
            l10n.cancelAnytimeNote,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.washiDim,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handlePurchase(context, l10n),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kin,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                l10n.continueWithPlanButton(_planDisplayLabel(l10n, _selectedPlan)),
                style: const TextStyle(
                  color: AppColors.sumi,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(
    BuildContext context, {
    AppLocalizations? l10n,
    required String title,
    required String price,
    required String period,
    required String description,
    bool isBestValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isBestValue ? AppColors.kin : AppColors.sumiLine,
          width: isBestValue ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isBestValue
            ? AppColors.kin.withOpacity(0.1)
            : AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isBestValue)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.kin,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n!.bestValueBadge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.sumi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: price,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: period,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.faqTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(context, l10n.faqCancelQuestion, l10n.faqCancelAnswer),
          const SizedBox(height: 12),
          _buildFaqItem(context, l10n.faqPaymentQuestion, l10n.faqPaymentAnswer),
          const SizedBox(height: 12),
          _buildFaqItem(context, l10n.faqTrialQuestion, l10n.faqTrialAnswer),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.washiDim,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribedState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.wakatake.withOpacity(0.2),
              border: Border.all(
                color: AppColors.wakatake,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.check_circle,
              size: 60,
              color: AppColors.wakatake,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.subscribedTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.subscribedDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  /// 分析イベント用の安定した英語識別子（表示文言とは別に保つ:
  /// ログにはロケールに関わらず常に同じ値を送る必要があるため）。
  String _planLabel(SubscriptionPlan plan) => switch (plan) {
        SubscriptionPlan.monthly => 'Monthly',
        SubscriptionPlan.annual => 'Annual',
      };

  String _planDisplayLabel(AppLocalizations l10n, SubscriptionPlan plan) => switch (plan) {
        SubscriptionPlan.monthly => l10n.monthlyLabel,
        SubscriptionPlan.annual => l10n.annualLabel,
      };

  /// ストアの現地通貨価格。取得できない間は日本円の既定価格を出す
  /// （実際の請求額は常にストア側の設定が正）。
  String _priceLabel(SubscriptionPlan plan) {
    final product = ref.watch(subscriptionProductProvider(plan)).valueOrNull;
    if (product != null) return product.price;
    return switch (plan) {
      SubscriptionPlan.monthly => '¥300',
      SubscriptionPlan.annual => '¥2,400',
    };
  }

  ({double price, String currency}) _planPrice(SubscriptionPlan plan) {
    final product = ref.read(subscriptionProductProvider(plan)).valueOrNull;
    if (product != null) {
      return (price: product.rawPrice, currency: product.currencyCode);
    }
    return switch (plan) {
      SubscriptionPlan.monthly => (price: 300.0, currency: 'JPY'),
      SubscriptionPlan.annual => (price: 2400.0, currency: 'JPY'),
    };
  }

  void _handlePurchase(BuildContext context, AppLocalizations l10n) async {
    _logger.i('Processing purchase');

    final plan = _selectedPlan;
    final planLabel = _planLabel(plan).toLowerCase();
    final planDisplayLabel = _planDisplayLabel(l10n, plan);
    final price = _planPrice(plan);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.kin),
        ),
      ),
    );

    try {
      await ref.read(purchaseSubscriptionProvider)(plan);

      // The purchase itself already succeeded at this point — log the
      // conversion in its own try/catch so an analytics hiccup can't make
      // a real purchase get reported to the user as a failure below.
      try {
        await ref.read(logPaywallConvertedProvider)(
          plan: planLabel,
          price: price.price,
          currency: price.currency,
        );
      } catch (e) {
        _logger.w('Failed to log paywall conversion (purchase still succeeded): $e');
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.subscriptionActivatedMessage(planDisplayLabel)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to home after successful purchase
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    } on PurchaseUnavailableException catch (e) {
      _logger.w('Purchase unavailable: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _logger.e('Purchase failed: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseFailedMessage('$e')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
