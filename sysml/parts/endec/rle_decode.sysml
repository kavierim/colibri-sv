// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Endec_rle_decode {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/endec/rle_decode.sv";
        verifPath = "sim/endec/rle_decode_tb.sv";
        fvPath = "fv/endec/rle_decode_sva.sv";
    }
    part def rle_decode {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_WORD_WIDTH : Integer = 16;
        attribute g_COUNT_WIDTH : Integer = 3;

        in item clk_i;
        in item reset_i;
        out item snk_ready_o;
        in item snk_valid_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0] snk_data_i";
        in item src_ready_i;
        out item src_valid_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_WORD_WIDTH-1:0] src_data_o";
        satisfy requirement REQ_RLE_DECODE_001;
        satisfy requirement REQ_RLE_DECODE_002;
        satisfy requirement REQ_RLE_DECODE_003;
        satisfy requirement REQ_RLE_DECODE_004;

    }

    part rleDecodeUse : rle_decode;
}
