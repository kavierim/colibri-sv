---
type: Module
title: skid_buffer
description: Legacy low-latency elastic buffer; prefer `stream_buffer`.
tags: [domain:common, module:skid_buffer]
status: draft
resource: src/common/skid_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Common::skid_buffer
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-SKID_BUFFER-001
    statement: The cycle after reset_i, src_valid_o shall be low and the skid register shall be empty.
  - id: REQ-SKID_BUFFER-002
    statement: When src_valid_o is high and src_ready_i is low, src_valid_o and src_data_o shall hold on the next clock edge.
  - id: REQ-SKID_BUFFER-003
    statement: When a beat is accepted while the output is stalled, the skid register shall capture snk_data_i on the next cycle.
  - id: REQ-SKID_BUFFER-004
    statement: When src_ready_i is high, snk_valid_i shall equal src_valid_o on the next clock edge.
  - id: REQ-SKID_BUFFER-005
    statement: When the skid register is full and src_ready_i is high, reg_full shall be low on the next cycle.
---
# Purpose

Legacy low-latency elastic buffer; prefer `stream_buffer`.

# When to use

Prefer [`stream_buffer`](stream_buffer.md) with `g_REGISTER_DATAPATH = 0`.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_DATA_WIDTH = 32` |

## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i` |
| `input  logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] snk_keep_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o` |
| `output logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] src_keep_o` |
| `output logic src_sop_o` |
| `output logic src_eop_o` |
| `output logic src_valid_o` |
| `input  logic src_ready_i` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Skid buffer to propagate back-pressure. Use this if low latency is needed, use pipeline buffer for better performance and full decoupling. Release log: - 0.1 first release See RTL for clocking; not every block has `reset_i`.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-SKID_BUFFER-001"></a>

## REQ-SKID_BUFFER-001

- Kind: extracted
- Verified by: `fv/common/skid_buffer_sva.sv` property `t_no_valid_after_reset`

<a id="REQ-SKID_BUFFER-002"></a>

## REQ-SKID_BUFFER-002

- Kind: extracted
- Verified by: `fv/common/skid_buffer_sva.sv` property `t_out_stable_backpressure`

<a id="REQ-SKID_BUFFER-003"></a>

## REQ-SKID_BUFFER-003

- Kind: extracted
- Verified by: `fv/common/skid_buffer_sva.sv` property `t_no_data_drop`

<a id="REQ-SKID_BUFFER-004"></a>

## REQ-SKID_BUFFER-004

- Kind: extracted
- Verified by: `fv/common/skid_buffer_sva.sv` property `t_idle`

<a id="REQ-SKID_BUFFER-005"></a>

## REQ-SKID_BUFFER-005

- Kind: extracted
- Verified by: `fv/common/skid_buffer_sva.sv` property `t_reg_read`
# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/skid_buffer.sv`.

- Upstream entity name matches module name `skid_buffer`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

skid_buffer #(
  // parameters from Schema
) u_skid_buffer (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_keep_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_keep_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/skid_buffer_tb.sv | fv/common/skid_buffer_sva.sv |

# Agent notes

- Read `src/common/skid_buffer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/skid_buffer_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/skid_buffer.sv)
- [simulation](../../playbooks/simulation.md)
