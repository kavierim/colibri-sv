---
type: Module
title: packet_join
description: Concatenate consecutive packets into one.
tags: [domain:packet, module:packet_join]
status: draft
resource: src/packet/packet_join.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Packet::packet_join
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-PACKET_JOIN-001
    statement: The cycle after reset_i, src_valid_o shall be low and snk_ready_o shall be low.
  - id: REQ-PACKET_JOIN-002
    statement: The cycle after reset_i falls, snk_ready_o shall be high.
  - id: REQ-PACKET_JOIN-003
    statement: When src_valid_o is stalled, output data and packet flags shall remain stable.
  - id: REQ-PACKET_JOIN-004
    statement: Non-zero src_empty_o shall only occur with src_eop_o.
  - id: REQ-PACKET_JOIN-005
    statement: When the join logic needs a start-of-packet, src_sop_o shall be high on valid output.
  - id: REQ-PACKET_JOIN-006
    statement: While waiting for the first output sop, a valid beat shall carry src_sop_o.
  - id: REQ-PACKET_JOIN-007
    statement: At an output end-of-packet with the expected input symbol count, out_cnt shall match the configured symbol total.
---
# Purpose

Concatenate consecutive packets into one.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_SYM_WIDTH = 8` |
| `parameter int unsigned g_DATA_SYM  = 4` |

## Ports

| Declaration |
| --- |
| `input  logic                   clk_i` |
| `input  logic                   reset_i` |
| `input  logic                   last_i` |
| `input  logic [c_DATA_W-1:0]    snk_data_i` |
| `input  logic [c_EMPTY_W-1:0]   snk_empty_i` |
| `input  logic                   snk_sop_i` |
| `input  logic                   snk_eop_i` |
| `input  logic                   snk_valid_i` |
| `output logic                   snk_ready_o` |
| `output logic [c_DATA_W-1:0]    src_data_o` |
| `output logic [c_EMPTY_W-1:0]   src_empty_o` |
| `output logic                   src_sop_o` |
| `output logic                   src_eop_o` |
| `output logic                   src_valid_o` |
| `input  logic                   src_ready_i` |

Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.

# Behaviour

Joins consecutive Avalon-ST packets into one. Empty symbols at an input end of packet are removed so the next packet follows directly. Library lint elaborates every module; wave0_elab is the other top. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-PACKET_JOIN-001"></a>

## REQ-PACKET_JOIN-001

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_reset`

<a id="REQ-PACKET_JOIN-002"></a>

## REQ-PACKET_JOIN-002

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_ready_init`

<a id="REQ-PACKET_JOIN-003"></a>

## REQ-PACKET_JOIN-003

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_out_stable`

<a id="REQ-PACKET_JOIN-004"></a>

## REQ-PACKET_JOIN-004

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_empty_at_eop_only`

<a id="REQ-PACKET_JOIN-005"></a>

## REQ-PACKET_JOIN-005

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_first_and_next_sop`

<a id="REQ-PACKET_JOIN-006"></a>

## REQ-PACKET_JOIN-006

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_out_sop`

<a id="REQ-PACKET_JOIN-007"></a>

## REQ-PACKET_JOIN-007

- Kind: extracted
- Verified by: `fv/packet/packet_join_sva.sv` property `a_out_cnt`
# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/packet_join.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `packet_join`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

packet_join #(
  // parameters from Schema
) u_packet_join (
  .clk_i (...),
  .reset_i (...),
  .last_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/packet_join_tb.sv | fv/packet/packet_join_sva.sv |

# Agent notes

- Read `src/packet/packet_join.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/packet_join_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/packet_join.sv)
- [simulation](../../playbooks/simulation.md)
