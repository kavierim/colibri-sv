---
type: Module
title: cc_gearbox
description: Dual-clock width gearbox.
tags: [domain:comms, module:cc_gearbox, cdc]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/comms/cc_gearbox.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Dual-clock width gearbox.

RTL notes: Dual-clock gearbox. Uses cc_fifo, or cc_ram_fifo when g_USE_BLOCK_RAM is set.

# When to use

Use [`gearbox`](gearbox.md) for single-clock width conversion.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_INPUT_WIDTH = 8` |
| | `parameter int unsigned g_OUTPUT_WIDTH = 10` |
| | `parameter int unsigned g_BUFFER_WORDS = 6` |
| | `parameter bit          g_USE_BLOCK_RAM = 1'b0` |
| | `parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                      snk_clk_i` |
| | `input  logic                      snk_reset_i` |
| | `input  logic                      src_clk_i` |
| | `input  logic [g_INPUT_WIDTH-1:0]  snk_data_i` |
| | `input  logic                      snk_valid_i` |
| | `output logic                      snk_ready_o` |
| | `output logic [g_OUTPUT_WIDTH-1:0] src_data_o` |
| | `output logic                      src_valid_o` |
| | `input  logic                      src_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Dual-clock gearbox. Uses cc_fifo, or cc_ram_fifo when g_USE_BLOCK_RAM is set. Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.

# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/cc_gearbox.sv`.


- Upstream entity name matches module name `cc_gearbox`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

cc_gearbox #(
  // parameters from Schema
) u_cc_gearbox (
  .snk_clk_i (...),
  .snk_reset_i (...),
  .src_clk_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/cc_gearbox_up_tb.sv, cc_gearbox_down_tb.sv, cc_gearbox_*_thr_tb.sv, cc_gearbox_loopback_tb.sv | none |

# Agent notes

- Read `src/comms/cc_gearbox.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/cc_gearbox_up_tb.sv, cc_gearbox_down_tb.sv, cc_gearbox_*_thr_tb.sv, cc_gearbox_loopback_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/cc_gearbox.sv)
- [simulation](../../playbooks/simulation.md)
