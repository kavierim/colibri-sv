---
type: Playbook
title: Simulation
description: Verilator 5 regression via run_all.sh and per-domain file lists.
tags: [playbook, verilator, simulation]
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Requirements

Verilator 5 with `--timing` and `--assert`.

# Full regression

From the repository root:

```sh
./verilator/run_all.sh
```

The script discovers every `sim/**/*_tb.sv`, selects a matching `verilator/files/*.f` list from the testbench path, builds, runs, and exits non-zero if any test fails.

# File lists

## Full RTL (`colibri.f`)

[`colibri.f`](../../colibri.f) at the repository root lists every `src/**/*.sv` file in dependency order (same order as the `verilator/files/*.f` fragments combined). Use it for lint or integration builds. Regression uses the split lists below so each testbench compiles only the RTL it needs.

## Per-testbench lists (`verilator/`)

`run_all.sh` always passes `verilator/colibri.f`, then the lists below.

| Testbench path | Additional file lists under `verilator/files/` |
| --- | --- |
| `sim/common/` | `common.f` |
| `sim/memory/`, `sim/comms/` | `common.f`, `memory.f`, `comms.f` |
| `sim/endec/` | `common.f`, `endec.f` |
| `sim/io/` | `common.f`, `io.f` |
| `sim/interfaces/` | `common.f`, `memory.f`, `interfaces.f` |
| `sim/packet/`, `sim/pipes/` | `common.f`, `memory.f`, `interfaces.f`, `misc.f`, `packet_pipes.f` |
| `sim/misc/` | `common.f`, `memory.f`, `interfaces.f`, `misc.f` |
| `sim/proto/` | `common.f`, `memory.f`, `comms.f`, `endec.f`, `aurora.f` |
| `sim/fileio/` | `fileio.f` |

Bound checkers under `fv/` are selected per testbench by `run_all.sh`, not by these lists.

# Related

- [getting-started](getting-started.md)
- [package-managers](package-managers.md)
- Module pages list per-module testbenches under **Verification**.
