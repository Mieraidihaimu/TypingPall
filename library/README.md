# TypingPall Practice Library

This directory contains the modular source files for TypingPall's built-in practice catalog.

## Directory Structure

```text
library/
├── manifest.json                  # Order and list of tracks
├── README.md                      # This documentation
└── lessons/
    ├── leetcode/                  # Track folder
    │   ├── track.json             # Categories order in this track
    │   ├── py-sliding-window.json # Individual lesson file
    │   └── ...
    ├── lowLevelDesign/
    │   ├── track.json
    │   ├── py-builder.json
    │   └── ...
    └── languages/
        ├── track.json
        ├── cpp-vectors.json
        └── ...
```

## Adding a Lesson in 3 Steps

### 1. Run the interactive wizard or command
```sh
python3 scripts/library.py add
```
Or pass arguments directly:
```sh
python3 scripts/library.py add \
  --track leetcode \
  --category "Sliding window" \
  --title "Longest Substring Without Repeating Characters" \
  --language python \
  --summary "Sliding window with last-seen hash map. O(n)." \
  --code-file path/to/solution.py
```

### 2. Validate your lesson
```sh
python3 scripts/library.py validate
```

### 3. Rebuild the catalog & test
```sh
python3 scripts/library.py build
python3 scripts/check_lessons.py
```

## Lesson File Schema

Each lesson is stored as `library/lessons/<track>/<id>.json`:

```json
{
  "id": "py-sliding-window",
  "title": "Sliding window",
  "category": "Python interview patterns",
  "track": "leetcode",
  "language": "python",
  "summary": "Longest run of text with no repeated character. O(n).",
  "code": [
    "# Keep a window with no repeated characters.",
    "def longest_unique(text):",
    "    last_seen = {}",
    "    left = 0",
    "    ...",
    "    return best"
  ],
  "family": "sliding-window",
  "triggers": [
    "longest or shortest contiguous substring or subarray under a constraint"
  ],
  "keyLineIndices": [7, 8, 9]
}
```

### Key Highlights:
- **Clean Git Diffs**: Code is stored as an array of string lines or in a separate file via `"codeFile"`. In pull requests, reviewers see real, clean lines instead of escaped `\n` characters.
- **Zero Merge Conflicts**: Each lesson is isolated in its own file. Multiple PRs adding lessons won't conflict with each other.
- **Line Indices**: Line indices (`keyLineIndices`, `scaffoldLineIndices`, `mutations`) are 0-based array indices into `code`.
- **Extensible Tracks & Languages**: Tracks and languages are dynamically handled by the app. Adding new tracks (e.g. `algorithms`, `systemDesign`) or languages (e.g. `swift`, `typescript`, `sql`) works out of the box.

## CLI Commands

| Command | Description |
| --- | --- |
| `python3 scripts/library.py add` | Interactive wizard to scaffold and add a lesson |
| `python3 scripts/library.py build` | Compiles `library/lessons/` into `TypingPall/Content/lessons.json` |
| `python3 scripts/library.py build --check` | Verifies `lessons.json` is synchronized with modular files |
| `python3 scripts/library.py validate` | Checks schema, mutual contrast links, and line indices |
| `python3 scripts/library.py stats` | Prints catalog counts and statistics |
