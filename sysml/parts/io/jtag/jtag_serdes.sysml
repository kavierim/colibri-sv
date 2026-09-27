// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Io_Jtag_jtag_serdes {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/io/jtag/jtag_serdes.sv";
        verifPath = "sim/io/jtag/jtag_serdes_tb.sv";
    }
    part def jtag_serdes {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 8;
        attribute g_REG_FALLING : Boolean = false;

        in item clk_ser_i;
        in item clk_par_i;
        in item shift_i;
        in item update_i;
        in item par_data_i;
        attribute par_data_i_sv : String = "logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_i";
        in item par_valid_i;
        out item par_ready_o;
        out item par_data_o;
        attribute par_data_o_sv : String = "logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_o";
        out item par_valid_o;
        in item ser_data_i;
        out item ser_data_o;
    }
}
