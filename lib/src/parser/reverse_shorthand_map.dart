/// Reverse shorthand dictionaries for YAML → Dart conversion.
///
/// Every abbreviation from the compact format mapped back to its
/// full Flutter/Dart equivalent.

/// Reverse property shorthands: YAML key → Dart property name.
const Map<String, String> reversePropertyShorthands = {
  'bg': 'backgroundColor',
  'br': 'borderRadius',
  'h': 'height',
  'w': 'width',
  'align': 'mainAxisAlignment',
  'crossAlign': 'crossAxisAlignment',
};

/// Reverse color shorthands: YAML color → Dart Colors.xxx.
const Map<String, String> reverseColorShorthands = {
  'white': 'Colors.white',
  'black': 'Colors.black',
  'red': 'Colors.red',
  'blue': 'Colors.blue',
  'green': 'Colors.green',
  'yellow': 'Colors.yellow',
  'orange': 'Colors.orange',
  'purple': 'Colors.purple',
  'pink': 'Colors.pink',
  'grey': 'Colors.grey',
  'teal': 'Colors.teal',
  'cyan': 'Colors.cyan',
  'amber': 'Colors.amber',
  'indigo': 'Colors.indigo',
  'brown': 'Colors.brown',
  'transparent': 'Colors.transparent',
  'black12': 'Colors.black12',
  'black26': 'Colors.black26',
  'black38': 'Colors.black38',
  'black45': 'Colors.black45',
  'black54': 'Colors.black54',
  'black87': 'Colors.black87',
  'white10': 'Colors.white10',
  'white12': 'Colors.white12',
  'white24': 'Colors.white24',
  'white30': 'Colors.white30',
  'white38': 'Colors.white38',
  'white54': 'Colors.white54',
  'white60': 'Colors.white60',
  'white70': 'Colors.white70',
  'grey100': 'Colors.grey[100]',
  'grey200': 'Colors.grey[200]',
  'grey300': 'Colors.grey[300]',
  'grey400': 'Colors.grey[400]',
  'grey500': 'Colors.grey[500]',
  'grey600': 'Colors.grey[600]',
  'grey700': 'Colors.grey[700]',
  'grey800': 'Colors.grey[800]',
  'grey900': 'Colors.grey[900]',
};

/// Reverse MainAxisAlignment shorthands.
const Map<String, String> reverseMainAxisShorthands = {
  'start': 'MainAxisAlignment.start',
  'end': 'MainAxisAlignment.end',
  'center': 'MainAxisAlignment.center',
  'spaceBetween': 'MainAxisAlignment.spaceBetween',
  'spaceAround': 'MainAxisAlignment.spaceAround',
  'spaceEvenly': 'MainAxisAlignment.spaceEvenly',
};

/// Reverse CrossAxisAlignment shorthands.
const Map<String, String> reverseCrossAxisShorthands = {
  'start': 'CrossAxisAlignment.start',
  'end': 'CrossAxisAlignment.end',
  'center': 'CrossAxisAlignment.center',
  'stretch': 'CrossAxisAlignment.stretch',
  'baseline': 'CrossAxisAlignment.baseline',
};

/// Reverse FontWeight shorthands.
const Map<String, String> reverseFontWeightShorthands = {
  'bold': 'FontWeight.bold',
  'normal': 'FontWeight.normal',
  'w100': 'FontWeight.w100',
  'w200': 'FontWeight.w200',
  'w300': 'FontWeight.w300',
  'w400': 'FontWeight.w400',
  'w500': 'FontWeight.w500',
  'w600': 'FontWeight.w600',
  'w700': 'FontWeight.w700',
  'w800': 'FontWeight.w800',
  'w900': 'FontWeight.w900',
};

/// State management package imports to add when detected.
const Map<String, String> stateManagementPackages = {
  'GetX': "package:get/get.dart",
  'Riverpod': "package:flutter_riverpod/flutter_riverpod.dart",
  'Bloc': "package:flutter_bloc/flutter_bloc.dart",
  'Provider': "package:provider/provider.dart",
  'MobX': "package:flutter_mobx/flutter_mobx.dart",
  'Redux': "package:flutter_redux/flutter_redux.dart",
};

/// CrossAxisAlignment-only shorthands — values that only make sense as cross axis.
const Set<String> crossAxisOnlyValues = {'start', 'end', 'stretch', 'baseline'};

/// MainAxisAlignment-only shorthands — values that only exist for main axis.
const Set<String> mainAxisOnlyValues = {
  'spaceBetween',
  'spaceAround',
  'spaceEvenly',
};

/// Expands a color shorthand to full Dart expression.
String expandColor(String colorValue) {
  if (reverseColorShorthands.containsKey(colorValue)) {
    return reverseColorShorthands[colorValue]!;
  }
  // Handle #RRGGBB → Color(0xFFRRGGBB)
  final hexMatch = RegExp(r'^#([0-9a-fA-F]{6})$');
  final match = hexMatch.firstMatch(colorValue);
  if (match != null) {
    return 'Color(0xFF${match.group(1)!.toUpperCase()})';
  }
  // Already a full expression (e.g., Colors.blue.shade200)
  if (colorValue.startsWith('Colors.') || colorValue.startsWith('Color(')) {
    return colorValue;
  }
  return 'Colors.$colorValue';
}

/// Expands a property shorthand key to full Dart name.
String expandProperty(String shortKey) {
  return reversePropertyShorthands[shortKey] ?? shortKey;
}

/// Expands a value shorthand (e.g., 'full' → 'double.infinity').
String expandValue(String value) {
  if (value == 'full') return 'double.infinity';
  return value;
}

/// Checks if a value looks like a color shorthand that needs expansion.
bool isColorValue(String value) {
  return reverseColorShorthands.containsKey(value) ||
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value);
}

/// Checks if a property is color-related.
bool isColorProperty(String property) {
  return const {
    'color',
    'backgroundColor',
    'bg',
    'foregroundColor',
    'shadowColor',
    'splashColor',
    'highlightColor',
    'hoverColor',
    'focusColor',
    'iconColor',
    'textColor',
  }.contains(property);
}

/// Parses a dimension shorthand like '200x200' into width and height.
/// Returns null if not a dimension pattern.
({String width, String height})? parseDimension(String value) {
  final match = RegExp(r'^(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)$').firstMatch(value);
  if (match != null) {
    return (width: match.group(1)!, height: match.group(2)!);
  }
  return null;
}

/// Parses a duration shorthand like '3s', '500ms' into Duration constructor.
String expandDuration(String value) {
  final match = RegExp(r'^(\d+)(ms|s|min|h|d)$').firstMatch(value);
  if (match == null) return value;

  final amount = match.group(1)!;
  final unit = match.group(2)!;

  switch (unit) {
    case 'ms':
      return 'Duration(milliseconds: $amount)';
    case 's':
      return 'Duration(seconds: $amount)';
    case 'min':
      return 'Duration(minutes: $amount)';
    case 'h':
      return 'Duration(hours: $amount)';
    case 'd':
      return 'Duration(days: $amount)';
    default:
      return value;
  }
}

/// Determines alignment type from a single shorthand value.
/// For Row/Column: mainAxis vs crossAxis disambiguation.
({String? mainAxis, String? crossAxis}) resolveAlignment(
  String widgetName,
  String shorthand,
) {
  final parts = shorthand.split(',').map((s) => s.trim()).toList();

  if (parts.length == 2) {
    return (
      mainAxis: reverseMainAxisShorthands[parts[0]],
      crossAxis: reverseCrossAxisShorthands[parts[1]],
    );
  }

  final value = parts[0];

  // Unambiguous: only exists in one set.
  if (mainAxisOnlyValues.contains(value)) {
    return (mainAxis: reverseMainAxisShorthands[value], crossAxis: null);
  }

  // For Column(start)/Row(start) — 'start' as single value:
  // Column: cross-axis is more commonly specified alone.
  // But 'center' alone = mainAxis (most common use).
  if (widgetName == 'Column' || widgetName == 'Row') {
    if (value == 'start' || value == 'end' || value == 'stretch') {
      return (mainAxis: null, crossAxis: reverseCrossAxisShorthands[value]);
    }
    return (mainAxis: reverseMainAxisShorthands[value], crossAxis: null);
  }

  return (mainAxis: reverseMainAxisShorthands[value], crossAxis: null);
}
