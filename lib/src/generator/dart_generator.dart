import '../models/dart_file_model.dart';
import '../models/state_model.dart';
import '../models/widget_node.dart';
import '../parser/reverse_shorthand_map.dart';

/// Generates idiomatic Flutter Dart source code from a [DartFileModel].
///
/// Produces properly formatted, const-aware code with correct imports,
/// class structure, state management, lifecycle methods, and widget tree.
class DartGenerator {
  /// Generates complete Dart source code from the given [model].
  String generate(DartFileModel model) {
    final buffer = StringBuffer();

    _writeImports(buffer, model);
    buffer.writeln();

    if (model.widgetType == WidgetType.statelessWidget) {
      _writeStatelessWidget(buffer, model);
    } else {
      _writeStatefulWidget(buffer, model);
    }

    return buffer.toString();
  }

  /// Writes import statements.
  void _writeImports(StringBuffer buffer, DartFileModel model) {
    final imports = List<String>.from(model.imports);

    // Always ensure material.dart is imported.
    if (!imports.any((i) => i.contains('flutter/material.dart'))) {
      imports.insert(0, 'package:flutter/material.dart');
    }

    // Add state management import if detected.
    if (model.stateManagement != null) {
      final smPackage = stateManagementPackages[model.stateManagement!.type];
      if (smPackage != null && !imports.any((i) => i.contains(smPackage))) {
        imports.add(smPackage);
      }
    }

    for (final importUri in imports) {
      buffer.writeln("import '$importUri';");
    }
  }

  /// Writes a StatelessWidget class.
  void _writeStatelessWidget(StringBuffer buffer, DartFileModel model) {
    buffer.writeln('class ${model.className} extends StatelessWidget {');

    _writeFields(buffer, model);
    _writeConstructor(buffer, model);
    buffer.writeln();
    _writeBuildMethod(buffer, model);

    buffer.writeln('}');
  }

  /// Writes a StatefulWidget class + State class.
  void _writeStatefulWidget(StringBuffer buffer, DartFileModel model) {
    // Widget class.
    buffer.writeln('class ${model.className} extends StatefulWidget {');
    _writeFields(buffer, model);
    _writeConstructor(buffer, model);
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln(
      '  State<${model.className}> createState() => _${model.className}State();',
    );
    buffer.writeln('}');
    buffer.writeln();

    // State class.
    buffer.writeln(
      'class _${model.className}State extends State<${model.className}> {',
    );

    _writeStateVariables(buffer, model);
    _writeLifecycleMethods(buffer, model);
    buffer.writeln();
    _writeBuildMethod(buffer, model);

    buffer.writeln('}');
  }

  /// Writes field declarations for constructor parameters.
  void _writeFields(StringBuffer buffer, DartFileModel model) {
    for (final param in model.constructorParams) {
      if (param.type == 'super' || param.name == 'key') continue;
      buffer.writeln('  final ${param.type} ${param.name};');
    }
  }

  /// Writes the constructor.
  void _writeConstructor(StringBuffer buffer, DartFileModel model) {
    if (model.constructorParams.isEmpty) {
      buffer.writeln('  const ${model.className}({super.key});');
      return;
    }

    final params = <String>[];
    for (final param in model.constructorParams) {
      if (param.name == 'key') {
        params.add('super.key');
      } else if (param.type == 'super') {
        params.add('super.${param.name}');
      } else if (param.isRequired) {
        params.add('required this.${param.name}');
      } else {
        params.add('this.${param.name}');
      }
    }

    buffer.writeln('  const ${model.className}({');
    for (final param in params) {
      buffer.writeln('    $param,');
    }
    buffer.writeln('  });');
  }

  /// Writes state variable declarations.
  void _writeStateVariables(StringBuffer buffer, DartFileModel model) {
    final stateModel = model.stateModel;
    if (stateModel == null) return;

    for (final variable in stateModel.variables) {
      final defaultStr = variable.defaultValue != null
          ? ' = ${variable.defaultValue}'
          : '';
      buffer.writeln('  ${variable.type} ${variable.name}$defaultStr;');
    }

    if (stateModel.variables.isNotEmpty) buffer.writeln();
  }

  /// Writes lifecycle methods (initState, dispose, etc.).
  void _writeLifecycleMethods(StringBuffer buffer, DartFileModel model) {
    final stateModel = model.stateModel;
    if (stateModel == null) return;

    for (final method in stateModel.lifecycleMethods) {
      buffer.writeln('  @override');
      buffer.writeln('  void ${method.name}() {');
      buffer.writeln('    super.${method.name}();');

      for (final action in method.actions) {
        final expandedAction = _expandAction(action);
        buffer.writeln('    $expandedAction;');
      }

      buffer.writeln('  }');
      buffer.writeln();
    }

    // If StatefulWidget has no lifecycle methods, add skeleton.
    if (stateModel.lifecycleMethods.isEmpty &&
        model.widgetType == WidgetType.statefulWidget) {
      // No skeleton needed if state has no variables either.
    }
  }

  /// Writes the build() method with the widget tree.
  void _writeBuildMethod(StringBuffer buffer, DartFileModel model) {
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');

    if (model.widgetTree != null) {
      buffer.writeln('    return ${_generateWidget(model.widgetTree!, 4)};');
    } else {
      buffer.writeln('    return const Placeholder();');
    }

    buffer.writeln('  }');
  }

  /// Recursively generates Dart code for a widget node.
  String _generateWidget(WidgetNode node, int indent) {
    final widgetName = node.displayName;

    // Special handling for known widgets.
    switch (node.name) {
      case 'Text':
        return _generateText(node, indent);
      case 'Icon':
        return _generateIcon(node, indent);
      case 'Image':
        return _generateImage(node, indent);
      case 'SizedBox':
        return _generateSizedBox(node, indent);
    }

    // Generic widget generation.
    return _generateGenericWidget(node, widgetName, indent);
  }

  /// Generates Text widget with TextStyle.
  String _generateText(WidgetNode node, int indent) {
    final textContent =
        node.properties['text'] ?? node.properties['value'] ?? '';
    final isLiteral =
        textContent.startsWith('"') || textContent.startsWith("'");
    final isStringLiteral = isLiteral || textContent.contains(' ');

    String textArg;
    if (isStringLiteral) {
      // Remove surrounding quotes if present, then re-add as single quotes.
      var clean = textContent;
      if (clean.startsWith('"') && clean.endsWith('"')) {
        clean = clean.substring(1, clean.length - 1);
      }
      textArg = "'$clean'";
    } else {
      textArg = textContent;
    }

    final styleArgs = <String>[];
    if (node.textStyle.containsKey('fontSize')) {
      styleArgs.add('fontSize: ${node.textStyle['fontSize']}');
    }
    if (node.textStyle.containsKey('fontWeight')) {
      final fw =
          reverseFontWeightShorthands[node.textStyle['fontWeight']] ??
          node.textStyle['fontWeight']!;
      styleArgs.add('fontWeight: $fw');
    }
    if (node.textStyle.containsKey('color')) {
      final color = expandColor(node.textStyle['color']!);
      styleArgs.add('color: $color');
    }

    // Extra style properties.
    for (final entry in node.textStyle.entries) {
      if (const {'fontSize', 'fontWeight', 'color'}.contains(entry.key))
        continue;
      styleArgs.add('${entry.key}: ${entry.value}');
    }

    final hasStyle = styleArgs.isNotEmpty;
    final isConst = isStringLiteral && !hasStyle && node.callbacks.isEmpty;

    final args = <String>[textArg];
    if (hasStyle) {
      final isStyleConst = !styleArgs.any((a) => !_isConstExpression(a));
      final constPrefix = isStyleConst ? 'const ' : '';
      args.add('style: ${constPrefix}TextStyle(${styleArgs.join(', ')})');
    }

    final prefix = isConst ? 'const ' : '';
    return '${prefix}Text(${args.join(', ')})';
  }

  /// Generates Icon widget.
  String _generateIcon(WidgetNode node, int indent) {
    final iconName =
        node.properties['icon'] ?? node.properties['value'] ?? 'help';
    final isConst = node.callbacks.isEmpty;
    final prefix = isConst ? 'const ' : '';
    return '${prefix}Icon(Icons.$iconName)';
  }

  /// Generates Image widget.
  String _generateImage(WidgetNode node, int indent) {
    final src = node.properties['src'] ?? node.properties['value'] ?? '';
    final constructor = node.constructor ?? 'asset';
    final args = <String>["'$src'"];

    // Dimensions.
    final width = node.properties['width'];
    final height = node.properties['height'];
    if (width != null) args.add('width: ${expandValue(width)}');
    if (height != null) args.add('height: ${expandValue(height)}');

    // Other properties.
    for (final entry in node.properties.entries) {
      if (const {'src', 'value', 'width', 'height'}.contains(entry.key))
        continue;
      final expandedKey = expandProperty(entry.key);
      args.add(
        '$expandedKey: ${_expandPropertyValue(expandedKey, entry.value)}',
      );
    }

    return 'Image.$constructor(${args.join(', ')})';
  }

  /// Generates SizedBox widget.
  String _generateSizedBox(WidgetNode node, int indent) {
    final args = <String>[];

    final height = node.properties['h'] ?? node.properties['height'];
    final width = node.properties['w'] ?? node.properties['width'];
    if (height != null) args.add('height: ${expandValue(height)}');
    if (width != null) args.add('width: ${expandValue(width)}');

    if (node.children.isNotEmpty) {
      final childCode = _generateWidget(node.children.first, indent + 2);
      args.add('child: $childCode');
    }

    final isConst = args.every(_isConstExpression) && node.children.isEmpty;
    final prefix = isConst ? 'const ' : '';
    return '${prefix}SizedBox(${args.join(', ')})';
  }

  /// Generates a generic widget with properties, callbacks, and children.
  String _generateGenericWidget(
    WidgetNode node,
    String widgetName,
    int indent,
  ) {
    final pad = ' ' * indent;
    final args = <String>[];

    // Alignment from parenthetical syntax.
    if (node.alignmentShorthand != null) {
      final alignment = resolveAlignment(node.name, node.alignmentShorthand!);
      if (alignment.mainAxis != null) {
        args.add('mainAxisAlignment: ${alignment.mainAxis}');
      }
      if (alignment.crossAxis != null) {
        args.add('crossAxisAlignment: ${alignment.crossAxis}');
      }
    }

    // Collect decoration properties for Container wrapping.
    final isContainer = node.name == 'Container';
    final decorationArgs = <String>[];

    // Properties — expand shorthands.
    for (final entry in node.properties.entries) {
      if (entry.key == 'value') continue;
      // Skip internal metadata keys (prefixed with _)
      if (entry.key.startsWith('_')) continue;

      // Handle spacing shorthands (p, px, py, m, mx, my).
      final spacingResult = _tryExpandSpacingShorthand(
        entry.key,
        entry.value,
        node,
      );
      if (spacingResult != null) {
        args.add(spacingResult);
        continue;
      }

      // For Container: collect bg, br, border, shadow, gradient into BoxDecoration.
      if (isContainer && _isDecorationProperty(entry.key)) {
        final decorArg = _expandDecorationProperty(entry.key, entry.value);
        if (decorArg != null) {
          decorationArgs.add(decorArg);
        }
        continue;
      }

      final expandedKey = expandProperty(entry.key);
      final expandedValue = _expandPropertyValue(expandedKey, entry.value);
      args.add('$expandedKey: $expandedValue');
    }

    // Emit collected decoration properties as a single BoxDecoration.
    if (decorationArgs.isNotEmpty) {
      args.add('decoration: BoxDecoration(${decorationArgs.join(', ')})');
    }

    // Callbacks with arrow notation.
    for (final entry in node.callbacks.entries) {
      final callbackValue = entry.value;
      if (callbackValue.contains('(') && callbackValue.contains(')')) {
        args.add('${entry.key}: () => $callbackValue');
      } else {
        args.add('${entry.key}: $callbackValue');
      }
    }

    // Children.
    if (node.children.length == 1) {
      final childKey = _inferChildKey(node);
      final childCode = _generateWidget(node.children.first, indent + 2);
      args.add('$childKey: $childCode');
    } else if (node.children.length > 1) {
      final childrenCode = node.children
          .map((child) {
            final childCode = _generateWidget(child, indent + 4);
            if (child.condition != null) {
              return '${pad}      if (${child.condition}) $childCode';
            }
            return '${pad}      $childCode';
          })
          .join(',\n');
      args.add('children: [\n$childrenCode,\n$pad    ]');
    }

    if (args.isEmpty) {
      return 'const $widgetName()';
    }

    // Determine formatting — single line or multi-line.
    final singleLine = '$widgetName(${args.join(', ')})';
    if (singleLine.length <= 80 && !singleLine.contains('\n')) {
      return singleLine;
    }

    // Multi-line format.
    final formattedArgs = args.map((arg) => '$pad  $arg').join(',\n');
    return '$widgetName(\n$formattedArgs,\n$pad)';
  }

  /// Tries to expand spacing shorthands (p, px, py, m, mx, my) into full Dart.
  /// Returns null if the key is not a spacing shorthand.
  String? _tryExpandSpacingShorthand(
    String key,
    String value,
    WidgetNode node,
  ) {
    final isPadding = key == 'p' || key == 'px' || key == 'py';
    final isMargin = key == 'm' || key == 'mx' || key == 'my';

    if (!isPadding && !isMargin) return null;

    final propName = isPadding ? 'padding' : 'margin';

    // Check for combined px + py on the same node.
    if (key == 'px' && node.properties.containsKey('py')) {
      final pyValue = node.properties['py']!;
      return '$propName: EdgeInsets.symmetric(horizontal: $value, vertical: $pyValue)';
    } else if (key == 'py' && node.properties.containsKey('px')) {
      // Skip — already handled when px was processed.
      return null;
    } else if (key == 'mx' && node.properties.containsKey('my')) {
      final myValue = node.properties['my']!;
      return '$propName: EdgeInsets.symmetric(horizontal: $value, vertical: $myValue)';
    } else if (key == 'my' && node.properties.containsKey('mx')) {
      return null;
    }

    switch (key) {
      case 'p':
      case 'm':
        if (value.startsWith('{') && value.endsWith('}')) {
          return '$propName: ${_expandSpacing(value)}';
        }
        return '$propName: EdgeInsets.all($value)';
      case 'px':
      case 'mx':
        return '$propName: EdgeInsets.symmetric(horizontal: $value)';
      case 'py':
      case 'my':
        return '$propName: EdgeInsets.symmetric(vertical: $value)';
      default:
        return null;
    }
  }

  /// Expands a property value based on the property name context.
  String _expandPropertyValue(String propertyName, String value) {
    // Handle special shorthands.
    if (propertyName == 'backgroundColor' || isColorProperty(propertyName)) {
      return expandColor(value);
    }

    if (propertyName == 'borderRadius') {
      return _expandBorderRadius(value);
    }

    if (value == 'full') return 'double.infinity';

    // Check for gradient syntax.
    if (value.startsWith('gradient(') && value.endsWith(')')) {
      return _expandGradient(value);
    }

    // Check for padding/margin shorthand.
    if (propertyName == 'padding' || propertyName == 'margin') {
      return _expandSpacing(value);
    }

    // Check for shadow shorthand.
    if (propertyName == 'shadow') {
      return _expandShadow(value);
    }

    // Check for dimension shorthand.
    final dim = parseDimension(value);
    if (dim != null) {
      return value; // Let caller handle splitting.
    }

    // Numeric values.
    if (double.tryParse(value) != null) return value;

    // Boolean values.
    if (value == 'true' || value == 'false') return value;

    return value;
  }

  /// Expands `gradient(blue, purple)` to LinearGradient.
  String _expandGradient(String value) {
    final content = value.substring(
      9,
      value.length - 1,
    ); // Remove gradient(...)
    final colors = content
        .split(',')
        .map((c) => expandColor(c.trim()))
        .toList();
    return 'LinearGradient(colors: [${colors.join(', ')}])';
  }

  /// Expands spacing shorthand to EdgeInsets.
  String _expandSpacing(String value) {
    if (value.startsWith('{') && value.endsWith('}')) {
      // EdgeInsets.only: {l: 8, t: 12}
      final content = value.substring(1, value.length - 1).trim();
      final parts = content.split(',').map((s) => s.trim()).toList();
      final namedArgs = parts
          .map((p) {
            final kv = p.split(':').map((s) => s.trim()).toList();
            final longName = _expandEdgeInsetKey(kv[0]);
            return '$longName: ${kv[1]}';
          })
          .join(', ');
      return 'EdgeInsets.only($namedArgs)';
    }
    return 'EdgeInsets.all($value)';
  }

  /// Expands EdgeInsets key abbreviations.
  String _expandEdgeInsetKey(String key) {
    switch (key) {
      case 'l':
        return 'left';
      case 'r':
        return 'right';
      case 't':
        return 'top';
      case 'b':
        return 'bottom';
      default:
        return key;
    }
  }

  /// Expands shadow shorthand to BoxShadow.
  /// Handles: `{c: black, blur: 3, offset: Offset(0, 1)}`
  /// Must respect commas inside nested parens like `Offset(0, 1)`.
  String _expandShadow(String value) {
    if (value.startsWith('{') && value.endsWith('}')) {
      final content = value.substring(1, value.length - 1).trim();
      final parts = _splitRespectingParens(content);
      final args = <String>[];
      for (final part in parts) {
        final colonIdx = part.indexOf(':');
        if (colonIdx < 0) continue;
        final key = part.substring(0, colonIdx).trim();
        final val = part.substring(colonIdx + 1).trim();
        switch (key) {
          case 'c':
            args.add('color: ${expandColor(val)}');
            break;
          case 'blur':
            args.add('blurRadius: $val');
            break;
          case 'spread':
            args.add('spreadRadius: $val');
            break;
          case 'offset':
            args.add('offset: $val');
            break;
          default:
            args.add('$key: $val');
        }
      }
      return '[BoxShadow(${args.join(', ')})]';
    }
    return value;
  }

  /// Splits a string by commas while respecting nested parens and braces.
  List<String> _splitRespectingParens(String input) {
    final results = <String>[];
    var depth = 0;
    var current = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '(' || char == '{') {
        depth++;
        current.write(char);
      } else if (char == ')' || char == '}') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        results.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) results.add(current.toString().trim());
    return results;
  }

  /// Expands a lifecycle action summary to Dart code.
  String _expandAction(String action) {
    // Handle Future.delayed(3s)
    if (action.startsWith('Future.delayed(') && action.endsWith(')')) {
      final durationStr = action.substring(15, action.length - 1);
      final expanded = expandDuration(durationStr);
      return 'Future.delayed(const $expanded, () {})';
    }

    // Handle navigate: pushReplacementNamed(...)
    if (action.startsWith('navigate: ')) {
      final navAction = action.substring(10);
      return 'Navigator.$navAction';
    }

    // Handle setState
    if (action == 'setState') {
      return 'setState(() {})';
    }

    return action;
  }

  /// Checks if a code expression is const-eligible.
  bool _isConstExpression(String expr) {
    // Simple heuristic: numeric literals and known const values.
    if (double.tryParse(expr) != null) return true;
    if (expr.contains('Colors.')) return true;
    if (expr.contains('FontWeight.')) return true;
    if (expr.contains('EdgeInsets.')) return true;
    if (expr.startsWith('height:') || expr.startsWith('width:')) return true;
    return false;
  }

  /// Infers child key based on widget type.
  String _inferChildKey(WidgetNode parent) {
    if (parent.name == 'Scaffold') return 'body';
    return 'child';
  }

  /// Properties that should be collected into BoxDecoration for Container.
  bool _isDecorationProperty(String key) {
    return const {'bg', 'br', 'border', 'shadow', 'gradient'}.contains(key);
  }

  /// Expands a decoration property into a named argument for BoxDecoration.
  String? _expandDecorationProperty(String key, String value) {
    switch (key) {
      case 'bg':
        return 'color: ${expandColor(value)}';
      case 'br':
        return 'borderRadius: ${_expandBorderRadius(value)}';
      case 'border':
        return 'border: ${_expandBorder(value)}';
      case 'shadow':
        return 'boxShadow: ${_expandShadow(value)}';
      case 'gradient':
        return 'gradient: ${_expandGradient(value)}';
      default:
        return null;
    }
  }

  /// Expands border radius — handles both uniform and per-corner syntax.
  /// Uniform: `12` → `BorderRadius.circular(12)`
  /// Per-corner: `{tl: 24, tr: 24, bl: 0, br: 0}` → `BorderRadius.only(...)`
  String _expandBorderRadius(String value) {
    if (value.startsWith('{') && value.endsWith('}')) {
      final content = value.substring(1, value.length - 1).trim();
      final parts = content.split(',').map((s) => s.trim()).toList();
      final namedArgs = <String>[];
      for (final part in parts) {
        final kv = part.split(':').map((s) => s.trim()).toList();
        if (kv.length != 2) continue;
        final radiusValue = kv[1];
        if (radiusValue == '0') continue; // Skip zero radii for cleaner output
        final cornerName = _expandBorderRadiusKey(kv[0]);
        namedArgs.add('$cornerName: Radius.circular($radiusValue)');
      }
      if (namedArgs.isEmpty) return 'BorderRadius.zero';
      return 'BorderRadius.only(${namedArgs.join(', ')})';
    }
    return 'BorderRadius.circular($value)';
  }

  /// Expands border radius key abbreviations.
  String _expandBorderRadiusKey(String key) {
    switch (key) {
      case 'tl':
        return 'topLeft';
      case 'tr':
        return 'topRight';
      case 'bl':
        return 'bottomLeft';
      case 'br':
        return 'bottomRight';
      default:
        return key;
    }
  }

  /// Expands border shorthand to Border.
  /// Formats: `{c: #121212}`, `{c: grey200, w: 1}`, `1 solid grey200`
  String _expandBorder(String value) {
    if (value.startsWith('{') && value.endsWith('}')) {
      final content = value.substring(1, value.length - 1).trim();
      final parts = content.split(',').map((s) => s.trim()).toList();
      String? color;
      String? width;
      for (final part in parts) {
        final kv = part.split(':').map((s) => s.trim()).toList();
        if (kv.length != 2) continue;
        switch (kv[0]) {
          case 'c':
            color = expandColor(kv[1]);
            break;
          case 'w':
            width = kv[1];
            break;
        }
      }
      final args = <String>[];
      if (color != null) args.add('color: $color');
      if (width != null) args.add('width: $width');
      return 'Border.all(${args.join(', ')})';
    }
    return value;
  }
}
