---
type: Module
title: channel_bond
description: Multi-lane channel bonding.
tags: [domain:aurora, module:channel_bond]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/proto/aurora_64b66b/rx/channel_bond.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Multi-lane channel bonding.

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_N_LANES      = 1` |
| `parameter int unsigned g_BUF_SIZE     = 8` |
| `parameter bit          g_REGISTER_OUT = 1'b1` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] snk_data_i [0:g_N_LANES-1]` |
| `input  logic [g_N_LANES-1:0] snk_valid_i` |
| `output logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] src_data_o [0:g_N_LANES-1]` |
| `output logic [g_N_LANES-1:0] src_valid_o` |
| `output logic src_bond_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Aurora Multi Lane Bonding. Each lane is fed to a dedicated FIFO. The FIFOs are read until a channel bond word is seen. Once every FIFO shows a bond word, skew is compensated and src_bond_o is asserted. changelog: - 0.1 first release - 0.1b: update to lhcb vhdl style guideline Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/rx/channel_bond.sv`.


- Upstream entity name matches module name `channel_bond`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

channel_bond #(
  // parameters from Schema
) u_channel_bond (
  .clk_i (...),
  .reset_i (...),
  .snk_valid_i (...),
  .src_valid_o (...),
  .src_bond_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/rx/channel_bond.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/rx/channel_bond.sv)
- [simulation](../../../playbooks/simulation.md)
