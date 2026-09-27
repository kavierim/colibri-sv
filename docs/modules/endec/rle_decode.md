---
type: Module
title: rle_decode
description: Run-length decoder.
tags: [domain:endec, module:rle_decode]
status: draft
resource: src/endec/rle_decode.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Endec::rle_decode
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
---
# Purpose

Run-length decoder.

# When to use

See the [endec domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_WORD_WIDTH  = 16` |
| `parameter int unsigned g_COUNT_WIDTH = 3` |

## Ports

| Declaration |
| --- |
| `input  logic                                      clk_i` |
| `input  logic                                      reset_i` |
| `output logic                                      snk_ready_o` |
| `input  logic                                      snk_valid_i` |
| `input  logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0]     snk_data_i` |
| `input  logic                                      src_ready_i` |
| `output logic                                      src_valid_o` |
| `output logic [g_WORD_WIDTH-1:0]                   src_data_o` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Run-Length Decoder Some of the work was inspired by VHDL Whiz Release log: - 0.1 first release Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops. 8b/10b tables live in `colibri_common_8b10b`; RLE modules operate on streaming data.

# Requirements

<a id="REQ-RLE_DECODE-001"></a>

## REQ-RLE_DECODE-001

The cycle after reset_i, src_valid_o shall be low.

- Kind: extracted
- Verified by: `fv/endec/rle_decode_sva.sv` property `t_no_valid_after_reset`

<a id="REQ-RLE_DECODE-002"></a>

## REQ-RLE_DECODE-002

When src_valid_o is stalled, src_data_o shall be stable on the next cycle.

- Kind: extracted
- Verified by: `fv/endec/rle_decode_sva.sv` property `t_out_stable_backpressure`

<a id="REQ-RLE_DECODE-003"></a>

## REQ-RLE_DECODE-003

When a new RLE word is accepted and the output is idle, src_valid_o shall rise with the expanded data word.

- Kind: extracted
- Verified by: `fv/endec/rle_decode_sva.sv` property `t_rle_forward`

<a id="REQ-RLE_DECODE-004"></a>

## REQ-RLE_DECODE-004

When the sink presents a new data value after a gap, the output count field shall match the encoder count.

- Kind: extracted
- Verified by: `fv/endec/rle_decode_sva.sv` property `t_rle_count`

# Integration

- Verilator: add `verilator/files/endec.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/endec/rle_decode.sv`.

- Upstream entity name matches module name `rle_decode`.

# Examples

```systemverilog
// Compile verilator/files/endec.f and verilator/colibri.f

rle_decode #(
  // parameters from Schema
) u_rle_decode (
  .clk_i (...),
  .reset_i (...),
  .snk_ready_o (...),
  .snk_valid_i (...),
  .snk_data_i (...),
  .src_ready_i (...),
  .src_valid_o (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/endec/rle_decode_tb.sv | fv/endec/rle_decode_sva.sv |

# Agent notes

- Read `src/endec/rle_decode.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/endec/rle_decode_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [endec RTL](../../../src/endec/rle_decode.sv)
- [simulation](../../playbooks/simulation.md)
