import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/chatbot/domain/repositories/chat_repository.dart';

/// Asks Fima one question and returns her answer.
class AskFimaUseCase extends UseCase<String, AskFimaParams> {
  final ChatRepository repository;
  AskFimaUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(AskFimaParams params) =>
      repository.ask(params.question);
}

class AskFimaParams extends Equatable {
  final String question;

  const AskFimaParams(this.question);

  @override
  List<Object> get props => [question];
}
