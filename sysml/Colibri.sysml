// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
//
// Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.
//
// Library index. Nested packages re-export the part definitions.
// Stable URI: sysml://Colibri::<Domain>::<module>

package Colibri {
    doc /*
     * Nested re-export of part packages.
     * Example: sysml://Colibri::Common::counter
     */

    package Common {
        public import Colibri_Common_comparator::*;
        public import Colibri_Common_counter::*;
        public import Colibri_Common_debouncer::*;
        public import Colibri_Common_edge_detect::*;
        public import Colibri_Common_pipeline_buffer::*;
        public import Colibri_Common_skid_buffer::*;
        public import Colibri_Common_stream_buffer::*;
        public import Colibri_Common_stream_buffer_generic::*;
        public import Colibri_Common_synchro::*;
        public import Colibri_Common_synchro_generic::*;
        public import Colibri_Common_synchro_handshake::*;
        public import Colibri_Common_synchro_pulse::*;
        public import Colibri_Common_synchro_reset::*;
    }

    package Comms {
        public import Colibri_Comms_bert::*;
        public import Colibri_Comms_bit_shifter::*;
        public import Colibri_Comms_cc_gearbox::*;
        public import Colibri_Comms_crc::*;
        public import Colibri_Comms_descrambler::*;
        public import Colibri_Comms_gearbox::*;
        public import Colibri_Comms_scrambler::*;
        public import Colibri_Comms_slip_buffer::*;
    }

    package Endec {
        public import Colibri_Endec_decode_8b10b::*;
        public import Colibri_Endec_encode_8b10b::*;
        public import Colibri_Endec_rle_decode::*;
        public import Colibri_Endec_rle_encode::*;
    }

    package Interfaces_Memory_mapped {
        public import Colibri_Interfaces_Memory_mapped_wb_ram::*;
    }

    package Interfaces_Stream {
        public import Colibri_Interfaces_Stream_avst_cdc::*;
        public import Colibri_Interfaces_Stream_avst_fifo::*;
        public import Colibri_Interfaces_Stream_avst_ram_read::*;
        public import Colibri_Interfaces_Stream_avst_ram_read_unaligned::*;
        public import Colibri_Interfaces_Stream_avst_ram_write::*;
        public import Colibri_Interfaces_Stream_avst_ram_write_unaligned::*;
        public import Colibri_Interfaces_Stream_avst_to_axis::*;
        public import Colibri_Interfaces_Stream_avst_width_converter::*;
        public import Colibri_Interfaces_Stream_axis_to_avst::*;
    }

    package Io_I2c {
        public import Colibri_Io_I2c_i2c_controller::*;
    }

    package Io_Jtag {
        public import Colibri_Io_Jtag_jtag_serdes::*;
    }

    package Io_Spi {
        public import Colibri_Io_Spi_spi_master::*;
        public import Colibri_Io_Spi_spi_slave::*;
    }

    package Io_Uart {
        public import Colibri_Io_Uart_uart::*;
        public import Colibri_Io_Uart_uart_rx::*;
        public import Colibri_Io_Uart_uart_tx::*;
    }

    package Memory {
        public import Colibri_Memory_bicam::*;
        public import Colibri_Memory_cc_fifo::*;
        public import Colibri_Memory_cc_ram_fifo::*;
        public import Colibri_Memory_fifo::*;
        public import Colibri_Memory_packet_cc_fifo::*;
        public import Colibri_Memory_packet_cc_ram_fifo::*;
        public import Colibri_Memory_packet_fifo::*;
        public import Colibri_Memory_ram::*;
        public import Colibri_Memory_ring_buffer::*;
        public import Colibri_Memory_rom::*;
        public import Colibri_Memory_simple_dpram::*;
        public import Colibri_Memory_simple_dpram_be::*;
        public import Colibri_Memory_true_dpram::*;
    }

    package Memory_Optimized {
        public import Colibri_Memory_Optimized_simple_dpram_altera::*;
        public import Colibri_Memory_Optimized_simple_dpram_xilinx::*;
        public import Colibri_Memory_Optimized_true_dpram_altera::*;
        public import Colibri_Memory_Optimized_true_dpram_xilinx::*;
    }

    package Misc {
        public import Colibri_Misc_be_add_lead::*;
        public import Colibri_Misc_be_add_trail::*;
        public import Colibri_Misc_be_remove_lead::*;
        public import Colibri_Misc_be_remove_trail::*;
        public import Colibri_Misc_frequency_counter::*;
        public import Colibri_Misc_heartbeat::*;
        public import Colibri_Misc_powerup_reset::*;
        public import Colibri_Misc_stream_to_wbm::*;
    }

    package Misc_Mmap_fifo {
        public import Colibri_Misc_Mmap_fifo_mmap_fifo::*;
        public import Colibri_Misc_Mmap_fifo_mmap_fifo_rx::*;
        public import Colibri_Misc_Mmap_fifo_mmap_fifo_tx::*;
    }

    package Misc_Mmap_fifo_Vhdl_if {
        public import Colibri_Misc_Mmap_fifo_Vhdl_if_mmap_fifo_csr::*;
        public import Colibri_Misc_Mmap_fifo_Vhdl_if_rxfifo_csr::*;
        public import Colibri_Misc_Mmap_fifo_Vhdl_if_txfifo_csr::*;
    }

    package Packet {
        public import Colibri_Packet_broadcaster::*;
        public import Colibri_Packet_deinterleaver::*;
        public import Colibri_Packet_header_add::*;
        public import Colibri_Packet_header_remove::*;
        public import Colibri_Packet_interleaver::*;
        public import Colibri_Packet_packet_delay::*;
        public import Colibri_Packet_packet_join::*;
    }

    package Pipes {
        public import Colibri_Pipes_arbiter::*;
    }

    package Proto_Aurora_64b66b {
        public import Colibri_Proto_Aurora_64b66b_aurora_rx::*;
        public import Colibri_Proto_Aurora_64b66b_aurora_tx::*;
    }

    package Proto_Aurora_64b66b_Include {
        public import Colibri_Proto_Aurora_64b66b_Include_meta_buffer::*;
    }

    package Proto_Aurora_64b66b_Rx {
        public import Colibri_Proto_Aurora_64b66b_Rx_aurora_st_decoder::*;
        public import Colibri_Proto_Aurora_64b66b_Rx_block_sync_fsm::*;
        public import Colibri_Proto_Aurora_64b66b_Rx_cc_gearbox_up::*;
        public import Colibri_Proto_Aurora_64b66b_Rx_channel_bond::*;
        public import Colibri_Proto_Aurora_64b66b_Rx_gearbox_up::*;
    }

    package Proto_Aurora_64b66b_Tx {
        public import Colibri_Proto_Aurora_64b66b_Tx_aurora_st_encoder::*;
    }

}
