---
type: Module
title: avst_width_converter
description: Avalon-ST data-width converter.
tags: [domain:interfaces, module:avst_width_converter, interface:avst]
status: stable
resource: src/interfaces/stream/avst_width_converter.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Avalon-ST data-width converter.

# When to use

Between AVST blocks with different beat widths; keep `g_SYM_WIDTH` consistent. Needs packet `sop`/`eop`/`empty` preserved.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_SYM_WIDTH  = 8` |
| `parameter int unsigned g_INPUT_SYM  = 16` |
| `parameter int unsigned g_OUTPUT_SYM = 1` |


## Ports

| Declaration |
| --- |
| `input  logic                       clk_i` |
| `input  logic                       reset_i` |
| `output logic                       snk_ready_o` |
| `input  logic                       snk_valid_i` |
| `input  logic                       snk_sop_i` |
| `input  logic                       snk_eop_i` |
| `input  logic [c_SNK_EMPTY_W-1:0]   snk_empty_i` |
| `input  logic [c_INPUT_WIDTH-1:0]   snk_data_i` |
| `input  logic                       src_ready_i` |
| `output logic                       src_valid_o` |
| `output logic                       src_sop_o` |
| `output logic                       src_eop_o` |
| `output logic [c_SRC_EMPTY_W-1:0]   src_empty_o` |
| `output logic [c_OUTPUT_WIDTH-1:0]  src_data_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Avalon-ST width converter. Converts the data width of an Avalon stream, including packet delimiters (start and end of packet) and empty symbols. Symbol width is unchanged. Buffers and serialises beats when `g_INPUT_SYM` and `g_OUTPUT_SYM` differ. `snk_*` is the wide side, `src_*` the narrow side (or vice versa per parameterisation). Preserves packet boundaries via `sop`/`eop` and `empty`.

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_width_converter.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_width_converter`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_width_converter #(
  // parameters from Schema
) u_avst_width_converter (
  .clk_i (...),
  .reset_i (...),
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
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_width_converter_tb.sv | none |

# Agent notes

- Read `src/interfaces/stream/avst_width_converter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_width_converter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_width_converter.sv)
- [simulation](../../playbooks/simulation.md)
