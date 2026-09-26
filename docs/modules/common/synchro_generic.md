---
type: Module
title: synchro_generic
description: CDC for a user-defined payload type.
tags: [domain:common, module:synchro_generic, cdc]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/common/synchro_generic.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

CDC for a user-defined payload type.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter type data_t         = logic [7:0]` |
| `parameter g_INIT_VALUE        = 8'h00` |
| `parameter int g_NUM_STAGES    = 2` |


## Ports

| Declaration |
| --- |
| `input  logic  clk_i` |
| `input  logic  reset_i` |
| `input  data_t data_i` |
| `output data_t data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Generic clock domain boundary synchronizer. Synchronizes an arbitrary data type across a clock domain. g_NUM_STAGES is at least 2. VHDL requires data_t and g_INIT_VALUE. The defaults exist so Verilator can elaborate this module. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/synchro_generic.sv`.


- Upstream entity name matches module name `synchro_generic`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

synchro_generic #(
  // parameters from Schema
) u_synchro_generic (
  .clk_i (...),
  .reset_i (...),
  .data_i (...),
  .data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/synchro_generic_tb.sv | none |

# Agent notes

- Read `src/common/synchro_generic.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/synchro_generic_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/synchro_generic.sv)
- [simulation](../../playbooks/simulation.md)
