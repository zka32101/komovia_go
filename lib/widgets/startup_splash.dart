import 'package:flutter/material.dart';

import 'org_logo_footer.dart';

/// 起動中の読み込み画面（中央に進行表示、下部に組織ロゴ）。
///
/// 初期化（Firebase・広告など）が終わる前に出す。app_common_kit の
/// `StartupSplash` と同じ見た目を、アプリ内に持たせたもの。
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          Expanded(child: Center(child: CircularProgressIndicator())),
          OrgLogoFooter(),
        ],
      ),
    );
  }
}
