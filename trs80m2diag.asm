; code: language=asm-collection tabSize=8

; configuration defines:
; Whether to continue to DRAM testing after finding VRAM error.  This can be used
; to work on DRAM if you know the VRAM is bad, but you don't have replacement chips
; on hand and want to test DRAM chips too.  By default the released builds stop 
; if there is a VRAM error and try to display a character test pattern on the screen.
CONTINUE_ON_VRAM_ERROR = 0

; For debugging in an emulator, you can choose a page number to simulate a bit error
; while testing.
SIMULATE_ERROR = 0
; SIMULATE_ERROR = $80
; SIMULATE_ERROR = $3C

VBASE  equ $F800
VSIZE  equ $0800
VLINE  equ 80

.include "inc/z80.mac"
.include "inc/spt.mac"
.include "inc/m2.inc"

; Notes on global register allocation:
;
; This ROM doesn't work like typical Z80 code, which assumes the presence of a stack.
; There may in fact be no working memory in the machine for holding the stack.
;
; An overall goal for this version of the code is to run in the absence of any working
; ram at all.  There is no stack and no RAM variables.  The only storage of variables
; is in registers, so the registers must be carefully preserved.
;
; Without a stack, that means either saving them to other registers and restoring before 
; jumping to other code (remembering there can be no CALLs when there is no stack) 
; or avoiding their use altogether.  These are extremely confining restrictions.
;
; Assembly purists will shudder at the extensive use of macros, but for sanity it
; cannot be avoided.
;
; Globally, the contents of these registers must be preserved
;	e = bit errors in the region of memory currently being tested
;	ix = current location in VRAM for printing messages
;	iy = current table entry for test parameters
;



		.org 0000h				; z80 boot code starts at location 0
reset:
		di					; mask INT
		im	1

init_crtc:
		ld	bc,$0FFC			; count $0F, port $FC crtc address reg
		ld	hl,crtc_setup_table+crtc_setup_len-1
	.loop:	ld	a,(hl)				; fetch bytes from setup table and send top to bottom
		out	(c),b				; CRTC address register
		out	($FD),a				; CRTC data register
		dec	hl
		dec	b
		jp	p,.loop


test_vram:
		SPTHREAD_BEGIN				; set up to begin running threaded code
		dw vram_map				; map in VRAM so we can print results

		;;;; test the VRAM while lighting/clicking the floppy drive
		dw spt_call, sptc_fdc_reset_head
		dw spt_select_test, tp_vram
		dw memtestmarch				; test the VRAM
		dw fdc_deselect
		; dw spt_sim_error,$F0
		dw spt_jp_nc, .vram_ok

		dw chartest_fullscreen			; the VRAM tests bad.  Report and loop
	.vram_bad:
		dw spt_call, sptc_blink_biterrs
		dw spt_jp, .vram_bad


	.vram_ok:
		;;;; clear the screen, print charset at bottom, report the results of the VRAM test
		dw con_clear
		dw spt_con_index,9
		dw spt_con_print, msg_banner		; print the banner
		dw spt_call, sptc_print_charset
		dw spt_select_test, tp_vram
		dw spt_call, sptc_announcetest 		; print results of VRAM tst
		dw spt_con_print, msg_testok

	.test_b1:
		;;;; perform the test of the bank to which we are going to relocate some code
		dw spt_select_test, tp_rdest		; load the test parameters
		dw spt_call, sptc_announcetest 		; announce what test we are about to run
		dw tp_map_bank				; map in the bank to test (this unmaps VRAM)
		dw memtestmarch				; test the current bank
		dw vram_map				; map in VRAM so we can print results
		; dw spt_sim_error, $C0
		dw spt_jp_nc, .b1_ok

		dw spt_call, sptc_print_errsmsg		; relocation destination is not OK
		dw print_biterrs
		dw spt_select_test, tp_low		; announce that we're skipping the relocating test
		dw spt_call, sptc_announcetest		; 
		dw spt_con_print, msg_skipped		; we can't run the low test
		dw spt_jp, .test_banked
		

	.b1_ok:
		dw spt_con_print, msg_testok		; bank is good: print the OK message
		dw spt_con_print, msg_reloc		; bank is good: print the OK message

		;;;; relocate the memory test into upper half of low RAM, unmap ROM, run test on lowest RAM
		dw relocate_memtest
		dw spt_select_test, tp_low_reloc	; select the low mem test next
		dw spt_call, sptc_announcetest
		dw spt_call, sptc_relocated_test
		dw vram_map				; map in VRAM so we can print results
		; dw spt_sim_error, $C0
		dw spt_jp_nc, .b0_ok
		
		dw spt_call, sptc_print_errsmsg
		dw print_biterrs
		dw spt_jp, .test_banked

	.b0_ok:
		dw spt_con_print, msg_testok		; bank is good: print the OK message



	.test_banked:	
		;;;; Loop through the rest fo the banks, testing each one
		dw spt_select_test, tp_high		; load the test table

	.bank_loop:	
		dw spt_call, sptc_announcetest 		; announce what test we are about to run
		dw tp_map_bank
		dw spt_jp_bank_dup, .bank_dup
		dw memtestmarch				; test the current bank
		dw mark_bank_map_vram
		; dw vram_map
		dw spt_jp_nc, .bank_ok
		
		dw spt_call, sptc_print_errsmsg
		dw print_biterrs
		dw spt_jp, .cont

	.bank_dup:	
		dw vram_map
		dw spt_con_print, msg_dup
		dw spt_call, sptc_printbank
		dw spt_jp, .cont

	.bank_ok:
		dw spt_con_print, msg_testok		; bank is good: print the OK message

	.tryboot_floppy:				; boot from the floppy if it is ready
		dw spt_jp_fdc_ready,.boot
		; dw spt_jp,.test_b1

	.cont:	dw spt_tp_next, .test_b1		; start over if we've reached the end
		dw spt_jp, .bank_loop			; else test the next bank

	.boot:						; TODO: distinguish betweeen floppy and HD boot
		; dw spt_jp, .test_b1
		dw boot_os

;; -------------------------------------------------------------------------------------------------
;; end of main program.
spt_jp_bank_dup:
		; determine if this bank is a different, already tested bank
		ex	af,af'				; save old flags
		ld	h,(iy+TP_BASE)			; get the base address of ram
		ld	l,15				; plus 15 bytes
		ld	bc,15				; compare bytes at offset 15...1 (not 0)
		ld	a,$55				; test that the bank is filled with $55
	.test55:
		cpd					; compare a,(hl) ; hl-- ; bc--
		jr	nz,.done			; if mem != $55, this isn't a tested bank, so quit
		jp	pe,.test55			; if we have more to test, loop
	
		ld	a,(hl)				; HL should now be the base address
		cp	(iy+TP_BANK)			; compare to current bank number
		jr	c,.dup				; mem < bank; found a duplicate bank number
	.done:
		pop	hl				; discard the error address
		ex	af,af'
		ret
	
	.dup:						; found a match.  Jump to the specified SPT location
		ld	e,a				; report the error as the bank we found
		ex	af,af'
		pop	hl
		ld	sp,hl
		ret

mark_bank_map_vram:
		ex	af,af'				; save flags
		ld	h,(iy+TP_BASE)			; get this bank's base in HL
		ld	l,0
		ld	b,(iy+TP_BANK)			; get the bank number in b
		ld	(hl),b				; mark the base address with the bank number

		ld	a,b				; get the bank number into A
		or	$80				; enable VRAM
		out	($FF),a				; map in VRAM and the current bank

		ex	af,af'				; restore the saved flags
		ret	nc				; return if the test had no error

		ld	a,$ff				; see if this is a an absent bank
		cp	e
		jr	z,.absent			; if absent, don't record it as an errored bank

		ld	a,'!'				; not absent, but bad; note this with the exclamation
		ld	(VBASE),a			; put an exclamation in the corner if this bank is bad
	.absent:
		scf					; set the carry flag again
		ret

ld_a_e:
		ld	a,e
		ret

sptc_printbank:
		dw ld_a_e
		dw con_printh
		dw spt_con_print,msg_space
		dw spt_exit

ld_d_0:
		ld	d,0
		ret

spt_dec_d_jp_nz:
		pop	hl
		dec	d
		ret	z
		ld	sp,hl
		ret

spt_jp_fdc_ready
		pop	hl
		ld	a,fdc_sel_side_0+fdc_sel_dr_0
		out	(fdc_select_reg),a
		in	a,(fdc_status_reg)
		bit	7,a
		ret	nz				; return if not ready
		ld	sp,hl
		ret


sptc_fdc_terminate_ready_timeout:
		dw	ld_d_0				; wait up to 256 times, then fail out
	.loop:	dw	fdc_terminate_cmd
		dw	spt_jp_fdc_ready,.done
		dw	spt_dec_d_jp_nz,.loop
	.done:	dw	spt_exit

; terminate_fdc_cmd:
fdc_terminate_cmd:
		; ld	c,0
	.start:	ld	a,fdc_cmd_force_int+fdc_cmd_force_int_immediate
		out	(fdc_cmd_reg),a
		ld	a,fdc_cmd_force_int
		out	(fdc_cmd_reg),a

		ld	b,11
	.delay:	djnz	.delay				; delay by 138 T-states (34.5ms@4MHz)

		in	a,(fdc_data_reg)		; to reset DRQ, presumably
		in	a,(fdc_status_reg)

		; bit	7,a
		; ret	z				; return if ready

		; dec	c				; issue the command up to 256 times
		; jr	nz,.start
		ret

fdc_select_none:
		ld	a,fdc_sel_side_0|fdc_sel_dr_none
		jr	fdc_select
fdc_select_d0s0:
		ld	a,fdc_sel_side_0|fdc_sel_dr_0	; select d0s0
fdc_select:
		out	(fdc_select_reg),a
		ld	b,0				; short delay for FDC to respond
	.dly1:	djnz	.dly1
		ret

fdc_deselect:
		ld	a,fdc_sel_dr_none		; deselect the drive
		out	(fdc_select_reg),a
		ret

fdc_step_in_5:
		ld	c,5
fdc_step_in:
		; pop	bc				; how many tracks (only C is significant)

	.silp:	ld	a,fdc_cmd_step_in|fdc_cmd_update_track|fdc_cmd_head_load|fdc_cmd_step_rate_15ms
		out	(fdc_cmd_reg),a

		ld	b,0				; short delay for FDC to respond
	.dly1:	djnz	.dly1

	.wrdy1:	in	a,(fdc_status_reg)		; wait for ready indication
		bit	0,a
		jr	nz,.wrdy1
	
		dec	c
		jr	nz,.silp			; repeate the stepping
		ret

fdc_head_restore:
		ld	a,fdc_cmd_restore|fdc_cmd_head_load|fdc_cmd_step_rate_15ms
		out	(fdc_cmd_reg),a			; restore head to track zero
		ret


sptc_fdc_reset_head:
		dw fdc_select_d0s0
		; dw fdc_terminate_cmd			; reset FDC
		dw spt_call, sptc_fdc_terminate_ready_timeout
		dw fdc_step_in_5
		dw fdc_head_restore
		dw spt_pause,1599
		dw spt_exit



; test if the e register matches 7-bit vram and jump to spt address if match
spt_jp_e_zero:
		pop	hl				; get the address for jumping if match
		ld	a,0				; test clean
		cp	e				; 
		ret	nz				; return without jump if there is NOT a match
		ld	sp,hl				; else jump to the requested location
		ret

spt_jp_e_ff:
		pop	hl				; get the address for jumping if match
		ld	a,$FF				; test all bits err
		cp	e				; 
		ret	nz				; return without jump if there is NOT a match
		ld	sp,hl				; else jump to the requested location
		ret



; load the label string address from the current test parameter table entry into hl
ld_hl_tp_label:
		ld	c,(iy+TP_LABEL)
		ld	b,0
		ld	hl,labels_start
		add	hl,bc
		ret

ld_hl_tp_base:
		ld	h,(iy+TP_BASE)
		ld	l,0
		ret

ld_bc_tp_size:
		ld	b,(iy+TP_SIZE)
		ld	c,0
		ret

ld_a_tp_bank:
		ld	a,(iy+TP_BANK)
		ret


tp_map_bank:
		ld	a,(iy+TP_BANK)
		cp	0				; special case: when we say bank 0, we really mean 1
		jr	nz,.send
		ld	a,1				; substitute a 1 when actually banking 0
	.send:
		out	($FF),a
		ret

spt_tp_goto:	ld	a,(iy+TP_POS)
		ld	ixl,a
		ld	a,(iy+TP_POS+1)
		ld	ixh,a
		ret

; move to the next test parameter table entry
spt_tp_next:	pop	hl				; get the address to jump to if we are starting over
		ld 	bc,tp_entrysize			; find the next entry
		add 	iy,bc
		ld	a,(iy+TP_SIZE)			; is the length zero?
		or	a
		ret	nz				; no, use it

		ld	c,(iy+TP_GOTO)			; yes, get the address of the first entry
		ld	b,(iy+TP_GOTO+1)
		ld	iy,0
		add	iy,bc
		ld	sp,hl				; jump to the next location
		ret

sptc_announcetest:
		dw spt_tp_goto
		dw ld_hl_tp_label
		dw con_print
		dw ld_a_tp_bank
		dw con_printh
		dw spt_con_print, msg_space
		dw spt_call, sptc_tp_print_range
		dw spt_con_print, msg_testing
		dw spt_con_index, -status_backup
		dw spt_exit

ld_a_h:		ld	a,h
		ret

ld_a_l:		ld	a,l
		ret

add_hl_bc:	add	hl,bc
		ret

dec_hl:		dec	hl
		ret

sptc_tp_print_range:
		dw ld_hl_tp_base
		dw ld_a_h
		dw con_printx
		dw ld_a_l
		dw con_printx
		dw spt_con_print, msg_dash

		dw ld_hl_tp_base
		dw ld_bc_tp_size
		dw add_hl_bc
		dw dec_hl
		dw ld_a_h
		dw con_printx
		dw ld_a_l
		dw con_printx
		; dw spt_con_print, msg_space
		dw spt_exit


spt_pause:							; pause by an amount specified in BC
		pop	bc
pause_bc:							; pause by BC*50-5+14 t-states
		ex	af,af'
	.loop:							
		nop12
		nop12
		dec	bc
		ld	a,b
		or	c
		jr	nz,.loop
		ex	af,af'
		ret


sptc_print_errsmsg:
		dw spt_jp_e_ff,.absent
		dw spt_con_print,msg_biterrs
		dw spt_exit
	.absent:
		dw spt_con_print,msg_absent
		dw spt_exit

print_biterrs:
		ld	a,'7'
		ld	b,8
	.showbit:
		rlc	e
		jr	nc,.zero
		ld	(ix+0),a
		jr	.cont
	.zero:
		ld	(ix+0),'.'
	.cont:
		inc	ix
		dec	a
		djnz	.showbit

		ret

rlc_e:
		rlc	e
		ret

spt_blink_bit_rl:
		; rlc	e
		SPTHREAD_ENTER
		dw rlc_e
		; dw m2_drivelight_on
		dw fdc_select_d0s0
		dw spt_jp_c, .long
		dw spt_pause, $2000
		dw spt_jp, .off
	.long:
		dw spt_pause, $FFFF
	.off:
		; dw m2_drivelight_off
		dw fdc_select_none
		dw spt_pause, $8000
		dw spt_exit
		

sptc_blink_biterrs:
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_blink_bit_rl
		dw spt_pause, $00
		dw spt_pause, $00
		dw spt_pause, $00
		dw spt_exit

ld_a_0:
		ld	a,0
		ret

sptc_print_charset:
		MAC_SPT_CON_GOTO 20,-8
		dw ld_a_0
		dw spt_charset_40
		dw spt_charset_40
		dw spt_charset_40
		dw spt_charset_40
		dw spt_exit

spt_charset_40:
		ld	bc,$10
		add	ix,bc
		ld	bc,$40
		jr	charset_here
chartest_fullscreen:
		ld	ix,VBASE
		ld	bc,VSIZE
charset_here:
	.charloop:
		ld	(ix+0),a	; copy A to byte pointed by HL
		inc	a		; increments A
		inc	ix
		cpi			; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret


V_END = (VBASE+VSIZE-1)


labels_start:
label_vram:	dbz " 2K VRAM "
label_dram16:	dbz "16K DRAM "
label_bank16:	dbz "16K page "

msg_dash:	dbz "-"
msg_space:	dbz " "
msg_banner:	dbz "TRS-80 M2 Test ROM - Frank IZ8DWF / Dave KI3V / Adrian Black"
msg_charset:	dbz "charset:"
; msg_testing:	dbz "..test.. "
; msg_testok:	dbz "---OK--- "
; msg_biterrs:	dbz "BIT ERRS "
; msg_testing:	dbz " >test< "
msg_testok:	dbz " --OK-- "
msg_reloc:	dbz "(reloc) "
msg_skipped:	dbz " *skip* "
msg_biterrs:	dbz " errors:"
msg_absent:	dbz " absent:"
msg_dup:	dbz "  DUP "
msg_testing:	db " ", " "+$80, "t"+$80, "e"+$80, "s"+$80, "t"+$80, " "+$80, " ", 0
status_backup equ $-msg_testing-1

; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. bank to map before test
; 4. location in screen memory to start printing test data
; 5. address of string for announcing test
; tp_entrysize equ 10
tp_entrysize equ tp_low-tp_vram

COL1 = 2
COL2 = (COL1+40)

TP_SIZE equ 0
TP_BASE equ 1
TP_BANK equ 2
TP_LABEL equ 3
TP_POS equ 4
TP_GOTO equ 1

memtest_ld_bc_size .macro
		ld	b,(iy+TP_SIZE)
		ld	c,a
.endm

memtest_ld_hl_base .macro
		ld	h,(iy+TP_BASE)
		ld	l,a
.endm

memtest_loadregs .macro
		xor	a
		memtest_ld_bc_size
		memtest_ld_hl_base
.endm


tp_vram:	db	high VSIZE, high VBASE, $0, label_vram-labels_start
		dw	VBASE+( 2*VLINE)+COL1

tp_low:		db	$40, $00, $0, label_dram16-labels_start
		dw	VBASE+( 3*VLINE)+COL1
tp_rdest:	db	$40, $40, $0, label_dram16-labels_start
		dw	VBASE+( 4*VLINE)+COL1

tp_high:	db	$40, $80, $1, label_bank16-labels_start
		dw	VBASE+( 5*VLINE)+COL1
		db	$40, $C0, $1, label_bank16-labels_start
		dw	VBASE+( 6*VLINE)+COL1
		db	$40, $80, $2, label_bank16-labels_start
		dw	VBASE+( 7*VLINE)+COL1
		db	$40, $C0, $2, label_bank16-labels_start
		dw	VBASE+( 8*VLINE)+COL1
		db	$40, $80, $3, label_bank16-labels_start
		dw	VBASE+( 9*VLINE)+COL1
		db	$40, $C0, $3, label_bank16-labels_start
		dw	VBASE+(10*VLINE)+COL1
		db	$40, $80, $4, label_bank16-labels_start
		dw	VBASE+(11*VLINE)+COL1
		db	$40, $C0, $4, label_bank16-labels_start
		dw	VBASE+(12*VLINE)+COL1
		db	$40, $80, $5, label_bank16-labels_start
		dw	VBASE+(13*VLINE)+COL1
		db	$40, $C0, $5, label_bank16-labels_start
		dw	VBASE+(14*VLINE)+COL1
		db	$40, $80, $6, label_bank16-labels_start
		dw	VBASE+(15*VLINE)+COL1
		db	$40, $C0, $6, label_bank16-labels_start
		dw	VBASE+(16*VLINE)+COL1
		db	$40, $80, $7, label_bank16-labels_start
		dw	VBASE+(17*VLINE)+COL1
		db	$40, $C0, $7, label_bank16-labels_start
		dw	VBASE+(18*VLINE)+COL1
		db	$40, $80, $8, label_bank16-labels_start
		dw	VBASE+( 3*VLINE)+COL2
		db	$40, $C0, $8, label_bank16-labels_start
		dw	VBASE+( 4*VLINE)+COL2
		db	$40, $80, $9, label_bank16-labels_start
		dw	VBASE+( 5*VLINE)+COL2
		db	$40, $C0, $9, label_bank16-labels_start
		dw	VBASE+( 6*VLINE)+COL2
		db	$40, $80, $A, label_bank16-labels_start
		dw	VBASE+( 7*VLINE)+COL2
		db	$40, $C0, $A, label_bank16-labels_start
		dw	VBASE+( 8*VLINE)+COL2
		db	$40, $80, $B, label_bank16-labels_start
		dw	VBASE+( 9*VLINE)+COL2
		db	$40, $C0, $B, label_bank16-labels_start
		dw	VBASE+(10*VLINE)+COL2
		db	$40, $80, $C, label_bank16-labels_start
		dw	VBASE+(11*VLINE)+COL2
		db	$40, $C0, $C, label_bank16-labels_start
		dw	VBASE+(12*VLINE)+COL2
		db	$40, $80, $D, label_bank16-labels_start
		dw	VBASE+(13*VLINE)+COL2
		db	$40, $C0, $D, label_bank16-labels_start
		dw	VBASE+(14*VLINE)+COL2
		db	$40, $80, $E, label_bank16-labels_start
		dw	VBASE+(15*VLINE)+COL2
		db	$40, $C0, $E, label_bank16-labels_start
		dw	VBASE+(16*VLINE)+COL2
		db	$40, $80, $F, label_bank16-labels_start
		dw	VBASE+(17*VLINE)+COL2
		db	$40, $C0, $F, label_bank16-labels_start
		dw	VBASE+(18*VLINE)+COL2
		db	$00 
		dw	tp_high



relocate_memtest:
		ld	de,reloc_dst_begin
		ld	hl,reloc_src_begin
		ld	bc,reloc_dst_end-reloc_dst_begin
		ldir
		ld	de,relocated_memtest
		ld	hl,memtestmarch
		ld	bc,memtestmarch_end-memtestmarch
		ldir
		ret

; ----------------------------------------------------------------------------
; Relocated tests:
; The code below is assembled to be relocated to $4100.  It contains threaded
; code which cannot be written in a position-independent manner (consisting
; mostly of absolute subroutine addresses).  So we use the assembler's 
; .phase directive to tell it to assemble for operation when moved to $4000.
; This code should unmap the ROM from the region starting at $0000, perform
; the memory test, then remap the ROM and return execution there via the
; normal mechanism.  The rest of ROM will not be visible during this, so no
; calls back into it can happen until the ROM is remapped, and no data
; from it can be seen either (hence an extra copy of the label).
reloc_src_begin:
		.phase $4100
reloc_dst_begin:
sptc_relocated_test:
		dw rom_unmap
		dw relocated_memtest
		dw rom_map
		dw spt_exit

rom_unmap:
		xor	a
		out	($F9),a
		ret

rom_map:
		ld	a,1
		out	($F9),a
		ret

tp_low_reloc:	db	$40, $00, $0, label_dram16-labels_start
		dw 	VBASE+( 3*VLINE)+COL1



reloc_dst_end:
relocated_memtest equ $
		.dephase

; End of relocated section. 
; (But note, the code will place a copy of the memtestmarch routine right 
; after the above code.  That routine is written in position-independent code
; aka relocatable code in Z80 terminology.  We need this RAM copy while
; testing the RAM that is mapped behind the ROM at location $0000.)
; ----------------------------------------------------------------------------

.include "inc/trs80m2fdcboot.asm"
.include "inc/spt.asm"
.include "inc/memtestmarch.asm"
.include "inc/trs80m2con.asm"
; include "inc/trs80m2music.asm"

