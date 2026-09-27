// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Pipes_arbiter {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/pipes/arbiter.sv";
        verifPath = "sim/pipes/arbiter_tb.sv";
        fvPath = "fv/pipes/arbiter_sva.sv";
    }
    part def arbiter {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_INPUTS : Integer = 4;

        in item clk_i;
        in item reset_i;
        in item requests_i;
        attribute requests_i_sv : String = "logic [g_NUM_INPUTS-1:0] requests_i";
        out item grants_o;
        attribute grants_o_sv : String = "logic [g_NUM_INPUTS-1:0] grants_o";
        satisfy requirement REQ_ARBITER_001;
        satisfy requirement REQ_ARBITER_002;
        satisfy requirement REQ_ARBITER_003;
        satisfy requirement REQ_ARBITER_004;
        satisfy requirement REQ_ARBITER_005;
        satisfy requirement REQ_ARBITER_006;

    }

    part arbiterUse : arbiter;
}
