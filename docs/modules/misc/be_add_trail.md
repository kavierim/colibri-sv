---
type: Module
title: be_add_trail
description: Append a trailing word (e.g. CRC).
tags: [domain:misc, module:be_add_trail]
status: draft
resource: src/misc/be_add_trail.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Misc::be_add_trail
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-BE_ADD_TRAIL-001
    statement: When the output packet state is idle and a beat is presented, src_sop_o shall be high.
  - id: REQ-BE_ADD_TRAIL-002
    statement: When the output packet state is multi-beat, src_sop_o shall be low on presented beats.
  - id: REQ-BE_ADD_TRAIL-003
    statement: On the last beat of a packet, src_empty_o shall indicate fewer than a full word of valid bytes.
---
# Purpose

Append a trailing word (e.g. CRC).

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH = 32` |

## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8):0] shl_i` |
| `output logic snk_ready_o` |
| `input  logic snk_valid_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] snk_empty_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_trail_i` |
| `input  logic src_ready_i` |
| `output logic src_valid_o` |
| `output logic src_sop_o` |
| `output logic src_eop_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] src_empty_o` |
| `output logic [g_DATA_WIDTH-1:0] src_data_o` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Big-endian add-trailing-word module. Adds `snk_trail_i` at the end of an Avalon-ST packet. `snk_trail_i` and `shl_i` are sampled at `snk_eop_i`. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-BE_ADD_TRAIL-001"></a>

## REQ-BE_ADD_TRAIL-001

- Kind: extracted
- Verified by: `fv/misc/be_add_trail_sva.sv` property `a_valid_out_sop`

<a id="REQ-BE_ADD_TRAIL-002"></a>

## REQ-BE_ADD_TRAIL-002

- Kind: extracted
- Verified by: `fv/misc/be_add_trail_sva.sv` property `a_valid_out_multi`

<a id="REQ-BE_ADD_TRAIL-003"></a>

## REQ-BE_ADD_TRAIL-003

- Kind: extracted
- Verified by: `fv/misc/be_add_trail_sva.sv` property `a_empty_out`
# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/be_add_trail.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `be_add_trail`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

be_add_trail #(
  // parameters from Schema
) u_be_add_trail (
  .clk_i (...),
  .reset_i (...),
  .shl_i (...),
  .snk_ready_o (...),
  .snk_valid_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_empty_i (...),
  .snk_data_i (...),
  .snk_trail_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/be_add_trail_tb.sv | fv/misc/be_add_trail_sva.sv |

# Agent notes

- Read `src/misc/be_add_trail.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/be_add_trail_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/be_add_trail.sv)
- [simulation](../../playbooks/simulation.md)
