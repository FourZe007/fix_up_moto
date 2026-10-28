import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/features/chatbot/presentation/models/agent_chat_link.dart';

void main() {
  group('agentChatMessage', () {
    test('greets and quotes the question that could not be answered', () {
      expect(
        agentChatMessage('Berapa poin saya?'),
        'Halo FixUp Moto, saya butuh bantuan. '
        'Pertanyaan saya: "Berapa poin saya?"',
      );
    });

    test('is only a greeting when there is no question', () {
      const greeting = 'Halo FixUp Moto, saya butuh bantuan.';

      expect(agentChatMessage(), greeting);
      expect(agentChatMessage(null), greeting);
      expect(agentChatMessage(''), greeting);
      expect(agentChatMessage('  \n'), greeting);
    });

    test('trims the question', () {
      expect(agentChatMessage('  poin?  '), endsWith('"poin?"'));
    });
  });

  group('agentChatUrl', () {
    test('is the customer service chat with the message typed in', () {
      final url = Uri.parse(agentChatUrl('Berapa poin saya?'));

      expect(
        '${url.scheme}://${url.host}${url.path}',
        AppConstants.whatsappServiceUrl,
      );
      expect(
        url.queryParameters['text'],
        'Halo FixUp Moto, saya butuh bantuan. '
        'Pertanyaan saya: "Berapa poin saya?"',
      );
    });

    test('writes spaces as %20, as WhatsApp\'s own links do, not as +', () {
      final url = agentChatUrl('a b');

      expect(url, contains('%20'));
      expect(url, isNot(contains('+')));
      expect(url, isNot(contains(' ')));
    });

    test('survives characters that mean something in a link', () {
      const question = 'Harga oli & busi? 50% #1 "murah"';
      final url = Uri.parse(agentChatUrl(question));

      expect(url.queryParameters.keys, ['text']);
      expect(url.queryParameters['text'], endsWith('"$question"'));
      expect(url.fragment, isEmpty);
    });

    test('keeps accents and emoji intact', () {
      const question = 'Motor saya mogok 😢 café';

      expect(
        Uri.parse(agentChatUrl(question)).queryParameters['text'],
        endsWith('"$question"'),
      );
    });

    test('is a plain greeting link when there is no question', () {
      expect(
        agentChatUrl(),
        'https://wa.me/6285179798961?text='
        'Halo%20FixUp%20Moto%2C%20saya%20butuh%20bantuan.',
      );
    });
  });
}
