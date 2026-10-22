import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// Asks the member to confirm something, in a panel that slides up from the
/// bottom. Reached through [ConfirmPanelScope.of].
abstract interface class ConfirmPanel {
  /// Slides the panel up and resolves to `true` if the member pressed the
  /// confirm button, `false` for Batal, a tap outside, a drag down or the
  /// system back button.
  ///
  /// It resolves only once the panel has finished sliding away, so whatever the
  /// caller does next (a sign-out that makes the router replace the page, say)
  /// never overlaps the animation. Returns `false` straight away when a
  /// confirmation is already open.
  Future<bool> confirm({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Batal',
    bool destructive = false,
  });
}

/// Hosts the confirmation panel for the page below it — the replacement for
/// `showDialog` — and blurs the whole screen behind it while it is open.
///
/// The panel is mounted in the app's root Overlay, above the page's Scaffold
/// and `MainShell`'s bottom bar, for the same reason as the Bookings filter
/// panel (see BookingsPage._insertFilterOverlay): inside the page it could only
/// ever slide up *underneath* the bar. Its lifetime is this widget's, like the
/// other panels in the app: inserted after the first frame, removed on dispose.
///
/// Needs the app's `MaterialApp.router`: the system back button is claimed
/// through the Router while the panel is open.
class ConfirmPanelScope extends StatefulWidget {
  final Widget child;

  const ConfirmPanelScope({super.key, required this.child});

  /// The nearest scope above [context]; there must be one.
  static ConfirmPanel of(BuildContext context) {
    final state = context.findAncestorStateOfType<_ConfirmPanelScopeState>();
    assert(state != null, 'No ConfirmPanelScope above this context');
    return state!;
  }

  @override
  State<ConfirmPanelScope> createState() => _ConfirmPanelScopeState();
}

class _ConfirmRequest {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final completer = Completer<bool>();

  _ConfirmRequest({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });
}

class _ConfirmPanelScopeState extends State<ConfirmPanelScope>
    implements ConfirmPanel {
  /// How far the background is blurred when the panel is fully open.
  static const _maxBlurSigma = 8.0;

  /// Panel height while nothing is being asked: it is never seen, but the
  /// package wants a maxHeight above its minHeight.
  static const _idleHeight = 200.0;

  /// Side padding of the panel's content, which is also what the message wraps
  /// inside — kept here so the height is measured at the width it is drawn at.
  static const _sidePadding = 20.0;

  final _controller = PanelController();

  /// The panel's position, 0 (closed) to 1 (open); drives the blur.
  final _slide = ValueNotifier<double>(0);

  OverlayEntry? _entry;
  _ConfirmRequest? _request;

  /// What the open request resolves to. Only the confirm button sets it, so a
  /// tap outside, a drag down or back all end as `false`.
  bool _confirmed = false;

  /// Whether the panel has left position 0 since it was asked to open. The
  /// package reports "closed" on the first tick of the opening animation too
  /// (the value is still 0 then), and that must not end the request.
  bool _seenOpen = false;

  /// Hides the page behind the panel from screen readers while it is open —
  /// the barrier `showDialog` gave for free.
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertOverlay());
  }

  void _insertOverlay() {
    if (!mounted) return;
    final entry = OverlayEntry(builder: _buildLayer);
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  void dispose() {
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
    _slide.dispose();
    final request = _request;
    if (request != null && !request.completer.isCompleted) {
      request.completer.complete(false);
    }
    super.dispose();
  }

  @override
  Future<bool> confirm({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Batal',
    bool destructive = false,
  }) {
    // Not mounted into the Overlay yet (a tap in the first frames), or already
    // asking something.
    if (_request != null || !_controller.isAttached) return Future.value(false);

    final request = _ConfirmRequest(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    );
    _request = request;
    _confirmed = false;
    _seenOpen = false;
    setState(() => _open = true);
    // The overlay entry lives outside this widget's subtree, so setState does
    // not reach it; it has to be told to build the new content before opening.
    _entry?.markNeedsBuild();
    _controller.open();
    return request.completer.future;
  }

  void _resolve({required bool confirmed}) {
    _confirmed = confirmed;
    _controller.close();
  }

  /// Back closes the panel instead of leaving the page (MainShell would send
  /// the member Home); with nothing open it is left to the router.
  Future<bool> _onBack() async {
    if (_request == null) return false;
    _resolve(confirmed: false);
    return true;
  }

  void _onSlide(double position) {
    _slide.value = position;
    if (position > 0) _seenOpen = true;
  }

  void _onClosed() {
    final request = _request;
    // Idempotent: the package reports "closed" on every tick at 0.
    if (request == null || !_seenOpen) return;
    _request = null;
    _seenOpen = false;
    if (mounted) setState(() => _open = false);
    // Drops the content: the package builds its panel even while it is closed.
    _entry?.markNeedsBuild();
    request.completer.complete(_confirmed);
  }

  // ── Layout ──────────────────────────────────────────────────────────────

  static double _textHeight(
    String text,
    TextStyle? style,
    double width,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// The panel is a fixed height, so it is worked out from what it holds —
  /// the message is measured at the width and text scale it will be drawn at —
  /// rather than guessed, which would leave a gap under the buttons or clip
  /// them.
  double _panelHeight(BuildContext context, _ConfirmRequest? request) {
    if (request == null) return _idleHeight;

    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final textWidth = media.size.width - 2 * _sidePadding;
    // Only the sizes matter here, and they are the same in the light-surface
    // theme the content is drawn in.
    final title = _textHeight(
      request.title,
      _ConfirmPanelContent.titleStyle(theme),
      textWidth,
      media.textScaler,
    );
    final message = _textHeight(
      request.message,
      _ConfirmPanelContent.messageStyle(theme),
      textWidth,
      media.textScaler,
    );

    final height =
        12 + // top padding
        20 + // drag handle and its gap
        56 + // icon tile
        16 +
        title +
        8 +
        message +
        24 +
        _ConfirmPanelContent.buttonHeight +
        20 + // bottom padding
        media.viewPadding.bottom;
    return math.min(height, media.size.height * 0.9);
  }

  Widget _buildLayer(BuildContext context) {
    final request = _request;

    return Positioned.fill(
      child: BackButtonListener(
        onBackButtonPressed: _onBack,
        child: Stack(
          children: [
            // The blur sits under the panel and over everything else in the
            // app, the bottom bar included. The package has no blur of its own,
            // so it follows the panel's position. Nothing is built at rest.
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _slide,
                builder: (context, position, _) {
                  if (position <= 0) return const SizedBox.shrink();
                  final sigma = _maxBlurSigma * position;
                  return IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: SlidingUpPanel(
                controller: _controller,
                minHeight: 0,
                maxHeight: _panelHeight(context, request),
                // Defaults to false — without it the package never builds its
                // dim / tap-to-close layer (same gotcha as Bookings' panel).
                // Black and light, so the blur shows through it.
                backdropEnabled: true,
                backdropColor: Colors.grey,
                backdropOpacity: 0.2,
                backdropTapClosesPanel: true,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                // The package default is white; read from the theme so it is
                // light grey in dark mode, like the other panels.
                color: Theme.of(context).colorScheme.surface,
                onPanelSlide: _onSlide,
                onPanelClosed: _onClosed,
                panel: request == null
                    ? const SizedBox.shrink()
                    : LightSurfaceScope(
                        child: _ConfirmPanelContent(
                          request: request,
                          onCancel: () => _resolve(confirmed: false),
                          onConfirm: () => _resolve(confirmed: true),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The same child instance every build, so toggling this only updates the
    // semantics flag; the page is not rebuilt.
    return ExcludeSemantics(
      key: const Key('confirm-panel-page-barrier'),
      excluding: _open,
      child: widget.child,
    );
  }
}

/// What is inside the panel: a drag handle, an icon tile, the title and
/// message, and the Batal / confirm buttons side by side.
class _ConfirmPanelContent extends StatelessWidget {
  /// Both buttons' height; the panel's height is worked out from it.
  static const buttonHeight = 48.0;

  final _ConfirmRequest request;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmPanelContent({
    required this.request,
    required this.onCancel,
    required this.onConfirm,
  });

  static TextStyle? titleStyle(ThemeData theme) => theme.textTheme.titleMedium
      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700);

  static TextStyle? messageStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey700);

  @override
  Widget build(BuildContext context) {
    // Read here, inside the LightSurfaceScope, so dark mode gets the dark text
    // the light-grey sheet needs.
    final theme = Theme.of(context);
    final destructive = request.destructive;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttonText = theme.textTheme.titleMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    // A scroll view only as the safety net for a layout the height measurement
    // did not foresee; normally everything fits and nothing scrolls.
    return SingleChildScrollView(
      key: const Key('confirm-panel'),
      padding: EdgeInsets.fromLTRB(
        _ConfirmPanelScopeState._sidePadding,
        12,
        _ConfirmPanelScopeState._sidePadding,
        20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle — signals the panel can be dragged down to close.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Container(
              key: const Key('confirm-panel-icon'),
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: destructive
                    ? AppColors.errorBackground
                    : AppColors.peachMist,
              ),
              child: Icon(
                request.icon,
                size: 28,
                color: destructive ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            request.title,
            textAlign: TextAlign.center,
            style: titleStyle(theme),
          ),
          const SizedBox(height: 8),
          Text(
            request.message,
            textAlign: TextAlign.center,
            style: messageStyle(theme),
          ),
          const SizedBox(height: 24),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('confirm-panel-cancel'),
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(buttonHeight),
                    foregroundColor: AppColors.grey700,
                    side: const BorderSide(color: AppColors.grey600),
                    shape: buttonShape,
                    textStyle: buttonText,
                  ),
                  child: Text(request.cancelLabel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const Key('confirm-panel-confirm'),
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(buttonHeight),
                    // The dark red, not the brand orange: white on the orange
                    // is only 3.8:1, too little for 14 px text; this is 7.2:1.
                    backgroundColor: destructive
                        ? AppColors.error
                        : AppColors.primaryDark,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: buttonShape,
                    textStyle: buttonText,
                  ),
                  child: Text(request.confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
