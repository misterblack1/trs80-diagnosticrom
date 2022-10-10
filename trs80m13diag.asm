; code: language=z80-asm tabSize=8

; SIMULATE_ERROR = $80
; SIMULATE_ERROR = $3C

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

VBASE  equ 3c00h
VSIZE  equ 0400h
VLINE  equ 64


		.org 0000h				; z80 boot code starts at location 0
reset:
		di					; mask INT
		im	1

diagnostics:
		ld	a,0
		out	($EC),a				; set 64 char mode	
		; ld	a,0				; byte to be written goes in A
		out	($F8),a				; blank printer port for now

test_vram:
		SPTHREAD_BEGIN				; set up to begin running threaded code

		dw spt_playmusic, tones_welcome

		dw spt_select_test, tp_vram
		dw memtestmarch				; test the VRAM
		dw spt_check_7bit_vram
		; dw spt_sim_error, $40
		dw spt_jp_nc, .vram_ok

		; we have bad vram
		dw spt_chartest
	.vram_bad_loop:
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_pause, $0000
		dw spt_jp,.vram_bad_loop

	.vram_7bit:
		dw spt_con_print, msg_ok7bit
		; dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp,.vram_goodtones

	.vram_ok:
		dw spt_prepare_display
		MAC_SPT_CON_GOTO 1,0
		dw spt_announcetest 			; print results of VRAM tst
		; dw print_biterrs
		dw spt_jp_e_7bit_vram, .vram_7bit
		dw spt_con_print, msg_ok8bit

	.vram_goodtones:
		dw spt_playmusic, tones_vramgood	; play the VRAM good tones

	.vram_continue:
		MAC_SPT_CON_GOTO 3,0
		dw spt_select_test, tp_bank

		dw spt_announcetest 			; announce what test we are about to run
		dw memtestmarch				; check for 4k vs 16k

		dw spt_jp_all_bits_bad, .banks_4k

		dw spt_select_test, tp_16k			; load the first test
		dw spt_jp, .start
	.banks_4k:
		dw spt_select_test, tp_4k			; load the first test

SPT_SKIP_NMIVEC

	.start	dw spt_con_goto
			MAC_SPT_CON_OFFSET 3,0

	.loop:	dw spt_announcetest 			; announce what test we are about to run
		dw memtestmarch				; test the current bank
		dw spt_jp_nc, .ok
		
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp, .cont
	
	.ok:	dw spt_con_print, msg_testok		; bank is good: print the OK message
		dw spt_play_testresult			; play the tones

	.cont:
		dw spt_tp_next, .start
		dw spt_jp, .loop


;; -------------------------------------------------------------------------------------------------
;; end of main program.

spt_prepare_display:
		SPTHREAD_ENTER
		dw con_clear
		dw spt_con_print, msg_banner		; print the banner
		dw spt_print_charset
		dw spt_exit

spt_check_vram_contents:
		pop	bc
		ld	a,b
		ld	d,c
; confirm that all of VRAM contains the value in register A
check_vram_contents:
		ld	hl,VBASE
		ld	bc,VSIZE
	.fillloop:
		ld	(HL),a
		cpi
		jp	pe,.fillloop

		ld	hl,VBASE
		ld	bc,VSIZE
		ld	a,d
	.readloop:
		cpi
		jr	nz,.bad
		jp	pe,.readloop

		or	a	; clear carry flag
		ret
	.bad:	scf
		ret

spt_check_7bit_vram:
		ret	nc				; if carry flag is not set, do nothing
		ld	a,01000000b
		cp	e
		jr	z,.scantests
		scf					; something other than bit 6 is bad, so this is not 7bit VRAM
		ret
	.scantests:
		SPTHREAD_ENTER
		dw spt_check_vram_contents, $0040
		dw spt_jp_c, .exit
		dw spt_check_vram_contents, $FFBF
		dw spt_jp_c, .exit
		dw spt_check_vram_contents, $AAAA
		dw spt_jp_c, .exit
		dw spt_check_vram_contents, $5555
		dw spt_jp_c, .exit
	.exit:	dw spt_exit				; if carry flag is set, this is not good 7-bit VRAM


spt_sim_error:
		pop	de
		scf
		ret


; test if the error is $FF (all bits bad)
spt_jp_all_bits_bad:
		pop	hl				; get the address for jumping if match
		ld	a,$FF				; check for all bits bad
		cp	e
		ret	nz				; return without jump if there is NOT a match
		ld	sp,hl				; else jump to the requested location
		ret

; test if the e register matches 7-bit vram and jump to spt address if match
spt_jp_e_7bit_vram:
		pop	hl				; get the address for jumping if match
		ld	a,01000000b			; ignore bit 6
		cp	e				; see if there are other errors
		ret	nz				; return without jump if there is NOT a match
		ld	sp,hl				; else jump to the requested location
		ret

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
		ld	l,(iy+4)
		ld	h,(iy+5)
		ret

; load the label string address from the current test parameter table entry into hl
spt_ld_hl_tp_tones:
		ld	l,(iy+6)
		ld	h,(iy+7)
		ret

; move to the next test parameter table entry
spt_tp_next:	pop	hl				; get the address to jump to if we are starting over
		ld 	bc,tp_size			; find the next entry
		add 	iy,bc
		ld	a,(iy+0)			; is the length zero?
		add	a,(iy+1)
		ret	nz				; no, use it
		ld	c,(iy+2)			; yes, get the address of the first entry
		ld	b,(iy+3)
		ld	iy,0
		add	iy,bc
		; sub	a				; clear zero flag when restarting
		ld	sp,hl				; jump to the next location
		ret

spt_announcetest:
		; pop	hl				; get the message to be printed
		SPTHREAD_ENTER

		dw con_NL
		dw spt_ld_hl_tp_label
		dw con_print				; picks up message from hl
		dw spt_con_print, msg_testing
		dw spt_con_index, -9
		dw spt_exit


spt_play_testresult:
		SPTHREAD_SAVE				; save the stack pointer

		SPTHREAD_BEGIN
		dw spt_ld_hl_tp_tones			; play the ID tune for current bank
		dw playmusic
		dw spt_pause, $2000
		SPTHREAD_END

		ld	a,$FF
		cp	e
		jr	z,.allbad			; if all bits bad, play shorter tune

		cpl
		cp	e
		jr	z,.allgood			; if all bits good, play shorter tune

		ld	d,8				; play bit tune for each bit, high to low
	.showbit:
		rlc	e
		jr	nc,.zero
		ld	hl,tones_bitbad
		jr	.msbe_cont
	.zero:
		ld	hl,tones_bitgood
	.msbe_cont:
		SPTHREAD_BEGIN
		dw playmusic
		dw spt_pause, $2000
		SPTHREAD_END

		; pause $4000
		dec	d
		jr	nz,.showbit
		jr	.done
	.allbad:
		SPTHREAD_BEGIN
		dw spt_playmusic, tones_bytebad
		dw spt_pause, $8000
		SPTHREAD_END
		jr	.done
	.allgood:
		SPTHREAD_BEGIN
		dw spt_playmusic, tones_bytegood
		dw spt_pause, $8000
		SPTHREAD_END
	.done:
		SPTHREAD_RESTORE			; restore the stack pointer
		ret


spt_pause:
		pop	bc
; pause by an amount specified in BC
pause_bc:
	.loop:
		dec	bc
		ld	a,b
		or	c
		jr	nz,.loop
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

spt_ld_bc:	pop 	bc
		ret


spt_print_charset:
		ld	a,ixh
		ld	h,a
		ld	a,ixl
		ld	l,a
		ld	a,0
		SPTHREAD_ENTER
		MAC_SPT_CON_GOTO 9,24
		dw spt_con_print, msg_charset		; show a copy of the character set
		MAC_SPT_CON_GOTO 10,0
		dw spt_ld_bc, $100
		dw do_charset_ix
		dw spt_exit

spt_chartest:
		ld	ix,VBASE
		ld	bc,VSIZE
		ld	a,0
do_charset_ix:
	.charloop:
		ld	(ix+0),a	; copy A to byte pointed by HL
		inc	a		; increments A
		inc	ix
		cpi			; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret


label_vram:	dbz " 1K VRAM 3C00-3FFF "
label_dram4k:	dbz " 4K DRAM 4000-4FFF "
label_dram16k1:	dbz "16K DRAM 4000-7FFF "
label_dram16k2:	dbz "16K DRAM 8000-BFFF "
label_dram16k3:	dbz "16K DRAM C000-FFFF "

msg_banner:	dbz "TRS-80 M1/M3 TEST ROM -- FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
msg_charset:	dbz "-CHARACTER SET-"
; msg_testing:	db " ", " "+$80, "t"+$80, "e"+$80, "s"+$80, "t"+$80, " "+$80, "  ", 0
msg_testing:	dbz "..TEST.. "
msg_testok:	dbz "---OK--- "
msg_biterrs:	dbz "BIT ERRS "
msg_ok7bit:	dbz "OK! (7-BIT MODEL 1)"
msg_ok8bit:	dbz "OK! (8-BIT)"
msg_banktest:	dbz "TESTING BANK SIZE  "


; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. address of string for announcing test
; 4. address of tones for identifying the test audibly
tp_size		equ	8

memtest_ld_bc_size .macro
		ld	c,(iy+0)
		ld	b,(iy+1)
.endm

memtest_ld_hl_base .macro
		ld	l,(iy+2)
		ld	h,(iy+3)
.endm

memtest_loadregs .macro
		memtest_ld_bc_size
		memtest_ld_hl_base
.endm


tp_vram:	dw	VSIZE, VBASE, label_vram, tones_vram
tp_bank:	dw	$1000, $7000, msg_banktest, tones_id1

tp_16k:		dw	$4000, $4000, label_dram16k1, tones_id1
		dw	$4000, $8000, label_dram16k2, tones_id2
		dw	$4000, $C000, label_dram16k3, tones_id3
		dw	$0000, tp_16k

tp_4k:		dw	$1000, $4000, label_dram4k, tones_id1
		dw	$0000, tp_4k


include "inc/spt.asm"
include "inc/memtestmarch.asm"
include "inc/trs80m13con.asm"
include "inc/trs80music.asm"
