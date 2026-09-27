// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Comms_bert {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/comms/bert.sv";
        verifPath = "sim/comms/bert_tb.sv";
    }
    part def bert {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 32;
        attribute g_STATS_WIDTH : Integer = 64;
        attribute g_PRBS_POLY : String = "colibri_poly::c_PRBS_7";
        attribute g_DUT_DELAY : Integer = 1;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_valid_o;
        out item bit_errors_o;
        attribute bit_errors_o_sv : String = "logic [g_STATS_WIDTH-1:0] bit_errors_o";
        out item total_bits_o;
        attribute total_bits_o_sv : String = "logic [g_STATS_WIDTH-1:0] total_bits_o";
        out item word_errors_o;
        attribute word_errors_o_sv : String = "logic [g_STATS_WIDTH-1:0] word_errors_o";
        out item invalid_words_o;
        attribute invalid_words_o_sv : String = "logic [g_STATS_WIDTH-1:0] invalid_words_o";
    }
}
