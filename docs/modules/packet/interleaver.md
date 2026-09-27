---
type: Module
title: interleaver
description: Merge multiple packet streams into one.
tags: [domain:packet, module:interleaver]
status: draft
resource: src/packet/interleaver.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Packet::interleaver
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-INTERLEAVER-001
    statement: While reset_i is low, snk_ready_o shall be zero or one-hot.
  - id: REQ-INTERLEAVER-002
    statement: When the selected input is idle and a beat is output, src_sop_o shall be high.
  - id: REQ-INTERLEAVER-003
    statement: When the selected input is in a multi-beat packet, src_sop_o shall be low on output beats.
  - id: REQ-INTERLEAVER-004
    statement: A single-beat packet on the output shall mark the corresponding input state as single.
  - id: REQ-INTERLEAVER-005
    statement: During a multi-beat packet on an input, src_channel_o shall not change while that input is active.
---
# Purpose

Merge multiple packet streams into one.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_NUM_INPUTS       = 3` |
| `parameter int unsigned g_DATA_WIDTH       = 32` |
| `parameter bit          g_INTERLEAVE_WORDS = 1'b1` |

## Ports

| Declaration |
| --- |
| `input  logic                         clk_i` |
| `input  logic                         reset_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_sop_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_eop_i` |
| `input  logic [g_NUM_INPUTS-1:0]      snk_valid_i` |
| `output logic [g_NUM_INPUTS-1:0]      snk_ready_o` |
| `input  logic [g_NUM_INPUTS*c_DATA_W-1:0]  snk_data_i` |
| `input  logic [g_NUM_INPUTS*c_EMPTY_W-1:0] snk_empty_i` |
| `output logic                         src_sop_o` |
| `output logic                         src_eop_o` |
| `output logic                         src_valid_o` |
| `input  logic                         src_ready_i` |
| `output logic [c_DATA_W-1:0]          src_data_o` |
| `output logic [c_EMPTY_W-1:0]         src_empty_o` |
| `output logic [c_CH_W-1:0]            src_channel_o` |

Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.

# Behaviour

Interleaves Avalon-ST streams into one stream and tags the source with src_channel_o. Packets already in flight win; otherwise the grant rotates. g_INTERLEAVE_WORDS selects word interleaving or whole-packet boundaries. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-INTERLEAVER-001"></a>

## REQ-INTERLEAVER-001

- Kind: extracted
- Verified by: `fv/packet/interleaver_sva.sv` property `a_only_one_src_active`

<a id="REQ-INTERLEAVER-002"></a>

## REQ-INTERLEAVER-002

- Kind: extracted
- Verified by: `fv/packet/interleaver_sva.sv` property `a_valid_out_sop`

<a id="REQ-INTERLEAVER-003"></a>

## REQ-INTERLEAVER-003

- Kind: extracted
- Verified by: `fv/packet/interleaver_sva.sv` property `a_valid_out_multi`

<a id="REQ-INTERLEAVER-004"></a>

## REQ-INTERLEAVER-004

- Kind: extracted
- Verified by: `fv/packet/interleaver_sva.sv` property `a_valid_out_single`

<a id="REQ-INTERLEAVER-005"></a>

## REQ-INTERLEAVER-005

- Kind: extracted
- Verified by: `fv/packet/interleaver_bd_sva.sv` property `a_pkt_boundaries`
# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/interleaver.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `interleaver`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

interleaver #(
  // parameters from Schema
) u_interleaver (
  .clk_i (...),
  .reset_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_channel_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/interleaver_tb.sv | fv/packet/interleaver_sva.sv, interleaver_bd_sva.sv |

# Agent notes

- Read `src/packet/interleaver.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/interleaver_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/interleaver.sv)
- [simulation](../../playbooks/simulation.md)
