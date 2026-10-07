import 'package:flutter/material.dart';

/// 画面下部に出す組織ロゴ（高さ40・下余白24・SafeAreaで端末の下端を避ける）。
///
/// 起動画面（StartupSplash）と既存のSplashScreenの両方で使う共通部品。
class OrgLogoFooter extends StatelessWidget {
  const OrgLogoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Semantics(
          label: 'Your Wish',
          child: Image.asset(
            'assets/branding/yourwish_logo.png',
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
