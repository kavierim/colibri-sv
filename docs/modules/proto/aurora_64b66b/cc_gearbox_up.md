---
type: Module
title: cc_gearbox_up
description: Clock-crossing upscaling gearbox variant.
tags: [domain:aurora, module:cc_gearbox_up, cdc]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/proto/aurora_64b66b/rx/cc_gearbox_up.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Clock-crossing upscaling gearbox variant.

RTL notes: CDC Streaming Upsizing Gearbox. Generic upscaling gearbox for continuous streams with a clock domain crossing. It includes a slip signal to shift the output (1 bit resolution). Based on gearbox_up and cc_fifo. Release log: - 0.1: initial release

# When to use

Clock-crossing Aurora upscaler variant in the RX path.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_INPUT_WIDTH  = 8` |
| | `parameter int unsigned g_OUTPUT_WIDTH = 10` |
| | `parameter int unsigned g_BUFFER_WORDS = 6` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                          snk_clk_i` |
| | `input  logic                          snk_reset_i` |
| | `input  logic                          src_clk_i` |
| | `input  logic                          slip_i` |
| | `input  logic [g_INPUT_WIDTH-1:0]      snk_data_i` |
| | `input  logic                          snk_valid_i` |
| | `output logic [g_OUTPUT_WIDTH-1:0]     src_data_o` |
| | `output logic                          src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

CDC Streaming Upsizing Gearbox. Generic upscaling gearbox for continuous streams with a clock domain crossing. It includes a slip signal to shift the output (1 bit resolution). Based on gearbox_up and cc_fifo. Release log: - 0.1: initial release Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/rx/cc_gearbox_up.sv`.


- Upstream entity name matches module name `cc_gearbox_up`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

cc_gearbox_up #(
  // parameters from Schema
) u_cc_gearbox_up (
  .snk_clk_i (...),
  .snk_reset_i (...),
  .src_clk_i (...),
  .slip_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .src_data_o (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/rx/cc_gearbox_up.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/rx/cc_gearbox_up.sv)
- [simulation](../../../playbooks/simulation.md)
