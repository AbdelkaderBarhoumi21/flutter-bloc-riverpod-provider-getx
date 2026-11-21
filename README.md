<div align="center">

# ⚔️ Flutter State Management Showdown

### Bloc · Riverpod · GetX · Provider: one app, four architectures, all test-driven

**Number Trivia** built four times, each with the architecture that fits its state management best.

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Bloc](https://img.shields.io/badge/flutter__bloc-9.1-13B9FD)](https://pub.dev/packages/flutter_bloc)
[![Riverpod](https://img.shields.io/badge/flutter__riverpod-3.5-00B4AB)](https://pub.dev/packages/flutter_riverpod)
[![GetX](https://img.shields.io/badge/get-4.7.3-8A2BE2)](https://pub.dev/packages/get)
[![Provider](https://img.shields.io/badge/provider-6.1-F7B500)](https://pub.dev/packages/provider)
[![TDD](https://img.shields.io/badge/approach-TDD-success)](#-test-driven-every-step)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS-lightgrey)](#-getting-started)

[The app](#-the-app) •
[Architectures](#-four-architectures-side-by-side) •
[Guides](#-step-by-step-guides) •
[Structure](#-repository-structure) •
[Getting started](#-getting-started) •
[Tech stack](#-tech-stack)

</div>

---

## 📖 About

Most state management comparisons show a counter app. This one builds a **real feature**
(remote API, offline cache, connectivity check, input validation, error handling) **four
times**, and each version uses the architecture its library was designed for:

| | State management | Architecture |
| :-: | --- | --- |
| 🧱 | **Bloc** | Clean Architecture (domain / data / presentation, use cases, `Either`) |
| 🌊 | **Riverpod 3** | Feature-first layered architecture (providers as DI, `AsyncNotifier`) |
| ⚡ | **GetX** | GetX Pattern (`get_cli` layout: bindings · controllers · views · routes) |
| 🧩 | **Provider** | MVVM from [Flutter's official architecture guide](https://docs.flutter.dev/app-architecture) |

The four apps are **independent Flutter projects** that share no code, so each one shows its
architecture in full and their dependencies never conflict.

## 📱 The app

**Number Trivia:** type a number and get a fun fact about it, or ask for a random one.
When the device is offline, the app shows the **last cached fact**.

```text
┌──────────────────────────────┐
│ Number Trivia                │
├──────────────────────────────┤
│              42              │   Empty → Loading → Loaded | Error
│  42 is the answer to life…   │
│ ┌──────────────────────────┐ │
│ │ Input a number           │ │
│ └──────────────────────────┘ │
│ [   Search   ] [ Get random ]│
└──────────────────────────────┘
```

**Data flow (same in all four apps):**

```text
online  → API (numbersapi) → cache the result → show it
offline → read the last cached result          → show it (or a cache error)
```

## 🏗️ Four architectures, side by side

| | 🧱 Bloc | 🌊 Riverpod | ⚡ GetX | 🧩 Provider |
| --- | --- | --- | --- | --- |
| **Architecture** | Clean Architecture | Feature-first layered | GetX Pattern | MVVM (official guide) |
| **Dependency injection** | `get_it` | Providers + `overrides` | Bindings (`Get.put` / `lazyPut` / `find`) | `MultiProvider` + `context.read` |
| **State holder** | `Bloc` (events → states) | `AsyncNotifier` | `GetxController` + `.obs` | `ChangeNotifier` ViewModel |
| **Screen state** | Sealed states | `AsyncValue<NumberTrivia?>` | `enum TriviaStatus` | Sealed `NumberTriviaState` |
| **Error handling** | Exception → `Failure` → `Either` | `AppException` + `AsyncValue.guard` | Typed exceptions in controller | `Result` (`Ok` / `Err`) |
| **Use cases** | ✅ Yes | ➖ Only when needed | ➖ No | ➖ Optional |
| **Fakes in tests** | `sl.unregister` / `register` | `ProviderScope(overrides:)` | Test `Bindings` + `Get.reset` | `buildProviders(...)` params |
| **Dart files in `lib/`** | 26 | 18 | 22 | 18 |
| **Unit + widget tests** | 61 | 53 | 53 | 54 |
| **Integration tests** | 4 | 4 | 4 | 4 |

## 📚 Step-by-step guides

Each guide contains **every line of its app, in the order you type it**. Start with guide 1:
it explains the shared ideas (layers, mocks, fixtures, integration tests) in the most detail,
and the later guides focus on what changes.

| # | Guide | What you learn |
| :-: | --- | --- |
| 0 | [Overview & setup](docs/state_management_guides/00_README.md) | Monorepo layout, project creation, VS Code launch configs, versions |
| 1 | [Bloc + Clean Architecture](docs/state_management_guides/01_bloc_clean_architecture.md) | Entities, repository contracts, use cases, `Either`, `get_it`, `bloc_test` |
| 2 | [Riverpod 3 architecture](docs/state_management_guides/02_riverpod_architecture.md) | Providers as DI, `AsyncNotifier`, `AsyncValue`, provider overrides in tests |
| 3 | [GetX Pattern](docs/state_management_guides/03_getx_pattern.md) | `.obs` + `Obx`, Bindings, `GetPage` routing, `Get.reset` in tests |
| 4 | [Provider + MVVM](docs/state_management_guides/04_provider_mvvm.md) | `ChangeNotifier` ViewModels, services + repositories, `Result` type |

## 🧪 Test-driven, every step

The apps are built with a strict **red → green** rhythm: after each file with logic, its test
is written and run before moving on.

- **Unit tests:** models, data sources, repositories, use cases, controllers / ViewModels / Blocs
- **Widget tests:** every widget and screen state (empty, loading, loaded, error)
- **Integration tests:** 4 end-to-end flows per app with `integration_test`
- **Mocks:** `mocktail`, plus JSON fixtures for API responses

**~221 unit + widget tests and 16 integration tests** across the four apps.

## 🗂️ Repository structure

```text
.
├── README.md
├── .vscode/launch.json            ← F5 → Bloc / Riverpod / GetX / Provider
├── docs/
│   └── state_management_guides/   ← the 4 step-by-step guides + overview
└── apps/
    ├── trivia_bloc/               ← core/ · features/number_trivia/{domain,data,presentation}
    ├── trivia_riverpod/           ← core/ · features/number_trivia/{domain,data,presentation}
    ├── trivia_getx/               ← app/{core,data,bindings,modules,routes}
    └── trivia_provider/           ← config/ · utils/ · domain/ · data/{services,repositories} · ui/
```

Every app has its own `pubspec.yaml`, a `test/` folder that mirrors `lib/` (plus `fixtures/`),
and `integration_test/app_test.dart`.

## 🚀 Getting started

**Requirements:** Flutter 3.47+ / Dart 3.13+

```bash
git clone https://github.com/AbdelkaderBarhoumi21/flutter-bloc-riverpod-getx.git
cd flutter-bloc-riverpod-getx

# run one app (always from inside its folder: fixtures use relative paths)
cd apps/trivia_bloc
flutter pub get
flutter run
```

Run the tests:

```bash
flutter test                         # unit + widget tests
flutter test integration_test        # end-to-end tests (needs a device/emulator)
```

Run every app's tests from the repo root:

```bash
for app in apps/*/; do (cd "$app" && echo "== $app" && flutter test); done
```

In VS Code, press **F5** and pick **Bloc**, **Riverpod**, **GetX** or **Provider**.

## 🛠️ Tech stack

| Category | Packages |
| --- | --- |
| **Framework** | Flutter 3.47 · Dart 3.13 |
| **State management** | `flutter_bloc` 9.1 · `flutter_riverpod` 3.5 · `get` 4.7.3 · `provider` 6.1 |
| **Dependency injection** | `get_it` 9.3 (Bloc) · Riverpod providers · GetX Bindings · `provider` |
| **Networking** | `http` 1.6 |
| **Local cache** | `shared_preferences` 2.5 |
| **Connectivity** | `internet_connection_checker_plus` 3.1 |
| **Functional / equality** | `dartz` 0.10 (`Either`) · `equatable` 2.x |
| **Testing** | `flutter_test` · `bloc_test` 10 · `mocktail` 1.0 · `integration_test` |
| **Linting** | `flutter_lints` 6.0 |

> ⚠️ Keep `equatable` on **^2.0.7** in the Bloc app. Version 3 no longer compares
> `runtimeType`, so `ServerFailure() == CacheFailure()` would be `true`.

## 🗺️ Roadmap

- [x] Step-by-step TDD guides for all four architectures
- [ ] `trivia_bloc`: Bloc + Clean Architecture
- [ ] `trivia_riverpod`: Riverpod 3
- [ ] `trivia_getx`: GetX Pattern
- [ ] `trivia_provider`: Provider + MVVM
- [ ] GitHub Actions CI running all four test suites

## 🤝 Contributing

Issues and pull requests are welcome, whether it's a bug in a guide, a better test, or a
fifth state management to add to the showdown.

## 👤 Author

**Abdelkader Barhoumi** · [@AbdelkaderBarhoumi21](https://github.com/AbdelkaderBarhoumi21)

<div align="center">

⭐ If this comparison helped you pick a state management, consider starring the repo!

</div>
