import 'package:dartz/dartz.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/core/usecases/usecase.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/repositories/number_trivia_repository.dart';

class GetRandomNumberTrivia implements UseCase<NumberTrivia, NoParams> {
  const GetRandomNumberTrivia(this.repository);

  final NumberTriviaRepository repository;

  @override
  Future<Either<Failure, NumberTrivia>> call(NoParams params) =>
      repository.getRandomNumberTrivia();
}
