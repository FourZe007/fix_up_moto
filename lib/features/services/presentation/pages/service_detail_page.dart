import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/theme/app_theme.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

/// Displays full details for a single service transaction record.
///
/// Nothing is loaded here. The backend has no call for one record's details:
/// every history record (`BrowseTrans`, `SERVICEHISTORY`) already carries its own
/// service lines (`detail`) and parts (`detail2`), so the Riwayat list hands this
/// page the record the member tapped.
///
/// The visit is drawn like an invoice in the Invoice tab (`InvoiceCard`), open:
///
/// ```
/// ┌──────────────────────────────────────────┐
/// │ 3106SNT26100316              25 Okt 2025 │   number, date
/// │ Fixup Moto - Kedung Tarukan              │   branch
/// │ Mekanik: Nurul Fahmi Azis                │
/// │ Total                         Rp 75.000  │
/// │ ──────────────────────────────────────── │
/// │ Chemical Cleaning + Rantai               │   service lines,
/// │ 2 x Oli Mesin                            │   then parts
/// │ ──────────────────────────────────────── │
/// │ Jasa                          Rp 13.000  │   the record has only these
/// │ Suku cadang                   Rp 62.000  │   two sums, no price per line
/// │ Total                         Rp 75.000  │
/// └──────────────────────────────────────────┘
///            [ Book Again ]
/// ```
class ServiceDetailPage extends StatelessWidget {
  final ServiceEntity service;

  const ServiceDetailPage({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandBackdrop(context),
      appBar: AppBar(title: const Text('Detail Service')),
      // top: false — the AppBar already accounts for the status bar; this
      // guards "Book Again" at the list's end from the gesture nav bar,
      // since this page has no bottomNavigationBar to reserve that space.
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          // Top-only — the bottom already meets the screen edge, so rounding
          // it wouldn't be visible against anything.
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: LightSurfaceScope(
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VisitCard(service: service),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push(RouteNames.createBooking),
                  child: const Text('Book Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The visit as one rounded card in the warm look `InvoiceCard` uses, always
/// open: the page is the detail, so there is nothing to expand.
class _VisitCard extends StatelessWidget {
  final ServiceEntity service;

  const _VisitCard({required this.service});

  /// "25 Okt 2025" from the record's `yyyy-MM-dd`. A date that cannot be read
  /// is shown as the server sent it rather than hidden.
  static String _shortDate(String raw) {
    final date = DateTime.tryParse(raw);
    return date == null ? raw : DateTimeFormatter.toShortDateId(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final total = service.amountService + service.amountPart;

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // A warm hairline rather than grey, like the Profile cards.
        side: const BorderSide(color: AppColors.peachHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        service.transNo,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _shortDate(service.transDate),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.grey700,
                      ),
                    ),
                  ],
                ),
                Text(
                  TextFormatter.fromUppercase(service.bsName),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
                Text(
                  'Mekanik: ${TextFormatter.fromUppercase(service.eName)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  spacing: 8,
                  children: [
                    Text(
                      'Total',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.grey700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.rupiah(total),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.peachHairline,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                if (service.detail.isEmpty && service.detail2.isEmpty)
                  Text(
                    'Tidak ada rincian',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.grey700,
                    ),
                  ),
                for (final line in service.detail)
                  _Line(name: line.serviceName, note: line.serviceNote),
                for (final part in service.detail2)
                  _Line(name: part.itemName, quantity: part.qty),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.peachHairline,
                ),
                // The record has no price per line, only these two sums; one
                // with nothing in it is left out rather than shown as Rp 0.
                if (service.amountService > 0)
                  _Sum(label: 'Jasa', amount: service.amountService),
                if (service.amountPart > 0)
                  _Sum(label: 'Suku cadang', amount: service.amountPart),
                _Sum(label: 'Total', amount: total, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A service line (name and note) or a part ("2 x name"). The backend shouts
/// names in capitals, so they are re-cased for display, as on the invoice.
class _Line extends StatelessWidget {
  final String name;
  final String note;

  /// A part is sold by the piece; a service line has none, so 0 shows no count.
  final int quantity;

  const _Line({required this.name, this.note = '', this.quantity = 0});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = TextFormatter.fromUppercase(name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quantity > 0 ? '$quantity x $shown' : shown,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (note.trim().isNotEmpty)
          Text(
            TextFormatter.fromUppercase(note),
            style: textTheme.bodySmall?.copyWith(color: AppColors.grey700),
          ),
      ],
    );
  }
}

/// A label with an amount at the far end, for the sums.
class _Sum extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _Sum({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );

    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(CurrencyFormatter.rupiah(amount), style: style),
      ],
    );
  }
}
