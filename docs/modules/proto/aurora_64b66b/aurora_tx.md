---
type: Module
title: aurora_tx
description: Aurora transmitter (64b stream to encoded lanes).
tags: [domain:aurora, module:aurora_tx]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/proto/aurora_64b66b/aurora_tx.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Aurora transmitter (64b stream to encoded lanes).

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_N_LANES           = 1` |
| `parameter int unsigned g_LANE_WIDTH        = 32` |
| `parameter int unsigned g_GBX_BUF_SIZE      = 16 * colibri_aurora_const::c_AURORA_ENC_WIDTH` |
| `parameter bit          g_DISABLE_SCRAMBLER = 1'b0` |


## Ports

| Declaration |
| --- |
| `input  logic snk_clk_i` |
| `input  logic snk_reset_i` |
| `input  logic src_clk_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `input  logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] snk_empty_i` |
| `output logic [g_LANE_WIDTH-1:0] src_data_o [0:g_N_LANES-1]` |
| `output logic [g_N_LANES-1:0]    src_valid_o` |
| `input  logic [g_N_LANES-1:0]    src_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Aurora 64b/66b Transmitter. Simplex multi-lane Aurora 64b/66b transmitter chain (PMA/PCS): ENCODER -> SCRAMBLER -> GEARBOX Release log: - 0.1 first release - 0.2 add sub-entity register control in generics - 0.3 add multi-lane support - 0.4 vhdl common library integration - 0.4b Update to VHDL Style Guideline - 0.5 use only two clocks (removed the need of lane_clk), add generic lane width Top-level transmitter: 64-bit stream to Aurora-encoded lanes. Generics `g_N_LANES` and `g_LANE_WIDTH` set PHY width. Size `g_GBX_BUF_SIZE` for gearbox buffering under backpressure.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/aurora_tx.sv`.


- Upstream entity name matches module name `aurora_tx`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

aurora_tx #(
  // parameters from Schema
) u_aurora_tx (
  .snk_clk_i (...),
  .snk_reset_i (...),
  .src_clk_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/aurora_tx.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/aurora_tx.sv)
- [simulation](../../../playbooks/simulation.md)
