# memory
Modules under `src/memory/`.

| Module | Description |
| --- | --- |
| [bicam](bicam.md) | Binary content-addressable memory. |
| [cc_fifo](cc_fifo.md) | Dual-clock asynchronous FIFO; arbitrary widths. |
| [cc_ram_fifo](cc_ram_fifo.md) | Dual-clock RAM-based FIFO with asymmetric ports. |
| [fifo](fifo.md) | Single-clock FIFO; arbitrary input and output width. |
| [packet_cc_fifo](packet_cc_fifo.md) | Dual-clock Avalon-ST packet FIFO (legacy style). |
| [packet_cc_ram_fifo](packet_cc_ram_fifo.md) | Dual-clock packet FIFO with RAM and mixed widths. |
| [packet_fifo](packet_fifo.md) | Single-clock Avalon-ST packet FIFO. |
| [ram](ram.md) | Single-port, single-clock RAM. |
| [ring_buffer](ring_buffer.md) | Circular buffer; overwrite oldest when full. |
| [rom](rom.md) | Read-only memory loaded from a hex init file. |
| [simple_dpram](simple_dpram.md) | Simple dual-port RAM (one write, one read); dual clock. |
| [simple_dpram_altera](simple_dpram_altera.md) | Vendor-style simple DPRAM for Intel/Altera inference. |
| [simple_dpram_be](simple_dpram_be.md) | `simple_dpram` with byte-enable on the write port. |
| [simple_dpram_xilinx](simple_dpram_xilinx.md) | Vendor-style simple DPRAM for Xilinx BRAM inference. |
| [true_dpram](true_dpram.md) | True dual-port RAM (two write and two read ports). |
| [true_dpram_altera](true_dpram_altera.md) | Vendor-style true DPRAM for Intel/Altera. |
| [true_dpram_xilinx](true_dpram_xilinx.md) | Vendor-style true DPRAM for Xilinx. |
