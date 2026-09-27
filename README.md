<!--
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland

Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.
-->

# Colibri SystemVerilog

[![CI Status](https://github.com/kavierim/colibri-sv/actions/workflows/verilator.yml/badge.svg)](https://github.com/kavierim/colibri-sv/actions/workflows/verilator.yml)

Open-source SystemVerilog port of the CERN **colibri** VHDL library for [Verilator](https://www.veripool.org/verilator/) and other free EDA tooling: reusable FPGA/ASIC RTL components (memory, buses, I/O, packet handling, and more).

This repository is an **unofficial** port. CERN has not endorsed it. It is pinned to upstream commit [`3fa7841`](https://gitlab.com/colibri-cern/colibri/-/commit/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f).

## Licence

CERN-OHL-W-2.0. The text is [`LICENSES/CERN-OHL-W-2.0.txt`](LICENSES/CERN-OHL-W-2.0.txt). [`NOTICE`](NOTICE) records the modification and the source location. Release history: [`CHANGELOG.md`](CHANGELOG.md).

## Simulation

Requires Verilator 5 (`--timing` and `--assert`). From this directory:

```sh
sudo apt install verilator
./verilator/run_all.sh
```

The script builds every `sim/**/*_tb.sv` and exits 0 only when every test passes. GitHub Actions runs the same script.

## Package managers and integration

| Artifact | Use |
| --- | --- |
| [`colibri.f`](colibri.f) | Full `src/` compile order and `+incdir+src` for simulators |
| [`Bender.yml`](Bender.yml) | [Bender](https://github.com/pulp-platform/bender) package `colibri-sv` |
| [`colibri.core`](colibri.core) | FuseSoC core `kavierim:colibri:sv:0.1.0` (`default` = RTL, `sim` = Verilator testbenches) |

Details: [Package managers and integration](docs/playbooks/package-managers.md).

## Names

VHDL packages use a `colibri_` prefix: `utils` is `colibri_utils`, and the same for `types`, `encoders`, `poly`, `mem`, `common_8b10b`, `aurora_const`, and `binaryio`. Module and port names are unchanged. The translation rules are in [`CONVENTIONS.md`](CONVENTIONS.md).

## Documentation

Canonical module and package documentation is under [`docs/`](docs/index.md), maintained directly in the repo. Coding agents should start from [`AGENTS.md`](AGENTS.md).

- [Bundle index](docs/index.md)
- [Playbooks](docs/playbooks/index.md)
- [Module catalog](docs/modules/index.md)
- [Packages](docs/packages/index.md)

## SysML v2

The structural model lives in [`sysml/`](sysml/Colibri.sysml). There is one `part def` per SystemVerilog module. Edit that part before the matching file under `src/`. SHALL sentences stay on the module page in [`docs/modules/`](docs/modules/index.md). [`sysml/requirements.sysml`](sysml/requirements.sysml) stores only the requirement identifier and a link to that page.

`sysml/parts/` is Covered Source under CERN-OHL-W-2.0, like the RTL. The library index, metadata, and requirement stubs are ancillary.

- [SysML playbook](docs/playbooks/sysml.md)
- Check agreement of the model, the stubs, and the RTL ports: `uv run python tools/check_sysml_ssot.py`

## Components

Module and package catalog: [`docs/modules/index.md`](docs/modules/index.md) and [`docs/packages/index.md`](docs/packages/index.md). [`COMPONENTS.md`](COMPONENTS.md) points to the bundle.

## Layout

| Path | Contents |
| --- | --- |
| `src/` | RTL and packages |
| `sim/` | Self-checking testbenches |
| `fv/` | SystemVerilog assertions |
| `docs/` | Module and package documentation |
| `sysml/` | SysML v2 structural model (`parts/`), requirement stubs, library index. Edit the model before RTL. |
| `colibri.f`, `Bender.yml`, `colibri.core` | Integration manifests (see above) |
| `tools/gen_packaging.py` | Regenerates those manifests from `verilator/files/` |
| `tools/check_sysml_ssot.py` | Checks that the SysML model, requirement stubs, and RTL ports still match (see [sysml playbook](docs/playbooks/sysml.md)) |
| `verilator/run_all.sh` | Full regression |

## CERN upstream (colibri)

| Resource | Link |
| --- | --- |
| Official GitLab repository | [gitlab.com/colibri-cern/colibri](https://gitlab.com/colibri-cern/colibri) |
| CERN GitLab mirror | [gitlab.cern.ch/colibri/colibri](https://gitlab.cern.ch/colibri/colibri) |
| Project documentation | [colibri.docs.cern.ch](https://colibri.docs.cern.ch) |
| CERN Open Hardware Repository | [ohwr.org](https://ohwr.org/) (upstream registers via `.ohwr.yaml`; see the GitLab repo) |
