# Bundle changelog

## 2026-09-27

- Root integration manifests: `colibri.f`, `Bender.yml`, `colibri.core` (RTL order aligned with `verilator/files/*.f`).
- Playbook [package-managers](playbooks/package-managers.md); README and simulation/getting-started cross-links.
- FuseSoC `sim` target uses Verilator `binary` mode. `depend` example sits in a fileset. Simulation playbook lists every `run_all.sh` file-list group.
- `tools/gen_packaging.py` regenerates root integration manifests; documentation stays hand-edited under `docs/`.

## 2026-09-26

- Documentation bundle: module/package pages, playbooks (including typical datapaths), and agent entry points.
- Reference modules/packages marked `status: stable` after review pass.
- Documentation is edited in-tree; module pages follow `MODULE_TEMPLATE.md`.
- Removed `tools/` from the published repository; optional local scripts may live in `tools/` (gitignored).
- SPDX policy: ancillary repo files use Kari-only headers; `NOTICE` has no SPDX block; RTL keeps CERN-OHL-W per file.
