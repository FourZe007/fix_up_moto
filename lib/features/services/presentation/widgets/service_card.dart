import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/helpers/date_formatter.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

/// Displays a single service transaction/history record in the list.
///
/// Mirrors the "My Bookings" card design exactly (see
/// `_buildBookingsList` in `bookings_page.dart`) — flat black-bordered
/// `Card`, branch location as the smaller title with the brand prefix
/// stripped, date under the title, a right-aligned badge centred against
/// that title+date column, a divider, then the remaining details — so both
/// segments of the Bookings tab read as one consistent design.
class ServiceCard extends StatelessWidget {
  final ServiceEntity service;
  final VoidCallback? onTap;

  const ServiceCard({super.key, required this.service, this.onTap});

  /// Strips the repeated "FIXUP MOTO - " brand prefix every `bsName`
  /// carries — same logic as the My Bookings card's own helper.
  String _branchLocationName(String bsName) {
    final match = RegExp(
      r'^FIXUP MOTO\s*-\s*',
      caseSensitive: false,
    ).firstMatch(bsName);
    if (match == null) return bsName;
    return bsName.substring(match.end).trim();
  }

  /// `transDate` arrives as a plain string (e.g. "2024-05-11"); reformat it
  /// when it parses, otherwise fall back to showing it verbatim rather than
  /// hiding a record over an unexpected date format.
  String _displayDate(String transDate) {
    final parsed = DateTime.tryParse(transDate);
    return parsed == null ? transDate : DateFormatter.toShortDate(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final total = service.amountService + service.amountPart;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _branchLocationName(service.bsName),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayDate(service.transDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AmountBadge(amount: total),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Text('${service.transNo} · ${service.eName}'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Total-amount badge — the History equivalent of the My Bookings card's
/// [_StatusBadge], same shape/padding, styled as a positive/confirmed value
/// since a completed transaction always has one.
class _AmountBadge extends StatelessWidget {
  final double amount;
  const _AmountBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        '₱${amount.toStringAsFixed(0)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
