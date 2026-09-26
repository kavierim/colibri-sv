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

RTL, simulation, and formal verification files in this repository are **Covered Source** under [CERN-OHL-W-2.0](../LICENSES/CERN-OHL-W-2.0.txt); see [NOTICE](../NOTICE) for modification and provenance (plain text, no SPDX header). Per-file SPDX headers on `src/**/*.sv`, `sim/**/*.sv`, and `fv/**/*.sv` satisfy redistribution of that hardware Source.

The pages under `docs/` are descriptive documentation, maintained directly in the repository (no bundled doc generator). They are not hardware Source and do not need per-file CERN-OHL-W SPDX blocks. The same applies to ancillary repository files (Verilator file lists and `run_all.sh`, CI workflows, and similar): Kari copyright only, with hardware licencing described in `NOTICE`. Upstream colibri provenance is cited in module `sources` and in RTL headers.

Translation contract (authoritative): [`CONVENTIONS.md`](../CONVENTIONS.md).
