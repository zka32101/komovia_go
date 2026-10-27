import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/services/direct_message_service.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/utils/dm_presets.dart';

final _logger = Logger();

/// フレンドとの1対1チャット画面。フレンド一覧からの遷移のみを想定して
/// いるため（通知やディープリンクからの直接遷移は無い）、名前付きルート
/// ではなくウィジェット引数で現在/相手のuid・表示名を受け取る
/// （FriendProfileScreenと同じ方針）。
class ChatScreen extends ConsumerStatefulWidget {
  final String currentUid;
  final String currentDisplayName;
  final String friendUid;
  final String friendDisplayName;

  const ChatScreen({
    super.key,
    required this.currentUid,
    required this.currentDisplayName,
    required this.friendUid,
    required this.friendDisplayName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  late final String _threadId;

  @override
  void initState() {
    super.initState();
    _threadId = DirectMessageService.threadIdFor(widget.currentUid, widget.friendUid);
    // 既読化はスレッドが無くても安全（markThreadReadはmergeのset）。
    ref.read(markThreadReadProvider)(threadId: _threadId, uid: widget.currentUid);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String content) async {
    try {
      await ref.read(sendDirectMessageProvider)(
        fromUid: widget.currentUid,
        fromDisplayName: widget.currentDisplayName,
        toUid: widget.friendUid,
        toDisplayName: widget.friendDisplayName,
        content: content,
      );
      // 送信直後に自分の既読カウントも0のまま保つ（相手宛のunreadだけが
      // 増える実装なので、ここでは何もしなくてよい）。
    } catch (e) {
      _logger.e('Failed to send direct message: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.messageSendFailedMessage)),
        );
      }
    }
  }

  /// プリセット文言/絵文字の一覧シートを開く。相手を煽る・中傷するような
  /// 自由入力を一切許さない方針のため、ChatScreenには自由入力欄を置かず、
  /// ここで選んだものがそのまま送信される（タップ=送信、プレビュー無し）。
  Future<void> _openPresetPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sumiSurface,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.dmPresetPickerTitle,
                  style: const TextStyle(color: AppColors.washi, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dmPresetLabels(japanese: isJapanese)
                      .map(
                        (label) => ActionChip(
                          label: Text(label),
                          backgroundColor: AppColors.sumiCard,
                          labelStyle: const TextStyle(color: AppColors.washi),
                          onPressed: () => Navigator.pop(sheetContext, label),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dmAllowedEmoji
                      .map(
                        (emoji) => ActionChip(
                          label: Text(emoji, style: const TextStyle(fontSize: 20)),
                          backgroundColor: AppColors.sumiCard,
                          onPressed: () => Navigator.pop(sheetContext, emoji),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _send(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.watch(threadMessagesProvider(_threadId));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(widget.friendDisplayName),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noMessagesYetMessage,
                        style: const TextStyle(color: AppColors.washiDim),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.fromUid == widget.currentUid;
                      return _MessageBubble(content: message.content, isMine: isMine);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
              ),
            ),
            _buildInputRow(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(AppLocalizations l10n) {
    // 相手を煽る・中傷するような自由入力を一切許さない方針のため、自由
    // テキスト入力欄は置かず、決められたフレーズ/絵文字を選ぶボタンのみ。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.sumiSurface,
        border: Border(top: BorderSide(color: AppColors.sumiLine)),
      ),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          onPressed: _openPresetPicker,
          icon: const Icon(Icons.chat_bubble_outline, color: AppColors.kin),
          label: Text(
            l10n.dmPresetPickerButton,
            style: const TextStyle(color: AppColors.washi),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.sumiLine),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMine;

  const _MessageBubble({required this.content, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.kin : AppColors.sumiCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          content,
          style: TextStyle(color: isMine ? AppColors.sumi : AppColors.washi),
        ),
      ),
    );
  }
}
