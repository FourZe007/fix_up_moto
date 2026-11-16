import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

/// Displays a single service transaction/history record in the list.
///
/// Laid out like the "My Bookings" card next to it — branch location as the
/// smaller title with the brand prefix stripped, date under the title, the
/// amount on the right centred against that title+date column, a divider, then
/// the transaction number and mechanic — but coloured like the invoice card
/// (`InvoiceCard`), in as few colours as it takes:
///
/// - a white surface with a warm hairline border, not a black outline;
/// - the amount as plain brand-red text, not a tinted, outlined badge;
/// - everything that is only supporting detail (date, number, mechanic) in one
///   soft grey, so the title and the amount are the two things that stand out.
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
    return parsed == null ? transDate : DateTimeFormatter.toShortDate(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = service.amountService + service.amountPart;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // A warm hairline rather than black or grey, like the Profile cards
        // and the invoices.
        side: const BorderSide(color: AppColors.peachHairline),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayDate(service.transDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.rupiah(total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.peachHairline),
              ),
              Text(
                '${service.transNo} · ${TextFormatter.fromUppercase(service.eName)}',
                style: const TextStyle(color: AppColors.grey700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
