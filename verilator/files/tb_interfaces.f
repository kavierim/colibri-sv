// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Interface testbenches and bound SVA. Paths are relative to colibri_sv.

sim/interfaces/stream/avst_cdc_tb.sv
sim/interfaces/stream/avst_fifo_tb.sv
sim/interfaces/stream/avst_to_axis_tb.sv
sim/interfaces/stream/avst_width_converter_tb.sv
sim/interfaces/stream/axis_to_avst_tb.sv
sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv
sim/interfaces/stream/avst_ram_be_tb/avst_ram_be_tb.sv
sim/interfaces/stream/avst_ram_read_unaligned_tb/avst_ram_read_unaligned_tb.sv
sim/interfaces/stream/avst_ram_write_unaligned_tb.sv
sim/interfaces/memory_mapped/wb_ram_tb.sv

fv/interfaces/stream/avst_ram_read_sva.sv
fv/interfaces/stream/avst_ram_write_sva.sv
fv/interfaces/stream/avst_ram_write_unaligned_sva.sv
fv/interfaces/stream/avst_to_axis_sva.sv
fv/interfaces/stream/axis_to_avst_sva.sv
