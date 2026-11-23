import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/core/usecases/usecase.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/repositories/number_trivia_repository.dart';
import 'package:trivia_bloc/features/number_trivia/domain/usecases/get_random_number_trivia.dart';

class MockGetRandomNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late MockGetRandomNumberTriviaRepository mockRepository;
  late GetRandomNumberTrivia usecase;
  setUp(() {
    mockRepository = MockGetRandomNumberTriviaRepository();
    usecase = GetRandomNumberTrivia(mockRepository);
  });

  const tNumberTrivia = NumberTrivia(text: 'test', number: 1);

  test('should get random trivia from the repository', () async {
    // Arrange
    when(() => mockRepository.getRandomNumberTrivia())
        .thenAnswer((_) async =>  Right(tNumberTrivia));

    // Act
    final result = await usecase(const NoParams());
    // Assert
    expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
    verify(() => mockRepository.getRandomNumberTrivia()).called(1);
    verifyNoMoreInteractions(mockRepository);
  });

  test('should get failure when repository returns failure', () async {
    // Arrange
    when(() => mockRepository.getRandomNumberTrivia())
        .thenAnswer((_) async => const Left(ServerFailure()));

    // Act
    final result = await usecase(const NoParams());
    // Assert
    expect(result, const Left<Failure, NumberTrivia>(ServerFailure()));
  });
}
