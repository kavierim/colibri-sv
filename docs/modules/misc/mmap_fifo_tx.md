---
type: Module
title: mmap_fifo_tx
description: TX half of `mmap_fifo`.
tags: [domain:misc, module:mmap_fifo_tx]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/misc/mmap_fifo/mmap_fifo_tx.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

TX half of `mmap_fifo`.

RTL notes: Memory Mapped FIFO to Stream. Write a destination id, write data, then write the packet size in bytes.

# When to use

Full bridge: [`mmap_fifo`](mmap_fifo.md).

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_WB_ADDR_WIDTH = 32` |
| | `parameter int unsigned g_WB_DATA_WIDTH = 32` |
| | `parameter int unsigned g_STREAM_DATA_WIDTH = g_WB_DATA_WIDTH` |
| | `parameter int unsigned g_NUM_WORDS = 16` |
| | `parameter int unsigned g_NUM_CH = 4` |
| | `parameter bit g_USE_BLOCK_RAM = 1'b0` |
| | `parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic reset_i` |
| | `input  logic clk_i` |
| | `input  logic src_ready_i` |
| | `output logic src_valid_o` |
| | `output logic src_sop_o` |
| | `output logic src_eop_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] src_empty_o` |
| | `output logic [g_STREAM_DATA_WIDTH-1:0] src_data_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] src_chan_o` |
| | `input  logic wb_clk_i` |
| | `input  logic [g_WB_ADDR_WIDTH-1:0] wb_adr_i` |
| | `output logic [g_WB_DATA_WIDTH-1:0] wb_dat_o` |
| | `input  logic [g_WB_DATA_WIDTH-1:0] wb_dat_i` |
| | `input  logic wb_we_i` |
| | `input  logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_i` |
| | `input  logic wb_stb_i` |
| | `input  logic wb_cyc_i` |
| | `output logic wb_ack_o` |
| | `output logic wb_err_o` |
| | `output logic intr_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Memory Mapped FIFO to Stream. Write a destination id, write data, then write the packet size in bytes. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/mmap_fifo/mmap_fifo_tx.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `mmap_fifo_tx`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

mmap_fifo_tx #(
  // parameters from Schema
) u_mmap_fifo_tx (
  .reset_i (...),
  .clk_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_data_o (...),
  .src_chan_o (...),
  .wb_clk_i (...),
  .wb_adr_i (...),
  .wb_dat_o (...),
  .wb_dat_i (...),
  .wb_we_i (...),
  .wb_sel_i (...),
  .wb_stb_i (...),
  // ...
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/mmap_fifo/mmap_fifo_tb.sv | none |

# Agent notes

- Read `src/misc/mmap_fifo/mmap_fifo_tx.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/mmap_fifo/mmap_fifo_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/mmap_fifo/mmap_fifo_tx.sv)
- [simulation](../../playbooks/simulation.md)
