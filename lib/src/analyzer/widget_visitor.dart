import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../generator/shorthand_map.dart';
import '../models/widget_node.dart';

/// Named child arguments — single widget assigned to a named slot.
/// These get stored in [WidgetNode.namedChildren] instead of generic properties.
const _namedChildArguments = {
  'child',
  'body',
  'home',
  'drawer',
  'endDrawer',
  'floatingActionButton',
  'bottomSheet',
  'appBar',
  'bottomNavigationBar',
  'leading',
  'title',
  'icon',
  'label',
  'background',
  'secondaryBackground',
  'header',
  'footer',
  'placeholder',
};

/// Children list arguments — multiple widgets in a list.
const _childrenListArguments = {
  'children',
  'actions',
  'tabs',
  'slivers',
  'items',
  'destinations',
};

/// AST visitor that extracts the widget tree from a Flutter build() method.
class WidgetVisitor extends RecursiveAstVisitor<void> {
  WidgetNode? _rootWidget;

  WidgetNode? get rootWidget => _rootWidget;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      final body = node.body;
      if (body is BlockFunctionBody) {
        for (final statement in body.block.statements) {
          if (statement is ReturnStatement && statement.expression != null) {
            _rootWidget = _extractWidget(statement.expression!);
          }
        }
      } else if (body is ExpressionFunctionBody) {
        _rootWidget = _extractWidget(body.expression);
      }
    }
  }

  /// Extracts a WidgetNode from an AST expression node.
  WidgetNode? _extractWidget(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return _extractFromConstructor(expression);
    } else if (expression is MethodInvocation) {
      return _extractFromMethodInvocation(expression);
    } else if (expression is ConditionalExpression) {
      return _extractTernary(expression);
    } else if (expression is PrefixedIdentifier) {
      return WidgetNode(
        name: expression.prefix.name,
        constructor: expression.identifier.name,
      );
    }
    return null;
  }

  /// Extracts a ternary expression: `condition ? WidgetA : WidgetB`.
  WidgetNode? _extractTernary(ConditionalExpression expression) {
    final condition = _extractPropertyValue(expression.condition);
    final thenWidget = _extractWidget(expression.thenExpression);
    if (thenWidget == null) return null;

    final elseWidget = _extractWidget(expression.elseExpression);

    // Create a conditional wrapper node.
    final node = WidgetNode(
      name: thenWidget.name,
      constructor: thenWidget.constructor,
      properties: thenWidget.properties,
      callbacks: thenWidget.callbacks,
      children: thenWidget.children,
      namedChildren: thenWidget.namedChildren,
      textStyle: thenWidget.textStyle,
      alignmentShorthand: thenWidget.alignmentShorthand,
      condition: condition,
    );

    // Store else branch as a named child if it exists.
    if (elseWidget != null) {
      node.namedChildren['else'] = elseWidget;
    }

    return node;
  }

  /// Extracts widget from a const constructor call.
  WidgetNode? _extractFromConstructor(InstanceCreationExpression expression) {
    final constructorName = expression.constructorName;
    final typeSource = constructorName.type.toSource();

    String typeName;
    String? namedConstructor;

    if (typeSource.contains('.')) {
      final parts = typeSource.split('.');
      typeName = parts.first;
      namedConstructor = parts.sublist(1).join('.');
    } else {
      typeName = typeSource;
      if (constructorName.name != null) {
        namedConstructor = constructorName.name!.name;
      }
    }

    final widgetNode = WidgetNode(
      name: typeName,
      constructor: namedConstructor,
    );

    _extractArguments(expression.argumentList, widgetNode);
    _applyPostProcessing(widgetNode);
    return widgetNode;
  }

  /// Extracts widget from a method invocation.
  WidgetNode? _extractFromMethodInvocation(MethodInvocation expression) {
    final target = expression.target;
    final methodName = expression.methodName.name;

    if (target == null) {
      final widgetNode = WidgetNode(name: methodName);
      _extractArguments(expression.argumentList, widgetNode);
      _applyPostProcessing(widgetNode);
      return widgetNode;
    }

    if (target is SimpleIdentifier) {
      final widgetNode = WidgetNode(name: target.name, constructor: methodName);
      _extractArguments(expression.argumentList, widgetNode);
      _applyPostProcessing(widgetNode);
      return widgetNode;
    }

    return null;
  }

  /// Post-processes a widget node to apply all shorthands.
  void _applyPostProcessing(WidgetNode widgetNode) {
    _extractAlignmentShorthand(widgetNode);
    _extractDimensionShorthand(widgetNode);
    _applyColorShorthands(widgetNode);
    _applyPropertyShorthands(widgetNode);
    _detectPageWidget(widgetNode);
  }

  /// Extracts parenthetical alignment shorthand for Row/Column/Wrap.
  void _extractAlignmentShorthand(WidgetNode node) {
    final name = node.name;
    if (name != 'Row' && name != 'Column' && name != 'Wrap') return;

    String? mainAxis = node.properties.remove('mainAxisAlignment');
    String? crossAxis = node.properties.remove('crossAxisAlignment');

    if (mainAxis != null) {
      final shortMain = mainAxisShorthands[mainAxis] ?? mainAxis;
      if (crossAxis != null) {
        final shortCross = crossAxisShorthands[crossAxis] ?? crossAxis;
        node.alignmentShorthand = '$shortMain, $shortCross';
      } else {
        node.alignmentShorthand = shortMain;
      }
    } else if (crossAxis != null) {
      final shortCross = crossAxisShorthands[crossAxis] ?? crossAxis;
      node.alignmentShorthand = shortCross;
    }
  }

  /// Detects and merges width+height into dimension shorthand.
  void _extractDimensionShorthand(WidgetNode node) {
    final width = node.properties['w'] ?? node.properties['width'];
    final height = node.properties['h'] ?? node.properties['height'];

    if (width != null && height != null && width == height) {
      node.properties.remove('w');
      node.properties.remove('width');
      node.properties.remove('h');
      node.properties.remove('height');
      node.properties['size'] = '${width}x$height';
    }
  }

  /// Replaces `Colors.xxx` with short color names.
  void _applyColorShorthands(WidgetNode node) {
    for (final key in node.properties.keys.toList()) {
      node.properties[key] = shortenColor(node.properties[key]!);
    }
    for (final key in node.textStyle.keys.toList()) {
      node.textStyle[key] = shortenColor(node.textStyle[key]!);
    }
  }

  /// Renames verbose property names to CSS-like shorthands.
  void _applyPropertyShorthands(WidgetNode node) {
    for (final key in node.properties.keys.toList()) {
      final shortKey = shortenProperty(key);
      if (shortKey != key) {
        node.properties[shortKey] = node.properties.remove(key)!;
      }
    }
  }

  /// Marks the node if it contains a page-level widget.
  void _detectPageWidget(WidgetNode node) {
    if (pageIndicatorWidgets.contains(node.name)) {
      node.isPage = true;
    }
  }

  /// Extracts arguments from a widget constructor.
  void _extractArguments(ArgumentList argumentList, WidgetNode widgetNode) {
    var positionalIndex = 0;

    for (final argument in argumentList.arguments) {
      if (argument is NamedExpression) {
        final argumentName = argument.name.label.name;
        final argumentValue = argument.expression;

        if (_namedChildArguments.contains(argumentName)) {
          // Named child slot (body, drawer, appBar, etc.)
          final childWidget = _extractWidget(argumentValue);
          if (childWidget != null) {
            widgetNode.namedChildren[argumentName] = childWidget;
          }
        } else if (_childrenListArguments.contains(argumentName)) {
          _extractChildrenList(argumentValue, widgetNode);
        } else if (argumentName == 'style' && widgetNode.name == 'Text') {
          _extractTextStyle(argumentValue, widgetNode);
        } else if (argumentName == 'padding' || argumentName == 'margin') {
          _extractSpacingShorthand(argumentName, argumentValue, widgetNode);
        } else if (argumentName == 'decoration') {
          _extractDecorationShorthand(argumentValue, widgetNode);
        } else if (argumentName == 'itemBuilder') {
          _extractBuilderPattern(argumentValue, widgetNode);
        } else if (isCallback(argumentName)) {
          widgetNode.callbacks[argumentName] = _extractCallbackValue(
            argumentValue,
          );
        } else {
          widgetNode.properties[argumentName] = _extractPropertyValue(
            argumentValue,
          );
        }
      } else {
        // Positional argument.
        final key = _inferPositionalArgName(
          widgetNode.name,
          widgetNode.constructor,
          positionalIndex,
        );
        widgetNode.properties[key] = _extractPropertyValue(argument);
        positionalIndex++;
      }
    }
  }

  /// Extracts TextStyle properties for pipe syntax.
  void _extractTextStyle(Expression expression, WidgetNode node) {
    ArgumentList? args;

    if (expression is InstanceCreationExpression) {
      args = expression.argumentList;
    } else if (expression is MethodInvocation && expression.target == null) {
      args = expression.argumentList;
    }

    if (args == null) {
      node.properties['style'] = _extractPropertyValue(expression);
      return;
    }

    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = _extractPropertyValue(arg.expression);
        switch (name) {
          case 'fontSize':
            node.textStyle['fontSize'] = value;
          case 'fontWeight':
            node.textStyle['fontWeight'] = fontWeightShorthands[value] ?? value;
          case 'color':
            node.textStyle['color'] = shortenColor(value);
          case 'fontStyle':
            node.textStyle['fontStyle'] = value;
          case 'letterSpacing':
            node.textStyle['letterSpacing'] = value;
          case 'wordSpacing':
            node.textStyle['wordSpacing'] = value;
          case 'height':
            node.textStyle['height'] = value;
          case 'decoration':
            node.textStyle['decoration'] = value;
          case 'decorationColor':
            node.textStyle['decorationColor'] = shortenColor(value);
          case 'decorationStyle':
            node.textStyle['decorationStyle'] = value;
          case 'decorationThickness':
            node.textStyle['decorationThickness'] = value;
          case 'overflow':
            node.textStyle['overflow'] = value;
          default:
            node.textStyle[name] = value;
        }
      }
    }
  }

  /// Extracts EdgeInsets into compact spacing shorthand (p, px, py).
  void _extractSpacingShorthand(
    String propertyName,
    Expression expression,
    WidgetNode node,
  ) {
    final prefix = propertyName == 'padding' ? 'p' : 'm';
    String? shorthand;

    if (expression is InstanceCreationExpression) {
      shorthand = _parseEdgeInsets(expression, prefix);
    } else if (expression is MethodInvocation && expression.target == null) {
      shorthand = _parseEdgeInsetsMethod(expression, prefix);
    }

    if (shorthand != null) {
      final parts = shorthand.split('=');
      node.properties[parts[0]] = parts[1];
    } else {
      node.properties[propertyName] = _extractPropertyValue(expression);
    }
  }

  /// Parses EdgeInsets InstanceCreationExpression into shorthand.
  String? _parseEdgeInsets(
    InstanceCreationExpression expression,
    String prefix,
  ) {
    final typeSource = expression.constructorName.type.toSource();
    final args = expression.argumentList.arguments;

    if (typeSource == 'EdgeInsets.all' || typeSource.endsWith('.all')) {
      if (args.length == 1) {
        return '$prefix=${_extractPropertyValue(args.first as Expression)}';
      }
    } else if (typeSource.endsWith('.symmetric')) {
      String? horizontal, vertical;
      for (final arg in args) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = _extractPropertyValue(arg.expression);
          if (name == 'horizontal') horizontal = value;
          if (name == 'vertical') vertical = value;
        }
      }
      if (horizontal != null && vertical != null) {
        return '${prefix}x=$horizontal, ${prefix}y=$vertical';
      } else if (horizontal != null) {
        return '${prefix}x=$horizontal';
      } else if (vertical != null) {
        return '${prefix}y=$vertical';
      }
    } else if (typeSource.endsWith('.only')) {
      final parts = <String>[];
      for (final arg in args) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = _extractPropertyValue(arg.expression);
          parts.add('${name[0]}: $value');
        }
      }
      if (parts.isNotEmpty) {
        return '$prefix={${parts.join(', ')}}';
      }
    }
    return null;
  }

  /// Parses EdgeInsets from MethodInvocation (without const keyword).
  String? _parseEdgeInsetsMethod(MethodInvocation expression, String prefix) {
    final methodName = expression.methodName.name;
    final args = expression.argumentList.arguments;

    if (methodName == 'all' && args.length == 1) {
      return '$prefix=${_extractPropertyValue(args.first as Expression)}';
    }
    return null;
  }

  /// Extracts BoxDecoration into compact shorthand properties.
  void _extractDecorationShorthand(Expression expression, WidgetNode node) {
    ArgumentList? args;

    if (expression is InstanceCreationExpression) {
      args = expression.argumentList;
    } else if (expression is MethodInvocation && expression.target == null) {
      if (expression.methodName.name == 'BoxDecoration') {
        args = expression.argumentList;
      }
    }

    if (args == null) {
      node.properties['decoration'] = _extractPropertyValue(expression);
      return;
    }

    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = arg.expression;
        switch (name) {
          case 'color':
            node.properties['bg'] = shortenColor(_extractPropertyValue(value));
          case 'borderRadius':
            final brValue = _extractBorderRadius(value);
            if (brValue != null) {
              node.properties['br'] = brValue;
            } else {
              node.properties['br'] = _extractPropertyValue(value);
            }
          case 'boxShadow':
            final shadowValue = _extractBoxShadow(value);
            if (shadowValue != null) {
              node.properties['shadow'] = shadowValue;
            }
          case 'gradient':
            final gradientValue = _extractGradient(value);
            if (gradientValue != null) {
              node.properties['bg'] = gradientValue;
            }
          case 'shape':
            node.properties['shape'] = _extractPropertyValue(value);
          case 'border':
            final borderValue = _extractBorder(value);
            if (borderValue != null) {
              node.properties['border'] = borderValue;
            } else {
              node.properties['border'] = _extractPropertyValue(value);
            }
          case 'image':
            node.properties['bgImage'] = _extractPropertyValue(value);
          default:
            node.properties[name] = _extractPropertyValue(value);
        }
      }
    }
  }

  /// Extracts Border.all(color, width) → `{c: color, w: width}`.
  String? _extractBorder(Expression expression) {
    ArgumentList? args;

    if (expression is InstanceCreationExpression) {
      final typeSource = expression.constructorName.type.toSource();
      if (typeSource.endsWith('.all')) {
        args = expression.argumentList;
      }
    } else if (expression is MethodInvocation) {
      if (expression.methodName.name == 'all') {
        args = expression.argumentList;
      }
    }

    if (args == null) return null;

    final parts = <String>[];
    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = _extractPropertyValue(arg.expression);
        switch (name) {
          case 'color':
            parts.add('c: ${shortenColor(value)}');
          case 'width':
            parts.add('w: $value');
          default:
            parts.add('$name: $value');
        }
      }
    }

    return parts.isEmpty ? null : '{${parts.join(', ')}}';
  }

  /// Extracts BorderRadius.circular(N) → "N".
  String? _extractBorderRadius(Expression expression) {
    if (expression is InstanceCreationExpression) {
      final typeSource = expression.constructorName.type.toSource();
      if (typeSource.endsWith('.circular') &&
          expression.argumentList.arguments.length == 1) {
        return _extractPropertyValue(
          expression.argumentList.arguments.first as Expression,
        );
      }
    } else if (expression is MethodInvocation) {
      if (expression.methodName.name == 'circular' &&
          expression.argumentList.arguments.length == 1) {
        return _extractPropertyValue(
          expression.argumentList.arguments.first as Expression,
        );
      }
    }
    return null;
  }

  /// Extracts BoxShadow list → compact `{c: color, blur: N}`.
  String? _extractBoxShadow(Expression expression) {
    if (expression is ListLiteral && expression.elements.isNotEmpty) {
      final first = expression.elements.first;
      if (first is Expression) {
        return _extractSingleBoxShadow(first);
      }
    }
    return null;
  }

  String? _extractSingleBoxShadow(Expression expression) {
    ArgumentList? args;
    if (expression is InstanceCreationExpression) {
      args = expression.argumentList;
    } else if (expression is MethodInvocation && expression.target == null) {
      args = expression.argumentList;
    }
    if (args == null) return null;

    final parts = <String>[];
    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final value = _extractPropertyValue(arg.expression);
        switch (name) {
          case 'color':
            parts.add('c: ${shortenColor(value)}');
          case 'blurRadius':
            parts.add('blur: $value');
          case 'spreadRadius':
            parts.add('spread: $value');
          case 'offset':
            parts.add('offset: $value');
          default:
            parts.add('$name: $value');
        }
      }
    }
    return parts.isEmpty ? null : '{${parts.join(', ')}}';
  }

  /// Extracts LinearGradient → `gradient(color1, color2)`.
  String? _extractGradient(Expression expression) {
    ArgumentList? args;
    String? gradientType;

    if (expression is InstanceCreationExpression) {
      final typeSource = expression.constructorName.type.toSource();
      gradientType = typeSource.split('.').first;
      args = expression.argumentList;
    } else if (expression is MethodInvocation && expression.target == null) {
      gradientType = expression.methodName.name;
      args = expression.argumentList;
    }
    if (args == null || gradientType != 'LinearGradient') return null;

    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'colors') {
        final colorsExpr = arg.expression;
        if (colorsExpr is ListLiteral) {
          final colors = colorsExpr.elements
              .whereType<Expression>()
              .map((e) => shortenColor(_extractPropertyValue(e)))
              .join(', ');
          return 'gradient($colors)';
        }
      }
    }
    return null;
  }

  /// Extracts itemBuilder pattern from ListView.builder/GridView.builder.
  void _extractBuilderPattern(Expression expression, WidgetNode parentNode) {
    FunctionBody? body;

    if (expression is FunctionExpression) {
      body = expression.body;
    }

    if (body == null) {
      parentNode.properties['itemBuilder'] = _extractPropertyValue(expression);
      return;
    }

    // Extract the returned widget from the builder body.
    WidgetNode? builderWidget;

    if (body is ExpressionFunctionBody) {
      builderWidget = _extractWidget(body.expression);
    } else if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        if (statement is ReturnStatement && statement.expression != null) {
          builderWidget = _extractWidget(statement.expression!);
          break;
        }
      }
    }

    if (builderWidget != null) {
      parentNode.namedChildren['builder'] = builderWidget;
    }
  }

  /// Extracts children from a list literal, including spread and for elements.
  void _extractChildrenList(Expression expression, WidgetNode parentNode) {
    if (expression is ListLiteral) {
      for (final element in expression.elements) {
        if (element is IfElement) {
          final childWidget = _extractConditionalChild(element);
          if (childWidget != null) {
            parentNode.children.add(childWidget);
          }
        } else if (element is SpreadElement) {
          // ...items → special spread node
          final spreadNode = WidgetNode(name: '...');
          spreadNode.properties['spread'] = element.expression.toSource();
          parentNode.children.add(spreadNode);
        } else if (element is ForElement) {
          // for (var x in list) Widget(x) → special for node
          final forNode = WidgetNode(name: 'for');
          forNode.properties['loop'] = element.forLoopParts.toSource();
          if (element.body is Expression) {
            final bodyWidget = _extractWidget(element.body as Expression);
            if (bodyWidget != null) {
              forNode.children.add(bodyWidget);
            }
          }
          parentNode.children.add(forNode);
        } else if (element is Expression) {
          final childWidget = _extractWidget(element);
          if (childWidget != null) {
            parentNode.children.add(childWidget);
          }
        }
      }
    }
  }

  /// Extracts a child widget wrapped in an if-condition.
  WidgetNode? _extractConditionalChild(IfElement element) {
    final condition = _extractPropertyValue(element.expression);
    final thenElement = element.thenElement;

    WidgetNode? childWidget;
    if (thenElement is Expression) {
      childWidget = _extractWidget(thenElement);
    }

    if (childWidget == null) return null;

    final node = WidgetNode(
      name: childWidget.name,
      constructor: childWidget.constructor,
      properties: childWidget.properties,
      callbacks: childWidget.callbacks,
      children: childWidget.children,
      namedChildren: childWidget.namedChildren,
      textStyle: childWidget.textStyle,
      alignmentShorthand: childWidget.alignmentShorthand,
      condition: condition,
    );

    // Handle else branch.
    if (element.elseElement != null) {
      if (element.elseElement is Expression) {
        final elseWidget = _extractWidget(element.elseElement as Expression);
        if (elseWidget != null) {
          node.namedChildren['else'] = elseWidget;
        }
      }
    }

    return node;
  }

  /// Converts an expression to a compact string property value.
  String _extractPropertyValue(Expression expression) {
    if (expression is PrefixedIdentifier) {
      final prefix = expression.prefix.name;
      final identifier = expression.identifier.name;
      // Shorten double.infinity → full.
      if (prefix == 'double' && identifier == 'infinity') {
        return 'full';
      }
      if (_isCommonEnumPrefix(prefix)) {
        return identifier;
      }
      return '$prefix.$identifier';
    } else if (expression is SimpleStringLiteral) {
      return expression.value;
    } else if (expression is IntegerLiteral) {
      return expression.value?.toString() ?? expression.literal.lexeme;
    } else if (expression is DoubleLiteral) {
      return expression.value.toString();
    } else if (expression is BooleanLiteral) {
      return expression.value.toString();
    } else if (expression is SimpleIdentifier) {
      return expression.name;
    } else if (expression is PrefixExpression) {
      return '${expression.operator.lexeme}${_extractPropertyValue(expression.operand)}';
    } else if (expression is InstanceCreationExpression) {
      final typeSource = expression.constructorName.type.toSource();
      final baseTypeName = typeSource.split('.').first;
      if (_isSimpleValueType(baseTypeName)) {
        return _extractSimpleValueFromInstance(expression);
      }
      return baseTypeName;
    } else if (expression is MethodInvocation) {
      return _extractMethodInvocationValue(expression);
    } else if (expression is PropertyAccess) {
      // Handle chained property access like Theme.of(context).textTheme.headline
      return _extractPropertyAccessValue(expression);
    }
    return expression.toSource();
  }

  /// Extracts a method invocation value with special shorthand detection.
  String _extractMethodInvocationValue(MethodInvocation expression) {
    final target = expression.target;
    final methodName = expression.methodName.name;

    if (target == null) {
      if (_isSimpleValueType(methodName)) {
        return _extractSimpleValueFromMethod(expression);
      }
      return methodName;
    }

    // Detect Theme.of(context) patterns.
    if (target is SimpleIdentifier &&
        target.name == 'Theme' &&
        methodName == 'of') {
      return 'theme';
    }

    // Detect MediaQuery.of(context) patterns.
    if (target is SimpleIdentifier &&
        target.name == 'MediaQuery' &&
        methodName == 'of') {
      return 'screen';
    }

    if (target is SimpleIdentifier) {
      return '${target.name}.$methodName(...)';
    }

    // Handle chained calls like Theme.of(context).textTheme
    if (target is MethodInvocation) {
      final innerValue = _extractMethodInvocationValue(target);
      return '$innerValue.$methodName';
    }

    return '$methodName(...)';
  }

  /// Extracts chained property access (Theme.of(context).textTheme.headline).
  String _extractPropertyAccessValue(PropertyAccess expression) {
    final target = expression.target;
    final property = expression.propertyName.name;

    if (target is MethodInvocation) {
      final innerValue = _extractMethodInvocationValue(target);
      if (innerValue == 'theme') {
        return 'theme.$property';
      }
      if (innerValue == 'screen') {
        // MediaQuery.of(context).size → screen
        if (property == 'size') return 'screen';
        return 'screen.$property';
      }
      return '$innerValue.$property';
    }

    if (target is PropertyAccess) {
      final innerValue = _extractPropertyAccessValue(target);
      // screen.size.width → screen.w, screen.size.height → screen.h
      if (innerValue == 'screen' && property == 'width') return 'screen.w';
      if (innerValue == 'screen' && property == 'height') return 'screen.h';
      return '$innerValue.$property';
    }

    return expression.toSource();
  }

  /// Extracts a callback value into compact arrow notation.
  String _extractCallbackValue(Expression expression) {
    if (expression is SimpleIdentifier) {
      return expression.name;
    } else if (expression is FunctionExpression) {
      final body = expression.body;
      if (body is ExpressionFunctionBody) {
        return _summarizeCallbackExpression(body.expression);
      }
      return '(...)';
    } else if (expression is MethodInvocation) {
      final target = expression.target;
      final method = expression.methodName.name;
      if (target is SimpleIdentifier) {
        return '${target.name}.$method()';
      }
      return '$method()';
    }
    return expression.toSource();
  }

  /// Summarizes a callback body expression into compact form.
  String _summarizeCallbackExpression(Expression expression) {
    if (expression is MethodInvocation) {
      final target = expression.target;
      final method = expression.methodName.name;
      final args = expression.argumentList.arguments;

      String argsStr = '';
      if (args.isNotEmpty) {
        argsStr = args
            .map((a) => _extractPropertyValue(a as Expression))
            .join(', ');
      }

      if (target is SimpleIdentifier) {
        return '${target.name}.$method($argsStr)';
      }
      return '$method($argsStr)';
    } else if (expression is AssignmentExpression) {
      return 'set ${expression.leftHandSide.toSource()}';
    }
    return expression.toSource();
  }

  /// Extracts a compact value string from InstanceCreationExpression.
  String _extractSimpleValueFromInstance(
    InstanceCreationExpression expression,
  ) {
    final typeSource = expression.constructorName.type.toSource();
    final args = expression.argumentList.arguments
        .map((arg) {
          if (arg is NamedExpression) {
            return '${arg.name.label.name}: ${_extractPropertyValue(arg.expression)}';
          }
          return _extractPropertyValue(arg as Expression);
        })
        .join(', ');

    return '$typeSource($args)';
  }

  /// Extracts a simple value from a MethodInvocation for value types.
  String _extractSimpleValueFromMethod(MethodInvocation expression) {
    final methodName = expression.methodName.name;
    final args = expression.argumentList.arguments
        .map((arg) {
          if (arg is NamedExpression) {
            return '${arg.name.label.name}: ${_extractPropertyValue(arg.expression)}';
          }
          return _extractPropertyValue(arg as Expression);
        })
        .join(', ');
    return '$methodName($args)';
  }

  /// Infers a readable name for a positional argument.
  String _inferPositionalArgName(
    String widgetName,
    String? constructor,
    int index,
  ) {
    final key = constructor != null ? '$widgetName.$constructor' : widgetName;
    switch (key) {
      case 'Image.asset':
      case 'Image.network':
      case 'Image.file':
        return 'src';
      case 'Text':
        return 'text';
      case 'Icon':
        return 'icon';
      default:
        if (index == 0) return 'value';
        return 'arg$index';
    }
  }

  bool _isCommonEnumPrefix(String prefix) => const {
    'MainAxisAlignment',
    'CrossAxisAlignment',
    'MainAxisSize',
    'Axis',
    'TextAlign',
    'TextDirection',
    'FontWeight',
    'FontStyle',
    'TextOverflow',
    'BoxFit',
    'Alignment',
    'WrapAlignment',
    'StackFit',
    'Clip',
    'BorderStyle',
    'BlendMode',
    'FilterQuality',
    'ImageRepeat',
    'VerticalDirection',
    'TextBaseline',
    'TextInputType',
    'TextInputAction',
    'TextCapitalization',
    'Brightness',
    'TabBarIndicatorSize',
    'ScrollPhysics',
    'BoxShape',
    'TextDecoration',
    'TextDecorationStyle',
    'Icons',
    'CupertinoIcons',
  }.contains(prefix);

  bool _isSimpleValueType(String typeName) => const {
    'EdgeInsets',
    'Duration',
    'Size',
    'Offset',
    'Radius',
    'BorderRadius',
    'Border',
    'BoxDecoration',
    'TextStyle',
    'BoxConstraints',
    'RoundedRectangleBorder',
    'CircleBorder',
    'StadiumBorder',
  }.contains(typeName);
}
