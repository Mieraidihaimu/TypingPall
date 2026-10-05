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

## Fastest Way: One-Command Ingestion (`ingest`)

Write your code normally in Python with assertions at the bottom:

```python
# Fixed window counter rate limiter.
class FixedWindowCounter:
    def __init__(self, limit, window_seconds):
        self.limit = limit
        self.window = window_seconds
        self.counts = {}

    def allow(self, user_id, timestamp):
        window_id = int(timestamp // self.window)
        key = (user_id, window_id)
        current = self.counts.get(key, 0)
        if current >= self.limit:
            return False
        self.counts[key] = current + 1
        return True

if __name__ == '__main__':
    limiter = FixedWindowCounter(2, 60)
    assert limiter.allow('alice', 10) == True
    assert limiter.allow('alice', 20) == True
    assert limiter.allow('alice', 30) == False
```

Then run:
```sh
python3 scripts/library.py ingest path/to/my_pattern.py
# Or pipe from clipboard:
pbpaste | python3 scripts/library.py ingest
```

The CLI tool will automatically:
1. Extract the code and separate the test assertions.
2. Extract the summary from the top comment and title from the class/function.
3. Automatically select the best `keyLineIndices`.
4. Generate a verified planted-bug mutation.
5. Save the self-contained JSON with `"test": [...]`.
6. Rebuild and validate the entire library.

## Adding a Lesson Manually or Interactively

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
  "keyLineIndices": [7, 8, 9],
  "test": [
    "assert longest_unique('abcabcbb') == 3",
    "assert longest_unique('bbbbb') == 1"
  ]
}
```

### Key Highlights:
- **Self-Contained Tests**: With `"test": [...]` in your JSON, you never have to edit `scripts/check_lessons.py`. The test suite automatically runs and validates your lesson and its planted bugs.
- **Clean Git Diffs**: Code is stored as an array of string lines or in a separate file via `"codeFile"`. In pull requests, reviewers see real, clean lines instead of escaped `\n` characters.
- **Zero Merge Conflicts**: Each lesson is isolated in its own file. Multiple PRs adding lessons won't conflict with each other.
- **Line Indices**: Line indices (`keyLineIndices`, `scaffoldLineIndices`, `mutations`) are 0-based array indices into `code`.
- **Extensible Tracks & Languages**: Tracks and languages are dynamically handled by the app. Adding new tracks (e.g. `algorithms`, `systemDesign`) or languages (e.g. `swift`, `typescript`, `sql`) works out of the box.

## CLI Commands

| Command | Description |
| --- | --- |
| `python3 scripts/library.py ingest [file]` | **Instant 1-command ingestion**: parses code, extracts test, generates mutation, builds, and validates |
| `python3 scripts/library.py add` | Interactive wizard to scaffold and add a lesson |
| `python3 scripts/library.py build` | Compiles `library/lessons/` into `TypingPall/Content/lessons.json` |
| `python3 scripts/library.py build --check` | Verifies `lessons.json` is synchronized with modular files |
| `python3 scripts/library.py validate` | Checks schema, mutual contrast links, and line indices |
| `python3 scripts/library.py stats` | Prints catalog counts and statistics |
