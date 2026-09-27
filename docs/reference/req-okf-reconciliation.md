---
type: Reference
title: Requirement identifiers and OKF v0.2 frontmatter
description: Maps review feedback to colibri_sv conventions for module requirements.
tags: [okf, sysml, requirements]
status: stable
---

# Purpose

Reconcile external review terminology (`module-spec`, `REQ_SYNC_STAGES`, `ColibriRequirements::Req_*`) with what this repository already uses.

# Canonical scheme (colibri_sv)

| Review / external | colibri_sv choice | Notes |
| --- | --- | --- |
| `type: module-spec` | **`type: Module`** | OKF `type` is descriptive; [`project.md`](../../.cursor/skills/documentation/project.md) registers **Module** for RTL module pages. Do not fork a second concept type. |
| `REQ_SYNC_STAGES` / `Req_SyncStages` | **`REQ-<MODULE>-<NNN>`** / **`REQ_<MODULE>_<NNN>`** | Public id uses the module token uppercased with underscores as hyphens (`counter` → `REQ-COUNTER-001`). SysML short name is `REQ_COUNTER_001` (underscores, no quotes in identifier). |
| `ColibriRequirements` | **`Colibri_Requirements`** | Single ancillary package in [`sysml/requirements.sysml`](../../sysml/requirements.sysml). Qualified references: `Colibri_Requirements::REQ_COUNTER_001`. |
| `model:` URI | **`model: sysml://Colibri::<Domain>::<module>`** | Unchanged; ties the page to the `part def` in [`sysml/parts/`](../../sysml/parts/). |
| Provenance blob | **`provenance`** + existing **`sources`** | `provenance.upstream_path` and `provenance.pinned_commit` are the machine fields agents check. Keep `sources[]` for human-readable upstream links (OKF v0.2). |

# SHALL single source of truth

1. **Observable SHALL prose** lives in the module page YAML frontmatter under `requirements[].statement` (must contain `shall`).
2. The `# Requirements` body section holds **anchors**, **headings**, and **verification metadata** only — not a second copy of the sentence.
3. [`sysml/requirements.sysml`](../../sysml/requirements.sysml) stubs carry **`OKF: <docPath>#<id>`** in `doc` and `@OKFReference`; they do **not** repeat SHALL text.
4. The matching `part def` declares **`satisfy`** usages for each stub the module implements.

# When to add `requirements` frontmatter

Add the block only when the module has at least one observable requirement (typically when `fv/` or self-checking `sim/` exists). Structure-only modules omit `requirements` entirely; no placeholder REQ ids.

# Related

- [SysML playbook](../playbooks/sysml.md)
- [MODULE_TEMPLATE](../MODULE_TEMPLATE.md)
- Golden example: [counter](../modules/common/counter.md)
