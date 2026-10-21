import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';

/// The FixUp Moto brand mark, shown on the welcome screen.
///
/// [AssetConstants.logoRedText] is a transparent 500x500 PNG with red lettering
/// in the middle and a lot of empty canvas around it, so it is drawn straight
/// onto the page with no box behind it, cropped to the lettering. It fades and
/// slides in briefly on first appearance.
///
/// Sized by [width] alone (the crop fixes the height at half of it) and placed
/// by its parent — put it in a `Center`, or a Column that is not stretching.
class AuthLogo extends StatelessWidget {
  /// How wide the cropped logo is drawn, in logical pixels.
  final double width;

  const AuthLogo({super.key, this.width = 144});

  /// The part of the source image that is kept, as a fraction of its sides.
  /// The lettering is about 391x189 of the 500x500 canvas and centred in it, so
  /// a centred 400x200 window frames it with a few pixels to spare.
  static const double _widthFactor = 0.8;
  static const double _heightFactor = 0.4;

  /// The lettering's colour in the PNG, which the fallback text below matches
  /// so a missing asset still leaves a recognisable mark.
  static const Color red = Color(0xFFFE0000);

  static const Duration _entrance = Duration(milliseconds: 400);
  static const double _slide = 12;

  @override
  Widget build(BuildContext context) {
    // The side the whole canvas is drawn at, so that the kept window comes out
    // exactly [width] wide. The lettering is 391 source pixels wide, so the
    // image is sharpest up to about 130 logical px of lettering on a 3x phone;
    // past that it is stretched (see FilterQuality.high below).
    final sourceSide = width / _widthFactor;
    final height = sourceSide * _heightFactor;

    // Respect the OS "remove animations" setting.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _entrance;

    // Plays once, when the page first shows it. The page rebuilds on every
    // state change, but a TweenAnimationBuilder whose end value is unchanged
    // does not restart.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _slide),
          child: child,
        ),
      ),
      child: SizedBox(
        key: const Key('auth-logo-box'),
        width: width,
        height: height,
        // The canvas is drawn bigger than the box and centred, so only its
        // middle window is inside the box. What spills over is transparent.
        child: OverflowBox(
          maxWidth: sourceSide,
          maxHeight: sourceSide,
          child: Image.asset(
            AssetConstants.logoRedText,
            key: const Key('auth-logo-image'),
            width: sourceSide,
            height: sourceSide,
            // Bicubic rather than the default bilinear: when the logo is drawn
            // larger than the file can fill, it keeps edges smoother.
            filterQuality: FilterQuality.high,
            // Decode at the size it is drawn at (Flutter never upscales past
            // the file's own 500 px).
            cacheWidth: (sourceSide * MediaQuery.devicePixelRatioOf(context))
                .round(),
            semanticLabel: 'FixUp Moto',
            // Same colour and name as the real thing, so a missing asset
            // still leaves a recognisable mark.
            errorBuilder: (_, _, _) => const Center(
              child: Text(
                'FIXUP MOTO',
                style: TextStyle(
                  color: red,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
