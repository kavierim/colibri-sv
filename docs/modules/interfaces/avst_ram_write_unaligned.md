---
type: Module
title: avst_ram_write_unaligned
description: Byte-addressable Avalon-ST RAM writer.
tags: [domain:interfaces, module:avst_ram_write_unaligned, interface:avst]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/interfaces/stream/avst_ram_write_unaligned.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Byte-addressable Avalon-ST RAM writer.

RTL notes: Avalon Stream to RAM writer with unaligned (byte-addressable) access. Writes Avalon-ST packets to a word-addressed RAM with a byte-enable vector. start_addr_i is the initial byte address at start of packet. An extra write after end of packet can deassert snk_ready_o for one cycle. RAM outputs are delayed by 2 cycles. flush_i writes any bytes still in the buffer.

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_BYTE_WIDTH = 8` |
| | `parameter int unsigned g_WORD_BYTES = 8` |
| | `parameter int unsigned g_RAM_DEPTH  = 16` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                       clk_i` |
| | `input  logic                       reset_i` |
| | `input  logic [c_DATA_W-1:0]        snk_data_i` |
| | `input  logic [c_EMPTY_W-1:0]       snk_empty_i` |
| | `input  logic                       snk_sop_i` |
| | `input  logic                       snk_eop_i` |
| | `input  logic                       snk_valid_i` |
| | `output logic                       snk_ready_o` |
| | `input  logic [c_BYTE_ADDR_W-1:0]   start_addr_i` |
| | `input  logic                       flush_i` |
| | `output logic [g_WORD_BYTES-1:0]    wr_be_o` |
| | `output logic [c_ADDR_W-1:0]        wr_addr_o` |
| | `output logic [c_DATA_W-1:0]        wr_data_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Avalon Stream to RAM writer with unaligned (byte-addressable) access. Writes Avalon-ST packets to a word-addressed RAM with a byte-enable vector. start_addr_i is the initial byte address at start of packet. An extra write after end of packet can deassert snk_ready_o for one cycle. RAM outputs are delayed by 2 cycles. flush_i writes any bytes still in the buffer. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_ram_write_unaligned.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_ram_write_unaligned`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_ram_write_unaligned #(
  // parameters from Schema
) u_avst_ram_write_unaligned (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .start_addr_i (...),
  .flush_i (...),
  .wr_be_o (...),
  .wr_addr_o (...),
  .wr_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_ram_write_unaligned_tb.sv, avst_ram_be_tb/ | fv/interfaces/stream/avst_ram_write_unaligned_sva.sv |

# Agent notes

- Read `src/interfaces/stream/avst_ram_write_unaligned.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_ram_write_unaligned_tb.sv, avst_ram_be_tb/` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_ram_write_unaligned.sv)
- [simulation](../../playbooks/simulation.md)
