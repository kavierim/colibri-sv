// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Comms_cc_gearbox {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/comms/cc_gearbox.sv";
    }
    part def cc_gearbox {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_INPUT_WIDTH : Integer = 8;
        attribute g_OUTPUT_WIDTH : Integer = 10;
        attribute g_BUFFER_WORDS : Integer = 6;
        attribute g_USE_BLOCK_RAM : Boolean = false;
        attribute g_IMPL_STYLE : String = "colibri_utils::get_compiler()";

        in item snk_clk_i;
        in item snk_reset_i;
        in item src_clk_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_INPUT_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_OUTPUT_WIDTH-1:0] src_data_o";
        out item src_valid_o;
        in item src_ready_i;
    }

    part ccGearboxUse : cc_gearbox;
}
