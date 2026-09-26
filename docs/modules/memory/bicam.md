---
type: Module
title: bicam
description: Binary content-addressable memory.
tags: [domain:memory, module:bicam]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/memory/bicam.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Binary content-addressable memory.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_N_WORDS    = 16` |
| `parameter int g_DATA_WIDTH = 8` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic rdreq_i` |
| `input  logic wrreq_i` |
| `input  logic clear_i` |
| `input  logic [g_DATA_WIDTH-1:0] data_i` |
| `output logic full_o` |
| `output logic busy_o` |
| `output logic match_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Binary content-addressable memory. g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/bicam.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `bicam`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

bicam #(
  // parameters from Schema
) u_bicam (
  .clk_i (...),
  .reset_i (...),
  .rdreq_i (...),
  .wrreq_i (...),
  .clear_i (...),
  .data_i (...),
  .full_o (...),
  .busy_o (...),
  .match_o (...),
  .addr_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/bicam_tb.sv | none |

# Agent notes

- Read `src/memory/bicam.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/bicam_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/bicam.sv)
- [simulation](../../playbooks/simulation.md)
