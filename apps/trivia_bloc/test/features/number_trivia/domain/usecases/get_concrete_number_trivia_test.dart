import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/failure.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/repositories/number_trivia_repository.dart';
import 'package:trivia_bloc/features/number_trivia/domain/usecases/get_concrete_number_trivia.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late GetConcreteNumberTrivia usecase;
  late MockNumberTriviaRepository mockRepository;

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
    usecase = GetConcreteNumberTrivia(mockRepository);
  });

  const tNumber = 1;
  const tNumberTrivia = NumberTrivia(text: 'test', number: tNumber);

  test('should get trivia for the number from the repository', () async {
    // arrange
    when(() => mockRepository.getConcreteNumberTrivia(any()))
        .thenAnswer((_) async => const Right(tNumberTrivia));
    // act
    final result = await usecase(const Params(number: tNumber));
    // assert
    expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
    verify(() => mockRepository.getConcreteNumberTrivia(tNumber)).called(1);
    verifyNoMoreInteractions(mockRepository);
  });

  test('should return the Failure from the repository unchanged', () async {
    when(() => mockRepository.getConcreteNumberTrivia(any()))
        .thenAnswer((_) async => const Left(ServerFailure()));

    final result = await usecase(const Params(number: tNumber));

    expect(result, const Left<Failure, NumberTrivia>(ServerFailure()));
  });
}
