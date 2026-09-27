// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Stream_axis_to_avst {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/stream/axis_to_avst.sv";
        verifPath = "sim/interfaces/stream/axis_to_avst_tb.sv";
        fvPath = "fv/interfaces/stream/axis_to_avst_sva.sv";
    }
    part def axis_to_avst {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 32;
        attribute g_AVST_ENDIANNESS : String = "colibri_types::BIG";
        attribute g_ADD_REGISTERS : Boolean = true;

        in item clk_i;
        in item reset_i;
        out item snk_tready_o;
        in item snk_tvalid_i;
        in item snk_tlast_i;
        in item snk_tkeep_i;
        attribute snk_tkeep_i_sv : String = "logic [c_KEEP_W-1:0] snk_tkeep_i";
        in item snk_tdata_i;
        attribute snk_tdata_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_tdata_i";
        in item src_ready_i;
        out item src_valid_o;
        out item src_sop_o;
        out item src_eop_o;
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [c_EMPTY_W-1:0] src_empty_o";
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
    }

    part axisToAvstUse : axis_to_avst;
}
