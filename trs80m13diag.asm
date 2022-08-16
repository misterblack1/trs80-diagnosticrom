; code: language=z80-asm tabSize=8

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
VREPEAT equ 2

VSTACK equ VBASE+VSIZE


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
		spthread_begin				; set up to begin running threaded code

		dw spt_playmusic, tones_welcome

		dw spt_ld_iy, tp_vram
		dw memtestmarch				; test the VRAM

.if SIMULATE_ERROR
		dw spt_simulate_error
.endif

.if ! CONTINUE_ON_VRAM_ERROR
		dw spt_jp_nc, .vramok
		dw spt_jp_e_7bit_vram, .vramok

		dw spt_chartest				; the VRAM tests bad.  Report and loop
	.vrambadloop:
		dw spt_play_testresult
		dw spt_pause, $FFFF
		dw spt_jp, .vrambadloop
.endif

	.vramok:
		dw con_clear
		dw spt_con_print, msg_banner		; print the banner

		dw spt_ld_iy, tp_vram
		dw spt_announcetest 			; print results of VRAM tst

		dw spt_jp_e_7bit_vram, .vram_7bit

.if CONTINUE_ON_VRAM_ERROR
		dw spt_jp_e_zero, .vram_8bit

		; we have bad vram
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp,.vram_continue
.endif

	.vram_8bit:
		dw spt_con_print, msg_ok8bit
		dw spt_jp, .play_vramgood
	.vram_7bit:
		dw spt_con_print, msg_ok7bit

	.play_vramgood:
		dw spt_playmusic, tones_vramgood	; play the VRAM good tones

	.vram_continue:
		dw spt_con_goto
			spt_con_offset 9,24
		dw spt_con_print, msg_charset		; show a copy of the character set

if CONTINUE_ON_VRAM_ERROR
spt_skip_nmivec
endif
		dw con_NL
		dw spt_charset_here

		dw spt_con_goto
			spt_con_offset 3,0
		dw spt_ld_iy, tp_bank
		dw spt_announcetest 			; announce what test we are about to run

if ! CONTINUE_ON_VRAM_ERROR
spt_skip_nmivec
endif

		dw memtestmarch				; check for 4k vs 16k

		dw spt_jp_all_bits_bad, .banks_4k

		dw spt_ld_iy, tp_16k			; load the first test
		dw spt_jp, .start
	.banks_4k:
		dw spt_ld_iy, tp_4k			; load the first test

	.start	dw spt_con_goto
			spt_con_offset 3,0

	.loop:	dw spt_announcetest 			; announce what test we are about to run
		dw memtestmarch				; test the current bank
.if SIMULATE_ERROR
		dw spt_simulate_error
.endif
		dw spt_jp_nc, .ok
		
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp, .cont
	
	.ok:	dw spt_con_print, msg_testok		; bank is good: print the OK message
		dw spt_play_testresult			; play the tones

	.cont:
		dw spt_next_test, .start
		dw spt_jp, .loop


;; -------------------------------------------------------------------------------------------------
;; end of main program.

.if SIMULATE_ERROR
spt_simulate_error:
		ex	af,af'

		ld	a,(iy+3)			; get the start address page
		cp	SIMULATE_ERROR			; match a particular page
		jr	nz,.noerror				; only error on specific page
		ld	e,00100001b			; report an error
		ex	af,af'
		scf					; and set the carry flag
		ret
	.noerror:
	; 	cp	$3C				; match a particular page
	; 	jr	nz,.noerror2				; only error on specific page
	; 	ld	e,00000101b			; report an error
	; 	ex	af,af'
	; 	scf					; and set the carry flag
	; 	ret
	; .noerror2
		ex	af,af'
		ret
.endif

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
spt_ld_hl_tp_notes:
		ld	l,(iy+6)
		ld	h,(iy+7)
		ret

; move to the next test parameter table entry
spt_next_test:	pop	hl				; get the address to jump to if we are starting over
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
		spthread_enter

		dw con_NL
		dw spt_ld_hl_tp_label
		dw con_print				; picks up message from hl
		dw spt_con_print, msg_testing
		dw spt_con_index, -9
		dw spt_exit


spt_play_testresult:
		spthread_save				; save the stack pointer

		spthread_begin
		dw spt_ld_hl_tp_notes			; play the ID tune for current bank
		dw playmusic
		dw spt_pause, $2000
		spthread_end

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
		spthread_begin
		dw playmusic
		dw spt_pause, $2000
		spthread_end

		; pause $4000
		dec	d
		jr	nz,.showbit
		jr	.done
	.allbad:
		spthread_begin
		dw spt_playmusic, tones_bytebad
		dw spt_pause, $8000
		spthread_end
		jr	.done
	.allgood:
		spthread_begin
		dw spt_playmusic, tones_bytegood
		dw spt_pause, $8000
		spthread_end
	.done:
		spthread_restore			; restore the stack pointer
		ret


spt_pause:
		pop	bc
; pause by an amount specified in BC
do_pause:
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



spt_chartest:
		ld	hl,VBASE
		ld	bc,VSIZE
		jp	do_charset

spt_charset_here:
		ld	a,ixh
		ld	h,a
		ld	a,ixl
		ld	l,a
		ld	bc,$100
do_charset:
		ld	a,0
	.charloop:
		ld	(hl),a	; copy A to byte pointed by HL
		inc	a	; increments A
		cpi		; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret


include "inc/spt.asm"
include "inc/memtestmarch.asm"
include "inc/trs80con.asm"
include "inc/trs80music.asm"

label_vram:	dbz " 1K VRAM 3C00-3FFF "
label_dram4k:	dbz " 4K DRAM 4000-4FFF "
label_dram16k1:	dbz "16K DRAM 4000-7FFF "
label_dram16k2:	dbz "16K DRAM 8000-BFFF "
label_dram16k3:	dbz "16K DRAM C000-FFFF "

; vramstackmsg:	dbz "STACK IN VRAM ->"
msg_banner:	dbz "TRS-80 M1/M3 TEST ROM -- FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
msg_charset:	dbz "-CHARACTER SET-"
msg_testing:	dbz "..TEST.. "
msg_testok:	dbz "---OK--- "
msg_biterrs:	dbz "BIT ERRS "
msg_ok7bit:	dbz "OK! (7-BIT)"
msg_ok8bit:	dbz "OK! (8-BIT)"
msg_banktest:	dbz "TESTING BANK SIZE  "


; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. address of string for announcing test
; 4. address of tones for identifying the test audibly
tp_size		equ	8

tp_vram:	dw	VSIZE, VBASE, label_vram, tones_vram
tp_bank:	dw	$1000, $7000, msg_banktest, tones_id1

tp_16k:		dw	$4000, $4000, label_dram16k1, tones_id1
		dw	$4000, $8000, label_dram16k2, tones_id2
		dw	$4000, $C000, label_dram16k3, tones_id3
		dw	$0000, tp_16k

tp_4k:		dw	$1000, $4000, label_dram4k, tones_id1
		dw	$0000, tp_4k