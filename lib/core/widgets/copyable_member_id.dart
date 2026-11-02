import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// How [CopyableMemberId] is drawn.
enum CopyableMemberIdStyle {
  /// A pale-peach pill: an "ID" tag, the number and the copy icon in one
  /// tappable shape. For the Profile header, where it has to read as something
  /// to tap.
  pill,

  /// The number with the copy icon beside it and no shape of its own. For a
  /// surface that is already white, such as the member QR popup.
  plain,
}

/// A member ID that can be copied: the number with a copy icon beside it, the
/// whole thing one tap target.
///
/// Tapping puts the ID on the clipboard, swaps the icon for a green check for
/// [copiedFor], and (unless [showSnackBar] is off) says "ID Member disalin" in a
/// snackbar. Android 13 and later add their own "copied" notice on top.
///
/// The ID is shown and copied trimmed, exactly as it is otherwise: never
/// reformatted or grouped, since whoever pastes it needs the original.
///
/// It scales down rather than overflowing when the space it is given is
/// narrower than the 16 digits, so a small phone or a large font cannot break
/// the layout around it.
class CopyableMemberId extends StatefulWidget {
  /// How long the check shows, and the snackbar with it.
  static const Duration copiedFor = Duration(seconds: 2);

  final String memberId;
  final CopyableMemberIdStyle style;

  /// Whether copying also shows a snackbar. Off inside a dialog: the snackbar
  /// belongs to the page under it, which the dialog's barrier dims and half
  /// hides, so there the check is the confirmation.
  final bool showSnackBar;

  /// The number's own style in [CopyableMemberIdStyle.plain], so it can match
  /// the text around it. The pill sets its own.
  final TextStyle? textStyle;

  const CopyableMemberId({
    super.key,
    required this.memberId,
    this.style = CopyableMemberIdStyle.pill,
    this.showSnackBar = true,
    this.textStyle,
  });

  @override
  State<CopyableMemberId> createState() => _CopyableMemberIdState();
}

class _CopyableMemberIdState extends State<CopyableMemberId> {
  static const String _label = 'Salin ID Member';

  bool _copied = false;
  Timer? _resetTimer;

  String get _id => widget.memberId.trim();

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _id));
    if (!mounted) return;

    setState(() => _copied = true);
    // A second tap restarts the countdown instead of racing the first one.
    _resetTimer?.cancel();
    _resetTimer = Timer(CopyableMemberId.copiedFor, () {
      if (mounted) setState(() => _copied = false);
    });

    if (widget.showSnackBar) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('ID Member disalin'),
            duration: CopyableMemberId.copiedFor,
          ),
        );
    }
  }

  Widget _icon() {
    return Icon(
      _copied ? Icons.check : Icons.content_copy,
      size: 16,
      color: _copied ? AppColors.success : AppColors.primary,
    );
  }

  Widget _pill(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;

    return Material(
      color: AppColors.peachMist,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(
        side: BorderSide(
          color: _copied
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.peachHairline,
        ),
      ),
      child: InkWell(
        onTap: _copy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                'ID',
                style: base?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                _id,
                style: base?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  // Digits of equal width, so the number does not shift.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              _icon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plain(BuildContext context) {
    final style =
        widget.textStyle ??
        Theme.of(context).textTheme.titleSmall ??
        const TextStyle();

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                _id,
                style: style.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              _icon(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPill = widget.style == CopyableMemberIdStyle.pill;

    // One button for a screen reader, reading the ID it would copy; the text
    // and icon inside it are not separate stops.
    return Semantics(
      button: true,
      label: '$_label $_id',
      onTap: _copy,
      excludeSemantics: true,
      child: Tooltip(
        message: _label,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isPill ? Alignment.centerLeft : Alignment.center,
          child: isPill ? _pill(context) : _plain(context),
        ),
      ),
    );
  }
}
