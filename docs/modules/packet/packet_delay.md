---
type: Module
title: packet_delay
description: Delay packets by a fixed number of clocks.
tags: [domain:packet, module:packet_delay]
status: draft
resource: src/packet/packet_delay.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Packet::packet_delay
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
---
# Purpose

Delay packets by a fixed number of clocks.

# When to use

See the [packet domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_SYM_WIDTH   = 8` |
| `parameter int unsigned g_DATA_SYM    = 4` |
| `parameter int unsigned g_N_PACKETS   = 3` |
| `parameter int unsigned g_NUM_BEATS   = 8` |
| `parameter int unsigned g_DELAY_WIDTH = 4` |

## Ports

| Declaration |
| --- |
| `input  logic                      clk_i` |
| `input  logic                      reset_i` |
| `input  logic [g_DELAY_WIDTH-1:0]  delay_i` |
| `input  logic [c_DATA_W-1:0]       snk_data_i` |
| `input  logic [c_EMPTY_W-1:0]      snk_empty_i` |
| `input  logic                      snk_sop_i` |
| `input  logic                      snk_eop_i` |
| `input  logic                      snk_valid_i` |
| `output logic                      snk_ready_o` |
| `output logic [c_DATA_W-1:0]       src_data_o` |
| `output logic [c_EMPTY_W-1:0]      src_empty_o` |
| `output logic                      src_sop_o` |
| `output logic                      src_eop_o` |
| `output logic                      src_valid_o` |
| `input  logic                      src_ready_i` |

Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.

# Behaviour

Delays Avalon-ST packets by delay_i clock cycles, counted from the input start-of-packet handshake. Up to g_N_PACKETS packets can be in flight. Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.

# Requirements

<a id="REQ-PACKET_DELAY-001"></a>

## REQ-PACKET_DELAY-001

The cycle after reset_i, src_valid_o shall be low.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_reset`

<a id="REQ-PACKET_DELAY-002"></a>

## REQ-PACKET_DELAY-002

While reset_i is high, snk_ready_o shall be low.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_ready_mask`

<a id="REQ-PACKET_DELAY-003"></a>

## REQ-PACKET_DELAY-003

On the cycle reset_i falls, snk_ready_o shall be high.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_ready_init`

<a id="REQ-PACKET_DELAY-004"></a>

## REQ-PACKET_DELAY-004

When src_valid_o is stalled, output data and packet flags shall remain stable.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_out_stable`

<a id="REQ-PACKET_DELAY-005"></a>

## REQ-PACKET_DELAY-005

When the delay logic needs a start-of-packet, src_sop_o shall be high on valid output.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_first_and_next_sop`

<a id="REQ-PACKET_DELAY-006"></a>

## REQ-PACKET_DELAY-006

On the first output start-of-packet with non-zero configured delay, delay_cnt shall equal the captured delay.

- Kind: extracted
- Verified by: `fv/packet/packet_delay_sva.sv` property `a_delay`

# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/packet/packet_delay.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `packet_delay`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

packet_delay #(
  // parameters from Schema
) u_packet_delay (
  .clk_i (...),
  .reset_i (...),
  .delay_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/packet/packet_delay_tb.sv | fv/packet/packet_delay_sva.sv |

# Agent notes

- Read `src/packet/packet_delay.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/packet/packet_delay_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [packet RTL](../../../src/packet/packet_delay.sv)
- [simulation](../../playbooks/simulation.md)
