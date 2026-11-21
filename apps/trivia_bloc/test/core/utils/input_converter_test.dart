import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/core/utils/input_converter.dart';

void main() {
  late InputConverter inputConverter;

  setUp(() {
    inputConverter = InputConverter();
  });

  group('stringToUnsignedInteger', () {
    test('should return an int when the string is an unsigned integer', () {
      // act
      final result = inputConverter.stringToUnsignedInteger('123');
      // assert
      expect(result, const Right<Failure, int>(123));
    });

    test('should accept zero', () {
      final result = inputConverter.stringToUnsignedInteger('0');
      expect(result, const Right<Failure, int>(0));
    });

    test('should return a Failure when the string is not an integer', () {
      final result = inputConverter.stringToUnsignedInteger('abc');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is a decimal', () {
      final result = inputConverter.stringToUnsignedInteger('1.0');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is a negative integer', () {
      final result = inputConverter.stringToUnsignedInteger('-123');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is empty', () {
      final result = inputConverter.stringToUnsignedInteger('');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });
  });
}
