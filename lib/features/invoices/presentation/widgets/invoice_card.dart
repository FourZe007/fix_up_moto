import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/helpers/currency_formatter.dart';
import 'package:fix_up_moto/core/helpers/date_time_formatter.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

/// One invoice, as a rounded card in the warm Profile look.
///
/// ```
/// ┌──────────────────────────────────────────┐
/// │ 3101SNT24090303              16 Sep 2024 │   invoice number, date
/// │ Fixup Moto - Kutisari                    │   workshop
/// │ Total                    Rp 65.000    ⌄  │   what was paid; tap to expand
/// │ ──────────────────────────────────────── │
/// │ Tune Up Paket                  Rp 60.000 │   expanded: each line,
/// │ Perawatan Berkala (Paket Service)        │   then subtotal, discount,
/// │ ...                                      │   voucher
/// │ ──────────────────────────────────────── │
/// │                        [⬇ Unduh Struk]   │   saves the receipt as a PDF
/// └──────────────────────────────────────────┘
/// ```
///
/// Tapping the card opens and closes its lines in place, so the list keeps its
/// place. The backend shouts names in capitals, so they are re-cased for
/// display; the invoice number is shown as it was sent.
///
/// The card downloads nothing itself: "Unduh Struk" calls [onDownload], and the
/// page does the work. [onDownload] is null while the button cannot be pressed
/// (another receipt is on its way); [downloading] is true while this card's own
/// receipt is, and swaps the icon for a spinner.
class InvoiceCard extends StatefulWidget {
  final InvoiceEntity invoice;
  final VoidCallback? onDownload;
  final bool downloading;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onDownload,
    this.downloading = false,
  });

  /// The key of the invoice's "Unduh Struk" button.
  static Key downloadKeyFor(InvoiceEntity invoice) =>
      ValueKey('invoice-download-${invoice.number}');

  @override
  State<InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<InvoiceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      // Keeps the ripple inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // A warm hairline rather than grey, like the Profile cards.
        side: const BorderSide(color: AppColors.peachHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: _Summary(invoice: invoice, expanded: _expanded),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _expanded
                ? _Details(invoice: invoice)
                : const SizedBox(width: double.infinity),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.peachHairline,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: InvoiceCard.downloadKeyFor(invoice),
                // Not pressable while this receipt is on its way, so a second
                // tap cannot ask for it again.
                onPressed: widget.downloading ? null : widget.onDownload,
                icon: widget.downloading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(
                  widget.downloading ? 'Mengunduh...' : 'Unduh Struk',
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What shows while the card is closed.
class _Summary extends StatelessWidget {
  final InvoiceEntity invoice;
  final bool expanded;

  const _Summary({required this.invoice, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                invoice.number,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateTimeFormatter.toShortDateId(invoice.date),
              style: textTheme.bodySmall?.copyWith(color: AppColors.grey700),
            ),
          ],
        ),
        Text(
          TextFormatter.fromUppercase(invoice.workshopName),
          style: textTheme.bodySmall?.copyWith(color: AppColors.grey700),
        ),
        const SizedBox(height: 4),
        Row(
          spacing: 8,
          children: [
            Text(
              'Total',
              style: textTheme.bodySmall?.copyWith(color: AppColors.grey700),
            ),
            const Spacer(),
            Text(
              CurrencyFormatter.rupiah(invoice.total),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.grey600,
            ),
          ],
        ),
      ],
    );
  }
}

/// What opens under the summary: each line, then the sums.
class _Details extends StatelessWidget {
  final InvoiceEntity invoice;

  const _Details({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.peachHairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              if (invoice.lines.isEmpty)
                Text(
                  'Tidak ada rincian',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
              for (final line in invoice.lines) _Line(line: line),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.peachHairline,
              ),
              _Sum(label: 'Subtotal', amount: invoice.subtotal),
              if (invoice.discount > 0)
                _Sum(label: 'Diskon', amount: -invoice.discount),
              if (invoice.hasVoucher)
                Text(
                  invoice.voucherName.isNotEmpty
                      ? 'Voucher: ${TextFormatter.fromUppercase(invoice.voucherName)}'
                      : 'Voucher: ${invoice.voucherNo}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
              _Sum(label: 'Total', amount: invoice.total, bold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final InvoiceLineEntity line;

  const _Line({required this.line});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = TextFormatter.fromUppercase(line.name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // A count means nothing on a service line, where the backend
                // sends 0; a part is sold by the piece.
                line.quantity > 0 ? '${line.quantity} x $name' : name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (line.note.isNotEmpty)
                Text(
                  TextFormatter.fromUppercase(line.note),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.grey700,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.rupiah(line.price),
              style: textTheme.bodyMedium,
            ),
            if (line.discount > 0)
              Text(
                'Diskon ${CurrencyFormatter.rupiah(-line.discount)}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.grey700),
              ),
          ],
        ),
      ],
    );
  }
}

/// A label with an amount at the far end, for the subtotal / discount / total.
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
