---
type: Module
title: arbiter
description: Round-robin arbiter for multiple stream sources.
tags: [domain:pipes, module:arbiter]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/pipes/arbiter.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Round-robin arbiter for multiple stream sources.

RTL notes: Round-robin arbiter. Inspired by https://github.com/chclau/arbiter_rr Grants one requester. The priority mask rotates after a grant is released.

# When to use

See the [pipes domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_NUM_INPUTS = 4` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                    clk_i` |
| | `input  logic                    reset_i` |
| | `input  logic [g_NUM_INPUTS-1:0] requests_i` |
| | `output logic [g_NUM_INPUTS-1:0] grants_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Round-robin arbiter. Inspired by https://github.com/chclau/arbiter_rr Grants one requester. The priority mask rotates after a grant is released. Round-robin grants one input stream per cycle when the sink accepts a beat.

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/pipes/arbiter.sv`.


- Upstream entity name matches module name `arbiter`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

arbiter #(
  // parameters from Schema
) u_arbiter (
  .clk_i (...),
  .reset_i (...),
  .requests_i (...),
  .grants_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/pipes/arbiter_tb.sv | fv/pipes/arbiter_sva.sv |

# Agent notes

- Read `src/pipes/arbiter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/pipes/arbiter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [pipes RTL](../../../src/pipes/arbiter.sv)
- [simulation](../../playbooks/simulation.md)
