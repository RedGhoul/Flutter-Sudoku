# CLAUDE.md - Flutter Sudoku AI Development Guide

> Last Updated: 2025-11-16
> Version: 2.4.1

## Project Overview

Flutter-Sudoku is a fully-fledged cross-platform Sudoku game written in Dart using Flutter. The project supports multiple platforms including Android, iOS, Web (PWA), Windows, Linux, and macOS.

**Key Facts:**
- **Main Directory:** `/sudoku/` (all Flutter code lives here)
- **Source Code:** `sudoku/lib/`
- **Current Version:** 2.4.1 (see `main.dart:27`)
- **License:** GPL v3
- **Platforms:** Android, iOS, Web, Windows, Linux, macOS, Fuchsia
- **Live Demo:** https://sudoku-vs2002.web.app/

## Codebase Structure

### Directory Layout

```
Flutter-Sudoku/
├── README.md                    # User-facing documentation
├── CLAUDE.md                    # This file - AI assistant guide
└── sudoku/                      # Main Flutter application
    ├── lib/                     # Dart source code
    │   ├── main.dart           # Entry point & HomePage
    │   ├── splash_screen_page.dart
    │   ├── styles.dart         # Color system & theming
    │   ├── board_style.dart    # Sudoku board styling utilities
    │   ├── material_color_generator.dart
    │   └── alerts/             # Dialog components (modular)
    │       ├── all.dart        # Barrel file (exports all alerts)
    │       ├── about.dart
    │       ├── accent_colors.dart
    │       ├── difficulty.dart
    │       ├── exit.dart
    │       ├── game_over.dart
    │       └── numbers.dart
    ├── assets/                  # Images and resources
    │   └── icon/
    ├── android/                 # Android-specific code
    ├── web/                     # Web-specific code
    ├── windows/                 # Windows-specific code
    ├── pubspec.yaml            # Dependencies & metadata
    ├── analysis_options.yaml   # Dart linter configuration
    └── flutter_native_splash.yaml
```

### Key Files Reference

| File | Purpose | Key Elements |
|------|---------|--------------|
| `main.dart` | App entry point, game state, UI | `HomePageState`, game logic, platform detection |
| `styles.dart` | Theme & color definitions | Material color palettes, accent colors map |
| `board_style.dart` | Board rendering utilities | Button sizing, colors, borders |
| `alerts/all.dart` | Module exports | Barrel file pattern |
| `pubspec.yaml` | Dependencies & config | Package versions, assets |

## Architecture & Code Organization

### Recent Refactoring Patterns

The codebase follows a **modular extraction pattern**. Recent commits show:

1. **Utility Extraction** (commit `9e5a98e`): Board styling functions moved from `main.dart` → `board_style.dart`
2. **Module Splitting** (commit `54ec791`): Large `alerts.dart` split into individual files in `alerts/` directory
3. **Barrel Files**: `alerts/all.dart` exports all alert components

### Code Organization Principles

1. **Single Responsibility:** Each file has a clear, focused purpose
2. **Barrel Exports:** Use `all.dart` files for module exports
3. **Utility Functions:** Extract reusable logic into dedicated files
4. **Platform Awareness:** Code adapts to platform (mobile vs desktop vs web)

### Component Structure

**Alert Dialog Pattern:**
```dart
// alerts/numbers.dart
class AlertNumbersState extends StatefulWidget { ... }
class AlertNumbers extends State<AlertNumbersState> { ... }
```

**Export Pattern:**
```dart
// alerts/all.dart
export 'about.dart';
export 'accent_colors.dart';
export 'difficulty.dart';
// ... etc
```

## Development Workflows

### Working Directory

**CRITICAL:** All Flutter commands must run from the `sudoku/` directory, not the repository root.

```bash
cd /home/user/Flutter-Sudoku/sudoku
```

### Building for Different Platforms

#### Web (PWA)
```bash
cd sudoku
flutter config --enable-web
flutter build web --release
# Output: sudoku/build/web/
```

#### Android
```bash
cd sudoku
# Single APK for all ABIs:
flutter build apk

# Split APKs per ABI (recommended for production):
flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi
# Output: sudoku/build/app/outputs/flutter-apk/
```

#### Windows
```bash
cd sudoku
flutter config --enable-windows-desktop
flutter build windows --release
# Output: sudoku/build/windows/runner/Release/
```

### Package Management

```bash
cd sudoku
flutter pub get          # Install dependencies
flutter pub upgrade      # Upgrade to latest compatible versions
flutter pub outdated     # Check for newer versions
flutter doctor          # Verify environment setup
```

### Testing & Linting

```bash
cd sudoku
flutter analyze         # Run Dart analyzer
flutter test           # Run tests (when available)
```

## Dependencies

### Core Dependencies (from `pubspec.yaml`)

| Package | Version | Purpose |
|---------|---------|---------|
| `sudoku_solver_generator` | ^2.1.0+1 | Sudoku generation & solving logic |
| `shared_preferences` | ^2.0.15 | Local preference storage |
| `flutter_animated_dialog` | ^2.0.1 | Animated dialog animations |
| `splashscreen` | git (custom fork) | App splash screen |
| `flutter_native_splash` | ^2.2.3+1 | Native splash screen generation (dev) |
| `url_launcher` | ^6.1.4 | Opening external links |
| `bitsdojo_window` | ^0.1.2 | Desktop window customization |

### Dev Dependencies

- `flutter_lints: ^2.0.1` - Recommended linting rules
- `flutter_native_splash: ^2.2.3+1` - Splash screen asset generation

## Code Conventions

### Theming System

**Location:** `lib/styles.dart`

The app uses a comprehensive custom color system:

- **Background Colors:** `darkGrey` (dark theme), `white` (light theme)
- **Accent Colors:** 9 predefined MaterialColors (Cyan, Blue, Indigo, Violet, Purple, Pink, Red, Orange, Green)
- **Color Format:** All colors defined as `MaterialColor` with shades 50-900

**Usage Pattern:**
```dart
Styles.primaryColor        // Current accent color
Styles.primaryBackgroundColor  // Dark grey or white
Styles.foregroundColor     // Text color
Styles.accentColors        // Map of available accent colors
```

### Platform Detection

**Location:** `main.dart:62-72`

```dart
static String platform = () {
  if (kIsWeb) {
    return 'web-${defaultTargetPlatform.toString()...}';
  } else {
    return defaultTargetPlatform.toString()...;
  }
}();
static bool isDesktop = ['windows', 'linux', 'macos'].contains(platform);
```

**Key Points:**
- Web platforms prefixed with `web-`
- Desktop detection for layout adjustments
- Mobile vs Desktop sizing (see `board_style.dart:26-42`)

### State Management

- **Primary Pattern:** StatefulWidget with manual state management
- **Persistence:** SharedPreferences for user settings (theme, difficulty, accent color)
- **Game State:** Maintained in `HomePageState` class

### Naming Conventions

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables:** `camelCase`
- **Constants:** `camelCase` (static final)
- **Private:** Prefix with `_` (standard Dart convention)

### Import Organization

Standard order in files:
1. Dart core libraries (`dart:async`, `dart:core`)
2. Flutter packages (`package:flutter/...`)
3. Third-party packages (`package:...`)
4. Local imports (relative paths)

Example from `main.dart:1-14`:
```dart
import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ... other packages

import 'alerts/all.dart';
import 'board_style.dart';
// ... other local imports
```

## Git Workflow

### Branching Strategy

- **Main Branch:** `master` (implied from README badges)
- **Feature Branches:** Use descriptive names
- **Current Branch:** `claude/claude-md-mi200rhocdj4me60-01GeNHkdoQiD9ZypY3tkz9VH`

### Commit Message Style

Based on recent commits, follow these patterns:

- **Refactoring:** "Extracted [feature] to [file] from [source]"
  - Example: "Extracted sudoku board style related functions to board_style.dart from main.dart"

- **Splitting:** "Split [file] into multiple files and exported everything from [barrel]"
  - Example: "Split alerts.dart into multiple files and exported everything from alerts/all.dart"

- **Features:** "Added [feature]"
  - Example: "Added vector icons"

- **Updates:** "Updated [component]"
  - Example: "Updated .metadata"

- **Multi-action:** Use braces for detailed changes
  - Example: "Recreate android files Improved app/build.gradle { Bumped minSdkVersion to 21... }"

### Commit Guidelines for AI Assistants

1. **Be Descriptive:** Clearly state what changed and why
2. **Group Related Changes:** Use braces `{ }` for detailed sub-items
3. **Reference Files:** Mention specific files that changed
4. **Action Verbs:** Start with: Added, Updated, Fixed, Extracted, Split, Improved, Optimized
5. **No Periods:** Don't end commit messages with periods

## Common Tasks for AI Assistants

### 1. Adding New Alert Dialogs

**Pattern to Follow:**
```bash
# 1. Create new file in alerts/
sudoku/lib/alerts/my_new_alert.dart

# 2. Follow existing structure (see alerts/numbers.dart)
# 3. Export from alerts/all.dart
export 'my_new_alert.dart';

# 4. Import in main.dart (already using barrel import)
import 'alerts/all.dart';  // Already present
```

### 2. Extracting Utilities from main.dart

**When main.dart gets too large:**
1. Identify cohesive function groups
2. Create new file: `sudoku/lib/[utility_name].dart`
3. Move functions to new file
4. Add imports: `import '[utility_name].dart';` in main.dart
5. Commit: "Extracted [functionality] to [file] from main.dart"

### 3. Adding New Accent Colors

**Location:** `styles.dart`

1. Define MaterialColor constant (follow existing pattern)
2. Add to `accentColors` map (line 192-202)
3. Update `alerts/accent_colors.dart` if UI changes needed

### 4. Modifying Game Logic

**Key Areas:**
- Game generation: Uses `sudoku_solver_generator` package
- Game state: `HomePageState` in `main.dart`
- Board rendering: `main.dart` + `board_style.dart`
- Difficulty levels: See `main.dart` and `alerts/difficulty.dart`

**Difficulty Mapping:**
- Beginner: 18 empty squares
- Easy: 27 empty squares
- Medium: 36 empty squares
- Hard: 54 empty squares

### 5. Platform-Specific Changes

**Before making platform-specific changes:**
1. Check current platform: `HomePageState.platform`
2. Use conditional logic: `isDesktop` flag
3. Test responsive sizing (see `board_style.dart:26-42`)

### 6. Testing Changes

```bash
cd sudoku

# Web testing
flutter run -d chrome

# Android emulator
flutter run -d emulator-5554

# Windows desktop
flutter run -d windows

# Hot reload is available during development
```

## Linting & Code Quality

**Configuration:** `sudoku/analysis_options.yaml`

- Uses `package:flutter_lints/flutter.yaml` (official Flutter lints)
- Enforces best practices
- Run before committing: `flutter analyze`

**Common Lint Suppressions in Codebase:**
- `// ignore: empty_catches` - Used in main.dart:82 for platform-specific code
- `// ignore: avoid_init_to_null` - Used in alerts/numbers.dart:21

## Asset Management

**Location:** `sudoku/assets/icon/`

**Configured in pubspec.yaml:**
```yaml
assets:
  - assets/icon/icon_foreground.png
  - assets/icon/icon_round.png
```

**Adding New Assets:**
1. Place in `sudoku/assets/[category]/`
2. Update `pubspec.yaml` under `flutter: > assets:`
3. Reference in code: `'assets/[category]/[filename]'`

## Important Notes for AI Assistants

### DO:
- ✅ Run all Flutter commands from `sudoku/` directory
- ✅ Follow the modular extraction pattern when refactoring
- ✅ Use barrel files (`all.dart`) for module exports
- ✅ Check platform compatibility for new features
- ✅ Test on multiple platforms when possible
- ✅ Run `flutter analyze` before committing
- ✅ Use descriptive commit messages following project style
- ✅ Maintain the existing Material Design patterns
- ✅ Preserve responsive sizing for mobile/desktop
- ✅ Update version in `main.dart` when making releases

### DON'T:
- ❌ Run Flutter commands from repository root
- ❌ Create monolithic files (split when >200 lines)
- ❌ Hardcode platform-specific values (use detection)
- ❌ Skip imports (use barrel imports where available)
- ❌ Modify generated files (e.g., `lib/generated_plugin_registrant.dart`)
- ❌ Change core dependencies without testing
- ❌ Break existing theme system
- ❌ Ignore lint warnings
- ❌ Commit build artifacts (`/build/` is gitignored)
- ❌ Test only on one platform

### Platform-Specific Gotchas:

1. **Windows:** Requires `bitsdojo_window` initialization in `main.dart:78-83`
2. **Web:** Some packages may not work (check compatibility)
3. **Android:** Minimum SDK 21 (Lollipop), target SDK is dynamic
4. **iOS/macOS:** Untested - changes may be needed

## Build & Release Process

### Version Numbering

**Format:** `major.minor.patch+build`
**Current:** `2.4.1+2041` (in `pubspec.yaml:18`)

**Update locations when releasing:**
1. `sudoku/pubspec.yaml` (line 18)
2. `main.dart` (line 27 - display version)
3. Update README badges if needed

### Release Checklist

1. Update version numbers
2. Run `flutter pub get`
3. Run `flutter analyze` (ensure no issues)
4. Test on target platforms
5. Build release artifacts:
   - Web: `flutter build web --release`
   - Android: `flutter build apk --split-per-abi`
   - Windows: `flutter build windows --release`
6. Test built artifacts
7. Create git tag: `git tag -a vX.X.X -m "Version X.X.X"`
8. Update README download links

### Native Splash Screen

**Configuration:** `flutter_native_splash.yaml`

Regenerate after icon changes:
```bash
cd sudoku
flutter pub run flutter_native_splash:create
```

## Troubleshooting

### Common Issues

**Issue:** "Target file doesn't exist"
**Solution:** Ensure you're in `sudoku/` directory, not repository root

**Issue:** Build fails with platform not enabled
**Solution:** Run `flutter config --enable-[platform]` first

**Issue:** Hot reload not working
**Solution:** Full restart: press `R` in terminal or stop/start

**Issue:** Package version conflicts
**Solution:**
```bash
flutter pub upgrade
flutter pub get
```

**Issue:** Platform-specific imports failing
**Solution:** Check conditional imports and platform availability

## Additional Resources

- **Flutter Docs:** https://flutter.dev/docs
- **Dart Docs:** https://dart.dev/guides
- **Package Repository:** https://pub.dev/
- **Project Issues:** https://github.com/VarunS2002/Flutter-Sudoku/issues
- **Live Demo:** https://sudoku-vs2002.web.app/

## Development Philosophy

This project prioritizes:
1. **Cross-platform compatibility** - Works everywhere Flutter runs
2. **Material Design** - Follows Google's design system
3. **Modularity** - Code organized into focused, reusable components
4. **User experience** - Smooth animations, responsive UI
5. **Simplicity** - Clean code over complex abstractions

## Conclusion

When working on this codebase:
- **Understand the structure** before making changes
- **Follow established patterns** for consistency
- **Test across platforms** when possible
- **Keep commits atomic** and well-documented
- **Ask questions** if unclear about architecture decisions

This codebase is well-organized and actively maintained. Respect the existing patterns, and your contributions will integrate smoothly.

---

**Generated by:** Claude AI Assistant
**For questions:** Check project README or open a GitHub issue
