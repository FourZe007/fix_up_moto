import 'package:fix_up_moto/core/router/tab_container.dart';

/// One stop on the app tour: a tab of the bottom bar and what to say about it.
class AppTourStep {
  /// The tab to light up, as a [MainTabs] index.
  final int tab;

  /// A few words, the tab's own name.
  final String title;

  /// One or two short sentences in plain Bahasa Indonesia: what the member does
  /// there. Written for someone who has never used the app, so no jargon.
  final String message;

  const AppTourStep({
    required this.tab,
    required this.title,
    required this.message,
  });
}

/// What the tour says, in the order it says it: the five tabs, left to right.
///
/// Each [AppTourStep.title] repeats the tab's label in the bottom bar, so
/// **renaming a tab means renaming it here too**; a test checks they match. The
/// sentences repeat what the pages offer (Home's Booking and Motor Saya buttons,
/// the member QR on MyPoint, Riwayat inside Booking, Kotak Masuk on Saya): when
/// a page stops offering one, change its line.
abstract final class AppTourSteps {
  static const List<AppTourStep> all = [
    AppTourStep(
      tab: MainTabs.home,
      title: 'Beranda',
      message:
          'Halaman utama Anda. Lihat promo terbaru, lalu pilih Booking untuk '
          'membuat jadwal servis atau Motor Saya untuk melihat motor Anda.',
    ),
    AppTourStep(
      tab: MainTabs.feeds,
      title: 'Feed',
      message:
          'Tonton video terbaru dari FixUp Moto. Geser layar ke atas untuk '
          'melihat video berikutnya.',
    ),
    AppTourStep(
      tab: MainTabs.membership,
      title: 'MyPoint',
      message:
          'Lihat poin dan voucher Anda di sini. Tunjukkan kode QR member '
          'kepada kasir saat servis.',
    ),
    AppTourStep(
      tab: MainTabs.bookings,
      title: 'Booking',
      message:
          'Buat booking servis, lihat booking Anda, dan buka Riwayat servis'
          'untuk setiap motor.',
    ),
    AppTourStep(
      tab: MainTabs.profile,
      title: 'Saya',
      message:
          'Ubah data diri, kelola motor, buka Kotak Masuk, atau hubungi kami'
          'lewat WhatsApp. Panduan ini bisa dibuka lagi dari sini.',
    ),
  ];
}
