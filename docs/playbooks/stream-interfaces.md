---
type: Playbook
title: Stream interfaces
description: Avalon-ST and AXI-Stream records, adapters, and CDC patterns.
tags: [playbook, interface:avst, interface:axis]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Types

Stream records and conversion helpers live in [`colibri_types`](../packages/colibri_types.md): Avalon-ST (`t_avst_*`) and AXI-Stream (`t_axis_*`) bundles with `data`, `valid`, `ready`, `startofpacket`, `endofpacket`, and `empty` where applicable.

# Adapters (`src/interfaces/stream/`)

| Module | Role |
| --- | --- |
| [`avst_to_axis`](../modules/interfaces/avst_to_axis.md) | AVST → AXI-Stream |
| [`axis_to_avst`](../modules/interfaces/axis_to_avst.md) | AXI-Stream → AVST |
| [`avst_width_converter`](../modules/interfaces/avst_width_converter.md) | Beat width change on AVST |
| [`avst_cdc`](../modules/interfaces/avst_cdc.md) | AVST clock-domain crossing |
| [`avst_fifo`](../modules/interfaces/avst_fifo.md) | AVST FIFO wrapper |

RAM writers/readers (`avst_ram_*`) connect streams to on-chip memories; see module pages for aligned vs byte-addressable variants.

# CDC

For arbitrary payloads use [`synchro_generic`](../modules/common/synchro_generic.md) or [`synchro_handshake`](../modules/common/synchro_handshake.md) in `src/common/`. Stream-specific CDC prefers `avst_cdc` or memory FIFOs (`packet_cc_ram_fifo`).

# Macros

Use the helper macros documented in `types.sv` and [`CONVENTIONS.md`](../../CONVENTIONS.md) to connect interfaces without manually wiring every field.

# Related

- [interfaces domain](../modules/interfaces/index.md)
- [colibri_types](../packages/colibri_types.md)
