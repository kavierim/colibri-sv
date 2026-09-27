// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Misc_powerup_reset {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/misc/powerup_reset.sv";
        verifPath = "sim/misc/powerup_reset_tb.sv";
    }
    part def powerup_reset {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_POLARITY : Boolean = true;
        attribute g_DURATION : Integer = 16;

        in item clk_i;
        in item reset_ext_i;
        out item reset_o;
    }
}
