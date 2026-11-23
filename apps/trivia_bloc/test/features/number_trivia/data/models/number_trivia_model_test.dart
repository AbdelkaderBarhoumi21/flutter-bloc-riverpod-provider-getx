import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  const tNumberTriviaModel = NumberTriviaModel(text: 'Test Text', number: 1);

  test('should be a subclass of NumberTrivia entity', () async {
    // assert
    expect(tNumberTriviaModel, isA<NumberTrivia>());
  });

  group('fromJson', () {
    test('should return a valid model when the json number is an integer', () {
      // Arrange
      final jsonMap =
          json.decode(fixture('trivia.json')) as Map<String, dynamic>;
      // Act
      final result = NumberTriviaModel.fromJson(jsonMap);
      // Assert
      expect(result, tNumberTriviaModel);
    });
    test('should return a valid model when the JSON number is a double', () {
      final jsonMap =
          json.decode(fixture('trivia_double.json')) as Map<String, dynamic>;

      final result = NumberTriviaModel.fromJson(jsonMap);

      expect(result, tNumberTriviaModel);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () {
      final result = tNumberTriviaModel.toJson();
      expect(result, {'text': 'Test Text', 'number': 1});
    });
  });
}
