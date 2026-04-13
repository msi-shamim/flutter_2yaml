import '../models/widget_node.dart';
import 'reverse_shorthand_map.dart';

/// Parses pipe-syntax widget lines into [WidgetNode] instances.
///
/// Handles Text, Image, Icon, and SizedBox compact formats:
/// - `Text: "Hello" | 20 | bold | white`
/// - `Image.asset: logo.png | 200x200`
/// - `Icon: search | onTap → method()`
/// - `SizedBox: { h: 20 }`
class PipeParser {
  /// Parses a widget value string (everything after `WidgetName: `).
  ///
  /// [widgetName] is the base widget name (e.g., 'Text', 'Image').
  /// [constructor] is the named constructor if any (e.g., 'asset').
  /// [valueStr] is the raw value string after the colon.
  WidgetNode parse(String widgetName, String? constructor, String valueStr) {
    switch (widgetName) {
      case 'Text':
        return _parseText(valueStr);
      case 'Image':
        return _parseImage(constructor, valueStr);
      case 'Icon':
        return _parseIcon(valueStr);
      case 'SizedBox':
        return _parseSizedBox(valueStr);
      default:
        return _parseGenericInline(widgetName, constructor, valueStr);
    }
  }

  /// Parses Text pipe syntax: `"Hello" | 20 | bold | white`
  WidgetNode _parseText(String valueStr) {
    final parts = valueStr.split('|').map((s) => s.trim()).toList();
    final node = WidgetNode(name: 'Text');

    if (parts.isEmpty) return node;

    // First part is always the text content.
    final textContent = parts[0];
    node.properties['text'] = textContent;

    // Remaining parts: fontSize, fontWeight, color (in order).
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];

      // Check for key: value format (extra properties).
      if (part.contains(':')) {
        final kvParts = part.split(':').map((s) => s.trim()).toList();
        if (kvParts.length == 2) {
          node.properties[kvParts[0]] = kvParts[1];
        }
        continue;
      }

      // Try to determine what this pipe part represents.
      if (_isNumeric(part)) {
        node.textStyle['fontSize'] = part;
      } else if (reverseFontWeightShorthands.containsKey(part)) {
        node.textStyle['fontWeight'] = part;
      } else if (isColorValue(part) ||
          reverseColorShorthands.containsKey(part)) {
        node.textStyle['color'] = part;
      } else {
        // Unknown — treat as extra property or style.
        node.textStyle[part] = part;
      }
    }

    return node;
  }

  /// Parses Image pipe syntax: `logo.png | 200x200 | fit: cover`
  WidgetNode _parseImage(String? constructor, String valueStr) {
    final parts = valueStr.split('|').map((s) => s.trim()).toList();
    final node = WidgetNode(name: 'Image', constructor: constructor);

    if (parts.isEmpty) return node;

    // First part is the source.
    node.properties['src'] = parts[0];

    // Remaining parts.
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      final dim = parseDimension(part);
      if (dim != null) {
        node.properties['width'] = dim.width;
        node.properties['height'] = dim.height;
      } else if (part.contains(':')) {
        final kvParts = part.split(':').map((s) => s.trim()).toList();
        if (kvParts.length == 2) {
          node.properties[kvParts[0]] = kvParts[1];
        }
      }
    }

    return node;
  }

  /// Parses Icon syntax: `search | onTap → method()`
  WidgetNode _parseIcon(String valueStr) {
    final parts = valueStr.split('|').map((s) => s.trim()).toList();
    final node = WidgetNode(name: 'Icon');

    if (parts.isEmpty) return node;

    node.properties['icon'] = parts[0];

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.contains('→')) {
        final arrowParts = part.split('→').map((s) => s.trim()).toList();
        if (arrowParts.length == 2) {
          node.callbacks[arrowParts[0]] = arrowParts[1];
        }
      }
    }

    return node;
  }

  /// Parses SizedBox inline: `{ h: 20 }` or `{ w: 10, h: 20 }`
  WidgetNode _parseSizedBox(String valueStr) {
    final node = WidgetNode(name: 'SizedBox');
    final props = parseInlineProperties(valueStr);
    node.properties.addAll(props);
    return node;
  }

  /// Parses a generic inline widget: `{ key: value, key2: value2 }`
  WidgetNode _parseGenericInline(
    String widgetName,
    String? constructor,
    String valueStr,
  ) {
    final node = WidgetNode(name: widgetName, constructor: constructor);
    final trimmed = valueStr.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final props = parseInlineProperties(trimmed);
      node.properties.addAll(props);
    } else {
      // Single value property.
      node.properties['value'] = trimmed;
    }

    return node;
  }

  /// Parses compact inline properties: `{ h: 20, w: 10, bg: white }`
  static Map<String, String> parseInlineProperties(String inlineStr) {
    final props = <String, String>{};
    var content = inlineStr.trim();

    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}'))
      content = content.substring(0, content.length - 1);
    content = content.trim();

    if (content.isEmpty) return props;

    // Split by comma, but respect nested braces.
    final entries = _splitRespectingBraces(content, ',');

    for (final entry in entries) {
      final colonIndex = entry.indexOf(':');
      if (colonIndex > 0) {
        final key = entry.substring(0, colonIndex).trim();
        final value = entry.substring(colonIndex + 1).trim();
        props[key] = value;
      }
    }

    return props;
  }

  /// Splits a string by delimiter while respecting nested braces.
  static List<String> _splitRespectingBraces(String input, String delimiter) {
    final results = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '{') {
        depth++;
        current.write(char);
      } else if (char == '}') {
        depth--;
        current.write(char);
      } else if (char == delimiter[0] && depth == 0) {
        results.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      results.add(current.toString());
    }

    return results;
  }

  bool _isNumeric(String s) {
    return double.tryParse(s) != null;
  }
}
