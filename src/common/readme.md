<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Common packages and modules

Shared functions and small building blocks used by the rest of the library.

### Packages

- `colibri_utils` (`utils.sv`) — bit-math, registers, and bit/byte manipulation. VHDL package `utils`.
- `colibri_encoders` (`encoders.sv`) — gray, one-hot, and related encodings. VHDL package `encoders`.
- `colibri_types` (`types.sv`) — stream and interface types. VHDL package `types`.
- `colibri_poly` (`poly_pkg.sv`) — CRC, scrambler, and PRBS polynomials. VHDL package `poly`.

### Modules

- `counter` — a simple counter.
- `comparator` — a comparator with an enable.
- `edge_detect` — rising and falling edge detect.
- `synchro` — clock-domain crossing for a packed vector.
- `synchro_generic` — clock-domain crossing for a wider set of payloads.
- `synchro_reset` — reset synchronizer.
- `synchro_pulse` — pulse synchronizer across clock domains.
- `synchro_handshake` — stream synchronizer that propagates backpressure.
- `debouncer` — input debouncer.
- `stream_buffer` — elastic buffer for a simple stream. `g_REGISTER_DATAPATH` selects skid or pipeline behaviour.
- `stream_buffer_generic` — the same buffer with a caller-chosen data type.
- `skid_buffer` — legacy low-latency elastic buffer. Prefer `stream_buffer`.
- `pipeline_buffer` — legacy two-stage decoupled buffer. Prefer `stream_buffer`.

### How to use

Compile `verilator/colibri.f` and `verilator/files/common.f`. Import the packages you need:

```systemverilog
import colibri_utils::*;
import colibri_types::*;
import colibri_encoders::*;
import colibri_poly::*;
```

### Skid buffers and pipeline buffers

Skid and pipeline buffers connect blocks that use backpressure. They cut the combinational path by registering part or all of the handshake, and they do not drop data when the destination stalls.

Both behaviours live in `stream_buffer.sv` and `stream_buffer_generic.sv`. `g_REGISTER_DATAPATH` selects the mode.

In skid mode the data path is direct in normal operation, so the minimum latency is zero.

- When backpressure is asserted, the in-flight data is stored and the registered `ready` can fall.
- If backpressure lasts longer than one clock, it is propagated upstream through that registered `ready`.
- When backpressure is released, the stored data goes out first, the source stays not-ready for that beat, and then normal operation resumes.

In pipeline mode the mechanism is the same except that data is always registered, so the minimum latency is one clock. It is also a two-word FIFO. It uses more registers and it fully decouples source and destination.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `colibri_utils` | yes | `sim/common/utils_tb.sv` | `fv/common/utils_sva.sv` |
| `colibri_encoders` | yes | `sim/common/encoders_tb.sv` | no |
| `colibri_types` | yes | `sim/common/type_conv_tb.sv` | no |
| `counter` | yes | `sim/common/counter_tb.sv` | `fv/common/counter_sva.sv` |
| `comparator` | yes | `sim/common/comparator_tb.sv` | no |
| `edge_detect` | yes | `sim/common/edge_detect_tb.sv` | `fv/common/edge_detect_sva.sv` |
| `synchro` | yes | `sim/common/synchro_tb.sv` | no |
| `synchro_generic` | yes | `sim/common/synchro_generic_tb.sv` | no |
| `synchro_reset` | yes | `sim/common/synchro_reset_tb.sv` | no |
| `synchro_pulse` | yes | `sim/common/synchro_pulse_tb.sv` | no |
| `synchro_handshake` | yes | `sim/common/synchro_handshake_tb.sv` | no |
| `stream_buffer` | yes | `sim/common/stream_buffer_tb.sv` | `fv/common/stream_buffer_sva.sv` |
| `stream_buffer_generic` | yes | `sim/common/stream_buffer_generic_tb.sv` | no |
| `debouncer` | yes | `sim/common/debouncer_tb.sv` | `fv/common/debouncer_sva.sv` |
| `skid_buffer` | yes | `sim/common/skid_buffer_tb.sv` | `fv/common/skid_buffer_sva.sv` |
| `pipeline_buffer` | yes | `sim/common/pipeline_buffer_tb.sv` | `fv/common/pipeline_buffer_sva.sv` |
