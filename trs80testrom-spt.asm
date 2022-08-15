; code: language=z80-asm tabSize=8
.include "inc/trs80diag.mac"
.include "inc/spthread.mac"

; Notes on global register allocation
;
; This ROM doesn't work like typical Z80 code, which assumes the presence of a stack.
; There may in fact be no working memory in the machine for holding the stack.
; So for much of this code, it must be assumed not only that there is no stack, but
; that certain registers must be carefully preserved.  And without a stack, that means
; either saving them to other registers and restoring before jumping to other code
; (remembering there can be no CALL instructions when there is no stack) 
; or avoiding their use altogether.  When there's no RAM and no stack, the registers
; are the ONLY place to store information, which is why some of this code is structured
; oddly.
;
; Assembly purists will shudder at the extensive use of macros.  They're not wrong,
; but the need to repeat 
;
; Globally, the contents of these registers must be preserved
;	e = bit errors in the region of memory currently being tested
;	ix = current location in VRAM for printing messages
;
; Additionally, these registers must be preserved in SOME areas of the code, at least
; while there is no stack:
;	iy = return address for current non-stack "subroutine".  See iycall macro.

; SILENCE++

VBASE  equ 3c00h
VSIZE  equ 0400h
VLINE  equ 64
VREPEAT equ 2

VSTACK equ VBASE+VSIZE


		.org 0000h
reset:
		di		; mask INT
		im 1
		; music welcomemusic

diagnostics:
		ld a,0
		out ($EC), a	; set 64 char mode	
		ld a,0		; byte to be written goes in A
		out (0f8h),a	; blank printer port for now

test_vram:
		spthread_begin
			dw spt_playmusic, welcomemusic

			dw spt_clr_e
			dw spt_memtestmarch, tp_vram

			dw spt_jp_nc, .vramok
			dw spt_jp_e_7bit_vram, .vramok

			; the VRAM tests bad.  Report and loop
			dw spt_chartest
		.vrambadloop:
			dw spt_playmusic, sadvram
			dw spt_play_bit_errors
			dw spt_pause, $FFFF
			dw spt_jp, .vrambadloop

		.vramok:
			; print the banner
			dw con_clear
			dw spt_con_print, bannermsg
			dw con_NL

			dw spt_announcetest, label_vram

			dw spt_jp_e_7bit_vram, .vram_7bit

			; show the VRAM tested message
			dw spt_con_print, ok8msg
			dw spt_jp, .play_vramgood
		.vram_7bit:
			dw spt_con_print, ok7msg

		.play_vramgood:
			dw spt_playmusic, happymusic

			; show the character set			
			dw spt_con_goto
				spt_con_offset 9,24
			dw spt_con_print, charsetmsg
			dw con_NL
			dw spt_charset_here
		
			; TODO: check for 4k vs 16k
			dw spt_jp, thread_ramtest
		spthread_end
		; ld e,0
		; link_memtest memtestmarch, VBASE, VSIZE
; vram_result:
; 		; jr nc,vram_8bit

; 		; ; Check if it is just bit 6 failing and assume it is a 7-bit VRAM model 1.
; 		; ld a,10111111b	; ignore bit 6
; 		; and e
; 		; jp nz,vrambad	; VRAM is really bad, not just bit 6.  Report via tones.
; 		; ; jp vram_7bit	; VRAM is no good for stack, but OK for printing

; vram_7bit:						; we know we have 7-bit VRAM and that it tests OK

; 		; spthread_begin
; 		; 	dw con_clear
; 		; 	dw spt_con_print, bannermsg
; 		; 	dw spt_con_goto
; 		; 		spt_con_offset 4,0
; 		; 	dw spt_con_print, msgstacktest
			
; 		; 	dw spt_clr_e
; 		; 	dw spt_memtestmarch, tp_dstack

; 		; spthread_end

; 		; mac_con_clear				; clear and print banner (this does not require stack)
; 		; mac_con_print_iy bannermsg
		
; 		; mac_con_row 4
; 		; mac_con_print_iy msgstacktest

; 		; ld e,0
; 		; link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)

; 		jp nc,dram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

; 		ld a,$FF
; 		cp e
; 		jp z,dram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine
; 		jp dram_stack_16k_banks


; interrupt vectors: these need to be located at 38h and 66h, so there is little
; code space before them.  They should probably be present so that any incoming interrupts
; won't kill the test routines.  The INT vector is probably unnecessary but the NMI should
; be present. Put the main program after them; we've got 8k to work with for the main ROM.

; 		dc 0038h-$,0ffh	; fill empty space
; 		org 0038h	; INT vector
; intvec: reti

		.assert $ <= $66
		dc 0066h-$,0ffh	; fill empty space
		org 0066h	; NMI vector
nmivec: retn


; vram_8bit:						; VRAM tests good all 8 bits
; 		; ld sp, VSTACK				; use VRAM as the stack

; 		spthread_begin
; 			dw con_clear
; 			dw spt_con_print, bannermsg
; 			dw con_NL
; 		spthread_end

; 		; mac_con_clear
; 		; mac_con_println bannermsg
; 		; mac_memtest_announce label_vram
; 		; mac_con_print ramstackmsg
; 		; music happymusic

; 		; mac_con_row 15
; 		; mac_con_print vramstackmsg

; 		; ; print the character set in the bottom part of the screen
; 		; mac_con_pos 9,24
; 		; mac_con_println charsetmsg
		
; 		; iycall charset_here


; 		; ; determine which kind of DRAM we have
; 		; link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)
; 		; jr nc,vram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

; 		; ld a,$FF
; 		; cp e
; 		; jr z,vram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine

; 		; ; otherwise, only some of the bits between 12k and 16k were bad.  The first bank is bad but VRAM is good, 
; 		; ; so fall through and do the 16k bank tests with display

; vram_stack_16k_banks:
; 	; .loop:
; 	; 	mac_con_row 3
; 	; 	link_memtest_block $4000, $4000, label_dram16k1
; 	; 	call reportmem
; 	; 	link_memtest_block $8000, $4000, label_dram16k2
; 	; 	call reportmem
; 	; 	link_memtest_block $C000, $4000, label_dram16k3
; 	; 	call reportmem
; 	; 	jr .loop


; vram_stack_4k_banks:
; 	; .loop:
; 	; 	mac_con_row 3
; 	; 	link_memtest_block $4000, $1000, label_dram4k
; 	; 	call reportmem
; 	; 	; a 4k bank machine can only have one bank
; 	; 	jr .loop



; dram_stack_16k_banks:					; The first 16K DRAM tests good.  Assuming 16k DRAM banks.
	; 	ld sp,$4000+$1000

		; spthread_begin
		; 	dw spt_banner
		; 	dw spt_announcetest, label_vram
		; spthread_end
	; 	; mac_con_row 4
	; 	; mac_con_println msgstacktest

	; 	; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
	; 	; calling anything that requires the stack.  The announcement messages require the stack, so 
	; 	; run the test first, then announce if it succeeds, and tone out if it fails
	; 	ld e,0
	; 	link_memtest memtestmarch, $4000, $4000
		; jr nc,.dramstackgood

		; mac_reportmem_stackbank_bad		; we did not pass the first stack bank test (never returns)

	; .dramstackgood:					; stack has tested good, so we can print using stack
		spthread_begin
		thread_ramtest:

			; go to start of memory testing display on screen
		.start	dw spt_ld_iy, tp_16k			; load the first test
			dw spt_con_goto
				spt_con_offset 3,0

		.loop:	dw spt_announcetest, label_dram16k1

			dw spt_clr_e
			dw memtestmarch
			dw spt_jp_nc, .ok
			
			dw spt_con_print, biterrmsg
			dw printbiterr
			dw spt_play_bit_errors
			; play_bit_errors
			dw spt_jp, .cont
		
		.ok:	dw spt_con_print, okmsg
			dw spt_playmusic, bytegoodnotes

		.cont:
			dw spt_next_test
			dw spt_jp_z,.start
			dw spt_jp, .loop
		spthread_end

dram_stack_4k_banks:					; The first 4K DRAM tests good.  Assuming it's a 4k bank machine
	; 	ld sp,$4000+$1000
	; 	; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
	; 	; calling anything that requires the stack.  The announcement messages require the stack, so 
	; 	; run the test first, then announce if it succeeds, and tone out if it fails
	; 	ld e,0
	; 	link_memtest memtestmarch, $4000, $1000
	; 	jr nc,.dramstackgood

	; 	mac_reportmem_stackbank_bad		; we did not pass the first stack bank test (never returns)

	; .dramstackgood:					; stack has tested good, so we can print using stack
	; 	mac_con_row 1				; announce results of VRAM test
	; 	mac_memtest_announce label_vram
	; 	mac_con_print ok7msg

	; 	mac_con_pos 9,24			; print the character set at the bottom of the screen
	; 	mac_con_println charsetmsg
	; 	iycall charset_here

	; 	mac_con_row 3				; announce results of first DRAM test
	; 	mac_memtest_announce label_dram4k
	; 	mac_reportmem_stackbank_ok

	; .loop:
	; 	mac_con_row 3				; test the stack bank.  It has passed once so we can print using stack.
	; 	link_memtest_block $4000, $1000, label_dram4k
	; 	mac_reportmem_stackbank
	; 	jr .loop


halthere:	jr	halthere

;; -------------------------------------------------------------------------------------------------
;; end of main program.

; test if the e register matches 7-bit vram and jump to spt address if match
spt_jp_e_7bit_vram:
		pop hl		; get the address for jumping if match
		ld a,10111111b	; ignore bit 6
		and e		; see if there are other errors
		ret nz		; return without jump if there is NOT a match
		ld sp,hl	; else jump to the requested location
		ret


; load the label string address from the current test parameter table entry into hl
spt_ld_hl_tp_label:
		ld	l,(iy+4)
		ld	h,(iy+5)
		ret

; move to the next test parameter table entry
spt_next_test:	ld 	bc,6				; find the next entry
		add 	iy,bc
		ld	a,(iy+0)			; is the length zero?
		add	a,(iy+1)
		ret	nz				; no, use it
		ld	c,(iy+2)			; yes, get the address of the first entry
		ld	b,(iy+3)
		ld	iy,0
		add	iy,bc
		sub	a				; clear zero flag when restarting
		ret

; spt_banner:
; 		spthread_enter
; 			dw con_clear
; 			dw spt_con_print, bannermsg
; 			dw con_NL
; 			dw spt_exit

spt_announcetest:
		pop	hl				; get the message to be printed
		spthread_enter
			dw con_NL
			dw con_print			; picks up message from hl
			dw spt_con_print, testingmsg
			dw spt_con_index, -9
			dw spt_exit


spt_play_bit_errors:
			spthread_save

			ld a,$FF
			cp e
			jr z,.allbad

			ld d,8
		.showbit:
			rlc e
			jr nc,.zero
			ld hl,bitbadnotes
			jr .msbe_cont
		.zero:
			ld hl,bitgoodnotes
		.msbe_cont:
			spthread_begin
				dw playmusic
			spthread_end
			pause $4000
			dec d
			jr nz,.showbit
			jr .done
		.allbad:
			spthread_begin
				dw spt_playmusic, bytebadnotes
			spthread_end
		.done:
			spthread_restore
			ret


spt_pause:
		pop bc
; pause by an amount specified in BC
do_pause:
	.loop:
		dec bc
		ld a,b
		or c
		jr nz,.loop
		ret


; vrambad:
; 		iycall chartest
; 	.toneout:
; 		ld hl,sadvram
; 		jr membadtones

; drambad:	ld hl,sadmusic
; membadtones:	iycall playmusic
; 		pause $4000
; 		play_bit_errors
; 		pause $FFFF
; 		jr membadtones


; stackbank_bad:
; 		; mac_con_print_iy biterrmsg
; 		; iycall printbiterr_iy
; 		; mac_con_print_iy haltmsg
; 		jp drambad



; announcetest:
; 		iycall con_NL_iy
; 		iycall con_print_iy
; 		mac_con_print testingmsg
; 		mac_con_index -9
; 		ret




; reportmem:
; 		; mac_reportmem
; 		ret



; printbiterr_iy:
; 		ld a,'7'
; 		ld b,8
; 	.showbit:
; 		; bit 7,e
; 		; jr z,.zero
; 		rlc e
; 		jr nc,.zero
; 		ld (ix+0),a
; 		jr .cont
; 	.zero:
; 		ld (ix+0),'.'
; 	.cont:
; 		inc ix
; 		dec a
; 		djnz .showbit

; 		iyret

printbiterr:
		ld a,'7'
		ld b,8
	.showbit:
		rlc e
		jr nc,.zero
		ld (ix+0),a
		jr .cont
	.zero:
		ld (ix+0),'.'
	.cont:
		inc ix
		dec a
		djnz .showbit

		ret



; chartest:
; 		ld hl,VBASE
; 		ld bc,VSIZE
; 		jr charset

; ; charset_here:
; ; 		push ix
; ; 		pop hl
; ; 		ld bc,$100	; one copy of the 256-byte character set
; charset:
; 		ld a,0
; 	.charloop:
; 		ld (hl),a	; copy A to byte pointed by HL
; 		inc a		; increments A
; 		cpi		; increments HL, decrements BC (and does a CP)
; 		jp pe, .charloop

; 		iyret

spt_chartest:
		ld hl,VBASE
		ld bc,VSIZE
		jp do_charset

spt_charset_here:
		ld a,ixh
		ld h,a
		ld a,ixl
		ld l,a
		ld bc,$100
do_charset:
		ld a,0
	.charloop:
		ld (hl),a	; copy A to byte pointed by HL
		inc a		; increments A
		cpi		; increments HL, decrements BC (and does a CP)
		jp pe, .charloop
		ret


; include "inc/memtest-rnd.asm"
include "inc/spthread.asm"
include "inc/memtest-march-spt.asm"
include "inc/trs80con-spt.asm"
include "inc/trs80music-spt.asm"

; vramname:	dbz " 1K VRAM "
; dram4name:	dbz " 4K DRAM "
; dram16name:	dbz "16K DRAM "

label_vram:	dbz " 1K VRAM 3C00-3FFF "
label_dram4k:	dbz " 4K DRAM 4000-4FFF "
label_dram16k1:	dbz "16K DRAM 4000-7FFF "
label_dram16k2:	dbz "16K DRAM 8000-BFFF "
label_dram16k3:	dbz "16K DRAM C000-FFFF "

; vramstackmsg:	dbz "STACK IN VRAM ->"
bannermsg:	dbz "TRS-80 M1/M3 TEST ROM - FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
charsetmsg:	dbz "-CHARACTER SET-"
testingmsg:	dbz "..TEST.. "
okmsg:		dbz "---OK--- "
biterrmsg:	dbz "BIT ERRS "
; haltmsg:	dbz " STACK ERROR! HALT!"
ok7msg:		dbz "OK! (7-BIT)"
ok8msg:		dbz "OK! (8-bit)"
; msg7vram:	dbz "(7-bit)"
; ramstackmsg:	dbz "OK! (USING FOR STACK)"
; msgstack:	dbz "(USING FOR STACK)"
msgstacktest:	dbz "TESTING STACK AREA..."


tp_vram:	dw	VSIZE, VBASE, label_vram
tp_dstack:	dw	$1000, $7000, msgstacktest

tp_16k:
tp_d16_0:	dw	$4000, $4000, label_dram16k1
tp_d16_1:	dw	$4000, $8000, label_dram16k2
tp_d16_2:	dw	$4000, $C000, label_dram16k3
		dw	$0000, tp_16k

tp_4k:
tp_d4:		dw	$1000, $4000, label_dram4k
		dw	$0000, tp_4k