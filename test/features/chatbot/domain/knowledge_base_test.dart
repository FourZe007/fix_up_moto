import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/chatbot/domain/entities/knowledge_base.dart';

void main() {
  const file = '''
# Pengetahuan Fima

Catatan di atas topik pertama tidak dipakai.

## Poin
Kata kunci: poin, point, tukar poin
Poin didapat dari setiap servis.

Poin bisa ditukar dengan voucher.

## Voucher
Kata kunci: voucher, kupon
Voucher dipakai saat membayar.

## Booking
Kata kunci: booking, pesan, memesan
Booking dilakukan lewat menu Booking.
''';

  group('KnowledgeBase.parse', () {
    test('reads each section with its keywords and answer', () {
      final knowledge = KnowledgeBase.parse(file);

      expect(
        [for (final e in knowledge.entries) e.title],
        ['Poin', 'Voucher', 'Booking'],
      );
      expect(knowledge.entries.first.keywords, ['poin', 'point', 'tukar poin']);
      expect(
        knowledge.entries.first.answer,
        'Poin didapat dari setiap servis.\n\nPoin bisa ditukar dengan voucher.',
      );
    });

    test('knows nothing from an empty file', () {
      expect(KnowledgeBase.parse('').entries, isEmpty);
      expect(KnowledgeBase.parse('  \n\n').entries, isEmpty);
    });

    test('skips what is above the first topic, however it is written', () {
      final knowledge = KnowledgeBase.parse(
        'Kata kunci: poin\nIni bukan jawaban.\n\n## Poin\nKata kunci: poin\nIni.',
      );

      expect([for (final e in knowledge.entries) e.title], ['Poin']);
      expect(knowledge.entries.single.answer, 'Ini.');
    });

    test('reads a file saved with Windows line endings', () {
      final knowledge = KnowledgeBase.parse(
        '## Poin\r\nKata kunci: poin\r\nSatu.\r\n\r\nDua.\r\n',
      );

      expect(knowledge.entries.single.answer, 'Satu.\n\nDua.');
    });

    test('drops <!-- comments --> so notes never reach a member', () {
      final knowledge = KnowledgeBase.parse('''
<!--
## Contoh
Kata kunci: contoh
Jangan tampilkan ini.
-->
## Poin
Kata kunci: poin
Jawaban <!-- catatan -->asli.
''');

      expect([for (final e in knowledge.entries) e.title], ['Poin']);
      expect(knowledge.entries.single.answer, 'Jawaban asli.');
    });

    test('skips a section with no keywords line, no keywords or no answer', () {
      final knowledge = KnowledgeBase.parse('''
## Tanpa kata kunci
Jawaban yang tidak akan ditemukan siapa pun.

## Kata kunci kosong
Kata kunci: , ,
Jawaban.

## Tanpa jawaban
Kata kunci: kosong

## Lengkap
Kata kunci: lengkap
Ada.
''');

      expect([for (final e in knowledge.entries) e.title], ['Lengkap']);
    });

    test('accepts the keywords line in any case and spacing', () {
      final knowledge = KnowledgeBase.parse(
        '## A\n  KATA KUNCI :  Satu ,  Dua Kata \nIsi.',
      );

      expect(knowledge.entries.single.keywords, ['satu', 'dua kata']);
    });

    test('keeps ### and #hashtag lines as part of the answer', () {
      final knowledge = KnowledgeBase.parse(
        '## A\nKata kunci: a\nAtas\n### Bagian\n#fixupmoto\nBawah',
      );

      expect(
        knowledge.entries.single.answer,
        'Atas\n### Bagian\n#fixupmoto\nBawah',
      );
    });

    test('cannot be changed from outside', () {
      final knowledge = KnowledgeBase.parse(file);

      expect(
        () => knowledge.entries.add(knowledge.entries.first),
        throwsUnsupportedError,
      );
    });
  });

  group('KnowledgeBase.answerFor', () {
    final knowledge = KnowledgeBase.parse(file);

    test('answers a question that holds a keyword', () {
      expect(
        knowledge.answerFor('Bagaimana cara dapat voucher?'),
        'Voucher dipakai saat membayar.',
      );
    });

    test('does not mind capitals or punctuation', () {
      expect(knowledge.answerFor('POIN?!'), startsWith('Poin didapat'));
      expect(
        knowledge.answerFor('apa itu "poin".'),
        startsWith('Poin didapat'),
      );
    });

    test('matches a keyword that is a phrase', () {
      expect(
        knowledge.answerFor('Bagaimana cara tukar poin saya'),
        startsWith('Poin didapat'),
      );
    });

    test('counts whole words only', () {
      expect(knowledge.answerFor('Kepoin banget'), isNull);
      expect(knowledge.answerFor('vouchers'), isNull);
    });

    test('prefers the topic with more of its keywords in the question', () {
      expect(
        knowledge.answerFor('Bisa pesan dan booking voucher?'),
        startsWith('Booking dilakukan'),
      );
    });

    test('on a tie, takes the topic written first', () {
      expect(
        knowledge.answerFor('poin atau voucher?'),
        startsWith('Poin didapat'),
      );
    });

    test('has no answer when nothing matches', () {
      expect(knowledge.answerFor('Apakah bengkel buka hari Minggu?'), isNull);
      expect(knowledge.answerFor(''), isNull);
    });

    test('has no answer at all from an empty knowledge base', () {
      expect(KnowledgeBase.empty.answerFor('poin'), isNull);
    });
  });
}
