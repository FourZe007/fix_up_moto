import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// The policy's wording lives here, apart from the layout below, so it can be
// edited without touching the widget.

const _heading = 'KEBIJAKAN PRIVASI FIXUP MOTO';

/// Shown after "Berlaku sejak" — replace it with the release date when the app
/// ships.
const _effectiveDate = '[tgl rilis app]';

const _introParagraphs = <String>[
  'Kebijakan Privasi ini berlaku untuk Aplikasi FixUp Moto dan aplikasi atau '
      'situs web lain yang terkait dengan merek atau produk FixUp Moto '
      '("Aplikasi") yang mengarahkan Pengguna ke Kebijakan Privasi ini. '
      'PT Sapta Aji Manungga Prima membangun Aplikasi sebagai aplikasi dengan '
      'tujuan bisnis dan dimaksudkan untuk digunakan apa adanya.',
  'Kebijakan Privasi ini digunakan untuk memberi tahu Pengguna mengenai '
      'kebijakan FixUp Moto dengan pengumpulan, penggunaan, pengolahan, '
      'penyimpanan, penguasaan dan pengungkapan Informasi Pribadi jika ada '
      'yang memutuskan untuk menggunakan Layanan dan Aplikasi FixUp Moto.',
  'Jika Pengguna memilih untuk menggunakan Layanan dan Aplikasi FixUp Moto, '
      'maka Pengguna mengakui bahwa Pengguna telah membaca dan memahami '
      'Kebijakan Privasi ini dan menyetujui segala ketentuannya. Secara '
      'khusus, Pengguna setuju dan memberikan persetujuan kepada FixUp Moto '
      'untuk mengumpulkan, menggunakan, membagikan, mengungkapkan, menyimpan, '
      'mentransfer, atau mengolah Informasi Pribadi Pengguna sesuai dengan '
      'Kebijakan Privasi ini.',
  'Kebijakan Privasi ini berlaku efektif pada tanggal yang tercantum di '
      'Kebijakan Privasi ini. FixUp Moto dapat mengubah, menambah, menghapus, '
      'mengoreksi dan/atau memperbarui Kebijakan Privasi ini dari waktu ke '
      'waktu untuk memastikan bahwa Kebijakan Privasi ini konsisten dengan '
      'perkembangan FixUp Moto di masa depan, dan/atau perubahan persyaratan '
      'hukum atau peraturan, dengan memposting Kebijakan Privasi yang telah '
      'direvisi di Aplikasi, di mana FixUp Moto akan mengganti tanggal pada '
      'bagian atas Kebijakan Privasi ini; dan Pengguna melepaskan hak apapun '
      'yang mungkin Pengguna miliki untuk menerima pemberitahuan khusus '
      'tentang perubahan atau modifikasi tersebut. Oleh karena itu, FixUp Moto '
      'menyarankan Pengguna untuk meninjau halaman Kebijakan Privasi ini dari '
      'waktu ke waktu untuk melihat adanya perubahan bilamana ada. Perubahan '
      'tersebut berlaku segera setelah diposting di halaman Kebijakan Privasi '
      'dan penggunaan Pengguna yang berkelanjutan atas Aplikasi setelah '
      'perubahan tersebut diposting merupakan penerimaan Pengguna terhadap '
      'Kebijakan Privasi yang direvisi tersebut.',
  'Mohon baca Kebijakan Privasi ini dengan saksama untuk memastikan bahwa '
      'Pengguna memahami bagaimana proses pengolahan data FixUp Moto. Istilah '
      'yang digunakan dalam Kebijakan Privasi ini memiliki arti yang sama '
      'seperti dalam Ketentuan Penggunaan Aplikasi (sebagaimana relevan) '
      '("Syarat dan Ketentuan", pengertian mana termasuk setiap perubahan dan '
      'variasi terhadapnya dari waktu ke waktu), yang dapat diakses di '
      'Aplikasi kecuali ditentukan lain dalam Kebijakan Privasi ini.',
];

const _termsHeading = 'Syarat dan Ketentuan';

const _terms = <String>[
  'Saya menyatakan informasi data pribadi yang saya masukkan pada sistem '
      'FixUp Moto adalah informasi dan data pribadi saya yang terbaru dan '
      'sebenar-benarnya.',
  'Saya menyatakan informasi data pribadi sebagaimana tersebut di atas saya '
      'masukkan pada sistem FixUp Moto secara sadar tanpa ada paksaan dari '
      'pihak manapun.',
  'Saya menyetujui dan bersedia menerima promosi produk dan broadcast '
      'penawaran produk dari FixUp Moto.',
  'Saya menyetujui bahwa informasi data yang saya masukkan pada sistem '
      'FixUp Moto dapat dibagikan kepada pihak ke-3 (tiga) yang terafiliasi '
      'dengan FixUp Moto, untuk antara lain namun tidak terbatas pada '
      'keperluan promosi produk dan broadcast penawaran produk.',
];

/// The app's privacy policy, reached from the Profile tab's Kebijakan Privasi
/// row: the policy text followed by the numbered terms and conditions.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Both colours come from the active Theme rather than AppColors constants,
    // so this bar follows light/dark automatically when ThemeCubit changes
    // MaterialApp's themeMode — no cubit read needed here. The title and arrow
    // are coloured explicitly because the app's AppBarTheme hard-codes a white
    // title style.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kebijakan Privasi',
          style: TextStyle(color: onSurface, fontSize: 16),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        // Same colour as the page behind it, so the bar blends into the body.
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(foregroundColor: onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  _heading,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Berlaku sejak $_effectiveDate',
                  textAlign: TextAlign.center,
                  style: body,
                ),
              ),
              for (final paragraph in _introParagraphs)
                Text(paragraph, style: body),
              const SizedBox(height: 4),
              Text(
                _termsHeading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (var i = 0; i < _terms.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text('${i + 1}.', style: body),
                    Expanded(child: Text(_terms[i], style: body)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
