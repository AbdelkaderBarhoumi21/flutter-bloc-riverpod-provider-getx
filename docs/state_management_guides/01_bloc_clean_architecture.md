# Number Trivia with **Bloc** + **Clean Architecture**, step by step (TDD)

> **Guide 1 of 4** in the *Number Trivia: 4 state managements* series
> (Bloc · Riverpod · GetX · Provider). All four guides build **the same app** in the same
> monorepo, so you can compare them side by side.

Every line of the app is in this guide, **in the order you type it**. After each file that
has logic, you write its test straight away, run it, see it pass, and only then go on.
Nothing is left for "write all the tests at the end".

**What you will have at the end:** 61 unit + widget tests and 4 integration tests, all
passing. They were run on Flutter 3.47 / Dart 3.13 with the versions in the `pubspec.yaml`
below.

## Contents

0. [The app](#0-the-app)
1. [Why Clean Architecture for Bloc](#1-why-clean-architecture-for-bloc)
2. [Final folder structure](#2-final-folder-structure)
3. [Project setup](#3-project-setup)
4. [Part A: Core](#part-a--core)
5. [Part B: Domain layer](#part-b--domain-layer)
6. [Part C: Data layer](#part-c--data-layer)
7. [Part D: Presentation: the Bloc](#part-d--presentation-the-bloc)
8. [Part E: Presentation: widgets](#part-e--presentation-widgets)
9. [Part F: Dependency injection, page, app](#part-f--dependency-injection-page-app)
10. [Part G: Integration test](#part-g--integration-test)
11. [Final check](#final-check)

## 0. The app

**Number Trivia:** the user types a number and gets a fun fact about it. A second button
gets a fact about a random number. If the device is offline, the app shows the **last
trivia it cached**.

```text
┌──────────────────────────────┐
│ Number Trivia                │  AppBar
├──────────────────────────────┤
│              42              │  ← TriviaDisplay / MessageDisplay / LoadingWidget
│  42 is the answer to life…   │    (top third of the screen)
│                              │
│ ┌──────────────────────────┐ │
│ │ Input a number           │ │  ← TextField
│ └──────────────────────────┘ │
│ [   Search   ] [ Get random ]│  ← TriviaControls
└──────────────────────────────┘
```

The screen has four states: **Empty** ("Start searching!") → **Loading** → **Loaded**
(trivia) or **Error** (message).

## 1. Why Clean Architecture for Bloc

Bloc's core idea is **events in, states out**. It fits Clean Architecture very well,
because the Bloc is just the presentation layer that calls **use cases**:

```text
          PRESENTATION                 DOMAIN (pure Dart)                 DATA
 ┌───────────────────────────┐  ┌────────────────────────┐  ┌──────────────────────────────┐
 │ Widgets ──event──▶ Bloc   │  │ UseCases               │  │ RepositoryImpl               │
 │   ▲                │      │─▶│   GetConcreteNumber…   │─▶│   ├─ RemoteDataSource (http) │
 │   └────state───────┘      │  │   GetRandomNumber…     │  │   ├─ LocalDataSource (prefs) │
 │                           │  │ Repository (interface) │◀─│   └─ NetworkInfo             │
 └───────────────────────────┘  │ Entity: NumberTrivia   │  │ Model: NumberTriviaModel     │
                                └────────────────────────┘  └──────────────────────────────┘
               Dependencies point INWARD → the domain imports nothing from data/presentation
```

| Rule | How this project follows it |
|---|---|
| The domain knows nothing about Flutter, HTTP or storage | `domain/` imports only `dartz` and `equatable` |
| Data **implements** what the domain **declares** | `NumberTriviaRepository` (interface) ← `NumberTriviaRepositoryImpl` |
| Exceptions stay in the data layer | Data sources **throw** `ServerException`; the repository **returns** `Left(ServerFailure())` |
| The UI never builds its own dependencies | `get_it` (service locator) builds everything in `injection_container.dart` |
| One Bloc per feature, created per screen | `registerFactory` + `BlocProvider` closes it automatically |

**Packages and why**

| Package | Role |
|---|---|
| `flutter_bloc` | Bloc + `BlocProvider` / `BlocBuilder` |
| `equatable` **^2.0.7** | Value equality for states, events, failures. ⚠️ **Do not use 3.x here.** Equatable 3.0 stopped comparing `runtimeType`, so `ServerFailure() == CacheFailure()` and `NumberTriviaEmpty() == NumberTriviaLoading()` would both be **true**, and the Bloc tests would pass when they should fail. |
| `dartz` | `Either<Failure, T>`: a function returns the error **or** the value, never throws |
| `get_it` | Service locator (dependency injection) |
| `http` | API calls (`package:http/testing.dart` also gives us a fake server for integration tests) |
| `shared_preferences` | Cache the last trivia |
| `internet_connection_checker_plus` | Is there **real** internet (not only Wi-Fi)? |
| `bloc_test` (dev) | `blocTest(...)` and `MockBloc` |
| `mocktail` (dev) | Mocks **without code generation**: no `build_runner`, no `.mocks.dart` files to keep in sync |
| `integration_test` (dev, SDK) | Runs the real app on a device in tests |

## 2. Final folder structure

This is what you will have at the end. The `test/` tree mirrors `lib/`.

```text
trivia_bloc/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart
│   │   ├── error/
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── network/
│   │   │   └── network_info.dart
│   │   ├── usecases/
│   │   │   └── usecase.dart
│   │   └── utils/
│   │       └── input_converter.dart
│   ├── features/
│   │   └── number_trivia/
│   │       ├── data/
│   │       │   ├── datasources/
│   │       │   │   ├── number_trivia_local_data_source.dart
│   │       │   │   └── number_trivia_remote_data_source.dart
│   │       │   ├── models/
│   │       │   │   └── number_trivia_model.dart
│   │       │   └── repositories/
│   │       │       └── number_trivia_repository_impl.dart
│   │       ├── domain/
│   │       │   ├── entities/
│   │       │   │   └── number_trivia.dart
│   │       │   ├── repositories/
│   │       │   │   └── number_trivia_repository.dart
│   │       │   └── usecases/
│   │       │       ├── get_concrete_number_trivia.dart
│   │       │       └── get_random_number_trivia.dart
│   │       └── presentation/
│   │           ├── bloc/
│   │           │   ├── number_trivia_bloc.dart
│   │           │   ├── number_trivia_event.dart
│   │           │   └── number_trivia_state.dart
│   │           ├── pages/
│   │           │   └── number_trivia_page.dart
│   │           └── widgets/
│   │               ├── loading_widget.dart
│   │               ├── message_display.dart
│   │               ├── trivia_controls.dart
│   │               ├── trivia_display.dart
│   │               └── widgets.dart
│   ├── app.dart
│   ├── injection_container.dart
│   └── main.dart
├── test/
│   ├── core/
│   │   ├── network/
│   │   │   └── network_info_test.dart
│   │   └── utils/
│   │       └── input_converter_test.dart
│   ├── features/
│   │   └── number_trivia/
│   │       ├── data/
│   │       │   ├── datasources/
│   │       │   │   ├── number_trivia_local_data_source_test.dart
│   │       │   │   └── number_trivia_remote_data_source_test.dart
│   │       │   ├── models/
│   │       │   │   └── number_trivia_model_test.dart
│   │       │   └── repositories/
│   │       │       └── number_trivia_repository_impl_test.dart
│   │       ├── domain/
│   │       │   └── usecases/
│   │       │       ├── get_concrete_number_trivia_test.dart
│   │       │       └── get_random_number_trivia_test.dart
│   │       └── presentation/
│   │           ├── bloc/
│   │           │   └── number_trivia_bloc_test.dart
│   │           ├── pages/
│   │           │   └── number_trivia_page_test.dart
│   │           └── widgets/
│   │               ├── loading_widget_test.dart
│   │               ├── message_display_test.dart
│   │               ├── trivia_controls_test.dart
│   │               └── trivia_display_test.dart
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

### 3.1 The monorepo: four apps in one repo

All four guides live in **one repo**, with the apps in an `apps/` folder. Each app is a
normal, independent Flutter project, so their dependencies never clash (Bloc, Riverpod,
GetX and Provider don't need to agree on versions), and you can open the repo root in
VS Code to compare them.

```text
flutter-state-management-showdown/   ← open THIS folder in VS Code
├── README.md
├── .vscode/launch.json              ← run any app from the Run panel
├── docs/                            ← the 4 guides
└── apps/
    ├── trivia_bloc/                 ← this guide
    ├── trivia_riverpod/             ← guide 2
    ├── trivia_getx/                 ← guide 3
    └── trivia_provider/             ← guide 4
```

```bash
mkdir -p flutter-state-management-showdown/apps
cd flutter-state-management-showdown/apps
flutter create --org com.example --platforms=android,ios,macos trivia_bloc
cd trivia_bloc
```

(`macos` is optional. It lets you run the integration test on your Mac without an
emulator.)

Optional: `flutter-state-management-showdown/.vscode/launch.json` lets you start any app with F5:

```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "Bloc",     "request": "launch", "type": "dart", "cwd": "apps/trivia_bloc",     "program": "lib/main.dart" },
    { "name": "Riverpod", "request": "launch", "type": "dart", "cwd": "apps/trivia_riverpod", "program": "lib/main.dart" },
    { "name": "GetX",     "request": "launch", "type": "dart", "cwd": "apps/trivia_getx",     "program": "lib/main.dart" },
    { "name": "Provider", "request": "launch", "type": "dart", "cwd": "apps/trivia_provider", "program": "lib/main.dart" }
  ]
}
```

### 3.2 Dependencies

Run inside `trivia_bloc/`:

```bash
flutter pub add flutter_bloc "equatable:^2.0.7" dartz get_it http shared_preferences internet_connection_checker_plus
flutter pub add dev:bloc_test dev:mocktail "dev:integration_test:{sdk: flutter}"
```

Your `pubspec.yaml` should now look like this. Keep the `environment: sdk:` line that
`flutter create` wrote for you.

```yaml
name: trivia_bloc
description: "Number Trivia - Bloc + Clean Architecture"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.9.0 # keep the value flutter create generated

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bloc: ^9.1.1
  equatable: ^2.0.7
  dartz: ^0.10.1
  get_it: ^9.3.0
  http: ^1.6.0
  shared_preferences: ^2.5.6
  internet_connection_checker_plus: ^3.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  bloc_test: ^10.0.0
  mocktail: ^1.0.5
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

### 3.3 Delete the default test

`flutter create` made `test/widget_test.dart` for the counter app. Delete it, because it
would fail once we replace `main.dart`:

```bash
rm test/widget_test.dart
```

### 3.4 Platform setup (only needed to run the app on a phone)

The default API is `http://numbersapi.com`. It is plain **http**, so Android and iOS
block it unless you allow it. (The automated tests never touch the network, so they pass
without this. You only need it to run the app.)

**Android:** `trivia_bloc/android/app/src/main/AndroidManifest.xml`. Add the permission
above `<application>` and the cleartext flag on `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="trivia_bloc"
        android:name="${applicationName}"
        android:usesCleartextTraffic="true"
        android:icon="@mipmap/ic_launcher">
        <!-- keep everything flutter create generated in here -->
```

**iOS:** `trivia_bloc/ios/Runner/Info.plist`. Add this inside the top `<dict>`
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

`core/` holds code that **any** feature can use: errors, the "use case" contract, input
parsing, network check, URLs.

### Step 1 — Failures: what the domain sees when something goes wrong

`sealed` means "these are ALL the failures". A `switch` on a `Failure` must handle every
subtype, or it won't compile.

📄 **Create:** `trivia_bloc/lib/core/error/failures.dart`

```dart
import 'package:equatable/equatable.dart';

/// Failures are what the domain and presentation layers see.
///
/// Exceptions stay inside the data layer; the repository converts them into
/// one of these values. `sealed` lets `switch` check that every case is
/// handled.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

final class ServerFailure extends Failure {
  const ServerFailure();
}

final class CacheFailure extends Failure {
  const CacheFailure();
}

final class InvalidInputFailure extends Failure {
  const InvalidInputFailure();
}
```

> 🧪 **No test for this file:** it only declares data classes. Their equality is checked in every test that does `expect(result, const Left(ServerFailure()))`.

### Step 2 — Exceptions: what the data layer throws

📄 **Create:** `trivia_bloc/lib/core/error/exceptions.dart`

```dart
/// Thrown by the remote data source when the server answers with an error
/// or cannot be reached.
class ServerException implements Exception {}

/// Thrown by the local data source when nothing is cached yet.
class CacheException implements Exception {}
```

> 🧪 **No test for this file:** empty marker classes. The data source tests check they are thrown (`throwsA(isA<ServerException>())`).

### Step 3 — API URLs

One place for the URLs, so the code and the tests always use the same ones.
`String.fromEnvironment` reads `--dart-define` at build time.

📄 **Create:** `trivia_bloc/lib/core/constants/api_constants.dart`

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

> 🧪 **No test for this file:** constants only. The remote data source test checks the exact URL it calls (Step 13).

### Step 4 — InputConverter: turn the text field into a number

The user types text; the use case needs an `int >= 0`. Invalid input becomes
`Left(InvalidInputFailure())`, not an exception.

📄 **Create:** `trivia_bloc/lib/core/utils/input_converter.dart`

```dart
import 'package:dartz/dartz.dart';

import '../error/failures.dart';

class InputConverter {
  /// Converts the text typed by the user into a number >= 0.
  Either<Failure, int> stringToUnsignedInteger(String str) {
    final integer = int.tryParse(str.trim());
    if (integer == null || integer < 0) {
      return const Left(InvalidInputFailure());
    }
    return Right(integer);
  }
}
```

📄 **Create the test:** `trivia_bloc/test/core/utils/input_converter_test.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/core/error/failures.dart';
import 'package:trivia_bloc/core/utils/input_converter.dart';

void main() {
  late InputConverter inputConverter;

  setUp(() {
    inputConverter = InputConverter();
  });

  group('stringToUnsignedInteger', () {
    test('should return an int when the string is an unsigned integer', () {
      // act
      final result = inputConverter.stringToUnsignedInteger('123');
      // assert
      expect(result, const Right<Failure, int>(123));
    });

    test('should accept zero', () {
      final result = inputConverter.stringToUnsignedInteger('0');
      expect(result, const Right<Failure, int>(0));
    });

    test('should return a Failure when the string is not an integer', () {
      final result = inputConverter.stringToUnsignedInteger('abc');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is a decimal', () {
      final result = inputConverter.stringToUnsignedInteger('1.0');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is a negative integer', () {
      final result = inputConverter.stringToUnsignedInteger('-123');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });

    test('should return a Failure when the string is empty', () {
      final result = inputConverter.stringToUnsignedInteger('');
      expect(result, const Left<Failure, int>(InvalidInputFailure()));
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/core/utils/input_converter_test.dart
```

✅ **Expected:** `+6: All tests passed!` — green? Go to the next step.

### Step 5 — NetworkInfo: is the device online?

An **interface** (`NetworkInfo`) plus one implementation. The repository depends on the
interface, so its tests can mock "online" and "offline" easily.

📄 **Create:** `trivia_bloc/lib/core/network/network_info.dart`

```dart
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract interface class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this.connectionChecker);

  final InternetConnection connectionChecker;

  @override
  Future<bool> get isConnected => connectionChecker.hasInternetAccess;
}
```

📄 **Create the test:** `trivia_bloc/test/core/network/network_info_test.dart`

The implementation only forwards the call, so we mock `InternetConnection` and check that
the call is forwarded.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/network/network_info.dart';

class MockInternetConnection extends Mock implements InternetConnection {}

void main() {
  late NetworkInfoImpl networkInfo;
  late MockInternetConnection mockInternetConnection;

  setUp(() {
    mockInternetConnection = MockInternetConnection();
    networkInfo = NetworkInfoImpl(mockInternetConnection);
  });

  group('isConnected', () {
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

    test('should return false when there is no internet access', () async {
      when(() => mockInternetConnection.hasInternetAccess)
          .thenAnswer((_) async => false);

      final result = await networkInfo.isConnected;

      expect(result, false);
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/core/network/network_info_test.dart
```

✅ **Expected:** `+2: All tests passed!` — green? Go to the next step.

### Step 6 — The UseCase contract

Every use case is a class with a single `call` method. Because the method is named `call`,
you can use the object like a function: `getRandomNumberTrivia(const NoParams())`.

📄 **Create:** `trivia_bloc/lib/core/usecases/usecase.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Every use case has one public method, `call`, so it can be invoked like a
/// function: `getRandomNumberTrivia(const NoParams())`.
abstract interface class UseCase<SuccessType, Params> {
  Future<Either<Failure, SuccessType>> call(Params params);
}

/// Used by use cases that need no input.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
```

> 🧪 **No test for this file:** an interface and an empty `NoParams` class. The use case tests (Steps 9–10) cover them.

---

## Part B — Domain layer

Pure Dart business rules. **No Flutter, no http, no shared_preferences imports here.**

### Step 7 — Entity: NumberTrivia

📄 **Create:** `trivia_bloc/lib/features/number_trivia/domain/entities/number_trivia.dart`

```dart
import 'package:equatable/equatable.dart';

class NumberTrivia extends Equatable {
  const NumberTrivia({required this.text, required this.number});

  final String text;
  final int number;

  @override
  List<Object?> get props => [text, number];
}
```

> 🧪 **No test for this file:** a plain value class (Equatable gives `==`). Every later test compares entities with `expect`.

### Step 8 — Repository contract (interface)

The domain **declares** what it needs; the data layer will **implement** it (Step 15).
This is the dependency inversion that makes everything testable.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/domain/repositories/number_trivia_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/number_trivia.dart';

/// The contract the domain layer needs. The data layer implements it.
abstract interface class NumberTriviaRepository {
  Future<Either<Failure, NumberTrivia>> getConcreteNumberTrivia(int number);

  Future<Either<Failure, NumberTrivia>> getRandomNumberTrivia();
}
```

> 🧪 **No test for this file:** an interface has no code. We mock it in the use case tests.

### Step 9 — Use case: GetConcreteNumberTrivia

📄 **Create:** `trivia_bloc/lib/features/number_trivia/domain/usecases/get_concrete_number_trivia.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/number_trivia.dart';
import '../repositories/number_trivia_repository.dart';

class GetConcreteNumberTrivia implements UseCase<NumberTrivia, Params> {
  const GetConcreteNumberTrivia(this.repository);

  final NumberTriviaRepository repository;

  @override
  Future<Either<Failure, NumberTrivia>> call(Params params) {
    return repository.getConcreteNumberTrivia(params.number);
  }
}

class Params extends Equatable {
  const Params({required this.number});

  final int number;

  @override
  List<Object?> get props => [number];
}
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/domain/usecases/get_concrete_number_trivia_test.dart`

`MockNumberTriviaRepository extends Mock implements NumberTriviaRepository`. That one line
is all mocktail needs; there is no code generation.

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/failures.dart';
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
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/domain/usecases/get_concrete_number_trivia_test.dart
```

✅ **Expected:** `+2: All tests passed!` — green? Go to the next step.

### Step 10 — Use case: GetRandomNumberTrivia

📄 **Create:** `trivia_bloc/lib/features/number_trivia/domain/usecases/get_random_number_trivia.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/number_trivia.dart';
import '../repositories/number_trivia_repository.dart';

class GetRandomNumberTrivia implements UseCase<NumberTrivia, NoParams> {
  const GetRandomNumberTrivia(this.repository);

  final NumberTriviaRepository repository;

  @override
  Future<Either<Failure, NumberTrivia>> call(NoParams params) {
    return repository.getRandomNumberTrivia();
  }
}
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/domain/usecases/get_random_number_trivia_test.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/failures.dart';
import 'package:trivia_bloc/core/usecases/usecase.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/repositories/number_trivia_repository.dart';
import 'package:trivia_bloc/features/number_trivia/domain/usecases/get_random_number_trivia.dart';

class MockNumberTriviaRepository extends Mock
    implements NumberTriviaRepository {}

void main() {
  late GetRandomNumberTrivia usecase;
  late MockNumberTriviaRepository mockRepository;

  setUp(() {
    mockRepository = MockNumberTriviaRepository();
    usecase = GetRandomNumberTrivia(mockRepository);
  });

  const tNumberTrivia = NumberTrivia(text: 'test', number: 1);

  test('should get random trivia from the repository', () async {
    // arrange
    when(() => mockRepository.getRandomNumberTrivia())
        .thenAnswer((_) async => const Right(tNumberTrivia));
    // act
    final result = await usecase(const NoParams());
    // assert
    expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
    verify(() => mockRepository.getRandomNumberTrivia()).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/domain/usecases/get_random_number_trivia_test.dart
```

✅ **Expected:** `+1: All tests passed!` — green? Go to the next step.

---

## Part C — Data layer

Talks to the outside world (API, disk) and converts it to domain objects.

### Step 11 — Test fixtures (fake JSON responses)

Fixtures are JSON files that look exactly like real API answers. `trivia_double.json`
checks that `1.0` is read as `1`.

📄 **Create the test:** `trivia_bloc/test/fixtures/trivia.json`

```json
{
  "text": "Test Text",
  "number": 1,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_bloc/test/fixtures/trivia_double.json`

```json
{
  "text": "Test Text",
  "number": 1.0,
  "found": true,
  "type": "trivia"
}
```

📄 **Create the test:** `trivia_bloc/test/fixtures/trivia_cached.json`

```json
{
  "text": "Test Text",
  "number": 1
}
```

📄 **Create the test:** `trivia_bloc/test/fixtures/fixture_reader.dart`

```dart
import 'dart:io';

/// Reads a JSON file from `test/fixtures/`.
/// Works because `flutter test` runs from the project root.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
```

> 🧪 **No test for this file:** these are test helpers, used by the next steps.

### Step 12 — Model: NumberTriviaModel (entity + JSON)

The model **extends** the entity and adds `fromJson` / `toJson`. The domain never sees
JSON.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/data/models/number_trivia_model.dart`

```dart
import '../../domain/entities/number_trivia.dart';

/// The data-layer version of [NumberTrivia]: it knows how to read and write
/// JSON. Because it extends the entity, the repository can return it as an
/// entity with no conversion.
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
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/data/models/number_trivia_model_test.dart`

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  const tNumberTriviaModel = NumberTriviaModel(text: 'Test Text', number: 1);

  test('should be a subclass of NumberTrivia entity', () {
    expect(tNumberTriviaModel, isA<NumberTrivia>());
  });

  group('fromJson', () {
    test('should return a valid model when the JSON number is an integer', () {
      // arrange
      final jsonMap =
          json.decode(fixture('trivia.json')) as Map<String, dynamic>;
      // act
      final result = NumberTriviaModel.fromJson(jsonMap);
      // assert
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
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/models/number_trivia_model_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

### Step 13 — Remote data source (http)

It turns HTTP into a `NumberTriviaModel`, and any problem (status ≠ 200, no network) into
`ServerException`. Note that we inject `http.Client`, so the test can give it a mock.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/data/datasources/number_trivia_remote_data_source.dart`

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/number_trivia_model.dart';

abstract interface class NumberTriviaRemoteDataSource {
  /// Calls the `{baseUrl}/{number}?json` endpoint.
  ///
  /// Throws a [ServerException] for every error.
  Future<NumberTriviaModel> getConcreteNumberTrivia(int number);

  /// Calls the `{baseUrl}/random/trivia?json` endpoint.
  ///
  /// Throws a [ServerException] for every error.
  Future<NumberTriviaModel> getRandomNumberTrivia();
}

class NumberTriviaRemoteDataSourceImpl implements NumberTriviaRemoteDataSource {
  const NumberTriviaRemoteDataSourceImpl({required this.client});

  final http.Client client;

  @override
  Future<NumberTriviaModel> getConcreteNumberTrivia(int number) =>
      _getTriviaFromUrl(ApiConstants.concreteTriviaUrl(number));

  @override
  Future<NumberTriviaModel> getRandomNumberTrivia() =>
      _getTriviaFromUrl(ApiConstants.randomTriviaUrl);

  Future<NumberTriviaModel> _getTriviaFromUrl(String url) async {
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
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
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/data/datasources/number_trivia_remote_data_source_test.dart`

`registerFallbackValue(Uri())` is needed because we write `any()` for the `Uri` parameter
of `client.get`.

```dart
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
            Uri.parse(ApiConstants.concreteTriviaUrl(tNumber)),
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
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/datasources/number_trivia_remote_data_source_test.dart
```

✅ **Expected:** `+7: All tests passed!` — green? Go to the next step.

### Step 14 — Local data source (shared_preferences cache)

📄 **Create:** `trivia_bloc/lib/features/number_trivia/data/datasources/number_trivia_local_data_source.dart`

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../models/number_trivia_model.dart';

const cachedNumberTriviaKey = 'CACHED_NUMBER_TRIVIA';

abstract interface class NumberTriviaLocalDataSource {
  /// Returns the [NumberTriviaModel] cached the last time the device was
  /// online.
  ///
  /// Throws a [CacheException] if nothing is cached.
  Future<NumberTriviaModel> getLastNumberTrivia();

  Future<void> cacheNumberTrivia(NumberTriviaModel triviaToCache);
}

class NumberTriviaLocalDataSourceImpl implements NumberTriviaLocalDataSource {
  const NumberTriviaLocalDataSourceImpl({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  @override
  Future<NumberTriviaModel> getLastNumberTrivia() async {
    final jsonString = sharedPreferences.getString(cachedNumberTriviaKey);
    if (jsonString == null) {
      throw CacheException();
    }
    return NumberTriviaModel.fromJson(
      json.decode(jsonString) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> cacheNumberTrivia(NumberTriviaModel triviaToCache) async {
    await sharedPreferences.setString(
      cachedNumberTriviaKey,
      json.encode(triviaToCache.toJson()),
    );
  }
}
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/data/datasources/number_trivia_local_data_source_test.dart`

No mock here: `SharedPreferences.setMockInitialValues({...})` gives a real, in-memory
`SharedPreferences`. The test then reads back exactly what was stored.

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_bloc/core/error/exceptions.dart';
import 'package:trivia_bloc/features/number_trivia/data/datasources/number_trivia_local_data_source.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  late NumberTriviaLocalDataSourceImpl dataSource;

  /// Instead of mocking SharedPreferences we use its built-in in-memory
  /// version. The test then checks what is really stored.
  Future<SharedPreferences> preferencesWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('getLastNumberTrivia', () {
    final tNumberTriviaModel = NumberTriviaModel.fromJson(
      json.decode(fixture('trivia_cached.json')) as Map<String, dynamic>,
    );

    test(
      'should return NumberTriviaModel from SharedPreferences when cached',
      () async {
        // arrange
        final prefs = await preferencesWith({
          cachedNumberTriviaKey: fixture('trivia_cached.json'),
        });
        dataSource = NumberTriviaLocalDataSourceImpl(sharedPreferences: prefs);
        // act
        final result = await dataSource.getLastNumberTrivia();
        // assert
        expect(result, tNumberTriviaModel);
      },
    );

    test(
      'should throw a CacheException when there is no cached value',
      () async {
        final prefs = await preferencesWith({});
        dataSource = NumberTriviaLocalDataSourceImpl(sharedPreferences: prefs);

        final call = dataSource.getLastNumberTrivia;

        expect(() => call(), throwsA(isA<CacheException>()));
      },
    );
  });

  group('cacheNumberTrivia', () {
    const tNumberTriviaModel = NumberTriviaModel(
      text: 'test trivia',
      number: 1,
    );

    test(
      'should store the trivia as a JSON string in SharedPreferences',
      () async {
        // arrange
        final prefs = await preferencesWith({});
        dataSource = NumberTriviaLocalDataSourceImpl(sharedPreferences: prefs);
        // act
        await dataSource.cacheNumberTrivia(tNumberTriviaModel);
        // assert
        final expectedJsonString = json.encode(tNumberTriviaModel.toJson());
        expect(prefs.getString(cachedNumberTriviaKey), expectedJsonString);
      },
    );
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/datasources/number_trivia_local_data_source_test.dart
```

✅ **Expected:** `+3: All tests passed!` — green? Go to the next step.

### Step 15 — Repository implementation (online → API + cache, offline → cache)

This is the heart of the data layer. It turns **exceptions into failures**
(`ServerException` → `Left(ServerFailure())`), so nothing above it ever needs `try/catch`.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/data/repositories/number_trivia_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/number_trivia.dart';
import '../../domain/repositories/number_trivia_repository.dart';
import '../datasources/number_trivia_local_data_source.dart';
import '../datasources/number_trivia_remote_data_source.dart';
import '../models/number_trivia_model.dart';

/// The leading `_` keeps this type private to this file.
typedef _ConcreteOrRandomChooser = Future<NumberTriviaModel> Function();

class NumberTriviaRepositoryImpl implements NumberTriviaRepository {
  const NumberTriviaRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  final NumberTriviaRemoteDataSource remoteDataSource;
  final NumberTriviaLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  @override
  Future<Either<Failure, NumberTrivia>> getConcreteNumberTrivia(int number) {
    return _getTrivia(() => remoteDataSource.getConcreteNumberTrivia(number));
  }

  @override
  Future<Either<Failure, NumberTrivia>> getRandomNumberTrivia() {
    return _getTrivia(remoteDataSource.getRandomNumberTrivia);
  }

  /// Online: fetch from the API and cache the result.
  /// Offline: return the last cached trivia.
  Future<Either<Failure, NumberTrivia>> _getTrivia(
    _ConcreteOrRandomChooser getConcreteOrRandom,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final remoteTrivia = await getConcreteOrRandom();
        await localDataSource.cacheNumberTrivia(remoteTrivia);
        return Right(remoteTrivia);
      } on ServerException {
        return const Left(ServerFailure());
      }
    }

    try {
      final localTrivia = await localDataSource.getLastNumberTrivia();
      return Right(localTrivia);
    } on CacheException {
      return const Left(CacheFailure());
    }
  }
}
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/data/repositories/number_trivia_repository_impl_test.dart`

`runTestsOnline` / `runTestsOffline` wrap groups whose `setUp` stubs `isConnected`. This
avoids repeating the same stub in every test.

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/exceptions.dart';
import 'package:trivia_bloc/core/error/failures.dart';
import 'package:trivia_bloc/core/network/network_info.dart';
import 'package:trivia_bloc/features/number_trivia/data/datasources/number_trivia_local_data_source.dart';
import 'package:trivia_bloc/features/number_trivia/data/datasources/number_trivia_remote_data_source.dart';
import 'package:trivia_bloc/features/number_trivia/data/models/number_trivia_model.dart';
import 'package:trivia_bloc/features/number_trivia/data/repositories/number_trivia_repository_impl.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';

class MockRemoteDataSource extends Mock
    implements NumberTriviaRemoteDataSource {}

class MockLocalDataSource extends Mock implements NumberTriviaLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late NumberTriviaRepositoryImpl repository;
  late MockRemoteDataSource mockRemoteDataSource;
  late MockLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;

  setUpAll(() {
    registerFallbackValue(const NumberTriviaModel(text: 'fallback', number: 0));
  });

  setUp(() {
    mockRemoteDataSource = MockRemoteDataSource();
    mockLocalDataSource = MockLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = NumberTriviaRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
    );
    // Caching succeeds by default.
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
    const tNumberTriviaModel = NumberTriviaModel(
      text: 'test trivia',
      number: tNumber,
    );
    const NumberTrivia tNumberTrivia = tNumberTriviaModel;

    test('should check if the device is online', () async {
      // arrange
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
          .thenAnswer((_) async => tNumberTriviaModel);
      // act
      await repository.getConcreteNumberTrivia(tNumber);
      // assert
      verify(() => mockNetworkInfo.isConnected).called(1);
    });

    runTestsOnline(() {
      test('should return remote data when the remote call succeeds', () async {
        when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
            .thenAnswer((_) async => tNumberTriviaModel);

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verify(() => mockRemoteDataSource.getConcreteNumberTrivia(tNumber));
        expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
      });

      test(
        'should cache the data locally when the remote call succeeds',
        () async {
          when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
              .thenAnswer((_) async => tNumberTriviaModel);

          await repository.getConcreteNumberTrivia(tNumber);

          verify(
            () => mockLocalDataSource.cacheNumberTrivia(tNumberTriviaModel),
          ).called(1);
        },
      );

      test('should return ServerFailure when the remote call fails', () async {
        when(() => mockRemoteDataSource.getConcreteNumberTrivia(any()))
            .thenThrow(ServerException());

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verifyNever(() => mockLocalDataSource.cacheNumberTrivia(any()));
        expect(result, const Left<Failure, NumberTrivia>(ServerFailure()));
      });
    });

    runTestsOffline(() {
      test('should return the last cached data when it is present', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenAnswer((_) async => tNumberTriviaModel);

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verifyZeroInteractions(mockRemoteDataSource);
        verify(() => mockLocalDataSource.getLastNumberTrivia()).called(1);
        expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
      });

      test('should return CacheFailure when no data is cached', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenThrow(CacheException());

        final result = await repository.getConcreteNumberTrivia(tNumber);

        verifyZeroInteractions(mockRemoteDataSource);
        expect(result, const Left<Failure, NumberTrivia>(CacheFailure()));
      });
    });
  });

  group('getRandomNumberTrivia', () {
    const tNumberTriviaModel = NumberTriviaModel(
      text: 'test trivia',
      number: 123,
    );
    const NumberTrivia tNumberTrivia = tNumberTriviaModel;

    test('should check if the device is online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockRemoteDataSource.getRandomNumberTrivia())
          .thenAnswer((_) async => tNumberTriviaModel);

      await repository.getRandomNumberTrivia();

      verify(() => mockNetworkInfo.isConnected).called(1);
    });

    runTestsOnline(() {
      test('should return remote data when the remote call succeeds', () async {
        when(() => mockRemoteDataSource.getRandomNumberTrivia())
            .thenAnswer((_) async => tNumberTriviaModel);

        final result = await repository.getRandomNumberTrivia();

        verify(() => mockRemoteDataSource.getRandomNumberTrivia());
        expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
      });

      test(
        'should cache the data locally when the remote call succeeds',
        () async {
          when(() => mockRemoteDataSource.getRandomNumberTrivia())
              .thenAnswer((_) async => tNumberTriviaModel);

          await repository.getRandomNumberTrivia();

          verify(
            () => mockLocalDataSource.cacheNumberTrivia(tNumberTriviaModel),
          ).called(1);
        },
      );

      test('should return ServerFailure when the remote call fails', () async {
        when(() => mockRemoteDataSource.getRandomNumberTrivia())
            .thenThrow(ServerException());

        final result = await repository.getRandomNumberTrivia();

        verifyNever(() => mockLocalDataSource.cacheNumberTrivia(any()));
        expect(result, const Left<Failure, NumberTrivia>(ServerFailure()));
      });
    });

    runTestsOffline(() {
      test('should return the last cached data when it is present', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenAnswer((_) async => tNumberTriviaModel);

        final result = await repository.getRandomNumberTrivia();

        verifyZeroInteractions(mockRemoteDataSource);
        expect(result, const Right<Failure, NumberTrivia>(tNumberTrivia));
      });

      test('should return CacheFailure when no data is cached', () async {
        when(() => mockLocalDataSource.getLastNumberTrivia())
            .thenThrow(CacheException());

        final result = await repository.getRandomNumberTrivia();

        verifyZeroInteractions(mockRemoteDataSource);
        expect(result, const Left<Failure, NumberTrivia>(CacheFailure()));
      });
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/data/repositories/number_trivia_repository_impl_test.dart
```

✅ **Expected:** `+12: All tests passed!` — green? Go to the next step.

---

## Part D — Presentation: the Bloc

The Bloc receives **events** from the UI and emits **states**. It uses the use cases and the
`InputConverter`, and knows nothing about HTTP or storage.

```text
GetTriviaForConcreteNumber("42")
   │ InputConverter ──invalid──▶ emit Error(invalid input)
   ▼ valid (42)
emit Loading ──▶ GetConcreteNumberTrivia(Params(42)) ──Right──▶ emit Loaded(trivia)
                                                     └─Left───▶ emit Error(message)
```

### Step 16 — Events, states and the Bloc

Three files that belong together. Events and states are `part of` the bloc file, so one
import gives you all three. Type the event and state files first, then the bloc.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/bloc/number_trivia_event.dart`

```dart
part of 'number_trivia_bloc.dart';

sealed class NumberTriviaEvent extends Equatable {
  const NumberTriviaEvent();

  @override
  List<Object?> get props => [];
}

/// Events carry raw UI data only. Converting the string to an int is the
/// bloc's job (through InputConverter), not the event's or the widget's.
final class GetTriviaForConcreteNumber extends NumberTriviaEvent {
  const GetTriviaForConcreteNumber(this.numberString);

  final String numberString;

  @override
  List<Object?> get props => [numberString];
}

final class GetTriviaForRandomNumber extends NumberTriviaEvent {
  const GetTriviaForRandomNumber();
}
```

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/bloc/number_trivia_state.dart`

```dart
part of 'number_trivia_bloc.dart';

sealed class NumberTriviaState extends Equatable {
  const NumberTriviaState();

  @override
  List<Object?> get props => [];
}

final class NumberTriviaEmpty extends NumberTriviaState {
  const NumberTriviaEmpty();
}

final class NumberTriviaLoading extends NumberTriviaState {
  const NumberTriviaLoading();
}

final class NumberTriviaLoaded extends NumberTriviaState {
  const NumberTriviaLoaded({required this.trivia});

  final NumberTrivia trivia;

  @override
  List<Object?> get props => [trivia];
}

/// Named `NumberTriviaError` (not `Error`) so it does not hide Dart's
/// built-in `Error` class.
final class NumberTriviaError extends NumberTriviaState {
  const NumberTriviaError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
```

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/bloc/number_trivia_bloc.dart`

```dart
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/input_converter.dart';
import '../../domain/entities/number_trivia.dart';
import '../../domain/usecases/get_concrete_number_trivia.dart';
import '../../domain/usecases/get_random_number_trivia.dart';

part 'number_trivia_event.dart';
part 'number_trivia_state.dart';

const String serverFailureMessage = 'Server Failure';
const String cacheFailureMessage = 'Cache Failure';
const String invalidInputFailureMessage =
    'Invalid Input - The number must be a positive integer or zero';

class NumberTriviaBloc extends Bloc<NumberTriviaEvent, NumberTriviaState> {
  NumberTriviaBloc({
    required this.getConcreteNumberTrivia,
    required this.getRandomNumberTrivia,
    required this.inputConverter,
  }) : super(const NumberTriviaEmpty()) {
    on<GetTriviaForConcreteNumber>(_onGetTriviaForConcreteNumber);
    on<GetTriviaForRandomNumber>(_onGetTriviaForRandomNumber);
  }

  final GetConcreteNumberTrivia getConcreteNumberTrivia;
  final GetRandomNumberTrivia getRandomNumberTrivia;
  final InputConverter inputConverter;

  Future<void> _onGetTriviaForConcreteNumber(
    GetTriviaForConcreteNumber event,
    Emitter<NumberTriviaState> emit,
  ) async {
    final inputEither = inputConverter.stringToUnsignedInteger(
      event.numberString,
    );

    await inputEither.fold(
      (failure) async {
        emit(const NumberTriviaError(message: invalidInputFailureMessage));
      },
      (integer) async {
        emit(const NumberTriviaLoading());
        final failureOrTrivia = await getConcreteNumberTrivia(
          Params(number: integer),
        );
        _emitLoadedOrError(failureOrTrivia, emit);
      },
    );
  }

  Future<void> _onGetTriviaForRandomNumber(
    GetTriviaForRandomNumber event,
    Emitter<NumberTriviaState> emit,
  ) async {
    emit(const NumberTriviaLoading());
    final failureOrTrivia = await getRandomNumberTrivia(const NoParams());
    _emitLoadedOrError(failureOrTrivia, emit);
  }

  void _emitLoadedOrError(
    Either<Failure, NumberTrivia> failureOrTrivia,
    Emitter<NumberTriviaState> emit,
  ) {
    emit(
      failureOrTrivia.fold(
        (failure) => NumberTriviaError(message: _mapFailureToMessage(failure)),
        (trivia) => NumberTriviaLoaded(trivia: trivia),
      ),
    );
  }

  /// `Failure` is sealed, so this switch must list every subtype.
  /// Add a new Failure and the compiler shows you this line.
  String _mapFailureToMessage(Failure failure) {
    return switch (failure) {
      ServerFailure() => serverFailureMessage,
      CacheFailure() => cacheFailureMessage,
      InvalidInputFailure() => invalidInputFailureMessage,
    };
  }
}
```

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/bloc/number_trivia_bloc_test.dart`

`blocTest` builds a fresh Bloc, runs `act`, and checks the emitted states listed in
`expect`. The initial state is **not** in that list. Use `setUp` for stubs and `verify` for
call checks.

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/core/error/failures.dart';
import 'package:trivia_bloc/core/usecases/usecase.dart';
import 'package:trivia_bloc/core/utils/input_converter.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/usecases/get_concrete_number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/domain/usecases/get_random_number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/bloc/number_trivia_bloc.dart';

class MockGetConcreteNumberTrivia extends Mock
    implements GetConcreteNumberTrivia {}

class MockGetRandomNumberTrivia extends Mock implements GetRandomNumberTrivia {}

class MockInputConverter extends Mock implements InputConverter {}

void main() {
  late MockGetConcreteNumberTrivia mockGetConcreteNumberTrivia;
  late MockGetRandomNumberTrivia mockGetRandomNumberTrivia;
  late MockInputConverter mockInputConverter;

  setUpAll(() {
    registerFallbackValue(const Params(number: 0));
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    mockGetConcreteNumberTrivia = MockGetConcreteNumberTrivia();
    mockGetRandomNumberTrivia = MockGetRandomNumberTrivia();
    mockInputConverter = MockInputConverter();
  });

  NumberTriviaBloc buildBloc() => NumberTriviaBloc(
    getConcreteNumberTrivia: mockGetConcreteNumberTrivia,
    getRandomNumberTrivia: mockGetRandomNumberTrivia,
    inputConverter: mockInputConverter,
  );

  test('initial state should be NumberTriviaEmpty', () {
    expect(buildBloc().state, const NumberTriviaEmpty());
  });

  group('GetTriviaForConcreteNumber', () {
    const tNumberString = '1';
    const tNumberParsed = 1;
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

    void setUpInputConverterSuccess() {
      when(() => mockInputConverter.stringToUnsignedInteger(any()))
          .thenReturn(const Right(tNumberParsed));
    }

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should call InputConverter to validate and convert the string',
      setUp: () {
        setUpInputConverterSuccess();
        when(() => mockGetConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Right(tNumberTrivia));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber(tNumberString)),
      verify: (_) {
        verify(() => mockInputConverter.stringToUnsignedInteger(tNumberString))
            .called(1);
      },
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Error] when the input is invalid',
      setUp: () {
        when(() => mockInputConverter.stringToUnsignedInteger(any()))
            .thenReturn(const Left(InvalidInputFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber('abc')),
      expect: () => const [
        NumberTriviaError(message: invalidInputFailureMessage),
      ],
      verify: (_) => verifyZeroInteractions(mockGetConcreteNumberTrivia),
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should get data from the concrete use case',
      setUp: () {
        setUpInputConverterSuccess();
        when(() => mockGetConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Right(tNumberTrivia));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber(tNumberString)),
      verify: (_) {
        verify(
          () =>
              mockGetConcreteNumberTrivia(const Params(number: tNumberParsed)),
        ).called(1);
      },
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Loaded] when data is gotten successfully',
      setUp: () {
        setUpInputConverterSuccess();
        when(() => mockGetConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Right(tNumberTrivia));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber(tNumberString)),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaLoaded(trivia: tNumberTrivia),
      ],
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Error] when getting data fails on the server',
      setUp: () {
        setUpInputConverterSuccess();
        when(() => mockGetConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Left(ServerFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber(tNumberString)),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaError(message: serverFailureMessage),
      ],
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Error] with the cache message for a CacheFailure',
      setUp: () {
        setUpInputConverterSuccess();
        when(() => mockGetConcreteNumberTrivia(any()))
            .thenAnswer((_) async => const Left(CacheFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForConcreteNumber(tNumberString)),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaError(message: cacheFailureMessage),
      ],
    );
  });

  group('GetTriviaForRandomNumber', () {
    const tNumberTrivia = NumberTrivia(text: 'test trivia', number: 1);

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should get data from the random use case',
      setUp: () {
        when(() => mockGetRandomNumberTrivia(any()))
            .thenAnswer((_) async => const Right(tNumberTrivia));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForRandomNumber()),
      verify: (_) {
        verify(() => mockGetRandomNumberTrivia(const NoParams())).called(1);
      },
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Loaded] when data is gotten successfully',
      setUp: () {
        when(() => mockGetRandomNumberTrivia(any()))
            .thenAnswer((_) async => const Right(tNumberTrivia));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForRandomNumber()),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaLoaded(trivia: tNumberTrivia),
      ],
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Error] when getting data fails on the server',
      setUp: () {
        when(() => mockGetRandomNumberTrivia(any()))
            .thenAnswer((_) async => const Left(ServerFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForRandomNumber()),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaError(message: serverFailureMessage),
      ],
    );

    blocTest<NumberTriviaBloc, NumberTriviaState>(
      'should emit [Loading, Error] with the cache message for a CacheFailure',
      setUp: () {
        when(() => mockGetRandomNumberTrivia(any()))
            .thenAnswer((_) async => const Left(CacheFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const GetTriviaForRandomNumber()),
      expect: () => const [
        NumberTriviaLoading(),
        NumberTriviaError(message: cacheFailureMessage),
      ],
    );
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/presentation/bloc/number_trivia_bloc_test.dart
```

✅ **Expected:** `+11: All tests passed!` — green? Go to the next step.

---

## Part E — Presentation: widgets

Small, dumb widgets first (each with a **widget test**), then the controls that talk to the
Bloc.

### Step 17 — MessageDisplay widget

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/widgets/message_display.dart`

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

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/widgets/message_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/widgets/message_display.dart';

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

### Step 18 — LoadingWidget

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/widgets/loading_widget.dart`

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

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/widgets/loading_widget_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/widgets/loading_widget.dart';

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

### Step 19 — TriviaDisplay widget

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/widgets/trivia_display.dart`

```dart
import 'package:flutter/material.dart';

import '../../domain/entities/number_trivia.dart';

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

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/widgets/trivia_display_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/widgets/trivia_display.dart';

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

### Step 20 — TriviaControls (text field + buttons → events)

The widget only **adds events**; it never converts the text or calls a use case. It reads
`_controller.text` **before** clearing the field.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/widgets/trivia_controls.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/number_trivia_bloc.dart';

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

  void _dispatchConcrete() {
    // Read the text before clearing the field.
    final input = _controller.text;
    _controller.clear();
    context.read<NumberTriviaBloc>().add(GetTriviaForConcreteNumber(input));
  }

  void _dispatchRandom() {
    _controller.clear();
    context.read<NumberTriviaBloc>().add(const GetTriviaForRandomNumber());
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
          onSubmitted: (_) => _dispatchConcrete(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _dispatchConcrete,
                child: const Text('Search'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _dispatchRandom,
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

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/widgets/trivia_controls_test.dart`

`MockBloc` (from `bloc_test`) lets us check which events the widget adds, with no real Bloc
and no use cases.

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/bloc/number_trivia_bloc.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/widgets/trivia_controls.dart';

class MockNumberTriviaBloc
    extends MockBloc<NumberTriviaEvent, NumberTriviaState>
    implements NumberTriviaBloc {}

void main() {
  late MockNumberTriviaBloc mockBloc;

  setUp(() {
    mockBloc = MockNumberTriviaBloc();
    when(() => mockBloc.state).thenReturn(const NumberTriviaEmpty());
  });

  Future<void> pumpControls(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<NumberTriviaBloc>.value(
            value: mockBloc,
            child: const TriviaControls(),
          ),
        ),
      ),
    );
  }

  testWidgets('should add GetTriviaForConcreteNumber when Search is tapped', (
    tester,
  ) async {
    // arrange
    await pumpControls(tester);
    // act
    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();
    // assert
    verify(() => mockBloc.add(const GetTriviaForConcreteNumber('42')))
        .called(1);
  });

  testWidgets('should clear the text field after Search', (tester) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Search'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets('should add GetTriviaForConcreteNumber when keyboard submits', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.enterText(find.byType(TextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => mockBloc.add(const GetTriviaForConcreteNumber('7'))).called(1);
  });

  testWidgets('should add GetTriviaForRandomNumber when random is tapped', (
    tester,
  ) async {
    await pumpControls(tester);

    await tester.tap(find.text('Get random trivia'));
    await tester.pump();

    verify(() => mockBloc.add(const GetTriviaForRandomNumber())).called(1);
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/presentation/widgets/trivia_controls_test.dart
```

✅ **Expected:** `+4: All tests passed!` — green? Go to the next step.

### Step 21 — Barrel file for the widgets

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/widgets/widgets.dart`

```dart
export 'loading_widget.dart';
export 'message_display.dart';
export 'trivia_controls.dart';
export 'trivia_display.dart';
```

> 🧪 **No test for this file:** it only re-exports the widgets above.

---

## Part F — Dependency injection, page, app

Now we wire everything together.

### Step 22 — Dependency injection with get_it

`registerFactory` → a new object every time (**Bloc**, which must be closable).
`registerLazySingleton` → one object, created on first use (everything else).
Register the **interface type** and return the implementation.

📄 **Create:** `trivia_bloc/lib/injection_container.dart`

```dart
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/network_info.dart';
import 'core/utils/input_converter.dart';
import 'features/number_trivia/data/datasources/number_trivia_local_data_source.dart';
import 'features/number_trivia/data/datasources/number_trivia_remote_data_source.dart';
import 'features/number_trivia/data/repositories/number_trivia_repository_impl.dart';
import 'features/number_trivia/domain/repositories/number_trivia_repository.dart';
import 'features/number_trivia/domain/usecases/get_concrete_number_trivia.dart';
import 'features/number_trivia/domain/usecases/get_random_number_trivia.dart';
import 'features/number_trivia/presentation/bloc/number_trivia_bloc.dart';

/// sl = service locator.
final sl = GetIt.instance;

Future<void> init() async {
  //! Features - Number Trivia
  // Bloc: registerFactory -> a NEW bloc every time. A bloc has a stream that
  // must be closed, so it must not be a singleton.
  sl.registerFactory(
    () => NumberTriviaBloc(
      getConcreteNumberTrivia: sl(),
      getRandomNumberTrivia: sl(),
      inputConverter: sl(),
    ),
  );

  // Use cases: lazy singletons, created on first use and then reused.
  sl.registerLazySingleton(() => GetConcreteNumberTrivia(sl()));
  sl.registerLazySingleton(() => GetRandomNumberTrivia(sl()));

  // Repository: register the INTERFACE type, return the implementation.
  sl.registerLazySingleton<NumberTriviaRepository>(
    () => NumberTriviaRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<NumberTriviaRemoteDataSource>(
    () => NumberTriviaRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<NumberTriviaLocalDataSource>(
    () => NumberTriviaLocalDataSourceImpl(sharedPreferences: sl()),
  );

  //! Core
  sl.registerLazySingleton(InputConverter.new);
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(http.Client.new);
  sl.registerLazySingleton(InternetConnection.new);
}
```

> 🧪 **No test for this file:** it only wires real objects together. The integration test (Part G) runs this exact `init()`; if anything is missing, `get_it` throws there.

### Step 23 — The page: NumberTriviaPage + NumberTriviaView

Split in two on purpose:

* `NumberTriviaPage` **creates** the Bloc (`BlocProvider` + `sl`).
* `NumberTriviaView` **only shows** the state. Widget tests give it a `MockBloc`.

The `switch` over the sealed state is exhaustive: add a new state and the compiler points
here.

📄 **Create:** `trivia_bloc/lib/features/number_trivia/presentation/pages/number_trivia_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../bloc/number_trivia_bloc.dart';
import '../widgets/widgets.dart';

/// Creates the bloc (from get_it) and hands it to the view.
/// BlocProvider closes the bloc when the page is removed.
class NumberTriviaPage extends StatelessWidget {
  const NumberTriviaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NumberTriviaBloc>(),
      child: const NumberTriviaView(),
    );
  }
}

/// Pure UI: reads the bloc from the context. Widget tests give it a mock bloc.
class NumberTriviaView extends StatelessWidget {
  const NumberTriviaView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Number Trivia')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              BlocBuilder<NumberTriviaBloc, NumberTriviaState>(
                builder: (context, state) => switch (state) {
                  NumberTriviaEmpty() => const MessageDisplay(
                    message: 'Start searching!',
                  ),
                  NumberTriviaLoading() => const LoadingWidget(),
                  NumberTriviaLoaded(:final trivia) => TriviaDisplay(
                    numberTrivia: trivia,
                  ),
                  NumberTriviaError(:final message) => MessageDisplay(
                    message: message,
                  ),
                },
              ),
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

📄 **Create the test:** `trivia_bloc/test/features/number_trivia/presentation/pages/number_trivia_page_test.dart`

`whenListen` makes the mock Bloc emit a stream of states. This checks that the view really
rebuilds. The last test registers the mock in `sl` and checks that `NumberTriviaPage` gets
its Bloc from `get_it`. `sl.reset()` in `tearDown` keeps tests independent.

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_bloc/features/number_trivia/domain/entities/number_trivia.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/bloc/number_trivia_bloc.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/pages/number_trivia_page.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/widgets/widgets.dart';
import 'package:trivia_bloc/injection_container.dart';

class MockNumberTriviaBloc
    extends MockBloc<NumberTriviaEvent, NumberTriviaState>
    implements NumberTriviaBloc {}

void main() {
  late MockNumberTriviaBloc mockBloc;

  setUp(() {
    mockBloc = MockNumberTriviaBloc();
  });

  Future<void> pumpView(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<NumberTriviaBloc>.value(
          value: mockBloc,
          child: const NumberTriviaView(),
        ),
      ),
    );
  }

  group('NumberTriviaView', () {
    testWidgets('should show "Start searching!" for NumberTriviaEmpty', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(const NumberTriviaEmpty());

      await pumpView(tester);

      expect(find.text('Start searching!'), findsOneWidget);
      expect(find.byType(TriviaControls), findsOneWidget);
    });

    testWidgets('should show LoadingWidget for NumberTriviaLoading', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(const NumberTriviaLoading());

      await pumpView(tester);

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('should show TriviaDisplay for NumberTriviaLoaded', (
      tester,
    ) async {
      const trivia = NumberTrivia(text: 'test trivia', number: 1);
      when(() => mockBloc.state)
          .thenReturn(const NumberTriviaLoaded(trivia: trivia));

      await pumpView(tester);

      expect(find.byType(TriviaDisplay), findsOneWidget);
      expect(find.text('test trivia'), findsOneWidget);
    });

    testWidgets('should show the error message for NumberTriviaError', (
      tester,
    ) async {
      when(() => mockBloc.state)
          .thenReturn(const NumberTriviaError(message: serverFailureMessage));

      await pumpView(tester);

      expect(find.text(serverFailureMessage), findsOneWidget);
    });

    testWidgets('should rebuild when the bloc emits new states', (
      tester,
    ) async {
      const trivia = NumberTrivia(text: 'streamed trivia', number: 5);
      whenListen(
        mockBloc,
        Stream<NumberTriviaState>.fromIterable(const [
          NumberTriviaLoading(),
          NumberTriviaLoaded(trivia: trivia),
        ]),
        initialState: const NumberTriviaEmpty(),
      );

      await pumpView(tester);
      expect(find.text('Start searching!'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('streamed trivia'), findsOneWidget);
    });
  });

  group('NumberTriviaPage', () {
    tearDown(() => sl.reset());

    testWidgets('should get the bloc from get_it and show the view', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(const NumberTriviaEmpty());
      sl.registerFactory<NumberTriviaBloc>(() => mockBloc);

      await tester.pumpWidget(const MaterialApp(home: NumberTriviaPage()));

      expect(find.byType(NumberTriviaView), findsOneWidget);
      expect(find.text('Start searching!'), findsOneWidget);
    });
  });
}
```

▶️ **Run it:**

```bash
flutter test test/features/number_trivia/presentation/pages/number_trivia_page_test.dart
```

✅ **Expected:** `+6: All tests passed!` — green? Go to the next step.

### Step 24 — App widget and main()

`NumberTriviaApp` is separate from `main()`, so the integration test can start the app
with fakes.

📄 **Create:** `trivia_bloc/lib/app.dart`

```dart
import 'package:flutter/material.dart';

import 'features/number_trivia/presentation/pages/number_trivia_page.dart';

class NumberTriviaApp extends StatelessWidget {
  const NumberTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Trivia (Bloc)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green.shade800),
      home: const NumberTriviaPage(),
    );
  }
}
```

📄 **Create:** `trivia_bloc/lib/main.dart`

```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const NumberTriviaApp());
}
```

> 🧪 **No test for this file:** `main()` is covered by the integration test, which runs `di.init()` and pumps `NumberTriviaApp`.

**Run the whole unit + widget suite now:**

```bash
flutter test
```

✅ **Expected:** `+61: All tests passed!`

Then run the app (emulator or device): `flutter run`

---

## Part G — Integration test

An integration test runs the **real app** (real Bloc, use cases, repository, data sources,
`get_it`) on a device. We replace only the **outside world**:

* `http.Client` → `MockClient` from `package:http/testing.dart` (a fake server, no network)
* `NetworkInfo` → `FakeNetworkInfo`, so a test can switch online/offline
* `SharedPreferences` → in-memory (`setMockInitialValues`)

With `get_it` we do this by calling the real `di.init()`, then **unregistering** the
external pieces and registering fakes. Nothing has been created yet (lazy singletons), so
the fakes are used everywhere.

### Step 25 — End-to-end flows

📄 **Create the test:** `trivia_bloc/integration_test/app_test.dart`

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trivia_bloc/app.dart';
import 'package:trivia_bloc/core/network/network_info.dart';
import 'package:trivia_bloc/features/number_trivia/presentation/bloc/number_trivia_bloc.dart';
import 'package:trivia_bloc/injection_container.dart' as di;

/// Lets each test decide whether the device is "online".
class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({required this.connected});

  bool connected;

  @override
  Future<bool> get isConnected async => connected;
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

  /// Runs the real DI setup, then swaps the external pieces for fakes.
  Future<void> startApp(WidgetTester tester, {bool online = true}) async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
    networkInfo = FakeNetworkInfo(connected: online);
    di.sl
      ..unregister<http.Client>()
      ..registerLazySingleton<http.Client>(fakeTriviaServer)
      ..unregister<NetworkInfo>()
      ..registerLazySingleton<NetworkInfo>(() => networkInfo);

    await tester.pumpWidget(const NumberTriviaApp());
    await tester.pumpAndSettle();
  }

  tearDown(() => di.sl.reset());

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

    expect(find.text(invalidInputFailureMessage), findsOneWidget);
  });

  testWidgets('offline: shows cached trivia, or Cache Failure if none', (
    tester,
  ) async {
    await startApp(tester, online: false);

    // Nothing cached yet.
    await tester.tap(find.text('Get random trivia'));
    await tester.pumpAndSettle();
    expect(find.text(cacheFailureMessage), findsOneWidget);

    // Go online once to fill the cache, then go offline again.
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

▶️ **Run it** (pick a device: an Android emulator, iOS simulator, or `macos`):

```bash
flutter devices                      # list devices
flutter test integration_test -d macos
# or: flutter test integration_test -d emulator-5554
```

✅ **Expected:** `+4: All tests passed!`

---

## Final check

```bash
flutter analyze                       # No issues found!
flutter test                          # +61: All tests passed!
flutter test integration_test -d macos   # +4: All tests passed!
flutter run                           # try it for real
```

### Checklist

- [ ] Every step's test was green before moving on
- [ ] `domain/` imports no `package:flutter`, `http` or `shared_preferences`
- [ ] The Bloc is registered with `registerFactory`, not as a singleton
- [ ] `equatable` is `^2.0.7` (not 3.x)
- [ ] `flutter analyze` shows no issues

### Common problems

| Problem | Fix |
|---|---|
| `Bad state: No fallback value for any()` | Add `registerFallbackValue(...)` for that type in `setUpAll` |
| `GetIt: Object/factory with type X is not registered` | You forgot a `sl.register…` in `init()`, or the test didn't `sl.reset()` |
| `Cannot read fixture` / `PathNotFoundException` | Run `flutter test` from the `apps/trivia_bloc/` folder (fixture paths are relative) |
| App shows "Server Failure" on Android | Add the INTERNET permission and `usesCleartextTraffic` (§3.4), or use your own server with `--dart-define` |
| Bloc test passes when it shouldn't | Check that `equatable` is not 3.x (see §1) |

**Next:** Guide 2 builds the same app with **Riverpod** and the Riverpod app architecture.
It has fewer layers and no service locator, and the providers are the dependency
injection.
