// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Proto_Aurora_64b66b_aurora_tx {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/proto/aurora_64b66b/aurora_tx.sv";
        verifPath = "sim/proto/aurora_64b66b/aurora_tx_tb.sv";
    }
    part def aurora_tx {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_N_LANES : Integer = 1;
        attribute g_LANE_WIDTH : Integer = 32;
        attribute g_GBX_BUF_SIZE : String = "16 * colibri_aurora_const::c_AURORA_ENC_WIDTH";
        attribute g_DISABLE_SCRAMBLER : Boolean = false;

        in item snk_clk_i;
        in item snk_reset_i;
        in item src_clk_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] snk_empty_i";
        out item src_valid_o;
        attribute src_valid_o_sv : String = "logic [g_N_LANES-1:0] src_valid_o";
        in item src_ready_i;
        attribute src_ready_i_sv : String = "logic [g_N_LANES-1:0] src_ready_i";
    }

    part auroraTxUse : aurora_tx;
}
