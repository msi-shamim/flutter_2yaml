// example/main.dart
//
// This example demonstrates how to use flutter_2yaml programmatically.
// Most users will use the CLI directly — see "CLI Usage" below.
//
// ═══════════════════════════════════════════════════════════
// CLI USAGE (recommended)
// ═══════════════════════════════════════════════════════════
//
// Install:
//   dart pub global activate flutter_2yaml
//
// Forward — Dart to YAML:
//   flutter_2yaml lib/screens/splash_screen.dart
//   flutter_2yaml lib/screens/ --recursive
//   flutter_2yaml lib/screens/ --level minimal
//   flutter_2yaml lib/screens/ --level full --output yaml_output/
//   flutter_2yaml lib/screens/ --watch
//
// Reverse — YAML to Dart:
//   flutter_2yaml reverse splash_screen.yaml
//   flutter_2yaml reverse yaml_output/ --output lib/screens/
//
// ═══════════════════════════════════════════════════════════
// ALL OPTIONS
// ═══════════════════════════════════════════════════════════
//
// flutter_2yaml <path> [options]          Forward (Dart → YAML)
// flutter_2yaml reverse <path> [options]  Reverse (YAML → Dart)
//
// Options:
//   -l, --level       minimal | standard (default) | full
//   -o, --output      Output directory (default: same as source)
//   -w, --watch       Watch mode — auto-regenerate on file changes
//   -r, --recursive   Scan subdirectories
//   -h, --help        Show usage information
//   -v, --version     Show package version
//
// ═══════════════════════════════════════════════════════════
// COMPACT FORMAT REFERENCE
// ═══════════════════════════════════════════════════════════
//
// Pipe Syntax:
//   Text: "Hello" | 20 | bold | white     (text | fontSize | fontWeight | color)
//   Image.asset: logo.png | 200x200       (source | WxH dimensions)
//   Icon: search | onTap → goSearch()     (icon | callback)
//
// CSS-Like Shorthands:
//   bg → backgroundColor       br → borderRadius
//   h  → height                w  → width
//   p  → EdgeInsets.all         px → EdgeInsets.symmetric(horizontal)
//   py → EdgeInsets.symmetric(vertical)
//   t/l/r/b → top/left/right/bottom (Positioned)
//   gap → spacing               runGap → runSpacing (Wrap)
//   full → double.infinity
//
// Arrow Callbacks:
//   onTap → goSearch()          onPressed → handleSubmit
//
// Alignment:
//   Column(center)              Row(spaceBetween)
//   Column(start)               Row(spaceEvenly, center)
//
// Colors:    Colors.blue → blue     Color(0xFF123456) → #123456
// Icons:     Icons.menu → menu      Icons.search → search
// Theme:     Theme.of(context).textTheme.headline → theme.headline
// Screen:    MediaQuery.of(context).size.width → screen.w
//
// ═══════════════════════════════════════════════════════════
// PROGRAMMATIC USAGE
// ═══════════════════════════════════════════════════════════

import 'package:flutter_2yaml/flutter_2yaml.dart';

void main() {
  // ── Forward: Dart → YAML ──────────────────────────────

  const dartSource = '''
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 200, height: 200),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
''';

  // 1. Analyze Dart source
  final analyzer = DartFileAnalyzer();
  final model = analyzer.analyze(dartSource, 'splash_screen.dart');

  if (model == null) {
    print('No widget found in source.');
    return;
  }

  print('Widget: ${model.className}');
  print('Type: ${model.widgetType}');
  print('Is page: ${model.isPage}');
  print('');

  // 2. Generate YAML at each verbosity level
  final yamlGenerator = YamlGenerator();

  for (final level in VerbosityLevel.values) {
    final yaml = yamlGenerator.generate(model, level);
    print('── $level ──');
    print(yaml);
  }

  // ── Reverse: YAML → Dart ──────────────────────────────

  final yaml = yamlGenerator.generate(model, VerbosityLevel.standard);

  // 3. Parse YAML back into a model
  final yamlParser = YamlParser();
  final reverseModel = yamlParser.parse(yaml, 'splash_screen.yaml');

  // 4. Generate Dart code from the model
  final dartGenerator = DartGenerator();
  final generatedDart = dartGenerator.generate(reverseModel);

  print('── Generated Dart (from YAML) ──');
  print(generatedDart);

  // ── File-level conversion ─────────────────────────────

  // Forward: convert file(s)
  // final converter = Converter();
  // converter.convertFile('lib/screens/splash.dart');
  // converter.convertDirectory('lib/screens/', recursive: true);

  // Reverse: convert YAML file(s) back to Dart
  // final reverseConverter = ReverseConverter();
  // reverseConverter.reverseFile('splash_screen.yaml');
  // reverseConverter.reverseDirectory('yaml_output/');

  // ── Token savings ─────────────────────────────────────

  final dartChars = dartSource.length;
  final yamlChars = yaml.length;
  final reduction = ((1 - yamlChars / dartChars) * 100).toStringAsFixed(1);
  print('── Token Savings ──');
  print('Dart: $dartChars chars → YAML: $yamlChars chars ($reduction% reduction)');
}
