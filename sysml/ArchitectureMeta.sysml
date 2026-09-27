// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
//
// Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

package ArchitectureMeta {
    doc /*
     * OKF trace metadata for Colibri SystemVerilog.
     * Requirement stubs and part definitions reference docs/modules via @OKFReference.
     */

    private import ScalarValues::*;

    metadata def OKFReference {
        doc /* Links a requirement stub to the markdown page that owns the SHALL text. */
        attribute docPath : String;
        attribute conceptId : String;
        attribute section : String;
    }

    metadata def ArtifactTrace {
        doc /* Paths from a part definition to its SystemVerilog sources. */
        attribute rtlPath : String;
        attribute verifPath : String;
        attribute fvPath : String;
    }
}
