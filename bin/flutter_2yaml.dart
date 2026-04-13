import 'dart:io';

import 'package:flutter_2yaml/src/cli/command_runner.dart';

/// CLI entry point for flutter_2yaml.
///
/// Converts Flutter .dart widget files into compact YAML representations
/// optimized for LLM/AI token consumption.
Future<void> main(List<String> arguments) async {
  final runner = CommandRunner();
  final exitCode = await runner.run(arguments);
  exit(exitCode);
}
