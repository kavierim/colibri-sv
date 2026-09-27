// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Proto_Aurora_64b66b_Rx_gearbox_up {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/proto/aurora_64b66b/rx/gearbox_up.sv";
    }
    part def gearbox_up {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_INPUT_WIDTH : Integer;
        attribute g_OUTPUT_WIDTH : Integer;

        in item clk_i;
        in item reset_i;
        in item slip_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_INPUT_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_OUTPUT_WIDTH-1:0] src_data_o";
        out item src_valid_o;
    }

    part gearboxUpUse : gearbox_up;
}
