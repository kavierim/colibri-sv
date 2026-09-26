<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Colibri SystemVerilog

Unofficial SystemVerilog port of the CERN [colibri](https://gitlab.com/colibri-cern/colibri) library, pinned to commit [`3fa7841`](https://gitlab.com/colibri-cern/colibri/-/commit/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f). CERN has not endorsed this port.

The port is for free SystemVerilog tools, especially [Verilator](https://www.veripool.org/verilator/).

## Licence

CERN-OHL-W-2.0. The text is [`LICENSES/CERN-OHL-W-2.0.txt`](LICENSES/CERN-OHL-W-2.0.txt). [`NOTICE`](NOTICE) records the modification and the source location.

## Simulation

Requires Verilator 5 (`--timing` and `--assert`). From this directory:

```sh
sudo apt install verilator
./verilator/run_all.sh
```

The script builds every `sim/**/*_tb.sv` and exits 0 only when every test passes. GitHub Actions runs the same script.

## Names

VHDL packages use a `colibri_` prefix: `utils` is `colibri_utils`, and the same for `types`, `encoders`, `poly`, `mem`, `common_8b10b`, `aurora_const`, and `binaryio`. Module and port names are unchanged. The translation rules are in [`CONVENTIONS.md`](CONVENTIONS.md).

## Documentation

Canonical module and package documentation is under [`docs/`](docs/index.md). Coding agents should start from [`AGENTS.md`](AGENTS.md).

- [Bundle index](docs/index.md)
- [Playbooks](docs/playbooks/index.md)
- [Module catalog](docs/modules/index.md)
- [Packages](docs/packages/index.md)

## Components

Module and package catalog: [`docs/modules/index.md`](docs/modules/index.md) and [`docs/packages/index.md`](docs/packages/index.md). [`COMPONENTS.md`](COMPONENTS.md) points to the bundle.

## Layout

| Path | Contents |
| --- | --- |
| `src/` | RTL and packages |
| `sim/` | Self-checking testbenches |
| `fv/` | SystemVerilog assertions |
| `verilator/run_all.sh` | Full regression |
