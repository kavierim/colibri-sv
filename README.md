<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Colibri SystemVerilog

This directory is a SystemVerilog translation of the CERN [colibri](https://gitlab.com/colibri-cern/colibri) VHDL library. It is a translation of that Covered Source under CERN-OHL-W-2.0. It is not an official CERN project, and CERN has not endorsed it.

The translation is pinned to upstream commit `3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f` (2026-07-17).

## Licence

The sources are CERN-OHL-W-2.0. The licence text is `LICENSES/CERN-OHL-W-2.0.txt`. See `NOTICE` for the modification record and the Source Location.

## Layout

`CONVENTIONS.md` is the rule set for the translation: package names, constant functions, record macros, and file ownership. `src/common/counter.sv` is the module style reference. `verilator/colibri.f` lists sources in dependency order.

## Simulation target

The simulator is Verilator on WSL2 (Verilator 5, with `--timing`). Wave 0 was linted with Verilator 5.020:

```text
verilator --lint-only -Wall -Wno-DECLFILENAME -f verilator/colibri.f
```

Run that from this directory. On Windows, `wsl` can see the tree under `/mnt/c/Work/colibri/colibri_sv`.

Install and regression commands for the full library will be added here once the testbenches exist. The intended simulation invocation is `verilator --timing --binary --assert -f verilator/colibri.f`, driven by a script that runs every testbench.
