# Number Trivia with **Provider** + **MVVM** (Flutter's official architecture), step by step (TDD)

> **Guide 4 of 4** in the *Number Trivia: 4 state managements* series
> (Bloc · Riverpod · GetX · Provider). Same app, same monorepo, different architecture.

Every line of the app is in this guide, **in the order you type it**. After each file that
has logic, you write its test straight away, run it, see it pass, and only then go on.

**What you will have at the end:** 54 unit + widget tests and 4 integration tests, all
passing. They were run on Flutter 3.47 / Dart 3.13 with `provider` 6.1.

## Contents

0. [The app](#0-the-app)
1. [Why MVVM for Provider](#1-why-mvvm-for-provider)
2. [Final folder structure](#2-final-folder-structure)
3. [Project setup](#3-project-setup)
4. [Part A: Utils and config](#part-a--utils-and-config)
5. [Part B: Domain model](#part-b--domain-model)
6. [Part C: Data layer: services and repository](#part-c--data-layer-services-and-repository)
7. [Part D: The ViewModel](#part-d--the-viewmodel)
8. [Part E: UI widgets and screen](#part-e--ui-widgets-and-screen)
9. [Part F: Dependencies, app, main](#part-f--dependencies-app-main)
10. [Part G: Integration test](#part-g--integration-test)
11. [Final check](#final-check)

## 0. The app

The same **Number Trivia** app as in the other guides. The user types a number and gets a
fact about it, or asks for a random one. Offline, the app shows the last cached fact.

```text
┌──────────────────────────────┐
│ Number Trivia                │
├──────────────────────────────┤
│              42              │  ← context.watch<NumberTriviaViewModel>().state
│  42 is the answer to life…   │    TriviaEmpty / TriviaLoading / TriviaLoaded / TriviaError
│ ┌──────────────────────────┐ │
│ │ Input a number           │ │
│ └──────────────────────────┘ │
│ [   Search   ] [ Get random ]│  ← context.read<NumberTriviaViewModel>()…
└──────────────────────────────┘
```

## 1. Why MVVM for Provider

`provider` is the package used by **Flutter's official "Guide to app architecture"**
(docs.flutter.dev/app-architecture). That guide recommends **MVVM** with two layers, and
this app follows it closely:

```text
              UI LAYER                                     DATA LAYER
 ┌─────────────────────────────────────┐   ┌──────────────────────────────────────────────┐
 │ View: NumberTriviaScreen            │   │ Repository: NumberTriviaRepository           │
 │   context.watch → rebuild on notify │   │   (single source of truth, combines services)│
 │ ViewModel: NumberTriviaViewModel    │──▶│ Services (one per outside source):           │
 │   ChangeNotifier, sealed UI state   │   │   NumberTriviaApiService   → http            │
 └─────────────────────────────────────┘   │   NumberTriviaCacheService → shared_prefs    │
                                           │   ConnectivityService      → internet check  │
        domain/models: NumberTrivia        └──────────────────────────────────────────────┘
        utils: Result<T> (Ok / Err)        config/dependencies.dart: all providers in one list
```

| Rule from the official guide | How this app does it |
|---|---|
| **View** = widgets only, no logic | `NumberTriviaScreen` just switches on the state |
| **ViewModel** = UI state + UI logic, a `ChangeNotifier` | `NumberTriviaViewModel`; one per screen, created with `ChangeNotifierProvider` |
| **Repository** = single source of truth for a type of data | `NumberTriviaRepository` decides between API and cache |
| **Service** = wraps one outside API, holds no state | API, cache and connectivity services |
| **Errors as values with `Result`** | Services return `Ok(trivia)` / `Err(exception)`; nothing throws across layers |
| **Dependency injection with `provider`** | `buildProviders()` in `config/dependencies.dart`, used by `MultiProvider` |

**How the four guides differ**

* **Bloc:** events/states + use cases + `Either` + `get_it`.
* **Riverpod:** providers are the DI; `AsyncValue`; exceptions + `guard`.
* **GetX:** `.obs`; Bindings; controller owns the text controller.
* **Provider:** the official Flutter way: `ChangeNotifier` ViewModel, `Result` type, DI
  through the widget tree.

**Packages**

| Package | Role |
|---|---|
| `provider` 6.x | Dependency injection through the widget tree + `ChangeNotifierProvider` |
| `http` | API (+ `http/testing.dart` fake server) |
| `shared_preferences` | Cache |
| `internet_connection_checker_plus` | Real internet check |
| `mocktail` (dev) | Mocks without code generation |
| `integration_test` (dev, SDK) | Run the real app in tests |

## 2. Final folder structure

What you will have at the end. `test/` mirrors `lib/`.

```text
trivia_provider/
├── lib/
│   ├── config/
│   │   ├── api_constants.dart
│   │   └── dependencies.dart
│   ├── data/
│   │   ├── repositories/
│   │   │   └── number_trivia_repository.dart
│   │   └── services/
│   │       ├── connectivity_service.dart
│   │       ├── number_trivia_api_service.dart
│   │       └── number_trivia_cache_service.dart
│   ├── domain/
│   │   └── models/
│   │       └── number_trivia.dart
│   ├── ui/
│   │   ├── core/
│   │   │   └── widgets/
│   │   │       ├── loading_widget.dart
│   │   │       └── message_display.dart
│   │   └── number_trivia/
│   │       ├── view_models/
│   │       │   └── number_trivia_view_model.dart
│   │       └── widgets/
│   │           ├── number_trivia_screen.dart
│   │           ├── trivia_controls.dart
│   │           └── trivia_display.dart
│   ├── utils/
│   │   ├── app_exception.dart
│   │   ├── input_converter.dart
│   │   └── result.dart
│   ├── app.dart
│   └── main.dart
├── test/
│   ├── data/
│   │   ├── repositories/
│   │   │   └── number_trivia_repository_test.dart
│   │   └── services/
│   │       ├── connectivity_service_test.dart
│   │       ├── number_trivia_api_service_test.dart
│   │       └── number_trivia_cache_service_test.dart
│   ├── domain/
│   │   └── models/
│   │       └── number_trivia_test.dart
│   ├── fixtures/
│   │   ├── fixture_reader.dart
│   │   ├── trivia.json
│   │   ├── trivia_cached.json
│   │   └── trivia_double.json
│   ├── ui/
│   │   ├── core/
│   │   │   └── widgets/
│   │   │       ├── loading_widget_test.dart
│   │   │       └── message_display_test.dart
│   │   └── number_trivia/
│   │       ├── view_models/
│   │       │   └── number_trivia_view_model_test.dart
│   │       └── widgets/
│   │           ├── number_trivia_screen_test.dart
│   │           ├── trivia_controls_test.dart
│   │           └── trivia_display_test.dart
│   └── utils/
│       ├── app_exception_test.dart
│       └── input_converter_test.dart
└── integration_test/
    └── app_test.dart

(+ pubspec.yaml, analysis_options.yaml, android/, ios/ … created by flutter create)
```

## 3. Project setup

### 3.1 Create the app in the monorepo

```bash
cd flutter-state-management-showdown/apps   # your repo's apps/ folder
flutter create --org com.example --platforms=android,ios,macos trivia_provider
cd trivia_provider
```

### 3.2 Dependencies

```bash
flutter pub add provider http shared_preferences internet_connection_checker_plus
flutter pub add dev:mocktail "dev:integration_test:{sdk: flutter}"
```

`pubspec.yaml` (keep the `environment: sdk:` value that `flutter create` wrote):

```yaml
name: trivia_provider
description: "Number Trivia - Provider + MVVM"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.0 # keep the value flutter create generated

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.5+1
  http: ^1.6.0
  shared_preferences: ^2.5.6
  internet_connection_checker_plus: ^3.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.5
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

### 3.3 Delete the default test

```bash
rm test/widget_test.dart
```

### 3.4 Platform setup (only needed to run the app on a phone)

The default API is `http://numbersapi.com`. It is plain **http**, so Android and iOS
block it unless you allow it. (The automated tests never touch the network, so they pass
without this. You only need it to run the app.)

**Android:** `trivia_provider/android/app/src/main/AndroidManifest.xml`. Add the permission
above `<application>` and the cleartext flag on `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="trivia_provider"
        android:name="${applicationName}"
        android:usesCleartextTraffic="true"
        android:icon="@mipmap/ic_launcher">
        <!-- keep everything flutter create generated in here -->
```

**iOS:** `trivia_provider/ios/Runner/Info.plist`. Add this inside the top `<dict>`
(development only; for a real release use an https API):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Your own server.** If you run the Number Trivia API yourself (for example on port 8083),
pass its address when you run the app. `10.0.2.2` is your computer as seen from the
Android emulator:

```bash
flutter run --dart-define=TRIVIA_BASE_URL=http://10.0.2.2:8083
```

### Provider in 60 seconds (words used below)

| Term | Meaning |
|---|---|
| `Provider(create: …)` | Puts an object in the widget tree; every widget below can get it. |
| `ChangeNotifierProvider` | Like `Provider`, for a `ChangeNotifier`: it rebuilds listeners and **disposes** the notifier for you. |
| `MultiProvider(providers: [...])` | Many providers without deep nesting. |
| `context.watch<T>()` | Get `T` **and** rebuild when it notifies (use in `build`). |
| `context.read<T>()` | Get `T` once, without listening (use in callbacks and `create`). |
| `notifyListeners()` | Called by the ViewModel after changing its state, so watchers rebuild. |
| `Result` / `Ok` / `Err` | Our sealed type: success with a value, or failure with an exception. |

### How to work through this guide (the TDD rhythm)

Every step follows the same loop:

1. 📄 **Write the file** (production code).
2. 🧪 **Write its test** right away, if the file has logic.
3. ▶️ **Run only that test** with the command given.
4. ✅ **Check you get the expected number of passing tests.** Then go to the next step.

Files with no logic (pure data classes, interfaces, constants, barrel exports) have no
test of their own. Each one says why, and says which later test covers it.

> 💡 **Want strict TDD?** In every step, type the test file first, run it, and watch it
> fail (red). Then type the production file and run it again (green). The order of steps
> stays the same.

**Test words used in this guide**

| Word | Meaning |
|---|---|
| **Arrange / Act / Assert** | Prepare the mocks → call the code → check the result. Every test follows these three parts. |
| **Mock** (`mocktail`) | A fake object whose answers you choose: `when(() => mock.x()).thenAnswer(...)`. You check calls with `verify(...)`. |
| **`registerFallbackValue`** | mocktail needs one example value of a custom type before you can write `any()` for that type. |
| **Unit test** | Tests one class with its dependencies mocked. Fast and runs anywhere. |
| **Widget test** | Builds one widget in a fake screen (`testWidgets`, `tester.pumpWidget`). No device needed. |
| **Integration test** | Runs the whole app on a real device, simulator or desktop (`integration_test/`). |

---

## Part A — Utils and config

Small building blocks used by every layer.

### Step 1 — Result: Ok or Err

The official Flutter architecture guide returns errors as **values**. `Result<T>` is either
`Ok(value)` or `Err(exception)`. Because it is `sealed`, a `switch` on it must handle both.

📄 **Create:** `trivia_provider/lib/utils/result.dart`

```dart
/// The result of an operation that can fail: either [Ok] with a value or
/// [Err] with an exception. This is the error-handling style recommended by
/// Flutter's official architecture guide.
///
/// `sealed` lets `switch` check that both cases are handled:
/// ```dart
/// switch (result) {
///   case Ok(:final value): ...
///   case Err(:final error): ...
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final Exception error;

  @override
  String toString() => 'Err($error)';
}
```

> 🧪 **No test for this file:** two tiny value classes with no logic. Every service, repository and ViewModel test checks Results.

### Step 2 — AppException: typed errors with their message

📄 **Create:** `trivia_provider/lib/utils/app_exception.dart`

```dart
/// Every error the app knows how to show. Each one carries its message.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ServerException extends AppException {
  const ServerException() : super('Server Failure');
}

final class CacheException extends AppException {
  const CacheException() : super('Cache Failure');
}

final class InvalidInputException extends AppException {
  const InvalidInputException()
    : super('Invalid Input - The number must be a positive integer or zero');
}

/// Turns any error into text for the UI.
String errorMessageFor(Exception error) {
  return switch (error) {
    AppException(:final message) => message,
    _ => 'Unexpected error',
  };
}
```

📄 **Create the test:** `trivia_provider/test/utils/app_exception_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/utils/app_exception.dart';

void main() {
  group('errorMessageFor', () {
    test('should return the message of an AppException', () {
      expect(errorMessageFor(const ServerException()), 'Server Failure');
      expect(errorMessageFor(const CacheException()), 'Cache Failure');
      expect(
        errorMessageFor(const InvalidInputException()),
        'Invalid Input - The number must be a positive integer or zero',
      );
    });

    test('should return "Unexpected error" for any other exception', () {
      expect(errorMessageFor(Exception('boom')), 'Unexpected error');
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/utils/app_exception_test.dart
```

✅ **Expected:** `+2: All tests passed!` — green? Go to the next step.

### Step 3 — Input converter (returns a Result)

Invalid input is not thrown: it comes back as `Err(InvalidInputException())`, like every
other error in this app.

📄 **Create:** `trivia_provider/lib/utils/input_converter.dart`

```dart
import 'app_exception.dart';
import 'result.dart';

/// Converts the text typed by the user into a number >= 0.
Result<int> stringToUnsignedInteger(String input) {
  final integer = int.tryParse(input.trim());
  if (integer == null || integer < 0) {
    return const Err(InvalidInputException());
  }
  return Ok(integer);
}
```

📄 **Create the test:** `trivia_provider/test/utils/input_converter_test.dart`

`isA<Ok<int>>().having((r) => r.value, 'value', 123)` looks **inside** the Result. We use
this matcher style in every Result test.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/input_converter.dart';
import 'package:trivia_provider/utils/result.dart';

void main() {
  // Matchers that look inside a Result.
  Matcher isOk(int value) =>
      isA<Ok<int>>().having((r) => r.value, 'value', value);
  final isInvalidInput = isA<Err<int>>().having(
    (r) => r.error,
    'error',
    isA<InvalidInputException>(),
  );

  group('stringToUnsignedInteger', () {
    test('should return Ok(int) when the string is an unsigned integer', () {
      expect(stringToUnsignedInteger('123'), isOk(123));
    });

    test('should accept zero', () {
      expect(stringToUnsignedInteger('0'), isOk(0));
    });

    test('should return Err for a non-number', () {
      expect(stringToUnsignedInteger('abc'), isInvalidInput);
    });

    test('should return Err for a decimal', () {
      expect(stringToUnsignedInteger('1.0'), isInvalidInput);
    });

    test('should return Err for a negative integer', () {
      expect(stringToUnsignedInteger('-123'), isInvalidInput);
    });

    test('should return Err for an empty string', () {
      expect(stringToUnsignedInteger(''), isInvalidInput);
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/utils/input_converter_test.dart
```

✅ **Expected:** `+6: All tests passed!` — green? Go to the next step.

### Step 4 — API URLs

📄 **Create:** `trivia_provider/lib/config/api_constants.dart`

```dart
/// All URLs used by the app live here, so tests and code share one source.
///
/// Override the server at run time with:
/// `flutter run --dart-define=TRIVIA_BASE_URL=http://10.0.2.2:8083`
class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'TRIVIA_BASE_URL',
    defaultValue: 'http://numbersapi.com',
  );

  static String concreteTriviaUrl(int number) => '$baseUrl/$number?json';

  static String get randomTriviaUrl => '$baseUrl/random/trivia?json';
}
```

> 🧪 **No test for this file:** constants only. The API service test checks the exact URLs (Step 8).

---

## Part B — Domain model

### Step 5 — Test fixtures

Fake API answers. `trivia_double.json` checks that `1.0` is read as `1`.

📄 **Create the test:** `trivia_provider/test/fixtures/trivia.json`

```json
{
  "text": "Test Text",
  "number": 1,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_provider/test/fixtures/trivia_double.json`

```json
{
  "text": "Test Text",
  "number": 1.0,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_provider/test/fixtures/trivia_cached.json`

```json
{
  "text": "Test Text",
  "number": 1
}
```

📄 **Create the test:** `trivia_provider/test/fixtures/fixture_reader.dart`

```dart
import 'dart:io';

/// Reads a JSON file from `test/fixtures/`.
/// Works because `flutter test` runs from the project root.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
```

> 🧪 **No test for this file:** test helpers, used from the next step on.

### Step 6 — Model: NumberTrivia

An immutable model with JSON and hand-written value equality (`==`, `hashCode`).

📄 **Create:** `trivia_provider/lib/domain/models/number_trivia.dart`

```dart
import 'package:flutter/foundation.dart';

/// The domain model. It also reads and writes JSON, so there is no separate
/// Entity / Model pair.
@immutable
class NumberTrivia {
  const NumberTrivia({required this.text, required this.number});

  factory NumberTrivia.fromJson(Map<String, dynamic> json) {
    return NumberTrivia(
      text: json['text'] as String,
      // The API can send 1 or 1.0, so read it as `num` and convert.
      number: (json['number'] as num).toInt(),
    );
  }

  final String text;
  final int number;

  Map<String, dynamic> toJson() => {'text': text, 'number': number};

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NumberTrivia && other.text == text && other.number == number;
  }

  @override
  int get hashCode => Object.hash(text, number);

  @override
  String toString() => 'NumberTrivia(number: $number, text: $text)';
}
```

📄 **Create the test:** `trivia_provider/test/domain/models/number_trivia_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';

import '../../fixtures/fixture_reader.dart';

void main() {
  const tNumberTrivia = NumberTrivia(text: 'Test Text', number: 1);

  group('equality', () {
    test('two objects with the same values should be equal', () {
      expect(
        const NumberTrivia(text: 'a', number: 1),
        const NumberTrivia(text: 'a', number: 1),
      );
    });

    test('objects with different values should not be equal', () {
      expect(
        const NumberTrivia(text: 'a', number: 1),
        isNot(const NumberTrivia(text: 'a', number: 2)),
      );
    });
  });

  group('fromJson', () {
    test('should return a valid object when the JSON number is an integer', () {
      final jsonMap =
          json.decode(fixture('trivia.json')) as Map<String, dynamic>;

      expect(NumberTrivia.fromJson(jsonMap), tNumberTrivia);
    });

    test('should return a valid object when the JSON number is a double', () {
      final jsonMap =
          json.decode(fixture('trivia_double.json')) as Map<String, dynamic>;

      expect(NumberTrivia.fromJson(jsonMap), tNumberTrivia);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing the proper data', () {
      expect(tNumberTrivia.toJson(), {'text': 'Test Text', 'number': 1});
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/domain/models/number_trivia_test.dart
```

✅ **Expected:** `+5: All tests passed!` — green? Go to the next step.

---

## Part C — Data layer: services and repository

**Services** each wrap one outside thing and never throw. The **repository** combines them.

### Step 7 — ConnectivityService

📄 **Create:** `trivia_provider/lib/data/services/connectivity_service.dart`

```dart
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Wraps internet_connection_checker_plus: is there real internet access?
class ConnectivityService {
  ConnectivityService(this.connectionChecker);

  final InternetConnection connectionChecker;

  Future<bool> get isConnected => connectionChecker.hasInternetAccess;
}
```

📄 **Create the test:** `trivia_provider/test/data/services/connectivity_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_provider/data/services/connectivity_service.dart';

class MockInternetConnection extends Mock implements InternetConnection {}

void main() {
  late ConnectivityService connectivityService;
  late MockInternetConnection mockInternetConnection;

  setUp(() {
    mockInternetConnection = MockInternetConnection();
    connectivityService = ConnectivityService(mockInternetConnection);
  });

  test(
    'should forward the call to InternetConnection.hasInternetAccess',
    () async {
      // arrange
      when(() => mockInternetConnection.hasInternetAccess)
          .thenAnswer((_) async => true);
      // act
      final result = await connectivityService.isConnected;
      // assert
      verify(() => mockInternetConnection.hasInternetAccess).called(1);
      expect(result, true);
    },
  );
}
```

▶️ **Run it:**

```bash
flutter test test/data/services/connectivity_service_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 8 — NumberTriviaApiService (http)

The `try/catch` lives **here**, at the edge of the app. Everything above this point
works with `Result`s.

📄 **Create:** `trivia_provider/lib/data/services/number_trivia_api_service.dart`

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_constants.dart';
import '../../domain/models/number_trivia.dart';
import '../../utils/app_exception.dart';
import '../../utils/result.dart';

/// A service wraps ONE outside source (here: the HTTP API).
/// It never throws: every problem comes back as `Err(ServerException())`.
class NumberTriviaApiService {
  const NumberTriviaApiService({required this.client});

  final http.Client client;

  Future<Result<NumberTrivia>> getConcreteNumberTrivia(int number) =>
      _getTriviaFromUrl(ApiConstants.concreteTriviaUrl(number));

  Future<Result<NumberTrivia>> getRandomNumberTrivia() =>
      _getTriviaFromUrl(ApiConstants.randomTriviaUrl);

  Future<Result<NumberTrivia>> _getTriviaFromUrl(String url) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        return const Err(ServerException());
      }
      return Ok(
        NumberTrivia.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        ),
      );
    } on http.ClientException {
      return const Err(ServerException());
    }
  }
}
```

📄 **Create the test:** `trivia_provider/test/data/services/number_trivia_api_service_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trivia_provider/config/api_constants.dart';
import 'package:trivia_provider/data/services/number_trivia_api_service.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/result.dart';

import '../../fixtures/fixture_reader.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late NumberTriviaApiService apiService;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    // mocktail needs a fallback value to use `any()` for a non-null Uri.
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    apiService = NumberTriviaApiService(client: mockHttpClient);
  });

  void setUpMockHttpClientSuccess200() {
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(fixture('trivia.json'), 200));
  }

  void setUpMockHttpClientFailure404() {
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('Something went wrong', 404));
  }

  final tNumberTrivia = NumberTrivia.fromJson(
    json.decode(fixture('trivia.json')) as Map<String, dynamic>,
  );

  Matcher isOk(NumberTrivia value) =>
      isA<Ok<NumberTrivia>>().having((r) => r.value, 'value', value);
  final isServerError = isA<Err<NumberTrivia>>().having(
    (r) => r.error,
    'error',
    isA<ServerException>(),
  );

  group('getConcreteNumberTrivia', () {
    const tNumber = 1;

    test(
      'should perform a GET request on the number URL with a JSON header',
      () async {
        setUpMockHttpClientSuccess200();

        await apiService.getConcreteNumberTrivia(tNumber);

        verify(
          () => mockHttpClient.get(
            Uri.parse(ApiConstants.concreteTriviaUrl(tNumber)),
            headers: {'Content-Type': 'application/json'},
          ),
        ).called(1);
      },
    );

    test(
      'should return Ok(NumberTrivia) when the response code is 200',
      () async {
        setUpMockHttpClientSuccess200();

        final result = await apiService.getConcreteNumberTrivia(tNumber);

        expect(result, isOk(tNumberTrivia));
      },
    );

    test(
      'should return Err(ServerException) when the response code is 404',
      () async {
        setUpMockHttpClientFailure404();

        final result = await apiService.getConcreteNumberTrivia(tNumber);

        expect(result, isServerError);
      },
    );

    test('should return Err(ServerException) when the request fails', () async {
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(http.ClientException('no route to host'));

      final result = await apiService.getConcreteNumberTrivia(tNumber);

      expect(result, isServerError);
    });
  });

  group('getRandomNumberTrivia', () {
    test(
      'should perform a GET request on the random URL with a JSON header',
      () async {
        setUpMockHttpClientSuccess200();

        await apiService.getRandomNumberTrivia();

        verify(
          () => mockHttpClient.get(
            Uri.parse(ApiConstants.randomTriviaUrl),
            headers: {'Content-Type': 'application/json'},
          ),
        ).called(1);
      },
    );

    test(
      'should return Ok(NumberTrivia) when the response code is 200',
      () async {
        setUpMockHttpClientSuccess200();

        final result = await apiService.getRandomNumberTrivia();

        expect(result, isOk(tNumberTrivia));
      },
    );

    test(
      'should return Err(ServerException) when the response code is 404',
      () async {
        setUpMockHttpClientFailure404();

        final result = await apiService.getRandomNumberTrivia();

        expect(result, isServerError);
      },
    );
  });
}
```

▶️ **Run it:**

```bash
flutter test test/data/services/number_trivia_api_service_test.dart
```

✅ **Expected:** `+7: All tests passed!` — green? Go to the next step.

### Step 9 — NumberTriviaCacheService (shared_preferences)

📄 **Create:** `trivia_provider/lib/data/services/number_trivia_cache_service.dart`

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/number_trivia.dart';
import '../../utils/app_exception.dart';
import '../../utils/result.dart';

const cachedNumberTriviaKey = 'CACHED_NUMBER_TRIVIA';

/// Wraps shared_preferences: stores and reads the last trivia.
class NumberTriviaCacheService {
  const NumberTriviaCacheService({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  /// Returns `Err(CacheException())` if nothing is cached.
  Future<Result<NumberTrivia>> getLastNumberTrivia() async {
    final jsonString = sharedPreferences.getString(cachedNumberTriviaKey);
    if (jsonString == null) {
      return const Err(CacheException());
    }
    return Ok(
      NumberTrivia.fromJson(json.decode(jsonString) as Map<String, dynamic>),
    );
  }

  Future<void> cacheNumberTrivia(NumberTrivia triviaToCache) async {
    await sharedPreferences.setString(
      cachedNumberTriviaKey,
      json.encode(triviaToCache.toJson()),
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/data/services/number_trivia_cache_service_test.dart`

`SharedPreferences.setMockInitialValues` gives a real in-memory store, so no mock is
needed.

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_provider/data/services/number_trivia_cache_service.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/result.dart';

import '../../fixtures/fixture_reader.dart';

void main() {
  late NumberTriviaCacheService cacheService;

  /// SharedPreferences' built-in in-memory version: no mock needed.
  Future<SharedPreferences> preferencesWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('getLastNumberTrivia', () {
    final tNumberTrivia = NumberTrivia.fromJson(
      json.decode(fixture('trivia_cached.json')) as Map<String, dynamic>,
    );

    test(
      'should return Ok(NumberTrivia) when there is a cached value',
      () async {
        final prefs = await preferencesWith({
          cachedNumberTriviaKey: fixture('trivia_cached.json'),
        });
        cacheService = NumberTriviaCacheService(sharedPreferences: prefs);

        final result = await cacheService.getLastNumberTrivia();

        expect(
          result,
          isA<Ok<NumberTrivia>>().having(
            (r) => r.value,
            'value',
            tNumberTrivia,
          ),
        );
      },
    );

    test('should return Err(CacheException) when nothing is cached', () async {
      final prefs = await preferencesWith({});
      cacheService = NumberTriviaCacheService(sharedPreferences: prefs);

      final result = await cacheService.getLastNumberTrivia();

      expect(
        result,
        isA<Err<NumberTrivia>>().having(
          (r) => r.error,
          'error',
          isA<CacheException>(),
        ),
      );
    });
  });

  group('cacheNumberTrivia', () {
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

    test(
      'should store the trivia as a JSON string in SharedPreferences',
      () async {
        final prefs = await preferencesWith({});
        cacheService = NumberTriviaCacheService(sharedPreferences: prefs);

        await cacheService.cacheNumberTrivia(tNumberTrivia);

        expect(
          prefs.getString(cachedNumberTriviaKey),
          json.encode(tNumberTrivia.toJson()),
        );
      },
    );
  });
}
```

▶️ **Run it:**

```bash
flutter test test/data/services/number_trivia_cache_service_test.dart
```

✅ **Expected:** `+3: All tests passed!` — green? Go to the next step.

### Step 10 — NumberTriviaRepository (online → API + cache, offline → cache)

`if (result case Ok(:final value))` is Dart 3's **if-case**: it runs the block only for
`Ok`, and gives you `value` already unwrapped.

📄 **Create:** `trivia_provider/lib/data/repositories/number_trivia_repository.dart`

```dart
import '../../domain/models/number_trivia.dart';
import '../../utils/result.dart';
import '../services/connectivity_service.dart';
import '../services/number_trivia_api_service.dart';
import '../services/number_trivia_cache_service.dart';

/// The single source of truth for trivia. It combines the services:
/// online -> API (and cache the result); offline -> last cached trivia.
class NumberTriviaRepository {
  const NumberTriviaRepository({
    required this.apiService,
    required this.cacheService,
    required this.connectivityService,
  });

  final NumberTriviaApiService apiService;
  final NumberTriviaCacheService cacheService;
  final ConnectivityService connectivityService;

  Future<Result<NumberTrivia>> getConcreteNumberTrivia(int number) {
    return _getTrivia(() => apiService.getConcreteNumberTrivia(number));
  }

  Future<Result<NumberTrivia>> getRandomNumberTrivia() {
    return _getTrivia(apiService.getRandomNumberTrivia);
  }

  Future<Result<NumberTrivia>> _getTrivia(
    Future<Result<NumberTrivia>> Function() getConcreteOrRandom,
  ) async {
    if (await connectivityService.isConnected) {
      final result = await getConcreteOrRandom();
      // `if case`: run the block only when the result is Ok.
      if (result case Ok(:final value)) {
        await cacheService.cacheNumberTrivia(value);
      }
      return result;
    }
    return cacheService.getLastNumberTrivia();
  }
}
```

📄 **Create the test:** `trivia_provider/test/data/repositories/number_trivia_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_provider/data/repositories/number_trivia_repository.dart';
import 'package:trivia_provider/data/services/connectivity_service.dart';
import 'package:trivia_provider/data/services/number_trivia_api_service.dart';
import 'package:trivia_provider/data/services/number_trivia_cache_service.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/result.dart';

class MockApiService extends Mock implements NumberTriviaApiService {}

class MockCacheService extends Mock implements NumberTriviaCacheService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late NumberTriviaRepository repository;
  late MockApiService mockApiService;
  late MockCacheService mockCacheService;
  late MockConnectivityService mockConnectivityService;

  setUpAll(() {
    registerFallbackValue(const NumberTrivia(text: 'fallback', number: 0));
  });

  setUp(() {
    mockApiService = MockApiService();
    mockCacheService = MockCacheService();
    mockConnectivityService = MockConnectivityService();
    repository = NumberTriviaRepository(
      apiService: mockApiService,
      cacheService: mockCacheService,
      connectivityService: mockConnectivityService,
    );
    when(() => mockCacheService.cacheNumberTrivia(any()))
        .thenAnswer((_) async {});
  });

  void runTestsOnline(void Function() body) {
    group('device is online', () {
      setUp(() {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => true);
      });
      body();
    });
  }

  void runTestsOffline(void Function() body) {
    group('device is offline', () {
      setUp(() {
        when(() => mockConnectivityService.isConnected)
            .thenAnswer((_) async => false);
      });
      body();
    });
  }

  Matcher isOk(NumberTrivia value) =>
      isA<Ok<NumberTrivia>>().having((r) => r.value, 'value', value);
  Matcher isErrOf<E>() =>
      isA<Err<NumberTrivia>>().having((r) => r.error, 'error', isA<E>());

  group('getConcreteNumberTrivia', () {
    const tNumber = 1;
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: tNumber);

    test('should check if the device is online', () async {
      when(() => mockConnectivityService.isConnected)
          .thenAnswer((_) async => true);
      when(() => mockApiService.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => const Ok(tNumberTrivia));

      await repository.getConcreteNumberTrivia(tNumber);

      verify(() => mockConnectivityService.isConnected).called(1);
    });

    runTestsOnline(() {
      test('should return the API result when the call succeeds', () async {
        when(() => mockApiService.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verify(() => mockApiService.getConcreteNumberTrivia(tNumber));
        expect(result, isOk(tNumberTrivia));
      });

      test('should cache the trivia when the call succeeds', () async {
        when(() => mockApiService.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        await repository.getConcreteNumberTrivia(tNumber);

        verify(() => mockCacheService.cacheNumberTrivia(tNumberTrivia))
            .called(1);
      });

      test('should return the Err and not cache when the call fails', () async {
        when(() => mockApiService.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Err(ServerException()));

        final result = await repository.getConcreteNumberTrivia(tNumber);

        expect(result, isErrOf<ServerException>());
        verifyNever(() => mockCacheService.cacheNumberTrivia(any()));
      });
    });

    runTestsOffline(() {
      test('should return the last cached trivia', () async {
        when(() => mockCacheService.getLastNumberTrivia())
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verifyZeroInteractions(mockApiService);
        expect(result, isOk(tNumberTrivia));
      });

      test(
        'should return Err(CacheException) when nothing is cached',
        () async {
          when(() => mockCacheService.getLastNumberTrivia())
              .thenAnswer((_) async => const Err(CacheException()));

          final result = await repository.getConcreteNumberTrivia(tNumber);

          verifyZeroInteractions(mockApiService);
          expect(result, isErrOf<CacheException>());
        },
      );
    });
  });

  group('getRandomNumberTrivia', () {
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 123);

    runTestsOnline(() {
      test('should return the API result and cache it', () async {
        when(() => mockApiService.getRandomNumberTrivia())
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        final result = await repository.getRandomNumberTrivia();

        expect(result, isOk(tNumberTrivia));
        verify(() => mockCacheService.cacheNumberTrivia(tNumberTrivia))
            .called(1);
      });

      test('should return the Err when the call fails', () async {
        when(() => mockApiService.getRandomNumberTrivia())
            .thenAnswer((_) async => const Err(ServerException()));

        final result = await repository.getRandomNumberTrivia();

        expect(result, isErrOf<ServerException>());
      });
    });

    runTestsOffline(() {
      test('should return the last cached trivia', () async {
        when(() => mockCacheService.getLastNumberTrivia())
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        final result = await repository.getRandomNumberTrivia();

        verifyZeroInteractions(mockApiService);
        expect(result, isOk(tNumberTrivia));
      });

      test(
        'should return Err(CacheException) when nothing is cached',
        () async {
          when(() => mockCacheService.getLastNumberTrivia())
              .thenAnswer((_) async => const Err(CacheException()));

          final result = await repository.getRandomNumberTrivia();

          expect(result, isErrOf<CacheException>());
        },
      );
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/data/repositories/number_trivia_repository_test.dart
```

✅ **Expected:** `+10: All tests passed!` — green? Go to the next step.

---

## Part D — The ViewModel

```text
getTriviaForConcreteNumber("42")
   │ stringToUnsignedInteger ──Err──▶ state = TriviaError(invalid input)   notifyListeners()
   ▼ Ok(42)
state = TriviaLoading  notifyListeners()
   ▼ repository.getConcreteNumberTrivia(42)
   ├─ Ok(trivia)  ─▶ state = TriviaLoaded(trivia)        notifyListeners()
   └─ Err(e)      ─▶ state = TriviaError(message of e)   notifyListeners()
```

### Step 11 — NumberTriviaViewModel (ChangeNotifier) + its sealed state

The state classes live in the same file as the ViewModel, because only this screen uses
them. `_disposed` stops a late answer from calling `notifyListeners()` after the screen
closed, which would throw.

📄 **Create:** `trivia_provider/lib/ui/number_trivia/view_models/number_trivia_view_model.dart`

```dart
import 'package:flutter/foundation.dart';

import '../../../data/repositories/number_trivia_repository.dart';
import '../../../domain/models/number_trivia.dart';
import '../../../utils/app_exception.dart';
import '../../../utils/input_converter.dart';
import '../../../utils/result.dart';

/// Everything the screen can show. `sealed` -> the view's switch must
/// handle every case.
sealed class NumberTriviaState {
  const NumberTriviaState();
}

final class TriviaEmpty extends NumberTriviaState {
  const TriviaEmpty();
}

final class TriviaLoading extends NumberTriviaState {
  const TriviaLoading();
}

final class TriviaLoaded extends NumberTriviaState {
  const TriviaLoaded(this.trivia);

  final NumberTrivia trivia;
}

final class TriviaError extends NumberTriviaState {
  const TriviaError(this.message);

  final String message;
}

/// MVVM ViewModel: holds the screen state and calls `notifyListeners()`
/// whenever it changes. Widgets that `watch` it rebuild.
class NumberTriviaViewModel extends ChangeNotifier {
  NumberTriviaViewModel({required this.repository});

  final NumberTriviaRepository repository;

  NumberTriviaState _state = const TriviaEmpty();
  NumberTriviaState get state => _state;

  bool _disposed = false;

  Future<void> getTriviaForConcreteNumber(String input) async {
    switch (stringToUnsignedInteger(input)) {
      case Err(:final error):
        _setState(TriviaError(errorMessageFor(error)));
      case Ok(value: final number):
        await _load(() => repository.getConcreteNumberTrivia(number));
    }
  }

  Future<void> getTriviaForRandomNumber() {
    return _load(repository.getRandomNumberTrivia);
  }

  Future<void> _load(Future<Result<NumberTrivia>> Function() fetch) async {
    _setState(const TriviaLoading());
    final result = await fetch();
    // The screen may have closed while we waited.
    if (_disposed) return;
    _setState(switch (result) {
      Ok(:final value) => TriviaLoaded(value),
      Err(:final error) => TriviaError(errorMessageFor(error)),
    });
  }

  void _setState(NumberTriviaState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/number_trivia/view_models/number_trivia_view_model_test.dart`

A ViewModel is a plain Dart object, so no widgets are needed. `addListener` records
the state at every `notifyListeners()`, so we can check the order `[Loading, Loaded]`. The
last test checks the `_disposed` guard.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_provider/data/repositories/number_trivia_repository.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/ui/number_trivia/view_models/number_trivia_view_model.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/result.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late NumberTriviaViewModel viewModel;
  late MockNumberTriviaRepository mockRepository;
  late List<NumberTriviaState> states;

  const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
    viewModel = NumberTriviaViewModel(repository: mockRepository);
    // Record the state every time the ViewModel notifies its listeners.
    states = [];
    viewModel.addListener(() => states.add(viewModel.state));
  });

  tearDown(() => viewModel.dispose());

  // Matchers for each kind of state.
  final isLoading = isA<TriviaLoading>();
  Matcher isLoaded(NumberTrivia trivia) =>
      isA<TriviaLoaded>().having((s) => s.trivia, 'trivia', trivia);
  Matcher isError(String message) =>
      isA<TriviaError>().having((s) => s.message, 'message', message);

  test('initial state should be TriviaEmpty', () {
    expect(viewModel.state, isA<TriviaEmpty>());
  });

  group('getTriviaForConcreteNumber', () {
    test('should call the repository with the parsed number', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => const Ok(tNumberTrivia));

      await viewModel.getTriviaForConcreteNumber('1');

      verify(() => mockRepository.getConcreteNumberTrivia(1)).called(1);
    });

    test('should emit [Error] with the invalid input message', () async {
      await viewModel.getTriviaForConcreteNumber('abc');

      expect(states, [isError(const InvalidInputException().message)]);
      verifyZeroInteractions(mockRepository);
    });

    test(
      'should emit [Loading, Loaded] when data is gotten successfully',
      () async {
        when(() => mockRepository.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        await viewModel.getTriviaForConcreteNumber('1');

        expect(states, [isLoading, isLoaded(tNumberTrivia)]);
      },
    );

    test('should emit [Loading, Error] with the server message', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => const Err(ServerException()));

      await viewModel.getTriviaForConcreteNumber('1');

      expect(states, [isLoading, isError('Server Failure')]);
    });

    test('should emit [Loading, Error] with the cache message', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => const Err(CacheException()));

      await viewModel.getTriviaForConcreteNumber('1');

      expect(states, [isLoading, isError('Cache Failure')]);
    });
  });

  group('getTriviaForRandomNumber', () {
    test(
      'should emit [Loading, Loaded] when data is gotten successfully',
      () async {
        when(() => mockRepository.getRandomNumberTrivia())
            .thenAnswer((_) async => const Ok(tNumberTrivia));

        await viewModel.getTriviaForRandomNumber();

        verify(() => mockRepository.getRandomNumberTrivia()).called(1);
        expect(states, [isLoading, isLoaded(tNumberTrivia)]);
      },
    );

    test('should emit [Loading, Error] with the server message', () async {
      when(() => mockRepository.getRandomNumberTrivia())
          .thenAnswer((_) async => const Err(ServerException()));

      await viewModel.getTriviaForRandomNumber();

      expect(states, [isLoading, isError('Server Failure')]);
    });
  });

  test(
    'should not notify after dispose when a request finishes late',
    () async {
      // A ViewModel disposed during a request must not call notifyListeners
      // (that would throw). We dispose a second ViewModel mid-request.
      final lateViewModel = NumberTriviaViewModel(repository: mockRepository);
      when(() => mockRepository.getRandomNumberTrivia()).thenAnswer((_) async {
        lateViewModel.dispose();
        return const Ok(tNumberTrivia);
      });

      await expectLater(lateViewModel.getTriviaForRandomNumber(), completes);
    },
  );
}
```

▶️ **Run it:**

```bash
flutter test test/ui/number_trivia/view_models/number_trivia_view_model_test.dart
```

✅ **Expected:** `+9: All tests passed!` — green? Go to the next step.

---

## Part E — UI widgets and screen

The official guide puts widgets reused by many screens in `ui/core/`, and each
feature's widgets next to its ViewModel.

### Step 12 — MessageDisplay widget (shared)

📄 **Create:** `trivia_provider/lib/ui/core/widgets/message_display.dart`

```dart
import 'package:flutter/material.dart';

class MessageDisplay extends StatelessWidget {
  const MessageDisplay({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height / 3,
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 25),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/core/widgets/message_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/ui/core/widgets/message_display.dart';

void main() {
  testWidgets('should show the given message', (tester) async {
    // arrange + act
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessageDisplay(message: 'Hello')),
      ),
    );
    // assert
    expect(find.text('Hello'), findsOneWidget);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/ui/core/widgets/message_display_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 13 — LoadingWidget (shared)

📄 **Create:** `trivia_provider/lib/ui/core/widgets/loading_widget.dart`

```dart
import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height / 3,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/core/widgets/loading_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/ui/core/widgets/loading_widget.dart';

void main() {
  testWidgets('should show a CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingWidget())),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/ui/core/widgets/loading_widget_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 14 — TriviaDisplay widget

📄 **Create:** `trivia_provider/lib/ui/number_trivia/widgets/trivia_display.dart`

```dart
import 'package:flutter/material.dart';

import '../../../domain/models/number_trivia.dart';

class TriviaDisplay extends StatelessWidget {
  const TriviaDisplay({required this.numberTrivia, super.key});

  final NumberTrivia numberTrivia;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height / 3,
      child: Column(
        children: [
          Text(
            numberTrivia.number.toString(),
            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  numberTrivia.text,
                  style: const TextStyle(fontSize: 25),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/number_trivia/widgets/trivia_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/ui/number_trivia/widgets/trivia_display.dart';

void main() {
  testWidgets('should show the number and the trivia text', (tester) async {
    const trivia = NumberTrivia(text: '42 is the answer.', number: 42);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TriviaDisplay(numberTrivia: trivia)),
      ),
    );

    expect(find.text('42'), findsOneWidget);
    expect(find.text('42 is the answer.'), findsOneWidget);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/ui/number_trivia/widgets/trivia_display_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 15 — TriviaControls

A `StatefulWidget` because it owns the `TextEditingController`. Callbacks use
`context.read`, never `context.watch`.

📄 **Create:** `trivia_provider/lib/ui/number_trivia/widgets/trivia_controls.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/number_trivia_view_model.dart';

class TriviaControls extends StatefulWidget {
  const TriviaControls({super.key});

  @override
  State<TriviaControls> createState() => _TriviaControlsState();
}

class _TriviaControlsState extends State<TriviaControls> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _searchConcrete() {
    // Read the text before clearing the field.
    final input = _controller.text;
    _controller.clear();
    // `context.read` in callbacks (no rebuild), `context.watch` in build.
    context.read<NumberTriviaViewModel>().getTriviaForConcreteNumber(input);
  }

  void _searchRandom() {
    _controller.clear();
    context.read<NumberTriviaViewModel>().getTriviaForRandomNumber();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Input a number',
          ),
          onSubmitted: (_) => _searchConcrete(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _searchConcrete,
                child: const Text('Search'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _searchRandom,
                child: const Text('Get random trivia'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/number_trivia/widgets/trivia_controls_test.dart`

We provide a **real** ViewModel with a **mock repository**, then check which repository
call each button causes.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:trivia_provider/data/repositories/number_trivia_repository.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/ui/number_trivia/view_models/number_trivia_view_model.dart';
import 'package:trivia_provider/ui/number_trivia/widgets/trivia_controls.dart';
import 'package:trivia_provider/utils/result.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late MockNumberTriviaRepository mockRepository;
  const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
    when(() => mockRepository.getConcreteNumberTrivia(any()))
        .thenAnswer((_) async => const Ok(tNumberTrivia));
    when(() => mockRepository.getRandomNumberTrivia())
        .thenAnswer((_) async => const Ok(tNumberTrivia));
  });

  /// A real ViewModel with a mock repository, provided above the widget.
  Future<void> pumpControls(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NumberTriviaViewModel(repository: mockRepository),
        child: const MaterialApp(home: Scaffold(body: TriviaControls())),
      ),
    );
  }

  testWidgets('should search the typed number when Search is tapped', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();

    verify(() => mockRepository.getConcreteNumberTrivia(42)).called(1);
  });

  testWidgets('should clear the text field after Search', (tester) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets('should search when the keyboard submits', (tester) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => mockRepository.getConcreteNumberTrivia(7)).called(1);
  });

  testWidgets('should fetch random trivia when random is tapped', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.tap(find.text('Get random trivia'));
    await tester.pump();

    verify(() => mockRepository.getRandomNumberTrivia()).called(1);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/ui/number_trivia/widgets/trivia_controls_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

### Step 16 — NumberTriviaScreen (the View)

`context.watch<NumberTriviaViewModel>().state` plus an exhaustive `switch` on the sealed
state. This is the whole View.

📄 **Create:** `trivia_provider/lib/ui/number_trivia/widgets/number_trivia_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/message_display.dart';
import '../view_models/number_trivia_view_model.dart';
import 'trivia_controls.dart';
import 'trivia_display.dart';

class NumberTriviaScreen extends StatelessWidget {
  const NumberTriviaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // watch = rebuild this widget every time the ViewModel notifies.
    final state = context.watch<NumberTriviaViewModel>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Number Trivia')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              switch (state) {
                TriviaEmpty() => const MessageDisplay(
                  message: 'Start searching!',
                ),
                TriviaLoading() => const LoadingWidget(),
                TriviaLoaded(:final trivia) => TriviaDisplay(
                  numberTrivia: trivia,
                ),
                TriviaError(:final message) => MessageDisplay(message: message),
              },
              const SizedBox(height: 20),
              const TriviaControls(),
            ],
          ),
        ),
      ),
    );
  }
}
```

📄 **Create the test:** `trivia_provider/test/ui/number_trivia/widgets/number_trivia_screen_test.dart`

A `Completer` lets the test see the loading state first. Use `pump()`, not
`pumpAndSettle()`, while the spinner is showing.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:trivia_provider/data/repositories/number_trivia_repository.dart';
import 'package:trivia_provider/domain/models/number_trivia.dart';
import 'package:trivia_provider/ui/core/widgets/loading_widget.dart';
import 'package:trivia_provider/ui/number_trivia/view_models/number_trivia_view_model.dart';
import 'package:trivia_provider/ui/number_trivia/widgets/number_trivia_screen.dart';
import 'package:trivia_provider/ui/number_trivia/widgets/trivia_controls.dart';
import 'package:trivia_provider/ui/number_trivia/widgets/trivia_display.dart';
import 'package:trivia_provider/utils/app_exception.dart';
import 'package:trivia_provider/utils/result.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late MockNumberTriviaRepository mockRepository;

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
  });

  /// Real ViewModel + mocked repository: the screen and the ViewModel are
  /// tested together; only the data layer is faked.
  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => NumberTriviaViewModel(repository: mockRepository),
        child: const MaterialApp(home: NumberTriviaScreen()),
      ),
    );
  }

  testWidgets('should show "Start searching!" at first', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Start searching!'), findsOneWidget);
    expect(find.byType(TriviaControls), findsOneWidget);
  });

  testWidgets('should show LoadingWidget, then TriviaDisplay on success', (
    tester,
  ) async {
    // A Completer lets the test decide WHEN the repository answers.
    final completer = Completer<Result<NumberTrivia>>();
    when(() => mockRepository.getConcreteNumberTrivia(any()))
        .thenAnswer((_) => completer.future);
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.byType(LoadingWidget), findsOneWidget);

    completer.complete(const Ok(NumberTrivia(text: 'test trivia', number: 1)));
    await tester.pump();
    expect(find.byType(TriviaDisplay), findsOneWidget);
    expect(find.text('test trivia'), findsOneWidget);
  });

  testWidgets('should show the error message when the repository fails', (
    tester,
  ) async {
    when(() => mockRepository.getRandomNumberTrivia())
        .thenAnswer((_) async => const Err(ServerException()));
    await pumpScreen(tester);

    await tester.tap(find.text('Get random trivia'));
    await tester.pump();

    expect(find.text('Server Failure'), findsOneWidget);
  });

  testWidgets('should show the invalid input message for bad input', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(find.text(const InvalidInputException().message), findsOneWidget);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/ui/number_trivia/widgets/number_trivia_screen_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

---

## Part F — Dependencies, app, main

### Step 17 — config/dependencies.dart: every provider in one list

The order matters: the repository's `create` reads the services, so they must come
**before** it in the list. The outside world comes in as **parameters**, which is what
lets the integration test inject fakes.

📄 **Create:** `trivia_provider/lib/config/dependencies.dart`

```dart
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/number_trivia_repository.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/number_trivia_api_service.dart';
import '../data/services/number_trivia_cache_service.dart';

/// All app-wide dependencies, as a list for `MultiProvider`.
///
/// The outside world (http client, preferences, connectivity) is passed in:
/// main() gives the real ones, the integration test gives fakes.
List<SingleChildWidget> buildProviders({
  required http.Client httpClient,
  required SharedPreferences sharedPreferences,
  required ConnectivityService connectivityService,
}) {
  return [
    Provider(create: (_) => NumberTriviaApiService(client: httpClient)),
    Provider(
      create: (_) =>
          NumberTriviaCacheService(sharedPreferences: sharedPreferences),
    ),
    Provider.value(value: connectivityService),
    // `context.read<T>()` finds a provider registered ABOVE in this list.
    Provider(
      create: (context) => NumberTriviaRepository(
        apiService: context.read(),
        cacheService: context.read(),
        connectivityService: context.read(),
      ),
    ),
  ];
}
```

> 🧪 **No test for this file:** wiring only. The integration test calls `buildProviders()` with fakes and runs the whole app on it.

### Step 18 — App widget and main()

`main()` builds the real outside-world objects and gives them to `buildProviders`. The
ViewModel is created **per screen** by `ChangeNotifierProvider` in `app.dart`, which also
disposes it when the screen closes.

📄 **Create:** `trivia_provider/lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/number_trivia/view_models/number_trivia_view_model.dart';
import 'ui/number_trivia/widgets/number_trivia_screen.dart';

class NumberTriviaApp extends StatelessWidget {
  const NumberTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Trivia (Provider)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      // The ViewModel belongs to the screen: ChangeNotifierProvider creates
      // it here and disposes it when the screen goes away.
      home: ChangeNotifierProvider(
        create: (context) => NumberTriviaViewModel(repository: context.read()),
        child: const NumberTriviaScreen(),
      ),
    );
  }
}
```

📄 **Create:** `trivia_provider/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/dependencies.dart';
import 'data/services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: buildProviders(
        httpClient: http.Client(),
        sharedPreferences: sharedPreferences,
        connectivityService: ConnectivityService(InternetConnection()),
      ),
      child: const NumberTriviaApp(),
    ),
  );
}
```

> 🧪 **No test for this file:** covered by the integration test.

**Run the whole unit + widget suite now:**

```bash
flutter test
```

✅ **Expected:** `+54: All tests passed!`

Then: `flutter run`

---

## Part G — Integration test

The real app: the real `buildProviders`, repository, services, ViewModel and screen.
Only the outside world is replaced, by passing fakes to `buildProviders()`: a
`MockClient` fake server, `FakeConnectivityService`, and in-memory prefs. Each test pumps a
fresh `MultiProvider`, so nothing needs resetting.

### Step 19 — End-to-end flows

📄 **Create the test:** `trivia_provider/integration_test/app_test.dart`

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_provider/app.dart';
import 'package:trivia_provider/config/dependencies.dart';
import 'package:trivia_provider/data/services/connectivity_service.dart';
import 'package:trivia_provider/utils/app_exception.dart';

/// Lets each test decide whether the device is "online".
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({required this.connected});

  bool connected;

  @override
  Future<bool> get isConnected async => connected;

  /// Never used by the app; the fake answers `isConnected` itself.
  @override
  InternetConnection get connectionChecker => throw UnimplementedError();
}

/// A fake HTTP server: answers every request with trivia for the number in
/// the URL (or 99 for the random endpoint).
http.Client fakeTriviaServer() {
  return MockClient((request) async {
    final segment = request.url.pathSegments.first;
    final number = segment == 'random' ? 99 : int.parse(segment);
    return http.Response(
      json.encode({'text': '$number is a test number.', 'number': number}),
      200,
    );
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivityService connectivityService;

  /// Same as main(), but buildProviders() gets fakes for the outside world.
  Future<void> startApp(WidgetTester tester, {bool online = true}) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    connectivityService = FakeConnectivityService(connected: online);

    await tester.pumpWidget(
      MultiProvider(
        providers: buildProviders(
          httpClient: fakeTriviaServer(),
          sharedPreferences: sharedPreferences,
          connectivityService: connectivityService,
        ),
        child: const NumberTriviaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows trivia for the number the user types', (tester) async {
    await startApp(tester);
    expect(find.text('Start searching!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('42 is a test number.'), findsOneWidget);
  });

  testWidgets('shows random trivia', (tester) async {
    await startApp(tester);

    await tester.tap(find.text('Get random trivia'));
    await tester.pumpAndSettle();

    expect(find.text('99 is a test number.'), findsOneWidget);
  });

  testWidgets('shows an error for invalid input', (tester) async {
    await startApp(tester);

    await tester.enterText(find.byType(TextField), '-5');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text(const InvalidInputException().message), findsOneWidget);
  });

  testWidgets('offline: shows cached trivia, or Cache Failure if none', (
    tester,
  ) async {
    await startApp(tester, online: false);

    await tester.tap(find.text('Get random trivia'));
    await tester.pumpAndSettle();
    expect(find.text('Cache Failure'), findsOneWidget);

    connectivityService.connected = true;
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    connectivityService.connected = false;
    await tester.tap(find.text('Get random trivia'));
    await tester.pumpAndSettle();
    expect(find.text('7 is a test number.'), findsOneWidget);
  });
}
```

▶️ **Run it** on a device, simulator or `macos`:

```bash
flutter test integration_test -d macos
```

✅ **Expected:** `+4: All tests passed!`

---

## Final check

```bash
flutter analyze                          # No issues found!
flutter test                             # +54: All tests passed!
flutter test integration_test -d macos   # +4: All tests passed!
flutter run
```

### Checklist

- [ ] Services never throw; they return `Ok` / `Err`
- [ ] `context.watch` only in `build`, `context.read` only in callbacks / `create`
- [ ] The ViewModel is created by `ChangeNotifierProvider` (so it gets disposed)
- [ ] Providers in `buildProviders` are ordered so each one only reads providers above it
- [ ] `flutter analyze` shows no issues

### Common problems

| Problem | Fix |
|---|---|
| `ProviderNotFoundException: Could not find the correct Provider<X>` | X is not above this widget: check `buildProviders` order, or wrap the test widget in the provider |
| `Tried to listen to a value exposed with provider, from outside of the widget tree` | You used `context.watch` in a callback; use `context.read` |
| `A NumberTriviaViewModel was used after being disposed` | Keep the `_disposed` check in `_load` |
| `pumpAndSettle timed out` | A spinner is showing; use `pump()` |

### The four guides side by side

| | Bloc | Riverpod | GetX | Provider |
|---|---|---|---|---|
| Architecture | Clean Architecture | Feature-first layered | GetX Pattern | MVVM (official Flutter guide) |
| DI | `get_it` | Providers + `overrides` | Bindings | `MultiProvider` + `context.read` |
| State holder | `Bloc` (events → states) | `AsyncNotifier` | `GetxController` + `.obs` | `ChangeNotifier` ViewModel |
| Screen state | Sealed states | `AsyncValue<NumberTrivia?>` | `enum TriviaStatus` | Sealed `NumberTriviaState` |
| Errors | `Failure` + `Either` | Exceptions + `AsyncValue.guard` | Exceptions caught in controller | `Result` (`Ok` / `Err`) |
| Swapping in fakes for tests | `sl.unregister` / `register` | `ProviderScope(overrides:)` | Test `Bindings` + `Get.reset` | `buildProviders(...)` parameters |
