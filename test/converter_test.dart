import 'dart:io';

import 'package:flutter_2yaml/flutter_2yaml.dart';
import 'package:test/test.dart';

void main() {
  late Converter converter;
  late Directory tempOutputDir;

  setUp(() {
    converter = Converter();
    tempOutputDir = Directory.systemTemp.createTempSync('flutter_2yaml_test_');
  });

  tearDown(() {
    if (tempOutputDir.existsSync()) {
      tempOutputDir.deleteSync(recursive: true);
    }
    // Clean up any .yaml files generated next to fixtures.
    final fixtureDir = Directory('test/fixtures');
    for (final file in fixtureDir.listSync()) {
      if (file is File && file.path.endsWith('.yaml')) {
        file.deleteSync();
      }
    }
  });

  group('Converter', () {
    test('converts a single StatefulWidget file', () {
      final result = converter.convertFile(
        'test/fixtures/stateful_widget.dart',
        outputDir: tempOutputDir.path,
      );

      expect(result, isNotNull);
      expect(File(result!).existsSync(), isTrue);

      final content = File(result).readAsStringSync();
      expect(content, contains('page: SplashScreen'));
      expect(content, contains('type: StatefulWidget'));
    });

    test('converts a single StatelessWidget file', () {
      final result = converter.convertFile(
        'test/fixtures/stateless_widget.dart',
        outputDir: tempOutputDir.path,
      );

      expect(result, isNotNull);
      final content = File(result!).readAsStringSync();
      expect(content, contains('widget: WelcomeCard'));
      expect(content, contains('type: StatelessWidget'));
    });

    test('skips non-widget files', () {
      final result = converter.convertFile(
        'test/fixtures/plain_class.dart',
        outputDir: tempOutputDir.path,
      );

      expect(result, isNull);
    });

    test('outputs to same directory by default', () {
      final result = converter.convertFile(
        'test/fixtures/stateful_widget.dart',
      );

      expect(result, isNotNull);
      expect(result, contains('test/fixtures/stateful_widget.yaml'));
      expect(File(result!).existsSync(), isTrue);
    });

    test('outputs to specified directory', () {
      final result = converter.convertFile(
        'test/fixtures/stateful_widget.dart',
        outputDir: tempOutputDir.path,
      );

      expect(result, isNotNull);
      expect(result, contains(tempOutputDir.path));
    });

    test('respects verbosity level', () {
      final minimalResult = converter.convertFile(
        'test/fixtures/stateful_widget.dart',
        level: VerbosityLevel.minimal,
        outputDir: tempOutputDir.path,
      );

      final content = File(minimalResult!).readAsStringSync();
      expect(content, isNot(contains('state:')));
      expect(content, isNot(contains('imports:')));
      expect(content, contains('build:'));
    });

    test('converts a directory of .dart files', () {
      final results = converter.convertDirectory(
        'test/fixtures',
        outputDir: tempOutputDir.path,
      );

      // Should convert stateful and stateless widgets, skip plain_class.
      expect(results.length, greaterThanOrEqualTo(2));
    });

    test('returns null for nonexistent file', () {
      final result = converter.convertFile(
        'test/fixtures/nonexistent.dart',
        outputDir: tempOutputDir.path,
      );

      expect(result, isNull);
    });

    test('compact format uses CSS shorthands', () {
      final result = converter.convertFile(
        'test/fixtures/stateful_widget.dart',
        outputDir: tempOutputDir.path,
      );

      final content = File(result!).readAsStringSync();
      expect(content, contains('bg: white'));
      expect(content, contains('Column(center)'));
      expect(content, contains('Image.asset:'));
    });
  });
}
