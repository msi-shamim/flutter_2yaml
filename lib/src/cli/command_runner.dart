import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../converter.dart';
import '../models/dart_file_model.dart';
import '../reverse_converter.dart';
import 'watcher.dart';

/// The package version — kept in sync with pubspec.yaml.
const String packageVersion = '0.4.0';

/// Parses CLI arguments and dispatches to the appropriate conversion logic.
class CommandRunner {
  final Converter _converter = Converter();
  final ReverseConverter _reverseConverter = ReverseConverter();
  final FileWatcher _fileWatcher = FileWatcher();

  /// Runs the CLI with the given [arguments].
  ///
  /// Returns an exit code (0 for success, non-zero for errors).
  Future<int> run(List<String> arguments) async {
    final parser = _buildArgParser();

    try {
      final results = parser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage(parser);
        return 0;
      }

      if (results['version'] as bool) {
        stdout.writeln('flutter_2yaml v$packageVersion');
        return 0;
      }

      // The target path is the first positional argument.
      if (results.rest.isEmpty) {
        stderr.writeln('Error: No input path provided.\n');
        _printUsage(parser);
        return 1;
      }

      // Check for 'reverse' subcommand.
      final isReverse = results.rest.first == 'reverse';
      final targetPath = isReverse
          ? (results.rest.length > 1 ? results.rest[1] : '')
          : results.rest.first;

      if (targetPath.isEmpty) {
        stderr.writeln('Error: No input path provided after "reverse".\n');
        _printUsage(parser);
        return 1;
      }

      final outputDir = results['output'] as String?;
      final recursive = results['recursive'] as bool;

      final entityType = FileSystemEntity.typeSync(targetPath);

      if (entityType == FileSystemEntityType.notFound) {
        stderr.writeln('Error: Path not found: $targetPath');
        return 1;
      }

      if (isReverse) {
        return _runReverseConversion(
          targetPath,
          entityType: entityType,
          outputDir: outputDir,
          recursive: recursive,
        );
      }

      final level = _parseLevel(results['level'] as String);
      final watch = results['watch'] as bool;

      if (watch) {
        return await _runWatchMode(
          targetPath,
          entityType: entityType,
          level: level,
          outputDir: outputDir,
          recursive: recursive,
        );
      }

      return _runConversion(
        targetPath,
        entityType: entityType,
        level: level,
        outputDir: outputDir,
        recursive: recursive,
      );
    } on FormatException catch (e) {
      stderr.writeln('Error: ${e.message}\n');
      _printUsage(parser);
      return 1;
    }
  }

  /// Runs a one-time conversion on the target path.
  int _runConversion(
    String targetPath, {
    required FileSystemEntityType entityType,
    required VerbosityLevel level,
    String? outputDir,
    required bool recursive,
  }) {
    if (entityType == FileSystemEntityType.file) {
      if (!targetPath.endsWith('.dart')) {
        stderr.writeln('Error: Not a .dart file: $targetPath');
        return 1;
      }
      final result = _converter.convertFile(
        targetPath,
        level: level,
        outputDir: outputDir,
      );
      if (result != null) {
        stdout.writeln(
          'Converted: ${p.basename(targetPath)} → ${p.basename(result)}',
        );
        return 0;
      }
      return 1;
    }

    if (entityType == FileSystemEntityType.directory) {
      final results = _converter.convertDirectory(
        targetPath,
        level: level,
        outputDir: outputDir,
        recursive: recursive,
      );
      if (results.isEmpty) {
        stderr.writeln('No widget files converted.');
        return 1;
      }
      stdout.writeln('Converted ${results.length} file(s):');
      for (final result in results) {
        stdout.writeln('  → ${p.basename(result)}');
      }
      return 0;
    }

    stderr.writeln('Error: Unsupported file system entity: $targetPath');
    return 1;
  }

  /// Runs reverse conversion (YAML → Dart) on the target path.
  int _runReverseConversion(
    String targetPath, {
    required FileSystemEntityType entityType,
    String? outputDir,
    required bool recursive,
  }) {
    if (entityType == FileSystemEntityType.file) {
      if (!targetPath.endsWith('.yaml')) {
        stderr.writeln('Error: Not a .yaml file: $targetPath');
        return 1;
      }
      final result = _reverseConverter.reverseFile(
        targetPath,
        outputDir: outputDir,
      );
      if (result != null) {
        stdout.writeln(
          'Reversed: ${p.basename(targetPath)} → ${p.basename(result)}',
        );
        return 0;
      }
      return 1;
    }

    if (entityType == FileSystemEntityType.directory) {
      final results = _reverseConverter.reverseDirectory(
        targetPath,
        outputDir: outputDir,
        recursive: recursive,
      );
      if (results.isEmpty) {
        stderr.writeln('No .yaml files reversed.');
        return 1;
      }
      stdout.writeln('Reversed ${results.length} file(s):');
      for (final result in results) {
        stdout.writeln('  → ${p.basename(result)}');
      }
      return 0;
    }

    stderr.writeln('Error: Unsupported file system entity: $targetPath');
    return 1;
  }

  /// Runs the watcher on the target path.
  Future<int> _runWatchMode(
    String targetPath, {
    required FileSystemEntityType entityType,
    required VerbosityLevel level,
    String? outputDir,
    required bool recursive,
  }) async {
    // Run initial conversion first.
    _runConversion(
      targetPath,
      entityType: entityType,
      level: level,
      outputDir: outputDir,
      recursive: recursive,
    );

    stdout.writeln('');

    if (entityType == FileSystemEntityType.file) {
      await _fileWatcher.watchFile(
        targetPath,
        level: level,
        outputDir: outputDir,
      );
    } else {
      await _fileWatcher.watchDirectory(
        targetPath,
        level: level,
        outputDir: outputDir,
        recursive: recursive,
      );
    }

    return 0;
  }

  /// Parses the verbosity level string into [VerbosityLevel].
  VerbosityLevel _parseLevel(String levelStr) {
    switch (levelStr) {
      case 'minimal':
        return VerbosityLevel.minimal;
      case 'full':
        return VerbosityLevel.full;
      case 'standard':
      default:
        return VerbosityLevel.standard;
    }
  }

  /// Builds the argument parser with all supported flags and options.
  ArgParser _buildArgParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Show the package version.',
      )
      ..addOption(
        'level',
        abbr: 'l',
        defaultsTo: 'standard',
        allowed: ['minimal', 'standard', 'full'],
        help: 'YAML verbosity level.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory (default: same as source).',
      )
      ..addFlag(
        'watch',
        abbr: 'w',
        negatable: false,
        help: 'Watch mode — auto-regenerate on file changes.',
      )
      ..addFlag(
        'recursive',
        abbr: 'r',
        negatable: false,
        help: 'Scan subdirectories recursively.',
      );
  }

  /// Prints usage information.
  void _printUsage(ArgParser parser) {
    stdout.writeln(
      'flutter_2yaml — Convert between Flutter .dart and compact YAML',
    );
    stdout.writeln('');
    stdout.writeln('Usage:');
    stdout.writeln('  flutter_2yaml <path> [options]          # Dart → YAML');
    stdout.writeln('  flutter_2yaml reverse <path> [options]  # YAML → Dart');
    stdout.writeln('');
    stdout.writeln('Arguments:');
    stdout.writeln('  <path>    A .dart/.yaml file or directory');
    stdout.writeln('');
    stdout.writeln('Options:');
    stdout.writeln(parser.usage);
    stdout.writeln('');
    stdout.writeln('Examples:');
    stdout.writeln('  flutter_2yaml lib/screens/splash_screen.dart');
    stdout.writeln('  flutter_2yaml lib/screens/ --recursive --level full');
    stdout.writeln('  flutter_2yaml lib/screens/ --watch');
    stdout.writeln('  flutter_2yaml reverse splash_screen.yaml');
    stdout.writeln(
      '  flutter_2yaml reverse yaml_output/ --output lib/screens/',
    );
  }
}
