---
type: Module
title: axis_to_avst
description: AXI-Stream to Avalon-ST adapter.
tags: [domain:interfaces, module:axis_to_avst, interface:avst]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/interfaces/stream/axis_to_avst.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

AXI-Stream to Avalon-ST adapter.

RTL notes: AXI Stream to Avalon ST adapter. AXI-Stream byte order is little-endian (first byte in the low bits). Partially empty words keep the valid bytes grouped at the low end. Release log: - 0.1 first release - 0.2 changed g_SWAP_ENDIANNESS for g_AVST_ENDIANNESS

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned             g_DATA_WIDTH      = 32` |
| | `parameter colibri_types::endian_t  g_AVST_ENDIANNESS = colibri_types::BIG` |
| | `parameter bit                      g_ADD_REGISTERS   = 1'b1` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                    clk_i` |
| | `input  logic                    reset_i` |
| | `output logic                    snk_tready_o` |
| | `input  logic                    snk_tvalid_i` |
| | `input  logic                    snk_tlast_i` |
| | `input  logic [c_KEEP_W-1:0]     snk_tkeep_i` |
| | `input  logic [g_DATA_WIDTH-1:0] snk_tdata_i` |
| | `input  logic                    src_ready_i` |
| | `output logic                    src_valid_o` |
| | `output logic                    src_sop_o` |
| | `output logic                    src_eop_o` |
| | `output logic [c_EMPTY_W-1:0]    src_empty_o` |
| | `output logic [g_DATA_WIDTH-1:0] src_data_o` |


Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.


# Behaviour

AXI Stream to Avalon ST adapter. AXI-Stream byte order is little-endian (first byte in the low bits). Partially empty words keep the valid bytes grouped at the low end. Release log: - 0.1 first release - 0.2 changed g_SWAP_ENDIANNESS for g_AVST_ENDIANNESS Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/axis_to_avst.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `axis_to_avst`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

axis_to_avst #(
  // parameters from Schema
) u_axis_to_avst (
  .clk_i (...),
  .reset_i (...),
  .snk_tready_o (...),
  .snk_tvalid_i (...),
  .snk_tlast_i (...),
  .snk_tkeep_i (...),
  .snk_tdata_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/axis_to_avst_tb.sv | fv/interfaces/stream/axis_to_avst_sva.sv |

# Agent notes

- Read `src/interfaces/stream/axis_to_avst.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/axis_to_avst_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/axis_to_avst.sv)
- [simulation](../../playbooks/simulation.md)
