# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
#
# Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

# Comms testbenches and SVA. Paths are relative to colibri_sv.
# Each testbench is a separate --top. Do not pass this file on one Verilator
# command together with every bench; that would elaborate every top at once.

fv/comms/gearbox_up_sva.sv
fv/comms/gearbox_down_sva.sv
sim/comms/bit_shifter_tb.sv
sim/comms/bert_tb.sv
sim/comms/prbs_tb.sv
sim/comms/scrambler_tb.sv
sim/comms/slip_buffer_tb.sv
sim/comms/gearbox_up_tb.sv
sim/comms/gearbox_down_tb.sv
sim/comms/gearbox_loopback_tb.sv
sim/comms/cc_gearbox_up_tb.sv
sim/comms/cc_gearbox_down_tb.sv
sim/comms/cc_gearbox_up_thr_tb.sv
sim/comms/cc_gearbox_down_thr_tb.sv
sim/comms/cc_gearbox_loopback_tb.sv
sim/comms/crc_tb.sv
