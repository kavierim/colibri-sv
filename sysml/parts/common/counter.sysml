// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_counter {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/common/counter.sv";
        verifPath = "sim/common/counter_tb.sv";
        fvPath = "fv/common/counter_sva.sv";
    }
    part def counter {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_MODULO : Integer = 0;
        attribute g_COUNTER_WIDTH : String = "colibri_utils::log2ceil(int'(g_MODULO))";

        in item clk_i;
        in item reset_i;
        in item enable_i;
        out item value_o;
        attribute value_o_sv : String = "logic [((g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1)-1:0] value_o";
        out item wraparound_o;

        satisfy requirement REQ_COUNTER_001;
        satisfy requirement REQ_COUNTER_002;
        satisfy requirement REQ_COUNTER_003;
        satisfy requirement REQ_COUNTER_004;
    }

    part counterUse : counter;
}
