// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Stream_avst_to_axis {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/stream/avst_to_axis.sv";
        verifPath = "sim/interfaces/stream/avst_to_axis_tb.sv";
        fvPath = "fv/interfaces/stream/avst_to_axis_sva.sv";
    }
    part def avst_to_axis {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 32;
        attribute g_AVST_ENDIANNESS : String = "colibri_types::BIG";
        attribute g_ADD_REGISTERS : Boolean = true;

        in item clk_i;
        in item reset_i;
        out item snk_ready_o;
        in item snk_valid_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [c_EMPTY_W-1:0] snk_empty_i";
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item src_tready_i;
        out item src_tvalid_o;
        out item src_tlast_o;
        out item src_tkeep_o;
        attribute src_tkeep_o_sv : String = "logic [c_KEEP_W-1:0] src_tkeep_o";
        out item src_tdata_o;
        attribute src_tdata_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_tdata_o";
    }

    part avstToAxisUse : avst_to_axis;
}
