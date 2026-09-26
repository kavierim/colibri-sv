---
type: Playbook
title: Typical datapaths
description: Common module chains for integration (not exhaustive).
tags: [playbook, integration]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# AVST packet + CRC

[`header_add`](../modules/packet/header_add.md) → payload logic → [`crc`](../modules/comms/crc.md) → [`be_add_trail`](../modules/misc/be_add_trail.md) (optional) → [`packet_fifo`](../modules/memory/packet_fifo.md) or PHY adapter.

# Width / protocol bridge

Narrow AVST → [`avst_width_converter`](../modules/interfaces/avst_width_converter.md) → wide AVST → [`avst_to_axis`](../modules/interfaces/avst_to_axis.md) → AXI-Stream IP.

# Clock crossing

Same-width AVST: [`avst_cdc`](../modules/interfaces/avst_cdc.md) or [`packet_cc_ram_fifo`](../modules/memory/packet_cc_ram_fifo.md). Arbitrary payload: [`synchro_handshake`](../modules/common/synchro_handshake.md).

# CPU packet port

[`mmap_fifo`](../modules/misc/mmap_fifo.md) (Wishbone) ↔ software; AVST TX/RX to the datapath. CSR definitions in [`mmap_fifo_csr_pkg`](../packages/mmap_fifo_csr_pkg.md).

# Line coding

[`scrambler`](../modules/comms/scrambler.md) → PHY or [`encode_8b10b`](../modules/endec/encode_8b10b.md) depending on link. Receive: [`descrambler`](../modules/comms/descrambler.md) or [`decode_8b10b`](../modules/endec/decode_8b10b.md).

# Elasticity

Prefer [`stream_buffer`](../modules/common/stream_buffer.md) between blocks with backpressure; [`avst_fifo`](../modules/interfaces/avst_fifo.md) for packetized FIFO storage.

# Related

- [stream-interfaces](stream-interfaces.md)
- [modules index](../modules/index.md)
