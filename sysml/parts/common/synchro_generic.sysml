// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_synchro_generic {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/synchro_generic.sv";
        verifPath = "sim/common/synchro_generic_tb.sv";
    }
    part def synchro_generic {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute data_t : String = "logic [7:0]";
        attribute g_INIT_VALUE : String = "8'h00";
        attribute g_NUM_STAGES : Integer = 2;

        in item clk_i;
        in item reset_i;
        in item data_i;
        attribute data_i_sv : String = "data_t data_i";
        out item data_o;
        attribute data_o_sv : String = "data_t data_o";
    }
}
