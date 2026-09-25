<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# I/O modules

UART, SPI, I2C, and JTAG streaming.

### Modules

- `i2c/i2c_controller` — I2C controller (master). Under Verilator, a released SCL is driven high. See the root README.
- `uart/uart` — UART transceiver.
- `uart/uart_rx` — UART receiver.
- `uart/uart_tx` — UART transmitter.
- `spi/spi_slave` — SPI slave.
- `spi/spi_master` — SPI master.
- `jtag/jtag_serdes` — JTAG-compatible duplex stream. See [jtag/readme.md](jtag/readme.md).

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `i2c_controller` | yes | `sim/io/i2c/i2c_controller_tb.sv` | no |
| `uart` | yes | `sim/io/uart/uart_tb.sv` | no |
| `spi_slave` | yes | `sim/io/spi/spi_slave_tb.sv` | no |
| `spi_master` | yes | `sim/io/spi/spi_master_tb.sv` | no |
| `jtag_serdes` | yes | `sim/io/jtag/jtag_serdes_tb.sv` | no |
