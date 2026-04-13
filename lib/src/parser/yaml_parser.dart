import '../models/dart_file_model.dart';
import '../models/state_model.dart';
import '../models/widget_node.dart';
import 'widget_parser.dart';

/// Parses a Unified Compact Format YAML string into a [DartFileModel].
///
/// Reads the header, state, lifecycle, and build sections, then
/// delegates widget tree parsing to [WidgetParser].
class YamlParser {
  final WidgetParser _widgetParser = WidgetParser();

  /// Parses the given YAML [source] from a file named [fileName]
  /// and returns a [DartFileModel].
  DartFileModel parse(String source, String fileName) {
    final lines = source.split('\n');

    // Extract header fields.
    final className =
        _extractValue(lines, 'page') ??
        _extractValue(lines, 'widget') ??
        _classNameFromFile(fileName);
    final isPage = _hasKey(lines, 'page');
    final typeStr = _extractValue(lines, 'type') ?? 'StatelessWidget';
    final widgetType = typeStr == 'StatefulWidget'
        ? WidgetType.statefulWidget
        : WidgetType.statelessWidget;
    final route = _extractValue(lines, 'route');

    // Parse state management.
    final controllerLine = _extractValue(lines, 'controller');
    StateManagementInfo? stateManagement;
    if (controllerLine != null) {
      stateManagement = _parseController(controllerLine);
    } else {
      final smLine = _extractValue(lines, 'stateManagement');
      if (smLine != null) {
        stateManagement = StateManagementInfo(type: smLine);
      }
    }

    // Parse imports.
    final imports = _parseImports(lines);

    // Parse constructor.
    final constructorParams = _parseConstructor(lines);

    // Parse state variables.
    final stateVariables = _parseState(lines);

    // Parse lifecycle methods.
    final lifecycleMethods = _parseLifecycle(lines);

    // Build state model.
    StateModel? stateModel;
    if (widgetType == WidgetType.statefulWidget) {
      stateModel = StateModel(
        variables: stateVariables,
        lifecycleMethods: lifecycleMethods,
      );
    }

    // Parse widget tree.
    final buildLines = _extractSection(lines, 'build:');
    final widgetTree = _widgetParser.parse(buildLines);

    // Derive output file name.
    final dartFileName = fileName.replaceAll('.yaml', '.dart');

    return DartFileModel(
      fileName: dartFileName,
      className: className,
      widgetType: widgetType,
      imports: imports,
      constructorParams: constructorParams,
      widgetTree: widgetTree,
      stateModel: stateModel,
      isPage: isPage,
      stateManagement: stateManagement,
      route: route,
    );
  }

  /// Extracts the value for a top-level key like `page: SplashScreen`.
  String? _extractValue(List<String> lines, String key) {
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('$key:')) {
        final value = trimmed.substring(key.length + 1).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// Checks if a top-level key exists.
  bool _hasKey(List<String> lines, String key) {
    return lines.any((line) => line.trim().startsWith('$key:'));
  }

  /// Parses `controller: HomeController(GetX)` into StateManagementInfo.
  StateManagementInfo _parseController(String value) {
    final match = RegExp(r'^(\w+)\((\w+)\)$').firstMatch(value);
    if (match != null) {
      return StateManagementInfo(
        type: match.group(2)!,
        controllerName: match.group(1),
      );
    }
    return StateManagementInfo(type: value);
  }

  /// Parses imports section — either inline `[...]` or multi-line `- ...`.
  List<String> _parseImports(List<String> lines) {
    final importsValue = _extractValue(lines, 'imports');
    if (importsValue != null) {
      // Inline: `imports: [package:flutter/material.dart, ...]`
      if (importsValue.startsWith('[') && importsValue.endsWith(']')) {
        final content = importsValue.substring(1, importsValue.length - 1);
        return content
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [importsValue];
    }

    // Multi-line imports.
    final section = _extractSection(lines, 'imports:');
    return section
        .map((line) => line.trim())
        .where((line) => line.startsWith('- '))
        .map((line) => line.substring(2).trim())
        .toList();
  }

  /// Parses `constructor: { key: super, title: this }` into ConstructorParam list.
  List<ConstructorParam> _parseConstructor(List<String> lines) {
    final value = _extractValue(lines, 'constructor');
    if (value == null) return [];

    if (value.startsWith('{') && value.endsWith('}')) {
      final content = value.substring(1, value.length - 1).trim();
      final entries = content.split(',');
      return entries.map((entry) {
        final parts = entry.split(':').map((s) => s.trim()).toList();
        if (parts.length == 2) {
          final name = parts[0];
          final typeOrDefault = parts[1];
          return ConstructorParam(
            name: name,
            type: typeOrDefault == 'super' ? 'super' : typeOrDefault,
            isRequired: typeOrDefault != 'super',
            defaultValue: typeOrDefault == 'super' ? 'super.$name' : null,
          );
        }
        return ConstructorParam(name: parts[0], type: 'dynamic');
      }).toList();
    }

    return [];
  }

  /// Parses `state: [_isLoading: bool = true, count: int]`.
  List<StateVariable> _parseState(List<String> lines) {
    final value = _extractValue(lines, 'state');
    if (value == null) return [];

    if (value.startsWith('[') && value.endsWith(']')) {
      final content = value.substring(1, value.length - 1).trim();
      if (content.isEmpty) return [];

      final entries = content.split(',');
      return entries.map((entry) => _parseStateVariable(entry.trim())).toList();
    }

    // Multi-line state.
    final section = _extractSection(lines, 'state:');
    return section
        .map((line) => line.trim())
        .where((line) => line.startsWith('- '))
        .map((line) => _parseStateVariable(line.substring(2).trim()))
        .toList();
  }

  /// Parses a single state variable: `_isLoading: bool = true`.
  StateVariable _parseStateVariable(String entry) {
    // Format: `name: Type = defaultValue` or `name: Type`
    final equalsIndex = entry.indexOf('=');
    String? defaultValue;
    String nameAndType;

    if (equalsIndex > 0) {
      nameAndType = entry.substring(0, equalsIndex).trim();
      defaultValue = entry.substring(equalsIndex + 1).trim();
    } else {
      nameAndType = entry;
    }

    final colonIndex = nameAndType.indexOf(':');
    if (colonIndex > 0) {
      final name = nameAndType.substring(0, colonIndex).trim();
      final type = nameAndType.substring(colonIndex + 1).trim();
      return StateVariable(name: name, type: type, defaultValue: defaultValue);
    }

    return StateVariable(
      name: nameAndType.trim(),
      type: 'dynamic',
      defaultValue: defaultValue,
    );
  }

  /// Parses `lifecycle:` section into MethodSummary list.
  List<MethodSummary> _parseLifecycle(List<String> lines) {
    final section = _extractSection(lines, 'lifecycle:');
    if (section.isEmpty) return [];

    final methods = <MethodSummary>[];

    for (final line in section) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) continue; // Skip sub-items for now.

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex < 0) continue;

      final methodName = trimmed.substring(0, colonIndex).trim();
      final valueStr = trimmed.substring(colonIndex + 1).trim();

      List<String> actions;
      if (valueStr.startsWith('[') && valueStr.endsWith(']')) {
        final content = valueStr.substring(1, valueStr.length - 1).trim();
        actions = content.isEmpty
            ? []
            : content.split(',').map((s) => s.trim()).toList();
      } else {
        actions = [];
      }

      methods.add(MethodSummary(name: methodName, actions: actions));
    }

    return methods;
  }

  /// Extracts all indented lines under a top-level section key.
  List<String> _extractSection(List<String> lines, String sectionKey) {
    final result = <String>[];
    var inSection = false;
    var sectionIndent = -1;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed == sectionKey || trimmed.startsWith(sectionKey)) {
        // Check it's a top-level key (no or minimal indentation).
        final indent = _getIndent(line);
        if (indent <= 2) {
          inSection = true;
          sectionIndent = indent;
          continue;
        }
      }

      if (inSection) {
        if (line.trim().isEmpty) continue;

        final currentIndent = _getIndent(line);
        // If we hit a line at or before section level, section is over.
        if (currentIndent <= sectionIndent && line.trim().isNotEmpty) {
          // Check if this is a new top-level key.
          if (!line.trim().startsWith('-') && line.trim().contains(':')) {
            break;
          }
        }
        if (currentIndent > sectionIndent) {
          result.add(line);
        }
      }
    }

    return result;
  }

  /// Gets indentation level of a line.
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

  /// Derives a class name from a file name.
  String _classNameFromFile(String fileName) {
    final baseName = fileName.replaceAll('.yaml', '').replaceAll('.dart', '');
    return baseName
        .split('_')
        .map(
          (part) => part.isEmpty
              ? ''
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join();
  }
}
