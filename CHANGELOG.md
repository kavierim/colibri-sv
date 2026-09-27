<!--
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland

Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.
-->

# Changelog

Release notes for [colibri-sv](https://github.com/kavierim/colibri-sv). Version numbers track this port, not the upstream CERN colibri VHDL library.

## [0.1.0] - 2026-09-27

First public release: unofficial SystemVerilog translation of CERN colibri, aimed at Verilator 5 and other free EDA flows.

### RTL

- Complete port of upstream colibri at commit [`3fa7841`](https://gitlab.com/colibri-cern/colibri/-/commit/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f): common utilities, memory, communications, encoders/decoders, bus and stream interfaces, I/O (UART, SPI, I2C, JTAG), packet and pipe blocks, Aurora 64b/66b protocol stack, mmap FIFO and related misc blocks, and `binaryio`.
- VHDL packages exposed as SystemVerilog packages with a `colibri_` prefix where needed (`colibri_utils`, `colibri_types`, and others); module and port names match upstream where the language allows.
- Translation rules and naming contract documented in [`CONVENTIONS.md`](CONVENTIONS.md).

### Verification

- Self-checking testbenches under `sim/` for all major domains.
- SystemVerilog assertion bind collateral under `fv/` for selected modules.
- Full regression via [`verilator/run_all.sh`](verilator/run_all.sh) (Verilator 5, `--timing` and `--assert`).
- Continuous integration on GitHub Actions (workflow `verilator`).

### Documentation

- In-repository module and package catalog under [`docs/`](docs/index.md), with playbooks for getting started, simulation, stream interfaces, integration, and agent workflow.
- [`AGENTS.md`](AGENTS.md) and [`COMPONENTS.md`](COMPONENTS.md) as entry points for contributors and tooling.

### SysML v2

- Structural model under [`sysml/parts/`](sysml/parts): one part definition per SystemVerilog module. Edit the part before the RTL.
- Requirement identifiers in [`sysml/requirements.sysml`](sysml/requirements.sysml) link to SHALL text in `docs/modules/`. [`counter`](docs/modules/common/counter.md) is the worked example.
- [`tools/check_sysml_ssot.py`](tools/check_sysml_ssot.py) reports divergence between the model, the stubs, and the RTL ports. It does not regenerate files.

### Integration

- [`colibri.f`](colibri.f): full `src/` compile order and `+incdir+src`.
- [`Bender.yml`](Bender.yml): package `colibri-sv` (version 0.1.0).
- [`colibri.core`](colibri.core): FuseSoC core `kavierim:colibri:sv:0.1.0`.
- [`tools/gen_packaging.py`](tools/gen_packaging.py) regenerates the root manifests from `verilator/files/*.f`.

### Licence and provenance

- Covered Source under [CERN-OHL-W-2.0](LICENSES/CERN-OHL-W-2.0.txt); modification and upstream pin recorded in [`NOTICE`](NOTICE).
- This is not an official CERN project; CERN has not endorsed this port.
