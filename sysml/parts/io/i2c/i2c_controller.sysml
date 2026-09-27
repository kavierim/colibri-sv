// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Io_I2c_i2c_controller {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/io/i2c/i2c_controller.sv";
        verifPath = "sim/io/i2c/i2c_controller_tb.sv";
    }
    part def i2c_controller {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_CLOCK_PERIOD : String = "time'(10ns)";
        attribute g_I2C_PERIOD : String = "time'(10us)";

        in item clk_i;
        in item reset_i;
        out item scl_o;
        in item sda_i;
        out item sda_o;
        out item sda_en_o;
        in item cmd_data_i;
        attribute cmd_data_i_sv : String = "logic [7:0] cmd_data_i";
        in item cmd_address_i;
        attribute cmd_address_i_sv : String = "logic [6:0] cmd_address_i";
        in item cmd_valid_i;
        out item cmd_error_o;
        out item cmd_ready_o;
        in item cmd_read_i;
        out item rd_data_o;
        attribute rd_data_o_sv : String = "logic [7:0] rd_data_o";
        out item rd_valid_o;
        in item rd_ready_i;
    }

    part i2cControllerUse : i2c_controller;
}
