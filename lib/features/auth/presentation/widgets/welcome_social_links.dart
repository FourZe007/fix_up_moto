import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

/// One of FixUp Moto's public pages, as the welcome screen's footer shows it.
class SocialLink {
  /// Short and stable: part of the icon's widget key.
  final String id;

  /// What the page is called, for the icon's label and the messages about it.
  final String name;

  /// A Font Awesome brand glyph: Material's icons have no Instagram or TikTok.
  final FaIconData icon;

  /// The full https:// address; empty while the real one has not been set.
  final String url;

  const SocialLink({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
  });

  bool get isSet => url.trim().isNotEmpty;
}

/// The welcome screen's quiet footer: "Ikuti kami" over one small grey icon per
/// public page, each opening that page in its own app (or the browser). The
/// label and the icons are centred on the same axis as the buttons above.
///
/// It is a footer on purpose — small and grey, under the "Masuk" line — so that
/// "Get started" stays the loudest thing on a screen whose job is to get a
/// visitor to register. A logged-out visitor cannot reach Profile, so this is
/// the only place they can see the business is real.
///
/// A link whose address is still empty ([SocialLink.isSet]) is hidden in a
/// release build, so a button that goes nowhere can never ship. With
/// [showUnset] (on in debug and profile builds) it is shown as a placeholder
/// that says it is not set yet, so the design can be judged by simply running
/// the app. When nothing is left to show, the whole footer — label included —
/// is left out.
class WelcomeSocialLinks extends StatelessWidget {
  /// Instagram first, then TikTok.
  static const defaultLinks = [
    SocialLink(
      id: 'instagram',
      name: 'Instagram',
      icon: FontAwesomeIcons.instagram,
      url: AppConstants.instagramUrl,
    ),
    SocialLink(
      id: 'tiktok',
      name: 'TikTok',
      icon: FontAwesomeIcons.tiktok,
      url: AppConstants.tiktokUrl,
    ),
  ];

  final List<SocialLink> links;
  final bool showUnset;

  const WelcomeSocialLinks({
    super.key,
    this.links = defaultLinks,
    this.showUnset = !kReleaseMode,
  });

  /// Opens [link] outside the app; says so if it cannot, or is not set yet.
  Future<void> _open(BuildContext context, SocialLink link) async {
    // Resolved before the await, so the context is not used across the gap.
    final messenger = ScaffoldMessenger.of(context);

    if (!link.isSet) {
      messenger.showSnackBar(
        SnackBar(content: Text('Link ${link.name} belum diatur')),
      );
      return;
    }

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(link.url),
        // Hands the link to the Instagram / TikTok app (or the browser) rather
        // than an in-app web view, which cannot open them.
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // A malformed address or no handler: reported below, same as `false`.
    }

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('${link.name} tidak dapat dibuka')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final link in links)
        if (link.isSet || showUnset) link,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    // One row, centred as a whole: the label, then the icons. It is the group
    // that is centred on the page's axis (where "Get started" and "Masuk" are),
    // not the pair of icons on their own.
    return Row(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Flexible, so at a very large text size or on a very narrow screen the
        // label wraps instead of overflowing the row.
        const Flexible(child: Text('Ikuti kami', textAlign: TextAlign.center)),
        // A Wrap, not a Row: with many links it flows onto a second line
        // instead of overflowing. Every icon button is the same size, 8 px
        // apart.
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final link in shown)
              IconButton(
                key: Key('welcome-social-${link.id}'),
                // Also the icon's label for screen readers.
                tooltip: link.name,
                onPressed: () => _open(context, link),
                color: AppColors.grey600,
                // Snug around the glyph. The default 48 x 48 box leaves ~15 px
                // of empty space on each side of the icon, which made two
                // neighbouring icons ~30 px apart. Now each button is the glyph
                // plus 4 px a side (about 25 wide) by 44 tall.
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  // Without this the button still claims a 48 x 48 layout box.
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: FaIcon(link.icon, size: 20),
              ),
          ],
        ),
      ],
    );
  }
}
