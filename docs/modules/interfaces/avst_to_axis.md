---
type: Module
title: avst_to_axis
description: Avalon-ST to AXI-Stream adapter.
tags: [domain:interfaces, module:avst_to_axis, interface:avst]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: stable
resource: src/interfaces/stream/avst_to_axis.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Avalon-ST to AXI-Stream adapter.

# When to use

Connect colibri AVST logic to AXI-Stream IP. Map `tkeep` from beat width; see [`colibri_types`](../../packages/colibri_types.md).

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned             g_DATA_WIDTH      = 32` |
| `parameter colibri_types::endian_t  g_AVST_ENDIANNESS = colibri_types::BIG` |
| `parameter bit                      g_ADD_REGISTERS   = 1'b1` |


## Ports

| Declaration |
| --- |
| `input  logic                    clk_i` |
| `input  logic                    reset_i` |
| `output logic                    snk_ready_o` |
| `input  logic                    snk_valid_i` |
| `input  logic                    snk_sop_i` |
| `input  logic                    snk_eop_i` |
| `input  logic [c_EMPTY_W-1:0]    snk_empty_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic                    src_tready_i` |
| `output logic                    src_tvalid_o` |
| `output logic                    src_tlast_o` |
| `output logic [c_KEEP_W-1:0]     src_tkeep_o` |
| `output logic [g_DATA_WIDTH-1:0] src_tdata_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

Avalon ST to AXI Stream adapter. Release log: - 0.1 first release - 0.2 changed g_SWAP_ENDIANNESS for g_AVST_ENDIANNESS Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_to_axis.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `avst_to_axis`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_to_axis #(
  // parameters from Schema
) u_avst_to_axis (
  .clk_i (...),
  .reset_i (...),
  .snk_ready_o (...),
  .snk_valid_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_empty_i (...),
  .snk_data_i (...),
  .src_tready_i (...),
  .src_tvalid_o (...),
  .src_tlast_o (...),
  .src_tkeep_o (...),
  .src_tdata_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_to_axis_tb.sv | fv/interfaces/stream/avst_to_axis_sva.sv |

# Agent notes

- Read `src/interfaces/stream/avst_to_axis.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_to_axis_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_to_axis.sv)
- [simulation](../../playbooks/simulation.md)
