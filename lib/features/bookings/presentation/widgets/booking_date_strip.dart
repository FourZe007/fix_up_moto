import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

/// A swipeable row of day cards for choosing a booking date.
///
/// Replaces a popup calendar: every day that can't be booked stays visible but
/// greyed out and untappable, so the rules (no weekends, no same-day) can be
/// seen instead of explained. Which days those are is the caller's decision
/// ([isEnabled]) — this widget only draws them.
class BookingDateStrip extends StatelessWidget {
  const BookingDateStrip({
    super.key,
    required this.firstDay,
    required this.dayCount,
    required this.selectedDate,
    required this.isEnabled,
    required this.onSelected,
    this.controller,
  });

  static const double cardWidth = 56;
  static const double cardGap = 8;
  static const double height = 88;

  /// Every card takes the same horizontal space, which is what lets
  /// [offsetFor] turn a date into a scroll position without measuring.
  static const double itemExtent = cardWidth + cardGap;

  /// The date shown on the first card, at midnight.
  final DateTime firstDay;
  final int dayCount;
  final DateTime? selectedDate;
  final bool Function(DateTime day) isEnabled;
  final ValueChanged<DateTime> onSelected;
  final ScrollController? controller;

  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');

  /// The key of [day]'s card, so tests can find it without scrolling by hand.
  static Key keyFor(DateTime day) =>
      ValueKey('booking-day-${_keyFormat.format(day)}');

  /// The scroll offset that puts [day]'s card at the strip's left edge.
  static double offsetFor(DateTime firstDay, DateTime day) {
    final days = DateUtils.dateOnly(
      day,
    ).difference(DateUtils.dateOnly(firstDay));
    // Rounded, not truncated: a daylight-saving change makes a day 23 or 25h.
    return (days.inHours / 24).round() * itemExtent;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemExtent: itemExtent,
        itemCount: dayCount,
        itemBuilder: (context, index) {
          final day = DateUtils.addDaysToDate(firstDay, index);
          return Padding(
            padding: const EdgeInsets.only(right: cardGap),
            child: _DayCard(
              key: keyFor(day),
              weekday: DateTimeFormatter.shortWeekdayId(day),
              dayOfMonth: '${day.day}',
              month: DateTimeFormatter.shortMonthId(day),
              spoken: DateTimeFormatter.toSpokenDateId(day),
              selected:
                  selectedDate != null &&
                  DateUtils.isSameDay(day, selectedDate),
              enabled: isEnabled(day),
              onTap: () => onSelected(day),
            ),
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String weekday;
  final String dayOfMonth;
  final String month;
  final String spoken;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DayCard({
    super.key,
    required this.weekday,
    required this.dayOfMonth,
    required this.month,
    required this.spoken,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(14);
    // null keeps the theme's own text colour for an ordinary, tappable day.
    final Color? foreground = selected
        ? Colors.white
        : enabled
        ? null
        : AppColors.grey400;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.primary
            : enabled
            ? AppColors.grey200
            : AppColors.grey200.withValues(alpha: 0.4),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: textTheme.bodySmall?.copyWith(color: foreground),
              ),
              Text(
                dayOfMonth,
                style: textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                month,
                style: textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
