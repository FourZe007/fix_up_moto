import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// One stop on a form's field guide: a field (or the photo box) and how to fill
/// it in.
class FieldGuideStep {
  /// The key the form put on the field. The guide lights up whatever this is on.
  final GlobalKey key;

  /// The field's own label, so the member can tell which one is lit.
  final String title;

  /// One or two short sentences in plain Bahasa Indonesia: what goes in the
  /// field and where to find it.
  final String message;

  /// Whether the form refuses to save without it: true shows a "Wajib diisi" tag,
  /// false an "Opsional" one, so the member knows what can be left empty. Null
  /// shows no tag, for a step that is not something to fill in (a button, a
  /// choice that already has an answer).
  final bool? required;

  /// A caution shown in its own box under [message], for the one thing on the
  /// page a member must not miss (Create Booking's "add your bike first").
  final String? warning;

  /// Put the card **above** the lit thing instead of below it. For something
  /// fixed at the bottom of the screen, where there is no room below (Create
  /// Booking's Konfirmasi bar).
  final bool cardAbove;

  const FieldGuideStep({
    required this.key,
    required this.title,
    required this.message,
    this.required,
    this.warning,
    this.cardAbove = false,
  });
}

/// Builds a field guide: the dark overlay that lights up one text field at a
/// time, with a [FieldGuideCard] beside it saying how to fill it in.
///
/// The same overlay and look as the app tour (`buildAppTour`), for a form
/// instead of the tab bar. [steps] are in the order they are shown, which should
/// be the form's own top-to-bottom order. [onEnd] runs once however the guide
/// ends: after the last step or on "Lewati".
///
/// [reveal] is called before each step is lit and awaited: the form uses it to
/// scroll the field into view, since a form is longer than the screen and the
/// package measures a field where it is *now*.
///
/// The returned [TutorialCoachMark] still has to be shown (`show(context:)`); the
/// form does that.
///
/// A few choices, the same as the tour's:
/// - Tapping the lit field or the dark area does nothing, so a stray tap cannot
///   open the keyboard or leave the guide. The card's buttons and "Lewati" are
///   the ways through and out.
/// - The card goes **below** what is lit, unless the step says [FieldGuideStep.cardAbove].
///   Below only works if [reveal] has brought it up into the top part of the
///   screen, so the form has to make that possible for every step, the last ones
///   too (see `FieldGuidePlayer`, which asks the form for blank scroll room while
///   the guide plays). A card above a field would run off the top of a short
///   screen for the fields near the top; `cardAbove` is only for something fixed
///   at the bottom, which cannot be scrolled and has all the room above it.
/// - "Lewati" is hidden on the last step, which has "Selesai".
TutorialCoachMark buildFieldGuide({
  required List<FieldGuideStep> steps,
  required VoidCallback onEnd,
  required Future<void> Function(FieldGuideStep step) reveal,
}) {
  return TutorialCoachMark(
    targets: [
      for (var i = 0; i < steps.length; i++)
        TargetFocus(
          identify: 'field-$i',
          keyTarget: steps[i].key,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 4,
          enableOverlayTab: false,
          // A tap on the lit field does nothing: the package's default is to
          // count it as "next", which a member trying to type would not expect.
          enableTargetTab: false,
          contents: [
            TargetContent(
              align: steps[i].cardAbove
                  ? ContentAlign.top
                  : ContentAlign.bottom,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              builder: (context, controller) => FieldGuideCard(
                step: steps[i],
                number: i + 1,
                total: steps.length,
                onNext: controller.next,
                // Nothing before the first step to go back to.
                onBack: i == 0 ? null : controller.previous,
              ),
            ),
          ],
        ),
    ],
    beforeFocus: (target) async {
      final index = steps.indexWhere((s) => s.key == target.keyTarget);
      if (index >= 0) await reveal(steps[index]);
    },
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    pulseEnable: false,
    // Quicker than the package's 600 ms each way: the fields are close together
    // and a step change (fade out, scroll, light, fade in) ignores taps while it
    // runs, so a slow one feels like a button that does nothing.
    focusAnimationDuration: const Duration(milliseconds: 400),
    unFocusAnimationDuration: const Duration(milliseconds: 250),
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

/// One field's message: its name, whether it is required, how to fill it in,
/// where the member is in the guide, and the buttons to go on (or back).
///
/// A white card in both light and dark mode, like `AppTourCard`, since it sits
/// on the guide's own black overlay rather than on a page.
class FieldGuideCard extends StatelessWidget {
  final FieldGuideStep step;

  /// Position of [step] in the guide, counting from 1, and how many there are.
  final int number;
  final int total;

  final VoidCallback onNext;

  /// Null on the first step, where there is no "Kembali".
  final VoidCallback? onBack;

  const FieldGuideCard({
    super.key,
    required this.step,
    required this.number,
    required this.total,
    required this.onNext,
    this.onBack,
  });

  bool get _isLast => number == total;

  /// "Wajib diisi" or "Opsional", so what can be skipped is clear at a glance;
  /// nothing for a step with no answer to give.
  Widget _tag() {
    final required = step.required;
    if (required == null) return const SizedBox.shrink();
    return Container(
      key: const Key('field-guide-tag'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Dark text on a pale fill both ways: 4.5:1 or better.
        color: required ? AppColors.peachMist : AppColors.grey200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: required ? AppColors.peachHairline : AppColors.grey200,
        ),
      ),
      child: Text(
        required ? 'Wajib diisi' : 'Opsional',
        style: TextStyle(
          color: required ? AppColors.primaryDark : AppColors.grey700,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// The step's caution, in the same peach box as the tour's hand-off message
  /// but with a warning sign, so it reads as something to heed, not more help.
  Widget _warning(String text) {
    return Container(
      key: const Key('field-guide-warning'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.peachMist,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.peachHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          Expanded(
            child: Text(
              text,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = TextButton.styleFrom(
      foregroundColor: AppColors.primaryDark,
      minimumSize: const Size(0, 48),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$number dari $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
                const Spacer(),
                _tag(),
              ],
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
            if (step.warning case final warning?) ...[
              const SizedBox(height: 12),
              _warning(warning),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (onBack != null)
                  TextButton(
                    key: const Key('field-guide-back'),
                    onPressed: onBack,
                    style: quiet,
                    child: const Text('Kembali'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('field-guide-next'),
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    // The dark red, not the brand orange: white on the orange is
                    // only 3.8:1, on this 7:1.
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(112, 48),
                  ),
                  child: Text(_isLast ? 'Selesai' : 'Lanjut'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
