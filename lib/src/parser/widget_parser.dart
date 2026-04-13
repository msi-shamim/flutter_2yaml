import '../models/widget_node.dart';
import 'pipe_parser.dart';

/// Parses the indented widget tree section of YAML into a [WidgetNode] hierarchy.
///
/// Uses a stack-based approach tracking indentation to determine parent-child
/// relationships. Handles pipe syntax, inline properties, arrow callbacks,
/// conditional prefixes, parenthetical alignment, and structural keys
/// (body:, child:, children:).
class WidgetParser {
  final PipeParser _pipeParser = PipeParser();

  /// Parses lines under `build:` into a root [WidgetNode].
  WidgetNode? parse(List<String> lines) {
    if (lines.isEmpty) return null;

    // Stack tracks (indent, node) pairs for building the tree.
    final stack = <({int indent, WidgetNode node})>[];
    WidgetNode? root;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final indent = _getIndent(line);
      final trimmed = line.trim();

      // Skip structural keys — they just indicate nesting direction.
      if (_isStructuralKey(trimmed)) continue;

      // Check if this is a property line (arrow callback or key: value for existing widget).
      if (stack.isNotEmpty && _isPropertyLine(trimmed, indent, stack)) {
        _applyProperty(trimmed, stack.last.node);
        continue;
      }

      // Parse as a widget node.
      final node = _parseWidgetLine(trimmed);
      if (node == null) continue;

      if (root == null) {
        root = node;
        stack.add((indent: indent, node: node));
        continue;
      }

      // Pop stack until we find the parent (widget with smaller indent).
      while (stack.length > 1 && stack.last.indent >= indent) {
        stack.removeLast();
      }

      // Add as child of the current top of stack.
      if (stack.isNotEmpty) {
        stack.last.node.children.add(node);
      }

      stack.add((indent: indent, node: node));
    }

    return root;
  }

  /// Checks if a line is a structural key (body:, child:, children:).
  bool _isStructuralKey(String trimmed) {
    return trimmed == 'body:' || trimmed == 'child:' || trimmed == 'children:';
  }

  /// Determines if a line is a property of the current widget (not a new child widget).
  bool _isPropertyLine(
    String trimmed,
    int indent,
    List<({int indent, WidgetNode node})> stack,
  ) {
    // Arrow callback: `onPressed → handleTap`
    if (trimmed.contains('→')) return true;

    // List item: `- Something` — this is a child, not a property.
    if (trimmed.startsWith('- ')) return false;

    // Extract key before colon.
    final colonIdx = _findColon(trimmed);
    if (colonIdx < 0) return false;

    final key = trimmed.substring(0, colonIdx).trim();

    // If key starts with uppercase, it's a widget (not a property).
    if (key.isNotEmpty &&
        key[0] == key[0].toUpperCase() &&
        key[0] != key[0].toLowerCase()) {
      // Could be a widget like `Center:` or `Column(center):`
      return false;
    }

    // If the key starts with 'if ', it's a conditional child.
    if (key.startsWith('if ')) return false;

    // Lowercase key → property of the parent widget.
    return true;
  }

  /// Applies a property or callback to a widget node.
  void _applyProperty(String trimmed, WidgetNode node) {
    // Arrow callback: `onPressed → handleTap`
    if (trimmed.contains('→')) {
      final parts = trimmed.split('→').map((s) => s.trim()).toList();
      if (parts.length == 2) {
        node.callbacks[parts[0]] = parts[1];
      }
      return;
    }

    // Key: value property.
    final colonIdx = _findColon(trimmed);
    if (colonIdx > 0) {
      final key = trimmed.substring(0, colonIdx).trim();
      final value = trimmed.substring(colonIdx + 1).trim();

      if (key == 'p' ||
          key == 'px' ||
          key == 'py' ||
          key == 'm' ||
          key == 'mx' ||
          key == 'my') {
        node.properties[key] = value;
      } else {
        node.properties[key] = value;
      }
    }
  }

  /// Parses a single line into a WidgetNode.
  WidgetNode? _parseWidgetLine(String line) {
    var trimmed = line;

    // Remove list marker.
    if (trimmed.startsWith('- ')) {
      trimmed = trimmed.substring(2);
    }

    // Check for conditional prefix: `if _isLoading: WidgetName: ...`
    String? condition;
    if (trimmed.startsWith('if ')) {
      final condMatch = RegExp(r'^if\s+(\S+):\s*(.+)$').firstMatch(trimmed);
      if (condMatch != null) {
        condition = condMatch.group(1);
        trimmed = condMatch.group(2)!;
      }
    }

    // Find the widget colon.
    final colonIdx = _findColon(trimmed);
    if (colonIdx < 0) return null;

    var widgetPart = trimmed.substring(0, colonIdx).trim();
    final valuePart = trimmed.substring(colonIdx + 1).trim();

    // Extract parenthetical alignment: `Column(center)` → Column + alignment.
    String? alignmentShorthand;
    final parenMatch = RegExp(r'^(\w+)\(([^)]+)\)$').firstMatch(widgetPart);
    if (parenMatch != null) {
      widgetPart = parenMatch.group(1)!;
      alignmentShorthand = parenMatch.group(2);
    }

    // Extract constructor: `Image.asset` → Image + asset.
    String widgetName;
    String? constructor;
    if (widgetPart.contains('.')) {
      final parts = widgetPart.split('.');
      widgetName = parts[0];
      constructor = parts.sublist(1).join('.');
    } else {
      widgetName = widgetPart;
    }

    // Determine what's after the colon.
    WidgetNode node;

    if (valuePart.isEmpty) {
      // Multi-line widget — properties/children follow on next lines.
      node = WidgetNode(
        name: widgetName,
        constructor: constructor,
        condition: condition,
        alignmentShorthand: alignmentShorthand,
      );
    } else if (valuePart.startsWith('{') && valuePart.endsWith('}')) {
      // Inline properties: `SizedBox: { h: 20 }`
      node = _pipeParser.parse(widgetName, constructor, valuePart);
      node = _rebuildNode(
        node,
        condition: condition,
        alignmentShorthand: alignmentShorthand,
      );
    } else if (_isPipeWidget(widgetName)) {
      // Pipe syntax: `Text: "Hello" | 20 | bold`
      node = _pipeParser.parse(widgetName, constructor, valuePart);
      node = _rebuildNode(
        node,
        condition: condition,
        alignmentShorthand: alignmentShorthand,
      );
    } else {
      // Value or unknown.
      node = WidgetNode(
        name: widgetName,
        constructor: constructor,
        condition: condition,
        alignmentShorthand: alignmentShorthand,
      );
      if (valuePart.isNotEmpty) {
        node.properties['value'] = valuePart;
      }
    }

    return node;
  }

  /// Rebuilds a node with additional metadata (condition, alignment).
  WidgetNode _rebuildNode(
    WidgetNode source, {
    String? condition,
    String? alignmentShorthand,
  }) {
    return WidgetNode(
      name: source.name,
      constructor: source.constructor,
      properties: source.properties,
      callbacks: source.callbacks,
      textStyle: source.textStyle,
      condition: condition ?? source.condition,
      alignmentShorthand: alignmentShorthand ?? source.alignmentShorthand,
    );
  }

  /// Finds the first colon in a line that separates key from value.
  int _findColon(String line) {
    for (var i = 0; i < line.length; i++) {
      if (line[i] == ':') {
        if (i == line.length - 1 || line[i + 1] == ' ') {
          return i;
        }
      }
    }
    return -1;
  }

  /// Checks if a widget supports pipe syntax.
  bool _isPipeWidget(String name) {
    return const {'Text', 'Image', 'Icon', 'SizedBox'}.contains(name);
  }

  /// Gets the indentation level (number of leading spaces).
  int _getIndent(String line) {
    var count = 0;
    for (final char in line.codeUnits) {
      if (char == 0x20) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}
