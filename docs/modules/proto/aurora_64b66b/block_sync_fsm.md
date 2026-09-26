---
type: Module
title: block_sync_fsm
description: Block synchronization state machine.
tags: [domain:aurora, module:block_sync_fsm]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/proto/aurora_64b66b/rx/block_sync_fsm.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Block synchronization state machine.

RTL notes: Block Sync FSM. Determines and checks the link lock status. See Aurora FSM flowchart and IEEE 802.3ae fig 49-14 (rev.2022). changelog: - 0.1 first release - 0.1b: update to lhcb vhdl style guideline

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_SH_CNT_MAX         = 64` |
| | `parameter int unsigned g_SH_INVALID_CNT_MAX = 16` |
| | `parameter int unsigned g_SLIP_CNT_MAX       = 32` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic       clk_i` |
| | `input  logic       reset_i` |
| | `input  logic [1:0] snk_meta_i` |
| | `input  logic       snk_valid_i` |
| | `output logic       snk_slip_o` |
| | `output logic       src_sync_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Block Sync FSM. Determines and checks the link lock status. See Aurora FSM flowchart and IEEE 802.3ae fig 49-14 (rev.2022). changelog: - 0.1 first release - 0.1b: update to lhcb vhdl style guideline Block synchronization FSM for Aurora RX. Tune `g_SH_INVALID_CNT_MAX` and `g_SH_CNT_MAX` when the link loses lock or corrupts framing.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/rx/block_sync_fsm.sv`.


- Upstream entity name matches module name `block_sync_fsm`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

block_sync_fsm #(
  // parameters from Schema
) u_block_sync_fsm (
  .clk_i (...),
  .reset_i (...),
  .snk_meta_i (...),
  .snk_valid_i (...),
  .snk_slip_o (...),
  .src_sync_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/rx/block_sync_fsm.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/rx/block_sync_fsm.sv)
- [simulation](../../../playbooks/simulation.md)
