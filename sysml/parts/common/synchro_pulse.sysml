// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Common_synchro_pulse {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/common/synchro_pulse.sv";
        verifPath = "sim/common/synchro_pulse_tb.sv";
    }
    part def synchro_pulse {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_STAGES : Integer = 2;

        in item src_clk_i;
        in item dst_clk_i;
        in item pulse_i;
        out item pulse_o;
    }

    part synchroPulseUse : synchro_pulse;
}
