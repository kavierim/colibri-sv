// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// misc SystemVerilog sources, dependency order.
// avst_fifo in interfaces.f leaves FIFO pins open. That warning is fatal
// under Verilator 5.020, so simulation file lists waive it here.
-Wno-PINMISSING
src/misc/mmap_fifo/vhdl_if/reg_utils.sv
src/misc/mmap_fifo/vhdl_if/mmap_fifo_csr_pkg.sv
src/misc/mmap_fifo/vhdl_if/txfifo_csr_pkg.sv
src/misc/mmap_fifo/vhdl_if/rxfifo_csr_pkg.sv
src/misc/mmap_fifo/vhdl_if/mmap_fifo_csr.sv
src/misc/mmap_fifo/vhdl_if/txfifo_csr.sv
src/misc/mmap_fifo/vhdl_if/rxfifo_csr.sv
src/misc/powerup_reset.sv
src/misc/heartbeat.sv
src/misc/frequency_counter.sv
src/misc/stream_to_wbm.sv
src/misc/be_add_lead.sv
src/misc/be_add_trail.sv
src/misc/be_remove_lead.sv
src/misc/be_remove_trail.sv
src/misc/mmap_fifo/mmap_fifo_tx.sv
src/misc/mmap_fifo/mmap_fifo_rx.sv
src/misc/mmap_fifo/mmap_fifo.sv
