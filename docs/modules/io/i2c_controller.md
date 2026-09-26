---
type: Module
title: i2c_controller
description: I2C master controller.
tags: [domain:io, module:i2c_controller]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/io/i2c/i2c_controller.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

I2C master controller.

# When to use

See the [io domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter time g_CLOCK_PERIOD = time'(10ns)` |
| `parameter time g_I2C_PERIOD = time'(10us)` |


## Ports

| Declaration |
| --- |
| `input  logic       clk_i` |
| `input  logic       reset_i` |
| `output logic       scl_o` |
| `input  logic       sda_i` |
| `output logic       sda_o` |
| `output logic       sda_en_o` |
| `input  logic [7:0] cmd_data_i` |
| `input  logic [6:0] cmd_address_i` |
| `input  logic       cmd_valid_i` |
| `output logic       cmd_error_o` |
| `output logic       cmd_ready_o` |
| `input  logic       cmd_read_i` |
| `output logic [7:0] rd_data_o` |
| `output logic       rd_valid_o` |
| `input  logic       rd_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

I2C Master Controller module Author: Alberto Perro (alberto.perro at cern.ch) Date: 20-03-2024 Version: 0.1 This module implements a simple I2C controller. Release log: - 0.1 first release Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).

# Integration

- Verilator: add `verilator/files/io.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/io/i2c/i2c_controller.sv`.


- Upstream entity name matches module name `i2c_controller`.

# Examples

```systemverilog
// Compile verilator/files/io.f and verilator/colibri.f

i2c_controller #(
  // parameters from Schema
) u_i2c_controller (
  .clk_i (...),
  .reset_i (...),
  .scl_o (...),
  .sda_i (...),
  .sda_o (...),
  .sda_en_o (...),
  .cmd_data_i (...),
  .cmd_address_i (...),
  .cmd_valid_i (...),
  .cmd_error_o (...),
  .cmd_ready_o (...),
  .cmd_read_i (...),
  .rd_data_o (...),
  .rd_valid_o (...),
  .rd_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/io/i2c/i2c_controller_tb.sv | none |

# Agent notes

- Read `src/io/i2c/i2c_controller.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/io/i2c/i2c_controller_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [io RTL](../../../src/io/i2c/i2c_controller.sv)
- [simulation](../../playbooks/simulation.md)
