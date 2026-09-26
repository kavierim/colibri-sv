---
type: Module
title: scrambler
description: Self-synchronous (multiplicative) scrambler.
tags: [domain:comms, module:scrambler]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/comms/scrambler.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Self-synchronous (multiplicative) scrambler.

RTL notes: Self-synchronous scrambler.

# When to use

See the [comms domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_DATA_WIDTH = 64` |
| | `parameter g_SCRAMBLER_POLY = colibri_poly::c_SCR_10GBASE` |
| | `parameter g_INIT_VAL = $bits(g_SCRAMBLER_POLY)'({4096{2'b01}})` |
| | `parameter bit g_INVERT_IN = 1'b1` |
| | `parameter bit g_INVERT_OUT = 1'b1` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                    clk_i` |
| | `input  logic                    reset_i,      // active high` |
| | `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| | `input  logic                    snk_valid_i` |
| | `output logic                    snk_ready_o` |
| | `output logic                    src_valid_o` |
| | `input  logic                    src_ready_i` |
| | `output logic [g_DATA_WIDTH-1:0] src_data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Self-synchronous scrambler. Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.

# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/scrambler.sv`.


- Upstream entity name matches module name `scrambler`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

scrambler #(
  // parameters from Schema
) u_scrambler (
  .clk_i (...),
  .high (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/scrambler_tb.sv | none |

# Agent notes

- Read `src/comms/scrambler.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/scrambler_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/scrambler.sv)
- [simulation](../../playbooks/simulation.md)
