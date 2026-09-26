---
type: Module
title: simple_dpram_be
description: `simple_dpram` with byte-enable on the write port.
tags: [domain:memory, module:simple_dpram_be]
status: draft
resource: src/memory/simple_dpram_be.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

`simple_dpram` with byte-enable on the write port.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_BYTE_WIDTH = 8` |
| `parameter int g_WORD_BYTES = 4` |
| `parameter int g_N_WORDS    = 16` |
| `parameter string g_INIT_FILE = ""` |
| `parameter logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] g_INIT_WORD = '0` |


## Ports

| Declaration |
| --- |
| `input  logic wrclk_i` |
| `input  logic [g_WORD_BYTES-1:0] wren_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] wraddr_i` |
| `input  logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] wrdata_i` |
| `input  logic rdclk_i` |
| `input  logic rden_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] rdaddr_i` |
| `output logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] rddata_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Simple dual-port RAM with a write byte-enable. g_WORD_BYTES and g_N_WORDS have elaboration defaults; the VHDL generics do not. The memory file list elaborates every uninstantiated module together with wave0_elab. Verilator -Wall treats that as MULTITOP. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/simple_dpram_be.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `simple_dpram_be`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

simple_dpram_be #(
  // parameters from Schema
) u_simple_dpram_be (
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
| yes | sim/memory/simple_dpram_be_tb.sv | none |

# Agent notes

- Read `src/memory/simple_dpram_be.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/simple_dpram_be_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/simple_dpram_be.sv)
- [simulation](../../playbooks/simulation.md)
