// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_debouncer {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/debouncer.sv";
        verifPath = "sim/common/debouncer_tb.sv";
        fvPath = "fv/common/debouncer_sva.sv";
    }
    part def debouncer {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_RESET_VAL : Boolean = false;
        attribute g_DEBOUNCE_TIME : String = "10ms";
        attribute g_CLOCK_PERIOD : String = "10ns";

        in item clk_i;
        in item reset_i;
        in item data_i;
        attribute data_i_sv : String = "logic [$bits(g_RESET_VAL)-1:0] data_i";
        out item data_o;
        attribute data_o_sv : String = "logic [$bits(g_RESET_VAL)-1:0] data_o";
    }

    part debouncerUse : debouncer;
}
