---
type: Module
title: powerup_reset
description: Power-up reset stretcher.
tags: [domain:misc, module:powerup_reset]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/misc/powerup_reset.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Power-up reset stretcher.

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter logic g_POLARITY = 1'b1` |
| `parameter int unsigned g_DURATION = 16` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_ext_i` |
| `output logic reset_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Power-up reset generator. Generates a fixed duration reset pulse at start-up. Polarity and duration come from `g_POLARITY` and `g_DURATION`. `reset_ext_i` is asynchronous and active high. `reset_o` is synchronous to `clk_i`. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/powerup_reset.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `powerup_reset`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

powerup_reset #(
  // parameters from Schema
) u_powerup_reset (
  .clk_i (...),
  .reset_ext_i (...),
  .reset_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/powerup_reset_tb.sv | none |

# Agent notes

- Read `src/misc/powerup_reset.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/powerup_reset_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/powerup_reset.sv)
- [simulation](../../playbooks/simulation.md)
