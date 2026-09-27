#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
"""Move SHALL prose from YAML frontmatter into # Requirements on module pages."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from apply_okf_requirements_rollout import migrate_requirements_to_body  # noqa: E402

if __name__ == "__main__":
    migrate_requirements_to_body()
