import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../generator/shorthand_map.dart';
import '../models/dart_file_model.dart';
import '../models/state_model.dart';
import '../models/widget_node.dart';
import 'state_visitor.dart';
import 'widget_visitor.dart';

/// Analyzes a Flutter .dart file and produces a [DartFileModel].
///
/// Uses the Dart `analyzer` package to parse the source code into an AST,
/// then applies [WidgetVisitor] and [StateVisitor] to extract the widget
/// tree and state information respectively. Auto-detects state management
/// patterns and classifies as page vs widget.
class DartFileAnalyzer {
  /// Parses the given [source] code from a file named [fileName]
  /// and returns a [DartFileModel] representing the widget structure.
  ///
  /// Returns `null` if the file does not contain a Flutter widget class.
  DartFileModel? analyze(String source, String fileName) {
    final parseResult = parseString(content: source);
    final compilationUnit = parseResult.unit;

    final imports = _extractImports(compilationUnit);
    final widgetClassInfo = _findWidgetClass(compilationUnit);
    if (widgetClassInfo == null) return null;

    final widgetClassName = widgetClassInfo.className;
    final widgetType = widgetClassInfo.widgetType;
    final constructorParams = _extractConstructorParams(widgetClassInfo.node);
    final mixins = _extractMixins(widgetClassInfo.node);

    WidgetNode? widgetTree;
    StateModel? stateModel;

    if (widgetType == WidgetType.statelessWidget) {
      widgetTree = _extractWidgetTree(widgetClassInfo.node);
    } else {
      final stateClass = _findStateClass(compilationUnit, widgetClassName);
      if (stateClass != null) {
        widgetTree = _extractWidgetTree(stateClass);
        stateModel = _extractStateModel(stateClass);
      }
    }

    // Auto-detect state management from imports.
    final stateManagement = _detectStateManagement(imports, compilationUnit);

    // Detect if this is a page (has Scaffold) or a component widget.
    final isPage = _isPageWidget(widgetTree);

    return DartFileModel(
      fileName: fileName,
      className: widgetClassName,
      widgetType: widgetType,
      imports: imports,
      constructorParams: constructorParams,
      widgetTree: widgetTree,
      stateModel: stateModel,
      mixins: mixins,
      isPage: isPage,
      stateManagement: stateManagement,
    );
  }

  /// Extracts all import directives from the compilation unit.
  List<String> _extractImports(CompilationUnit unit) {
    return unit.directives
        .whereType<ImportDirective>()
        .map((directive) => directive.uri.stringValue ?? '')
        .where((uri) => uri.isNotEmpty)
        .toList();
  }

  /// Finds the first class that extends StatelessWidget or StatefulWidget.
  _WidgetClassInfo? _findWidgetClass(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        final superclass = declaration.extendsClause?.superclass.name2.lexeme;

        // Direct StatelessWidget/StatefulWidget.
        if (superclass == 'StatelessWidget') {
          return _WidgetClassInfo(
            node: declaration,
            className: declaration.name.lexeme,
            widgetType: WidgetType.statelessWidget,
          );
        } else if (superclass == 'StatefulWidget') {
          return _WidgetClassInfo(
            node: declaration,
            className: declaration.name.lexeme,
            widgetType: WidgetType.statefulWidget,
          );
        }

        // Riverpod ConsumerWidget / ConsumerStatefulWidget.
        if (superclass == 'ConsumerWidget' ||
            superclass == 'HookConsumerWidget' ||
            superclass == 'HookWidget') {
          return _WidgetClassInfo(
            node: declaration,
            className: declaration.name.lexeme,
            widgetType: WidgetType.statelessWidget,
          );
        } else if (superclass == 'ConsumerStatefulWidget') {
          return _WidgetClassInfo(
            node: declaration,
            className: declaration.name.lexeme,
            widgetType: WidgetType.statefulWidget,
          );
        }

        // GetX: GetView / GetWidget.
        final superclassSource =
            declaration.extendsClause?.superclass.toSource() ?? '';
        if (superclassSource.startsWith('GetView') ||
            superclassSource.startsWith('GetWidget')) {
          return _WidgetClassInfo(
            node: declaration,
            className: declaration.name.lexeme,
            widgetType: WidgetType.statelessWidget,
          );
        }
      }
    }
    return null;
  }

  /// Finds the State class associated with a StatefulWidget.
  ClassDeclaration? _findStateClass(
    CompilationUnit unit,
    String widgetClassName,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        final superclass = declaration.extendsClause?.superclass;
        if (superclass != null) {
          final superclassSource = superclass.toSource();
          if (superclassSource.startsWith('State<') &&
              superclassSource.contains(widgetClassName)) {
            return declaration;
          }
          // ConsumerState for Riverpod.
          if (superclassSource.startsWith('ConsumerState<') &&
              superclassSource.contains(widgetClassName)) {
            return declaration;
          }
        }
      }
    }
    return null;
  }

  /// Extracts the widget tree from a class containing a build() method.
  WidgetNode? _extractWidgetTree(ClassDeclaration classNode) {
    final widgetVisitor = WidgetVisitor();
    classNode.accept(widgetVisitor);
    return widgetVisitor.rootWidget;
  }

  /// Extracts state information from a State class.
  StateModel _extractStateModel(ClassDeclaration stateClass) {
    final stateVisitor = StateVisitor();
    stateClass.accept(stateVisitor);
    return stateVisitor.stateModel;
  }

  /// Extracts constructor parameters from a widget class.
  List<ConstructorParam> _extractConstructorParams(ClassDeclaration classNode) {
    final params = <ConstructorParam>[];

    for (final member in classNode.members) {
      if (member is ConstructorDeclaration) {
        final parameterList = member.parameters;
        if (parameterList != null) {
          for (final param in parameterList.parameters) {
            if (param is DefaultFormalParameter) {
              final normalParam = param.parameter;
              params.add(
                ConstructorParam(
                  name: normalParam.name?.lexeme ?? '',
                  type: _getParameterType(normalParam),
                  isRequired: param.isRequired,
                  defaultValue: param.defaultValue?.toSource(),
                ),
              );
            } else {
              params.add(
                ConstructorParam(
                  name: param.name?.lexeme ?? '',
                  type: _getParameterType(param),
                  isRequired: true,
                ),
              );
            }
          }
        }
        break;
      }
    }

    return params;
  }

  /// Extracts mixins applied to a class.
  List<String> _extractMixins(ClassDeclaration classNode) {
    final withClause = classNode.withClause;
    if (withClause == null) return [];
    return withClause.mixinTypes.map((type) => type.name2.lexeme).toList();
  }

  /// Gets the type annotation string for a formal parameter.
  String _getParameterType(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource() ?? 'dynamic';
    } else if (param is SuperFormalParameter) {
      return param.type?.toSource() ?? 'super';
    } else if (param is FieldFormalParameter) {
      return param.type?.toSource() ?? 'this';
    }
    return 'dynamic';
  }

  /// Auto-detects state management framework from imports and class patterns.
  StateManagementInfo? _detectStateManagement(
    List<String> imports,
    CompilationUnit unit,
  ) {
    // Check imports for state management packages.
    String? detectedType;
    for (final importUri in imports) {
      for (final entry in stateManagementImports.entries) {
        if (importUri.startsWith(entry.key)) {
          detectedType = entry.value;
          break;
        }
      }
      if (detectedType != null) break;
    }

    if (detectedType == null) return null;

    // Try to find the controller/bloc/provider class name.
    String? controllerName;
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        final superclassSource =
            declaration.extendsClause?.superclass.toSource() ?? '';
        final className = declaration.name.lexeme;

        switch (detectedType) {
          case 'GetX':
            if (superclassSource.startsWith('GetxController') ||
                superclassSource.startsWith('GetxService')) {
              controllerName = className;
            }
          case 'Bloc':
            if (superclassSource.startsWith('Bloc<') ||
                superclassSource.startsWith('Cubit<')) {
              controllerName = className;
            }
          case 'Provider':
            if (superclassSource.contains('ChangeNotifier')) {
              controllerName = className;
            }
          case 'Riverpod':
            if (superclassSource.startsWith('StateNotifier') ||
                superclassSource.startsWith('AsyncNotifier') ||
                superclassSource.startsWith('Notifier')) {
              controllerName = className;
            }
        }
      }
    }

    return StateManagementInfo(
      type: detectedType,
      controllerName: controllerName,
    );
  }

  /// Checks if the widget tree contains a page-level widget (Scaffold etc.).
  bool _isPageWidget(WidgetNode? tree) {
    if (tree == null) return false;
    if (pageIndicatorWidgets.contains(tree.name)) return true;
    for (final child in tree.children) {
      if (_isPageWidget(child)) return true;
    }
    return false;
  }
}

/// Internal helper to hold widget class identification results.
class _WidgetClassInfo {
  final ClassDeclaration node;
  final String className;
  final WidgetType widgetType;

  _WidgetClassInfo({
    required this.node,
    required this.className,
    required this.widgetType,
  });
}
