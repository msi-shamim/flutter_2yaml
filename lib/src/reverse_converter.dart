import 'dart:io';

import 'package:path/path.dart' as p;

import 'generator/dart_generator.dart';
import 'parser/yaml_parser.dart';

/// Orchestrates the reverse conversion pipeline: read .yaml → parse → generate → write .dart.
///
/// Handles both single file and directory conversion with configurable output location.
class ReverseConverter {
  final YamlParser _parser = YamlParser();
  final DartGenerator _generator = DartGenerator();

  /// Converts a single .yaml file to .dart.
  ///
  /// Returns the output file path on success, or null on failure.
  String? reverseFile(String inputPath, {String? outputDir}) {
    final file = File(inputPath);
    if (!file.existsSync()) {
      stderr.writeln('Error: File not found: $inputPath');
      return null;
    }

    final source = file.readAsStringSync();
    final fileName = p.basename(inputPath);
    final model = _parser.parse(source, fileName);
    final dartCode = _generator.generate(model);

    final outputPath = _resolveOutputPath(inputPath, outputDir);

    // Ensure output directory exists.
    final outputDirectory = Directory(p.dirname(outputPath));
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    File(outputPath).writeAsStringSync(dartCode);
    return outputPath;
  }

  /// Converts all .yaml files in a directory to .dart.
  ///
  /// Returns a list of successfully converted output file paths.
  List<String> reverseDirectory(
    String dirPath, {
    String? outputDir,
    bool recursive = false,
  }) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      stderr.writeln('Error: Directory not found: $dirPath');
      return [];
    }

    final yamlFiles = directory
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((file) => file.path.endsWith('.yaml'))
        .toList();

    if (yamlFiles.isEmpty) {
      stderr.writeln('No .yaml files found in $dirPath');
      return [];
    }

    final convertedPaths = <String>[];
    for (final yamlFile in yamlFiles) {
      final result = reverseFile(yamlFile.path, outputDir: outputDir);
      if (result != null) {
        convertedPaths.add(result);
      }
    }

    return convertedPaths;
  }

  /// Resolves the output .dart file path from input .yaml path.
  String _resolveOutputPath(String inputPath, String? outputDir) {
    final baseName = p.basenameWithoutExtension(inputPath);
    final dartFileName = '$baseName.dart';

    if (outputDir != null) {
      return p.join(outputDir, dartFileName);
    }

    return p.join(p.dirname(inputPath), dartFileName);
  }
}
