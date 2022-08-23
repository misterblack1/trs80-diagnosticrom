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

		ld	a,$81				; enable video memory access
		out	($FF),a
		ld	a,1
		out	($EF),a				; turn on the drive light at the very start (select drive 0)

init_crtc:
		ld	bc,$0FFC	; count $0F, port $FC crtc address reg
		ld	hl,crtc_setup_last
	.crtc_setup_loop:
		ld	a,(hl)		; fetch bytes from setup table and send top to bottom
		out	(c),b		; CRTC address register
		out	($FD),a		; CRTC data register
		dec	hl
		dec	b
		jp	p,.crtc_setup_loop

test_vram:
		SPTHREAD_BEGIN				; set up to begin running threaded code
		dw spt_chartest				; the VRAM tests bad.  Report and loop
		dw spt_pause,$0000
		dw m2_drivelight_off
		; dw spt_playmusic, tones_welcome
		dw spt_select_test, tp_vram
		dw memtestmarch				; test the VRAM
		; dw spt_sim_error,$F0
		dw spt_jp_nc, .vramok

		dw spt_chartest				; the VRAM tests bad.  Report and loop
	.vrambadloop:
		; dw spt_play_testresult
		; dw spt_pause, $FFFF
		; rept 8
		; 	dw m2_blink_bit
		; endm
		dw m2_blink_biterrs
		dw spt_jp, .vrambadloop


	.vramok:
		dw con_clear
		dw spt_con_print, msg_banner		; print the banner
		dw spt_print_charset

		dw spt_select_test, tp_vram
		dw spt_announcetest 			; print results of VRAM tst
		dw spt_con_print, msg_testok

	; .play_vramgood:
	; 	dw spt_playmusic, tones_vramgood	; play the VRAM good tones
	; .vram_continue:

SPT_SKIP_NMIVEC

	.start:	
		dw spt_select_test, tp_rdest		; load the test parameters
		dw spt_announcetest 			; announce what test we are about to run
		dw spt_tp_map_bank			; map in the bank to test (this unmaps VRAM)
		dw memtestmarch				; test the current bank
		dw vram_map				; map in VRAM so we can print results
		; dw spt_sim_error, $C0
		dw spt_jp_nc, .rdestok

		dw spt_con_print, msg_biterrs		; we have errors in the rdest bank
		dw print_biterrs

		dw spt_select_test, tp_low		; select the low mem test next
		dw spt_announcetest			; announce that we're skipping the relocating test

		dw spt_con_print, msg_skipped		; we can't run the low test

		dw spt_jp, .table
		

	.rdestok:
		dw spt_con_print, msg_testok		; bank is good: print the OK message
		dw spt_con_print, msg_reloc		; bank is good: print the OK message

		dw spt_relocate_test
		dw spt_select_test, tp_low_reloc	; select the low mem test next
		dw spt_announcetest
		dw spt_relocated_test
		dw vram_map				; map in VRAM so we can print results
		; dw spt_sim_error, $C0
		dw spt_jp_nc, .zerook
		
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		; dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp, .table


	.zerook:
		dw spt_con_print, msg_testok		; bank is good: print the OK message
		; dw spt_play_testresult			; play the tones

	.table:	dw spt_select_test, tp_high			; load the test table

	.tloop:	dw spt_announcetest 			; announce what test we are about to run
		dw spt_tp_map_bank
		dw memtestmarch				; test the current bank
		dw vram_map
		dw spt_jp_nc, .ok
		
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		; dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp, .cont
	
	.ok:	dw spt_con_print, msg_testok		; bank is good: print the OK message
		; dw spt_play_testresult			; play the tones

	.cont:
		dw spt_next_test, .start
		dw spt_jp, .tloop
; 		SPTHREAD_END

; halthalt:	jr halthalt

;; -------------------------------------------------------------------------------------------------
;; end of main program.

m2_drivelight_off:
		; ld	a,' '
		; ld	(VBASE),a
		ld	a,$0F
		jr	m2_drivelight_set

m2_drivelight_on:
		; ld	a,' '+$80
		; ld	(VBASE),a
		ld	a,$0E
m2_drivelight_set:
		out	($EF),a
		ret

spt_sim_error:
		pop	de
		scf
		ret

; .if SIMULATE_ERROR
; spt_simulate_error:
; 		ex	af,af'

; 		ld	a,(iy+3)			; get the start address page
; 		cp	SIMULATE_ERROR			; match a particular page
; 		jr	nz,.noerror				; only error on specific page
; 		ld	e,00100001b			; report an error
; 		ex	af,af'
; 		scf					; and set the carry flag
; 		ret
; 	.noerror:
; 		ex	af,af'
; 		ret
; .endif

; ; test if the error is $FF (all bits bad)
; spt_jp_all_bits_bad:
; 		pop	hl				; get the address for jumping if match
; 		ld	a,$FF				; check for all bits bad
; 		cp	e
; 		ret	nz				; return without jump if there is NOT a match
; 		ld	sp,hl				; else jump to the requested location
; 		ret

; ; test if the e register matches 7-bit vram and jump to spt address if match
; spt_jp_e_7bit_vram:
; 		pop	hl				; get the address for jumping if match
; 		ld	a,01000000b			; ignore bit 6
; 		cp	e				; see if there are other errors
; 		ret	nz				; return without jump if there is NOT a match
; 		ld	sp,hl				; else jump to the requested location
; 		ret

; test if the e register matches 7-bit vram and jump to spt address if match
spt_jp_e_zero:
		pop	hl				; get the address for jumping if match
		ld	a,0				; test clean
		cp	e				; see if there are other errors
		ret	nz				; return without jump if there is NOT a match
		ld	sp,hl				; else jump to the requested location
		ret


; load the label string address from the current test parameter table entry into hl
spt_ld_hl_tp_label:
		ld	l,(iy+8)
		ld	h,(iy+9)
		ret

spt_ld_hl_tp_base:
		ld	l,(iy+2)
		ld	h,(iy+3)
		ret

spt_ld_bc_tp_size:
		ld	c,(iy+0)
		ld	b,(iy+1)
		ret

spt_ld_a_tp_bank:
		ld	a,(iy+4)
		ret

; ; load the label string address from the current test parameter table entry into hl
; spt_ld_hl_tp_notes:
; 		ld	l,(iy+8)
; 		ld	h,(iy+9)
; 		ret

; spt_map_bank:
; 		pop	hl
; 		ld	a,l
; 		out	($FF),a
; 		ret

spt_tp_map_bank:
		ld	a,(iy+4)
		cp	0				; special case: when we say bank 0, we really mean 1
		jr	nz,.send
		ld	a,1				; substitute a 1 when actually banking 0
	.send:
		out	($FF),a
		ret

spt_tp_goto:
		ld	a,(iy+6)
		ld	ixl,a
		ld	a,(iy+7)
		ld	ixh,a
		ret

; move to the next test parameter table entry
spt_next_test:	pop	hl				; get the address to jump to if we are starting over
		ld 	bc,tp_size			; find the next entry
		add 	iy,bc
		ld	a,(iy+0)			; is the length zero?
		or	(iy+1)
		ret	nz				; no, use it
		ld	c,(iy+2)			; yes, get the address of the first entry
		ld	b,(iy+3)
		ld	iy,0
		add	iy,bc
		; sub	a				; clear zero flag when restarting
		ld	sp,hl				; jump to the next location
		ret

spt_announcetest:
		SPTHREAD_ENTER
		dw spt_tp_goto
		dw spt_ld_hl_tp_label
		dw con_print
		dw spt_ld_a_tp_bank
		dw con_printh
		dw spt_con_print, msg_space
		dw spt_tp_printrange
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

spt_tp_printrange:
		SPTHREAD_ENTER
		dw spt_ld_hl_tp_base
		dw ld_a_h
		dw con_printx
		dw ld_a_l
		dw con_printx
		dw spt_con_print, msg_dash

		dw spt_ld_hl_tp_base
		dw spt_ld_bc_tp_size
		dw add_hl_bc
		dw dec_hl
		dw ld_a_h
		dw con_printx
		dw ld_a_l
		dw con_printx
		; dw spt_con_print, msg_space
		dw spt_exit


spt_pause:
		pop	bc
; pause by an amount specified in BC
; do_pause:
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

spt_rlc_e:
		rlc	e
		ret

m2_blink_bit:
		; rlc	e
		SPTHREAD_ENTER
		dw spt_rlc_e
		dw m2_drivelight_on
		dw spt_jp_c, .long
		dw spt_pause, $2000
		dw spt_jp, .off
	.long:
		dw spt_pause, $FFFF
	.off:
		dw m2_drivelight_off
		dw spt_pause, $8000
		dw spt_exit
		

m2_blink_biterrs:
		SPTHREAD_ENTER
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw m2_blink_bit
		dw spt_pause, $00
		dw spt_pause, $00
		dw spt_pause, $00
		dw spt_exit



spt_print_charset:
		ld	a,ixh
		ld	h,a
		ld	a,ixl
		ld	l,a
		ld	a,0
		SPTHREAD_ENTER
		MAC_SPT_CON_GOTO 20,0
		dw spt_con_print, msg_charset		; show a copy of the character set
		dw spt_ld_bc, $40
		dw do_charset_ix
		dw spt_con_index, 16
		dw spt_ld_bc, $40
		dw do_charset_ix
		dw spt_con_index, 16
		dw spt_ld_bc, $40
		dw do_charset_ix
		dw spt_con_index, 16
		dw spt_ld_bc, $40
		dw do_charset_ix
		dw spt_exit

spt_chartest:
		ld	ix,VBASE
		ld	bc,VSIZE
do_charset_ix:
	.charloop:
		ld	(ix+0),a	; copy A to byte pointed by HL
		inc	a		; increments A
		inc	ix
		cpi			; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret


include "inc/spt.asm"
include "inc/memtestmarch.asm"
include "inc/trs80m2con.asm"
; include "inc/trs80m2music.asm"

V_END = (VBASE+VSIZE-1)



label_vram:	dbz " 2K VRAM "
label_dram16:	dbz "16K DRAM "
label_bank16:	dbz "16K page "

msg_dash:	dbz "-"
msg_space:	dbz " "
msg_banner:	dbz "         TRS-80 M2 Test ROM - Frank IZ8DWF / Dave KI3V / Adrian Black"
msg_charset:	dbz "charset:"
; msg_testing:	dbz "..test.. "
; msg_testok:	dbz "---OK--- "
; msg_biterrs:	dbz "BIT ERRS "
; msg_testing:	dbz " >test< "
msg_testok:	dbz " --OK-- "
msg_reloc:	dbz "(reloc) "
msg_skipped:	dbz " *skip* "
msg_biterrs:	dbz " errors:"
msg_testing:	db " ", " "+$80, "t"+$80, "e"+$80, "s"+$80, "t"+$80, " "+$80, " ", 0
status_backup equ $-msg_testing-1

; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. bank to map before test
; 4. location in screen memory to start printing test data
; 5. address of string for announcing test
tp_size		equ	10

COL1 = 2
COL2 = (COL1+40)

tp_vram:	dw	VSIZE, VBASE, $0, VBASE+( 2*VLINE)+COL1, label_vram

tp_low:		dw	$4000, $0000, $0, VBASE+( 3*VLINE)+COL1, label_dram16
tp_rdest:	dw	$4000, $4000, $0, VBASE+( 4*VLINE)+COL1, label_dram16

tp_high:	dw	$4000, $8000, $1, VBASE+( 5*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $1, VBASE+( 6*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $2, VBASE+( 7*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $2, VBASE+( 8*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $3, VBASE+( 9*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $3, VBASE+(10*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $4, VBASE+(11*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $4, VBASE+(12*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $5, VBASE+(13*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $5, VBASE+(14*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $6, VBASE+(15*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $6, VBASE+(16*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $7, VBASE+(17*VLINE)+COL1, label_bank16
		dw	$4000, $C000, $7, VBASE+(18*VLINE)+COL1, label_bank16
		dw	$4000, $8000, $8, VBASE+( 3*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $8, VBASE+( 4*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $9, VBASE+( 5*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $9, VBASE+( 6*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $A, VBASE+( 7*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $A, VBASE+( 8*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $B, VBASE+( 9*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $B, VBASE+(10*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $C, VBASE+(11*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $C, VBASE+(12*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $D, VBASE+(13*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $D, VBASE+(14*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $E, VBASE+(15*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $E, VBASE+(16*VLINE)+COL2, label_bank16
		dw	$4000, $8000, $F, VBASE+(17*VLINE)+COL2, label_bank16
		dw	$4000, $C000, $F, VBASE+(18*VLINE)+COL2, label_bank16
		dw	$0000, tp_high



spt_relocate_test:
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
; The code below is assembled to be relocated to $4000.  It contains threaded
; code which cannot be written in a position-independent manner (consisting
; mostly of absolute subroutine addresses).  So we use the assembler's 
; .phase directive to tell it to assemble for operation when moved to $4000.
; This code should unmap the ROM from the region starting at $0000, perform
; the memory test, then remap the ROM and return execution there via the
; normal mechanism.  The rest of ROM will not be visible during this, so no
; calls back into it can happen until the ROM is remapped, and no data
; from it can be seen either (hence an extra copy of the label).
reloc_src_begin:
		.phase $4000
reloc_dst_begin:
spt_relocated_test:
		SPTHREAD_ENTER
		dw spt_unmap_rom
		dw relocated_memtest
		dw spt_map_rom
		SPTHREAD_LEAVE
		ret

spt_unmap_rom:
		xor	a
		out	($F9),a
		ret

spt_map_rom:
		ld	a,1
		out	($F9),a
		ret

tp_low_reloc:	dw	$4000, $0000, $0, VBASE+( 3*VLINE)+COL1, label_dram16



reloc_dst_end:
relocated_memtest equ $
		.dephase

; End of relocated section. 
; (But note, the code will place a copy of the memtestmarch routine right 
; after the above code.  That routine is written in position-independent code
; aka relocatable code in Z80 terminology.  We need this RAM copy while
; testing the RAM that is mapped behind the ROM at location $0000.)
; ----------------------------------------------------------------------------
