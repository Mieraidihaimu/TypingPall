#!/usr/bin/env python3
"""TypingPall Library Management CLI

Streamlines adding, splitting, building, validating, and inspecting practice lessons.
Supports modular lesson files under library/lessons/<track>/<id>.json.
"""

import argparse
import difflib
import json
import os
from pathlib import Path
import re
import sys
import types
from typing import Any, Dict, List, Optional, Set, Tuple

ROOT = Path(__file__).resolve().parents[1]
CONTENT_LESSONS_PATH = ROOT / "TypingPall" / "Content" / "lessons.json"
LIBRARY_DIR = ROOT / "library"
LESSONS_DIR = LIBRARY_DIR / "lessons"
MANIFEST_PATH = LIBRARY_DIR / "manifest.json"

SUPPORTED_LANGUAGES = [
    "python", "cpp", "rust", "go", "ruby", "shell",
    "swift", "javascript", "typescript", "sql", "java", "kotlin", "plainText"
]

DEFAULT_TRACKS = ["leetcode", "lowLevelDesign", "languages"]


def get_indentation(line: str) -> str:
    return line[:len(line) - len(line.lstrip())]


def comment_prefix_for(language: str) -> str:
    if language in ("python", "ruby", "shell"):
        return "#"
    elif language == "sql":
        return "--"
    return "//"


def typed_line_indices(code_lines: List[str], language: str, scaffold_indices: Optional[List[int]] = None) -> Set[int]:
    comment = comment_prefix_for(language)
    scaffold = set(scaffold_indices or [])
    typed = set()
    for idx, line in enumerate(code_lines):
        stripped = line.strip()
        if stripped and not stripped.startswith(comment) and idx not in scaffold:
            typed.add(idx)
    return typed


def normalize_code_to_lines(code_val: Any, base_dir: Path) -> List[str]:
    if isinstance(code_val, list):
        return [str(l) for l in code_val]
    elif isinstance(code_val, str):
        return code_val.split("\n")
    raise ValueError(f"Invalid code type: {type(code_val)}")


def resolve_lesson_code(lesson_data: Dict[str, Any], lesson_file_dir: Path) -> Tuple[str, List[str]]:
    """Returns (code_as_string, code_as_lines)."""
    if "codeFile" in lesson_data:
        code_file = lesson_file_dir / lesson_data["codeFile"]
        if not code_file.exists():
            raise FileNotFoundError(f"Referenced codeFile not found: {code_file}")
        code_str = code_file.read_text(encoding="utf-8")
        return code_str, code_str.split("\n")
    elif "code" in lesson_data:
        code_val = lesson_data["code"]
        if isinstance(code_val, list):
            lines = [str(l) for l in code_val]
            return "\n".join(lines), lines
        elif isinstance(code_val, str):
            return code_val, code_val.split("\n")
    raise ValueError(f"Lesson {lesson_data.get('id', 'unknown')} must contain 'code' or 'codeFile'")


# ==========================================
# COMMAND: split
# ==========================================
def cmd_split(args: argparse.Namespace) -> None:
    """Split TypingPall/Content/lessons.json into modular files under library/lessons/."""
    if not CONTENT_LESSONS_PATH.exists():
        print(f"Error: {CONTENT_LESSONS_PATH} not found.", file=sys.stderr)
        sys.exit(1)

    print(f"Reading monolithic catalog from {CONTENT_LESSONS_PATH}...")
    lessons = json.loads(CONTENT_LESSONS_PATH.read_text(encoding="utf-8"))
    print(f"Loaded {len(lessons)} lessons.")

    LESSONS_DIR.mkdir(parents=True, exist_ok=True)

    tracks_order: List[str] = []
    track_categories: Dict[str, List[str]] = {}
    track_counts: Dict[str, int] = {}

    for idx, lesson in enumerate(lessons):
        track = lesson["track"]
        cat = lesson["category"]
        if track not in tracks_order:
            tracks_order.append(track)
            track_categories[track] = []
            track_counts[track] = 0

        if cat not in track_categories[track]:
            track_categories[track].append(cat)

        track_dir = LESSONS_DIR / track
        track_dir.mkdir(parents=True, exist_ok=True)

        lesson_copy = dict(lesson)
        # Format code as list of lines for readability in git diffs
        if isinstance(lesson_copy.get("code"), str):
            lesson_copy["code"] = lesson_copy["code"].split("\n")

        # Assign explicit order to guarantee stable re-building
        lesson_copy["order"] = idx + 1

        dest_file = track_dir / f"{lesson['id']}.json"
        dest_file.write_text(json.dumps(lesson_copy, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        track_counts[track] += 1

    # Write manifest.json
    manifest = {
        "tracks": tracks_order,
        "description": "TypingPall practice lessons modular catalog manifest"
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Write track.json in each track dir
    for track in tracks_order:
        track_meta = {
            "track": track,
            "categories": track_categories[track]
        }
        (LESSONS_DIR / track / "track.json").write_text(
            json.dumps(track_meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    print(f"SUCCESS: Split {len(lessons)} lessons into {LESSONS_DIR}:")
    for track in tracks_order:
        print(f"  • {track}: {track_counts[track]} lessons across {len(track_categories[track])} categories")
    print(f"Manifest written to {MANIFEST_PATH}")


# ==========================================
# COMMAND: build
# ==========================================
def load_all_modular_lessons() -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """Loads all modular lesson files, returns (sorted_lessons, manifest)."""
    if not LESSONS_DIR.exists():
        raise FileNotFoundError(f"Library directory {LESSONS_DIR} does not exist. Run 'split' first.")

    tracks_order = DEFAULT_TRACKS
    if MANIFEST_PATH.exists():
        manifest_data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        tracks_order = manifest_data.get("tracks", DEFAULT_TRACKS)

    track_category_order: Dict[str, List[str]] = {}
    for track_dir in LESSONS_DIR.iterdir():
        if track_dir.is_dir() and not track_dir.name.startswith("."):
            track_json = track_dir / "track.json"
            if track_json.exists():
                try:
                    data = json.loads(track_json.read_text(encoding="utf-8"))
                    track_category_order[track_dir.name] = data.get("categories", [])
                except Exception:
                    pass

    raw_lessons: List[Tuple[Dict[str, Any], Path]] = []
    for lesson_path in LESSONS_DIR.glob("**/*.json"):
        if lesson_path.name in ("manifest.json", "track.json") or lesson_path.name.startswith("."):
            continue
        try:
            data = json.loads(lesson_path.read_text(encoding="utf-8"))
            if isinstance(data, dict) and "id" in data and "title" in data:
                raw_lessons.append((data, lesson_path.parent))
        except Exception as err:
            raise ValueError(f"Error reading JSON from {lesson_path}: {err}")

    # Build compiled lesson list
    compiled: List[Dict[str, Any]] = []
    for data, parent_dir in raw_lessons:
        code_str, _ = resolve_lesson_code(data, parent_dir)
        item = dict(data)
        item["code"] = code_str
        # Remove build helper fields
        item.pop("codeFile", None)
        compiled.append(item)

    # Sorting
    def sort_key(lesson: Dict[str, Any]) -> Tuple[int, int, int, str]:
        track = lesson.get("track", "")
        cat = lesson.get("category", "")
        track_idx = tracks_order.index(track) if track in tracks_order else 999
        cats_for_track = track_category_order.get(track, [])
        cat_idx = cats_for_track.index(cat) if cat in cats_for_track else 999
        order_val = lesson.get("order", 999999)
        return (track_idx, cat_idx, order_val, lesson.get("id", ""))

    compiled.sort(key=sort_key)

    # Clean up 'order' from final output if present
    for item in compiled:
        item.pop("order", None)

    return compiled, {"tracks": tracks_order}


def cmd_build(args: argparse.Namespace) -> None:
    """Build modular lesson files into TypingPall/Content/lessons.json."""
    compiled_lessons, _ = load_all_modular_lessons()
    output_json = json.dumps(compiled_lessons, indent=2, ensure_ascii=False) + "\n"

    if args.check:
        if not CONTENT_LESSONS_PATH.exists():
            print(f"FAIL: {CONTENT_LESSONS_PATH} does not exist.", file=sys.stderr)
            sys.exit(1)
        current = CONTENT_LESSONS_PATH.read_text(encoding="utf-8")
        if current == output_json:
            print(f"PASS: {CONTENT_LESSONS_PATH} is up-to-date with library/lessons/ ({len(compiled_lessons)} lessons)")
            sys.exit(0)
        else:
            diff = list(difflib.unified_diff(
                current.splitlines(), output_json.splitlines(),
                fromfile="lessons.json (current)", tofile="lessons.json (rebuilt from library/)"
            ))
            print("FAIL: TypingPall/Content/lessons.json is out of sync with library/lessons/!", file=sys.stderr)
            print("Run 'python3 scripts/library.py build' to synchronize.\n", file=sys.stderr)
            for line in diff[:40]:
                print(line, file=sys.stderr)
            if len(diff) > 40:
                print(f"... and {len(diff) - 40} more diff lines", file=sys.stderr)
            sys.exit(1)

    CONTENT_LESSONS_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONTENT_LESSONS_PATH.write_text(output_json, encoding="utf-8")
    print(f"SUCCESS: Built {len(compiled_lessons)} lessons into {CONTENT_LESSONS_PATH}")


# ==========================================
# COMMAND: validate
# ==========================================
def validate_lessons(lessons: List[Dict[str, Any]]) -> List[str]:
    errors: List[str] = []
    seen_ids: Set[str] = set()
    by_id: Dict[str, Dict[str, Any]] = {}
    categories_by_track: Dict[str, str] = {}

    for idx, lesson in enumerate(lessons):
        lid = lesson.get("id")
        if not lid:
            errors.append(f"Lesson #{idx}: missing 'id'")
            continue
        if lid in seen_ids:
            errors.append(f"Lesson '{lid}': duplicate id")
        seen_ids.add(lid)
        by_id[lid] = lesson

        # Required fields
        for field in ("title", "category", "track", "language", "summary", "code"):
            if not lesson.get(field):
                errors.append(f"Lesson '{lid}': missing or empty required field '{field}'")

        # Track and category mapping
        cat = lesson.get("category")
        track = lesson.get("track")
        if cat and track:
            if cat in categories_by_track and categories_by_track[cat] != track:
                errors.append(
                    f"Lesson '{lid}': category '{cat}' belongs to track '{categories_by_track[cat]}' but lesson has track '{track}'"
                )
            else:
                categories_by_track[cat] = track

        # Code and line checks
        code = lesson.get("code", "")
        lines = code.split("\n") if isinstance(code, str) else []
        scaffold = lesson.get("scaffoldLineIndices", [])
        if scaffold:
            for s_idx in scaffold:
                if not (0 <= s_idx < len(lines)):
                    errors.append(f"Lesson '{lid}': scaffoldLineIndex {s_idx} out of range [0, {len(lines)})")

        typed = typed_line_indices(lines, lesson.get("language", ""), scaffold)

        key_lines = lesson.get("keyLineIndices", [])
        if key_lines:
            for k_idx in key_lines:
                if k_idx not in typed:
                    errors.append(f"Lesson '{lid}': keyLineIndex {k_idx} is not a valid typed line")

        # Mutations check
        mutations = lesson.get("mutations", [])
        for m_idx, mutation in enumerate(mutations):
            line_num = mutation.get("line")
            repl = mutation.get("replacement")
            expl = mutation.get("explanation")
            if line_num is None or repl is None or not expl:
                errors.append(f"Lesson '{lid}': mutation #{m_idx} incomplete")
                continue
            if line_num not in typed:
                errors.append(f"Lesson '{lid}': mutation line {line_num} is not a typed line")
            elif line_num < len(lines):
                orig_line = lines[line_num]
                if repl == orig_line:
                    errors.append(f"Lesson '{lid}': mutation line {line_num} replacement equals original")
                if get_indentation(repl) != get_indentation(orig_line):
                    errors.append(f"Lesson '{lid}': mutation line {line_num} indentation does not match original")

    # Mutual contrastWith check
    for lid, lesson in by_id.items():
        contrasts = lesson.get("contrastWith", [])
        for other in contrasts:
            if other not in by_id:
                errors.append(f"Lesson '{lid}': contrastWith refers to non-existent lesson '{other}'")
            elif other == lid:
                errors.append(f"Lesson '{lid}': contrastWith refers to itself")
            else:
                other_contrasts = by_id[other].get("contrastWith", [])
                if lid not in other_contrasts:
                    errors.append(f"Lesson '{lid}': contrastWith '{other}' is not mutual (missing in '{other}')")

    return errors


def cmd_validate(args: argparse.Namespace) -> None:
    """Validate all lessons or a specific target."""
    if LESSONS_DIR.exists() and any(LESSONS_DIR.glob("**/*.json")):
        compiled_lessons, _ = load_all_modular_lessons()
        source = "modular files in library/lessons/"
    elif CONTENT_LESSONS_PATH.exists():
        compiled_lessons = json.loads(CONTENT_LESSONS_PATH.read_text(encoding="utf-8"))
        source = f"monolithic {CONTENT_LESSONS_PATH}"
    else:
        print("Error: No lessons found to validate.", file=sys.stderr)
        sys.exit(1)

    errors = validate_lessons(compiled_lessons)
    if errors:
        print(f"FAILED: Found {len(errors)} validation error(s) in {source}:\n", file=sys.stderr)
        for err in errors:
            print(f"  ❌ {err}", file=sys.stderr)
        sys.exit(1)

    print(f"PASS: All {len(compiled_lessons)} lessons passed validation ({source})")


# ==========================================
# COMMAND: add
# ==========================================
def slugify(text: str) -> str:
    s = text.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s)
    return re.sub(r"[-\s]+", "-", s)


def cmd_add(args: argparse.Namespace) -> None:
    """Interactive or flag-based wizard to add a new lesson."""
    print("=== TypingPall: Add a New Practice Lesson ===\n")

    # Determine track
    track = args.track
    if not track:
        existing_tracks = DEFAULT_TRACKS
        if MANIFEST_PATH.exists():
            manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
            existing_tracks = manifest.get("tracks", DEFAULT_TRACKS)

        print("Select or enter a track:")
        for idx, t in enumerate(existing_tracks, 1):
            print(f"  {idx}) {t}")
        print(f"  {len(existing_tracks) + 1}) Custom track...")
        choice = input(f"Choice [1-{len(existing_tracks) + 1}]: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(existing_tracks):
            track = existing_tracks[int(choice) - 1]
        elif choice.isdigit() and int(choice) == len(existing_tracks) + 1:
            track = input("Enter new track name (camelCase or kebab-case): ").strip()
        else:
            track = choice or "leetcode"

    # Determine category
    category = args.category
    if not category:
        existing_categories: List[str] = []
        track_json = LESSONS_DIR / track / "track.json"
        if track_json.exists():
            existing_categories = json.loads(track_json.read_text(encoding="utf-8")).get("categories", [])
        if existing_categories:
            print(f"\nSelect or enter a category in track '{track}':")
            for idx, c in enumerate(existing_categories, 1):
                print(f"  {idx}) {c}")
            print(f"  {len(existing_categories) + 1}) New category...")
            cchoice = input(f"Choice [1-{len(existing_categories) + 1}]: ").strip()
            if cchoice.isdigit() and 1 <= int(cchoice) <= len(existing_categories):
                category = existing_categories[int(cchoice) - 1]
            else:
                category = input("Enter category name: ").strip()
        else:
            category = input("\nEnter category name (e.g. 'Dynamic Programming'): ").strip()

    # Title
    title = args.title or input("\nLesson Title (e.g. 'Kadane algorithm'): ").strip()

    # Language
    language = args.language
    if not language:
        print("\nSelect language:")
        for idx, lang in enumerate(SUPPORTED_LANGUAGES, 1):
            print(f"  {idx}) {lang}")
        lchoice = input(f"Choice [1-{len(SUPPORTED_LANGUAGES)}] (default python): ").strip()
        if lchoice.isdigit() and 1 <= int(lchoice) <= len(SUPPORTED_LANGUAGES):
            language = SUPPORTED_LANGUAGES[int(lchoice) - 1]
        else:
            language = lchoice or "python"

    # ID
    lid = args.id
    if not lid:
        prefix = {
            "python": "py", "cpp": "cpp", "rust": "rust", "go": "go",
            "ruby": "rb", "shell": "sh", "swift": "swift", "typescript": "ts",
            "javascript": "js", "sql": "sql"
        }.get(language, language[:3])
        suggested_id = f"{prefix}-{slugify(title)}"
        lid_input = input(f"\nLesson ID [default: {suggested_id}]: ").strip()
        lid = lid_input if lid_input else suggested_id

    # Summary
    summary = args.summary or input("\nSummary (1-2 sentences explaining behavior and time complexity): ").strip()

    # Code
    code_lines: List[str] = []
    if args.code_file:
        code_file = Path(args.code_file).resolve()
        code_lines = code_file.read_text(encoding="utf-8").split("\n")
    elif args.code:
        code_lines = args.code.split("\n")
    else:
        print("\nProvide code: Enter path to source file, or leave blank to paste interactively:")
        file_input = input("File path: ").strip()
        if file_input:
            code_lines = Path(file_input).read_text(encoding="utf-8").split("\n")
        else:
            print("Paste code below, followed by an empty line with 'EOF':")
            while True:
                line = input()
                if line.strip() == "EOF":
                    break
                code_lines.append(line)

    print("\n--- Code Preview with 0-based Line Numbers ---")
    for idx, line in enumerate(code_lines):
        print(f"  {idx:2d} | {line}")
    print("----------------------------------------------\n")

    # Key lines
    key_lines: List[int] = []
    if args.key_lines:
        for p in args.key_lines.split(","):
            if p.strip().isdigit():
                key_lines.append(int(p.strip()))
    elif sys.stdin.isatty():
        key_input = input("Key lines to practice (comma-separated indices, e.g. '3, 4, 7') [optional]: ").strip()
        if key_input:
            for p in key_input.split(","):
                if p.strip().isdigit():
                    key_lines.append(int(p.strip()))

    lesson_data: Dict[str, Any] = {
        "id": lid,
        "title": title,
        "category": category,
        "track": track,
        "language": language,
        "summary": summary,
        "code": code_lines
    }

    if key_lines:
        lesson_data["keyLineIndices"] = key_lines

    # Optional recall notes for LeetCode / design patterns
    if args.family:
        lesson_data["family"] = args.family
    if args.mantra:
        lesson_data["mantra"] = args.mantra
    if args.invariant:
        lesson_data["invariant"] = args.invariant

    if sys.stdin.isatty() and track in ("leetcode", "lowLevelDesign") and not any((args.family, args.mantra, args.invariant)):
        print("\nOptional Recall Metadata (press Enter to skip):")
        family = input("  Pattern Family (e.g. 'sliding-window', 'two-pointers'): ").strip()
        if family:
            lesson_data["family"] = family
        mantra = input("  Mantra (short rule of thumb): ").strip()
        if mantra:
            lesson_data["mantra"] = mantra
        invariant = input("  Invariant (what holds true across each step): ").strip()
        if invariant:
            lesson_data["invariant"] = invariant

    # Save to file
    track_dir = LESSONS_DIR / track
    track_dir.mkdir(parents=True, exist_ok=True)
    dest = track_dir / f"{lid}.json"
    dest.write_text(json.dumps(lesson_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\n✅ Created lesson file: {dest}")

    # Update track.json categories if needed
    track_json = track_dir / "track.json"
    cat_list: List[str] = []
    if track_json.exists():
        cat_list = json.loads(track_json.read_text(encoding="utf-8")).get("categories", [])
    if category not in cat_list:
        cat_list.append(category)
        track_json.write_text(
            json.dumps({"track": track, "categories": cat_list}, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8"
        )

    # Rebuild lessons.json
    print("Rebuilding TypingPall/Content/lessons.json...")
    cmd_build(argparse.Namespace(check=False))

    # Validate
    cmd_validate(argparse.Namespace())


# ==========================================
# COMMAND: ingest
# ==========================================
def extract_components_from_source(source_text: str, language: str) -> Tuple[List[str], List[str], str, str]:
    """Returns (code_lines, test_lines, summary, title)."""
    raw_lines = source_text.strip().split("\n")

    # 1. Look for test delimiter
    test_start = None
    is_main_block = False
    for idx, l in enumerate(raw_lines):
        stripped = l.strip()
        if stripped.startswith("if __name__ == '__main__':") or stripped.startswith('if __name__ == "__main__":'):
            test_start = idx
            is_main_block = True
            break
        elif stripped.startswith("# test:") or stripped.startswith("# tests:") or stripped.startswith("# --- test"):
            test_start = idx
            break
        elif stripped.startswith("def test_"):
            test_start = idx
            break

    if test_start is not None:
        code_lines = raw_lines[:test_start]
        test_raw = raw_lines[test_start + 1:] if is_main_block else raw_lines[test_start:]
        test_lines = []
        for tl in test_raw:
            if is_main_block and tl.startswith("    "):
                test_lines.append(tl[4:])
            else:
                test_lines.append(tl)
    else:
        code_lines = raw_lines
        test_lines = []

    # Clean trailing whitespace / blank lines
    while code_lines and not code_lines[-1].strip():
        code_lines.pop()
    while test_lines and not test_lines[-1].strip():
        test_lines.pop()

    # 2. Extract summary from top comment or docstring
    summary = ""
    for line in code_lines:
        s = line.strip()
        if s.startswith("#"):
            candidate = s.lstrip("#").strip()
            if candidate and not candidate.startswith("!") and not candidate.startswith("-"):
                summary = candidate
                break
        elif s.startswith('"""') or s.startswith("'''"):
            summary = s.strip("\"'").strip()
            break
        elif s:
            break

    # 3. Extract title from class or function
    title = ""
    for line in code_lines:
        s = line.strip()
        class_match = re.match(r"^class\s+([A-Za-z0-9_]+)", s)
        func_match = re.match(r"^def\s+([A-Za-z0-9_]+)", s)
        if class_match:
            name = class_match.group(1)
            # CamelCase to Words
            title = re.sub(r"([A-Z])", r" \1", name).strip()
            break
        elif func_match:
            name = func_match.group(1)
            # snake_case to Words
            title = name.replace("_", " ").capitalize()
            break

    return code_lines, test_lines, summary, title


def select_key_lines(code_lines: List[str], language: str) -> List[int]:
    comment = comment_prefix_for(language)
    scored = []
    for idx, line in enumerate(code_lines):
        stripped = line.strip()
        if not stripped or stripped.startswith(comment) or stripped.startswith("def ") or stripped.startswith("class "):
            continue
        score = 0
        if any(op in line for op in (" % ", " // ")): score += 4
        if any(fn in line for fn in ("min(", "max(", "sum(")): score += 3
        if any(m in line for m in (".append(", ".add(", ".pop(", ".discard(", ".remove(")): score += 3
        if any(k in line for k in ("while ", "for ", "elif ")): score += 2
        if any(k in line for k in ("return ", "if ")): score += 1
        if score > 0:
            scored.append((score, idx))

    scored.sort(key=lambda item: (-item[0], item[1]))
    return sorted([idx for _, idx in scored[:3]])


def auto_generate_mutation(code_lines: List[str], test_lines: List[str]) -> Optional[Dict[str, Any]]:
    if not test_lines:
        return None
    test_code = "\n".join(test_lines)
    orig_code = "\n".join(code_lines)

    def test_eval(code_str: str) -> bool:
        mod = types.ModuleType("mutation_test_module")
        try:
            exec(compile(code_str, "code", "exec"), mod.__dict__)
            exec(compile(test_code, "test", "exec"), mod.__dict__)
            return True
        except Exception:
            return False

    # Check clean code first
    if not test_eval(orig_code):
        return None

    # Candidate mutation patterns
    for idx, line in enumerate(code_lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("def ") or stripped.startswith("class "):
            continue
        indent = get_indentation(line)

        candidates = []
        if " % " in line:
            candidates.append((line.replace(" % ", " // ", 1), "Replaces modulo with integer division"))
            candidates.append((line.replace(" % ", " + ", 1), "Replaces modulo with addition"))
        if " + " in line:
            candidates.append((line.replace(" + ", " - ", 1), "Replaces addition with subtraction"))
        if " - " in line:
            candidates.append((line.replace(" - ", " + ", 1), "Replaces subtraction with addition"))
        if "min(" in line:
            candidates.append((line.replace("min(", "max(", 1), "Replaces min with max"))
        if "max(" in line:
            candidates.append((line.replace("max(", "min(", 1), "Replaces max with min"))
        if " == " in line:
            candidates.append((line.replace(" == ", " != ", 1), "Inverts equality check"))
        if " != " in line:
            candidates.append((line.replace(" != ", " == ", 1), "Inverts inequality check"))
        if " < " in line:
            candidates.append((line.replace(" < ", " <= ", 1), "Off-by-one comparison check"))
        if " > " in line:
            candidates.append((line.replace(" > ", " >= ", 1), "Off-by-one comparison check"))
        if "if not " in line:
            candidates.append((line.replace("if not ", "if ", 1), "Inverts conditional check"))
        if "not in" in line:
            candidates.append((line.replace("not in", "in", 1), "Inverts membership check"))
        elif " in " in line:
            candidates.append((line.replace(" in ", " not in ", 1), "Inverts membership check"))
        if " and " in line:
            candidates.append((line.replace(" and ", " or ", 1), "Replaces logical AND with OR"))

        candidates.append((indent + "pass", "Skips required state update or operation"))

        for repl, expl in candidates:
            if repl == line:
                continue
            mutated_lines = list(code_lines)
            mutated_lines[idx] = repl
            mutated_code = "\n".join(mutated_lines)
            if not test_eval(mutated_code):
                return {
                    "line": idx,
                    "replacement": repl,
                    "explanation": expl
                }
    return None


def cmd_ingest(args: argparse.Namespace) -> None:
    """Ingest raw code, automatically separating code and tests, generating metadata, key lines, and mutations."""
    raw_text = ""
    language = args.language or "python"

    if args.file:
        file_path = Path(args.file)
        if not file_path.exists():
            print(f"Error: file '{args.file}' not found.", file=sys.stderr)
            sys.exit(1)
        raw_text = file_path.read_text(encoding="utf-8")
        ext = file_path.suffix.lstrip(".").lower()
        if not args.language:
            ext_map = {"py": "python", "swift": "swift", "go": "go", "rs": "rust", "cpp": "cpp", "rb": "ruby", "sh": "shell"}
            language = ext_map.get(ext, "python")
    else:
        if sys.stdin.isatty():
            print("=== TypingPall: Ingest Code to Practice Lesson ===")
            print("Paste your code below (with if __name__ == '__main__': tests if available), then press Ctrl+D / EOF:")
        raw_text = sys.stdin.read()

    if not raw_text.strip():
        print("Error: No code provided to ingest.", file=sys.stderr)
        sys.exit(1)

    code_lines, test_lines, extracted_summary, extracted_title = extract_components_from_source(raw_text, language)

    title = args.title or extracted_title or "Practice pattern"
    summary = args.summary or extracted_summary or f"Implementation of {title}."

    has_class = any(l.strip().startswith("class ") for l in code_lines)
    default_track = "lowLevelDesign" if has_class else "leetcode"
    track = args.track or default_track

    default_cat_map = {
        "lowLevelDesign": "Design building blocks",
        "leetcode": "Python interview patterns",
        "languages": "Python fundamentals"
    }
    category = args.category or default_cat_map.get(track, "Design building blocks")

    lid = args.id
    if not lid:
        prefix = "lld-" if track == "lowLevelDesign" else ("py-" if language == "python" else f"{language[:3]}-")
        lid = f"{prefix}{slugify(title)}"

    key_lines = select_key_lines(code_lines, language)

    mutations = []
    auto_mut = auto_generate_mutation(code_lines, test_lines)
    if auto_mut:
        mutations.append(auto_mut)

    lesson_data: Dict[str, Any] = {
        "id": lid,
        "title": title,
        "category": category,
        "track": track,
        "language": language,
        "summary": summary,
        "code": code_lines
    }
    if key_lines:
        lesson_data["keyLineIndices"] = key_lines
    if mutations:
        lesson_data["mutations"] = mutations
    if test_lines:
        lesson_data["test"] = test_lines

    if args.family:
        lesson_data["family"] = args.family
    elif track in ("leetcode", "lowLevelDesign"):
        lesson_data["family"] = slugify(title)

    if args.mantra:
        lesson_data["mantra"] = args.mantra
    if args.invariant:
        lesson_data["invariant"] = args.invariant

    track_dir = LESSONS_DIR / track
    track_dir.mkdir(parents=True, exist_ok=True)
    dest_path = track_dir / f"{lid}.json"
    dest_path.write_text(json.dumps(lesson_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"\n🎉 Successfully ingested lesson: {lid}")
    print(f"  • Title: {title}")
    print(f"  • Track: {track} | Category: {category}")
    print(f"  • Code lines: {len(code_lines)}")
    print(f"  • Test assertions: {'Extracted (' + str(len(test_lines)) + ' lines)' if test_lines else 'None'}")
    print(f"  • Key lines: {key_lines}")
    print(f"  • Planted bug mutation: {'Generated (line ' + str(auto_mut['line']) + ')' if auto_mut else 'None'}")
    print(f"  • File saved: {dest_path}")

    track_json = track_dir / "track.json"
    cat_list = []
    if track_json.exists():
        cat_list = json.loads(track_json.read_text(encoding="utf-8")).get("categories", [])
    if category not in cat_list:
        cat_list.append(category)
        track_json.write_text(
            json.dumps({"track": track, "categories": cat_list}, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8"
        )

    print("\nRebuilding and validating library...")
    cmd_build(argparse.Namespace(check=False))
    cmd_validate(argparse.Namespace())


# ==========================================
# COMMAND: stats
# ==========================================
def cmd_stats(args: argparse.Namespace) -> None:
    """Show library statistics."""
    compiled_lessons, _ = load_all_modular_lessons() if LESSONS_DIR.exists() else (
        json.loads(CONTENT_LESSONS_PATH.read_text(encoding="utf-8")), {}
    )

    from collections import Counter
    tracks = Counter(l["track"] for l in compiled_lessons)
    languages = Counter(l["language"] for l in compiled_lessons)
    categories = Counter(l["category"] for l in compiled_lessons)
    with_recall = sum(1 for l in compiled_lessons if "family" in l or "mantra" in l)

    print("==========================================")
    print("       TypingPall Practice Library        ")
    print("==========================================")
    print(f"Total Lessons: {len(compiled_lessons)}")
    print(f"With Recall Notes: {with_recall}")
    print(f"Total Categories: {len(categories)}")
    print("\n--- By Track ---")
    for t, c in tracks.most_common():
        print(f"  {t:20} : {c:3d} lessons")
    print("\n--- By Language ---")
    for lang, c in languages.most_common():
        print(f"  {lang:20} : {c:3d} lessons")
    print("==========================================")


def main() -> None:
    parser = argparse.ArgumentParser(description="TypingPall Library Management CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # build
    p_build = subparsers.add_parser("build", help="Compile library/lessons/ into TypingPall/Content/lessons.json")
    p_build.add_argument("--check", action="store_true", help="Fail if lessons.json is out of sync")

    # split
    subparsers.add_parser("split", help="Split TypingPall/Content/lessons.json into modular files under library/lessons/")

    # validate
    subparsers.add_parser("validate", help="Validate all lessons against schema and practice rules")

    # stats
    subparsers.add_parser("stats", help="Display library counts and statistics")

    # add
    p_add = subparsers.add_parser("add", help="Add a new lesson (interactive or flag-driven)")
    p_add.add_argument("--id", help="Unique lesson ID")
    p_add.add_argument("--title", help="Lesson title")
    p_add.add_argument("--track", help="Track name")
    p_add.add_argument("--category", help="Category name")
    p_add.add_argument("--language", help="Code language")
    p_add.add_argument("--summary", help="Summary text")
    p_add.add_argument("--code-file", help="Path to code file")
    p_add.add_argument("--code", help="Inline code string")
    p_add.add_argument("--key-lines", help="Comma-separated key line indices")
    p_add.add_argument("--family", help="Pattern family (e.g. sliding-window)")
    # ingest
    p_ingest = subparsers.add_parser("ingest", help="Paste or load code to automatically generate lesson JSON with inline tests")
    p_ingest.add_argument("file", nargs="?", help="Source code file path (or read from stdin / paste)")
    p_ingest.add_argument("--id", help="Unique lesson ID")
    p_ingest.add_argument("--title", help="Lesson title")
    p_ingest.add_argument("--track", help="Track name")
    p_ingest.add_argument("--category", help="Category name")
    p_ingest.add_argument("--language", help="Code language")
    p_ingest.add_argument("--summary", help="Summary text")
    p_ingest.add_argument("--family", help="Pattern family")
    p_ingest.add_argument("--mantra", help="Mantra rule of thumb")
    p_ingest.add_argument("--invariant", help="Pattern invariant")

    args = parser.parse_args()

    if args.command == "build":
        cmd_build(args)
    elif args.command == "split":
        cmd_split(args)
    elif args.command == "validate":
        cmd_validate(args)
    elif args.command == "stats":
        cmd_stats(args)
    elif args.command == "add":
        cmd_add(args)
    elif args.command == "ingest":
        cmd_ingest(args)


if __name__ == "__main__":
    main()
