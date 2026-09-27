// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_Mmap_fifo_Vhdl_if_rxfifo_csr {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/mmap_fifo/vhdl_if/rxfifo_csr.sv";
    }
    part def rxfifo_csr {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        in item clk;
        in item rst;
        in item s_cpuif_req;
        in item s_cpuif_req_is_wr;
        in item s_cpuif_addr;
        attribute s_cpuif_addr_sv : String = "logic [31:0] s_cpuif_addr";
        in item s_cpuif_wr_data;
        attribute s_cpuif_wr_data_sv : String = "logic [31:0] s_cpuif_wr_data";
        in item s_cpuif_wr_biten;
        attribute s_cpuif_wr_biten_sv : String = "logic [31:0] s_cpuif_wr_biten";
        out item s_cpuif_req_stall_wr;
        out item s_cpuif_req_stall_rd;
        out item s_cpuif_rd_ack;
        out item s_cpuif_rd_err;
        out item s_cpuif_rd_data;
        attribute s_cpuif_rd_data_sv : String = "logic [31:0] s_cpuif_rd_data";
        out item s_cpuif_wr_ack;
        out item s_cpuif_wr_err;
        in item hwif_in;
        attribute hwif_in_sv : String = "rxfifo_csr_pkg::rxfifo_csr_in_t hwif_in";
        out item hwif_out;
        attribute hwif_out_sv : String = "rxfifo_csr_pkg::rxfifo_csr_out_t hwif_out";
    }
}
