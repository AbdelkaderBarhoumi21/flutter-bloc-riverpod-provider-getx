import 'dart:io';

/// Reads a JSON file from `test/fixtures/`.
/// Works because `flutter test` runs from the project root.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();
