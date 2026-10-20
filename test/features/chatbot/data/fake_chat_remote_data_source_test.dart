import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import '../support/fake_chat_remote_data_source.dart';

void main() {
  const source = FakeChatRemoteDataSource(delay: Duration.zero);

  test('answers a question with a sample that says it is one and repeats the '
      'question', () async {
    final answer = await source.ask('  Berapa biaya ganti oli?  ');

    expect(answer, contains('“Berapa biaya ganti oli?”'));
    expect(answer, contains('contoh jawaban'));
  });

  group('the test words', () {
    test('/error fails the way the server does', () async {
      await expectLater(
        source.ask('/error'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 500),
        ),
      );
    });

    test('/offline fails the way no connection does', () async {
      await expectLater(
        source.ask('/offline'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('/kosong answers with nothing', () async {
      expect(await source.ask('/kosong'), isEmpty);
    });

    test('/panjang answers at length, over several lines', () async {
      final answer = await source.ask('/panjang');

      expect(answer, FakeChatRemoteDataSource.longAnswer);
      expect('\n'.allMatches(answer).length, greaterThan(3));
    });

    test('are matched however they are cased or padded', () async {
      await expectLater(
        source.ask('  /ERROR '),
        throwsA(isA<ServerException>()),
      );
    });

    test('are only special as the whole question', () async {
      expect(await source.ask('kenapa /error terus?'), contains('contoh'));
    });
  });

  group('how long it takes', () {
    testWidgets('a normal answer waits the delay, and not a moment less', (
      tester,
    ) async {
      var answered = false;
      const slow = FakeChatRemoteDataSource(delay: Duration(seconds: 2));
      unawaited(slow.ask('halo').then((_) => answered = true));

      await tester.pump(const Duration(milliseconds: 1999));
      expect(answered, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(answered, isTrue);
    });

    testWidgets('/lambat waits the slow delay', (tester) async {
      var answered = false;
      unawaited(source.ask('/lambat').then((_) => answered = true));

      await tester.pump(
        FakeChatRemoteDataSource.slowDelay - const Duration(milliseconds: 1),
      );
      expect(answered, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(answered, isTrue);
    });
  });
}
