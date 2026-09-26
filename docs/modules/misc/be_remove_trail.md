---
type: Module
title: be_remove_trail
description: Remove the trailing word (e.g. CRC).
tags: [domain:misc, module:be_remove_trail]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/misc/be_remove_trail.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Remove the trailing word (e.g. CRC).

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH   = 32` |
| `parameter bit          g_REGISTER_OUT = 1'b0` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8):0] shl_i` |
| `output logic snk_ready_o` |
| `input  logic snk_valid_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] snk_empty_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic src_ready_i` |
| `output logic src_valid_o` |
| `output logic src_sop_o` |
| `output logic src_eop_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] src_empty_o` |
| `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| `output logic [g_DATA_WIDTH-1:0] src_tail_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Big-endian packet remove-trailing-bytes module. Removes `shl_i` bytes and returns them on `src_tail_o` at `src_eop_o`. `g_REGISTER_OUT` is in the VHDL entity and unused by the architecture. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/be_remove_trail.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `be_remove_trail`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

be_remove_trail #(
  // parameters from Schema
) u_be_remove_trail (
  .clk_i (...),
  .reset_i (...),
  .shl_i (...),
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
  .src_data_o (...),
  .src_tail_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/be_remove_trail_tb.sv | fv/misc/be_remove_trail_sva.sv |

# Agent notes

- Read `src/misc/be_remove_trail.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/be_remove_trail_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/be_remove_trail.sv)
- [simulation](../../playbooks/simulation.md)
