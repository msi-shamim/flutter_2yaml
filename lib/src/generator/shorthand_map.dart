/// Centralized shorthand dictionaries for the compact YAML format.
///
/// All property abbreviations, callback names, color shorthands,
/// and pipe syntax ordering rules are defined here.

/// Maps verbose Flutter property names to compact shorthands.
const Map<String, String> propertyShorthands = {
  'backgroundColor': 'bg',
  'background': 'bg',
  'borderRadius': 'br',
  'height': 'h',
  'width': 'w',
  'mainAxisAlignment': 'align',
  'crossAxisAlignment': 'crossAlign',
  'spacing': 'gap',
  'runSpacing': 'runGap',
  'top': 't',
  'left': 'l',
  'right': 'r',
  'bottom': 'b',
};

/// Maps EdgeInsets patterns to compact CSS-like shorthands.
/// Detected during analysis and stored as shorthand in properties.
const Map<String, String> edgeInsetsShorthands = {
  'EdgeInsets.all': 'p',
  'EdgeInsets.symmetric(horizontal': 'px',
  'EdgeInsets.symmetric(vertical': 'py',
  'EdgeInsets.symmetric': 'p',
};

/// Recognizable callback property names that should use arrow notation.
const Set<String> callbackProperties = {
  'onTap',
  'onPressed',
  'onLongPress',
  'onDoubleTap',
  'onChanged',
  'onSubmitted',
  'onEditingComplete',
  'onSaved',
  'onFieldSubmitted',
  'onRefresh',
  'onDismissed',
  'onSelected',
  'onExpansionChanged',
  'onReorder',
  'onPageChanged',
  'onGenerateRoute',
  'onWillPop',
  'validator',
};

/// Maps `Colors.xxx` to short color names for compact output.
const Map<String, String> colorShorthands = {
  'Colors.white': 'white',
  'Colors.black': 'black',
  'Colors.red': 'red',
  'Colors.blue': 'blue',
  'Colors.green': 'green',
  'Colors.yellow': 'yellow',
  'Colors.orange': 'orange',
  'Colors.purple': 'purple',
  'Colors.pink': 'pink',
  'Colors.grey': 'grey',
  'Colors.teal': 'teal',
  'Colors.cyan': 'cyan',
  'Colors.amber': 'amber',
  'Colors.indigo': 'indigo',
  'Colors.brown': 'brown',
  'Colors.transparent': 'transparent',
  'Colors.black12': 'black12',
  'Colors.black26': 'black26',
  'Colors.black38': 'black38',
  'Colors.black45': 'black45',
  'Colors.black54': 'black54',
  'Colors.black87': 'black87',
  'Colors.white10': 'white10',
  'Colors.white12': 'white12',
  'Colors.white24': 'white24',
  'Colors.white30': 'white30',
  'Colors.white38': 'white38',
  'Colors.white54': 'white54',
  'Colors.white60': 'white60',
  'Colors.white70': 'white70',
  'Colors.grey100': 'grey100',
  'Colors.grey200': 'grey200',
  'Colors.grey300': 'grey300',
  'Colors.grey400': 'grey400',
  'Colors.grey500': 'grey500',
  'Colors.grey600': 'grey600',
  'Colors.grey700': 'grey700',
  'Colors.grey800': 'grey800',
  'Colors.grey900': 'grey900',
};

/// Maps MainAxisAlignment values to compact shorthand for parenthetical syntax.
const Map<String, String> mainAxisShorthands = {
  'MainAxisAlignment.start': 'start',
  'MainAxisAlignment.end': 'end',
  'MainAxisAlignment.center': 'center',
  'MainAxisAlignment.spaceBetween': 'spaceBetween',
  'MainAxisAlignment.spaceAround': 'spaceAround',
  'MainAxisAlignment.spaceEvenly': 'spaceEvenly',
  'center': 'center',
  'start': 'start',
  'end': 'end',
  'spaceBetween': 'spaceBetween',
  'spaceAround': 'spaceAround',
  'spaceEvenly': 'spaceEvenly',
};

/// Maps CrossAxisAlignment values to compact shorthand.
const Map<String, String> crossAxisShorthands = {
  'CrossAxisAlignment.start': 'start',
  'CrossAxisAlignment.end': 'end',
  'CrossAxisAlignment.center': 'center',
  'CrossAxisAlignment.stretch': 'stretch',
  'CrossAxisAlignment.baseline': 'baseline',
  'start': 'start',
  'end': 'end',
  'center': 'center',
  'stretch': 'stretch',
};

/// Maps FontWeight values to compact shorthand for pipe syntax.
const Map<String, String> fontWeightShorthands = {
  'FontWeight.bold': 'bold',
  'FontWeight.normal': 'normal',
  'FontWeight.w100': 'w100',
  'FontWeight.w200': 'w200',
  'FontWeight.w300': 'w300',
  'FontWeight.w400': 'w400',
  'FontWeight.w500': 'w500',
  'FontWeight.w600': 'w600',
  'FontWeight.w700': 'w700',
  'FontWeight.w800': 'w800',
  'FontWeight.w900': 'w900',
  'bold': 'bold',
  'normal': 'normal',
};

/// State management package import patterns for auto-detection.
const Map<String, String> stateManagementImports = {
  'package:get/': 'GetX',
  'package:get_it/': 'GetIt',
  'package:flutter_riverpod/': 'Riverpod',
  'package:hooks_riverpod/': 'Riverpod',
  'package:riverpod/': 'Riverpod',
  'package:flutter_bloc/': 'Bloc',
  'package:bloc/': 'Bloc',
  'package:provider/': 'Provider',
  'package:mobx/': 'MobX',
  'package:flutter_mobx/': 'MobX',
  'package:redux/': 'Redux',
  'package:flutter_redux/': 'Redux',
};

/// Widgets that use Scaffold indicate a "page" rather than a "widget".
const Set<String> pageIndicatorWidgets = {
  'Scaffold',
  'CupertinoPageScaffold',
  'MaterialApp',
  'CupertinoApp',
};

/// Widgets whose single-child key is 'body' instead of 'child'.
const Set<String> bodyChildWidgets = {'Scaffold', 'CupertinoPageScaffold'};

/// Properties that represent a value suitable for dimension shorthand (WxH).
const Set<String> dimensionProperties = {'width', 'height', 'w', 'h'};

/// Applies color shorthand: `Colors.blue` → `blue`, `Color(0xFF...)` → `#...`.
String shortenColor(String colorValue) {
  if (colorShorthands.containsKey(colorValue)) {
    return colorShorthands[colorValue]!;
  }
  // Handle Color(0xFFRRGGBB) → #RRGGBB
  final hexMatch = RegExp(r'Color\(0[xX][fF]{2}([0-9a-fA-F]{6})\)');
  final match = hexMatch.firstMatch(colorValue);
  if (match != null) {
    return '#${match.group(1)!}';
  }
  return colorValue;
}

/// Applies property shorthand: `backgroundColor` → `bg`, etc.
String shortenProperty(String propertyName) {
  return propertyShorthands[propertyName] ?? propertyName;
}

/// Checks if a property name is a callback.
bool isCallback(String propertyName) {
  return callbackProperties.contains(propertyName);
}
