import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_bloc.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_event.dart';
import 'package:fix_up_moto/features/chatbot/presentation/bloc/chat_state.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_bubble.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_composer.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_empty_state.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/fima_avatar.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/typing_indicator.dart';

/// Chat with Fima, the app's virtual customer service.
///
/// The member writes a question, it goes out as a bubble, and Fima's answer
/// comes back as hers. A question that cannot be answered stays on screen,
/// marked, with a tap to try again — nothing is ever dropped quietly. The
/// conversation is kept for the rest of the app session, so leaving the page
/// and coming back picks up where it was.
class ChatbotPage extends StatelessWidget {
  const ChatbotPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The conversation belongs to the signed-in member. The route is behind the
    // auth guard, so there always is one; the empty id is only a fallback that
    // never matches anybody's kept chat.
    final authState = context.read<AuthBloc>().state;
    final memberId = authState is AuthAuthenticated ? authState.user.id : '';

    return BlocProvider(
      create: (_) => sl<ChatBloc>()..add(ChatStarted(memberId)),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the newest message into view. The list is reversed, so its
  /// "bottom" — where the newest message is — is offset 0.
  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;

      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text) =>
      context.read<ChatBloc>().add(ChatMessageSent(text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _ChatAppBar(),
      body: BlocConsumer<ChatBloc, ChatState>(
        // A new bubble, or the typing indicator appearing or going: show it.
        listenWhen: (previous, current) =>
            previous.messages.length != current.messages.length ||
            previous.replying != current.replying,
        listener: (context, state) => _scrollToNewest(),
        builder: (context, state) {
          return Column(
            children: [
              Expanded(child: _body(context, state)),
              ChatComposer(canSend: !state.replying, onSend: _send),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, ChatState state) {
    // Not looked up yet: show nothing rather than the empty-chat greeting for
    // a moment before the kept messages appear.
    if (!state.loaded) return const SizedBox.shrink();

    if (state.messages.isEmpty && !state.replying) {
      return ChatEmptyState(onSuggestion: _send);
    }

    final messages = state.messages;

    return ListView.builder(
      key: const Key('chat-list'),
      controller: _scroll,
      // Newest at the bottom, and staying there as messages are added.
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      itemCount: messages.length + (state.replying ? 1 : 0),
      itemBuilder: (context, index) {
        // Index 0 is the bottom: the typing indicator while Fima answers, then
        // the messages, newest first.
        if (state.replying) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: TypingIndicator(),
            );
          }
          index -= 1;
        }

        final message = messages[messages.length - 1 - index];

        return Padding(
          key: ValueKey(message.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatBubble(
            message: message,
            // Not while Fima is busy with another question: it would be
            // ignored, so it is not offered.
            onRetry: state.replying
                ? null
                : () => context.read<ChatBloc>().add(
                    ChatRetryRequested(message.id),
                  ),
          ),
        );
      },
    );
  }
}

/// The page's top bar, set up like the app's other pages (flat, in the page's
/// own colour, a `leading` back arrow), with Fima's name and badge as its
/// title.
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    // Colours come from the active Theme, so the bar follows light/dark. The
    // title and arrow are coloured explicitly because the app's AppBarTheme
    // hard-codes a white title style.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      // Same colour as the page behind it, so the bar blends into the body.
      backgroundColor: theme.scaffoldBackgroundColor,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        style: IconButton.styleFrom(foregroundColor: onSurface),
        // Opened from Home, so normally there is a page to go back to; with
        // none (a restored session) go Home instead of failing.
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(RouteNames.home),
      ),
      title: Row(
        children: [
          const FimaAvatar(size: 36),
          const SizedBox(width: 12),
          // Flexible, with ellipses: at a large system text size on a narrow
          // screen the name would otherwise push the row past the bar.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fima',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Asisten virtual',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
