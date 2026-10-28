import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_failure_text.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/fima_avatar.dart';

/// One message in the chat: the member's on the right in the brand colour,
/// Fima's on the left on a white bubble with her avatar.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// Called when the member taps "try again" on a message that failed. Null
  /// while that cannot be done (Fima is busy with another question), which
  /// also takes the invitation out of the text.
  final VoidCallback? onRetry;

  /// Called when the member taps "Hubungi petugas" under an answer Fima could
  /// not give ([ChatMessage.unanswered]). Null takes the button away.
  final VoidCallback? onContactAgent;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onContactAgent,
  });

  /// How much of the screen's width a bubble may take.
  static const double maxWidthFactor = 0.78;

  static const _radius = Radius.circular(18);
  static const _tail = Radius.circular(4);

  /// "07:05" — the same in every locale, which is what a chat shows.
  static String clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * maxWidthFactor;

    return Semantics(
      container: true,
      label: '${message.isFromUser ? 'Anda' : 'Fima'}: ${message.text}',
      excludeSemantics: true,
      child: message.isFromUser
          ? _UserMessage(message: message, maxWidth: maxWidth, onRetry: onRetry)
          : _FimaMessage(
              message: message,
              maxWidth: maxWidth,
              onContactAgent: onContactAgent,
            ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  final ChatMessage message;
  final double maxWidth;
  final VoidCallback? onRetry;

  const _UserMessage({
    required this.message,
    required this.maxWidth,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final sending = message.status == ChatMessageStatus.sending;
    final failed = message.status == ChatMessageStatus.failed;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Dimmed until it has gone through.
            Opacity(
              opacity: sending ? 0.7 : 1,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: ChatBubble._radius,
                    topRight: ChatBubble._radius,
                    bottomLeft: ChatBubble._radius,
                    bottomRight: ChatBubble._tail,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // A clock while it is still being sent, then the time.
                      sending
                          ? const Icon(
                              Icons.schedule,
                              key: Key('chat-sending'),
                              size: 12,
                              color: Colors.white70,
                            )
                          : Text(
                              ChatBubble.clock(message.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            if (failed) _FailedNote(message: message, onRetry: onRetry),
          ],
        ),
      ),
    );
  }
}

/// The line under a message that did not go through: why, and — when it can be
/// tried again — a tap target to do so.
class _FailedNote extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _FailedNote({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // The usual red is too dark to read on a dark page (about 3 : 1).
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF8A80)
        : AppColors.error;

    final note = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              onRetry == null
                  ? chatFailureText(message.failure)
                  : '${chatFailureText(message.failure)} · Ketuk untuk coba lagi',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (onRetry == null) return note;
    return InkWell(
      key: const Key('chat-retry'),
      onTap: onRetry,
      borderRadius: BorderRadius.circular(8),
      child: note,
    );
  }
}

class _FimaMessage extends StatelessWidget {
  final ChatMessage message;
  final double maxWidth;
  final VoidCallback? onContactAgent;

  const _FimaMessage({
    required this.message,
    required this.maxWidth,
    required this.onContactAgent,
  });

  @override
  Widget build(BuildContext context) {
    return FimaBubbleRow(
      maxWidth: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selectable, so an answer can be copied.
          SelectableText(
            message.text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          // Fima had nothing to say: a person might.
          if (message.unanswered && onContactAgent != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const Key('chat-agent-inline'),
                onPressed: onContactAgent,
                icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                label: const Text('Hubungi petugas lewat WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.peachLight,
                  foregroundColor: AppColors.primaryDark,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            ChatBubble.clock(message.createdAt),
            style: const TextStyle(color: AppColors.grey600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Fima's side of the conversation: her avatar, then a white bubble around
/// [child]. Shared by her answers and her "typing" indicator.
class FimaBubbleRow extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const FimaBubbleRow({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const FimaAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              // A white bubble in light mode is light grey in dark mode, and
              // its text must then be dark — which is what this scope is for.
              child: LightSurfaceScope(
                child: Builder(
                  builder: (context) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: AppColors.grey200),
                      borderRadius: const BorderRadius.only(
                        topLeft: ChatBubble._radius,
                        topRight: ChatBubble._radius,
                        bottomRight: ChatBubble._radius,
                        bottomLeft: ChatBubble._tail,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
