import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';

/// One full-screen reel. Only initialises its [VideoPlayerController] while
/// [isActive] is true — the page above/below it in the feed stays a static
/// thumbnail until the user actually swipes to it. This is what keeps a
/// vertical feed from playing several videos' audio at once and from holding
/// a dozen live decoders in memory.
class ReelPlayer extends StatefulWidget {
  final FeedEntity post;
  final bool isActive;

  const ReelPlayer({super.key, required this.post, required this.isActive});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  VideoPlayerController? _controller;
  bool _muted = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initController();
  }

  @override
  void didUpdateWidget(covariant ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initController();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  Future<void> _initController() async {
    if (!widget.post.isVideo) return; // image posts have nothing to play
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _muted = !_muted;
      controller.setVolume(_muted ? 0 : 1);
    });
  }

  Future<void> _openOnInstagram() async {
    final uri = Uri.parse(widget.post.permalink);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail shown until the video is ready, and permanently for
            // non-video posts (IMAGE / CAROUSEL_ALBUM).
            if (widget.post.thumbnailUrl != null)
              Image.network(
                widget.post.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else if (_failed)
              const Center(
                child: Icon(Icons.error_outline, color: Colors.white54, size: 40),
              )
            else if (widget.post.isVideo)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Play icon flash when paused by a tap
            if (ready && !controller.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, color: Colors.white70, size: 72),
              ),

            _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    widget.post.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    if (widget.post.isVideo)
                      _ActionButton(
                        icon: _muted ? Icons.volume_off : Icons.volume_up,
                        onTap: _toggleMute,
                      ),
                    const SizedBox(height: 16),
                    _ActionButton(
                      icon: Icons.open_in_new,
                      onTap: _openOnInstagram,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 28),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
      ),
    );
  }
}
