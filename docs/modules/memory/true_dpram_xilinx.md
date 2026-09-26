---
type: Module
title: true_dpram_xilinx
description: Vendor-style true DPRAM for Xilinx.
tags: [domain:memory, module:true_dpram_xilinx]
status: draft
resource: src/memory/optimized/true_dpram_xilinx.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Vendor-style true DPRAM for Xilinx.

# When to use

Vendor Xilinx variant of [`true_dpram`](true_dpram.md).

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
| `parameter bit g_WRITE_FIRST  = 1'b1` |
| `parameter bit g_REGISTER_OUT = 1'b0` |
| `parameter string g_INIT_FILE = ""` |
| `parameter logic [g_DATA_WIDTH-1:0] g_INIT_WORD = '0` |


## Ports

| Declaration |
| --- |
| `input  logic clka_i` |
| `input  logic wra_i` |
| `input  logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] addra_i` |
| `input  logic [g_A_DATA_WIDTH-1:0] dataa_i` |
| `output logic [g_A_DATA_WIDTH-1:0] dataa_o` |
| `input  logic clkb_i` |
| `input  logic wrb_i` |
| `input  logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] addrb_i` |
| `input  logic [g_B_DATA_WIDTH-1:0] datab_i` |
| `output logic [g_B_DATA_WIDTH-1:0] datab_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Xilinx-style true dual-port RAM. Behavioural description for BRAM inference. The VHDL shared variable is a logic array. Both ports update it in always_ff. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/optimized/true_dpram_xilinx.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `true_dpram_xilinx`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

true_dpram_xilinx #(
  // parameters from Schema
) u_true_dpram_xilinx (
  .clka_i (...),
  .wra_i (...),
  .addra_i (...),
  .dataa_i (...),
  .dataa_o (...),
  .clkb_i (...),
  .wrb_i (...),
  .addrb_i (...),
  .datab_i (...),
  .datab_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/memory/optimized/true_dpram_xilinx.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/optimized/true_dpram_xilinx.sv)
- [simulation](../../playbooks/simulation.md)
