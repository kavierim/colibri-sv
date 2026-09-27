// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Proto_Aurora_64b66b_Rx_block_sync_fsm {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/proto/aurora_64b66b/rx/block_sync_fsm.sv";
    }
    part def block_sync_fsm {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_SH_CNT_MAX : Integer = 64;
        attribute g_SH_INVALID_CNT_MAX : Integer = 16;
        attribute g_SLIP_CNT_MAX : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_meta_i;
        attribute snk_meta_i_sv : String = "logic [1:0] snk_meta_i";
        in item snk_valid_i;
        out item snk_slip_o;
        out item src_sync_o;
    }
}
