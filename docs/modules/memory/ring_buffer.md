---
type: Module
title: ring_buffer
description: Circular buffer; overwrite oldest when full.
tags: [domain:memory, module:ring_buffer]
status: draft
resource: src/memory/ring_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Memory::ring_buffer
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
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

# Requirements

<a id="REQ-RING_BUFFER-001"></a>

## REQ-RING_BUFFER-001

The cycle after reset_i, src_valid_o shall be low and usedw shall be zero.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_reset_state`

<a id="REQ-RING_BUFFER-002"></a>

## REQ-RING_BUFFER-002

While reset_i is low, usedw shall not exceed g_NUM_WORDS.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_count_max`

<a id="REQ-RING_BUFFER-003"></a>

## REQ-RING_BUFFER-003

A write while full with no read shall keep usedw at g_NUM_WORDS on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_overwrite_full`

<a id="REQ-RING_BUFFER-004"></a>

## REQ-RING_BUFFER-004

When usedw is zero, src_valid_o shall be low.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_empty_read`

<a id="REQ-RING_BUFFER-005"></a>

## REQ-RING_BUFFER-005

When src_valid_o is stalled and the buffer is not full, src_data_o and src_valid_o shall be stable on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_data_stable_norm`

<a id="REQ-RING_BUFFER-006"></a>

## REQ-RING_BUFFER-006

When snk_valid_i is accepted into non-full storage and src_valid_o is low, src_valid_o shall rise within one cycle.

- Kind: extracted
- Verified by: `fv/memory/ring_buffer_sva.sv` property `p_data_availability`

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
