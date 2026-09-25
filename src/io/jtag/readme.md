<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# JTAG streaming interface

`jtag_serdes.sv` talks to a design over the usual JTAG port.

## How to use

FPGA tools provide JTAG primitives with USER boundary-scan registers. This module sits on the data register of one of those primitives and exchanges a parallel word with the design. Together with [`stream_to_wbm`](../../misc/stream_to_wbm.sv) it can reach memory-mapped registers over JTAG.

The vendor primitives below are not part of this port. The `jtag_serdes` instantiation is SystemVerilog.

| Signal | Description |
| --- | --- |
| `drck` / `clkdruser` | Gated clock, active while the JTAG FSM is in CAPTURE or SHIFT. On Altera it is active only when the USERx register is selected. |
| `sel` / `usr1user` | USER register select. Active-high on Xilinx. On Altera, `0` is USER0 and `1` is USER1. |
| `shift` / `shiftuser` | FSM SHIFT state. |
| `update` / `updateuser` | FSM UPDATE state. |
| `tdi` / `tdiutap` | Test data in, sampled on the rising edge. |
| `tdo` / `tdouser` | Test data out, sampled on the falling edge. |

### AMD/Xilinx Vivado

Xilinx provides the BSCANE2 primitive on 7-series, UltraScale, and UltraScale+ devices. Up to four instances use the four [USERx instructions](https://docs.amd.com/r/en-US/ug570-ultrascale-configuration/Instruction-Register):

| Register | IR code (5:0) |
| --- | --- |
| USER1 | 0x02 |
| USER2 | 0x03 |
| USER3 | 0x22 |
| USER4 | 0x23 |

Connect the primitive's DR pins to `jtag_serdes`:

```systemverilog
jtag_serdes #(
  .g_DATA_WIDTH(40)
) jtag_serdes_inst (
  .clk_ser_i  (gck),
  .clk_par_i  (sys_clk),
  .shift_i    (shift & sel),
  .update_i   (update & sel),
  .par_data_i  (ps_data),
  .par_valid_i (ps_valid),
  .par_ready_o (),
  .par_data_o  (sp_data),
  .par_valid_o (sp_valid),
  .ser_data_i (tdi),
  .ser_data_o (tdo)
);
```

`gck`, `sel`, `shift`, `update`, `tdi`, and `tdo` come from BSCANE2 (`JTAG_CHAIN` selects USER1..USER4).

### Altera/Intel Quartus

Altera JTAG primitives are family-specific and have two USER registers:

| Register | IR code (9:0) |
| --- | --- |
| USER0 | 0x00C |
| USER1 | 0x00E |

Declarations live under `<QUARTUS_ROOTDIR>/libraries/vhdl/<FAB_NODE>/<LIBNAME>.vhd`. On Arria 10 the primitive is `twentynm_jtag`. Wire `clkdruser`, `usr1user`, `shiftuser`, `updateuser`, `tdiutap`, and `tdouser` to the same `jtag_serdes` ports as above (`shift_i` and `update_i` are `shift & sel` and `update & sel`).

## Talking to the core

OpenOCD can shift the data register from the command line.

- Configure the adapter and a TAP with the right IR length (6 for Xilinx, 10 for Altera).
- Select the USERx instruction: `irscan <tap> <IR_CODE>` (for example `irscan xcau25.tap 0x23`).
- Shift data: `drscan <tap> <nbits> <hex>` (for example `drscan xcau25.tap 40 0x0102030405`). `drscan` returns the bits shifted out of the core.

## References

- [Tom Verbeure, Intel JTAG primitive](https://tomverbeure.github.io/2021/10/30/Intel-JTAG-Primitive.html)
- [BSCANE2](https://docs.amd.com/r/en-US/ug570-ultrascale-configuration/BSCANE2)
- [urJtag FJMEM](https://github.com/shuckc/urjtag/tree/master/urjtag/extra/fjmem)
