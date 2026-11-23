import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/network/network_info.dart';

class MockInternetConnection extends Mock implements InternetConnection {}

void main() {
  late NetworkInfoImpl networkInfo;
  late InternetConnection mockInternetConnection;
  setUp(() {
    mockInternetConnection = MockInternetConnection();
    networkInfo = NetworkInfoImpl(mockInternetConnection);
  });

  group('isConnected', () {
    test(
      'should forward the call to InternetConnection.hasInternetAccess',
      () async {
        // Arrange
        when(() => mockInternetConnection.hasInternetAccess)
            .thenAnswer((_) async => true);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        verify(() => mockInternetConnection.hasInternetAccess).called(1);
        expect(result, true);
      },
    );
    test('should return false when there is no internet access', () async {
      when(() => mockInternetConnection.hasInternetAccess)
          .thenAnswer((_) async => false);

      final result = await networkInfo.isConnected;

      expect(result, false);
    });
  });
}
