import 'dart:io';

import 'package:path/path.dart' as p;

import 'analyzer/dart_file_analyzer.dart';
import 'generator/yaml_generator.dart';
import 'models/dart_file_model.dart';

/// Orchestrates the full conversion pipeline: read .dart → analyze → generate YAML → write .yaml.
///
/// Handles both single file and directory conversion with configurable
/// output location and verbosity level.
class Converter {
  final DartFileAnalyzer _analyzer = DartFileAnalyzer();
  final YamlGenerator _generator = YamlGenerator();

  /// Converts a single .dart file to .yaml.
  ///
  /// Returns the output file path on success, or null if the file
  /// doesn't contain a widget class.
  String? convertFile(
    String inputPath, {
    VerbosityLevel level = VerbosityLevel.standard,
    String? outputDir,
  }) {
    final file = File(inputPath);
    if (!file.existsSync()) {
      stderr.writeln('Error: File not found: $inputPath');
      return null;
    }

    final source = file.readAsStringSync();
    final fileName = p.basename(inputPath);
    final model = _analyzer.analyze(source, fileName);

    if (model == null) {
      stderr.writeln('Skipped: No widget class found in $fileName');
      return null;
    }

    final yamlContent = _generator.generate(model, level);
    final outputPath = _resolveOutputPath(inputPath, outputDir);

    // Ensure output directory exists.
    final outputDirectory = Directory(p.dirname(outputPath));
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    File(outputPath).writeAsStringSync(yamlContent);
    return outputPath;
  }

  /// Converts all .dart files in a directory to .yaml.
  ///
  /// Returns a list of successfully converted output file paths.
  List<String> convertDirectory(
    String dirPath, {
    VerbosityLevel level = VerbosityLevel.standard,
    String? outputDir,
    bool recursive = false,
  }) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      stderr.writeln('Error: Directory not found: $dirPath');
      return [];
    }

    final dartFiles = directory
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    if (dartFiles.isEmpty) {
      stderr.writeln('No .dart files found in $dirPath');
      return [];
    }

    final convertedPaths = <String>[];

    for (final dartFile in dartFiles) {
      final result = convertFile(
        dartFile.path,
        level: level,
        outputDir: outputDir,
      );
      if (result != null) {
        convertedPaths.add(result);
      }
    }

    return convertedPaths;
  }

  /// Resolves the output .yaml file path from input .dart path.
  String _resolveOutputPath(String inputPath, String? outputDir) {
    final baseName = p.basenameWithoutExtension(inputPath);
    final yamlFileName = '$baseName.yaml';

    if (outputDir != null) {
      return p.join(outputDir, yamlFileName);
    }

    return p.join(p.dirname(inputPath), yamlFileName);
  }
}
