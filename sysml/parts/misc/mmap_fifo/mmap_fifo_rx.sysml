// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_Mmap_fifo_mmap_fifo_rx {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/mmap_fifo/mmap_fifo_rx.sv";
    }
    part def mmap_fifo_rx {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_WB_ADDR_WIDTH : Integer = 32;
        attribute g_WB_DATA_WIDTH : Integer = 32;
        attribute g_STREAM_DATA_WIDTH : String = "g_WB_DATA_WIDTH";
        attribute g_NUM_WORDS : Integer = 16;
        attribute g_NUM_CH : Integer = 4;
        attribute g_USE_BLOCK_RAM : Boolean = false;
        attribute g_IMPL_STYLE : String = "colibri_utils::get_compiler()";

        in item reset_i;
        in item clk_i;
        out item snk_ready_o;
        in item snk_valid_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] snk_empty_i";
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_STREAM_DATA_WIDTH-1:0] snk_data_i";
        in item snk_chan_i;
        attribute snk_chan_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] snk_chan_i";
        in item wb_clk_i;
        in item wb_adr_i;
        attribute wb_adr_i_sv : String = "logic [g_WB_ADDR_WIDTH-1:0] wb_adr_i";
        out item wb_dat_o;
        attribute wb_dat_o_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_o";
        in item wb_dat_i;
        attribute wb_dat_i_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_i";
        in item wb_we_i;
        in item wb_sel_i;
        attribute wb_sel_i_sv : String = "logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_i";
        in item wb_stb_i;
        in item wb_cyc_i;
        out item wb_ack_o;
        out item wb_err_o;
        out item intr_o;
    }
}
