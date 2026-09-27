// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Comms_descrambler {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/comms/descrambler.sv";
    }
    part def descrambler {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 64;
        attribute g_SCRAMBLER_POLY : String = "colibri_poly::c_SCR_10GBASE";
        attribute g_INIT_VAL : String = "$bits(g_SCRAMBLER_POLY)'({4096{2'b01}})";
        attribute g_INVERT_IN : Boolean = true;
        attribute g_INVERT_OUT : Boolean = true;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_valid_o;
        in item src_ready_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
    }

    part descramblerUse : descrambler;
}
