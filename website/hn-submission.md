# Hacker News launch copy

## Submission

**Title**

Show HN: TypingPall – Practice code patterns by hand, even in the age of AI

**URL**

`https://typingpall.pages.dev/`

Use the deployed landing-page URL rather than a temporary preview URL. If a project domain is not ready, submit the GitHub repository URL instead:

`https://github.com/Mieraidihaimu/TypingPall`

## First comment

Hi HN — Fast trains exist, but runners still use treadmills. I think the same logic applies to writing code by hand in the age of AI.

AI generates code, but engineers still need the muscle memory of *how* a binary search narrows, *why* a mutex guards shared state, and *where* an off-by-one hides. These are mechanical and cognitive skills — they atrophy without deliberate practice, just like any other muscle.

So I made TypingPall: a native macOS app that keeps the full reference visible while you reproduce code one line at a time. It is a treadmill for code patterns.

What it does:

- Built-in lessons for algorithms (sliding window, BFS, DP), low-level design (factory, observer, LRU cache), and language idioms across Python, C++, Rust, and Go
- Recall mode hides the code, offers one-token hints, and lets you repeat a line or the whole pattern — no timer, no speed score
- Paste or import your own UTF-8 snippets to practice anything

What it is not:

- Not a typing speed trainer
- Not a coding challenge platform
- Not connected to the internet at all — SwiftUI, AppKit, Core Data, GPL-3.0, no account, no analytics

You can install it via Homebrew Cask:
`brew install --cask mieraidihaimu/tap/typingpall`

Or build from source with Xcode (macOS 12+). I would especially value feedback on whether this kind of deliberate practice is useful, which patterns are worth adding, and where the native macOS experience could be clearer. Small, focused contributions are very welcome.

Source and contribution guide: https://github.com/Mieraidihaimu/TypingPall

## Reply guidelines

- Answer concrete questions before redirecting people to the README.
- Be candid that this is source-built today; do not imply an App Store release.
- Do not ask for upvotes. Ask for critique, edge cases, and lesson ideas.
- Thank contributors, but discuss decisions rather than making vague promises.
- If someone challenges the premise ("AI makes this pointless"), engage thoughtfully — the treadmill analogy works because understanding is a different kind of value than output speed.
