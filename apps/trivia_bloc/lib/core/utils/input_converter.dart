import 'package:dartz/dartz.dart';
import 'package:trivia_bloc/core/error/failure.dart';

class InputConverter {
  /// Converts the text typed by the user into a number >= 0.
  Either<Failure, int> stringToUnsignedInteger(String str) {
    final integer = int.tryParse(str.trim());
    if (integer == null || integer < 0) {
      return const Left(InvalidInputFailure());
    }
    return Right(integer);
  }
}
