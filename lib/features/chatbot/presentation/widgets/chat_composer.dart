import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fix_up_moto/core/constants/chat_constants.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// The box at the bottom of the chat where the member writes a question.
///
/// Grows to a few lines as they type, stops at
/// [ChatConstants.maxMessageLength], and sends only text that is not blank —
/// and only while [canSend]: with Fima busy answering, the member can already
/// write the next question, but the button waits.
class ChatComposer extends StatefulWidget {
  /// False while Fima is answering the previous question.
  final bool canSend;

  /// Called with the trimmed text when the member sends it; the box is then
  /// cleared.
  final ValueChanged<String> onSend;

  const ChatComposer({super.key, required this.canSend, required this.onSend});

  /// The share of the limit from which the counter is shown.
  static const double counterFrom = 0.7;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.canSend) return;

    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        // The theme's divider colour (the light grey in light mode), so the line
        // is as soft as the one under the bar in dark mode too.
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? theme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // The field is white-filled in light mode, so in dark mode it
                // is a light-grey box on the black page — the scope gives its
                // text and hint the dark-on-light colours that needs.
                child: LightSurfaceScope(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ChatConstants.maxMessageLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Tulis pertanyaan…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: _border(AppColors.grey200),
                      enabledBorder: _border(AppColors.grey200),
                      focusedBorder: _border(AppColors.primary),
                    ),
                    // No counter until the limit is near; then "85/100". The
                    // limit is short, so "near" starts early.
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) =>
                            currentLength >=
                                (maxLength ?? 0) * ChatComposer.counterFrom
                            ? Text(
                                '$currentLength/$maxLength',
                                style: Theme.of(context).textTheme.labelSmall,
                              )
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Level with the field's first line, not floating above it when
              // the field grows.
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton.filled(
                  key: const Key('chat-send'),
                  tooltip: 'Kirim',
                  onPressed: _hasText && widget.canSend ? _send : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    disabledBackgroundColor: AppColors.grey200,
                    disabledForegroundColor: AppColors.grey400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(color: color),
  );
}
