# Agent instructions (colibri_sv)

## Documentation

- Documentation root: [`docs/`](docs/index.md).
- Module template: [`docs/MODULE_TEMPLATE.md`](docs/MODULE_TEMPLATE.md).
- Project doc settings: [`.cursor/skills/documentation/project.md`](.cursor/skills/documentation/project.md).

## RTL

- Sources under `src/`. Follow [`CONVENTIONS.md`](CONVENTIONS.md).
- Verify with `sim/**/*_tb.sv` and [`verilator/run_all.sh`](verilator/run_all.sh).

## Maintaining docs

Edit pages under `docs/` directly (see [`docs/MODULE_TEMPLATE.md`](docs/MODULE_TEMPLATE.md)). Keep each module page in sync with its `resource` RTL file. There is no in-repo doc generator; `tools/` is not published (see `.gitignore`).

## Parallel work

- Own one `docs/modules/<domain>/` tree per change.
- Append meaningful updates to [`docs/log.md`](docs/log.md).
- Do not duplicate `CONVENTIONS.md` in documentation pages; link it.

## Upstream

VHDL reference: commit `3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f` on [colibri-cern/colibri](https://gitlab.com/colibri-cern/colibri).
