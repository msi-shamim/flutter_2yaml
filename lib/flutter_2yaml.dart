/// Convert Flutter .dart widget files into compact YAML representations
/// optimized for LLM/AI token consumption.
///
/// This package provides both a CLI tool and a programmatic API for
/// bidirectional conversion between Flutter widget files (.dart) and
/// structured YAML format with CSS-like shorthands, pipe syntax,
/// arrow callback notation, and configurable verbosity levels.
library flutter_2yaml;

export 'src/analyzer/dart_file_analyzer.dart' show DartFileAnalyzer;
export 'src/converter.dart' show Converter;
export 'src/generator/dart_generator.dart' show DartGenerator;
export 'src/generator/yaml_generator.dart' show YamlGenerator;
export 'src/models/dart_file_model.dart'
    show DartFileModel, VerbosityLevel, WidgetType, ConstructorParam;
export 'src/models/state_model.dart'
    show StateModel, StateVariable, MethodSummary, StateManagementInfo;
export 'src/models/widget_node.dart' show WidgetNode;
export 'src/parser/yaml_parser.dart' show YamlParser;
export 'src/reverse_converter.dart' show ReverseConverter;
