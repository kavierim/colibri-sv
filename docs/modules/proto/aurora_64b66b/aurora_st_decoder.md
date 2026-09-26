---
type: Module
title: aurora_st_decoder
description: Aurora stream decoder block.
tags: [domain:aurora, module:aurora_st_decoder]
status: draft
resource: src/proto/aurora_64b66b/rx/aurora_st_decoder.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Aurora stream decoder block.

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
| `input  logic snk_link_up_i` |
| `input  logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] snk_data_i [0:g_N_LANES-1]` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `output logic src_sop_o` |
| `output logic src_eop_o` |
| `output logic src_valid_o` |
| `output logic src_error_o` |
| `output logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] src_data_o` |
| `output logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] src_empty_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Aurora 64b/66b Decoder. Simplex multi-lane decoder. snk_link_up_i marks the end of link training and channel bonding. The first packet is dropped. src_error_o is set when the link drops mid-packet, or when a bond word arrives on a single lane. Changelog: - 0.5 Channel Bond lane mismatch error handling - 0.4 code cleanup rewriting - 0.3b update to vhdl style guideline - 0.3 Add Multi-Lane support - 0.2 FIX behaviour when valid is oscillating - 0.1 first release Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/rx/aurora_st_decoder.sv`.


- Upstream entity name matches module name `aurora_st_decoder`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

aurora_st_decoder #(
  // parameters from Schema
) u_aurora_st_decoder (
  .clk_i (...),
  .reset_i (...),
  .snk_link_up_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_error_o (...),
  .src_data_o (...),
  .src_empty_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/rx/aurora_st_decoder.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/rx/aurora_st_decoder.sv)
- [simulation](../../../playbooks/simulation.md)
