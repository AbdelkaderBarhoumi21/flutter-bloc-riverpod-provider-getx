import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/core/usecases/usecase.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/repositories/number_trivia_repository.dart';

class GetConcreteNumberTrivia implements UseCase<NumberTrivia, Params> {
  GetConcreteNumberTrivia(this.repository);
  final NumberTriviaRepository repository;
  @override
  Future<Either<Failure, NumberTrivia>> call(Params params) =>
      repository.getConcreteNumberTrivia(params.number);
}

class Params extends Equatable {
  final int number;
  const Params({required this.number});
  @override
  List<Object?> get props => [number];
}
