import 'package:intl/intl.dart';

/// Utility class for showing money the way Indonesians write it.
///
/// All methods are static — import and call directly:
///   `CurrencyFormatter.rupiah(65000)` → "Rp 65.000"
class CurrencyFormatter {
  CurrencyFormatter._(); // static-only class

  /// Created once and reused — instantiation is expensive. Rupiah has no
  /// everyday cents, so no decimals; a dot separates the thousands.
  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Formats [amount] as "Rp 65.000". A fraction is rounded away, so the
  /// backend's `65000.0000` reads as "Rp 65.000".
  static String rupiah(num amount) => _rupiah.format(amount);
}
