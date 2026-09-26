---
type: Module
title: heartbeat
description: Periodic heartbeat from a divided counter.
tags: [domain:misc, module:heartbeat]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/misc/heartbeat.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Periodic heartbeat from a divided counter.

RTL notes: Clock heartbeat generator. Divides `clk_i` down to `heartbeat_o`.

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter time g_BEAT_PERIOD = 1s` |
| | `parameter time g_CLK_PERIOD  = 8ns` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic clk_i` |
| | `input  logic reset_i` |
| | `output logic heartbeat_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Clock heartbeat generator. Divides `clk_i` down to `heartbeat_o`. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/heartbeat.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `heartbeat`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

heartbeat #(
  // parameters from Schema
) u_heartbeat (
  .clk_i (...),
  .reset_i (...),
  .heartbeat_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/heartbeat_tb.sv | none |

# Agent notes

- Read `src/misc/heartbeat.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/heartbeat_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/heartbeat.sv)
- [simulation](../../playbooks/simulation.md)
