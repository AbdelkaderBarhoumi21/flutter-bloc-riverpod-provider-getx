import 'package:equatable/equatable.dart';

/// Base class for all failure types.
sealed class Failure extends Equatable {
  const Failure();
  @override
  List<Object?> get props => [];
}

final class ServerFailure extends Failure {
  const ServerFailure();
}

final class CacheFailure extends Failure {
  const CacheFailure();
}

final class InvalidInputFailure extends Failure {
  const InvalidInputFailure();
}
