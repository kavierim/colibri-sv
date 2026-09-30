# Bundle changelog

## 2026-09-30

- README rewritten for public search visibility (keyword-led H1/overview, Quickstart with Verilator / `uv` model / Yosys synth paths); CI badges and ASIC synth exceptions unchanged.
- ASIC synthesis smoke: `tools/synth_asic.py` (Yosys `read_slang` + generic `synth` per `src/` module), CI workflow `asic-synth.yml` (oss-cad-suite `20260930`), playbook [asic-synth](playbooks/asic-synth.md). RTL fixes for Yosys: task→function in unaligned AVST RAM blocks, `$error`/`SYNTHESIS` guard in `axis_to_avst`, bounded loops in `avst_width_converter`, `gearbox_up` parameter defaults, local gray helpers in `cc_fifo` / `packet_cc_fifo` (avoids multi-`enc#` Yosys assert).
- README documents both Verilator and ASIC synth CI, plus accepted synth exceptions (behavioral RAM / flops, package-only skip, not Liberty/SRAM signoff).
- Behavioral models under `model/` (`colibri_model/`, shared `kernel/`); playbook [model](playbooks/model.md). Cross-repo chain test `model/tests/test_compat_poc.py` (optional sibling `PoC_sv/model`). `# Model` sections on the six runnable module pages. `AGENTS.md` / README note that SysML `parts/` are not regenerated.

## 2026-09-27

- SHALL prose moved from YAML `requirements[].statement` into `# Requirements` body paragraphs on **28** fv-backed module pages; frontmatter keeps OKF metadata only. `tools/check_sysml_ssot.py` parses SHALL from markdown; `tools/apply_okf_requirements_rollout.py` remains the statement/fv mapping for rollout and migration.
- OKF v0.2 `requirements[]` + SysML stubs/satisfy rolled out to **27** fv-backed modules (140 requirements) following the [`counter`](modules/common/counter.md) pattern; `tools/apply_okf_requirements_rollout.py` holds the mapping. Skipped (no Module page or no dedicated fv obligation): `utils_fv`, CSR-only mmap FIFO blocks, `uart_rx`/`uart_tx` standalone, `block_sync_fsm`, and sim-only blocks without fv bind collateral.
- OKF requirement stubs and `satisfy` on parts; reconciliation: [req-okf-reconciliation](reference/req-okf-reconciliation.md). Checker enforces body/stub/part alignment.
- Each part file references its own definition (`part wbRamUse : wb_ram` in the same package). Metadata definitions in `ArchitectureMeta.sysml` document `@OKFReference` and `@ArtifactTrace`.
- SysML v2 is the structural source: edit `sysml/parts/` before RTL. Generators removed. Requirement stubs kept only for [`counter`](modules/common/counter.md); dumped `$fatal` and PSL fragments removed from other module pages. `tools/check_sysml_ssot.py` reports divergence. Textual notation checked with sysml-v2-lsp 0.29.0: no syntax or semantic errors (unused-definition warnings only, because the parts are a library).
- [`CHANGELOG.md`](../CHANGELOG.md) for release **0.1.0** (release-level notes).
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
