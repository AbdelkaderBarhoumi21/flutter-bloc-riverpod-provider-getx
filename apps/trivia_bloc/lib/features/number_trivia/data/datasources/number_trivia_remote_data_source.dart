import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:trivia_bloc/core/constants/api_constants.dart';
import 'package:trivia_bloc/core/error/exceptions.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';

abstract interface class NumberTriviaRemoteDataSource {
  /// Calls the http://numbersapi.com/{number} endpoint.
  ///
  /// Throws a [ServerException] for all error codes.
  Future<NumberTriviaModel> getConcreteNumberTrivia(int number);

  /// Calls the http://numbersapi.com/random endpoint.
  ///
  /// Throws a [ServerException] for all error codes.
  Future<NumberTriviaModel> getRandomNumberTrivia();
}

class NumberTriviaRemoteDataSourceImpl implements NumberTriviaRemoteDataSource {
  final http.Client client;

  NumberTriviaRemoteDataSourceImpl({required this.client});

  @override
  Future<NumberTriviaModel> getConcreteNumberTrivia(int number) =>
      _getTriviaFromUrl(ApiConstants.concreteNumberTrivia(number));

  @override
  Future<NumberTriviaModel> getRandomNumberTrivia() =>
      _getTriviaFromUrl(ApiConstants.randomTriviaUrl);

  Future<NumberTriviaModel> _getTriviaFromUrl(String url) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
    } on http.ClientException {
      throw ServerException();
    }
    if (response.statusCode != 200) {
      throw ServerException();
    }
    return NumberTriviaModel.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}
