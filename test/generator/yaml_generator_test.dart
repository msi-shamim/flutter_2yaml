import 'dart:io';

import 'package:flutter_2yaml/flutter_2yaml.dart';
import 'package:test/test.dart';

void main() {
  late DartFileAnalyzer analyzer;
  late YamlGenerator generator;

  setUp(() {
    analyzer = DartFileAnalyzer();
    generator = YamlGenerator();
  });

  group('YamlGenerator - Compact Format', () {
    group('header', () {
      test('uses page: for widgets with Scaffold', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('page: SplashScreen'));
      });

      test('uses widget: for widgets without Scaffold', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('widget: WelcomeCard'));
      });

      test('includes type label', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('type: StatefulWidget'));
      });
    });

    group('compact state', () {
      test('writes state as inline list', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.standard);

        expect(yaml, contains('state: [_isLoading: bool = true]'));
      });
    });

    group('lifecycle', () {
      test('writes lifecycle methods', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.standard);

        expect(yaml, contains('lifecycle:'));
        expect(yaml, contains('initState:'));
      });
    });

    group('minimal level', () {
      test('excludes state and lifecycle', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, isNot(contains('state:')));
        expect(yaml, isNot(contains('lifecycle:')));
        expect(yaml, isNot(contains('imports:')));
        expect(yaml, contains('build:'));
      });
    });

    group('full level', () {
      test('includes imports as inline list', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.full);

        expect(yaml, contains('imports: [package:flutter/material.dart]'));
      });

      test('includes constructor params', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.full);

        expect(yaml, contains('constructor:'));
      });
    });

    group('CSS-like shorthands', () {
      test('converts backgroundColor to bg', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('bg: white'));
        expect(yaml, isNot(contains('backgroundColor')));
      });

      test('converts EdgeInsets.all to p shorthand', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('p: 16'));
      });

      test('converts height to h in SizedBox', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('SizedBox: { h: 20 }'));
      });
    });

    group('pipe syntax', () {
      test('formats Text with pipe for fontSize', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Text: title | 24'));
      });

      test('formats plain Text without pipes', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Text: subtitle'));
      });

      test('formats Text with quoted string', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Text: "Get Started"'));
      });

      test('formats Image with source and dimensions', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Image.asset: assets/logo.png | 200x200'));
      });
    });

    group('parenthetical alignment', () {
      test('formats Column(center)', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Column(center):'));
      });

      test('formats Column(start)', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('Column(start):'));
      });
    });

    group('arrow callback notation', () {
      test('formats onPressed with arrow', () {
        final source = File(
          'test/fixtures/stateless_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateless_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('onPressed → onTap'));
      });
    });

    group('conditional widgets', () {
      test('uses if prefix for conditional children', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.minimal);

        expect(yaml, contains('if _isLoading:'));
      });
    });

    group('token reduction', () {
      test('achieves significant character reduction', () {
        final source = File(
          'test/fixtures/stateful_widget.dart',
        ).readAsStringSync();
        final model = analyzer.analyze(source, 'stateful_widget.dart')!;
        final yaml = generator.generate(model, VerbosityLevel.standard);

        expect(yaml.length, lessThan(source.length));
      });
    });
  });
}
