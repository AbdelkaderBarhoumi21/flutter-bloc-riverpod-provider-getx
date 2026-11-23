import 'package:dartz/dartz.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';

/// The contract the domain layer needs. The data layer implements it.
abstract interface class NumberTriviaRepository {
  Future<Either<Failure, NumberTrivia>> getConcreteNumberTrivia(int number);

  Future<Either<Failure, NumberTrivia>> getRandomNumberTrivia();
}
