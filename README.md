# flutter_2yaml

[![pub package](https://img.shields.io/pub/v/flutter_2yaml.svg)](https://pub.dev/packages/flutter_2yaml)
[![pub points](https://img.shields.io/pub/points/flutter_2yaml)](https://pub.dev/packages/flutter_2yaml/score)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart 3](https://img.shields.io/badge/Dart-3.8+-00B4AB.svg?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows-lightgrey)](https://pub.dev/packages/flutter_2yaml)

Convert Flutter `.dart` widget files into compact YAML representations optimized for LLM/AI token consumption. Supports **bidirectional conversion** — Dart to YAML and YAML back to Dart.

## Why?

When feeding Flutter code to AI models, full `.dart` files waste tokens on boilerplate — imports, `@override`, `super.key`, `BuildContext context`, `const` keywords, semicolons, brackets. **flutter_2yaml** strips all that and produces structured YAML using CSS-like shorthands, pipe syntax, and arrow notation — saving **50-70% tokens** on typical screens.

### Before (Dart — 45 lines)

```dart
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
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
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
```

### After (YAML — 14 lines, standard level)

```yaml
page: SplashScreen
type: StatefulWidget
state: [_isLoading: bool = true]
lifecycle:
  initState: [Future.delayed(3s)]
build:
  Scaffold:
    bg: white
    body:
      Center:
        child:
          Column(center):
            children:
              - Image.asset: assets/logo.png | 200x200
              - SizedBox: { h: 20 }
              - if _isLoading: CircularProgressIndicator: { color: blue }
```

## Compact Format Features

### Pipe Syntax `|`
```yaml
Text: "Hello World" | 20 | bold | white    # text | fontSize | fontWeight | color
Image.asset: logo.png | 200x200            # source | dimensions
Icon: search | onTap → goSearch()          # icon | callback
```

### CSS-Like Shorthands
| Shorthand | Flutter Equivalent |
|-----------|-------------------|
| `bg` | `backgroundColor` / `color` (in BoxDecoration) |
| `br` | `borderRadius: BorderRadius.circular(N)` |
| `p` | `padding: EdgeInsets.all(N)` |
| `px`, `py` | `EdgeInsets.symmetric(horizontal/vertical: N)` |
| `h`, `w` | `height`, `width` |
| `full` | `double.infinity` |
| `t`, `l`, `r`, `b` | `top`, `left`, `right`, `bottom` (Positioned) |
| `gap`, `runGap` | `spacing`, `runSpacing` (Wrap) |
| `shadow` | `boxShadow: [BoxShadow(...)]` |
| `border` | `Border.all(...)` → `{c: color, w: width}` |

### Arrow Callback Notation `→`
```yaml
onTap → goSearch()          # onTap: () => controller.goSearch()
onPressed → handleSubmit    # onPressed: handleSubmit
```

### Parenthetical Alignment
```yaml
Row(spaceBetween)     # Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)
Column(start)         # Column(crossAxisAlignment: CrossAxisAlignment.start)
Column(center)        # Column(mainAxisAlignment: MainAxisAlignment.center)
```

### Scaffold Named Children
```yaml
Scaffold:
  bg: white
  appBar:
    AppBar: { title: Text: "Home" | 20 | bold, bg: blue }
  drawer:
    Drawer: { ... }
  body:
    Center: { ... }
  floatingActionButton:
    FloatingActionButton: { onPressed → add(), child: Icon: add }
  bottomNavigationBar:
    BottomNavigationBar: { ... }
```

### Auto-Detection
- **Page vs Widget**: `page:` for Scaffold-containing widgets, `widget:` for components
- **State Management**: Auto-detects GetX, Riverpod, Bloc, Provider, MobX from imports
- **Color Shorthand**: `Colors.blue` → `blue`, `Color(0xFF123456)` → `#123456`
- **Icon Shorthand**: `Icons.menu` → `menu`, `Icons.search` → `search`
- **Dimension Shorthand**: `width: 80, height: 80` → `80x80`, `double.infinity` → `full`
- **Theme Shorthand**: `Theme.of(context).textTheme.headline` → `theme.headline`
- **MediaQuery Shorthand**: `MediaQuery.of(context).size.width` → `screen.w`

### Component References (figma2flutter)
```yaml
children:
  - <QuickAcess:Property 1=Default>           # Component with variant
  - <B-NavBar:Status=Home, Mode=Light>        # Multi-property variant
  - <B-NavBar>                                # Component without variant
```
Component tags (`<>`) are generated by the [figma2flutter](https://github.com/msi-shamim/figma2flutter) plugin. Full resolution requires the MCP server. Offline reverse produces `Text('ComponentName (Variant)')` placeholders with a warning.

### Collection Elements
```yaml
children:
  - ...items                                  # Spread operator
  - for(item in products): ProductCard: {}    # For-in loop
  - if _isLoading: CircularProgressIndicator  # Conditional
```

## Installation

```bash
dart pub global activate flutter_2yaml
```

Or add to your project's `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_2yaml: ^0.4.0
```

## Usage

### CLI — Forward (Dart → YAML)

```bash
# Convert a single file
flutter_2yaml lib/screens/splash_screen.dart

# Convert all .dart files in a directory
flutter_2yaml lib/screens/ --recursive

# Choose verbosity level
flutter_2yaml lib/screens/ --level minimal    # Widget tree only
flutter_2yaml lib/screens/ --level standard   # + state & lifecycle (default)
flutter_2yaml lib/screens/ --level full       # + imports, constructor, methods

# Custom output directory
flutter_2yaml lib/screens/ --output yaml_output/

# Watch mode — auto-regenerate on file changes
flutter_2yaml lib/screens/ --watch
```

### CLI — Reverse (YAML → Dart)

```bash
# Convert a single YAML file back to Dart
flutter_2yaml reverse splash_screen.yaml

# Convert a directory of YAML files
flutter_2yaml reverse yaml_output/ --recursive

# Custom output directory
flutter_2yaml reverse yaml_output/ --output lib/screens/
```

### Programmatic API

```dart
import 'package:flutter_2yaml/flutter_2yaml.dart';

// Forward: Dart → YAML
final analyzer = DartFileAnalyzer();
final model = analyzer.analyze(dartSource, 'my_widget.dart');
final yamlGenerator = YamlGenerator();
final yaml = yamlGenerator.generate(model!, VerbosityLevel.standard);

// Reverse: YAML → Dart
final yamlParser = YamlParser();
final reverseModel = yamlParser.parse(yamlSource, 'my_widget.yaml');
final dartGenerator = DartGenerator();
final dartCode = dartGenerator.generate(reverseModel);

// File-level conversion
final converter = Converter();
converter.convertFile('lib/screens/home.dart');

final reverseConverter = ReverseConverter();
reverseConverter.reverseFile('home.yaml');
```

## Verbosity Levels

| Level | Includes | Use Case |
|-------|----------|----------|
| `minimal` | Widget tree + shorthands | Quick UI structure overview |
| `standard` | + state, lifecycle | Full widget understanding (default) |
| `full` | + imports, constructor, all methods | Complete file representation |

## Supported Widget Types

- `StatelessWidget`, `StatefulWidget`
- `ConsumerWidget`, `ConsumerStatefulWidget` (Riverpod)
- `GetView`, `GetWidget` (GetX)
- Non-widget classes are automatically skipped

## Supported Widget Features

- Scaffold with all named slots (appBar, drawer, FAB, bottomNav, etc.)
- Container with BoxDecoration (bg, br, shadow, gradient, border, shape)
- Stack + Positioned with coordinate shorthands
- ListView.builder / GridView.builder (itemBuilder extraction)
- Wrap with spacing shorthands
- Text with full TextStyle pipe syntax
- Conditional children (`if` / `if-else`)
- Spread and for-in elements in children lists
- All callback types with arrow notation

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.
