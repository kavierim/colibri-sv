---
type: Module
title: synchro
description: Clock-domain crossing for a packed vector.
tags: [domain:common, module:synchro, cdc]
status: draft
resource: src/common/synchro.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Clock-domain crossing for a packed vector.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int                       g_DATA_LENGTH = 1` |
| `parameter logic [g_DATA_LENGTH-1:0] g_INIT_VALUE  = '0` |
| `parameter int                       g_NUM_STAGES  = 2` |


## Ports

| Declaration |
| --- |
| `input  logic                     clk_i` |
| `input  logic                     reset_i` |
| `input  logic [g_DATA_LENGTH-1:0] data_i` |
| `output logic [g_DATA_LENGTH-1:0] data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Clock domain boundary synchronizer (legacy version). Synchronizes a vector across a clock domain. g_NUM_STAGES is at least 2. VHDL requires g_DATA_LENGTH (no default). Default 1 lets Verilator elaborate this module. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/synchro.sv`.


- Upstream entity name matches module name `synchro`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

synchro #(
  // parameters from Schema
) u_synchro (
  .clk_i (...),
  .reset_i (...),
  .data_i (...),
  .data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/synchro_tb.sv | none |

# Agent notes

- Read `src/common/synchro.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/synchro_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/synchro.sv)
- [simulation](../../playbooks/simulation.md)
