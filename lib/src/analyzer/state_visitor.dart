import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/state_model.dart';

/// AST visitor that extracts state information from a Flutter State class.
///
/// Captures state variables, lifecycle methods (initState, dispose, etc.),
/// and custom methods with their action summaries.
class StateVisitor extends RecursiveAstVisitor<void> {
  final List<StateVariable> _variables = [];
  final List<MethodSummary> _lifecycleMethods = [];
  final List<MethodSummary> _customMethods = [];

  static const _lifecycleMethodNames = {
    'initState',
    'dispose',
    'didChangeDependencies',
    'didUpdateWidget',
    'deactivate',
    'reassemble',
  };

  static const _skippedMethods = {'build', 'createState'};

  /// The aggregated state model after visiting.
  StateModel get stateModel => StateModel(
    variables: _variables,
    lifecycleMethods: _lifecycleMethods,
    customMethods: _customMethods,
  );

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // Skip static fields.
    if (node.isStatic) return;

    for (final variable in node.fields.variables) {
      final variableName = variable.name.lexeme;
      final variableType =
          node.fields.type?.toSource() ?? _inferType(variable.initializer);
      final defaultValue = variable.initializer?.toSource();

      _variables.add(
        StateVariable(
          name: variableName,
          type: variableType,
          defaultValue: defaultValue,
        ),
      );
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final methodName = node.name.lexeme;

    // Skip build() and createState() — handled separately.
    if (_skippedMethods.contains(methodName)) return;

    final actions = _extractMethodActions(node);
    final parameters = _extractParameters(node);
    final returnType = node.returnType?.toSource() ?? 'void';

    final methodSummary = MethodSummary(
      name: methodName,
      actions: actions,
      parameters: parameters,
      returnType: returnType,
    );

    if (_lifecycleMethodNames.contains(methodName)) {
      _lifecycleMethods.add(methodSummary);
    } else {
      _customMethods.add(methodSummary);
    }
  }

  /// Extracts compact action descriptions from a method body.
  List<String> _extractMethodActions(MethodDeclaration node) {
    final actions = <String>[];
    final body = node.body;

    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        final action = _summarizeStatement(statement);
        if (action != null) {
          actions.add(action);
        }
      }
    } else if (body is ExpressionFunctionBody) {
      final action = _summarizeExpression(body.expression);
      if (action != null) {
        actions.add(action);
      }
    }

    return actions;
  }

  /// Produces a one-line summary of a statement.
  String? _summarizeStatement(Statement statement) {
    if (statement is ExpressionStatement) {
      return _summarizeExpression(statement.expression);
    } else if (statement is VariableDeclarationStatement) {
      return _summarizeVariableDeclaration(statement);
    } else if (statement is ReturnStatement) {
      return 'return';
    } else if (statement is IfStatement) {
      return 'conditional logic';
    } else if (statement is ForStatement) {
      return 'loop';
    }
    return null;
  }

  /// Produces a one-line summary of an expression.
  String? _summarizeExpression(Expression expression) {
    if (expression is MethodInvocation) {
      return _summarizeMethodInvocation(expression);
    } else if (expression is AssignmentExpression) {
      return _summarizeAssignment(expression);
    } else if (expression is FunctionExpression) {
      return 'callback';
    }
    return null;
  }

  /// Summarizes a method invocation into a compact action string.
  String? _summarizeMethodInvocation(MethodInvocation invocation) {
    final methodName = invocation.methodName.name;
    final target = invocation.target;

    // Detect super.initState(), super.dispose() — skip as boilerplate.
    if (target is SuperExpression) {
      return null;
    }

    // Detect setState calls.
    if (methodName == 'setState') {
      return 'setState';
    }

    // Detect Navigator calls.
    if (target is SimpleIdentifier && target.name == 'Navigator') {
      final args = invocation.argumentList.arguments;
      if (args.isNotEmpty) {
        final firstArg = args.length > 1 ? args[1] : args[0];
        return 'navigate: $methodName(${_compactArg(firstArg)})';
      }
      return 'navigate: $methodName';
    }

    // Detect Future.delayed.
    if (target is SimpleIdentifier && target.name == 'Future') {
      if (methodName == 'delayed') {
        final delayArg = _extractDuration(invocation.argumentList);
        return 'Future.delayed($delayArg)';
      }
    }

    // Detect controller/service calls.
    if (target != null) {
      return '${target.toSource()}.$methodName(...)';
    }

    return '$methodName(...)';
  }

  /// Summarizes an assignment expression.
  String? _summarizeAssignment(AssignmentExpression expression) {
    final left = expression.leftHandSide.toSource();
    return 'set $left';
  }

  /// Summarizes a variable declaration.
  String? _summarizeVariableDeclaration(
    VariableDeclarationStatement statement,
  ) {
    final variables = statement.variables.variables;
    if (variables.isNotEmpty) {
      return 'declare ${variables.first.name.lexeme}';
    }
    return null;
  }

  /// Extracts a compact duration string from argument list.
  String _extractDuration(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is! NamedExpression) {
        if (arg is InstanceCreationExpression) {
          final typeName = arg.constructorName.type.name2.lexeme;
          if (typeName == 'Duration') {
            final durationArgs = arg.argumentList.arguments;
            for (final dArg in durationArgs) {
              if (dArg is NamedExpression) {
                final unit = dArg.name.label.name;
                final value = dArg.expression.toSource();
                final shortUnit = _shortenDurationUnit(unit);
                return '$value$shortUnit';
              }
            }
          }
        }
      }
    }
    return '?';
  }

  String _shortenDurationUnit(String unit) {
    switch (unit) {
      case 'milliseconds':
        return 'ms';
      case 'seconds':
        return 's';
      case 'minutes':
        return 'min';
      case 'hours':
        return 'h';
      case 'days':
        return 'd';
      default:
        return unit;
    }
  }

  String _compactArg(Expression arg) {
    if (arg is SimpleStringLiteral) return arg.value;
    return arg.toSource();
  }

  String? _extractParameters(MethodDeclaration node) {
    final params = node.parameters;
    if (params == null || params.parameters.isEmpty) return null;
    return params.toSource();
  }

  String _inferType(Expression? initializer) {
    if (initializer is BooleanLiteral) return 'bool';
    if (initializer is IntegerLiteral) return 'int';
    if (initializer is DoubleLiteral) return 'double';
    if (initializer is SimpleStringLiteral) return 'String';
    if (initializer is ListLiteral) return 'List';
    if (initializer is SetOrMapLiteral) return 'Map';
    return 'dynamic';
  }
}
