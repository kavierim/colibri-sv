// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Endec_encode_8b10b {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/endec/encode_8b10b.sv";
    }
    part def encode_8b10b {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        in item clk_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [7:0] snk_data_i";
        in item snk_valid_i;
        in item snk_control_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [9:0] src_data_o";
        out item src_valid_o;
    }
}
