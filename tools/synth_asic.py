#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
#
# Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

"""ASIC smoke synthesis for every src/ module via Yosys read_slang + generic synth.

Discovers ^module definitions under src/**/*.sv (skips package-only files such as
binaryio.sv). For each module runs read_slang on that module plus package sources,
with -y libdirs so instantiated submodules resolve, then:

    hierarchy -top NAME
    synth -top NAME
    stat

Generic synth only (never synth_xilinx / synth_ice40). Exit 0 iff every module
passes. Log path defaults to a gitignored directory under the repo.

Requires yosys on PATH (oss-cad-suite environment). Run from repository root:

    python3 tools/synth_asic.py
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
MODULE_RE = re.compile(r"^module\s+(\w+)\b", re.MULTILINE)
PACKAGE_RE = re.compile(r"^package\s+(\w+)\b", re.MULTILINE)
ERROR_RE = re.compile(r"(?:^|\n)\s*(?:ERROR:|error:)\s*(.+)", re.IGNORECASE)


def find_modules(src: Path) -> list[tuple[str, Path]]:
    """Return (module_name, file) for every ^module in src/**/*.sv."""
    found: list[tuple[str, Path]] = []
    for path in sorted(src.rglob("*.sv")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in MODULE_RE.finditer(text):
            found.append((match.group(1), path))
    return found


def find_package_files(src: Path) -> list[Path]:
    """SV files that declare a package (needed for imports / macros)."""
    pkgs: list[Path] = []
    for path in sorted(src.rglob("*.sv")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if PACKAGE_RE.search(text):
            pkgs.append(path)
    return pkgs


def lib_dirs(src: Path) -> list[Path]:
    """Directories under src/ that contain .sv files (for -y lookup)."""
    dirs: set[Path] = set()
    for path in src.rglob("*.sv"):
        dirs.add(path.parent)
    return sorted(dirs)


def first_error(text: str) -> str:
    """Prefer the first concrete slang/Yosys error over the summary line."""
    skip = (
        "design elaboration failed",
        "build failed",
    )
    for match in ERROR_RE.finditer(text):
        msg = match.group(1).strip().splitlines()[0].strip()
        if msg.lower() in skip or msg.lower().startswith("design elaboration"):
            continue
        return msg
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    for ln in lines:
        lower = ln.lower()
        if "assert `" in lower:
            return ln
        if "error" in lower and "design elaboration failed" not in lower:
            return ln
    return "unknown error (see log)"


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def synth_module(
    name: str,
    module_file: Path,
    package_files: list[Path],
    dirs: list[Path],
    *,
    yosys: str,
    src: Path,
    work_dir: Path,
) -> tuple[bool, str, str]:
    """Run Yosys for one top. Returns (ok, summary_line, full_log)."""
    # Primary unit: packages (macros + imports) and the module under test.
    # Other RTL is pulled via -y when instantiated, so unrelated broken tops
    # do not poison every check.
    primary: list[Path] = []
    seen: set[Path] = set()
    for path in package_files + [module_file]:
        if path not in seen:
            primary.append(path)
            seen.add(path)

    parts = [
        f"read_slang -I {src.as_posix()} --std 1800-2017 --single-unit "
        "--libraries-inherit-macros --libext .sv -D SYNTHESIS",
    ]
    parts.extend(rel(p) for p in primary)
    for d in dirs:
        parts.append(f"-y {rel(d)}")
    script = (
        " ".join(parts)
        + f"; hierarchy -top {name}; synth -top {name}; stat"
    )
    cmd = [yosys, "-q", "-p", script]
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    (work_dir / f"{name}.log").write_text(out, encoding="utf-8")
    if proc.returncode == 0:
        return True, f"PASS {name}", out
    return False, f"FAIL {name}: {first_error(out)}", out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=None,
        help="Directory for per-module and summary logs (default: build/asic-synth/)",
    )
    parser.add_argument(
        "--yosys",
        default=os.environ.get("YOSYS", "yosys"),
        help="Yosys executable (default: yosys or $YOSYS)",
    )
    parser.add_argument(
        "--module",
        action="append",
        default=[],
        help="Limit to one or more module names (repeatable)",
    )
    args = parser.parse_args()

    if not SRC.is_dir():
        print(f"ERROR: missing src/ at {SRC}", file=sys.stderr)
        return 2

    log_dir = args.log_dir
    if log_dir is None:
        log_dir = ROOT / "build" / "asic-synth"
    log_dir = log_dir.resolve()
    log_dir.mkdir(parents=True, exist_ok=True)

    modules = find_modules(SRC)
    if args.module:
        want = set(args.module)
        modules = [(n, p) for n, p in modules if n in want]
        missing = want - {n for n, _ in modules}
        if missing:
            print(
                f"ERROR: unknown module(s): {', '.join(sorted(missing))}",
                file=sys.stderr,
            )
            return 2

    if not modules:
        print("ERROR: no modules found under src/", file=sys.stderr)
        return 2

    package_files = find_package_files(SRC)
    dirs = lib_dirs(SRC)
    summary_lines: list[str] = []
    passed = 0
    failed = 0

    print(
        f"ASIC synth: {len(modules)} module(s), "
        f"{len(package_files)} package file(s), {len(dirs)} libdir(s)"
    )
    print(f"Log directory: {log_dir}")

    for name, path in modules:
        ok, line, _ = synth_module(
            name,
            path,
            package_files,
            dirs,
            yosys=args.yosys,
            src=SRC,
            work_dir=log_dir,
        )
        print(line, flush=True)
        summary_lines.append(line)
        if ok:
            passed += 1
        else:
            failed += 1

    summary = f"\nSummary: PASS={passed} FAIL={failed} TOTAL={len(modules)}\n"
    print(summary, end="")
    (log_dir / "summary.txt").write_text(
        "\n".join(summary_lines) + summary, encoding="utf-8"
    )
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
