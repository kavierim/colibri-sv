---
type: Module
title: rom
description: Read-only memory loaded from a hex init file.
tags: [domain:memory, module:rom]
status: draft
resource: src/memory/rom.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Read-only memory loaded from a hex init file.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_N_WORDS    = 16` |
| `parameter int g_DATA_WIDTH = 8` |
| `parameter string g_INIT_FILE = ""` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_i` |
| `output logic [g_DATA_WIDTH-1:0] data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Read-only memory. Contents come from a hex file, one word per line. g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/rom.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `rom`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

rom #(
  // parameters from Schema
) u_rom (
  .clk_i (...),
  .addr_i (...),
  .data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/rom/rom_tb.sv | none |

# Agent notes

- Read `src/memory/rom.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/rom/rom_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/rom.sv)
- [simulation](../../playbooks/simulation.md)
