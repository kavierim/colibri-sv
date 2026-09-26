---
type: Module
title: ram
description: Single-port, single-clock RAM.
tags: [domain:memory, module:ram]
status: draft
resource: src/memory/ram.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Single-port, single-clock RAM.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_N_WORDS      = 16` |
| `parameter int g_DATA_WIDTH   = 8` |
| `parameter bit g_REGISTER_IN  = 1'b0` |
| `parameter bit g_REGISTER_OUT = 1'b1` |
| `parameter string g_INIT_FILE = ""` |
| `parameter logic [g_DATA_WIDTH-1:0] g_INIT_WORD = '0` |
| `parameter bit g_WRITE_FIRST  = 1'b1` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_i` |
| `input  logic we_i` |
| `input  logic [g_DATA_WIDTH-1:0] data_i` |
| `output logic [g_DATA_WIDTH-1:0] q_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Single-port RAM. Hex init file, one word per line. g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/ram.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `ram`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

ram #(
  // parameters from Schema
) u_ram (
  .clk_i (...),
  .reset_i (...),
  .addr_i (...),
  .we_i (...),
  .data_i (...),
  .q_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/ram_tb.sv | none |

# Agent notes

- Read `src/memory/ram.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/ram_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/ram.sv)
- [simulation](../../playbooks/simulation.md)
