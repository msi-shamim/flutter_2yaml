## 0.4.1

- **Reverse codegen: Container BoxDecoration** — `bg`, `br`, `border`, `shadow`, `gradient` properties on Container are now collected into a single `decoration: BoxDecoration(...)` instead of emitting raw properties
- **Per-corner border radius** — `br: {tl: 24, tr: 24, bl: 0, br: 0}` now generates `BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))` instead of invalid `BorderRadius.circular({...})`
- **Border shorthand expansion** — `border: {c: #121212, w: 1}` now generates `Border.all(color: Color(0xFF121212), width: 1)`
- **Shadow offset fix** — `shadow: {c: black, blur: 3, offset: Offset(0, 1)}` no longer crashes on nested commas inside `Offset()`; now uses paren-aware splitting
- **figma2flutter compatibility** — reverse codegen validated against real Figma plugin YAML output (full pages with Stack, Positioned, per-corner radii, shadows, borders)

## 0.4.0

- **Forward conversion hardened** — full Scaffold support with named children
- Named children model: `appBar`, `drawer`, `floatingActionButton`, `bottomNavigationBar`, `endDrawer`, `bottomSheet`, `leading`, `title`, `icon`, `label` all properly nested
- Expanded children list detection: `slivers`, `items`, `destinations`
- SpreadElement support in children lists (`...items`)
- ForElement support in children lists (`for (x in list) Widget()`)
- Ternary expression support (`condition ? WidgetA : WidgetB`)
- `ListView.builder` / `GridView.builder` itemBuilder pattern extraction
- BoxDecoration complete: `shape`, `border`, `image` extraction added
- Border.all shorthand: `Border.all(color: black, width: 2)` → `border: {c: black, w: 2}`
- Positioned widget shorthand: `top/left/right/bottom` → `t/l/r/b`
- TextStyle complete: `wordSpacing`, `height`, `decorationColor`, `decorationStyle`, `decorationThickness`, `overflow`
- Icons prefix stripped: `Icons.menu` → `menu`, `Icons.search` → `search`
- `double.infinity` → `full`
- Wrap spacing shorthand: `spacing` → `gap`, `runSpacing` → `runGap`
- Theme.of(context) shorthand: → `theme.textTheme.headline`
- MediaQuery shorthand: → `screen.w`, `screen.h`
- Multiple positional argument support with indexed tracking
- Complex screen test fixture with full Scaffold + AppBar + Drawer + FAB + BottomNav

## 0.3.0

- **Reverse conversion**: YAML → Dart via `flutter_2yaml reverse <path.yaml>`
- Full round-trip support: `.dart` → `.yaml` → `.dart` with idiomatic output
- YAML parser with pipe syntax, arrow notation, parenthetical alignment parsing
- Dart code generator producing properly formatted Flutter code
- Automatic `const` propagation, `super.key` constructors, `@override` annotations
- Reverse expansion of all shorthands (bg → backgroundColor, p → EdgeInsets.all, etc.)
- State class skeleton generation for StatefulWidget
- Lifecycle method generation with proper `super.` calls
- Directory-level reverse conversion with `--recursive` support
- Programmatic API: `YamlParser`, `DartGenerator`, `ReverseConverter`

## 0.2.0

- **Breaking**: Unified Compact Format — complete output format overhaul
- Pipe syntax for Text, Image, Icon widgets (`Text: "Hello" | 20 | bold | white`)
- CSS-like property shorthands (`bg`, `br`, `p`, `px`, `py`, `h`, `w`)
- Arrow callback notation (`onPressed → handleTap()`)
- Parenthetical alignment (`Column(center)`, `Row(spaceBetween)`)
- Color shorthand (`Colors.blue` → `blue`)
- Dimension shorthand (`200x200`, `w: full`)
- Auto-detect state management (GetX, Riverpod, Bloc, Provider)
- Auto-classify `page:` vs `widget:` based on Scaffold presence
- Compact inline state format (`state: [isLoading: bool = true]`)
- EdgeInsets shorthand (`EdgeInsets.all(16)` → `p: 16`)
- BoxDecoration shorthand (bg, br, shadow, gradient)
- Support for ConsumerWidget, GetView, and other framework base classes

## 0.1.0

- Initial release
- Convert Flutter StatelessWidget and StatefulWidget files to YAML
- Three verbosity levels: minimal, standard, full
- CLI support for single file and directory conversion
- Watch mode for automatic regeneration on file changes
- Configurable output directory
