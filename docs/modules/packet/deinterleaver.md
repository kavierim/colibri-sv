---
type: Module
title: deinterleaver
description: Split one stream into multiple outputs.
tags: [domain:packet, module:deinterleaver]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/packet/deinterleaver.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Split one stream into multiple outputs.

RTL notes: Deinterleaves one Avalon-ST stream into g_NUM_OUTPUTS streams using the sideband identifier snk_channel_i.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_NUM_OUTPUTS = 3` |
| | `parameter int unsigned g_DATA_WIDTH  = 32` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                         clk_i` |
| | `input  logic                         reset_i` |
| | `input  logic                         snk_sop_i` |
| | `input  logic                         snk_eop_i` |
| | `input  logic                         snk_valid_i` |
| | `output logic                         snk_ready_o` |
| | `input  logic [c_DATA_W-1:0]          snk_data_i` |
| | `input  logic [c_EMPTY_W-1:0]         snk_empty_i` |
| | `input  logic [c_CH_W-1:0]            snk_channel_i` |
| | `output logic [g_NUM_OUTPUTS-1:0]     src_sop_o` |
| | `output logic [g_NUM_OUTPUTS-1:0]     src_eop_o` |
| | `output logic [g_NUM_OUTPUTS-1:0]     src_valid_o` |
| | `input  logic [g_NUM_OUTPUTS-1:0]     src_ready_i` |
| | `output logic [c_DATA_W-1:0]          src_data_o [g_NUM_OUTPUTS-1:0]` |
| | `output logic [c_EMPTY_W-1:0]         src_empty_o [g_NUM_OUTPUTS-1:0]` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Deinterleaves one Avalon-ST stream into g_NUM_OUTPUTS streams using the sideband identifier snk_channel_i. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/deinterleaver.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `deinterleaver`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

deinterleaver #(
  // parameters from Schema
) u_deinterleaver (
  .clk_i (...),
  .reset_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_channel_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/interleaver_loopback_tb.sv | fv/packet/deinterleaver_sva.sv |

# Agent notes

- Read `src/packet/deinterleaver.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/interleaver_loopback_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/deinterleaver.sv)
- [simulation](../../playbooks/simulation.md)
