/// Indonesian wording for text that reaches the app in English — the backend's
/// notification types, and the messages the app itself raises on a failure.
///
/// All members are static — import and call directly:
///   `TranslationConstants.translate('Service Booking Confirmed')`
///     → "Booking Service Terkonfirmasi"
///
/// To translate another sentence, add one line to [translations]: the key is
/// the English text in lowercase, the value is exactly what should be shown.
class TranslationConstants {
  TranslationConstants._(); // static-only class

  /// English sentence → Indonesian display text.
  ///
  /// Keys are lowercase and trimmed, because [translate] lowercases and trims
  /// what it is given before looking it up — so "Service Booking Confirmed",
  /// "service booking confirmed" and " SERVICE BOOKING CONFIRMED " all match
  /// the same entry. Values are display text, so they carry their own capital
  /// letters.
  static const Map<String, String> translations = {
    // ── Notification types (BrowseTrans `NotificationType`) ──────────────────
    'service booking confirmed': 'Booking Service Terkonfirmasi',
    'point earned': 'Point diterima',

    // ── Failure messages (see the repositories) ──────────────────────────────
    'no internet connection': 'Tidak ada koneksi internet',
    'no signed-in member found': 'Anggota belum masuk. Silakan masuk kembali',
    'session expired. please sign in again.':
        'Sesi berakhir. Silakan masuk kembali',
    'access denied': 'Akses ditolak',
    'resource not found': 'Data tidak ditemukan',
    'the receipt could not be downloaded': 'Struk tidak dapat diunduh',
    'the receipt could not be saved': 'Struk tidak dapat disimpan',
    'storage permission is needed to save the receipt':
        'Izin penyimpanan diperlukan untuk menyimpan struk. '
        'Aktifkan di pengaturan ponsel',
    'no app was found to open the receipt':
        'Tidak ada aplikasi untuk membuka PDF. '
        'Struk ada di folder Download',
    'the receipt could not be opened': 'Struk tidak dapat dibuka',
  };

  /// The Indonesian text for [text], or [text] itself when there is no entry
  /// for it — so a sentence nobody has translated yet still shows, in the
  /// language it arrived in, instead of disappearing.
  static String translate(String text) =>
      translations[text.trim().toLowerCase()] ?? text;
}
