.include "inc/trs80diag.mac"

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
		music welcomemusic

diagnostics:
		ld a,0
		out ($EC), a	; set 64 char mode	

		ld a,0		; byte to be written goes in A
		out (0f8h),a	; blank printer port for now

test_vram:
		ld e,0
		link_memtest memtestmarch, VBASE, VSIZE
vram_result:
		jr nc,vram_8bit

		; Check if it is just bit 6 failing and assume it is a 7-bit VRAM model 1.
		ld a,10111111b	; ignore bit 6
		and e
		jp nz,vrambad	; VRAM is really bad, not just bit 6.  Report via tones.
		; jp vram_7bit	; VRAM is no good for stack, but OK for printing

vram_7bit:						; we know we have 7-bit VRAM and that it tests OK
		mac_con_clear				; clear and print banner (this does not require stack)
		mac_con_print_iy bannermsg
		
		mac_con_row 4
		mac_con_print_iy msgstacktest

		ld e,0
		link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)
		jp nc,dram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

		ld a,$FF
		cp e
		jp z,dram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine
		jp dram_stack_16k_banks


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

vram_7bit_cont:


vram_8bit:						; VRAM tests good all 8 bits
		ld sp, VSTACK				; use VRAM as the stack

		mac_con_clear
		mac_con_println bannermsg
		mac_memtest_announce label_vram
		mac_con_print ramstackmsg
		music happymusic

		mac_con_row 15
		mac_con_print vramstackmsg

		; print the character set in the bottom part of the screen
		mac_con_pos 9,24
		mac_con_println charsetmsg
		
		iycall charset_here


		; determine which kind of DRAM we have
		link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)
		jr nc,vram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

		ld a,$FF
		cp e
		jr z,vram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine

		; otherwise, only some of the bits between 12k and 16k were bad.  The first bank is bad but VRAM is good, 
		; so fall through and do the 16k bank tests with display

vram_stack_16k_banks:
	.loop:
		mac_con_row 3
		link_memtest_block $4000, $4000, label_dram16k1
		call reportmem
		link_memtest_block $8000, $4000, label_dram16k2
		call reportmem
		link_memtest_block $C000, $4000, label_dram16k3
		call reportmem
		jr .loop


vram_stack_4k_banks:
	.loop:
		mac_con_row 3
		link_memtest_block $4000, $1000, label_dram4k
		call reportmem
		; a 4k bank machine can only have one bank
		jr .loop



dram_stack_16k_banks:					; The first 16K DRAM tests good.  Assuming 16k DRAM banks.
		ld sp,$4000+$1000

		; mac_con_row 4
		; mac_con_println msgstacktest

		; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
		; calling anything that requires the stack.  The announcement messages require the stack, so 
		; run the test first, then announce if it succeeds, and tone out if it fails
		ld e,0
		link_memtest memtestmarch, $4000, $4000
		jr nc,.dramstackgood

		mac_reportmem_stackbank_bad		; we did not pass the first stack bank test (never returns)

	.dramstackgood:					; stack has tested good, so we can print using stack
		mac_con_row 1				; announce results of VRAM test
		mac_memtest_announce label_vram
		mac_con_print ok7msg
		music happymusic

		mac_con_pos 9,24			; print the character set at the bottom of the screen
		mac_con_println charsetmsg
		iycall charset_here

		mac_con_row 3				; announce results of first DRAM test
		mac_memtest_announce label_dram16k1
		mac_reportmem_stackbank_ok

	.loop:
		link_memtest_block $8000, $4000, label_dram16k2
		call reportmem
		link_memtest_block $C000, $4000, label_dram16k3
		call reportmem
		mac_con_row 3				; test the stack bank.  It has passed once so we can print using stack.
		link_memtest_block $4000, $4000, label_dram16k1
		mac_reportmem_stackbank
		jp .loop

dram_stack_4k_banks:					; The first 4K DRAM tests good.  Assuming it's a 4k bank machine
		ld sp,$4000+$1000
		; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
		; calling anything that requires the stack.  The announcement messages require the stack, so 
		; run the test first, then announce if it succeeds, and tone out if it fails
		ld e,0
		link_memtest memtestmarch, $4000, $1000
		jr nc,.dramstackgood

		mac_reportmem_stackbank_bad		; we did not pass the first stack bank test (never returns)

	.dramstackgood:					; stack has tested good, so we can print using stack
		mac_con_row 1				; announce results of VRAM test
		mac_memtest_announce label_vram
		mac_con_print ok7msg

		mac_con_pos 9,24			; print the character set at the bottom of the screen
		mac_con_println charsetmsg
		iycall charset_here

		mac_con_row 3				; announce results of first DRAM test
		mac_memtest_announce label_dram4k
		mac_reportmem_stackbank_ok

	.loop:
		mac_con_row 3				; test the stack bank.  It has passed once so we can print using stack.
		link_memtest_block $4000, $1000, label_dram4k
		mac_reportmem_stackbank
		jr .loop




;; -------------------------------------------------------------------------------------------------
;; end of main program.



vrambad:
		iycall chartest
	.toneout:
		ld hl,sadvram
		jr membadtones

drambad:	ld hl,sadmusic
membadtones:	iycall playmusic
		pause $4000
		play_bit_errors
		pause $FFFF
		jr membadtones


stackbank_bad:
		mac_con_print_iy biterrmsg
		iycall printbiterr_iy
		mac_con_print_iy haltmsg
		jp drambad



announcetest:
		iycall con_NL_iy
		iycall con_print_iy
		mac_con_print testingmsg
		mac_con_index -9
		ret

reportmem:
		mac_reportmem
		ret



printbiterr_iy:
		ld a,'7'
		ld b,8
	.showbit:
		; bit 7,e
		; jr z,.zero
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

		iyret



chartest:
		ld hl,VBASE
		ld bc,VSIZE
		jr charset

charset_here:
		push ix
		pop hl
		ld bc,$100	; one copy of the 256-byte character set
charset:
		ld a,0
	.charloop:
		ld (hl),a	; copy A to byte pointed by HL
		inc a		; increments A
		cpi		; increments HL, decrements BC (and does a CP)
		jp pe, .charloop

		iyret


; include "inc/memtest-rnd.asm"
include "inc/memtest-march.asm"
include "inc/trs80con.asm"
include "inc/trs80music.asm"

; vramname:	dbz " 1K VRAM "
; dram4name:	dbz " 4K DRAM "
; dram16name:	dbz "16K DRAM "

label_vram:	dbz " 1K VRAM 3C00-3FFF "
label_dram4k:	dbz " 4K DRAM 4000-4FFF "
label_dram16k1:	dbz "16K DRAM 4000-7FFF "
label_dram16k2:	dbz "16K DRAM 8000-BFFF "
label_dram16k3:	dbz "16K DRAM C000-FFFF "

vramstackmsg:	dbz "STACK IN VRAM ->"
bannermsg:	dbz "TRS-80 M1/M3 TEST ROM - FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
charsetmsg:	dbz "-CHARACTER SET-"
testingmsg:	dbz "..TEST.. "
okmsg:		dbz "---OK--- "
biterrmsg:	dbz "BIT ERRS "
haltmsg:	dbz " STACK ERROR! HALT!"
ok7msg:		dbz "OK! (7-BIT)"
; msg7vram:	dbz "(7-bit)"
ramstackmsg:	dbz "OK! (USING FOR STACK)"
msgstack:	dbz "(USING FOR STACK)"
msgstacktest:	dbz "TESTING STACK AREA..."
