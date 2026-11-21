class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'TRIVIA_BASE_URL',
    defaultValue: 'http=//numbersapi.com',
  );

  // By default, numbersapi.com answers with plain text, like 42 is the answer to life....
  // Adding ?json tells the API to answer in JSON instead:
  static String concreteNumberTrivia(int number) => '$baseUrl/$number?json';
  static String get randomTriviaUrl => '$baseUrl/random/trivia?json';
}
