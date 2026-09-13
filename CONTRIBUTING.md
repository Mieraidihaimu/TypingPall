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
| Built-in examples | `TypingPall/Content/lessons.json` |
| Saved scripts and migration | `TypingPall/Persistence.swift` |
| Tests | `TypingPallTests/` and `TypingPallUITests/` |

Earlier editor and statistics experiments remain outside the app's Sources phase. Use the active source files above for current behavior.

## Add or improve a lesson

Each entry in `lessons.json` has a unique `id`, a short `title`, a `category`, a supported `language` (`python`, `cpp`, `rust`, or `go`), a `summary`, and `code`.

Write original examples that focus on one idea and fit comfortably into a practice session. Explain non-obvious behavior in comments and state complexity only when it is accurate. Avoid copying proprietary problem statements or solutions. C++, Rust, and Go examples should be runnable programs; Python examples should be safe to import.

Add meaningful behavior checks in `scripts/check_lessons.py`. When adding a lesson, update the catalog count assertions, affected README totals, and tests in `TypingPallTests/StringExtensionTests.swift`.

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
