import 'dart:io';

import 'package:flutter_2yaml/flutter_2yaml.dart';
import 'package:test/test.dart';

void main() {
  late DartFileAnalyzer analyzer;

  setUp(() {
    analyzer = DartFileAnalyzer();
  });

  group('DartFileAnalyzer', () {
    test('parses StatefulWidget correctly', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      expect(model, isNotNull);
      expect(model!.className, equals('SplashScreen'));
      expect(model.widgetType, equals(WidgetType.statefulWidget));
      expect(model.fileName, equals('stateful_widget.dart'));
    });

    test('detects page widget (has Scaffold)', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');
      expect(model!.isPage, isTrue);
    });

    test('detects component widget (no Scaffold)', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');
      expect(model!.isPage, isFalse);
    });

    test('extracts widget tree from StatefulWidget', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      expect(model!.widgetTree, isNotNull);
      expect(model.widgetTree!.name, equals('Scaffold'));
    });

    test('applies color shorthand to properties', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');
      expect(model!.widgetTree!.properties['bg'], equals('white'));
    });

    test('extracts state variables', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      expect(model!.stateModel, isNotNull);
      expect(model.stateModel!.variables, hasLength(1));
      expect(model.stateModel!.variables.first.name, equals('_isLoading'));
      expect(model.stateModel!.variables.first.type, equals('bool'));
      expect(model.stateModel!.variables.first.defaultValue, equals('true'));
    });

    test('extracts lifecycle methods without super calls', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      final lifecycle = model!.stateModel!.lifecycleMethods;
      expect(lifecycle, isNotEmpty);

      final initState = lifecycle.where((m) => m.name == 'initState').toList();
      expect(initState, isNotEmpty);
      for (final action in initState.first.actions) {
        expect(action, isNot(contains('super')));
      }
    });

    test('parses StatelessWidget correctly', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      expect(model, isNotNull);
      expect(model!.className, equals('WelcomeCard'));
      expect(model.widgetType, equals(WidgetType.statelessWidget));
      expect(model.stateModel, isNull);
    });

    test('extracts StatelessWidget tree with named children', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      expect(model!.widgetTree, isNotNull);
      expect(model.widgetTree!.name, equals('Card'));
      // Card has a 'child' named child (Padding).
      expect(model.widgetTree!.namedChildren, isNotEmpty);
      expect(model.widgetTree!.namedChildren.containsKey('child'), isTrue);
    });

    test('extracts imports', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');
      expect(model!.imports, contains('package:flutter/material.dart'));
    });

    test('extracts constructor parameters', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      expect(model!.constructorParams, isNotEmpty);
      final paramNames = model.constructorParams.map((p) => p.name).toList();
      expect(paramNames, contains('title'));
      expect(paramNames, contains('subtitle'));
    });

    test('returns null for non-widget classes', () {
      final source = File('test/fixtures/plain_class.dart').readAsStringSync();
      final model = analyzer.analyze(source, 'plain_class.dart');
      expect(model, isNull);
    });

    test('handles conditional children (if elements)', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      // Navigate: Scaffold → body (namedChild) → Center → child (namedChild) → Column → children
      final scaffold = model!.widgetTree!;
      final body = scaffold.namedChildren['body']!;
      final center = body;
      final column = center.namedChildren['child']!;

      final conditionalChild = column.children
          .where((c) => c.condition != null)
          .toList();
      expect(conditionalChild, isNotEmpty);
      expect(conditionalChild.first.condition, equals('_isLoading'));
      expect(conditionalChild.first.name, equals('CircularProgressIndicator'));
    });

    test('extracts alignment shorthand for Column', () {
      final source = File(
        'test/fixtures/stateful_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateful_widget.dart');

      final scaffold = model!.widgetTree!;
      final body = scaffold.namedChildren['body']!;
      final column = body.namedChildren['child']!;

      expect(column.name, equals('Column'));
      expect(column.alignmentShorthand, equals('center'));
    });

    test('extracts EdgeInsets as padding shorthand', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      // Card → child (Padding)
      final card = model!.widgetTree!;
      final padding = card.namedChildren['child']!;
      expect(padding.name, equals('Padding'));
      expect(padding.properties['p'], equals('16'));
    });

    test('separates callbacks from properties', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      // Card → child (Padding) → child (Column) → children → ElevatedButton
      final card = model!.widgetTree!;
      final padding = card.namedChildren['child']!;
      final column = padding.namedChildren['child']!;

      final button = column.children
          .where((c) => c.name == 'ElevatedButton')
          .first;

      expect(button.callbacks, isNotEmpty);
      expect(button.callbacks.containsKey('onPressed'), isTrue);
      expect(button.properties.containsKey('onPressed'), isFalse);
    });

    test('extracts TextStyle for pipe syntax', () {
      final source = File(
        'test/fixtures/stateless_widget.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'stateless_widget.dart');

      final card = model!.widgetTree!;
      final padding = card.namedChildren['child']!;
      final column = padding.namedChildren['child']!;

      // First child should be Text with fontSize: 24
      final textWidget = column.children.first;
      expect(textWidget.name, equals('Text'));
      expect(textWidget.textStyle['fontSize'], equals('24'));
    });

    test('detects state management from imports', () {
      const source = '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Hello')));
  }
}
''';
      final model = analyzer.analyze(source, 'home_page.dart');
      expect(model, isNotNull);
      expect(model!.stateManagement, isNotNull);
      expect(model.stateManagement!.type, equals('GetX'));
    });

    test('stores Scaffold children as named children', () {
      final source = File(
        'test/fixtures/complex_screen.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'complex_screen.dart');

      final scaffold = model!.widgetTree!;
      expect(scaffold.name, equals('Scaffold'));
      expect(scaffold.namedChildren.containsKey('appBar'), isTrue);
      expect(scaffold.namedChildren.containsKey('body'), isTrue);
      expect(scaffold.namedChildren.containsKey('drawer'), isTrue);
      expect(
        scaffold.namedChildren.containsKey('floatingActionButton'),
        isTrue,
      );
      expect(scaffold.namedChildren.containsKey('bottomNavigationBar'), isTrue);
    });

    test('extracts Positioned shorthand properties', () {
      final source = File(
        'test/fixtures/complex_screen.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'complex_screen.dart');

      // Navigate to Positioned widget in the tree.
      final scaffold = model!.widgetTree!;
      final body = scaffold.namedChildren['body']!;
      final scrollView = body;
      final column = scrollView.namedChildren['child']!;
      // First child: Container with Stack → Positioned
      final container = column.children.first;
      final stack = container.namedChildren['child']!;
      // Stack has a single child in children list via namedChildren
      // Actually Positioned is inside Stack's children list
      final positioned = stack.children.isNotEmpty
          ? stack.children.first
          : stack.namedChildren.values.first;

      expect(positioned.name, equals('Positioned'));
      // Should have shorthand: b (bottom) and l (left)
      expect(positioned.properties.containsKey('b'), isTrue);
      expect(positioned.properties.containsKey('l'), isTrue);
    });

    test('shortens double.infinity to full', () {
      final source = File(
        'test/fixtures/complex_screen.dart',
      ).readAsStringSync();
      final model = analyzer.analyze(source, 'complex_screen.dart');

      final scaffold = model!.widgetTree!;
      final body = scaffold.namedChildren['body']!;
      final column = body.namedChildren['child']!;
      final container = column.children.first;

      // Container has w: full (was double.infinity)
      expect(container.properties['w'], equals('full'));
    });
  });
}
