import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/chatbot/data/datasources/chat_remote_data_source.dart';
import 'package:fix_up_moto/features/chatbot/data/repositories/chat_repository_impl.dart';
import 'package:fix_up_moto/features/chatbot/domain/entities/chat_message.dart';

class MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockChatRemoteDataSource dataSource;
  late MockNetworkInfo networkInfo;
  late ChatRepositoryImpl repository;

  setUp(() {
    dataSource = MockChatRemoteDataSource();
    networkInfo = MockNetworkInfo();
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    repository = ChatRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: networkInfo,
    );
  });

  void givenAnswer(Future<String> Function() answer) =>
      when(() => dataSource.ask(any())).thenAnswer((_) => answer());

  group('ask', () {
    test('passes the question through and returns the answer', () async {
      givenAnswer(() async => 'Jawaban');

      expect(await repository.ask('Halo?'), const Right('Jawaban'));
      verify(() => dataSource.ask('Halo?')).called(1);
    });

    group('with no connection', () {
      setUp(
        () =>
            when(() => networkInfo.isConnected).thenAnswer((_) async => false),
      );

      test('does not ask at all, and says there is no connection', () async {
        givenAnswer(() async => 'Jawaban');

        final result = await repository.ask('Halo?');

        expect(result, const Left(NetworkFailure('No internet connection')));
        verifyNever(() => dataSource.ask(any()));
      });

      test('asks again once the connection is back', () async {
        givenAnswer(() async => 'Jawaban');
        expect((await repository.ask('Halo?')).isLeft(), isTrue);

        when(() => networkInfo.isConnected).thenAnswer((_) async => true);

        expect(await repository.ask('Halo?'), const Right('Jawaban'));
      });
    });

    test('trims the answer', () async {
      givenAnswer(() async => '  Jawaban\n');

      expect(await repository.ask('Halo?'), const Right('Jawaban'));
    });

    for (final blank in ['', '   ', '\n\t']) {
      test(
        'treats a blank answer (${blank.codeUnits}) as no answer at all',
        () async {
          givenAnswer(() async => blank);

          final result = await repository.ask('Halo?');

          expect(result.isLeft(), isTrue);
          expect(result.fold((f) => f, (_) => null), isA<ServerFailure>());
        },
      );
    }

    group('turns what goes wrong into a failure', () {
      Future<Failure?> failureOf(Object error) async {
        givenAnswer(() => Future<String>.error(error));
        return (await repository.ask('Halo?')).fold((f) => f, (_) => null);
      }

      test('no connection', () async {
        expect(
          await failureOf(const NetworkException(message: 'offline')),
          const NetworkFailure('offline'),
        );
      });

      test('the service failing, with its status', () async {
        expect(
          await failureOf(
            const ServerException(message: 'Boom', statusCode: 500),
          ),
          const ServerFailure('Boom', statusCode: 500),
        );
      });

      test('an expired session', () async {
        expect(
          await failureOf(const UnauthorizedException()),
          isA<AuthFailure>(),
        );
      });

      test(
        'anything unexpected, including errors and not just exceptions',
        () async {
          for (final surprise in [
            const FormatException('not json'),
            TypeError(),
            StateError('nope'),
            'a plain string, thrown',
          ]) {
            expect(
              await failureOf(surprise),
              isA<ServerFailure>(),
              reason: '$surprise',
            );
          }
        },
      );

      test('an unexpected failure is never left unreported by throwing out of '
          'ask', () async {
        givenAnswer(() => throw StateError('thrown, not returned as a Future'));

        expect((await repository.ask('Halo?')).isLeft(), isTrue);
      });
    });
  });

  group('the kept conversation', () {
    final time = DateTime(2026, 10, 20, 9);
    ChatMessage message(String id) => ChatMessage(
      id: id,
      text: 'Pesan $id',
      sender: ChatSender.user,
      status: ChatMessageStatus.sent,
      createdAt: time,
    );

    test('is empty when nothing has been kept', () {
      expect(repository.loadHistory('M-1'), isEmpty);
    });

    test('comes back as it was saved, in order', () {
      repository.saveHistory('M-1', [message('a'), message('b')]);

      expect(repository.loadHistory('M-1'), [message('a'), message('b')]);
    });

    test('belongs to one member: another gets nothing', () {
      repository.saveHistory('M-1', [message('a')]);

      expect(repository.loadHistory('M-2'), isEmpty);
    });

    test('is not shown to the next member, and is replaced when they save', () {
      repository.saveHistory('M-1', [message('a')]);

      expect(repository.loadHistory('M-2'), isEmpty);
      // Looking did not disturb it...
      expect(repository.loadHistory('M-1'), [message('a')]);

      // ...but their own chat takes its place, and the first member's is gone.
      repository.saveHistory('M-2', [message('b')]);
      expect(repository.loadHistory('M-2'), [message('b')]);
      expect(repository.loadHistory('M-1'), isEmpty);
    });

    test('saving replaces what was kept, not adds to it', () {
      repository.saveHistory('M-1', [message('a'), message('b')]);
      repository.saveHistory('M-1', [message('c')]);

      expect(repository.loadHistory('M-1'), [message('c')]);
    });

    test('cannot be changed from outside by editing the list that was saved '
        'or the one loaded', () {
      final saved = [message('a')];
      repository.saveHistory('M-1', saved);

      saved.add(message('b'));
      expect(repository.loadHistory('M-1'), [message('a')]);
      expect(
        () => repository.loadHistory('M-1').add(message('c')),
        throwsUnsupportedError,
      );
    });

    test('can be emptied by saving nothing', () {
      repository.saveHistory('M-1', [message('a')]);
      repository.saveHistory('M-1', const []);

      expect(repository.loadHistory('M-1'), isEmpty);
    });
  });
}
