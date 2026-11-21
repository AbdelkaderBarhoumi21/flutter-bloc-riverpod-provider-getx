# Number Trivia with **Riverpod 3**, step by step (TDD)

> **Guide 2 of 4** in the *Number Trivia: 4 state managements* series
> (Bloc · Riverpod · GetX · Provider). Same app, same monorepo folder, different architecture.

Every line of the app is in this guide, **in the order you type it**. After each file that
has logic, you write its test straight away, run it, see it pass, and only then go on.

**What you will have at the end:** 53 unit + widget tests and 4 integration tests, all
passing. They were run on Flutter 3.47 / Dart 3.13 with `flutter_riverpod` 3.5.

## Contents

0. [The app](#0-the-app)
1. [Why this architecture for Riverpod](#1-why-this-architecture-for-riverpod)
2. [Final folder structure](#2-final-folder-structure)
3. [Project setup](#3-project-setup)
4. [Part A: Core](#part-a--core)
5. [Part B: Domain](#part-b--domain)
6. [Part C: Data layer](#part-c--data-layer)
7. [Part D: Presentation: the controller](#part-d--presentation-the-controller)
8. [Part E: Presentation: widgets](#part-e--presentation-widgets)
9. [Part F: Screen, app, main](#part-f--screen-app-main)
10. [Part G: Integration test](#part-g--integration-test)
11. [Final check](#final-check)

## 0. The app

The same **Number Trivia** app as in the Bloc guide. The user types a number and gets a
fact about it, or asks for a random one. Offline, the app shows the last cached fact.

```text
┌──────────────────────────────┐
│ Number Trivia                │
├──────────────────────────────┤
│              42              │  ← AsyncData(trivia) / AsyncLoading / AsyncError
│  42 is the answer to life…   │
│ ┌──────────────────────────┐ │
│ │ Input a number           │ │
│ └──────────────────────────┘ │
│ [   Search   ] [ Get random ]│
└──────────────────────────────┘
```

## 1. Why this architecture for Riverpod

Riverpod already gives you two things that Clean Architecture builds by hand:

1. **Dependency injection.** Every `Provider` *is* a recipe for building an object, and
   `ref.watch(otherProvider)` *is* constructor injection. You don't need `get_it`.
2. **Loading / error / data states.** `AsyncValue<T>` (`AsyncLoading`, `AsyncError`,
   `AsyncData`) is a built-in, sealed state type. You don't need `Either` or hand-written
   state classes.

So the best fit is the **feature-first, layered Riverpod architecture**, as used in the
Riverpod docs and the community's "Riverpod app architecture" (presentation → application →
domain → data):

```text
        PRESENTATION                         DOMAIN               DATA
 ┌──────────────────────────────────┐  ┌────────────────┐  ┌──────────────────────────────────┐
 │ NumberTriviaScreen (ConsumerWidget)│ │ NumberTrivia   │  │ NumberTriviaRepository           │
 │   ref.watch(controllerProvider)  │  │ (model + JSON) │◀─│   ├─ RemoteDataSource ─ http      │
 │ TriviaControls ──ref.read──┐     │  └────────────────┘  │   ├─ LocalDataSource ─ prefs      │
 │ NumberTriviaController ◀───┘     │─────────────────────▶│   └─ NetworkInfo                 │
 │   AsyncNotifier<NumberTrivia?>   │                      └──────────────────────────────────┘
 └──────────────────────────────────┘
   Each class has a Provider right next to it. Providers wire the graph; tests override any node.
```

| Decision | Why |
|---|---|
| **No use-case classes** | With one repository call each, a use case would only forward the call. The architecture adds an *application* (service) layer only when logic combines several repositories. |
| **No `Either`** | Typed exceptions (`sealed class AppException`) + `AsyncValue.guard` give the same "success or typed failure" result with less code. |
| **No abstract repository interfaces** | `mocktail` can mock concrete classes, and `overrideWithValue` swaps any provider in tests. An interface would add a file and no testability. |
| **One model** (`NumberTrivia` with `fromJson`) | No separate Entity / Model pair to keep in sync. |
| **`AsyncNotifier` controller** | Holds the screen state; the UI does a `switch` over `AsyncValue`. |
| **`ProviderScope.overrides`** | How tests (and `main()`) plug in real or fake dependencies. |

**Packages**

| Package | Role |
|---|---|
| `flutter_riverpod` 3.x | State + dependency injection |
| `http` | API (and `http/testing.dart` for the fake server in integration tests) |
| `shared_preferences` | Cache the last trivia |
| `internet_connection_checker_plus` | Real internet check |
| `mocktail` (dev) | Mocks without code generation |
| `integration_test` (dev, SDK) | Run the real app in tests |

> We do **not** use `riverpod_generator` / `@riverpod` here. Writing the providers by hand
> shows exactly what they do and needs no `build_runner`. Once you know them, the
> generator is an optional shortcut.

## 2. Final folder structure

What you will have at the end. `test/` mirrors `lib/`.

```text
trivia_riverpod/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart
│   │   ├── exceptions/
│   │   │   └── app_exception.dart
│   │   ├── network/
│   │   │   └── network_info.dart
│   │   ├── providers/
│   │   │   └── core_providers.dart
│   │   └── utils/
│   │       └── input_converter.dart
│   ├── features/
│   │   └── number_trivia/
│   │       ├── data/
│   │       │   ├── number_trivia_local_data_source.dart
│   │       │   ├── number_trivia_remote_data_source.dart
│   │       │   └── number_trivia_repository.dart
│   │       ├── domain/
│   │       │   └── number_trivia.dart
│   │       └── presentation/
│   │           ├── widgets/
│   │           │   ├── loading_widget.dart
│   │           │   ├── message_display.dart
│   │           │   ├── trivia_controls.dart
│   │           │   ├── trivia_display.dart
│   │           │   └── widgets.dart
│   │           ├── number_trivia_controller.dart
│   │           └── number_trivia_screen.dart
│   ├── app.dart
│   └── main.dart
├── test/
│   ├── core/
│   │   ├── exceptions/
│   │   │   └── app_exception_test.dart
│   │   ├── network/
│   │   │   └── network_info_test.dart
│   │   └── utils/
│   │       └── input_converter_test.dart
│   ├── features/
│   │   └── number_trivia/
│   │       ├── data/
│   │       │   ├── number_trivia_local_data_source_test.dart
│   │       │   ├── number_trivia_remote_data_source_test.dart
│   │       │   └── number_trivia_repository_test.dart
│   │       ├── domain/
│   │       │   └── number_trivia_test.dart
│   │       └── presentation/
│   │           ├── widgets/
│   │           │   ├── loading_widget_test.dart
│   │           │   ├── message_display_test.dart
│   │           │   ├── trivia_controls_test.dart
│   │           │   └── trivia_display_test.dart
│   │           ├── number_trivia_controller_test.dart
│   │           └── number_trivia_screen_test.dart
│   └── fixtures/
│       ├── fixture_reader.dart
│       ├── trivia.json
│       ├── trivia_cached.json
│       └── trivia_double.json
└── integration_test/
    └── app_test.dart

(+ pubspec.yaml, analysis_options.yaml, android/, ios/ … created by flutter create)
```

## 3. Project setup

### 3.1 Create the app in the monorepo

```bash
cd flutter-state-management-showdown/apps   # the apps/ folder from guide 1
flutter create --org com.example --platforms=android,ios,macos trivia_riverpod
cd trivia_riverpod
```

### 3.2 Dependencies

```bash
flutter pub add flutter_riverpod http shared_preferences internet_connection_checker_plus
flutter pub add dev:mocktail "dev:integration_test:{sdk: flutter}"
```

`pubspec.yaml` (keep the `environment: sdk:` value that `flutter create` wrote):

```yaml
name: trivia_riverpod
description: "Number Trivia - Riverpod architecture"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.0 # keep the value flutter create generated

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.5.0
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

**Android:** `trivia_riverpod/android/app/src/main/AndroidManifest.xml`. Add the permission
above `<application>` and the cleartext flag on `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="trivia_riverpod"
        android:name="${applicationName}"
        android:usesCleartextTraffic="true"
        android:icon="@mipmap/ic_launcher">
        <!-- keep everything flutter create generated in here -->
```

**iOS:** `trivia_riverpod/ios/Runner/Info.plist`. Add this inside the top `<dict>`
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

### Riverpod in 60 seconds (words used below)

| Term | Meaning |
|---|---|
| `Provider<T>((ref) => …)` | A recipe that builds a `T`. It is built once and cached. |
| `ref.watch(p)` | Get `p`'s value **and** rebuild when it changes (in `build` and in providers). |
| `ref.read(p)` | Get the value once, without listening (in callbacks such as `onPressed`). |
| `AsyncNotifierProvider` | A provider whose value is an `AsyncValue<T>` managed by a class (the controller). |
| `.autoDispose` | Destroy the state when no widget watches it anymore. |
| `ProviderScope(overrides: […])` | Root of the app; `overrides` replace providers (real prefs in `main`, fakes in tests). |
| `ProviderContainer.test(...)` | A `ProviderScope` without widgets, for unit tests; it is disposed automatically. |
| `ref.mounted` | `false` if the provider was disposed while an `await` was running. |

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

## Part A — Core

Errors, input parsing, network check, URLs, and the providers for outside things
(http client, shared preferences, network).

### Step 1 — AppException: typed errors with their message

A `sealed` exception hierarchy replaces both *Failures* and *Either*. Each error knows its
user-facing message, and `errorMessageFor` turns any error into text for the UI.

📄 **Create:** `trivia_riverpod/lib/core/exceptions/app_exception.dart`

```dart
/// Every error the app knows how to show to the user.
///
/// Each subtype carries its user-facing [message], so the UI never needs a
/// separate failure-to-message mapping.
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

/// Turns any error caught by the controller into text for the UI.
String errorMessageFor(Object error) {
  return switch (error) {
    AppException(:final message) => message,
    _ => 'Unexpected error',
  };
}
```

📄 **Create the test:** `trivia_riverpod/test/core/exceptions/app_exception_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';

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

    test('should return "Unexpected error" for any other error', () {
      expect(errorMessageFor(StateError('boom')), 'Unexpected error');
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/core/exceptions/app_exception_test.dart
```

✅ **Expected:** `+2: All tests passed!` — green? Go to the next step.

### Step 2 — Input converter

A plain top-level function: it is pure, so there is nothing to inject or mock. Invalid
input **throws** `InvalidInputException`, which the controller turns into `AsyncError`.

📄 **Create:** `trivia_riverpod/lib/core/utils/input_converter.dart`

```dart
import '../exceptions/app_exception.dart';

/// Converts the text typed by the user into a number >= 0.
///
/// Throws [InvalidInputException] for anything else.
int stringToUnsignedInteger(String input) {
  final integer = int.tryParse(input.trim());
  if (integer == null || integer < 0) {
    throw const InvalidInputException();
  }
  return integer;
}
```

📄 **Create the test:** `trivia_riverpod/test/core/utils/input_converter_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/core/utils/input_converter.dart';

void main() {
  group('stringToUnsignedInteger', () {
    test('should return an int when the string is an unsigned integer', () {
      expect(stringToUnsignedInteger('123'), 123);
    });

    test('should accept zero', () {
      expect(stringToUnsignedInteger('0'), 0);
    });

    test('should throw InvalidInputException for a non-number', () {
      expect(
        () => stringToUnsignedInteger('abc'),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('should throw InvalidInputException for a decimal', () {
      expect(
        () => stringToUnsignedInteger('1.0'),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('should throw InvalidInputException for a negative integer', () {
      expect(
        () => stringToUnsignedInteger('-123'),
        throwsA(isA<InvalidInputException>()),
      );
    });

    test('should throw InvalidInputException for an empty string', () {
      expect(
        () => stringToUnsignedInteger(''),
        throwsA(isA<InvalidInputException>()),
      );
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/core/utils/input_converter_test.dart
```

✅ **Expected:** `+6: All tests passed!` — green? Go to the next step.

### Step 3 — NetworkInfo

📄 **Create:** `trivia_riverpod/lib/core/network/network_info.dart`

```dart
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// No abstract interface here: mocktail can mock a concrete class, and
/// Riverpod lets tests replace the provider. Less code, same testability.
class NetworkInfo {
  NetworkInfo(this.connectionChecker);

  final InternetConnection connectionChecker;

  Future<bool> get isConnected => connectionChecker.hasInternetAccess;
}
```

📄 **Create the test:** `trivia_riverpod/test/core/network/network_info_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_riverpod/core/network/network_info.dart';

class MockInternetConnection extends Mock implements InternetConnection {}

void main() {
  late NetworkInfo networkInfo;
  late MockInternetConnection mockInternetConnection;

  setUp(() {
    mockInternetConnection = MockInternetConnection();
    networkInfo = NetworkInfo(mockInternetConnection);
  });

  test(
    'should forward the call to InternetConnection.hasInternetAccess',
    () async {
      // arrange
      when(() => mockInternetConnection.hasInternetAccess)
          .thenAnswer((_) async => true);
      // act
      final result = await networkInfo.isConnected;
      // assert
      verify(() => mockInternetConnection.hasInternetAccess).called(1);
      expect(result, true);
    },
  );
}
```

▶️ **Run it:**

```bash
flutter test test/core/network/network_info_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 4 — API URLs

📄 **Create:** `trivia_riverpod/lib/core/constants/api_constants.dart`

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

> 🧪 **No test for this file:** constants only. The remote data source test checks the exact URLs (Step 8).

### Step 5 — Core providers (the "external" dependencies)

`sharedPreferencesProvider` **throws** on purpose. `SharedPreferences.getInstance()` is
async, so `main()` loads it first and overrides this provider with the real instance.
Forgetting the override fails loudly instead of silently.

📄 **Create:** `trivia_riverpod/lib/core/providers/core_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_info.dart';

/// Providers for things that come from outside the app (packages, platform).
/// They replace get_it: every class gets its dependencies through `ref`.

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// SharedPreferences needs `await` to load, so main() loads it and
/// overrides this provider with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo(InternetConnection());
});
```

> 🧪 **No test for this file:** these providers only create package objects. Every test overrides them; the integration test proves the wiring.

---

## Part B — Domain

### Step 6 — Test fixtures

Fake API answers. `trivia_double.json` checks that `1.0` is read as `1`.

📄 **Create the test:** `trivia_riverpod/test/fixtures/trivia.json`

```json
{
  "text": "Test Text",
  "number": 1,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_riverpod/test/fixtures/trivia_double.json`

```json
{
  "text": "Test Text",
  "number": 1.0,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_riverpod/test/fixtures/trivia_cached.json`

```json
{
  "text": "Test Text",
  "number": 1
}
```

📄 **Create the test:** `trivia_riverpod/test/fixtures/fixture_reader.dart`

```dart
import 'dart:io';

/// Reads a JSON file from `test/fixtures/`.
/// Works because `flutter test` runs from the project root.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
```

> 🧪 **No test for this file:** test helpers, used from the next step on.

### Step 7 — Model: NumberTrivia (with JSON and value equality)

`==` and `hashCode` are written by hand, which is plain Dart with no package needed. Tests
need them so that `expect(a, b)` compares values, not object identity.

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/domain/number_trivia.dart`

```dart
import 'package:flutter/foundation.dart';

/// One model for the whole feature. In this architecture the domain model
/// also handles JSON, so there is no separate Entity / Model pair.
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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/domain/number_trivia_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';

import '../../../fixtures/fixture_reader.dart';

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
flutter test test/features/number_trivia/domain/number_trivia_test.dart
```

✅ **Expected:** `+5: All tests passed!` — green? Go to the next step.

---

## Part C — Data layer

Each class has its **provider declared in the same file**, right above it. To see how
something is built, look at the top of its file.

### Step 8 — Remote data source (http)

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/data/number_trivia_remote_data_source.dart`

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/number_trivia.dart';

final numberTriviaRemoteDataSourceProvider =
    Provider<NumberTriviaRemoteDataSource>((ref) {
      return NumberTriviaRemoteDataSource(
        client: ref.watch(httpClientProvider),
      );
    });

class NumberTriviaRemoteDataSource {
  const NumberTriviaRemoteDataSource({required this.client});

  final http.Client client;

  /// Throws a [ServerException] for every error.
  Future<NumberTrivia> getConcreteNumberTrivia(int number) =>
      _getTriviaFromUrl(ApiConstants.concreteTriviaUrl(number));

  /// Throws a [ServerException] for every error.
  Future<NumberTrivia> getRandomNumberTrivia() =>
      _getTriviaFromUrl(ApiConstants.randomTriviaUrl);

  Future<NumberTrivia> _getTriviaFromUrl(String url) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
      );
    } on http.ClientException {
      throw const ServerException();
    }

    if (response.statusCode != 200) {
      throw const ServerException();
    }
    return NumberTrivia.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }
}
```

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/data/number_trivia_remote_data_source_test.dart`

These are plain unit tests: we call the constructor with a mock client. You don't need
Riverpod to test a class that takes its dependencies in the constructor.

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:trivia_riverpod/core/constants/api_constants.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_remote_data_source.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';

import '../../../fixtures/fixture_reader.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late NumberTriviaRemoteDataSource dataSource;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    // mocktail needs a fallback value to use `any()` for a non-null Uri.
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    dataSource = NumberTriviaRemoteDataSource(client: mockHttpClient);
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
            Uri.parse(ApiConstants.concreteTriviaUrl(tNumber)),
            headers: {'Content-Type': 'application/json'},
          ),
        ).called(1);
      },
    );

    test('should return NumberTrivia when the response code is 200', () async {
      setUpMockHttpClientSuccess200();

      final result = await dataSource.getConcreteNumberTrivia(tNumber);

      expect(result, tNumberTrivia);
    });

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

    test('should return NumberTrivia when the response code is 200', () async {
      setUpMockHttpClientSuccess200();

      final result = await dataSource.getRandomNumberTrivia();

      expect(result, tNumberTrivia);
    });

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
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/number_trivia_remote_data_source_test.dart
```

✅ **Expected:** `+7: All tests passed!` — green? Go to the next step.

### Step 9 — Local data source (shared_preferences)

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/data/number_trivia_local_data_source.dart`

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/number_trivia.dart';

const cachedNumberTriviaKey = 'CACHED_NUMBER_TRIVIA';

final numberTriviaLocalDataSourceProvider =
    Provider<NumberTriviaLocalDataSource>((ref) {
      return NumberTriviaLocalDataSource(
        sharedPreferences: ref.watch(sharedPreferencesProvider),
      );
    });

class NumberTriviaLocalDataSource {
  const NumberTriviaLocalDataSource({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  /// Throws a [CacheException] if nothing is cached.
  Future<NumberTrivia> getLastNumberTrivia() async {
    final jsonString = sharedPreferences.getString(cachedNumberTriviaKey);
    if (jsonString == null) {
      throw const CacheException();
    }
    return NumberTrivia.fromJson(
      json.decode(jsonString) as Map<String, dynamic>,
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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/data/number_trivia_local_data_source_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_local_data_source.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';

import '../../../fixtures/fixture_reader.dart';

void main() {
  late NumberTriviaLocalDataSource dataSource;

  /// Instead of mocking SharedPreferences we use its built-in in-memory
  /// version. The test then checks what is really stored.
  Future<SharedPreferences> preferencesWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('getLastNumberTrivia', () {
    final tNumberTrivia = NumberTrivia.fromJson(
      json.decode(fixture('trivia_cached.json')) as Map<String, dynamic>,
    );

    test(
      'should return NumberTrivia from SharedPreferences when cached',
      () async {
        final prefs = await preferencesWith({
          cachedNumberTriviaKey: fixture('trivia_cached.json'),
        });
        dataSource = NumberTriviaLocalDataSource(sharedPreferences: prefs);

        final result = await dataSource.getLastNumberTrivia();

        expect(result, tNumberTrivia);
      },
    );

    test(
      'should throw a CacheException when there is no cached value',
      () async {
        final prefs = await preferencesWith({});
        dataSource = NumberTriviaLocalDataSource(sharedPreferences: prefs);

        final call = dataSource.getLastNumberTrivia;

        expect(() => call(), throwsA(isA<CacheException>()));
      },
    );
  });

  group('cacheNumberTrivia', () {
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

    test(
      'should store the trivia as a JSON string in SharedPreferences',
      () async {
        final prefs = await preferencesWith({});
        dataSource = NumberTriviaLocalDataSource(sharedPreferences: prefs);

        await dataSource.cacheNumberTrivia(tNumberTrivia);

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
flutter test test/features/number_trivia/data/number_trivia_local_data_source_test.dart
```

✅ **Expected:** `+3: All tests passed!` — green? Go to the next step.

### Step 10 — Repository (online → API + cache, offline → cache)

Errors **pass through**: `ServerException` and `CacheException` reach the controller,
where `AsyncValue.guard` catches them. Compare with the Bloc version, which converted them
into `Left(Failure)`.

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/data/number_trivia_repository.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_info.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/number_trivia.dart';
import 'number_trivia_local_data_source.dart';
import 'number_trivia_remote_data_source.dart';

final numberTriviaRepositoryProvider = Provider<NumberTriviaRepository>((ref) {
  return NumberTriviaRepository(
    remoteDataSource: ref.watch(numberTriviaRemoteDataSourceProvider),
    localDataSource: ref.watch(numberTriviaLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

/// Online: fetch from the API and cache the result.
/// Offline: return the last cached trivia.
///
/// Errors are not wrapped in Either: the repository lets the typed
/// [AppException]s through, and the controller turns them into AsyncError.
class NumberTriviaRepository {
  const NumberTriviaRepository({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  final NumberTriviaRemoteDataSource remoteDataSource;
  final NumberTriviaLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  Future<NumberTrivia> getConcreteNumberTrivia(int number) {
    return _getTrivia(() => remoteDataSource.getConcreteNumberTrivia(number));
  }

  Future<NumberTrivia> getRandomNumberTrivia() {
    return _getTrivia(remoteDataSource.getRandomNumberTrivia);
  }

  Future<NumberTrivia> _getTrivia(
    Future<NumberTrivia> Function() getConcreteOrRandom,
  ) async {
    if (await networkInfo.isConnected) {
      final remoteTrivia = await getConcreteOrRandom();
      await localDataSource.cacheNumberTrivia(remoteTrivia);
      return remoteTrivia;
    }
    return localDataSource.getLastNumberTrivia();
  }
}
```

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/data/number_trivia_repository_test.dart`

To check that a `Future` throws, use `await expectLater(future, throwsA(isA<X>()))`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/core/network/network_info.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_local_data_source.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_remote_data_source.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_repository.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';

class MockRemoteDataSource extends Mock
    implements NumberTriviaRemoteDataSource {}

class MockLocalDataSource extends Mock implements NumberTriviaLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late NumberTriviaRepository repository;
  late MockRemoteDataSource mockRemoteDataSource;
  late MockLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;

  setUpAll(() {
    registerFallbackValue(const NumberTrivia(text: 'fallback', number: 0));
  });

  setUp(() {
    mockRemoteDataSource = MockRemoteDataSource();
    mockLocalDataSource = MockLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = NumberTriviaRepository(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
    );
    when(() => mockLocalDataSource.cacheNumberTrivia(any()))
        .thenAnswer((_) async {});
  });

  void runTestsOnline(void Function() body) {
    group('device is online', () {
      setUp(() {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      });
      body();
    });
  }

  void runTestsOffline(void Function() body) {
    group('device is offline', () {
      setUp(() {
        when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      });
      body();
    });
  }

  group('getConcreteNumberTrivia', () {
    const tNumber = 1;
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: tNumber);

    test('should check if the device is online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => tNumberTrivia);

      await repository.getConcreteNumberTrivia(tNumber);

      verify(() => mockNetworkInfo.isConnected).called(1);
    });

    runTestsOnline(() {
      test('should return remote data when the remote call succeeds', () async {
        when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => tNumberTrivia);

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verify(() => mockRemoteDataSource.getConcreteNumberTrivia(tNumber));
        expect(result, tNumberTrivia);
      });

      test(
        'should cache the data locally when the remote call succeeds',
        () async {
          when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
              .thenAnswer((_) async => tNumberTrivia);

          await repository.getConcreteNumberTrivia(tNumber);

          verify(() => mockLocalDataSource.cacheNumberTrivia(tNumberTrivia))
              .called(1);
        },
      );

      test(
        'should throw ServerException and not cache when the call fails',
        () async {
          when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
              .thenThrow(const ServerException());

          await expectLater(
            repository.getConcreteNumberTrivia(tNumber),
            throwsA(isA<ServerException>()),
          );
          verifyNever(() => mockLocalDataSource.cacheNumberTrivia(any()));
        },
      );
    });

    runTestsOffline(() {
      test('should return the last cached data when it is present', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenAnswer((_) async => tNumberTrivia);

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verifyZeroInteractions(mockRemoteDataSource);
        expect(result, tNumberTrivia);
      });

      test('should throw CacheException when no data is cached', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenThrow(const CacheException());

        await expectLater(
          repository.getConcreteNumberTrivia(tNumber),
          throwsA(isA<CacheException>()),
        );
        verifyZeroInteractions(mockRemoteDataSource);
      });
    });
  });

  group('getRandomNumberTrivia', () {
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 123);

    runTestsOnline(() {
      test('should return remote data and cache it', () async {
        when(() => mockRemoteDataSource.getRandomNumberTrivia())
            .thenAnswer((_) async => tNumberTrivia);

        final result = await repository.getRandomNumberTrivia();

        expect(result, tNumberTrivia);
        verify(() => mockLocalDataSource.cacheNumberTrivia(tNumberTrivia))
            .called(1);
      });

      test('should throw ServerException when the remote call fails', () async {
        when(() => mockRemoteDataSource.getRandomNumberTrivia())
            .thenThrow(const ServerException());

        await expectLater(
          repository.getRandomNumberTrivia(),
          throwsA(isA<ServerException>()),
        );
      });
    });

    runTestsOffline(() {
      test('should return the last cached data when it is present', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenAnswer((_) async => tNumberTrivia);

        final result = await repository.getRandomNumberTrivia();

        verifyZeroInteractions(mockRemoteDataSource);
        expect(result, tNumberTrivia);
      });

      test('should throw CacheException when no data is cached', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenThrow(const CacheException());

        await expectLater(
          repository.getRandomNumberTrivia(),
          throwsA(isA<CacheException>()),
        );
      });
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/number_trivia_repository_test.dart
```

✅ **Expected:** `+10: All tests passed!` — green? Go to the next step.

---

## Part D — Presentation: the controller

```text
getTriviaForConcreteNumber("42")
   │ stringToUnsignedInteger ──throws──▶ state = AsyncError(InvalidInputException)
   ▼ 42
state = AsyncLoading ──▶ repository.getConcreteNumberTrivia(42)
                          ├─ ok ──────▶ state = AsyncData(trivia)
                          └─ throws ──▶ state = AsyncError(ServerException / CacheException)
```

### Step 11 — NumberTriviaController (AsyncNotifier)

`build()` returns the **initial** state: `null`, meaning "nothing searched yet". The methods
change `state`, and every widget that watches the provider rebuilds.

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/number_trivia_controller.dart`

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/input_converter.dart';
import '../data/number_trivia_repository.dart';
import '../domain/number_trivia.dart';

/// `autoDispose`: the controller is destroyed when no widget watches it.
final numberTriviaControllerProvider =
    AsyncNotifierProvider.autoDispose<NumberTriviaController, NumberTrivia?>(
      NumberTriviaController.new,
    );

/// State is `AsyncValue<NumberTrivia?>`:
/// - `AsyncData(null)`   -> nothing searched yet ("Start searching!")
/// - `AsyncLoading()`    -> request running
/// - `AsyncData(trivia)` -> show the trivia
/// - `AsyncError(e)`     -> show `errorMessageFor(e)`
class NumberTriviaController extends AsyncNotifier<NumberTrivia?> {
  @override
  FutureOr<NumberTrivia?> build() => null;

  Future<void> getTriviaForConcreteNumber(String input) async {
    final int number;
    try {
      number = stringToUnsignedInteger(input);
    } on InvalidInputException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return;
    }
    final repository = ref.read(numberTriviaRepositoryProvider);
    await _load(() => repository.getConcreteNumberTrivia(number));
  }

  Future<void> getTriviaForRandomNumber() async {
    final repository = ref.read(numberTriviaRepositoryProvider);
    await _load(repository.getRandomNumberTrivia);
  }

  Future<void> _load(Future<NumberTrivia> Function() fetch) async {
    state = const AsyncLoading();
    // guard = try/catch that returns AsyncData on success, AsyncError on error.
    final result = await AsyncValue.guard<NumberTrivia?>(fetch);
    // The screen may have closed while we waited.
    if (!ref.mounted) return;
    state = result;
  }
}
```

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/number_trivia_controller_test.dart`

How to test a notifier:

1. Build a `ProviderContainer.test` and override the **repository** with a mock.
2. `container.listen(...)` records every state in order. It also keeps the `autoDispose`
   provider alive during the test.
3. Call the method, then check the recorded list with **matchers**. We match on the type
   (`isA<AsyncLoading>()`) rather than full equality, because `AsyncError` also holds a
   stack trace.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_repository.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/number_trivia_controller.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late MockNumberTriviaRepository mockRepository;
  late ProviderContainer container;
  late List<AsyncValue<NumberTrivia?>> states;

  const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
    // A ProviderContainer is a ProviderScope without widgets.
    // `.test` disposes it automatically at the end of the test.
    container = ProviderContainer.test(
      overrides: [
        numberTriviaRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    // Record every state the controller goes through.
    // Listening also keeps the autoDispose provider alive.
    states = [];
    container.listen(
      numberTriviaControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
  });

  NumberTriviaController controller() =>
      container.read(numberTriviaControllerProvider.notifier);

  // Matchers for each kind of state.
  final isEmptyData = isA<AsyncData<NumberTrivia?>>().having(
    (s) => s.value,
    'value',
    isNull,
  );
  final isLoading = isA<AsyncLoading<NumberTrivia?>>();
  Matcher isDataWith(NumberTrivia trivia) =>
      isA<AsyncData<NumberTrivia?>>().having((s) => s.value, 'value', trivia);
  Matcher isErrorOf<T>() => isA<AsyncError<NumberTrivia?>>().having(
    (s) => s.error,
    'error',
    isA<T>(),
  );

  test('initial state should be AsyncData(null)', () {
    expect(states, [isEmptyData]);
  });

  group('getTriviaForConcreteNumber', () {
    test('should call the repository with the parsed number', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => tNumberTrivia);

      await controller().getTriviaForConcreteNumber('1');

      verify(() => mockRepository.getConcreteNumberTrivia(1)).called(1);
    });

    test(
      'should emit [AsyncError(InvalidInputException)] for invalid input',
      () async {
        await controller().getTriviaForConcreteNumber('abc');

        expect(states, [isEmptyData, isErrorOf<InvalidInputException>()]);
        verifyZeroInteractions(mockRepository);
      },
    );

    test(
      'should emit [loading, data] when data is gotten successfully',
      () async {
        when(() => mockRepository.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => tNumberTrivia);

        await controller().getTriviaForConcreteNumber('1');

        expect(states, [isEmptyData, isLoading, isDataWith(tNumberTrivia)]);
      },
    );

    test('should emit [loading, error] when the server fails', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenThrow(const ServerException());

      await controller().getTriviaForConcreteNumber('1');

      expect(states, [isEmptyData, isLoading, isErrorOf<ServerException>()]);
    });

    test('should emit [loading, error] when there is no cache', () async {
      when(() => mockRepository.getConcreteNumberTrivia(any()))
          .thenThrow(const CacheException());

      await controller().getTriviaForConcreteNumber('1');

      expect(states, [isEmptyData, isLoading, isErrorOf<CacheException>()]);
    });
  });

  group('getTriviaForRandomNumber', () {
    test(
      'should emit [loading, data] when data is gotten successfully',
      () async {
        when(() => mockRepository.getRandomNumberTrivia())
            .thenAnswer((_) async => tNumberTrivia);

        await controller().getTriviaForRandomNumber();

        verify(() => mockRepository.getRandomNumberTrivia()).called(1);
        expect(states, [isEmptyData, isLoading, isDataWith(tNumberTrivia)]);
      },
    );

    test('should emit [loading, error] when the server fails', () async {
      when(() => mockRepository.getRandomNumberTrivia())
          .thenThrow(const ServerException());

      await controller().getTriviaForRandomNumber();

      expect(states, [isEmptyData, isLoading, isErrorOf<ServerException>()]);
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/presentation/number_trivia_controller_test.dart
```

✅ **Expected:** `+8: All tests passed!` — green? Go to the next step.

---

## Part E — Presentation: widgets

### Step 12 — MessageDisplay widget

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/widgets/message_display.dart`

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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/widgets/message_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/widgets/message_display.dart';

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
flutter test test/features/number_trivia/presentation/widgets/message_display_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 13 — LoadingWidget

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/widgets/loading_widget.dart`

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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/widgets/loading_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/widgets/loading_widget.dart';

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
flutter test test/features/number_trivia/presentation/widgets/loading_widget_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 14 — TriviaDisplay widget

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/widgets/trivia_display.dart`

```dart
import 'package:flutter/material.dart';

import '../../domain/number_trivia.dart';

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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/widgets/trivia_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/widgets/trivia_display.dart';

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
flutter test test/features/number_trivia/presentation/widgets/trivia_display_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

### Step 15 — TriviaControls (ConsumerStatefulWidget)

`ConsumerStatefulWidget` = `StatefulWidget` + `ref`. It is stateful because it owns the
`TextEditingController` (which must be disposed). Callbacks use `ref.read(...notifier)`.

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/widgets/trivia_controls.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../number_trivia_controller.dart';

class TriviaControls extends ConsumerStatefulWidget {
  const TriviaControls({super.key});

  @override
  ConsumerState<TriviaControls> createState() => _TriviaControlsState();
}

class _TriviaControlsState extends ConsumerState<TriviaControls> {
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
    // `ref.read` in callbacks, `ref.watch` in build.
    ref
        .read(numberTriviaControllerProvider.notifier)
        .getTriviaForConcreteNumber(input);
  }

  void _searchRandom() {
    _controller.clear();
    ref
        .read(numberTriviaControllerProvider.notifier)
        .getTriviaForRandomNumber();
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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/widgets/trivia_controls_test.dart`

`overrideWith(() => fakeController)` swaps the **whole controller** for a fake that records
calls. This tests the widget alone. The `Consumer` that watches the provider stands in for
the screen.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/number_trivia_controller.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/widgets/trivia_controls.dart';

/// A fake controller that only records which method was called.
class FakeNumberTriviaController extends NumberTriviaController {
  final calls = <String>[];

  @override
  FutureOr<NumberTrivia?> build() => null;

  @override
  Future<void> getTriviaForConcreteNumber(String input) async {
    calls.add('concrete:$input');
  }

  @override
  Future<void> getTriviaForRandomNumber() async {
    calls.add('random');
  }
}

void main() {
  late FakeNumberTriviaController fakeController;

  Future<void> pumpControls(WidgetTester tester) {
    fakeController = FakeNumberTriviaController();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          numberTriviaControllerProvider.overrideWith(() => fakeController),
        ],
        child: MaterialApp(
          home: Scaffold(
            // Watching the provider keeps the autoDispose controller alive,
            // the same way NumberTriviaScreen does in the real app.
            body: Consumer(
              builder: (context, ref, child) {
                ref.watch(numberTriviaControllerProvider);
                return child!;
              },
              child: const TriviaControls(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('should call getTriviaForConcreteNumber when Search is tapped', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(fakeController.calls, ['concrete:42']);
  });

  testWidgets('should clear the text field after Search', (tester) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets('should call getTriviaForConcreteNumber when keyboard submits', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(fakeController.calls, ['concrete:7']);
  });

  testWidgets('should call getTriviaForRandomNumber when random is tapped', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.tap(find.text('Get random trivia'));
    await tester.pump();

    expect(fakeController.calls, ['random']);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/presentation/widgets/trivia_controls_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

### Step 16 — Barrel file for the widgets

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/widgets/widgets.dart`

```dart
export 'loading_widget.dart';
export 'message_display.dart';
export 'trivia_controls.dart';
export 'trivia_display.dart';
```

> 🧪 **No test for this file:** re-exports only.

---

## Part F — Screen, app, main

### Step 17 — NumberTriviaScreen (ConsumerWidget)

`ref.watch` the controller and `switch` over the `AsyncValue`. The patterns
`AsyncData(value: final trivia?)` (data, not null) and `AsyncData()` (data, null) separate
"loaded" from "nothing searched yet".

📄 **Create:** `trivia_riverpod/lib/features/number_trivia/presentation/number_trivia_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions/app_exception.dart';
import 'number_trivia_controller.dart';
import 'widgets/widgets.dart';

class NumberTriviaScreen extends ConsumerWidget {
  const NumberTriviaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch = rebuild this widget every time the state changes.
    final state = ref.watch(numberTriviaControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Number Trivia')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // AsyncValue is sealed: the switch must handle all 3 cases.
              // AsyncLoading comes first because a loading value can still
              // hold the previous data.
              switch (state) {
                AsyncLoading() => const LoadingWidget(),
                AsyncError(:final error) => MessageDisplay(
                  message: errorMessageFor(error),
                ),
                AsyncData(value: final trivia?) => TriviaDisplay(
                  numberTrivia: trivia,
                ),
                AsyncData() => const MessageDisplay(
                  message: 'Start searching!',
                ),
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

📄 **Create the test:** `trivia_riverpod/test/features/number_trivia/presentation/number_trivia_screen_test.dart`

Here we keep the **real** controller and mock only the repository. This tests the screen
and controller together. A `Completer` holds the repository answer, so the test can see
the loading state first.

⚠️ Use `tester.pump()`, not `pumpAndSettle()`, while a `CircularProgressIndicator` is
showing. It animates forever, so `pumpAndSettle` would time out.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/features/number_trivia/data/number_trivia_repository.dart';
import 'package:trivia_riverpod/features/number_trivia/domain/number_trivia.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/number_trivia_screen.dart';
import 'package:trivia_riverpod/features/number_trivia/presentation/widgets/widgets.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late MockNumberTriviaRepository mockRepository;

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
  });

  /// Real controller + mocked repository: we test the screen and the
  /// controller together, and only fake the data layer.
  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          numberTriviaRepositoryProvider.overrideWithValue(mockRepository),
        ],
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
    final completer = Completer<NumberTrivia>();
    when(() => mockRepository.getConcreteNumberTrivia(any()))
        .thenAnswer((_) => completer.future);
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.byType(LoadingWidget), findsOneWidget);

    completer.complete(const NumberTrivia(text: 'test trivia', number: 1));
    await tester.pump();
    expect(find.byType(TriviaDisplay), findsOneWidget);
    expect(find.text('test trivia'), findsOneWidget);
  });

  testWidgets('should show the error message when the repository throws', (
    tester,
  ) async {
    when(() => mockRepository.getRandomNumberTrivia())
        .thenThrow(const ServerException());
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
flutter test test/features/number_trivia/presentation/number_trivia_screen_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

### Step 18 — App widget and main()

`main()` loads `SharedPreferences`, then **overrides** `sharedPreferencesProvider` in
`ProviderScope`. This is the Riverpod way to inject things that need `await`.

📄 **Create:** `trivia_riverpod/lib/app.dart`

```dart
import 'package:flutter/material.dart';

import 'features/number_trivia/presentation/number_trivia_screen.dart';

class NumberTriviaApp extends StatelessWidget {
  const NumberTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Trivia (Riverpod)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const NumberTriviaScreen(),
    );
  }
}
```

📄 **Create:** `trivia_riverpod/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    // ProviderScope stores the state of every provider.
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const NumberTriviaApp(),
    ),
  );
}
```

> 🧪 **No test for this file:** covered by the integration test, which builds the same `ProviderScope` with fakes.

**Run the whole unit + widget suite now:**

```bash
flutter test
```

✅ **Expected:** `+53: All tests passed!`

Then: `flutter run`

---

## Part G — Integration test

The real app with real providers. Only the outside world is replaced, using the
**same `overrides` mechanism as `main()`**:

* `httpClientProvider` → `MockClient` (fake server)
* `networkInfoProvider` → `FakeNetworkInfo` (switch online/offline)
* `sharedPreferencesProvider` → in-memory prefs

No unregistering or resetting is needed: each test builds a fresh `ProviderScope`.

### Step 19 — End-to-end flows

📄 **Create the test:** `trivia_riverpod/integration_test/app_test.dart`

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_riverpod/app.dart';
import 'package:trivia_riverpod/core/exceptions/app_exception.dart';
import 'package:trivia_riverpod/core/network/network_info.dart';
import 'package:trivia_riverpod/core/providers/core_providers.dart';

/// Lets each test decide whether the device is "online".
/// `implements` works on a normal class too: Dart gives every class an
/// implicit interface.
class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({required this.connected});

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

  late FakeNetworkInfo networkInfo;

  /// Same as main(), but the outside world is replaced through overrides.
  Future<void> startApp(WidgetTester tester, {bool online = true}) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    networkInfo = FakeNetworkInfo(connected: online);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          httpClientProvider.overrideWithValue(fakeTriviaServer()),
          networkInfoProvider.overrideWithValue(networkInfo),
        ],
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

    networkInfo.connected = true;
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    networkInfo.connected = false;
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
flutter test                             # +53: All tests passed!
flutter test integration_test -d macos   # +4: All tests passed!
flutter run
```

### Checklist

- [ ] Every class gets its dependencies through `ref.watch` in its provider; no globals
- [ ] `ref.watch` only in `build` / providers, `ref.read` only in callbacks
- [ ] The controller checks `ref.mounted` after `await` before setting `state`
- [ ] Widget tests use `pump()` while a spinner is visible
- [ ] `flutter analyze` shows no issues

### Common problems

| Problem | Fix |
|---|---|
| `UnimplementedError: sharedPreferencesProvider must be overridden` | Override it in `ProviderScope` (main) or in the test |
| `Bad state: No ProviderScope found` | Wrap the widget under test in `ProviderScope(...)` |
| `pumpAndSettle timed out` | A spinner is showing; use `pump()` |
| Controller state resets between calls in a test | Keep a listener (`container.listen`) so `autoDispose` doesn't dispose it |
| `Cannot use "ref" after the widget/provider was disposed` | Check `ref.mounted` after `await` (already done in `_load`) |

### Bloc vs Riverpod: what changed

| | Bloc guide | Riverpod guide |
|---|---|---|
| DI | `get_it` service locator | Providers + `overrides` |
| State | Hand-written sealed states | `AsyncValue<NumberTrivia?>` |
| Errors | Exception → `Failure` → `Either` | Typed `AppException` + `AsyncValue.guard` |
| Domain | Entity + Model, repository interface, use cases | One model, concrete repository |
| Dart files in `lib/` | 26 | 18 |

**Next:** Guide 3 builds the same app with **GetX** and the GetX Pattern.
