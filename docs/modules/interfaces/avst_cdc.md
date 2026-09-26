---
type: Module
title: avst_cdc
description: Avalon-ST clock-domain crossing.
tags: [domain:interfaces, module:avst_cdc, interface:avst, cdc]
status: stable
resource: src/interfaces/stream/avst_cdc.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Avalon-ST clock-domain crossing.

# When to use

For AVST packet streams across clocks; arbitrary payloads may use [`synchro_handshake`](../common/synchro_handshake.md) instead.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH = 16` |


## Ports

| Declaration |
| --- |
| `input  logic                     reset_i` |
| `input  logic                     snk_clk_i` |
| `input  logic                     src_clk_i` |
| `output logic                     snk_ready_o` |
| `input  logic                     snk_valid_i` |
| `input  logic                     snk_sop_i` |
| `input  logic                     snk_eop_i` |
| `input  logic [c_EMPTY_W-1:0]     snk_empty_i` |
| `input  logic [g_DATA_WIDTH-1:0]  snk_data_i` |
| `input  logic                     src_ready_i` |
| `output logic                     src_valid_o` |
| `output logic                     src_sop_o` |
| `output logic                     src_eop_o` |
| `output logic [c_EMPTY_W-1:0]     src_empty_o` |
| `output logic [g_DATA_WIDTH-1:0]  src_data_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Avalon-ST simple clock domain crossing. Library modules are tops alongside wave0_elab until a later wave instantiates them. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_cdc.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_cdc`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_cdc #(
  // parameters from Schema
) u_avst_cdc (
  .reset_i (...),
  .snk_clk_i (...),
  .src_clk_i (...),
  .snk_ready_o (...),
  .snk_valid_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_empty_i (...),
  .snk_data_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_cdc_tb.sv | none |

# Agent notes

- Read `src/interfaces/stream/avst_cdc.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_cdc_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_cdc.sv)
- [simulation](../../playbooks/simulation.md)
