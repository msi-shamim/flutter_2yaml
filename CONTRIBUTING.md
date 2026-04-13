# Contributing to flutter_2yaml

Thank you for your interest in contributing! This guide will help you get started.

## Development Setup

```bash
git clone https://github.com/msi-shamim/flutter_2yaml.git
cd flutter_2yaml
dart pub get
```

## Running Tests

```bash
dart test
```

## Code Style

- Follow Dart conventions and the existing code patterns
- Run `dart analyze` before submitting — zero warnings required
- Run `dart format .` to ensure consistent formatting

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/msi-shamim/flutter_2yaml/issues) first
2. Create a new issue with the **Bug Report** template
3. Include: steps to reproduce, expected behavior, actual behavior, environment info

### Suggesting Features

1. Check [existing issues](https://github.com/msi-shamim/flutter_2yaml/issues) for similar requests
2. Create a new issue with the **Feature Request** template
3. Describe the problem, proposed solution, and alternatives considered

### Submitting Code

1. Fork the repository
2. Create a feature branch from `main` (`git checkout -b feat/my-feature`)
3. Make your changes
4. Add or update tests as needed
5. Ensure all checks pass: `dart analyze && dart test`
6. Commit with conventional messages (`feat:`, `fix:`, `docs:`, `chore:`)
7. Push and open a Pull Request

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add support for CustomScrollView slivers`
- `fix: resolve TextStyle pipe parsing for partial styles`
- `docs: update README with new shorthand table`
- `chore: bump dependencies`
- `refactor: simplify widget visitor post-processing`
- `test: add round-trip tests for complex screens`

## Architecture

The package has two conversion pipelines:

**Forward (Dart → YAML):**
```
.dart → DartFileAnalyzer → DartFileModel → YamlGenerator → .yaml
```

**Reverse (YAML → Dart):**
```
.yaml → YamlParser → DartFileModel → DartGenerator → .dart
```

Key directories:
- `lib/src/analyzer/` — AST parsing (widget_visitor, state_visitor)
- `lib/src/generator/` — Output generation (yaml_generator, dart_generator, shorthand_map)
- `lib/src/parser/` — YAML parsing (yaml_parser, widget_parser, pipe_parser)
- `lib/src/models/` — Shared data models (DartFileModel, WidgetNode, StateModel)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.
