<!--
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland

Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.
-->

# Colibri SystemVerilog - Open RTL for Avalon-ST and AXI-Stream packet blocks

[![Verilator](https://github.com/kavierim/colibri-sv/actions/workflows/verilator.yml/badge.svg)](https://github.com/kavierim/colibri-sv/actions/workflows/verilator.yml)
[![ASIC synth](https://github.com/kavierim/colibri-sv/actions/workflows/asic-synth.yml/badge.svg)](https://github.com/kavierim/colibri-sv/actions/workflows/asic-synth.yml)

**colibri-sv** is an unofficial SystemVerilog RTL port of the CERN [colibri](https://gitlab.com/colibri-cern/colibri) VHDL library. It provides reusable packet and stream blocks (Avalon-ST, AXI-Stream subset), memories, bus adapters, and related IP for Verilator simulation and an ASIC synthesis smoke check with Yosys. CERN has not endorsed this port. Sources are pinned to upstream commit [`3fa7841`](https://gitlab.com/colibri-cern/colibri/-/commit/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f).

## Overview

CERN colibri is a VHDL component library aimed at FPGA and ASIC designs. This repository translates that library to SystemVerilog so free EDA flows—especially Verilator 5 and Yosys `read_slang`—can compile and check the same style of stream/packet datapath without a proprietary simulator.

Use it when you need Avalon-ST or AXI-Stream–oriented RTL (FIFOs, CRC, width converters, header/packet helpers, Wishbone bridges, and related blocks) under CERN-OHL-W, with self-checking testbenches and optional Python behavioral models.

## Key features

- SystemVerilog RTL under `src/`, organized by domain (common, memory, packet, interfaces, comms, and others)
- Avalon-ST and AXI-Stream subset adapters and packet/stream building blocks
- Self-checking Verilator 5 regression: `./verilator/run_all.sh`
- ASIC synthesis smoke via Yosys (`read_slang` + generic `synth`): `tools/synth_asic.py`
- Integration manifests: [`colibri.f`](colibri.f), [Bender](https://github.com/pulp-platform/bender) [`Bender.yml`](Bender.yml), FuseSoC [`colibri.core`](colibri.core)
- Behavioral Python models under `model/` (`uv run pytest`)
- SysML v2 structural model under `sysml/`; module docs under [`docs/`](docs/index.md)

## Architecture / tech stack

| Layer | Role |
| --- | --- |
| `src/` | SystemVerilog modules and packages (`colibri_*` package names) |
| `sim/` | Self-checking `*_tb.sv` testbenches |
| `fv/` | SystemVerilog assertions |
| `verilator/` | File lists and `run_all.sh` regression |
| `tools/synth_asic.py` | Yosys ASIC smoke (generic `synth`, not FPGA `synth_*`) |
| `model/` | Python behavioral models (`colibri_model/`) via [uv](https://github.com/astral-sh/uv) |
| `sysml/` | SysML v2 parts (edit before matching RTL) |
| `docs/` | Module catalog, playbooks, packages |

Naming and VHDL→SV rules: [`CONVENTIONS.md`](CONVENTIONS.md). Packaging details: [package managers](docs/playbooks/package-managers.md).

## Quickstart / installation

### Verilator simulation

Requires Verilator 5 (`--timing` and `--assert`). From this directory:

```sh
sudo apt install verilator
./verilator/run_all.sh
```

The script builds every `sim/**/*_tb.sv` and exits 0 only when every test passes. GitHub Actions (`verilator.yml`) runs the same script.

### Behavioral models (Python / uv)

```sh
cd model
uv run pytest
```

See [model playbook](docs/playbooks/model.md).

### ASIC synthesis smoke (Yosys)

Install [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) (CI pins release `20260930` / linux-x64), activate it, then from the repository root:

```sh
source /path/to/oss-cad-suite/environment
python3 tools/synth_asic.py
```

Details and accepted exceptions: [ASIC synthesis smoke](docs/playbooks/asic-synth.md).

This is a smoke check, not a Liberty- or SRAM-mapped signoff. Accepted exceptions:

- Yosys does not strip `// xilinx translate_off` comments, so `get_compiler()` stays `AUTO` and `true_dpram` uses the behavioral model.
- Memories may map to flip-flops rather than RAM macros.
- Files with no module (for example `src/fileio/binaryio.sv`) are not synthesised as tops.

## Usage / example

**Pull RTL into a Verilator project** using one of:

- [`colibri.f`](colibri.f) — full `src/` compile order and `+incdir+src`
- Domain file lists under `verilator/files/` (see [getting started](docs/playbooks/getting-started.md))
- Bender package `colibri-sv` or FuseSoC core `kavierim:colibri:sv:0.1.0`

Import packages as needed:

```systemverilog
import colibri_utils::*;
import colibri_types::*;
```

Pick modules from the [module catalog](docs/modules/index.md). Stream adapters and packet blocks assume Avalon-ST / AXI-Stream macros from `colibri_types`; see [stream interfaces](docs/playbooks/stream-interfaces.md).

**Confirm the tree still matches CI:**

```sh
./verilator/run_all.sh
# optional, with oss-cad-suite on PATH:
python3 tools/synth_asic.py
```

## Licence

CERN-OHL-W-2.0. The text is [`LICENSES/CERN-OHL-W-2.0.txt`](LICENSES/CERN-OHL-W-2.0.txt). [`NOTICE`](NOTICE) records the modification and the source location. Release history: [`CHANGELOG.md`](CHANGELOG.md). Bundle changelog: [`docs/log.md`](docs/log.md).

## Documentation

Canonical module and package documentation is under [`docs/`](docs/index.md). Coding agents should start from [`AGENTS.md`](AGENTS.md).

- [Bundle index](docs/index.md)
- [Playbooks](docs/playbooks/index.md)
- [Getting started](docs/playbooks/getting-started.md)
- [Behavioral models](docs/playbooks/model.md) (`model/`)
- [ASIC synthesis smoke](docs/playbooks/asic-synth.md) (Yosys generic `synth`)
- [Module catalog](docs/modules/index.md)
- [Packages](docs/packages/index.md)
- [SysML playbook](docs/playbooks/sysml.md) — check with `uv run python tools/check_sysml_ssot.py`

## Layout

| Path | Contents |
| --- | --- |
| `src/` | RTL and packages |
| `sim/` | Self-checking testbenches |
| `fv/` | SystemVerilog assertions |
| `docs/` | Module and package documentation |
| `model/` | Behavioral Python models (`colibri_model/`) and shared kernel |
| `sysml/` | SysML v2 structural model (`parts/`), requirement stubs, library index |
| `colibri.f`, `Bender.yml`, `colibri.core` | Integration manifests |
| `tools/gen_packaging.py` | Regenerates those manifests from `verilator/files/` |
| `tools/check_sysml_ssot.py` | SysML / RTL / docs agreement check |
| `tools/synth_asic.py` | Yosys ASIC smoke |
| `verilator/run_all.sh` | Full regression |

## CERN upstream (colibri)

| Resource | Link |
| --- | --- |
| Official GitLab repository | [gitlab.com/colibri-cern/colibri](https://gitlab.com/colibri-cern/colibri) |
| CERN GitLab mirror | [gitlab.cern.ch/colibri/colibri](https://gitlab.cern.ch/colibri/colibri) |
| Project documentation | [colibri.docs.cern.ch](https://colibri.docs.cern.ch) |
| CERN Open Hardware Repository | [ohwr.org](https://ohwr.org/) (upstream registers via `.ohwr.yaml`; see the GitLab repo) |
