---
type: Module
title: aurora_st_encoder
description: Aurora stream encoder block.
tags: [domain:aurora, module:aurora_st_encoder]
status: draft
resource: src/proto/aurora_64b66b/tx/aurora_st_encoder.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Aurora stream encoder block.

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_N_LANES    = 1` |
| `parameter int unsigned g_FIFO_WORDS = 8` |
| `parameter int unsigned g_LANE_WIDTH = 32` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `input  logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] snk_empty_i` |
| `output logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] src_data_o [0:g_N_LANES-1]` |
| `input  logic [g_N_LANES-1:0] src_ready_i` |
| `output logic [g_N_LANES-1:0] src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Aurora 64b/66b Encoder. Simplex multi-lane encoder. A 64-bit Avalon packet stream is encoded into Aurora lanes. A channel bonding word is sent every 64 cycles when more than one lane is used. After reset, idle words are sent for 64 cycles, then snk_ready_o is asserted. changelog: - 0.4 significant rewrite to clean up code (removed fifos) - 0.3b Update to VHDL Style Guideline - 0.3 Update to VHDL common library - 0.2 Adding Channel Bonding Feature - 0.1 first release Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/tx/aurora_st_encoder.sv`.


- Upstream entity name matches module name `aurora_st_encoder`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

aurora_st_encoder #(
  // parameters from Schema
) u_aurora_st_encoder (
  .clk_i (...),
  .reset_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .src_ready_i (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/tx/aurora_st_encoder.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/tx/aurora_st_encoder.sv)
- [simulation](../../../playbooks/simulation.md)
