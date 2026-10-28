import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/chatbot/domain/entities/fima_apology.dart';

void main() {
  group('isFimaApology', () {
    test('recognises the wording the live service was seen to use', () {
      expect(
        isFimaApology(
          'Mohon Maaf untuk saat ini saya belum bisa menjawab pertanyaan anda.',
        ),
        isTrue,
      );
    });

    test('does not mind capitals, extra spaces or line breaks', () {
      expect(isFimaApology('MOHON MAAF, SAYA BELUM BISA MENJAWAB'), isTrue);
      expect(isFimaApology('saya  belum\nbisa   menjawab'), isTrue);
    });

    test('recognises the same apology in other words', () {
      expect(
        isFimaApology('Maaf, saya tidak dapat menjawab pertanyaan itu.'),
        isTrue,
      );
      expect(isFimaApology('Mohon maaf, kami belum menjawab itu.'), isTrue);
    });

    test('is not fooled by one half of an apology', () {
      expect(isFimaApology('Maaf atas ketidaknyamanannya.'), isFalse);
      expect(
        isFimaApology('Kami akan menjawab pertanyaan Anda besok.'),
        isFalse,
      );
    });

    test('lets a real answer through', () {
      expect(
        isFimaApology(
          'Bengkel Fix Up Moto buka setiap hari pukul 08.00 sampai 17.00.',
        ),
        isFalse,
      );
    });

    test('has nothing to say about a blank answer', () {
      expect(isFimaApology(''), isFalse);
      expect(isFimaApology('   \n'), isFalse);
    });
  });
}
