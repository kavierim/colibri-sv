// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_stream_to_wbm {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/stream_to_wbm.sv";
        verifPath = "sim/misc/stream_to_wbm_tb.sv";
    }
    part def stream_to_wbm {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_WB_ADDR_WIDTH : Integer = 32;
        attribute g_WB_DATA_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] src_data_o";
        out item src_valid_o;
        out item wb_adr_o;
        attribute wb_adr_o_sv : String = "logic [g_WB_ADDR_WIDTH-1:0] wb_adr_o";
        in item wb_dat_i;
        attribute wb_dat_i_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_i";
        out item wb_dat_o;
        attribute wb_dat_o_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_o";
        out item wb_we_o;
        out item wb_sel_o;
        attribute wb_sel_o_sv : String = "logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_o";
        out item wb_stb_o;
        out item wb_cyc_o;
        in item wb_ack_i;
        in item wb_err_i;
    }

    part streamToWbmUse : stream_to_wbm;
}
