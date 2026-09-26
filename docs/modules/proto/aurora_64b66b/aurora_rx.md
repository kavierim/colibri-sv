---
type: Module
title: aurora_rx
description: Aurora receiver (lanes to 64b stream).
tags: [domain:aurora, module:aurora_rx]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/proto/aurora_64b66b/aurora_rx.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Aurora receiver (lanes to 64b stream).

RTL notes: Aurora 64b/66b Receiver. Simplex multi-lane Aurora 64b/66b receiver chain (PMA/PCS): GEARBOX -> DESCRAMBLER -> BIT_SHIFT_FSM -> CHANNEL_BONDING -> DECODER changelog: - 0.1 first release - 0.2 add sub-entity register control in generics - 0.3 add multi-lane support - 0.3b: update to lhcb vhdl style guideline

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_N_LANES             = 1` |
| | `parameter int unsigned g_LANE_WIDTH          = 32` |
| | `parameter int unsigned g_GBX_BUF_SIZE        = colibri_aurora_const::c_AURORA_ENC_WIDTH * 16` |
| | `parameter bit          g_DISABLE_DESCRAMBLER = 1'b0` |
| | `parameter bit          g_USE_OPTIMIZED_GBX   = 1'b1` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic snk_clk_i` |
| | `input  logic src_clk_i` |
| | `input  logic src_reset_i` |
| | `input  logic [g_N_LANES-1:0] snk_valid_i` |
| | `input  logic [g_LANE_WIDTH-1:0] snk_data_i [0:g_N_LANES-1]` |
| | `output logic src_sop_o` |
| | `output logic src_eop_o` |
| | `output logic src_valid_o` |
| | `output logic src_error_o` |
| | `output logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] src_data_o` |
| | `output logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] src_empty_o` |
| | `output logic src_link_up_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Aurora 64b/66b Receiver. Simplex multi-lane Aurora 64b/66b receiver chain (PMA/PCS): GEARBOX -> DESCRAMBLER -> BIT_SHIFT_FSM -> CHANNEL_BONDING -> DECODER changelog: - 0.1 first release - 0.2 add sub-entity register control in generics - 0.3 add multi-lane support - 0.3b: update to lhcb vhdl style guideline Top-level receiver with optional optimized RX gearbox (`g_USE_OPTIMIZED_GBX` defaults to 1). The continuous gearbox assumes a streaming line with limited `ready` backpressure—validate buffer depth in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/aurora_rx.sv`.


- Upstream entity name matches module name `aurora_rx`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

aurora_rx #(
  // parameters from Schema
) u_aurora_rx (
  .snk_clk_i (...),
  .src_clk_i (...),
  .src_reset_i (...),
  .snk_valid_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_error_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_link_up_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/aurora_rx.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/aurora_rx.sv)
- [simulation](../../../playbooks/simulation.md)
