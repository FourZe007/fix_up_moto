import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/chat_bubble.dart';

/// Fima's "typing" bubble: three dots that pulse one after another while her
/// answer is on its way. Still (all three dots lit) when the OS asks for no
/// animations.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when the OS "remove animations" setting flips.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How lit dot [index] is, 0.35 to 1: a swell that travels along the row.
  double _glow(int index) {
    if (!_controller.isAnimating) return 1;
    final phase = (_controller.value - index * 0.18) % 1;
    return 0.35 + 0.65 * math.max(0, math.sin(phase * math.pi));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fima sedang mengetik',
      excludeSemantics: true,
      child: FimaBubbleRow(
        maxWidth: MediaQuery.sizeOf(context).width * ChatBubble.maxWidthFactor,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  child: Opacity(
                    opacity: _glow(i),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.grey600,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
