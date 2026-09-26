---
type: Module
title: packet_fifo
description: Single-clock Avalon-ST packet FIFO.
tags: [domain:memory, module:packet_fifo]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/memory/packet_fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Single-clock Avalon-ST packet FIFO.

RTL notes: Single-clock packet FIFO on top of fifo.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_MAX_PACKET_BYTES  = 256` |
| | `parameter int g_NUM_PACKETS       = 4` |
| | `parameter int g_USEDP_BITS        = colibri_utils::log2ceil(g_NUM_PACKETS) + 1` |
| | `parameter bit g_ENABLE_SIZE_COUNT = 1'b1` |
| | `parameter int g_PKT_SIZE_BITS     = colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1` |
| | `parameter int g_DATA_WIDTH        = 8` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic clk_i` |
| | `input  logic reset_i` |
| | `output logic full_o` |
| | `output logic empty_o` |
| | `output logic [g_USEDP_BITS-1:0] usedp_o` |
| | `output logic snk_ready_o` |
| | `input  logic snk_valid_i` |
| | `input  logic snk_sop_i` |
| | `input  logic snk_eop_i` |
| | `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i` |
| | `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| | `input  logic src_ready_i` |
| | `output logic src_valid_o` |
| | `output logic src_sop_o` |
| | `output logic src_eop_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o` |
| | `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| | `output logic [g_PKT_SIZE_BITS-1:0] src_size_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Single-clock packet FIFO on top of fifo. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/packet_fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `packet_fifo`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

packet_fifo #(
  // parameters from Schema
) u_packet_fifo (
  .clk_i (...),
  .reset_i (...),
  .full_o (...),
  .empty_o (...),
  .usedp_o (...),
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
  // ...
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/packet_fifo/packet_fifo_tb.sv | none |

# Agent notes

- Read `src/memory/packet_fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/packet_fifo/packet_fifo_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/packet_fifo.sv)
- [simulation](../../playbooks/simulation.md)
