---
type: Module
title: wb_ram
description: RAM with Wishbone B4 slave port.
tags: [domain:interfaces, module:wb_ram]
status: draft
resource: src/interfaces/memory_mapped/wb_ram.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

RAM with Wishbone B4 slave port.

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_N_WORDS       = 16` |
| `parameter int unsigned g_WB_DATA_WIDTH = 32` |
| `parameter int unsigned g_WB_ADDR_WIDTH = 32` |


## Ports

| Declaration |
| --- |
| `input  logic                         clk_i` |
| `input  logic                         reset_i` |
| `input  logic [g_WB_ADDR_WIDTH-1:0]   wb_adr_i` |
| `input  logic [g_WB_DATA_WIDTH-1:0]   wb_dat_i` |
| `output logic [g_WB_DATA_WIDTH-1:0]   wb_dat_o` |
| `input  logic                         wb_we_i` |
| `input  logic [c_SEL_W-1:0]           wb_sel_i` |
| `input  logic                         wb_stb_i` |
| `input  logic                         wb_cyc_i` |
| `output logic                         wb_ack_o` |
| `output logic                         wb_err_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Wishbone RAM interface. Release log: - 0.1 first release Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/memory_mapped/wb_ram.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `wb_ram`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

wb_ram #(
  // parameters from Schema
) u_wb_ram (
  .clk_i (...),
  .reset_i (...),
  .wb_adr_i (...),
  .wb_dat_i (...),
  .wb_dat_o (...),
  .wb_we_i (...),
  .wb_sel_i (...),
  .wb_stb_i (...),
  .wb_cyc_i (...),
  .wb_ack_o (...),
  .wb_err_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/memory_mapped/wb_ram_tb.sv | none |

# Agent notes

- Read `src/interfaces/memory_mapped/wb_ram.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/memory_mapped/wb_ram_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/memory_mapped/wb_ram.sv)
- [simulation](../../playbooks/simulation.md)
