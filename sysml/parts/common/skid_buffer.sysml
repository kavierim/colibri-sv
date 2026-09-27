// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_skid_buffer {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/skid_buffer.sv";
        verifPath = "sim/common/skid_buffer_tb.sv";
        fvPath = "fv/common/skid_buffer_sva.sv";
    }
    part def skid_buffer {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i";
        in item snk_keep_i;
        attribute snk_keep_i_sv : String = "logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] snk_keep_i";
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o";
        out item src_keep_o;
        attribute src_keep_o_sv : String = "logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] src_keep_o";
        out item src_sop_o;
        out item src_eop_o;
        out item src_valid_o;
        in item src_ready_i;
    }

    part skidBufferUse : skid_buffer;
}
