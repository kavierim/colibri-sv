---
type: Module
title: stream_buffer
description: Elastic stream buffer (skid or pipeline via generic).
tags: [domain:common, module:stream_buffer, interface:avst]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/common/stream_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Elastic stream buffer (skid or pipeline via generic).

RTL notes: Simple generic stream buffer. Zero latency (skid) when g_REGISTER_DATAPATH is 0. One clock of latency (pipeline) when g_REGISTER_DATAPATH is 1. g_DATA_WIDTH is VHDL natural. downto_width keeps a 0-wide vector off the [ -1 : 0 ] range.

# When to use

Default elastic buffer for valid/ready streams. Set `g_REGISTER_DATAPATH = 0` for skid (minimum latency 0) or `1` for pipeline (minimum latency 1). Prefer over legacy [`skid_buffer`](skid_buffer.md) and [`pipeline_buffer`](pipeline_buffer.md).

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_DATA_WIDTH        = 8` |
| | `parameter bit g_REGISTER_DATAPATH = 1'b0` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                                                      reset_i` |
| | `input  logic                                                      clk_i` |
| | `input  logic [colibri_utils::downto_width(g_DATA_WIDTH)-1:0]      snk_data_i` |
| | `input  logic                                                      snk_valid_i` |
| | `output logic                                                      snk_ready_o` |
| | `output logic [colibri_utils::downto_width(g_DATA_WIDTH)-1:0]      src_data_o` |
| | `input  logic                                                      src_ready_i` |
| | `output logic                                                      src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Simple generic stream buffer. Zero latency (skid) when g_REGISTER_DATAPATH is 0. One clock of latency (pipeline) when g_REGISTER_DATAPATH is 1. g_DATA_WIDTH is VHDL natural. downto_width keeps a 0-wide vector off the [ -1 : 0 ] range. Skid mode keeps the datapath direct in normal operation; on backpressure the in-flight beat is stored and `snk_ready_o` can deassert until the skid empties. Pipeline mode always registers data (two-word FIFO semantics) and fully decouples source and destination.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/stream_buffer.sv`.


- Upstream entity name matches module name `stream_buffer`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

stream_buffer #(
  // parameters from Schema
) u_stream_buffer (
  .reset_i (...),
  .clk_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_ready_i (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/stream_buffer_tb.sv | fv/common/stream_buffer_sva.sv |

# Agent notes

- Read `src/common/stream_buffer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/stream_buffer_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/stream_buffer.sv)
- [simulation](../../playbooks/simulation.md)
