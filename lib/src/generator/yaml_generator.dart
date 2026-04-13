import '../models/dart_file_model.dart';
import '../models/state_model.dart';
import '../models/widget_node.dart';

/// Generates compact YAML in the Unified Format from a [DartFileModel].
///
/// Uses pipe syntax, CSS-like shorthands, arrow notation, parenthetical
/// alignment, named children, spread/for elements, and ternary support.
class YamlGenerator {
  /// Generates YAML string from the given [model] at the specified [level].
  String generate(DartFileModel model, VerbosityLevel level) {
    final buffer = StringBuffer();

    _writeCompactHeader(buffer, model, level);

    if (level == VerbosityLevel.full) {
      _writeImports(buffer, model);
      _writeConstructor(buffer, model);
    }

    if (level != VerbosityLevel.minimal) {
      _writeCompactState(buffer, model);
      _writeLifecycle(
        buffer,
        model,
        includeCustomMethods: level == VerbosityLevel.full,
      );
    }

    _writeWidgetTree(buffer, model);

    return buffer.toString();
  }

  /// Writes the compact header.
  void _writeCompactHeader(
    StringBuffer buffer,
    DartFileModel model,
    VerbosityLevel level,
  ) {
    final kindLabel = model.isPage ? 'page' : 'widget';
    buffer.writeln('$kindLabel: ${model.className}');

    final typeLabel = model.widgetType == WidgetType.statefulWidget
        ? 'StatefulWidget'
        : 'StatelessWidget';
    buffer.writeln('type: $typeLabel');

    if (model.route != null) {
      buffer.writeln('route: ${model.route}');
    }

    if (model.stateManagement != null) {
      final sm = model.stateManagement!;
      if (sm.controllerName != null) {
        buffer.writeln('controller: ${sm.controllerName}(${sm.type})');
      } else {
        buffer.writeln('stateManagement: ${sm.type}');
      }
    }
  }

  /// Writes imports as a compact inline list (full level only).
  void _writeImports(StringBuffer buffer, DartFileModel model) {
    if (model.imports.isEmpty) return;
    if (model.imports.length == 1) {
      buffer.writeln('imports: [${model.imports.first}]');
    } else {
      buffer.writeln('imports:');
      for (final importUri in model.imports) {
        buffer.writeln('  - $importUri');
      }
    }
  }

  /// Writes constructor parameters (full level only).
  void _writeConstructor(StringBuffer buffer, DartFileModel model) {
    if (model.constructorParams.isEmpty) return;

    final paramEntries = <String>[];
    for (final param in model.constructorParams) {
      final defaultStr = param.defaultValue != null
          ? param.defaultValue!
          : param.type;
      paramEntries.add('${param.name}: $defaultStr');
    }

    buffer.writeln('constructor: { ${paramEntries.join(', ')} }');
  }

  /// Writes state variables as compact inline list.
  void _writeCompactState(StringBuffer buffer, DartFileModel model) {
    final stateModel = model.stateModel;
    if (stateModel == null || stateModel.variables.isEmpty) return;

    final varEntries = stateModel.variables.map((variable) {
      final defaultStr = variable.defaultValue != null
          ? ' = ${variable.defaultValue}'
          : '';
      return '${variable.name}: ${variable.type}$defaultStr';
    }).toList();

    if (varEntries.length <= 3) {
      buffer.writeln('state: [${varEntries.join(', ')}]');
    } else {
      buffer.writeln('state:');
      for (final entry in varEntries) {
        buffer.writeln('  - $entry');
      }
    }
  }

  /// Writes lifecycle and custom methods.
  void _writeLifecycle(
    StringBuffer buffer,
    DartFileModel model, {
    bool includeCustomMethods = false,
  }) {
    final stateModel = model.stateModel;
    if (stateModel == null) return;

    final hasLifecycle = stateModel.lifecycleMethods.isNotEmpty;
    final hasCustom =
        includeCustomMethods && stateModel.customMethods.isNotEmpty;

    if (!hasLifecycle && !hasCustom) return;

    buffer.writeln('lifecycle:');

    for (final method in stateModel.lifecycleMethods) {
      _writeMethodCompact(buffer, method);
    }

    if (hasCustom) {
      for (final method in stateModel.customMethods) {
        _writeMethodCompact(buffer, method);
      }
    }
  }

  /// Writes a method as a compact YAML entry.
  void _writeMethodCompact(StringBuffer buffer, MethodSummary method) {
    if (method.actions.isEmpty) {
      buffer.writeln('  ${method.name}: []');
    } else if (method.actions.length == 1) {
      buffer.writeln('  ${method.name}: [${method.actions.first}]');
    } else {
      buffer.writeln('  ${method.name}:');
      for (final action in method.actions) {
        buffer.writeln('    - $action');
      }
    }
  }

  /// Writes the widget tree from the build() method.
  void _writeWidgetTree(StringBuffer buffer, DartFileModel model) {
    if (model.widgetTree == null) return;
    buffer.writeln('build:');
    _writeWidgetNode(buffer, model.widgetTree!, indent: 2);
  }

  /// Recursively writes a widget node in compact format.
  void _writeWidgetNode(
    StringBuffer buffer,
    WidgetNode node, {
    required int indent,
  }) {
    final pad = ' ' * indent;

    // Check for special node types.
    if (node.name == '...') {
      buffer.writeln('$pad...${node.properties['spread'] ?? ''}');
      return;
    }

    if (node.name == 'for') {
      buffer.writeln('$pad- for(${node.properties['loop'] ?? ''}):');
      for (final child in node.children) {
        _writeWidgetNode(buffer, child, indent: indent + 4);
      }
      return;
    }

    // Check if this widget can use pipe syntax.
    final pipeLine = _tryPipeSyntax(node);
    if (pipeLine != null &&
        node.children.isEmpty &&
        node.namedChildren.isEmpty) {
      buffer.writeln('$pad$pipeLine');
      return;
    }

    // Widget name with optional alignment shorthand.
    final displayName = _formatWidgetName(node);

    // Leaf widget with few properties and no children → compact inline.
    if (node.children.isEmpty &&
        node.namedChildren.isEmpty &&
        node.callbacks.isEmpty &&
        node.properties.length <= 3 &&
        node.textStyle.isEmpty) {
      if (node.properties.isEmpty) {
        buffer.writeln('$pad$displayName: {}');
      } else {
        final propsStr = _compactProperties(node);
        buffer.writeln('$pad$displayName: { $propsStr }');
      }
      return;
    }

    // Multi-line format.
    buffer.writeln('$pad$displayName:');

    // Write properties.
    for (final entry in node.properties.entries) {
      buffer.writeln('$pad  ${entry.key}: ${entry.value}');
    }

    // Write callbacks with arrow notation.
    for (final entry in node.callbacks.entries) {
      buffer.writeln('$pad  ${entry.key} → ${entry.value}');
    }

    // Write named children (appBar, body, drawer, etc.).
    for (final entry in node.namedChildren.entries) {
      if (entry.key == 'else') continue; // Handled separately.
      buffer.writeln('$pad  ${entry.key}:');
      _writeWidgetNode(buffer, entry.value, indent: indent + 4);
    }

    // Write unnamed children list.
    if (node.children.isNotEmpty) {
      // If there's only one unnamed child and no named children used 'child/body',
      // determine if we need a 'children:' wrapper.
      if (node.children.length == 1 && !_hasNamedChildSlot(node)) {
        final childKey = _inferChildKey(node);
        if (!node.namedChildren.containsKey(childKey)) {
          buffer.writeln('$pad  $childKey:');
          _writeWidgetNode(buffer, node.children.first, indent: indent + 4);
        } else {
          // Already written via named children.
        }
      } else if (node.children.length > 1 ||
          (node.children.length == 1 && _hasNamedChildSlot(node))) {
        buffer.writeln('$pad  children:');
        for (final child in node.children) {
          _writeChildListItem(buffer, child, indent: indent + 4);
        }
      }
    }
  }

  /// Checks if a widget has its primary child already occupied by a named child.
  bool _hasNamedChildSlot(WidgetNode node) {
    final childKey = _inferChildKey(node);
    return node.namedChildren.containsKey(childKey);
  }

  /// Writes a child widget as a YAML list item.
  void _writeChildListItem(
    StringBuffer buffer,
    WidgetNode node, {
    required int indent,
  }) {
    final pad = ' ' * indent;

    // Handle special nodes.
    if (node.name == '...') {
      buffer.writeln('$pad- ...${node.properties['spread'] ?? ''}');
      return;
    }

    if (node.name == 'for') {
      buffer.writeln('$pad- for(${node.properties['loop'] ?? ''}):');
      for (final child in node.children) {
        _writeWidgetNode(buffer, child, indent: indent + 4);
      }
      return;
    }

    final conditionPrefix = node.condition != null
        ? 'if ${node.condition}: '
        : '';

    // Try pipe syntax for list items.
    final pipeLine = _tryPipeSyntax(node);
    if (pipeLine != null &&
        node.children.isEmpty &&
        node.namedChildren.isEmpty) {
      buffer.writeln('$pad- $conditionPrefix$pipeLine');
      // Write else branch if present.
      if (node.namedChildren.containsKey('else')) {
        final elseNode = node.namedChildren['else']!;
        final elsePipe = _tryPipeSyntax(elseNode);
        if (elsePipe != null) {
          buffer.writeln('$pad  else: $elsePipe');
        }
      }
      return;
    }

    final displayName = _formatWidgetName(node);

    // Compact leaf item.
    if (node.children.isEmpty &&
        node.namedChildren.isEmpty &&
        node.callbacks.isEmpty &&
        node.properties.length <= 3 &&
        node.textStyle.isEmpty) {
      if (node.properties.isEmpty) {
        buffer.writeln('$pad- $conditionPrefix$displayName: {}');
      } else {
        final propsStr = _compactProperties(node);
        buffer.writeln('$pad- $conditionPrefix$displayName: { $propsStr }');
      }
      return;
    }

    // Complex child.
    buffer.writeln('$pad- $displayName:');
    for (final entry in node.properties.entries) {
      buffer.writeln('$pad    ${entry.key}: ${entry.value}');
    }
    for (final entry in node.callbacks.entries) {
      buffer.writeln('$pad    ${entry.key} → ${entry.value}');
    }

    // Named children of this list item.
    for (final entry in node.namedChildren.entries) {
      if (entry.key == 'else') continue;
      buffer.writeln('$pad    ${entry.key}:');
      _writeWidgetNode(buffer, entry.value, indent: indent + 6);
    }

    if (node.children.length == 1 && !_hasNamedChildSlot(node)) {
      final childKey = _inferChildKey(node);
      buffer.writeln('$pad    $childKey:');
      _writeWidgetNode(buffer, node.children.first, indent: indent + 6);
    } else if (node.children.length > 1) {
      buffer.writeln('$pad    children:');
      for (final child in node.children) {
        _writeChildListItem(buffer, child, indent: indent + 6);
      }
    }
  }

  /// Formats the widget name with optional alignment shorthand.
  String _formatWidgetName(WidgetNode node) {
    final baseName = node.displayName;
    if (node.alignmentShorthand != null) {
      return '$baseName(${node.alignmentShorthand})';
    }
    return baseName;
  }

  /// Attempts to format a widget using pipe syntax.
  String? _tryPipeSyntax(WidgetNode node) {
    if (node.name == 'Text') return _formatTextPipe(node);
    if (node.name == 'Image') return _formatImagePipe(node);
    if (node.name == 'Icon') return _formatIconPipe(node);
    if (node.name == 'SizedBox' && node.children.isEmpty) {
      return _formatSizedBoxShorthand(node);
    }
    return null;
  }

  /// Formats Text widget with pipe syntax.
  String _formatTextPipe(WidgetNode node) {
    final text = node.properties['text'] ?? node.properties['value'] ?? '';
    final isVariable =
        !text.contains(' ') &&
        !text.startsWith('"') &&
        !text.startsWith("'") &&
        text.isNotEmpty;

    final displayText = isVariable ? text : '"$text"';

    final pipeParts = <String>[];

    final fontSize = node.textStyle['fontSize'];
    if (fontSize != null) pipeParts.add(fontSize);

    final fontWeight = node.textStyle['fontWeight'];
    if (fontWeight != null) pipeParts.add(fontWeight);

    final color = node.textStyle['color'];
    if (color != null) pipeParts.add(color);

    // Extra style properties that don't fit pipe order.
    final extraStyle = Map<String, String>.from(node.textStyle)
      ..remove('fontSize')
      ..remove('fontWeight')
      ..remove('color');

    final extraProps = Map<String, String>.from(node.properties)
      ..remove('text')
      ..remove('value')
      ..remove('style');

    if (pipeParts.isEmpty && extraStyle.isEmpty && extraProps.isEmpty) {
      return 'Text: $displayText';
    }

    final pipeStr = pipeParts.isNotEmpty ? ' | ${pipeParts.join(' | ')}' : '';

    if (extraProps.isNotEmpty || extraStyle.isNotEmpty) {
      final extras = <String>[];
      extras.addAll(extraProps.entries.map((e) => '${e.key}: ${e.value}'));
      extras.addAll(extraStyle.entries.map((e) => '${e.key}: ${e.value}'));
      return 'Text: $displayText$pipeStr | ${extras.join(', ')}';
    }

    return 'Text: $displayText$pipeStr';
  }

  /// Formats Image widget with pipe syntax.
  String _formatImagePipe(WidgetNode node) {
    final src = node.properties['src'] ?? node.properties['value'] ?? '';
    final constructor = node.constructor;
    final displayName = constructor != null ? 'Image.$constructor' : 'Image';

    final parts = <String>[];

    final size = node.properties['size'];
    final width = node.properties['w'] ?? node.properties['width'];
    final height = node.properties['h'] ?? node.properties['height'];

    if (size != null) {
      parts.add(size);
    } else if (width != null && height != null) {
      parts.add('${width}x$height');
    }

    final extraProps = Map<String, String>.from(node.properties)
      ..remove('src')
      ..remove('value')
      ..remove('size')
      ..remove('w')
      ..remove('width')
      ..remove('h')
      ..remove('height');

    for (final entry in extraProps.entries) {
      parts.add('${entry.key}: ${entry.value}');
    }

    final suffix = parts.isNotEmpty ? ' | ${parts.join(' | ')}' : '';
    return '$displayName: $src$suffix';
  }

  /// Formats Icon widget as compact form.
  String _formatIconPipe(WidgetNode node) {
    final icon = node.properties['icon'] ?? node.properties['value'] ?? '';
    final callbacks = node.callbacks.entries
        .map((e) => '${e.key} → ${e.value}')
        .join(' | ');
    final suffix = callbacks.isNotEmpty ? ' | $callbacks' : '';
    return 'Icon: $icon$suffix';
  }

  /// Formats SizedBox as compact shorthand.
  String _formatSizedBoxShorthand(WidgetNode node) {
    final height = node.properties['h'] ?? node.properties['height'];
    final width = node.properties['w'] ?? node.properties['width'];

    final parts = <String>[];
    if (width != null) parts.add('w: $width');
    if (height != null) parts.add('h: $height');

    if (parts.isEmpty) return 'SizedBox: {}';
    return 'SizedBox: { ${parts.join(', ')} }';
  }

  /// Formats properties as a compact inline YAML string.
  String _compactProperties(WidgetNode node) {
    return node.properties.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }

  /// Infers the child key name based on the parent widget type.
  String _inferChildKey(WidgetNode parent) {
    if (parent.name == 'Scaffold') return 'body';
    return 'child';
  }
}
