; TRS-80 Model II hardware includes
; Copyright 2012 Eric Smith <eric@brouhaha.com>
; 20-FEB-2012

; This program is free software: you can redistribute it and/or modify
; it under the terms of version 3 of the GNU General Public License as
; published by the Free Software Foundation.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.

; -------------------------------------------------------
; I/O registers on CPU card
; -------------------------------------------------------

ctc_reg		equ	0f0h	; four channels at consecutive port numbers

ctc_bit_reset	equ	1
ctc_bit_control	equ	0

ctc_reset	equ	002h	; (1 SHL ctc_bit_reset)
ctc_control	equ	001h	; (1 SHL ctc_bit_control)


sio_data_reg	equ	0f4h	; two channels at consecutive port numbers
sio_ctl_reg	equ	0f6h	; two channels at consecutive port numbers

sio_cmd_channel_reset	equ	018h


dma_reg		equ	0f8h

dma_cmd_reset	equ	0c3h


rom_en_reg	equ	0f9h

; -------------------------------------------------------
; I/O registers on display/keyboard card
; -------------------------------------------------------

kbd_data_reg	equ	0fch	; read only
crtc_addr_reg	equ	0fch	; write only
crtc_data_reg	equ	0fdh	; read/write
rtc_reg		equ	0feh	; clear RTC interrupt

; CRTC cursor start register bits 
crtc_cursor_bit_blink_enable	equ	6
crtc_cursor_bit_blink_slow	equ	5

crtc_cursor_blink_enable	equ	040h	; (1 SHL crtc_cursor_bit_blink_enable)
crtc_cursor_blink_slow		equ	020h	; (1 SHL crtc_cursor_bit_blink_slow)

nmi_ram_reg	equ	0ffh	; write only
nmi_ram_en_video_ram	equ	080h
nmi_ram_dis_video	equ	040h
nmi_ram_en_rtc_int	equ	020h
nmi_ram_en_40_col	equ	010h
; bank in bits 0-3

nmi_status_reg	equ	0ffh	; read only
nmi_status_bit_kbd_int		equ	7
nmi_status_bit_dis_video	equ	6
nmi_status_bit_rtc_int_en	equ	5
nmi_status_bit_40_col		equ	4
; bits 3-0 are undefined - can't read back the RAM bank!

; -------------------------------------------------------
; I/O registers on floppy/printer card
; -------------------------------------------------------

fdc_pio_reg		equ	0e0h

fdc_cmd_reg	equ	0e4h	; command register, write only
fdc_cmd_restore		equ	000h
fdc_cmd_seek		equ	010h
fdc_cmd_step		equ	020h
fdc_cmd_step_in		equ	040h
fdc_cmd_step_out	equ	060h
fdc_cmd_read_sector	equ	080h
fdc_cmd_write_sector	equ	0a0h
fdc_cmd_read_address	equ	0c0h
fdc_cmd_read_track	equ	0e0h
fdc_cmd_write_track	equ	0f0h
fdc_cmd_force_int	equ	0d0h

; additional flags OR'd into restore/seek/step commands
fdc_cmd_update_track	equ	010h	       ; step commands only
fdc_cmd_head_load	equ	008h
fdc_cmd_verify_track	equ	004h
fdc_cmd_step_rate_3ms	equ	000h
fdc_cmd_step_rate_6ms	equ	001h
fdc_cmd_step_rate_10ms	equ	002h
fdc_cmd_step_rate_15ms	equ	003h

; interrupt reason selection for force_int command
fdc_cmd_force_int_immediate	equ	008h
fdc_cmd_force_int_index		equ	004h
fdc_cmd_force_int_not_ready	equ	002h
fdc_cmd_force_int_ready		equ	001h


fdc_status_reg	equ	0e4h	; status register, read only

; FDC status bits for all commands:
fdc_status_bit_busy		equ	0
fdc_status_bit_crc_err		equ	3
fdc_status_bit_write_protected	equ	6
fdc_status_bit_not_ready	equ	7

fdc_status_busy			equ	001h
fdc_status_crc_err		equ	008h
fdc_status_write_protected	equ	040h
fdc_status_not_ready		equ	080h

; FDC status bits for restore/seek/step commands:
fdc_status_bit_index		equ	1
fdc_status_bit_track_zero	equ	2
fdc_status_bit_seek_err		equ	4
fdc_status_bit_head_loaded	equ	5

fdc_status_index		equ	002h
fdc_status_track_zero		equ	004h
fdc_status_seek_err		equ	010h
fdc_status_head_loaded		equ	020h

; FDC status bits for read/write commands:
fdc_status_bit_drq    		equ	1
fdc_status_bit_lost_data	equ	2
fdc_status_bit_rec_not_found	equ	4
fdc_status_bit_deleted_data	equ	5	; read sector only
fdc_status_bit_write_fault	equ	5	; write sector/track only

fdc_status_drq			equ	002h
fdc_status_lost_data		equ	004h
fdc_status_rec_not_found	equ	010h
fdc_status_deleted_data		equ	020h	; read sector only
fdc_status_write_fault		equ	020h	; write sector/track only

fdc_track_reg	equ	0e5h
fdc_sector_reg	equ	0e6h
fdc_data_reg	equ	0e7h
fdc_reset_reg	equ	0e8h	; write only, late board revisions

fdc_select_reg	equ	0efh	; write only

; bit masks in select register
; 3-0 select drive, active low - MUST set at least three of these high

fdc_sel_mfm	equ	080h
fdc_sel_side_0	equ	040h
fdc_sel_dr_none	equ	00fh
fdc_sel_dr_0	equ	00eh
fdc_sel_dr_1	equ	00dh
fdc_sel_dr_2	equ	00bh
fdc_sel_dr_3	equ	007h

; -------------------------------------------------------
; I/O registers on hard disk adapter and controller cards
; -------------------------------------------------------

; For the 8MB drive, the write protect register, control register,
; and drive ID registers are on the adapter.  For other external
; drives, a different host adapter is necessary, and the write protect
; register, and control register are on the controller.
hdc_write_protect_reg	equ	0c0h	; read only
hdc_control_reg		equ	0c1h
hdc_drive_id_45		equ	0c2h	; DIP switches, low nib 4, high nib 5
hdc_drive_id_67		equ	0c3h	; DIP switches, low nib 6, high nib 7

hdc_data_reg		equ	0c8h
hdc_error_reg		equ	0c9h	; read only
hdc_write_precomp_reg	equ	0c9h	; write only
hdc_sector_count_reg	equ	0cah
hdc_sector_number_reg	equ	0cbh
hdc_cylinder_low_reg	equ	0cch
hdc_cylinder_high_reg	equ	0cdh
hdc_size_drive_head_reg	equ	0ceh
hdc_command_reg		equ	0cfh	; write only
hdc_status_reg		equ	0cfh	; read only

; hdc_write_protect_reg
; An extra chip select on pin 46 of the host interface is used to
; select this register for reading. This is not present on normal
; WD100x controllers.  See section C11-C12 of schematic in
; 8MB drive service manual.  Pin 5 of the ST506 interface radial
; data connectors is used for the active-low write protect signal.
; Note that the schematic of the 5MB controller shows the bits of the
; write protect register in the reverse order of those of the 8MB
; controller; possibly an error in the schematic? Unconfirmed.
hdc_write_protect_bit_intrq	equ	7	; interrupt request
hdc_write_protect_bit_hdwpl	equ	6	; write protect error, latched
; bits 5-4 are unused
; bits 3-0 are hardware write protect bits from the individual drives

; hdc_control_reg
; bits 7, 5 unused
hdc_control_soft_int		equ	040h
hdc_control_soft_reset		equ	010h
hdc_control_deven		equ	008h
hdc_control_wait_enable		equ	004h
hdc_control_intrq_enable	equ	002h
hdc_control_dma_enable		equ	001h

; hdc_error_reg:
hdc_error_bit_bad_block			equ	7
hdc_error_bit_crc_data			equ	6
hdc_error_bit_crc_id			equ	5
hdc_error_bit_id_not_found		equ	4
hdc_error_bit_aborted_cmd		equ	2
hdc_error_bit_track_0_not_found		equ	1
hdc_error_bit_data_mark_not_found	equ	0

; hdc_size_drive_head_reg:
hdc_sdh_sect_size_256	equ	000h
hdc_sdh_sect_size_512	equ	020h
hdc_sdh_sect_size_128	equ	060h

; hdc_command_reg:
hdc_command_restore		equ	010h	; logical OR with step rate
hdc_command_seek		equ	070h	; logical OR with step rate
hdc_command_read_sector_pio	equ	020h
hdc_command_read_sector_dma	equ	028h
hdc_command_write_sector	equ	030h
hdc_command_format_track	equ	050h

hdc_command_step_rate_1p5_ms	equ	003h
hdc_command_step_rate_7p5_ms	equ	00fh

; hdc_status_reg:
hdc_status_bit_busy			equ	7
hdc_status_bit_ready			equ	6
hdc_status_bit_write_fault		equ	5
hdc_status_bit_seek_complete		equ	4
hdc_status_bit_data_request		equ	3
hdc_status_bit_command_in_progress	equ	1	; WD1010, WD2010 only
hdc_status_bit_error			equ	0


; -------------------------------------------------------
; keycodes
; -------------------------------------------------------

key_break	equ	003h
key_escape	equ	01bh

; -------------------------------------------------------
; display
; -------------------------------------------------------

inverse		equ	080h

; -------------------------------------------------------
; memory map
; -------------------------------------------------------

rom_start	equ	00000h
max_rom_size	equ	01000h		; ROM is only 2K, but 4K is reserved

ram_start	equ	00000h
ram_size	equ	08000h		; assume 32K RAM, could be 64K

screen_start	equ	0f800h
screen_size	equ	00800h

fd_load_addr	equ	00e00h		; first 512 bytes overlaid by ROM space
fd_load_sector_size	equ	128	; sector size of boot track
fd_load_sector_count	equ	26	; one full track
fd_retry_count		equ	40


hd_load_addr	equ	00000h		; first overlaid by ROM space
			; we MUST load at least 9 sectors, because we can't
			; detect the end signature below 1000 since the
			; RAM from 0000-0fff is overlaid by this boot ROM

fd_stack_init	equ	02000h
hd_stack_init	equ	02800h		; needs to be higher since HD
					; bootstrap can be larger

