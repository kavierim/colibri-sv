---
type: Module
title: pipeline_buffer
description: Legacy two-stage decoupled buffer; prefer `stream_buffer`.
tags: [domain:common, module:pipeline_buffer]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/common/pipeline_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Legacy two-stage decoupled buffer; prefer `stream_buffer`.

RTL notes: Pipeline buffer (two-stage fifo) to propagate back-pressure and register combinational paths. Use this for better performance and full decoupling, use skid buffer if low latency is needed. Release log: - 0.1 first release

# When to use

Prefer [`stream_buffer`](stream_buffer.md) with `g_REGISTER_DATAPATH = 1`.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_DATA_WIDTH = 32` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic clk_i` |
| | `input  logic reset_i` |
| | `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| | `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i` |
| | `input  logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] snk_keep_i` |
| | `input  logic snk_sop_i` |
| | `input  logic snk_eop_i` |
| | `input  logic snk_valid_i` |
| | `output logic snk_ready_o` |
| | `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| | `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o` |
| | `output logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] src_keep_o` |
| | `output logic src_sop_o` |
| | `output logic src_eop_o` |
| | `output logic src_valid_o` |
| | `input  logic src_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Pipeline buffer (two-stage fifo) to propagate back-pressure and register combinational paths. Use this for better performance and full decoupling, use skid buffer if low latency is needed. Release log: - 0.1 first release See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/pipeline_buffer.sv`.


- Upstream entity name matches module name `pipeline_buffer`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

pipeline_buffer #(
  // parameters from Schema
) u_pipeline_buffer (
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
| yes | sim/common/pipeline_buffer_tb.sv | fv/common/pipeline_buffer_sva.sv |

# Agent notes

- Read `src/common/pipeline_buffer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/pipeline_buffer_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/pipeline_buffer.sv)
- [simulation](../../playbooks/simulation.md)
