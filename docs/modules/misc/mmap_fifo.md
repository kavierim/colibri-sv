---
type: Module
title: mmap_fifo
description: Wishbone slave to full-duplex Avalon-ST packet FIFO.
tags: [domain:misc, module:mmap_fifo]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/misc/mmap_fifo/mmap_fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Wishbone slave to full-duplex Avalon-ST packet FIFO.

RTL notes: Memory Mapped Stream FIFO. Wishbone slave in front of full-duplex Avalon-ST packet streams.

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

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
| | `output logic snk_ready_o` |
| | `input  logic snk_valid_i` |
| | `input  logic snk_sop_i` |
| | `input  logic snk_eop_i` |
| | `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] snk_empty_i` |
| | `input  logic [g_STREAM_DATA_WIDTH-1:0] snk_data_i` |
| | `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] snk_chan_i` |
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
| | `output logic rx_intr_o` |
| | `output logic tx_intr_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Memory Mapped Stream FIFO. Wishbone slave in front of full-duplex Avalon-ST packet streams. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/mmap_fifo/mmap_fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `mmap_fifo`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

mmap_fifo #(
  // parameters from Schema
) u_mmap_fifo (
  .reset_i (...),
  .clk_i (...),
  .snk_ready_o (...),
  .snk_valid_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_empty_i (...),
  .snk_data_i (...),
  .snk_chan_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_data_o (...),
  .src_chan_o (...),
  // ...
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/mmap_fifo/mmap_fifo_tb.sv | none |

# Agent notes

- Read `src/misc/mmap_fifo/mmap_fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/mmap_fifo/mmap_fifo_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/mmap_fifo/mmap_fifo.sv)
- [simulation](../../playbooks/simulation.md)
