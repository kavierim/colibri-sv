// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_frequency_counter {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/frequency_counter.sv";
        verifPath = "sim/misc/frequency_counter_tb.sv";
    }
    part def frequency_counter {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_CLK_REF_FREQ_HZ : String = "100_000_000";
        attribute g_NUM_CLOCKS : Integer = 1;
        attribute g_DATA_WIDTH : Integer = 32;
        attribute g_SAMPLE_FREQ_HZ : Integer = 1;

        in item clk_ref_i;
        in item reset_i;
        in item clk_meas_i;
        attribute clk_meas_i_sv : String = "logic [g_NUM_CLOCKS-1:0] clk_meas_i";
        out item freq_valid_o;
        attribute freq_valid_o_sv : String = "logic [g_NUM_CLOCKS-1:0] freq_valid_o";
    }

    part frequencyCounterUse : frequency_counter;
}
