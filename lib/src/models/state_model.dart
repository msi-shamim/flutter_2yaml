/// Represents a state variable declared in a StatefulWidget's State class.
class StateVariable {
  /// Variable name (e.g., '_isLoading').
  final String name;

  /// Dart type (e.g., 'bool', 'String', 'TextEditingController').
  final String type;

  /// Default/initial value if assigned inline (e.g., 'true', '""').
  final String? defaultValue;

  StateVariable({required this.name, required this.type, this.defaultValue});
}

/// Represents a lifecycle or custom method in the State class.
class MethodSummary {
  /// Method name (e.g., 'initState', 'dispose', '_handleTap').
  final String name;

  /// Compact summary of what the method does (e.g., 'navigate: pushNamed("/home")').
  final List<String> actions;

  /// Method parameters as a string (e.g., '(String value)').
  final String? parameters;

  /// Return type (e.g., 'void', 'Future<void>').
  final String returnType;

  MethodSummary({
    required this.name,
    List<String>? actions,
    this.parameters,
    this.returnType = 'void',
  }) : actions = actions ?? [];
}

/// Detected state management pattern information.
class StateManagementInfo {
  /// The framework type: 'GetX', 'Riverpod', 'Bloc', 'Provider', 'MobX', etc.
  final String type;

  /// The controller/provider/bloc class name (e.g., 'HomeController').
  final String? controllerName;

  StateManagementInfo({required this.type, this.controllerName});
}

/// Aggregated state information for a StatefulWidget's State class.
class StateModel {
  /// All declared state variables.
  final List<StateVariable> variables;

  /// Lifecycle methods (initState, dispose, didChangeDependencies, etc.).
  final List<MethodSummary> lifecycleMethods;

  /// Custom methods defined in the State class.
  final List<MethodSummary> customMethods;

  StateModel({
    List<StateVariable>? variables,
    List<MethodSummary>? lifecycleMethods,
    List<MethodSummary>? customMethods,
  }) : variables = variables ?? [],
       lifecycleMethods = lifecycleMethods ?? [],
       customMethods = customMethods ?? [];
}
