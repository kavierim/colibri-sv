---
type: Module
title: avst_ram_write
description: Write Avalon-ST beats into RAM.
tags: [domain:interfaces, module:avst_ram_write, interface:avst]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/interfaces/stream/avst_ram_write.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Write Avalon-ST beats into RAM.

RTL notes: Simple Avalon Stream to RAM writer. Sequential writes of a packeted Avalon-ST input. start_addr_i is sampled at start of packet. A later start of packet restarts from the new address. The write stops on end of packet.

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_DATA_WIDTH = 8` |
| | `parameter int unsigned g_ADDR_WIDTH = 8` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                      clk_i` |
| | `input  logic                      reset_i` |
| | `input  logic [g_ADDR_WIDTH-1:0]   start_addr_i` |
| | `input  logic                      snk_sop_i` |
| | `input  logic                      snk_eop_i` |
| | `input  logic [g_DATA_WIDTH-1:0]   snk_data_i` |
| | `input  logic                      snk_valid_i` |
| | `output logic                      wr_en_o` |
| | `output logic [g_ADDR_WIDTH-1:0]   wr_addr_o` |
| | `output logic [g_DATA_WIDTH-1:0]   wr_data_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Simple Avalon Stream to RAM writer. Sequential writes of a packeted Avalon-ST input. start_addr_i is sampled at start of packet. A later start of packet restarts from the new address. The write stops on end of packet. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_ram_write.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_ram_write`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_ram_write #(
  // parameters from Schema
) u_avst_ram_write (
  .clk_i (...),
  .reset_i (...),
  .start_addr_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .wr_en_o (...),
  .wr_addr_o (...),
  .wr_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv | fv/interfaces/stream/avst_ram_write_sva.sv |

# Agent notes

- Read `src/interfaces/stream/avst_ram_write.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_ram_write.sv)
- [simulation](../../playbooks/simulation.md)
