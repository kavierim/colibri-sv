// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Proto_Aurora_64b66b_Rx_channel_bond {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/proto/aurora_64b66b/rx/channel_bond.sv";
    }
    part def channel_bond {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_N_LANES : Integer = 1;
        attribute g_BUF_SIZE : Integer = 8;
        attribute g_REGISTER_OUT : Boolean = true;

        in item clk_i;
        in item reset_i;
        in item snk_valid_i;
        attribute snk_valid_i_sv : String = "logic [g_N_LANES-1:0] snk_valid_i";
        out item src_valid_o;
        attribute src_valid_o_sv : String = "logic [g_N_LANES-1:0] src_valid_o";
        out item src_bond_o;
    }

    part channelBondUse : channel_bond;
}
