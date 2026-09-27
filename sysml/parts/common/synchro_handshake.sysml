// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_synchro_handshake {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/synchro_handshake.sv";
        verifPath = "sim/common/synchro_handshake_tb.sv";
    }
    part def synchro_handshake {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 1;
        attribute g_NUM_STAGES : Integer = 2;

        in item snk_clk_i;
        in item src_clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_valid_o;
        in item src_ready_i;
    }

    part synchroHandshakeUse : synchro_handshake;
}
