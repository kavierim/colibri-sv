<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Colibri SystemVerilog

Unofficial SystemVerilog port of the CERN [colibri](https://gitlab.com/colibri-cern/colibri) library. CERN has not endorsed this port, and it is not an official CERN project.

The translation is pinned to upstream commit [`3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f`](https://gitlab.com/colibri-cern/colibri/-/commit/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f) (2026-07-17).

The port exists so the library can be simulated and developed with free SystemVerilog tools, especially [Verilator](https://www.veripool.org/verilator/).

Author of this modification: Kari Vierimaa, Kempele, Finland.

## Licence

The sources are CERN-OHL-W-2.0. The licence text is [`LICENSES/CERN-OHL-W-2.0.txt`](LICENSES/CERN-OHL-W-2.0.txt). [`NOTICE`](NOTICE) records the modification and the Source Location.

Use of the CERN Open Hardware Licence does not imply endorsement by CERN.

## Package names

VHDL packages in library `colibri` are SystemVerilog packages. The names changed because a package cannot share a name with a translation unit in the same compile:

| VHDL package | SystemVerilog package |
| --- | --- |
| `utils` | `colibri_utils` |
| `types` | `colibri_types` |
| `encoders` | `colibri_encoders` |
| `poly` | `colibri_poly` |
| `mem` | `colibri_mem` |
| `common_8b10b` | `colibri_common_8b10b` |
| `aurora_const` | `colibri_aurora_const` |
| `binaryio` | `colibri_binaryio` |

Module names, generic names, and port names are kept where the language allows. `CONVENTIONS.md` is the rule set for the translation.

## Behaviour notes

A few places differ from the VHDL because of the simulator or the language:

- Verilator is two-state. Values that were `'X'` or `'U'` in VHDL are `0` or `1` here.
- I2C released SCL is driven high under `` `VERILATOR` ``. Verilator has no pull-up resolution, so an open-drain release cannot float the line high by itself.
- In the `mmap_fifo` test, RX simple packets are capped at 56 bytes. The RX FSM raises overflow at `NUM_WORDS-2` words, and the test stays inside that limit.
- A null VHDL range (`0 downto 1`, and the same shape) becomes 1 bit through `downto_width`. SystemVerilog does not have VHDL's null ranges.
- Some wide `bits#(W)::swap_endianness` calls were replaced at the call site. Verilator 5.020 reports `SELRANGE` on those calls.

## Simulation

The regression target is Verilator 5 with `--timing` and `--assert`. This tree was run with Verilator 5.020.

On WSL2:

```text
sudo apt install verilator
cd /mnt/c/Work/colibri/colibri_sv
verilator/run_all.sh
```

`verilator/run_all.sh` builds and runs every `sim/**/*_tb.sv`. Each test gets its own `obj_dir/<tbname>`. The script prints a pass/fail summary and exits 0 only when every binary exits 0. `JOBS` defaults to 4.

GitHub Actions runs the same script on `ubuntu-latest` after `apt install verilator` (`.github/workflows/verilator.yml`).

## Layout

| Path | Contents |
| --- | --- |
| `src/` | RTL and packages |
| `sim/` | Self-checking testbenches |
| `fv/` | SVA bound to the RTL |
| `verilator/colibri.f` | Wave 0 sources in dependency order |
| `verilator/files/` | Per-directory source lists |
| `verilator/run_all.sh` | Full regression |
