import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/tour/app_tour_handoff.dart';
import 'package:fix_up_moto/core/tour/app_tour_steps.dart';

/// Builds the tour: the dark overlay that lights up one bottom-bar tab at a time
/// with [AppTourCard] above it.
///
/// [tabKeys] are the keys the bar's tabs carry, indexed by `MainTabs` (see
/// `AppTabBar.tabKeys`). [onEnd] runs once however the tour ends: after the last
/// step, when the member taps "Lewati", or when they answer the [handoff].
///
/// With a [handoff], the last step does not end on "Selesai" but offers the
/// member their first task: its accept button calls [onHandoff] and then closes
/// the tour at once, and "Nanti saja" just closes it. Opening the task's page is
/// left to whoever passed [onHandoff] (`AppTourHost`), after the tour is gone.
///
/// The returned [TutorialCoachMark] still has to be shown (`show(context:)`);
/// `AppTourHost` does that.
///
/// A few choices worth knowing:
/// - Tapping the lit tab goes to the next step instead of switching to that tab,
///   and tapping the dark area does nothing, so a stray tap cannot leave the
///   tour or change page behind it. The buttons on the card and "Lewati" are the
///   ways through and out.
/// - "Lewati" sits top right, away from the bar, and is hidden on the last step,
///   which has "Selesai" (or the [handoff]'s two buttons) instead.
/// - The highlight does not pulse: calmer, and nothing keeps animating once it
///   has settled.
TutorialCoachMark buildAppTour({
  required List<GlobalKey> tabKeys,
  required VoidCallback onEnd,
  AppTourHandoff? handoff,
  VoidCallback? onHandoff,
}) {
  const steps = AppTourSteps.all;

  return TutorialCoachMark(
    targets: [
      for (var i = 0; i < steps.length; i++)
        TargetFocus(
          identify: 'tab-${steps[i].tab}',
          keyTarget: tabKeys[steps[i].tab],
          shape: ShapeLightFocus.RRect,
          radius: 20,
          paddingFocus: 4,
          enableOverlayTab: false,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              builder: (context, controller) => AppTourCard(
                step: steps[i],
                number: i + 1,
                total: steps.length,
                onNext: controller.next,
                // Nothing before the first step to go back to.
                onBack: i == 0 ? null : controller.previous,
                // Only the last step hands the member on. Both answers close the
                // tour straight away (skip, not next, which would wait for the
                // highlight to fade first).
                handoff: i == steps.length - 1 ? handoff : null,
                onAccept: () {
                  onHandoff?.call();
                  controller.skip();
                },
                onDecline: controller.skip,
              ),
            ),
          ],
        ),
    ],
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    pulseEnable: false,
    textSkip: 'Lewati',
    textStyleSkip: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
    alignSkip: Alignment.topRight,
    showSkipInLastTarget: false,
    onFinish: onEnd,
    onSkip: () {
      onEnd();
      return true;
    },
  );
}

/// One step's message: the tab's name, what it is for, where the member is in
/// the tour, and the buttons to go on (or back).
///
/// On the last step, given a [handoff], the closing button is replaced by an
/// offer of the member's first task: a short line saying why, a big accept
/// button, and a quieter "Nanti saja".
///
/// A white card in both light and dark mode, since it sits on the tour's own
/// black overlay rather than on a page.
class AppTourCard extends StatelessWidget {
  final AppTourStep step;

  /// Position of [step] in the tour, counting from 1, and how many there are.
  final int number;
  final int total;

  final VoidCallback onNext;

  /// Null on the first step, where there is no "Kembali".
  final VoidCallback? onBack;

  /// What the last step offers instead of "Selesai"; null (the default) keeps
  /// the plain ending, and on every other step it is ignored.
  final AppTourHandoff? handoff;

  /// The member took the offer / said "Nanti saja". Both are needed to show a
  /// [handoff].
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const AppTourCard({
    super.key,
    required this.step,
    required this.number,
    required this.total,
    required this.onNext,
    this.onBack,
    this.handoff,
    this.onAccept,
    this.onDecline,
  }) : assert(
         handoff == null || (onAccept != null && onDecline != null),
         'a handoff needs both answers',
       );

  bool get _isLast => number == total;

  /// The ordinary row: "Kembali" on the left, Lanjut (or Selesai) on the right.
  Widget _plainButtons() {
    return Row(
      children: [
        if (onBack != null) _backButton(),
        const Spacer(),
        FilledButton(
          key: const Key('tour-next'),
          onPressed: onNext,
          style: _filled(const Size(112, 48)),
          child: Text(_isLast ? 'Selesai' : 'Lanjut'),
        ),
      ],
    );
  }

  /// The last step's offer: why, then the task's button across the full width,
  /// then "Kembali" and "Nanti saja" as quiet text below it.
  Widget _handoffButtons(AppTourHandoff handoff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('tour-handoff-message'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.peachMist,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.peachHairline),
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(handoff.icon, color: AppColors.primary, size: 22),
              Expanded(
                child: Text(
                  handoff.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('tour-accept'),
          onPressed: onAccept,
          style: _filled(const Size.fromHeight(48)),
          child: Text(handoff.acceptLabel),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (onBack != null) _backButton(),
            const Spacer(),
            TextButton(
              key: const Key('tour-decline'),
              onPressed: onDecline,
              style: _quiet(),
              child: const Text('Nanti saja'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _backButton() => TextButton(
    key: const Key('tour-back'),
    onPressed: onBack,
    style: _quiet(),
    child: const Text('Kembali'),
  );

  ButtonStyle _quiet() => TextButton.styleFrom(
    foregroundColor: AppColors.primaryDark,
    minimumSize: const Size(0, 48),
  );

  ButtonStyle _filled(Size minimumSize) => FilledButton.styleFrom(
    // The dark red, not the brand orange: white on the orange is only 3.8:1, on
    // this 7:1.
    backgroundColor: AppColors.primaryDark,
    foregroundColor: Colors.white,
    minimumSize: minimumSize,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number dari $total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.grey700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              step.title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (handoff != null && _isLast)
              _handoffButtons(handoff!)
            else
              _plainButtons(),
          ],
        ),
      ),
    );
  }
}
