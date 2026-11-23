import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/constants/api_constants.dart';
import 'package:trivia_bloc/core/error/exceptions.dart';
import 'package:trivia_bloc/features/number_trivia/data/datasources/number_trivia_remote_data_source.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';

import '../../../../fixtures/fixture_reader.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late NumberTriviaRemoteDataSourceImpl dataSource;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    // mocktail needs a fallback value to use `any()` for a non-null Uri.
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    dataSource = NumberTriviaRemoteDataSourceImpl(client: mockHttpClient);
  });

  void setUpMockHttpClientSuccess200() {
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(fixture('trivia.json'), 200));
  }

  void setUpMockHttpClientFailure404() {
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('Something went wrong', 404));
  }

  final tNumberTriviaModel = NumberTriviaModel.fromJson(
    json.decode(fixture('trivia.json')) as Map<String, dynamic>,
  );

  group('getConcreteNumberTrivia', () {
    const tNumber = 1;

    test(
      'should perform a GET request on the number URL with a JSON header',
      () async {
        // arrange
        setUpMockHttpClientSuccess200();
        // act
        await dataSource.getConcreteNumberTrivia(tNumber);
        // assert
        verify(
          () => mockHttpClient.get(
            Uri.parse(ApiConstants.concreteNumberTrivia(tNumber)),
            headers: {'Content-Type': 'application/json'},
          ),
        ).called(1);
      },
    );

    test(
      'should return NumberTriviaModel when the response code is 200',
      () async {
        setUpMockHttpClientSuccess200();

        final result = await dataSource.getConcreteNumberTrivia(tNumber);

        expect(result, tNumberTriviaModel);
      },
    );

    test(
      'should throw a ServerException when the response code is 404',
      () async {
        setUpMockHttpClientFailure404();

        final call = dataSource.getConcreteNumberTrivia;

        expect(() => call(tNumber), throwsA(isA<ServerException>()));
      },
    );

    test('should throw a ServerException when the request fails', () async {
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(http.ClientException('no route to host'));

      final call = dataSource.getConcreteNumberTrivia;

      expect(() => call(tNumber), throwsA(isA<ServerException>()));
    });
  });

  group('getRandomNumberTrivia', () {
    test(
      'should perform a GET request on the random URL with a JSON header',
      () async {
        setUpMockHttpClientSuccess200();

        await dataSource.getRandomNumberTrivia();

        verify(
          () => mockHttpClient.get(
            Uri.parse(ApiConstants.randomTriviaUrl),
            headers: {'Content-Type': 'application/json'},
          ),
        ).called(1);
      },
    );

    test(
      'should return NumberTriviaModel when the response code is 200',
      () async {
        setUpMockHttpClientSuccess200();

        final result = await dataSource.getRandomNumberTrivia();

        expect(result, tNumberTriviaModel);
      },
    );

    test(
      'should throw a ServerException when the response code is 404',
      () async {
        setUpMockHttpClientFailure404();

        final call = dataSource.getRandomNumberTrivia;

        expect(() => call(), throwsA(isA<ServerException>()));
      },
    );
  });
}
