import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../converter.dart';
import '../models/dart_file_model.dart';

/// Watches a file or directory for changes and auto-converts modified .dart files.
class FileWatcher {
  final Converter _converter = Converter();

  /// Starts watching a single .dart file for changes.
  ///
  /// Triggers conversion whenever the file is modified.
  Future<void> watchFile(
    String filePath, {
    VerbosityLevel level = VerbosityLevel.standard,
    String? outputDir,
  }) async {
    final directory = p.dirname(filePath);
    final fileName = p.basename(filePath);

    stdout.writeln('Watching $filePath for changes...');
    stdout.writeln('Press Ctrl+C to stop.\n');

    final directoryWatcher = DirectoryWatcher(directory);

    await for (final event in directoryWatcher.events) {
      if (p.basename(event.path) == fileName &&
          event.type == ChangeType.MODIFY) {
        stdout.writeln('Change detected: $fileName');
        final result = _converter.convertFile(
          filePath,
          level: level,
          outputDir: outputDir,
        );
        if (result != null) {
          stdout.writeln('  → Generated: ${p.basename(result)}');
        }
      }
    }
  }

  /// Starts watching a directory for .dart file changes.
  ///
  /// Triggers conversion whenever any .dart file is modified or added.
  Future<void> watchDirectory(
    String dirPath, {
    VerbosityLevel level = VerbosityLevel.standard,
    String? outputDir,
    bool recursive = false,
  }) async {
    stdout.writeln('Watching $dirPath for .dart file changes...');
    stdout.writeln('Press Ctrl+C to stop.\n');

    final directoryWatcher = DirectoryWatcher(dirPath);

    await for (final event in directoryWatcher.events) {
      if (!event.path.endsWith('.dart')) continue;

      if (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD) {
        // Skip files outside the directory if not recursive.
        if (!recursive) {
          final fileDir = p.dirname(event.path);
          if (p.normalize(fileDir) != p.normalize(dirPath)) continue;
        }

        final relativePath = p.relative(event.path, from: dirPath);
        stdout.writeln('Change detected: $relativePath');

        final result = _converter.convertFile(
          event.path,
          level: level,
          outputDir: outputDir,
        );
        if (result != null) {
          stdout.writeln('  → Generated: ${p.basename(result)}');
        }
      }
    }
  }
}
