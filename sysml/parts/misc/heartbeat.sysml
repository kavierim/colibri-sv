// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_heartbeat {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/heartbeat.sv";
        verifPath = "sim/misc/heartbeat_tb.sv";
    }
    part def heartbeat {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_BEAT_PERIOD : String = "1s";
        attribute g_CLK_PERIOD : String = "8ns";

        in item clk_i;
        in item reset_i;
        out item heartbeat_o;
    }

    part heartbeatUse : heartbeat;
}
