---
type: Module
title: interleaver
description: Merge multiple packet streams into one.
tags: [domain:packet, module:interleaver]
status: draft
resource: src/packet/interleaver.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Merge multiple packet streams into one.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_NUM_INPUTS       = 3` |
| `parameter int unsigned g_DATA_WIDTH       = 32` |
| `parameter bit          g_INTERLEAVE_WORDS = 1'b1` |


## Ports

| Declaration |
| --- |
| `input  logic                         clk_i` |
| `input  logic                         reset_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_sop_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_eop_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_valid_i` |
| `output logic [g_NUM_INPUTS-1:0]      snk_ready_o` |
| `input  logic [g_NUM_INPUTS*c_DATA_W-1:0]  snk_data_i` |
| `input  logic [g_NUM_INPUTS*c_EMPTY_W-1:0] snk_empty_i` |
| `output logic                         src_sop_o` |
| `output logic                         src_eop_o` |
| `output logic                         src_valid_o` |
| `input  logic                         src_ready_i` |
| `output logic [c_DATA_W-1:0]          src_data_o` |
| `output logic [c_EMPTY_W-1:0]         src_empty_o` |
| `output logic [c_CH_W-1:0]            src_channel_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Interleaves Avalon-ST streams into one stream and tags the source with src_channel_o. Packets already in flight win; otherwise the grant rotates. g_INTERLEAVE_WORDS selects word interleaving or whole-packet boundaries. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/interleaver.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `interleaver`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

interleaver #(
  // parameters from Schema
) u_interleaver (
  .clk_i (...),
  .reset_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_channel_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/interleaver_tb.sv | fv/packet/interleaver_sva.sv, interleaver_bd_sva.sv |

# Agent notes

- Read `src/packet/interleaver.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/interleaver_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/interleaver.sv)
- [simulation](../../playbooks/simulation.md)
