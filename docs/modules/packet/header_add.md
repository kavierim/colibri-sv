---
type: Module
title: header_add
description: Prepend a fixed header to each packet.
tags: [domain:packet, module:header_add]
status: draft
resource: src/packet/header_add.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Prepend a fixed header to each packet.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_HEADER_BYTES = 14` |
| `parameter int unsigned g_DATA_WIDTH   = 32` |


## Ports

| Declaration |
| --- |
| `input  logic                    clk_i` |
| `input  logic                    reset_i` |
| `input  logic                    snk_sop_i` |
| `input  logic                    snk_eop_i` |
| `input  logic                    snk_valid_i` |
| `output logic                    snk_ready_o` |
| `input  logic [c_DATA_W-1:0]     snk_data_i` |
| `input  logic [c_EMPTY_W-1:0]    snk_empty_i` |
| `input  logic [c_HDR_BITS-1:0]   snk_header_i` |
| `output logic                    src_sop_o` |
| `output logic                    src_eop_o` |
| `output logic                    src_valid_o` |
| `input  logic                    src_ready_i` |
| `output logic [c_DATA_W-1:0]     src_data_o` |
| `output logic [c_EMPTY_W-1:0]    src_empty_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Inserts snk_header_i, sampled at the input start of packet, in front of an Avalon-ST packet. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/header_add.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `header_add`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

header_add #(
  // parameters from Schema
) u_header_add (
  .clk_i (...),
  .reset_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_header_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_data_o (...),
  .src_empty_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/header_add_tb.sv | fv/packet/header_add_sva.sv |

# Agent notes

- Read `src/packet/header_add.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/header_add_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/header_add.sv)
- [simulation](../../playbooks/simulation.md)
