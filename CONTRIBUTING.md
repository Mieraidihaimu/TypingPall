# Contributing to TypingPall

Thanks for helping make code practice clearer and more useful. Contributions can be small: a reproducible bug report, a better lesson explanation, an accessibility fix, or a focused pull request.

## Pick a useful change

- **Report a bug:** include the macOS version, app version or commit, steps to reproduce, and expected behavior. A short sample pattern helps with input issues.
- **Suggest a lesson:** describe the pattern, language, learning focus, and why it belongs in a short practice session.
- **Improve the app:** keep the line-by-line practice flow simple. Discuss larger product or architecture changes in an issue before implementing them.

## Run locally

Fork and clone the repository, open `TypingPall.xcodeproj` in full Xcode, and run the **TypingPall** scheme on **My Mac**. The deployment target is macOS 12; there are no third-party runtime dependencies.

Useful places to start:

| Area | Location |
| --- | --- |
| Practice flow and progress | `TypingPall/Views/TypingScreenView/` |
| Active native editor | `TypingPall/Views/Editor/TextKit2TypingEditor.swift` |
| Lesson catalog and comment filtering | `TypingPall/Models/PracticeContent.swift` |
| Modular practice library | `library/lessons/` |
| Built-in catalog bundle | `TypingPall/Content/lessons.json` |
| Library CLI & authoring tool | `scripts/library.py` |
| Saved scripts and migration | `TypingPall/Persistence.swift` |
| Tests | `TypingPallTests/` and `TypingPallUITests/` |

Earlier editor and statistics experiments remain outside the app's Sources phase. Use the active source files above for current behavior.

## Add or improve a lesson

TypingPall organizes lessons in modular files under `library/lessons/<track>/<id>.json`, making it easy to create focused pull requests with clean diffs and zero merge conflicts. See [library/README.md](library/README.md) for full details.

Each lesson has a unique `id`, a short `title`, a `category`, a `track` (`leetcode`, `lowLevelDesign`, `languages`, or a new track like `algorithms`), a supported `language` (`python`, `cpp`, `rust`, `go`, `swift`, `typescript`, `sql`, etc.), a `summary`, and `code`.

### 1. Ingest from normal code (Fastest)

Write normal code with assertions at the bottom, then run:
```sh
python3 scripts/library.py ingest path/to/solution.py
# Or pipe from clipboard:
pbpaste | python3 scripts/library.py ingest
```

This automatically extracts code and assertions, generates key lines and a verified planted-bug mutation, compiles the catalog, and validates everything in one step.

### 2. Or use the interactive wizard / flags

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

### 3. Validate and build

```sh
python3 scripts/library.py validate
python3 scripts/library.py build
```

This compiles your changes from `library/lessons/` into `TypingPall/Content/lessons.json`.

### Guidelines for lesson content

Write original examples that focus on one idea and fit comfortably into a practice session. Explain non-obvious behavior in comments and state complexity only when it is accurate. Avoid copying proprietary problem statements or solutions. C++, Rust, and Go examples should be runnable programs; Python examples should be safe to import.

LeetCode and low-level design lessons also carry optional recall metadata: `family`, `triggers`, `prompts`, `invariant`, `mantra`, `pitfalls`, `anchors` (`name`, `trick`), `keyLineIndices`, `scaffoldLineIndices`, `contrastWith`, `complexity` (`time`, `space`) and `mutations` (`line`, `replacement`, `explanation`). Omit a field rather than leaving it empty.

- Prompts are original scenarios: no problem statements, examples or constraints. Anchors name public problems only.
- Line indices are 0-based into `code`. `keyLineIndices` and mutation lines must be typed lines: not blank, not a comment, not scaffold. Scaffold lines are shown but never typed.
- Each `mutations` entry keeps the line's indentation and must fail the lesson's check; `check_lessons.py` runs every planted bug.
- `contrastWith` links must be mutual.
- UI tests rely on the "Sliding window" title and code, and on the monotonic-stack lesson's "next greater" trigger.

Add a check in `scripts/check_lessons.py` (Python) or an `EXPECTED` output (C++/Rust/Go).

```sh
python3 scripts/check_lessons.py --require-all
```

This validates bundled examples, compiles C++/Go/Rust, and executes the resulting programs. It requires Python 3.9+, `clang++`, `go`, and `rustc`. Without `--require-all`, unavailable compilers are reported as skipped. The app itself never executes imported scripts.

## Validate a pull request

```sh
./scripts/check.sh
```

This runs unit and UI tests, then builds Release for Apple silicon and Intel. UI tests need a logged-in desktop and automation permission. If UI automation is unavailable, run `./scripts/check.sh -only-testing:TypingPallTests` and say which checks you could not run.

Keep changes focused, describe the user-visible result, and include relevant validation. For interface changes, attach a current screenshot. For typing changes, consider Unicode, deletion, Return, indentation, and repeating a line. Preserve saved libraries when changing persistence.

By contributing, you agree that your contributions are provided under the repository's [GPL-3.0 license](LICENSE).
