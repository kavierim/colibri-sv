# Documentation project settings (colibri_sv)

## Bundle root

`docs/` — start at [`docs/index.md`](../../../docs/index.md).

## Concept types

| type | Use |
| --- | --- |
| Playbook | How-to guides under `docs/playbooks/` |
| Reference | Stable contracts; `CONVENTIONS.md` remains authoritative |
| Package | `colibri_*` and CSR packages |
| Module | One RTL `module` per page |

## Tags

- `domain:<common|memory|comms|endec|io|interfaces|packet|pipes|misc|aurora>`
- `module:<name>`
- `interface:avst`, `interface:axis`, `interface:wishbone`
- `cdc`, `verilator`, `playbook`, `package`

## Workflow

1. Edit RTL in `src/`; update matching `docs/modules/...` page.
2. Keep parameters/ports in sync with elaborated RTL.
3. Update domain `index.md` descriptions when frontmatter changes.
4. Link to playbooks instead of copying stream/CDC prose.
5. Regenerate with `uv run python tools/generate_okf_bundle.py` when the catalog or verification tables change.

## Do not

- Duplicate full `CONVENTIONS.md` text in concept pages.
- Add per-file CERN-OHL-W SPDX blocks under `docs/` (see [Licencing](../../../docs/index.md#licencing)).
- Rename frozen packages or move bundle root without updating `AGENTS.md`.
