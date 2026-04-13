import 'dart:io';

import 'package:flutter_2yaml/flutter_2yaml.dart';
import 'package:test/test.dart';

void main() {
  late YamlParser parser;

  setUp(() {
    parser = YamlParser();
  });

  group('YamlParser', () {
    test('parses page header for StatefulWidget', () {
      const yaml = '''
page: SplashScreen
type: StatefulWidget
build:
  Scaffold:
    bg: white
''';
      final model = parser.parse(yaml, 'splash_screen.yaml');
      expect(model.className, equals('SplashScreen'));
      expect(model.widgetType, equals(WidgetType.statefulWidget));
      expect(model.isPage, isTrue);
    });

    test('parses widget header for StatelessWidget', () {
      const yaml = '''
widget: WelcomeCard
type: StatelessWidget
build:
  Card:
    elevation: 4
''';
      final model = parser.parse(yaml, 'welcome_card.yaml');
      expect(model.className, equals('WelcomeCard'));
      expect(model.widgetType, equals(WidgetType.statelessWidget));
      expect(model.isPage, isFalse);
    });

    test('parses inline state variables', () {
      const yaml = '''
page: Home
type: StatefulWidget
state: [_isLoading: bool = true, _count: int]
build:
  Scaffold:
    bg: white
''';
      final model = parser.parse(yaml, 'home.yaml');
      expect(model.stateModel!.variables, hasLength(2));
      expect(model.stateModel!.variables[0].name, equals('_isLoading'));
      expect(model.stateModel!.variables[0].type, equals('bool'));
      expect(model.stateModel!.variables[0].defaultValue, equals('true'));
      expect(model.stateModel!.variables[1].name, equals('_count'));
      expect(model.stateModel!.variables[1].type, equals('int'));
    });

    test('parses lifecycle methods', () {
      const yaml = '''
page: Home
type: StatefulWidget
lifecycle:
  initState: [Future.delayed(3s)]
  dispose: []
build:
  Scaffold:
    bg: white
''';
      final model = parser.parse(yaml, 'home.yaml');
      final lifecycle = model.stateModel!.lifecycleMethods;
      expect(lifecycle, hasLength(2));
      expect(lifecycle[0].name, equals('initState'));
      expect(lifecycle[0].actions, contains('Future.delayed(3s)'));
      expect(lifecycle[1].name, equals('dispose'));
      expect(lifecycle[1].actions, isEmpty);
    });

    test('parses inline imports', () {
      const yaml = '''
page: Home
type: StatefulWidget
imports: [package:flutter/material.dart]
build:
  Scaffold:
    bg: white
''';
      final model = parser.parse(yaml, 'home.yaml');
      expect(model.imports, contains('package:flutter/material.dart'));
    });

    test('parses constructor params', () {
      const yaml = '''
widget: MyWidget
type: StatelessWidget
constructor: { key: super, title: this, subtitle: this }
build:
  Text:
    text: title
''';
      final model = parser.parse(yaml, 'my_widget.yaml');
      expect(model.constructorParams, hasLength(3));
      expect(model.constructorParams[1].name, equals('title'));
    });

    test('parses controller with state management', () {
      const yaml = '''
page: Home
type: StatefulWidget
controller: HomeController(GetX)
build:
  Scaffold:
    bg: white
''';
      final model = parser.parse(yaml, 'home.yaml');
      expect(model.stateManagement, isNotNull);
      expect(model.stateManagement!.type, equals('GetX'));
      expect(model.stateManagement!.controllerName, equals('HomeController'));
    });

    test('parses widget tree with nested children', () {
      const yaml = '''
page: Home
type: StatefulWidget
build:
  Scaffold:
    bg: white
    body:
      Center:
        child:
          Column(center):
            children:
              - Text: "Hello"
              - SizedBox: { h: 20 }
''';
      final model = parser.parse(yaml, 'home.yaml');
      final scaffold = model.widgetTree!;
      expect(scaffold.name, equals('Scaffold'));
      expect(scaffold.children, hasLength(1));

      final center = scaffold.children.first;
      expect(center.name, equals('Center'));

      final column = center.children.first;
      expect(column.name, equals('Column'));
      expect(column.alignmentShorthand, equals('center'));
      expect(column.children, hasLength(2));
    });

    test('parses pipe syntax for Text', () {
      const yaml = '''
widget: MyWidget
type: StatelessWidget
build:
  Column:
    children:
      - Text: "Hello" | 20 | bold | white
''';
      final model = parser.parse(yaml, 'my_widget.yaml');
      final column = model.widgetTree!;
      final text = column.children.first;

      expect(text.name, equals('Text'));
      expect(text.properties['text'], equals('"Hello"'));
      expect(text.textStyle['fontSize'], equals('20'));
      expect(text.textStyle['fontWeight'], equals('bold'));
      expect(text.textStyle['color'], equals('white'));
    });

    test('parses Image with dimensions', () {
      const yaml = '''
widget: MyWidget
type: StatelessWidget
build:
  Column:
    children:
      - Image.asset: logo.png | 200x200
''';
      final model = parser.parse(yaml, 'my_widget.yaml');
      final image = model.widgetTree!.children.first;

      expect(image.name, equals('Image'));
      expect(image.constructor, equals('asset'));
      expect(image.properties['src'], equals('logo.png'));
      expect(image.properties['width'], equals('200'));
      expect(image.properties['height'], equals('200'));
    });

    test('parses conditional widgets', () {
      const yaml = '''
widget: MyWidget
type: StatelessWidget
build:
  Column:
    children:
      - if _isLoading: CircularProgressIndicator: { color: blue }
''';
      final model = parser.parse(yaml, 'my_widget.yaml');
      final conditional = model.widgetTree!.children.first;

      expect(conditional.condition, equals('_isLoading'));
      expect(conditional.name, equals('CircularProgressIndicator'));
      expect(conditional.properties['color'], equals('blue'));
    });

    test('parses arrow callbacks', () {
      const yaml = '''
widget: MyWidget
type: StatelessWidget
build:
  ElevatedButton:
    onPressed → handleTap()
    child:
      Text: "Submit"
''';
      final model = parser.parse(yaml, 'my_widget.yaml');
      final button = model.widgetTree!;

      expect(button.callbacks['onPressed'], equals('handleTap()'));
      expect(button.children, hasLength(1));
      expect(button.children.first.name, equals('Text'));
    });
  });

  group('Round-trip: .dart → .yaml → .dart', () {
    test('StatefulWidget round-trip produces valid structure', () {
      final originalSource = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();

      // Forward: .dart → .yaml
      final analyzer = DartFileAnalyzer();
      final forwardModel = analyzer.analyze(
        originalSource,
        'stateful_widget.dart',
      )!;
      final yamlGenerator = YamlGenerator();
      final yaml = yamlGenerator.generate(
        forwardModel,
        VerbosityLevel.standard,
      );

      // Reverse: .yaml → model
      final reverseModel = parser.parse(yaml, 'stateful_widget.yaml');

      expect(reverseModel.className, equals(forwardModel.className));
      expect(reverseModel.widgetType, equals(forwardModel.widgetType));
      expect(reverseModel.isPage, equals(forwardModel.isPage));
      expect(reverseModel.widgetTree, isNotNull);
      expect(reverseModel.widgetTree!.name, equals('Scaffold'));
    });

    test('StatelessWidget round-trip produces valid structure', () {
      final originalSource = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();

      final analyzer = DartFileAnalyzer();
      final forwardModel = analyzer.analyze(
        originalSource,
        'stateless_widget.dart',
      )!;
      final yamlGenerator = YamlGenerator();
      final yaml = yamlGenerator.generate(
        forwardModel,
        VerbosityLevel.standard,
      );

      final reverseModel = parser.parse(yaml, 'stateless_widget.yaml');

      expect(reverseModel.className, equals(forwardModel.className));
      expect(reverseModel.widgetType, equals(forwardModel.widgetType));
      expect(reverseModel.widgetTree, isNotNull);
    });

    test('Full round-trip generates compilable Dart', () {
      final originalSource = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();

      // Forward
      final analyzer = DartFileAnalyzer();
      final forwardModel = analyzer.analyze(
        originalSource,
        'stateful_widget.dart',
      )!;
      final yamlGenerator = YamlGenerator();
      final yaml = yamlGenerator.generate(
        forwardModel,
        VerbosityLevel.standard,
      );

      // Reverse
      final reverseModel = parser.parse(yaml, 'stateful_widget.yaml');
      final dartGenerator = DartGenerator();
      final generatedDart = dartGenerator.generate(reverseModel);

      // Verify generated Dart contains key elements.
      expect(generatedDart, contains('class SplashScreen'));
      expect(generatedDart, contains('StatefulWidget'));
      expect(generatedDart, contains('createState'));
      expect(generatedDart, contains('_SplashScreenState'));
      expect(generatedDart, contains('bool _isLoading = true'));
      expect(generatedDart, contains('initState'));
      expect(generatedDart, contains('super.initState'));
      expect(generatedDart, contains('Scaffold'));
      expect(generatedDart, contains('backgroundColor: Colors.white'));
      expect(generatedDart, contains('Column'));
      expect(generatedDart, contains('MainAxisAlignment.center'));
      expect(generatedDart, contains("Image.asset('assets/logo.png'"));
      expect(generatedDart, contains('SizedBox(height: 20)'));
      expect(
        generatedDart,
        contains('import \'package:flutter/material.dart\''),
      );
    });
  });
}
