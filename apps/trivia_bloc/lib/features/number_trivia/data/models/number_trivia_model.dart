import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';

class NumberTriviaModel extends NumberTrivia {
  const NumberTriviaModel({required super.text, required super.number});
  factory NumberTriviaModel.fromJson(Map<String, dynamic> json) {
    return NumberTriviaModel(
      text: json['text'] as String,
      // The API can send 1 or 1.0, so read it as `num` and convert.
      number: (json['number'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'number': number};
}
