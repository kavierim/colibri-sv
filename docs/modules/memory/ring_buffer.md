---
type: Module
title: ring_buffer
description: Circular buffer; overwrite oldest when full.
tags: [domain:memory, module:ring_buffer]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/memory/ring_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Circular buffer; overwrite oldest when full.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_NUM_WORDS  = 4` |
| `parameter int g_DATA_WIDTH = 8` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic snk_valid_i` |
| `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| `output logic src_valid_o` |
| `input  logic src_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

RAM-based ring buffer. A write while full overwrites the oldest word. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/ring_buffer.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `ring_buffer`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

ring_buffer #(
  // parameters from Schema
) u_ring_buffer (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .src_data_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/ring_buffer_tb.sv | fv/memory/ring_buffer_sva.sv |

# Agent notes

- Read `src/memory/ring_buffer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/ring_buffer_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/ring_buffer.sv)
- [simulation](../../playbooks/simulation.md)
