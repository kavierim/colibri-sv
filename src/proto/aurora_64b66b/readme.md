<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Aurora 64b/66b

An implementation of the [Aurora 64b/66b](https://docs.amd.com/v/u/en-US/aurora_64b66b_protocol_spec_sp011) specification.

Constants live in package `colibri_aurora_const` (`include/aurora_const_pkg.sv`), the VHDL package `aurora_const`.

The transmitter and receiver support:

- a 64-bit stream in either direction with an Aurora-encoded stream of a chosen lane width
- simplex transmission
- channel bonding

### Modules

- `aurora_tx` — transmitter (`aurora_tx.sv`)
- `aurora_rx` — receiver (`aurora_rx.sv`)
- `aurora_st_encoder` — stream encoder (`tx/aurora_st_encoder.sv`)
- `aurora_st_decoder` — stream decoder (`rx/aurora_st_decoder.sv`)
- `gearbox_up`, `cc_gearbox_up` — continuous upscaling gearboxes in `rx/` (these are Aurora gearboxes, not `src/comms/gearbox.sv`)
- `block_sync_fsm`, `channel_bond`, `meta_buffer`

### Generics

`g_N_LANES` sets the lane count and `g_LANE_WIDTH` sets the lane width.

Watch for backpressure in simulation. `g_GBX_BUF_SIZE` sizes the gearbox buffer.

On the receiver, `g_USE_OPTIMIZED_GBX` defaults to 1. The RX then uses the continuous gearbox in [`rx/`](rx/). On Xilinx UltraScale+ that path is about 200 LUTs instead of about 700 for a gearbox plus a slip buffer. That gearbox has no `ready` backpressure. It is built for a continuous stream: the last words stay inside until the buffer has enough data to emit a beat.

If the link corrupts data or loses lock, tune `g_SH_INVALID_CNT_MAX` and `g_SH_CNT_MAX` on `block_sync_fsm`.

### Two clocks

The encoder and decoder can run on two clocks, which is one way to match the stream rate to the line rate.

### Tests

| Testbench | What it checks |
| --- | --- |
| `sim/proto/aurora_64b66b/tx/aurora_st_encoder_tb.sv` | encoder |
| `sim/proto/aurora_64b66b/rx/aurora_st_decoder_tb.sv` | decoder |
| `sim/proto/aurora_64b66b/aurora_tx_tb.sv` | transmitter |
| `sim/proto/aurora_64b66b/endec/endec_loopback_tb.sv` | encoder/decoder loopback |
| `sim/proto/aurora_64b66b/loopback/aurora_loopback_tb.sv` | TX/RX loopback |
| `sim/proto/aurora_64b66b/loopback/aurora_lane_mismatch_tb.sv` | lane mismatch |
| `sim/proto/aurora_64b66b/throughput/aurora_throughput_tb.sv` | throughput |
