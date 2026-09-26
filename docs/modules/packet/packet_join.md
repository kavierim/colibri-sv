---
type: Module
title: packet_join
description: Concatenate consecutive packets into one.
tags: [domain:packet, module:packet_join]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/packet/packet_join.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Concatenate consecutive packets into one.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_SYM_WIDTH = 8` |
| `parameter int unsigned g_DATA_SYM  = 4` |


## Ports

| Declaration |
| --- |
| `input  logic                   clk_i` |
| `input  logic                   reset_i` |
| `input  logic                   last_i` |
| `input  logic [c_DATA_W-1:0]    snk_data_i` |
| `input  logic [c_EMPTY_W-1:0]   snk_empty_i` |
| `input  logic                   snk_sop_i` |
| `input  logic                   snk_eop_i` |
| `input  logic                   snk_valid_i` |
| `output logic                   snk_ready_o` |
| `output logic [c_DATA_W-1:0]    src_data_o` |
| `output logic [c_EMPTY_W-1:0]   src_empty_o` |
| `output logic                   src_sop_o` |
| `output logic                   src_eop_o` |
| `output logic                   src_valid_o` |
| `input  logic                   src_ready_i` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Joins consecutive Avalon-ST packets into one. Empty symbols at an input end of packet are removed so the next packet follows directly. Library lint elaborates every module; wave0_elab is the other top. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/packet_join.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `packet_join`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

packet_join #(
  // parameters from Schema
) u_packet_join (
  .clk_i (...),
  .reset_i (...),
  .last_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/packet_join_tb.sv | fv/packet/packet_join_sva.sv |

# Agent notes

- Read `src/packet/packet_join.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/packet_join_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/packet_join.sv)
- [simulation](../../playbooks/simulation.md)
