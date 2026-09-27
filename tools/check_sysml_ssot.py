#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
#
# Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

"""Verify the SysML model, requirement stubs, and RTL stay aligned.

The model is edited first. This checker reports divergence; it does not regenerate files.

Run from repository root:

    uv run python tools/check_sysml_ssot.py
    uv run python tools/check_sysml_ssot.py --module counter
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
DOCS = ROOT / "docs" / "modules"
PARTS = ROOT / "sysml" / "parts"
REQ_SYSML = ROOT / "sysml" / "requirements.sysml"

REQ_HEADING = re.compile(r"^##\s+(REQ-[A-Z0-9_]+-\d+)\s*$", re.MULTILINE)
REQ_ANCHOR = re.compile(r'<a id="(REQ-[A-Z0-9_]+-\d+)"></a>')
STUB_REQ = re.compile(r"requirement def <'(REQ-[A-Z0-9_]+-\d+)'>")
PART_DEF = re.compile(r"part def (\w+)")
IN_ITEM = re.compile(r"^\s*(in|out|inout) item (\w+);", re.MULTILINE)
SHALL_IN_STUB = re.compile(r"\bshall\b", re.IGNORECASE)
CERN_IN_PART = re.compile(r"SPDX-License-Identifier:\s*CERN-OHL-W")
CERN_IN_STUB = re.compile(r"SPDX-License-Identifier:\s*CERN-OHL-W")


@dataclass
class Param:
    name: str
    sysml_type: str
    default: str | None
    sv_expr: bool = False


@dataclass
class Port:
    name: str
    direction: str  # in | out | inout
    sv_decl: str


@dataclass
class ModuleHeader:
    name: str
    params: list[Param] = field(default_factory=list)
    ports: list[Port] = field(default_factory=list)


def strip_sv_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                break
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                break
            i = end + 2
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def find_balanced(text: str, start: int, open_ch: str, close_ch: str) -> int:
    if start >= len(text) or text[start] != open_ch:
        raise ValueError(f"expected {open_ch} at {start}")
    depth = 0
    i = start
    while i < len(text):
        ch = text[i]
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unbalanced {open_ch} from {start}")


def split_top_level(text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            piece = "".join(buf).strip()
            if piece:
                parts.append(piece)
            buf = []
            continue
        buf.append(ch)
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def classify_default(expr: str) -> tuple[str, bool]:
    expr = expr.strip()
    if re.fullmatch(r"-?\d+", expr):
        return "Integer", False
    if re.fullmatch(r"1'[bB][01]", expr) or expr in ("1'b0", "1'b1"):
        return "Boolean", False
    if re.fullmatch(r"1'[bB][01]+", expr):
        return "String", True
    return "String", True


def parse_parameter(chunk: str) -> Param | None:
    chunk = chunk.strip()
    if not chunk or chunk.startswith("localparam"):
        return None
    if not chunk.startswith("parameter"):
        return None
    rest = chunk[len("parameter") :].strip()
    if rest.startswith("type "):
        m = re.match(r"type\s+(\w+)\s*=\s*(.+)$", rest, re.DOTALL)
        if m:
            return Param(m.group(1), "String", m.group(2).strip(), True)
        return None
    eq = rest.find("=")
    head = rest[:eq].strip() if eq >= 0 else rest.strip()
    default = rest[eq + 1 :].strip() if eq >= 0 else None
    tokens = head.split()
    if not tokens:
        return None
    name = tokens[-1]
    type_blob = " ".join(tokens[:-1])
    if "type" in type_blob.split():
        return Param(name, "String", default or "", True)
    if re.search(r"\btime\b", type_blob):
        return Param(name, "String", default or "", True)
    if re.search(r"\bstring\b", type_blob):
        return Param(name, "String", default or '""', True)
    if re.search(r"\bint\b", type_blob):
        if default:
            st, sv = classify_default(default)
            return Param(name, st, default, sv)
        return Param(name, "Integer", None, False)
    if re.search(r"\bbit\b", type_blob):
        if default:
            st, sv = classify_default(default)
            return Param(name, st, default, sv)
        return Param(name, "Boolean", None, False)
    if default:
        st, sv = classify_default(default)
        return Param(name, st, default, sv)
    return Param(name, "String", None, True)


def parse_port(chunk: str) -> Port | None:
    chunk = re.sub(r"\s+", " ", chunk.strip())
    m = re.match(r"(input|output|inout)\s+(.+)$", chunk, re.IGNORECASE)
    if not m:
        return None
    raw = m.group(1).lower()
    direction = {"input": "in", "output": "out", "inout": "inout"}[raw]
    decl = m.group(2).strip().rstrip(",")
    name_m = re.search(r"(\w+)\s*$", decl)
    if not name_m:
        return None
    return Port(name_m.group(1), direction, decl)


def parse_module_header(text: str, path: Path) -> ModuleHeader | None:
    clean = strip_sv_comments(text)
    m = re.search(r"\bmodule\s+(\w+)", clean)
    if not m:
        return None
    name = m.group(1)
    pos = m.end()
    while pos < len(clean) and clean[pos].isspace():
        pos += 1
    param_text = ""
    if pos < len(clean) and clean[pos] == "#":
        open_paren = clean.find("(", pos)
        if open_paren < 0:
            raise ValueError(f"{path}: malformed parameter list")
        close_paren = find_balanced(clean, open_paren, "(", ")")
        param_text = clean[open_paren + 1 : close_paren]
        pos = close_paren + 1
        while pos < len(clean) and clean[pos].isspace():
            pos += 1
    while pos < len(clean) and clean[pos].isspace():
        pos += 1
    if pos >= len(clean) or clean[pos] != "(":
        raise ValueError(f"{path}: expected port list after module {name}")
    port_close = find_balanced(clean, pos, "(", ")")
    port_text = clean[pos + 1 : port_close]

    params: list[Param] = []
    for piece in split_top_level(param_text):
        p = parse_parameter(piece)
        if p:
            params.append(p)

    ports: list[Port] = []
    for piece in split_top_level(port_text):
        p = parse_port(piece)
        if p:
            ports.append(p)

    return ModuleHeader(name, params, ports)



def rtl_port_names(sv_path: Path, module: str) -> set[str]:
    text = sv_path.read_text(encoding="utf-8")
    header = parse_module_header(text, sv_path)
    if header is None or header.name != module:
        return set()
    return {p.name for p in header.ports}


def module_filter(req_id: str, module: str) -> bool:
    token = module.replace("_", "-").upper()
    return f"-{token}-" in req_id or req_id.endswith(f"-{token}-001")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", help="Only check REQ stubs for this module (e.g. counter)")
    args = ap.parse_args()

    errors: list[str] = []

    stub_text = REQ_SYSML.read_text(encoding="utf-8") if REQ_SYSML.is_file() else ""
    stub_ids = {m.group(1) for m in STUB_REQ.finditer(stub_text)}
    if not REQ_SYSML.is_file():
        errors.append("missing sysml/requirements.sysml")
    elif CERN_IN_STUB.search(stub_text):
        errors.append("requirements.sysml must not carry CERN-OHL-W SPDX")
    for match in re.finditer(
        r"requirement def <'REQ-[^']+'>\s+\w+\s*\{[^}]*\}", stub_text, re.DOTALL
    ):
        if SHALL_IN_STUB.search(match.group(0)):
            errors.append("requirement stub contains SHALL text in body")

    doc_ids: set[str] = set()
    for md in sorted(DOCS.rglob("*.md")):
        if md.name == "index.md":
            continue
        if args.module and md.stem != args.module:
            continue
        text = md.read_text(encoding="utf-8")
        headings = {m.group(1) for m in REQ_HEADING.finditer(text)}
        anchors = {m.group(1) for m in REQ_ANCHOR.finditer(text)}
        for hid in headings:
            doc_ids.add(hid)
            if hid not in anchors:
                errors.append(f"{md.relative_to(ROOT)}: heading {hid} without matching anchor")
        for aid in anchors:
            if aid not in headings:
                errors.append(f"{md.relative_to(ROOT)}: anchor {aid} without ## heading")

    for rid in sorted(doc_ids):
        if rid not in stub_ids:
            errors.append(f"missing stub for {rid}")
    if not args.module:
        for rid in sorted(stub_ids):
            if rid not in doc_ids:
                errors.append(f"orphan stub {rid}")
    else:
        for rid in sorted(stub_ids):
            if not module_filter(rid, args.module):
                continue
            if rid not in doc_ids:
                errors.append(f"orphan stub {rid} for --module {args.module}")

    for part_path in sorted(PARTS.rglob("*.sysml")):
        content = part_path.read_text(encoding="utf-8")
        if not CERN_IN_PART.search(content):
            errors.append(f"{part_path.relative_to(ROOT)}: missing CERN-OHL-W header")
        m = PART_DEF.search(content)
        if not m:
            errors.append(f"{part_path.relative_to(ROOT)}: no part def")
            continue
        module = m.group(1)
        if module != part_path.stem:
            errors.append(f"{part_path}: part def {module} != filename stem")
        sysml_ports = {m.group(2) for m in IN_ITEM.finditer(content)}
        sv_candidates = list(SRC.rglob(f"{module}.sv"))
        if not sv_candidates:
            errors.append(f"{part_path}: no RTL module {module}.sv")
            continue
        rtl = rtl_port_names(sv_candidates[0], module)
        if sysml_ports != rtl:
            missing = rtl - sysml_ports
            extra = sysml_ports - rtl
            errors.append(
                f"{part_path.relative_to(ROOT)}: RTL ports differ from the model; edit the model first, then RTL. missing_in_rtl={sorted(extra)} missing_in_model={sorted(missing)}"
            )

    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        print(f"check failed ({len(errors)} errors)", file=sys.stderr)
        return 1
    scope = args.module or "all"
    print(f"check_sysml_ssot: ok ({scope})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
