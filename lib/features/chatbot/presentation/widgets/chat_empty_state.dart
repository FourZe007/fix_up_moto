import 'package:flutter/material.dart';
import 'package:fix_up_moto/features/chatbot/presentation/widgets/fima_avatar.dart';

/// What the chat shows before anything has been said: Fima introduces herself
/// and offers a few questions to start with.
class ChatEmptyState extends StatelessWidget {
  /// Called with the question the member tapped; the page sends it as if they
  /// had typed it.
  final ValueChanged<String> onSuggestion;

  const ChatEmptyState({super.key, required this.onSuggestion});

  /// Starter questions — ones the live service was seen to answer properly
  /// (2026-10-20), within its 100-character limit. It apologises for most
  /// other things, such as points, vouchers and booking, so those are not
  /// offered. Revisit when what Fima can answer grows.
  static const suggestions = [
    'Saya ingin tahu tentang jam operasional bengkel',
    'Dimana lokasi bengkel Fix Up Moto?',
    'Apakah bengkel buka hari Sabtu dan Minggu?',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      // Scrolls when the keyboard leaves too little room for it all.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FimaAvatar(size: 72),
            const SizedBox(height: 16),
            Text(
              'Halo, saya Fima',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Asisten virtual FixUp Moto. Tanyakan seputar jam operasional '
              'dan lokasi bengkel.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            // Each question is answered on its own, with nothing carried over
            // from the one before.
            Text(
              'Tiap pertanyaan dijawab terpisah, jadi tulis pertanyaan '
              'selengkapnya.',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final question in suggestions)
                  ActionChip(
                    label: Text(question),
                    onPressed: () => onSuggestion(question),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
