---
type: Playbook
title: Simulation
description: Verilator 5 regression via run_all.sh and per-domain file lists.
tags: [playbook, verilator, simulation]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
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

| Path prefix | Typical `.f` file |
| --- | --- |
| `sim/common/` | `verilator/files/common.f` |
| `sim/memory/` | `verilator/files/memory.f` |
| `sim/comms/` | `verilator/files/comms.f` |
| `sim/interfaces/` | `verilator/files/interfaces.f` |
| `sim/packet/`, `sim/pipes/` | `verilator/files/packet_pipes.f` |
| `sim/misc/` | `verilator/files/misc.f` |
| `sim/proto/aurora_64b66b/` | `verilator/files/aurora.f` |

Packages are always pulled in through `verilator/colibri.f`.

# Related

- [getting-started](getting-started.md)
- Module pages list per-module testbenches under **Verification**.
