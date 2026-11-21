# Flutter State Management Showdown: Bloc · Riverpod · GetX · Provider

The same app, **Number Trivia** (type a number → get a fact; random fact; offline cache),
built four times. Each version uses the architecture that suits its state management
best. Each one is written test-first: every file comes with its test, in the order you type
it.

| # | Guide | Architecture | Tests |
| --- | --- | --- | --- |
| 1 | [01_bloc_clean_architecture.md](01_bloc_clean_architecture.md) | **Clean Architecture**: domain (entities, use cases, repository interface) / data / presentation, `get_it`, `Either` | 61 unit+widget · 4 integration |
| 2 | [02_riverpod_architecture.md](02_riverpod_architecture.md) | **Feature-first Riverpod architecture**: data / domain / presentation; providers are the DI, `AsyncNotifier` + `AsyncValue` | 53 unit+widget · 4 integration |
| 3 | [03_getx_pattern.md](03_getx_pattern.md) | **GetX Pattern** (`get_cli` layout): data / modules (bindings · controllers · views) / routes | 53 unit+widget · 4 integration |
| 4 | [04_provider_mvvm.md](04_provider_mvvm.md) | **MVVM** (Flutter's official architecture guide): `ChangeNotifier` ViewModels, repositories + services, `Result` type | 54 unit+widget · 4 integration |

Do them in order. Guide 1 explains the shared ideas (layers, mocks, fixtures, integration
tests) in the most detail, and the later guides point out what changes.

## Project structure

```text
flutter-state-management-showdown/      ← git repo root (open this in VS Code)
├── README.md                           ← this file
├── .gitignore
├── .vscode/
│   └── launch.json                     ← F5 → choose Bloc / Riverpod / GetX / Provider
├── docs/
│   ├── 01_bloc_clean_architecture.md
│   ├── 02_riverpod_architecture.md
│   ├── 03_getx_pattern.md
│   └── 04_provider_mvvm.md
└── apps/
    ├── trivia_bloc/                    ← App 1: Clean Architecture (guide 1)
    │   ├── pubspec.yaml
    │   ├── lib/
    │   │   ├── main.dart
    │   │   ├── app.dart
    │   │   ├── injection_container.dart
    │   │   ├── core/          (constants, error, network, usecases, utils)
    │   │   └── features/number_trivia/
    │   │       ├── domain/        (entities, repositories, usecases)
    │   │       ├── data/          (models, datasources, repositories)
    │   │       └── presentation/  (bloc, pages, widgets)
    │   ├── test/                       ← mirrors lib/ + fixtures/
    │   └── integration_test/app_test.dart
    │
    ├── trivia_riverpod/                ← App 2: Riverpod architecture (guide 2)
    │   ├── pubspec.yaml
    │   ├── lib/
    │   │   ├── main.dart
    │   │   ├── app.dart
    │   │   ├── core/          (constants, exceptions, network, providers, utils)
    │   │   └── features/number_trivia/
    │   │       ├── domain/        (number_trivia.dart)
    │   │       ├── data/          (remote, local, repository)
    │   │       └── presentation/  (controller, screen, widgets)
    │   ├── test/
    │   └── integration_test/app_test.dart
    │
    ├── trivia_getx/                    ← App 3: GetX Pattern (guide 3)
    │   ├── pubspec.yaml
    │   ├── lib/
    │   │   ├── main.dart
    │   │   └── app/
    │   │       ├── trivia_app.dart
    │   │       ├── core/       (constants, errors, network, utils, values)
    │   │       ├── data/       (models, providers, repositories)
    │   │       ├── bindings/   (initial_binding.dart)
    │   │       ├── modules/number_trivia/
    │   │       │   └── bindings/  controllers/  views/  widgets/
    │   │       └── routes/     (app_routes.dart, app_pages.dart)
    │   ├── test/
    │   └── integration_test/app_test.dart
    │
    └── trivia_provider/                ← App 4: Provider + MVVM (guide 4)
        ├── pubspec.yaml
        ├── lib/
        │   ├── main.dart
        │   ├── app.dart
        │   ├── config/     (api_constants.dart, dependencies.dart)
        │   ├── utils/      (result.dart, app_exception.dart, input_converter.dart)
        │   ├── domain/models/  (number_trivia.dart)
        │   ├── data/
        │   │   ├── services/      (api, cache, connectivity)
        │   │   └── repositories/  (number_trivia_repository.dart)
        │   └── ui/
        │       ├── core/widgets/  (message_display, loading_widget)
        │       └── number_trivia/
        │           ├── view_models/  (number_trivia_view_model.dart)
        │           └── widgets/      (screen, controls, trivia_display)
        ├── test/
        └── integration_test/app_test.dart
```

The four apps are **independent Flutter projects** inside `apps/` (not a pub workspace).
Each has its own `pubspec.yaml`. They share no code on purpose: each app shows its own
architecture in full, and their dependencies can never conflict.

## Create the project

```bash
mkdir flutter-state-management-showdown && cd flutter-state-management-showdown
git init
mkdir apps docs .vscode
cd apps
flutter create --org com.example --platforms=android,ios,macos trivia_bloc
flutter create --org com.example --platforms=android,ios,macos trivia_riverpod
flutter create --org com.example --platforms=android,ios,macos trivia_getx
flutter create --org com.example --platforms=android,ios,macos trivia_provider
```

File paths in the guides (such as `trivia_bloc/lib/...`) are relative to `apps/`.

`.vscode/launch.json`:

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

## Run

Always run Flutter commands **from inside the app folder**. The test fixtures use the
relative path `test/fixtures/…`.

```bash
cd apps/trivia_bloc && flutter run       # or: flutter test
```

Run all tests of all apps from the repo root:

```bash
for app in apps/*/; do
  (cd "$app" && echo "== $app" && flutter test)
done
```

## Same app, four architectures

| | Bloc | Riverpod | GetX | Provider |
| --- | --- | --- | --- | --- |
| Architecture | Clean Architecture | Feature-first layered | GetX Pattern | MVVM (official Flutter guide) |
| Dependency injection | `get_it` | Providers + `overrides` | Bindings (`Get.put` / `lazyPut` / `find`) | `MultiProvider` + `context.read` |
| State holder | `Bloc` (events → states) | `AsyncNotifier` | `GetxController` + `.obs` | `ChangeNotifier` ViewModel |
| Screen state | Sealed states | `AsyncValue<NumberTrivia?>` | `enum TriviaStatus` | Sealed `NumberTriviaState` |
| Errors | Exception → `Failure` → `Either` | Typed `AppException` + `AsyncValue.guard` | Typed exceptions caught in the controller | `Result` (`Ok` / `Err`) |
| Use cases | Yes | No (add an application layer only when needed) | No | No (optional in the official guide) |
| Swapping in fakes for tests | `sl.unregister` / `register` | `ProviderScope(overrides:)` | Test `Bindings` + `Get.reset` | `buildProviders(...)` parameters |
| Dart files in `lib/` | 26 | 18 | 22 | 18 |
| Unit + widget tests | 61 | 53 | 53 | 54 |

## Versions used (all tests run and passed)

Flutter 3.47 · Dart 3.13 · flutter_bloc 9.1 · bloc_test 10 · equatable **2.x** ·
flutter_riverpod 3.5 · get 4.7.3 · provider 6.1 · mocktail 1.0 · http 1.6 ·
shared_preferences 2.5 · internet_connection_checker_plus 3.1.

> ⚠️ Keep `equatable` on **^2.0.7** in the Bloc app. Version 3 no longer compares
> `runtimeType`, so `ServerFailure() == CacheFailure()` would be `true`.
