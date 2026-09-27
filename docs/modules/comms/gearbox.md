---
type: Module
title: gearbox
description: Single-clock width gearbox.
tags: [domain:comms, module:gearbox]
status: draft
resource: src/comms/gearbox.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Comms::gearbox
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-GEARBOX-001
    statement: For 4-to-12 upsizing, when src_valid_o is high and src_ready_i is low, src_valid_o shall remain high on the next cycle unless reset_i is high.
  - id: REQ-GEARBOX-002
    statement: For 4-to-12 upsizing, when src_valid_o is stalled, src_data_o shall be stable on the next cycle unless reset_i is high.
  - id: REQ-GEARBOX-003
    statement: For 4-to-12 upsizing, the first cycle after reset_i falls, snk_ready_o shall be high, src_valid_o low, and src_data_o zero.
  - id: REQ-GEARBOX-004
    statement: For 12-to-4 downsizing, when src_valid_o is high and src_ready_i is low, src_valid_o shall remain high on the next cycle unless reset_i is high.
  - id: REQ-GEARBOX-005
    statement: For 12-to-4 downsizing, when src_valid_o is stalled, src_data_o shall be stable on the next cycle unless reset_i is high.
  - id: REQ-GEARBOX-006
    statement: For 12-to-4 downsizing, the first cycle after reset_i falls, snk_ready_o shall be high, src_valid_o low, and src_data_o zero.
---
# Purpose

Single-clock width gearbox.

# When to use

Use [`cc_gearbox`](cc_gearbox.md) when the two sides use different clocks.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_INPUT_WIDTH = 8` |
| `parameter int g_OUTPUT_WIDTH = 8` |

## Ports

| Declaration |
| --- |
| `input  logic                     clk_i` |
| `input  logic                     reset_i` |
| `input  logic [g_INPUT_WIDTH-1:0] snk_data_i` |
| `input  logic                     snk_valid_i` |
| `output logic                     snk_ready_o` |
| `output logic [g_OUTPUT_WIDTH-1:0] src_data_o` |
| `output logic                     src_valid_o` |
| `input  logic                     src_ready_i` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Single-clock gearbox. Input and output widths are independent. Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-GEARBOX-001"></a>

## REQ-GEARBOX-001

- Kind: extracted
- Verified by: `fv/comms/gearbox_up_sva.sv` property `t_stable_valid_not_ready`

<a id="REQ-GEARBOX-002"></a>

## REQ-GEARBOX-002

- Kind: extracted
- Verified by: `fv/comms/gearbox_up_sva.sv` property `t_stable_data`

<a id="REQ-GEARBOX-003"></a>

## REQ-GEARBOX-003

- Kind: extracted
- Verified by: `fv/comms/gearbox_up_sva.sv` property `t_valid_reset`

<a id="REQ-GEARBOX-004"></a>

## REQ-GEARBOX-004

- Kind: extracted
- Verified by: `fv/comms/gearbox_down_sva.sv` property `t_stable_valid_not_ready`

<a id="REQ-GEARBOX-005"></a>

## REQ-GEARBOX-005

- Kind: extracted
- Verified by: `fv/comms/gearbox_down_sva.sv` property `t_stable_data`

<a id="REQ-GEARBOX-006"></a>

## REQ-GEARBOX-006

- Kind: extracted
- Verified by: `fv/comms/gearbox_down_sva.sv` property `t_valid_reset`
# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/gearbox.sv`.

- Upstream entity name matches module name `gearbox`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

gearbox #(
  // parameters from Schema
) u_gearbox (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/gearbox_up_tb.sv, gearbox_down_tb.sv, gearbox_loopback_tb.sv | fv/comms/gearbox_up_sva.sv, gearbox_down_sva.sv |

# Agent notes

- Read `src/comms/gearbox.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/gearbox_up_tb.sv, gearbox_down_tb.sv, gearbox_loopback_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/gearbox.sv)
- [simulation](../../playbooks/simulation.md)
