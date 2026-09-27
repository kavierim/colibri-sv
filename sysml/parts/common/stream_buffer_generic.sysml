// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_stream_buffer_generic {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/stream_buffer_generic.sv";
        verifPath = "sim/common/stream_buffer_generic_tb.sv";
    }
    part def stream_buffer_generic {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute data_t : String = "logic [7:0]";
        attribute g_REGISTER_DATAPATH : Boolean = false;

        in item reset_i;
        in item clk_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "data_t snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "data_t src_data_o";
        in item src_ready_i;
        out item src_valid_o;
    }

    part streamBufferGenericUse : stream_buffer_generic;
}
