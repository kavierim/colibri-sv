// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_comparator {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/comparator.sv";
        verifPath = "sim/common/comparator_tb.sv";
    }
    part def comparator {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 32;
        attribute g_IS_EQUAL : Boolean = false;

        in item clk_i;
        in item enable_i;
        in item a_i;
        attribute a_i_sv : String = "logic [g_DATA_WIDTH-1:0] a_i";
        in item b_i;
        attribute b_i_sv : String = "logic [g_DATA_WIDTH-1:0] b_i";
        out item a_gt_b_o;
    }
}
