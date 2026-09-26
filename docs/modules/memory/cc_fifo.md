---
type: Module
title: cc_fifo
description: Dual-clock asynchronous FIFO; arbitrary widths.
tags: [domain:memory, module:cc_fifo, cdc]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/memory/cc_fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Dual-clock asynchronous FIFO; arbitrary widths.

RTL notes: Dual-clock FIFO with optional mixed width, FWFT, and write-side peek. Reset and pointer crossing use synchro_reset and synchro (src/common). Mixed widths use gearbox (src/comms).

# When to use

For asymmetric widths at lower LUT cost, compare [`cc_ram_fifo`](cc_ram_fifo.md).

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_NUM_WORDS    = 4` |
| | `parameter int g_INPUT_WIDTH  = 8` |
| | `parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH` |
| | `parameter bit g_ENABLE_FWFT  = 1'b0` |
| | `parameter bit g_PEEK_NEXT    = 1'b0` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic reset_i` |
| | `input  logic wrclk_i` |
| | `input  logic rdclk_i` |
| | `input  logic [g_INPUT_WIDTH-1:0] data_i` |
| | `input  logic wrreq_i` |
| | `input  logic rdreq_i` |
| | `output logic [g_OUTPUT_WIDTH-1:0] q_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] wrusedw_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] rdusedw_o` |
| | `output logic wrempty_o` |
| | `output logic wrfull_o` |
| | `output logic rdempty_o` |
| | `output logic rdfull_o` |
| | `output logic [g_INPUT_WIDTH-1:0] wrq_o` |
| | `output logic wrq_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Dual-clock FIFO with optional mixed width, FWFT, and write-side peek. Reset and pointer crossing use synchro_reset and synchro (src/common). Mixed widths use gearbox (src/comms). FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/cc_fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `cc_fifo`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

cc_fifo #(
  // parameters from Schema
) u_cc_fifo (
  .reset_i (...),
  .wrclk_i (...),
  .rdclk_i (...),
  .data_i (...),
  .wrreq_i (...),
  .rdreq_i (...),
  .q_o (...),
  .wrusedw_o (...),
  .rdusedw_o (...),
  .wrempty_o (...),
  .wrfull_o (...),
  .rdempty_o (...),
  .rdfull_o (...),
  .wrq_o (...),
  .wrq_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/cc_fifo_tb.sv, mixedw_cc_fifo_tb.sv, mixedw_cc_fifo_fwft_tb.sv | none |

# Agent notes

- Read `src/memory/cc_fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/cc_fifo_tb.sv, mixedw_cc_fifo_tb.sv, mixedw_cc_fifo_fwft_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/cc_fifo.sv)
- [simulation](../../playbooks/simulation.md)
