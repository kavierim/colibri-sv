---
type: Module
title: jtag_serdes
description: JTAG USER-register duplex stream bridge.
tags: [domain:io, module:jtag_serdes]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/io/jtag/jtag_serdes.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

JTAG USER-register duplex stream bridge.

RTL notes: JTAG stream serializer/deserializer Author: Alberto Perro (alberto.perro at cern.ch) Date: 15-12-2025 Created Version: 0.1 Copyright CERN 2025 This component converts a simple jtag interface with additional FSM signals (shift, update) into a streaming duplex interface with configurable data width. The entity has been designed to work with JTAG primitives available from vendors to create a vendor-independent direct interface with user logic.

# When to use

Bridge parallel stream beats to a JTAG USER data register. Often paired with [`stream_to_wbm`](../misc/stream_to_wbm.md) for register access over JTAG.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_DATA_WIDTH = 8` |
| | `parameter bit g_REG_FALLING = 1'b0` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic clk_ser_i` |
| | `input  logic clk_par_i` |
| | `input  logic shift_i` |
| | `input  logic update_i` |
| | `input  logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_i` |
| | `input  logic par_valid_i` |
| | `output logic par_ready_o` |
| | `output logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_o` |
| | `output logic par_valid_o` |
| | `input  logic ser_data_i` |
| | `output logic ser_data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

JTAG stream serializer/deserializer Author: Alberto Perro (alberto.perro at cern.ch) Date: 15-12-2025 Created Version: 0.1 Copyright CERN 2025 This component converts a simple jtag interface with additional FSM signals (shift, update) into a streaming duplex interface with configurable data width. The entity has been designed to work with JTAG primitives available from vendors to create a vendor-independent direct interface with user logic. Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).

# Integration

- Verilator: add `verilator/files/io.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/io/jtag/jtag_serdes.sv`.

- Vendor BSCAN primitives are outside this port. Connect `shift_i`/`update_i` as `shift & sel` and `update & sel`. AMD USER1 IR is `0x02`; Intel USER0 is `0x00C`. See OpenOCD `irscan` / `drscan` examples in the upstream JTAG readme (now summarized here).
- Upstream entity name matches module name `jtag_serdes`.

# Examples

```systemverilog
jtag_serdes #(
  .g_DATA_WIDTH(40)
) jtag_serdes_inst (
  .clk_ser_i   (gck),
  .clk_par_i   (sys_clk),
  .shift_i     (shift & sel),
  .update_i    (update & sel),
  .par_data_i  (ps_data),
  .par_valid_i (ps_valid),
  .par_ready_o (),
  .par_data_o  (sp_data),
  .par_valid_o (sp_valid),
  .ser_data_i  (tdi),
  .ser_data_o  (tdo)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/io/jtag/jtag_serdes_tb.sv | none |

# Agent notes

- Read `src/io/jtag/jtag_serdes.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/io/jtag/jtag_serdes_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [io RTL](../../../src/io/jtag/jtag_serdes.sv)
- [simulation](../../playbooks/simulation.md)
