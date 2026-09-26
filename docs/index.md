# Colibri SystemVerilog documentation

Canonical module and package documentation for the Verilator-oriented SystemVerilog port of [colibri](https://gitlab.com/colibri-cern/colibri).

## Playbooks

- [Getting started](playbooks/getting-started.md)
- [Simulation](playbooks/simulation.md)
- [Stream interfaces](playbooks/stream-interfaces.md)
- [Typical datapaths](playbooks/typical-datapaths.md)
- [Agent workflow](playbooks/agent-workflow.md)

## Reference

- [Conventions summary](reference/conventions.md)

## Catalog

- [Packages](packages/index.md)
- [Modules by domain](modules/index.md)

## Licencing

RTL, simulation, and formal verification files in this repository are **Covered Source** under [CERN-OHL-W-2.0](../LICENSES/CERN-OHL-W-2.0.txt); see [NOTICE](../NOTICE). Per-file SPDX headers on `src/**/*.sv` and the obligations in NOTICE satisfy redistribution of that hardware Source.

The pages under `docs/` are descriptive documentation. They are not hardware Source and do not need `SPDX-FileCopyrightText: 2026 CERN` (or `SPDX-License-Identifier: CERN-OHL-W-2.0`) on every file. Upstream colibri provenance is cited in module `sources` and in RTL headers.

Translation contract (authoritative): [`CONVENTIONS.md`](../CONVENTIONS.md).
