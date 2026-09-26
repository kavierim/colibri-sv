# Agent instructions (colibri_sv)

## Documentation

- Documentation root: [`docs/`](docs/index.md).
- Module template: [`docs/MODULE_TEMPLATE.md`](docs/MODULE_TEMPLATE.md).
- Project doc settings: [`.cursor/skills/documentation/project.md`](.cursor/skills/documentation/project.md).

## RTL

- Sources under `src/`. Follow [`CONVENTIONS.md`](CONVENTIONS.md).
- Verify with `sim/**/*_tb.sv` and [`verilator/run_all.sh`](verilator/run_all.sh).

## Regenerating docs

From repo root: `uv run python tools/generate_okf_bundle.py` — refreshes generated module/package pages, playbooks, pointer readmes, and this file. Extend enrichments in `tools/generate_okf_bundle.py` instead of one-off edits that the next regen will overwrite.

## Parallel work

- Own one `docs/modules/<domain>/` tree per change.
- Append meaningful updates to [`docs/log.md`](docs/log.md).
- Do not duplicate `CONVENTIONS.md` in documentation pages; link it.

## Upstream

VHDL reference: commit `3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f` on [colibri-cern/colibri](https://gitlab.com/colibri-cern/colibri).
