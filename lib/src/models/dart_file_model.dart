import 'state_model.dart';
import 'widget_node.dart';

export 'state_model.dart' show StateManagementInfo;

/// The verbosity level for YAML output generation.
enum VerbosityLevel {
  /// Widget tree only — build method hierarchy and properties.
  minimal,

  /// Widgets + state variables, controllers, lifecycle methods.
  standard,

  /// Everything: imports, constructors, all methods, widget tree.
  full,
}

/// The type of Flutter widget class detected in the .dart file.
enum WidgetType { statelessWidget, statefulWidget }

/// Represents a constructor parameter.
class ConstructorParam {
  /// Parameter name (e.g., 'key', 'title').
  final String name;

  /// Parameter type (e.g., 'String', 'Key?').
  final String type;

  /// Whether the parameter is required.
  final bool isRequired;

  /// Default value if any (e.g., 'super.key').
  final String? defaultValue;

  ConstructorParam({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.defaultValue,
  });
}

/// Complete parsed representation of a Flutter .dart widget file.
///
/// This model captures all extractable information from a .dart file
/// and serves as the intermediate representation between AST parsing
/// and YAML generation.
class DartFileModel {
  /// Original source file name (e.g., 'splash_screen.dart').
  final String fileName;

  /// The widget class name (e.g., 'SplashScreen').
  final String className;

  /// Whether it's a StatelessWidget or StatefulWidget.
  final WidgetType widgetType;

  /// Import statements from the file.
  final List<String> imports;

  /// Constructor parameters of the widget class.
  final List<ConstructorParam> constructorParams;

  /// The parsed widget tree from the build() method.
  final WidgetNode? widgetTree;

  /// State information (only for StatefulWidget).
  final StateModel? stateModel;

  /// Mixins applied to the widget or state class.
  final List<String> mixins;

  /// Whether this widget is a page (has Scaffold) or a component widget.
  final bool isPage;

  /// Detected state management info (GetX, Riverpod, Bloc, Provider, etc.).
  final StateManagementInfo? stateManagement;

  /// Detected route path if found in code.
  final String? route;

  DartFileModel({
    required this.fileName,
    required this.className,
    required this.widgetType,
    List<String>? imports,
    List<ConstructorParam>? constructorParams,
    this.widgetTree,
    this.stateModel,
    List<String>? mixins,
    this.isPage = false,
    this.stateManagement,
    this.route,
  }) : imports = imports ?? [],
       constructorParams = constructorParams ?? [],
       mixins = mixins ?? [];
}
