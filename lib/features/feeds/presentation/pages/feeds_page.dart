import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_bloc.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_event.dart';
import 'package:fix_up_moto/features/feeds/presentation/bloc/feeds_state.dart';
import 'package:fix_up_moto/features/feeds/presentation/widgets/reel_player.dart';

/// Short-form video feed, sourced from Instagram via the fixupmoto-proxy
/// Vercel function — see [FeedConstants] and [FeedsRemoteDataSource].
///
/// No title bar: the reel underneath is meant to fill the screen edge to
/// edge, the same way TikTok/Reels/Shorts do. [AnnotatedRegion] still keeps
/// the OS status bar visible (never hidden/immersive) and forces its icons to
/// white so they read against a dark video background.
class FeedsPage extends StatelessWidget {
  const FeedsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FeedsBloc>()..add(const FeedsRequested()),
      child: const _FeedsView(),
    );
  }
}

class _FeedsView extends StatelessWidget {
  const _FeedsView();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<FeedsBloc, FeedsState>(
          builder: (context, state) {
            return switch (state) {
              FeedsInitial() || FeedsLoading() => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              FeedsError(:final message) => _ErrorView(
                message: message,
                onRetry: () =>
                    context.read<FeedsBloc>().add(const FeedsRequested()),
              ),
              FeedsLoaded(:final posts) => posts.isEmpty
                  ? const Center(
                      child: Text(
                        'No posts yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : _ReelsFeed(posts: posts),
            };
          },
        ),
      ),
    );
  }
}

class _ReelsFeed extends StatefulWidget {
  final List<FeedEntity> posts;
  const _ReelsFeed({required this.posts});

  @override
  State<_ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<_ReelsFeed> {
  final _controller = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // +1 for the end-of-feed card appended after the last real post — this is
    // a fixed list from one Instagram account, not an infinite algorithmic
    // queue, so looping back to post 1 would silently pass off old content as
    // new. Stopping honestly and offering a refresh matches how Instagram
    // itself behaves at the end of a single account's Reels.
    final itemCount = widget.posts.length + 1;

    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      itemCount: itemCount,
      onPageChanged: (index) => setState(() => _activeIndex = index),
      itemBuilder: (context, index) {
        if (index == widget.posts.length) {
          return _EndOfFeedCard(
            onRefresh: () =>
                context.read<FeedsBloc>().add(const FeedsRequested()),
          );
        }
        return ReelPlayer(
          key: ValueKey(widget.posts[index].id),
          post: widget.posts[index],
          isActive: index == _activeIndex,
        );
      },
    );
  }
}

/// Shown after the last fetched post. Refreshing re-dispatches
/// [FeedsRequested], which is also how any newly-posted content since the
/// tab was opened gets picked up — there's no separate polling mechanism.
class _EndOfFeedCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EndOfFeedCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 56, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                "You're all caught up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You've seen all the latest posts",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
