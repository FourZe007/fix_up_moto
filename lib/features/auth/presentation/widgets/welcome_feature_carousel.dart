import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// The card's text sizes and line heights. [_Slide] sets them and
/// [_WelcomeFeatureCarouselState._height] must leave room for exactly them, so
/// both read them from here.
const _titleSize = 16.0;
const _titleLeading = 1.3;
const _descriptionSize = 14.0;
const _descriptionLeading = 1.4;

/// One thing the app does, as the welcome screen's carousel shows it.
class WelcomeFeature {
  final IconData icon;
  final String title;
  final String description;

  const WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// The welcome screen's "what you can do here" carousel: one full-width card
/// per feature, swiped by hand or advancing by itself, with dots underneath.
///
/// Looks and paces like the promo carousel on Home (full-width pages, a
/// 400 ms slide every 4 s, a wide pill for the current dot), with three
/// differences:
/// - It is endless, so autoplay always moves forward and the last card leads
///   on to the first, instead of rewinding past the others.
/// - Autoplay stops while a finger is on it and resumes 4 s after the swipe
///   settles, so a card never moves out from under someone reading it.
/// - Autoplay is off when the OS asks for no animations.
class WelcomeFeatureCarousel extends StatefulWidget {
  const WelcomeFeatureCarousel({super.key});

  /// What the app does, in the three things members use most. These match
  /// Home's Booking and chat buttons and the Membership tab's points/vouchers.
  static const features = [
    WelcomeFeature(
      icon: Icons.calendar_month_outlined,
      title: 'Booking servis',
      description: 'Pilih bengkel dan jadwal servis langsung dari ponsel.',
    ),
    WelcomeFeature(
      icon: Icons.card_giftcard_outlined,
      title: 'Poin & voucher',
      description: 'Kumpulkan poin dari servis, tukar dengan voucher.',
    ),
    WelcomeFeature(
      icon: Icons.chat_bubble_outline,
      title: 'Chat dengan Fima',
      description: 'Tanya apa saja seputar servis ke asisten virtual kami.',
    ),
  ];

  /// The same pace as Home's promo carousel.
  static const autoPlayInterval = Duration(seconds: 4);
  static const slideDuration = Duration(milliseconds: 400);

  @override
  State<WelcomeFeatureCarousel> createState() => _WelcomeFeatureCarouselState();
}

class _WelcomeFeatureCarouselState extends State<WelcomeFeatureCarousel> {
  static const _features = WelcomeFeatureCarousel.features;

  /// The pager has no page before its first, so it starts this many laps in:
  /// that leaves as many to swipe back through, which is endless in practice.
  static const _laps = 1000;

  final _controller = PageController(initialPage: _features.length * _laps);

  /// Which feature is showing, 0 to the last. The pager itself counts in the
  /// thousands; this is that count modulo the features.
  int _page = 0;

  Timer? _autoPlay;

  /// A finger is on the carousel, or it is still settling after one.
  bool _touched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when the OS "remove animations" setting flips.
    if (!_touched) _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = null;
    // A card that moves on its own is the kind of motion that setting is for.
    if (MediaQuery.disableAnimationsOf(context)) return;

    _autoPlay = Timer.periodic(WelcomeFeatureCarousel.autoPlayInterval, (_) {
      if (!_controller.hasClients) return;
      // Always forward: the pager has no last page to rewind from.
      _controller.nextPage(
        duration: WelcomeFeatureCarousel.slideDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Pauses autoplay for a swipe and restarts its 4 s once the swipe settles.
  bool _onScroll(ScrollNotification notification) {
    // Only a finger counts: nextPage() above sends these too, with no drag.
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _touched = true;
      _autoPlay?.cancel();
      _autoPlay = null;
    } else if (notification is ScrollEndNotification && _touched) {
      _touched = false;
      _startAutoPlay();
    }
    return false; // not ours to swallow
  }

  /// The carousel's height: the card's fixed parts plus its text, which grows
  /// with the system text size (one title line and at most two of description,
  /// at the sizes set at the top of this file).
  double _height(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    const fixed = 16 + 44 + 10 + 4 + 16; // padding, icon, gaps, padding
    const text =
        _titleSize * _titleLeading + 2 * _descriptionSize * _descriptionLeading;
    return (fixed + text * textScale + 8).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _height(context),
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: PageView.builder(
              key: const Key('welcome-carousel'),
              controller: _controller,
              // No itemCount: no last page, so autoplay never has to rewind,
              // and `% length` picks the feature.
              onPageChanged: (index) =>
                  setState(() => _page = index % _features.length),
              itemBuilder: (context, index) =>
                  _Slide(feature: _features[index % _features.length]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _features.length; i++)
              AnimatedContainer(
                key: Key('welcome-dot-$i'),
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : AppColors.grey400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One card: a solid brand-orange tile with the feature's icon, over its title
/// and a line about it, on the same peach as the Membership tab's point card.
///
/// The card is peach in light and dark mode alike, so its text colours are set
/// here rather than taken from the theme (whose body text is white in dark mode
/// and a grey too pale for peach in light mode).
class _Slide extends StatelessWidget {
  final WelcomeFeature feature;

  const _Slide({required this.feature});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.peachLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.peach),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The same tile as the Membership tab's owned vouchers.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    feature.icon,
                    size: 24,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // One line for the title and at most two for the text, so the
              // card's height is known and _height() can set it.
              Text(
                feature.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: _titleLeading,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: _descriptionSize,
                  // Dark enough for 4.5:1 on peach; the theme's grey is not.
                  color: AppColors.grey700,
                  height: _descriptionLeading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
