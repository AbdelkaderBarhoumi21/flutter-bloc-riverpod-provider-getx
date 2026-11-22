import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:trivia_bloc/core/error/failure.dart';

/// Every use case has one public method, `call`, so it can be invoked like a
/// function: `getRandomNumberTrivia(const NoParams())`.
abstract interface class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
