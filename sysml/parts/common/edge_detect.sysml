// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_edge_detect {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/edge_detect.sv";
        verifPath = "sim/common/edge_detect_tb.sv";
        fvPath = "fv/common/edge_detect_sva.sv";
    }
    part def edge_detect {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_RESET_VAL : Boolean = false;

        in item clk_i;
        in item data_i;
        out item pulse_o;
    }
}
