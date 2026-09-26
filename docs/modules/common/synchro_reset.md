---
type: Module
title: synchro_reset
description: Reset synchronizer.
tags: [domain:common, module:synchro_reset, cdc]
status: draft
resource: src/common/synchro_reset.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Reset synchronizer.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter logic g_IN_POLARITY  = 1'b1` |
| `parameter logic g_OUT_POLARITY = 1'b1` |
| `parameter int   g_DURATION     = 1` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `output logic reset_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Reset signal synchronizer. Synchronizes an asynchronous reset into the destination clock domain. g_DURATION is how many destination clocks the output reset stays asserted after the input reset is released. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/synchro_reset.sv`.


- Upstream entity name matches module name `synchro_reset`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

synchro_reset #(
  // parameters from Schema
) u_synchro_reset (
  .clk_i (...),
  .reset_i (...),
  .reset_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/synchro_reset_tb.sv | none |

# Agent notes

- Read `src/common/synchro_reset.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/synchro_reset_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/synchro_reset.sv)
- [simulation](../../playbooks/simulation.md)
