# common
Modules under `src/common/`.

| Module | Description |
| --- | --- |
| [comparator](comparator.md) | Comparator with enable. |
| [counter](counter.md) | Simple counter with optional modulo and enable. |
| [debouncer](debouncer.md) | Input debouncer. |
| [edge_detect](edge_detect.md) | Rising and falling edge detection. |
| [pipeline_buffer](pipeline_buffer.md) | Legacy two-stage decoupled buffer; prefer `stream_buffer`. |
| [skid_buffer](skid_buffer.md) | Legacy low-latency elastic buffer; prefer `stream_buffer`. |
| [stream_buffer](stream_buffer.md) | Elastic stream buffer (skid or pipeline via generic). |
| [stream_buffer_generic](stream_buffer_generic.md) | Same buffer with a parameterized data type. |
| [synchro](synchro.md) | Clock-domain crossing for a packed vector. |
| [synchro_generic](synchro_generic.md) | CDC for a user-defined payload type. |
| [synchro_handshake](synchro_handshake.md) | Stream CDC with backpressure propagation. |
| [synchro_pulse](synchro_pulse.md) | Pulse synchronizer across clock domains. |
| [synchro_reset](synchro_reset.md) | Reset synchronizer. |
