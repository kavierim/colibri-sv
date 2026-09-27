// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Proto_Aurora_64b66b_Rx_aurora_st_decoder {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/proto/aurora_64b66b/rx/aurora_st_decoder.sv";
        verifPath = "sim/proto/aurora_64b66b/rx/aurora_st_decoder_tb.sv";
    }
    part def aurora_st_decoder {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_N_LANES : Integer = 1;
        attribute g_FIFO_WORDS : Integer = 8;
        attribute g_LANE_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_link_up_i;
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_sop_o;
        out item src_eop_o;
        out item src_valid_o;
        out item src_error_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] src_data_o";
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] src_empty_o";
    }

    part auroraStDecoderUse : aurora_st_decoder;
}
