---
type: Module
title: spi_master
description: SPI master.
tags: [domain:io, module:spi_master]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/io/spi/spi_master.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

SPI master.

RTL notes: Serial Peripheral Interface Master Author: Alberto Perro (alberto.perro at cern.ch) Date: 05-02-2025 Version: 0.1 0.1 initial release

# When to use

See the [io domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter time g_CLOCK_PERIOD = time'(25ns)` |
| | `parameter int unsigned g_SCK_FREQUENCY = 1_000_000,  // spi clock frequency` |
| | `parameter int unsigned g_WORD_SIZE = 8` |
| | `parameter logic g_SCK_POLARITY = 1'b0,  // 0 -> active high` |
| | `parameter logic g_SCK_PHASE = 1'b0      // 0 -> rising edge` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                   clk_i` |
| | `input  logic                   miso_i,  // Master In Slave Out` |
| | `output logic                   mosi_o,  // Master Out Slave In` |
| | `output logic                   cs_n_o,  // Chip Select (active low)` |
| | `output logic                   sck_o,   // SPI clock` |
| | `output logic [g_WORD_SIZE-1:0] src_data_o` |
| | `output logic                   src_valid_o` |
| | `input  logic [g_WORD_SIZE-1:0] snk_data_i` |
| | `input  logic                   snk_valid_i` |
| | `output logic                   snk_ready_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Serial Peripheral Interface Master Author: Alberto Perro (alberto.perro at cern.ch) Date: 05-02-2025 Version: 0.1 0.1 initial release Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).

# Integration

- Verilator: add `verilator/files/io.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/io/spi/spi_master.sv`.


- Upstream entity name matches module name `spi_master`.

# Examples

```systemverilog
// Compile verilator/files/io.f and verilator/colibri.f

spi_master #(
  // parameters from Schema
) u_spi_master (
  .clk_i (...),
  .Out (...),
  .In (...),
  .clock (...),
  .src_data_o (...),
  .src_valid_o (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/io/spi/spi_master_tb.sv | none |

# Agent notes

- Read `src/io/spi/spi_master.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/io/spi/spi_master_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [io RTL](../../../src/io/spi/spi_master.sv)
- [simulation](../../playbooks/simulation.md)
