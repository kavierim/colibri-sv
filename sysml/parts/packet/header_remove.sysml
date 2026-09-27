// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Packet_header_remove {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/packet/header_remove.sv";
        verifPath = "sim/packet/header_remove_tb.sv";
        fvPath = "fv/packet/header_remove_sva.sv";
    }
    part def header_remove {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_HEADER_BYTES : Integer = 14;
        attribute g_DATA_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [c_DATA_W-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [c_EMPTY_W-1:0] snk_empty_i";
        out item src_sop_o;
        out item src_eop_o;
        out item src_valid_o;
        in item src_ready_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [c_DATA_W-1:0] src_data_o";
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [c_EMPTY_W-1:0] src_empty_o";
        out item src_header_o;
        attribute src_header_o_sv : String = "logic [c_HDR_BITS-1:0] src_header_o";
        satisfy requirement REQ_HEADER_REMOVE_001;
        satisfy requirement REQ_HEADER_REMOVE_002;
        satisfy requirement REQ_HEADER_REMOVE_003;

    }

    part headerRemoveUse : header_remove;
}
