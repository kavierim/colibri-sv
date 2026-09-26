---
type: Module
title: cc_ram_fifo
description: Dual-clock RAM-based FIFO with asymmetric ports.
tags: [domain:memory, module:cc_ram_fifo, cdc]
status: draft
resource: src/memory/cc_ram_fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Dual-clock RAM-based FIFO with asymmetric ports.

# When to use

Use [`cc_fifo`](cc_fifo.md) when a logic FIFO is sufficient or widths match.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_NUM_WORDS    = 4` |
| `parameter int g_INPUT_WIDTH  = 8` |
| `parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH` |
| `parameter bit g_ENABLE_FWFT  = 1'b0` |
| `parameter int g_INPUT_USEDW_WIDTH = colibri_utils::log2ceil(` |
| `parameter int g_OUTPUT_USEDW_WIDTH = colibri_utils::log2ceil(` |
| `parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()` |


## Ports

| Declaration |
| --- |
| `input  logic reset_i` |
| `input  logic wrclk_i` |
| `input  logic [g_INPUT_WIDTH-1:0] data_i` |
| `input  logic wrreq_i` |
| `output logic [colibri_utils::downto_width(g_INPUT_USEDW_WIDTH)-1:0] wrusedw_o` |
| `output logic wrempty_o` |
| `output logic wrfull_o` |
| `input  logic rdclk_i` |
| `input  logic rdreq_i` |
| `output logic [g_OUTPUT_WIDTH-1:0] q_o` |
| `output logic [colibri_utils::downto_width(g_OUTPUT_USEDW_WIDTH)-1:0] rdusedw_o` |
| `output logic rdempty_o` |
| `output logic rdfull_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Dual-clock FIFO built around simple_dpram. g_NUM_WORDS and g_INPUT_WIDTH have elaboration defaults; the VHDL generics do not. Reset and pointer crossing use synchro_reset and synchro (src/common). FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/cc_ram_fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `cc_ram_fifo`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

cc_ram_fifo #(
  // parameters from Schema
) u_cc_ram_fifo (
  .reset_i (...),
  .wrclk_i (...),
  .data_i (...),
  .wrreq_i (...),
  .wrusedw_o (...),
  .wrempty_o (...),
  .wrfull_o (...),
  .rdclk_i (...),
  .rdreq_i (...),
  .q_o (...),
  .rdusedw_o (...),
  .rdempty_o (...),
  .rdfull_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/cc_ram_fifo_tb.sv | none |

# Agent notes

- Read `src/memory/cc_ram_fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/cc_ram_fifo_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/cc_ram_fifo.sv)
- [simulation](../../playbooks/simulation.md)
