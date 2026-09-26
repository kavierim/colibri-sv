---
type: Module
title: avst_ram_read_unaligned
description: Byte-addressable Avalon-ST RAM reader.
tags: [domain:interfaces, module:avst_ram_read_unaligned, interface:avst]
status: draft
resource: src/interfaces/stream/avst_ram_read_unaligned.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Byte-addressable Avalon-ST RAM reader.

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_BYTE_WIDTH = 8` |
| `parameter int unsigned g_WORD_BYTES = 8` |
| `parameter int unsigned g_RAM_DEPTH  = 16` |


## Ports

| Declaration |
| --- |
| `input  logic                       clk_i` |
| `input  logic                       reset_i` |
| `output logic [c_DATA_W-1:0]        src_data_o` |
| `output logic [c_EMPTY_W-1:0]       src_empty_o` |
| `output logic                       src_sop_o` |
| `output logic                       src_eop_o` |
| `output logic                       src_valid_o` |
| `input  logic                       src_ready_i` |
| `input  logic [c_BYTE_ADDR_W-1:0]   start_addr_i` |
| `input  logic [c_LEN_W-1:0]         length_i` |
| `input  logic                       start_i` |
| `output logic                       busy_o` |
| `output logic                       rd_en_o` |
| `output logic [c_ADDR_W-1:0]        rd_addr_o` |
| `input  logic [c_DATA_W-1:0]        rd_data_i` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Avalon Stream from RAM reader with unaligned (byte-addressable) access. start_i begins a read while the component is idle. start_addr_i is a byte address and length_i is a byte count. The last beat may be partially empty; empty bytes sit at the LSB. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_ram_read_unaligned.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_ram_read_unaligned`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_ram_read_unaligned #(
  // parameters from Schema
) u_avst_ram_read_unaligned (
  .clk_i (...),
  .reset_i (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .start_addr_i (...),
  .length_i (...),
  .start_i (...),
  .busy_o (...),
  .rd_en_o (...),
  .rd_addr_o (...),
  .rd_data_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_ram_read_unaligned_tb/, avst_ram_be_tb/ | none |

# Agent notes

- Read `src/interfaces/stream/avst_ram_read_unaligned.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_ram_read_unaligned_tb/, avst_ram_be_tb/` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_ram_read_unaligned.sv)
- [simulation](../../playbooks/simulation.md)
