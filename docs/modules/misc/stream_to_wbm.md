---
type: Module
title: stream_to_wbm
description: Bidirectional stream to Wishbone B4 master.
tags: [domain:misc, module:stream_to_wbm, interface:avst]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/misc/stream_to_wbm.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Bidirectional stream to Wishbone B4 master.

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_WB_ADDR_WIDTH = 32` |
| `parameter int unsigned g_WB_DATA_WIDTH = 32` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] snk_data_i` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `output logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] src_data_o` |
| `output logic src_valid_o` |
| `output logic [g_WB_ADDR_WIDTH-1:0] wb_adr_o` |
| `input  logic [g_WB_DATA_WIDTH-1:0] wb_dat_i` |
| `output logic [g_WB_DATA_WIDTH-1:0] wb_dat_o` |
| `output logic wb_we_o` |
| `output logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_o` |
| `output logic wb_stb_o` |
| `output logic wb_cyc_o` |
| `input  logic wb_ack_i` |
| `input  logic wb_err_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Stream to Wishbone Master Memory Mapped Interface. Converts a full duplex stream into a Wishbone.B4 master. 0x01 sets the address, 0x02 is a read, 0x03 is a write, 0x00 is NOP. Replies use the last command plus 0x10 in the high nibble. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/stream_to_wbm.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `stream_to_wbm`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

stream_to_wbm #(
  // parameters from Schema
) u_stream_to_wbm (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_valid_o (...),
  .wb_adr_o (...),
  .wb_dat_i (...),
  .wb_dat_o (...),
  .wb_we_o (...),
  .wb_sel_o (...),
  .wb_stb_o (...),
  .wb_cyc_o (...),
  .wb_ack_i (...),
  .wb_err_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/stream_to_wbm_tb.sv | none |

# Agent notes

- Read `src/misc/stream_to_wbm.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/stream_to_wbm_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/stream_to_wbm.sv)
- [simulation](../../playbooks/simulation.md)
