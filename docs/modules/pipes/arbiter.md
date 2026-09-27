---
type: Module
title: arbiter
description: Round-robin arbiter for multiple stream sources.
tags: [domain:pipes, module:arbiter]
status: draft
resource: src/pipes/arbiter.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Pipes::arbiter
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
requirements:
  - id: REQ-ARBITER-001
    statement: While reset_i is low, grants_o shall be zero or one-hot.
  - id: REQ-ARBITER-002
    statement: When exactly one request is active and reset_i is low, grants_o shall grant that request.
  - id: REQ-ARBITER-003
    statement: When no requests are active and reset_i is low, grants_o shall be all zeros.
  - id: REQ-ARBITER-004
    statement: When the previously granted request remains active, grants_o shall not change.
  - id: REQ-ARBITER-005
    statement: When the granted request drops but another request remains, grants_o shall change.
  - id: REQ-ARBITER-006
    statement: When the granted-request mask changes, priority_q shall update on the next cycle.
---
# Purpose

Round-robin arbiter for multiple stream sources.

# When to use

See the [pipes domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_NUM_INPUTS = 4` |

## Ports

| Declaration |
| --- |
| `input  logic                    clk_i` |
| `input  logic                    reset_i` |
| `input  logic [g_NUM_INPUTS-1:0] requests_i` |
| `output logic [g_NUM_INPUTS-1:0] grants_o` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Round-robin arbiter. Inspired by https://github.com/chclau/arbiter_rr Grants one requester. The priority mask rotates after a grant is released. Round-robin grants one input stream per cycle when the sink accepts a beat.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-ARBITER-001"></a>

## REQ-ARBITER-001

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_single_grant`

<a id="REQ-ARBITER-002"></a>

## REQ-ARBITER-002

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_req_grant`

<a id="REQ-ARBITER-003"></a>

## REQ-ARBITER-003

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_no_grant_if_no_req`

<a id="REQ-ARBITER-004"></a>

## REQ-ARBITER-004

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_stable_grant`

<a id="REQ-ARBITER-005"></a>

## REQ-ARBITER-005

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_change_grant`

<a id="REQ-ARBITER-006"></a>

## REQ-ARBITER-006

- Kind: extracted
- Verified by: `fv/pipes/arbiter_sva.sv` property `a_round_robin`
# Integration

- Verilator: add `verilator/files/packet_pipes.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/pipes/arbiter.sv`.

- Upstream entity name matches module name `arbiter`.

# Examples

```systemverilog
// Compile verilator/files/packet_pipes.f and verilator/colibri.f

arbiter #(
  // parameters from Schema
) u_arbiter (
  .clk_i (...),
  .reset_i (...),
  .requests_i (...),
  .grants_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/pipes/arbiter_tb.sv | fv/pipes/arbiter_sva.sv |

# Agent notes

- Read `src/pipes/arbiter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/pipes/arbiter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [pipes RTL](../../../src/pipes/arbiter.sv)
- [simulation](../../playbooks/simulation.md)
