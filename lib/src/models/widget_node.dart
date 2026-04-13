/// Represents a single widget in the Flutter widget tree.
///
/// Each node captures the widget name, its properties (key-value pairs),
/// callbacks (arrow notation), named children (for Scaffold-style multi-child),
/// and any child widgets nested within it.
class WidgetNode {
  /// The widget class name (e.g., 'Scaffold', 'Column', 'Text').
  final String name;

  /// Constructor variant if applicable (e.g., 'asset' for Image.asset).
  final String? constructor;

  /// Widget properties as key-value pairs (e.g., {'color': 'blue'}).
  final Map<String, String> properties;

  /// Callback properties stored separately for arrow notation.
  final Map<String, String> callbacks;

  /// Ordered list of child widget nodes (unnamed children list).
  final List<WidgetNode> children;

  /// Named children for multi-child widgets like Scaffold.
  /// e.g., {'appBar': AppBarNode, 'drawer': DrawerNode, 'floatingActionButton': FABNode}
  final Map<String, WidgetNode> namedChildren;

  /// Conditional expression wrapping this widget (e.g., '_isLoading').
  final String? condition;

  /// TextStyle properties extracted for pipe syntax.
  final Map<String, String> textStyle;

  /// Alignment shorthand for parenthetical syntax.
  String? alignmentShorthand;

  /// Whether this widget contains a Scaffold (indicates a page-level widget).
  bool isPage;

  WidgetNode({
    required this.name,
    this.constructor,
    Map<String, String>? properties,
    Map<String, String>? callbacks,
    List<WidgetNode>? children,
    Map<String, WidgetNode>? namedChildren,
    this.condition,
    Map<String, String>? textStyle,
    this.alignmentShorthand,
    this.isPage = false,
  }) : properties = properties ?? {},
       callbacks = callbacks ?? {},
       children = children ?? [],
       namedChildren = namedChildren ?? {},
       textStyle = textStyle ?? {};

  /// Returns the display name including constructor (e.g., 'Image.asset').
  String get displayName => constructor != null ? '$name.$constructor' : name;
}
