import 'package:flutter/material.dart';
import '../../models/index.dart';
import 'package:komovia_go/config/theme.dart';

/// Dialog for selecting a platform to share on
class ShareDialog extends StatelessWidget {
  final ShareContent content;
  final Function(SocialPlatform platform) onShare;

  const ShareDialog({Key? key, required this.content, required this.onShare})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sumiSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'シェア先を選択',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.washi,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.washi),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              // Platform buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _PlatformButton(
                      icon: Icons.favorite,
                      label: 'X (Twitter)',
                      color: AppColors.aiLight,
                      onTap: () {
                        onShare(SocialPlatform.twitter);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _PlatformButton(
                      icon: Icons.groups,
                      label: 'Facebook',
                      color: AppColors.aiLight,
                      onTap: () {
                        onShare(SocialPlatform.facebook);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _PlatformButton(
                      icon: Icons.chat,
                      label: 'WhatsApp',
                      color: AppColors.wakatake,
                      onTap: () {
                        onShare(SocialPlatform.whatsapp);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _PlatformButton(
                      icon: Icons.textsms,
                      label: 'LINE',
                      color: AppColors.wakatake,
                      onTap: () {
                        onShare(SocialPlatform.line);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _PlatformButton(
                      icon: Icons.content_copy,
                      label: 'クリップボードにコピー',
                      color: AppColors.washiDim,
                      onTap: () {
                        onShare(SocialPlatform.clipboard);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Preview
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.washiDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'プレビュー',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.washiDim,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single platform button in share dialog
class _PlatformButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PlatformButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.washiDim,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.washiDim),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.washi,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: AppColors.washiDim, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
