import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// Displays the privacy policy or terms of service in-app.
///
/// This is boilerplate reflecting what the app's own code actually does
/// (Firebase Auth/Firestore/Analytics/Crashlytics, in-app purchases via
/// the platform store) — not a substitute for legal review before a real
/// store submission. Replace the bracketed placeholders (contact email,
/// company/developer name) before release.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentKind kind;

  const LegalDocumentScreen({Key? key, required this.kind}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = kind == LegalDocumentKind.privacyPolicy
        ? l10n.privacyPolicyButton
        : l10n.termsOfServiceButton;
    final body = kind == LegalDocumentKind.privacyPolicy
        ? l10n.privacyPolicyBodyText(_lastUpdated)
        : l10n.termsOfServiceBodyText(_lastUpdated);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.sumi,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          body,
          style: const TextStyle(color: AppColors.washiDim, height: 1.6, fontSize: 14),
        ),
      ),
    );
  }
}

enum LegalDocumentKind { privacyPolicy, termsOfService }

const _lastUpdated = '2026-09-20';
