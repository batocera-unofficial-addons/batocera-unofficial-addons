#!/usr/bin/env python3
import subprocess
from pathlib import Path
from datetime import datetime, timezone

REPO_ROOT = Path(__file__).resolve().parents[2]
OUTPUT = REPO_ROOT / "SCRIPT_DATES.md"

# Adjust file globs/extensions as needed
FILE_PATTERNS = ["*.sh", "*.bash", "*.py", "*.js"]


def git_ls_files(pattern: str) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", pattern],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def get_staged_files() -> set[str]:
    """Get list of files staged for commit"""
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    return set(line.strip() for line in result.stdout.splitlines() if line.strip())


def git_last_date(path: str, staged_files: set[str]) -> str:
    """
    Get the date for a file:
    - If file is staged (about to be committed), use current timestamp
    - Otherwise, use last commit date from git log
    """
    # If this file is being committed right now, use current time
    if path in staged_files:
        now = datetime.now(timezone.utc)
        # Format as ISO: YYYY-MM-DD HH:MM:SS +0000
        return now.strftime("%Y-%m-%d %H:%M:%S +0000")

    # Otherwise, get last commit date
    result = subprocess.run(
        [
            "git",
            "log",
            "-1",
            "--date=iso",
            "--pretty=format:%ad",
            "--",
            path,
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip() or "N/A"



def main() -> None:
    files: list[str] = []
    for pattern in FILE_PATTERNS:
        files.extend(git_ls_files(pattern))

    files = sorted(set(files))  # de-dupe + stable order

    # Get files that are staged for commit
    staged_files = get_staged_files()

    lines = [
        "# Script Last Modified Dates",
        "",
        "| File | Last Commit Date |",
        "|------|------------------|",
    ]

    for f in files:
        date = git_last_date(f, staged_files)
        lines.append(f"| `{f}` | {date} |")

    text = "\n".join(lines) + "\n"

    if OUTPUT.exists():
        old = OUTPUT.read_text(encoding="utf-8")
        if old == text:
            print("SCRIPT_DATES.md is already up to date")
            return

    OUTPUT.write_text(text, encoding="utf-8")
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
