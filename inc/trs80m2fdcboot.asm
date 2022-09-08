; code: language=asm-collection tabSize=8

.include "inc/m2.inc"

boot_os:
	ld	sp,hd_stack_init

	ld	d,200
clear_keyboard_loop:
	in	a,(nmi_status_reg)
	bit	nmi_status_bit_kbd_int,a
	jr	z,clear_kbd_no_key
	in	a,(kbd_data_reg)
clear_kbd_no_key:
	ld	bc,128
	call	delay_bc		; delay by 3333 t-states (833.25us @ 4MHz)
	dec	d
	jr	nz,clear_keyboard_loop

; reset HDC and check for drive presence
	xor	a
	out	(hdc_control_reg),a
	ld	a,hdc_control_soft_reset
	out	(hdc_control_reg),a

; Earlier versions of the boot ROM didn't enable interrupt and DMA.  Not sure
; why this is a good idea.
	ld	a,hdc_control_deven+hdc_control_wait_enable+hdc_control_intrq_enable+hdc_control_dma_enable
	out	(hdc_control_reg),a

	in	a,(hdc_drive_id_45)	; check ID of drive 4
	and	$0f
	jp	z,floppy_boot		;   zero, no drive 4

hd_boot:
	ld	d,21	; loop up to 21 times waiting for controller ready
hd_wait_ready:
	call	delay_bc		; delay by 551 t-states (137.75us @4MHz)

; Check if controller is ready
; POSSIBLE BUG!  WD1000 documentation says that no other bits or registers
; are valid if the busy bit of the status register is set, so it should
; be checked here.
	in	a,(hdc_status_reg)
	bit	hdc_status_bit_ready,a
	jr	nz,hd_is_ready

; HD not ready. Is the user trying to abort the HD boot?
	call	check_escape_key	; escape key pressed?
	jp	z,floppy_boot		;   yes, skip HD and boot FD
	dec	d
	jr	nz,hd_wait_ready
	jr	ht_err

hd_is_ready:
; try to seek to track 5
	ld	a,hdc_sdh_sect_size_512
	out	(hdc_size_drive_head_reg),a
	xor	a
	out	(hdc_cylinder_high_reg),a
	ld	a,5
	out	(hdc_cylinder_low_reg),a
	ld	a,hdc_command_seek+hdc_command_step_rate_7p5_ms
	out	(hdc_command_reg),a
	call	hd_wait_not_busy
	
; restore
	ld	a,hdc_command_restore+hdc_command_step_rate_7p5_ms
	out	(hdc_command_reg),a
	call	hd_wait_not_busy
	jr	nz,hd_tr0_not_found

	ld	hl,hd_load_addr	; start loading HD sectors into memory at 0000
			; if we load 17 sectors, they'll occupy 0000-21ff
			; we MUST load at least 9 sectors, because we can't
			; detect the end signature below 1000 since the
			; RAM from 0000-0fff is overlaid by this boot ROM
	ld	bc,(1*256)+hdc_sector_number_reg	; start w/ sector 1

hd_read_sector:
	ld	d,h		; copy HL into DE for signature check
	ld	e,l
	out	(c),b		; write sector register
	ld	a,hdc_command_read_sector_pio
	out	(hdc_command_reg),a
	call	hd_wait_not_busy
	jr	nz,hd_err_from_err_reg

hd_wait_for_drq:
	in	a,(hdc_status_reg)
	bit	hdc_status_bit_data_request,a
	jr	z,hd_wait_for_drq
	call	check_escape_key
	jr	z,floppy_boot

	inc	b		; advance sector number
	push	bc		; and save it for next iteration
	ld	a,2
	ld	bc,(0*256)+hdc_data_reg
	inir
	inir

	push	hl			; check for end boot sig
	ld	hl,hd_boot_end_sig
	ld	b,hd_boot_end_sig_len
	call	check_disk_signature
	pop	hl
	pop	bc
	jr	nz,hd_read_sector	; end boot sig not found, continue read

	ld	bc,0
	call	delay_bc		; delay by 1,703,915 t-states (0.42597875 sec @ 4MHz)
	call	check_escape_key
	jr	z,floppy_boot

	xor	a			; disable HD
	out	(hdc_control_reg),a

	ex	de,hl			; jump to location after end sig
	jp	(hl)

ht_err:
	ld	e,'T'
	jr	hd_boot_err

hd_err_from_err_reg:
	; bit	hdc_error_bit_crc_data,a
	; ld	e,'C'
	; jr	nz,hd_boot_err

	; bit	hdc_error_bit_crc_id,a
	; ld	e,'I'
	; jr	nz,hd_boot_err

	; bit	hdc_error_bit_id_not_found,a
	; ld	e,'N'
	; jr	nz,hd_boot_err

	; bit	hdc_error_bit_aborted_cmd,a
	; ld	e,'A'
	; jr	nz,hd_boot_err

	; bit	hdc_error_bit_track_0_not_found,a
hd_tr0_not_found:
	; ld	e,'0'
	; jr	nz,hd_boot_err

	; bit	hdc_error_bit_data_mark_not_found,a
	; ld	e,'M'
	; jr	nz,hd_boot_err

	; ld	e,'D'	; other error

	ld	e,'D'	; don't decode error names

hd_boot_err:
	ld	d,'H'

boot_err:
	push	hl
	call	con_clear
	pop	hl

	ld	hl,$fb9a
	ld	(hl),d
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),' '

	ld	hl,boot_err_msg
	ld	de,$fb8e
	ld	bc,boot_err_msg_len
	ldir

wait_for_escape_key
	call	check_escape_key
	jr	nz,wait_for_escape_key





floppy_boot:
	ld	sp,fd_stack_init	; etablish a stack
	xor	a
	out	(hdc_control_reg),a

; select drive 0, side 0
	; ld	a,fdc_sel_side_0+fdc_sel_dr_0
	; out	(fdc_select_reg),a

; ; display "insert disk" message
; 	ld	hl,insert_disk_msg
; 	ld	de,$fb8e
; 	ld	bc,insert_disk_msg_len
; 	ldir

fd_wait_for_ready:
	ld	a,fdc_sel_side_0+fdc_sel_dr_0
	out	(fdc_select_reg),a

	call	terminate_fdc_cmd
	bit	7,a
	jr	nz,fd_wait_for_ready

	call	terminate_fdc_cmd

; step inward (toward 77) five tracks
	ld	b,5				; step in count
fd_step_in_loop:
	ld	a,fdc_cmd_step_in+fdc_cmd_update_track+fdc_cmd_head_load+fdc_cmd_step_rate_15ms
	out	(fdc_cmd_reg),a

; wait a while
	push	bc
	ld	bc,3075
	call	delay_bc			; delay by 79,955 t-states (0.0215275 sec @ 4MHz)
	pop	bc

	djnz	fd_step_in_loop
		
	call	terminate_fdc_cmd
fd_restore:
	ld	a,fdc_cmd_restore+fdc_cmd_head_load+fdc_cmd_step_rate_15ms
	out	(fdc_cmd_reg),a

; wait a long time, 8 times the maximum for delay_bc subroutine
; BC value at this point is left over from lddr
	ld	d,7
fd_restore_wait:	
	call	delay_bc			; delay by 206 t-states (0.01998875 sec @ 4MHz)
	dec	d
	jr	nz,fd_restore_wait

; check all the various error bits of the FDC status
	in	a,(fdc_status_reg)
	push	af
	xor	fdc_status_track_zero	; error when zero
	; and	fdc_status_seek_err+fdc_status_track_zero+fdc_status_busy
	; jr	nz,dc_err
	; pop	af
	; bit	fdc_status_bit_not_ready,a
	; jr	nz,d0_err
	; bit	fdc_status_bit_crc_err,a
	; jr	nz,sc_err
	and	fdc_status_seek_err+fdc_status_track_zero+fdc_status_busy+fdc_status_bit_not_ready+fdc_status_bit_crc_err
	jr	nz,ld_err

; read the bootstrap code from track zero of the floppy (single density)
fd_read_boot:
	ld	hl,fd_load_addr	; HL = buffer
	ld	de,(fd_load_sector_count*256)+fd_retry_count
						; D = sector count
						; E = retry count
	ld	bc,(fd_load_sector_size*256)+1	; B = sector size (128)
						; C = sector number (1)

	ld	a,fdc_cmd_read_sector	; keep an FDC read command in A'
	ex	af,af'

fd_read_sector:
	push	hl		; save copies of the arguments
	push	de
	push	bc

	call	terminate_fdc_cmd	; ensure that FDC is ready for a cmd

	ld	a,c			; give FDC the sector number
	out	(fdc_sector_reg),a

	ex	af,af'			; give FDC command from A'
	out	(fdc_cmd_reg),a
	ex	af,af'

	call	delay_bc_5		; delay by 135 t-states (33.75us @4MHz)
	pop	bc			; get original sector size, number back
	push	bc

	ld	c,fdc_data_reg		; prepare for ini instruction

fd_read_data_loop:
	in	a,(fdc_status_reg)	; is DRQ set
	bit	fdc_status_bit_drq,a
	jr	z,fd_read_data_no_drq	; no, make sure we're still busy

	ini				; read a byte into buffer
	jr	z,fd_read_data_done	; transfer complete?

fd_read_data_no_drq:
	bit	fdc_status_bit_busy,a	; still busy
	jr	nz,fd_read_data_loop	;   yes, continue reading

; read command data transfer complete
fd_read_data_done:
	pop	bc			; restore original sector, sector count
	pop	de			; etc.

	in	a,(fdc_status_reg)	; any errors?
	and	$1C
	jr	z,fd_read_ok		; no

; read error
	pop	hl			; restore original buffer pointer
	dec	e			; any retries left?
	jr	nz,fd_read_sector	; yes, go do it agin

; read fail - retries exhausted
	; bit	fdc_status_bit_rec_not_found,a
	; jr	nz,tk_err
	; bit	fdc_status_bit_crc_err,a
	; jr	nz,sc_err
	jr	ld_err

fd_read_ok:
	pop	af			; discard original buffer pointer
	inc	c			; increment sector number
	ld	e,fd_retry_count	; restore retry count
	dec	d			; decrement sector count
	jr	nz,fd_read_sector	; if more sectors, loop

	ld	hl,fd_boot_sig_0
	ld	de,$1000
	ld	b,fd_boot_sig_0_len
	call	check_disk_signature
	jr	nz,rs_err

	ld	hl,fd_boot_sig_1
	ld	de,$1400
	ld	b,fd_boot_sig_1_len
	call	check_disk_signature
	jr	nz,rs_err

	; call	clear_screen
	push	hl
	call	con_clear
	pop	hl

	call	fd_boot_sig_1_loc+fd_boot_sig_1_len
	jp	fd_boot_sig_0_loc+fd_boot_sig_0_len


; dc_err:
; 	ld	de,'DC'
; 	jr	boot_err_deselect_fd

; d0_err:
; 	ld	de,'D0'
; 	jr	boot_err_deselect_fd

; sc_err:
; 	ld	de,'SC'
; 	jr	boot_err_deselect_fd

; ck_err:
; 	ld	de,'CK'
; 	jr	boot_err

; z8_err:
; 	ld	de,'Z8'
; 	jr	boot_err

; mf_err:
; 	ld	de,'MF'
; 	jr	boot_err

; tk_err:
; 	ld	de,'TK'
; 	jr	boot_err_deselect_fd

ld_err:
	ld	de,'LD'
	jr	boot_err_deselect_fd

rs_err:
	ld	de,'RS'

boot_err_deselect_fd:
	call	terminate_fdc_cmd
	ld	a,fdc_cmd_restore+fdc_cmd_step_rate_10ms
	out	(fdc_cmd_reg),a

	ld	bc,0
	call	delay_bc				; delay by 1,703,915 t-states (0.42597875 sec @ 4MHz)
	call	terminate_fdc_cmd

	ld	a,fdc_sel_side_0+fdc_sel_dr_none
	out	(fdc_select_reg),a

fd_boot_err:
	jp	boot_err

	; ld	hl,$fb9a
	; ld	(hl),d
	; inc	hl
	; ld	(hl),e
	; inc	hl
	; ld	(hl),' '

	; ld	hl,boot_err_msg
	; ld	de,$fb8e
	; ld	bc,boot_err_msg_len
	; ldir

	; call	check_escape_key
	; jp	z,fd_boot_sig_0_loc+fd_boot_sig_0_len

; on return, zero flag set if escape or break pressed, clear if not
panic:
	jr	panic

; clear_screen:
; ; clear screen (all 020h)
; 	ld	bc,screen_size-1		; number of chars for block move
; 	ld	de,screen_start+screen_size-2	; next-to-last loc
; 	ld	hl,screen_start+screen_size-1	; last loc
; 	ld	(hl),' '
; 	lddr
; 	ret

delay_bc_5:			; delay by 135 T-states (33.75us @ 4MHz)
	ld	bc,5
delay_bc: 			; delay by BC*26-5+10 T-states (including ret instruction)
	dec	bc
	ld	a,b
	or	c
	jr	nz,delay_bc
	ret



; use the FDC's FORCE INTERRUPT command to terminate anything in progress
; returns FDC status regster in A
terminate_fdc_cmd:
	push	bc
	ld	a,fdc_cmd_force_int+fdc_cmd_force_int_immediate
	out	(fdc_cmd_reg),a
	ld	a,fdc_cmd_force_int
	out	(fdc_cmd_reg),a
	call	delay_bc_5		; delay by 135 T-states (33.75us @ 4MHz)
	; in	a,(fdc_data_reg)	; to reset DRQ, presumably
	in	a,(fdc_status_reg)
	pop	bc
	ret

; on entry:
;   HL = pointer to expected signature value constant (ROM)
;   DE = pointer to disk buffer location to check for signature
;   B = byte count
; on return, zero flag set if match, clear if no match
check_disk_signature:
	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	djnz	check_disk_signature
	ret

; on return, zero flag set if escape or break pressed, clear if not
check_escape_key:
	in	a,(nmi_status_reg)
	xor	$80
	bit	nmi_status_bit_kbd_int,a
	ret	nz
	in	a,(kbd_data_reg)
	cp	key_escape
	ret	z
	cp	key_break
	ret


; returns with Z set and hdc_status_reg in A for no error
; returns with Z clear and hdc_error_reg in A for HDC error
; returns with Z clear and $08 in A for timeout
hd_wait_not_busy:
	push	bc
	ld	bc,0		; retry counter (65536)
hd_wait_not_busy_loop:
	in	a,(hdc_status_reg)
	bit	hdc_status_bit_busy,a
	jr	nz,hd_busy
	bit	hdc_status_bit_seek_complete,a
	jr	nz,hd_seek_complete

hd_busy:
	ex	(sp),ix		; short delay
	ex	(sp),ix
	dec	bc		; decrement retry counter
	ld	a,b		; count expired?
	or	c
	jr	nz,hd_wait_not_busy_loop	;   no, try again
	or	$08		; pretend we got an "id not found" error
	pop	bc
	ret

hd_seek_complete:
	pop	bc
	bit	hdc_status_bit_error,a	; any error
	ret	z		; no, return with Z set
	in	a,(hdc_error_reg)
	ret


hd_boot_end_sig:
	db	"/* END BOOT */"
hd_boot_end_sig_len	equ	$-hd_boot_end_sig


boot_err_msg:
	db	" BOOT ERROR "
boot_err_msg_len	equ	$-boot_err_msg

fd_boot_sig_0_loc	equ	$1000
fd_boot_sig_0		equ	boot_err_msg+1
fd_boot_sig_0_len	equ	4

fd_boot_sig_1_loc	equ	$1400
fd_boot_sig_1:
	db	"DIAG"
fd_boot_sig_1_len	equ	$-fd_boot_sig_1

