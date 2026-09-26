---
type: Module
title: simple_dpram_altera
description: Vendor-style simple DPRAM for Intel/Altera inference.
tags: [domain:memory, module:simple_dpram_altera]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/memory/optimized/simple_dpram_altera.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Vendor-style simple DPRAM for Intel/Altera inference.

# When to use

Force Intel/Altera BRAM inference; otherwise use `simple_dpram`.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_DATA_WIDTH   = 16` |
| `parameter int g_A_DATA_WIDTH = g_DATA_WIDTH` |
| `parameter int g_B_DATA_WIDTH = g_A_DATA_WIDTH` |
| `parameter int g_N_WORDS      = 10` |
| `parameter int g_A_ADDR_WIDTH = colibri_utils::log2ceil(` |
| `parameter int g_B_ADDR_WIDTH = colibri_utils::log2ceil(` |
| `parameter bit g_REGISTER_OUT = 1'b0` |
| `parameter string g_INIT_FILE = ""` |
| `parameter logic [g_A_DATA_WIDTH-1:0] g_INIT_WORD = '0` |


## Ports

| Declaration |
| --- |
| `input  logic wrclk_i` |
| `input  logic wren_i` |
| `input  logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] wraddr_i` |
| `input  logic [g_A_DATA_WIDTH-1:0] wrdata_i` |
| `input  logic rdclk_i` |
| `input  logic rden_i` |
| `input  logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] rdaddr_i` |
| `output logic [g_B_DATA_WIDTH-1:0] rddata_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Altera-style simple dual-port RAM. Behavioural description for BRAM inference. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/optimized/simple_dpram_altera.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `simple_dpram_altera`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

simple_dpram_altera #(
  // parameters from Schema
) u_simple_dpram_altera (
  .wrclk_i (...),
  .wren_i (...),
  .wraddr_i (...),
  .wrdata_i (...),
  .rdclk_i (...),
  .rden_i (...),
  .rdaddr_i (...),
  .rddata_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/memory/optimized/simple_dpram_altera.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/optimized/simple_dpram_altera.sv)
- [simulation](../../playbooks/simulation.md)
