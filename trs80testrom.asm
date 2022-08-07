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
		jp diagnostics

; interrupt vectors: these need to be located at 38h and 66h, so there is little
; code space before them.  They should probably be present so that any incoming interrupts
; won't kill the test routines.  The INT vector is probably unnecessary but the NMI should
; be present. Put the main program after them; we've got 8k to work with for the main ROM.

		dc 0038h-$,0ffh	; fill empty space
		org 0038h	; INT vector
intvec: reti

		dc 0066h-$,0ffh	; fill empty space
		org 0066h	; NMI vector
nmivec: retn



;; main program
diagnostics:
		ld a,0
		out ($EC), a	; set 64 char mode	

		ld a,0		; byte to be written goes in A
		out (0f8h),a	; blank printer port for now

		iycall chartest	; show all characters on the screen

test_vram:
		ld e,0
		link_memtest memtestmarch, VBASE, VSIZE
		; ld e,10000000b	; simlulate a vram error
		; scf
vram_result:
		jp nc,vram_8bit

		; Check if it is just bit 6 failing and assume it is a 7-bit VRAM model 1.
		ld a,10111111b	; ignore bit 6
		and e
		jp nz,vrambad	; VRAM is really bad, not just bit 6.  Report via tones.
		jp vram_7bit	; VRAM is no good for stack, but OK for printing
	
vram_8bit:						; VRAM tests good all 8 bits
		ld sp, VSTACK				; use VRAM as the stack

		mac_con_clear
		mac_con_println bannermsg
		link_memtest_block_announce VBASE,VSIZE,vramname
		mac_con_print ramstackmsg

		mac_con_row 15
		mac_con_print vramstackmsg

		; print the character set in the bottom part of the screen
		mac_con_row 9
		mac_con_index 24
		mac_con_println charsetmsg
		iycall charset


		; determine which kind of DRAM we have
		link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)
		jr nc,vram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

		ld a,$FF
		cp e
		jp z,vram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine

		; otherwise, only some of the bits between 12k and 16k were bad.  The first bank is bad but VRAM is good, 
		; so fall through and do the 16k bank tests with display

vram_stack_16k_banks:
	.loop:
		mac_con_row 3
		link_memtest_block $4000, $4000, dram16name
		call reportmem
		link_memtest_block $8000, $4000, dram16name
		call reportmem
		link_memtest_block $C000, $4000, dram16name
		call reportmem
		jp .loop


vram_stack_4k_banks:
	.loop:
		mac_con_row 3
		link_memtest_block $4000, $1000, dram4name
		call reportmem
		; a 4k bank machine can only have one bank
		jp .loop



vram_7bit:						; we know we have 7-bit VRAM and that it tests OK
		mac_con_clear				; clear and print banner (this does not require stack)
		mac_con_print_nostack bannermsg
		
		ld e,0
		link_memtest memtestmarch, $7000, $1000	; test the region between 12k and 16k (can never have DRAM in 4k bank machine)
		jr nc,dram_stack_16k_banks		; if this region tests OK, assume 16k banks and start testing

		ld a,$FF
		cp e
		jp z,dram_stack_4k_banks		; if all bits are in error between 12k and 16k, assume 4k machine

		; otherwise, only some of the bits between 12k and 16k were bad.  The first bank is bad but and VRAM is 7-bit, 
		; so fall through and do the 16k bank tests.  The first one will fail and should tone out the error.


dram_stack_16k_banks:					; The first 16K DRAM tests good.  Assuming 16k DRAM banks.
		ld sp,$4000+$1000

		mac_con_row 4
		mac_con_println msgstacktest

		; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
		; calling anything that requires the stack.  The announcement messages require the stack, so 
		; run the test first, then announce if it succeeds, and tone out if it fails
		ld e,0
		link_memtest memtestmarch, $4000, $4000
		jp nc,.dramstackgood

		mac_reportmem_stackbank_bad		; we did not pass the first stack bank test
		haltcpu

	.dramstackgood:					; stack has tested good, so we can print using stack
		mac_con_row 1				; announce results of VRAM test
		link_memtest_block_announce VBASE,VSIZE,vramname
		mac_con_print ok7msg

		mac_con_row 9				; print the character set at the bottom of the screen
		mac_con_index 24
		mac_con_println charsetmsg
		iycall charset

		mac_con_row 3				; announce results of first DRAM test
		link_memtest_block_announce $4000,$4000,dram16name
		mac_reportmem_stackbank_ok

	.loop:
		link_memtest_block $8000, $4000, dram16name
		call reportmem
		link_memtest_block $C000, $4000, dram16name
		call reportmem
		mac_con_row 3				; test the stack bank.  It has passed once so we can print using stack.
		link_memtest_block $4000, $4000, dram16name
		mac_reportmem_stackbank
		jp .loop

dram_stack_4k_banks:					; The first 4K DRAM tests good.  Assuming it's a 4k bank machine
		ld sp,$4000+$1000
		; tricky: we can't assume the stack is good yet.  So we need to perform the first test without
		; calling anything that requires the stack.  The announcement messages require the stack, so 
		; run the test first, then announce if it succeeds, and tone out if it fails
		ld e,0
		link_memtest memtestmarch, $4000, $1000
		jp nc,.dramstackgood

		mac_reportmem_stackbank_bad		; we did not pass the first stack bank test
		haltcpu

	.dramstackgood:					; stack has tested good, so we can print using stack
		mac_con_row 1				; announce results of VRAM test
		link_memtest_block_announce VBASE,VSIZE,vramname
		mac_con_print ok7msg

		mac_con_row 9				; print the character set at the bottom of the screen
		mac_con_index 24
		mac_con_println charsetmsg
		iycall charset

		mac_con_row 3				; announce results of first DRAM test
		link_memtest_block_announce $4000,$1000,dram16name
		mac_reportmem_stackbank_ok

	.loop:
		mac_con_row 3				; test the stack bank.  It has passed once so we can print using stack.
		link_memtest_block $4000, $1000, dram16name
		mac_reportmem_stackbank
		jp .loop




;; -------------------------------------------------------------------------------------------------
;; end of main program.



vrambad:
		iycall chartest
	.toneout:
		music sadvram
		pause $4000
		play_bit_errors
		pause $FFFF
		jp .toneout


drambad:	music sadmusic
		pause $4000
		play_bit_errors
		haltcpu

; announceblock:
; 		mac_con_NL
; 		call printrange
; 		ret
	
announcetest:
		call printrange
		ld a,' '
		mac_con_printc
		push ix
		mac_con_print testingmsg
		pop ix
		ret




reportmem:
		mac_reportmem
		ret
; 		call c,reportmemerr
; 		call nc,reportmemgood
; 		ret


; reportmemgood:
; 		mac_con_print okmsg
; 		music bytegoodnotes
; 		ret

; reportmemerr:
; 		iycall printbiterr_iy
; 		play_bit_errors
; 		scf
; 		ret



printhlx:
		push af
		ld a,h
		call con_printx ; print bad address high byte
		ld a,l
		call con_printx ; print bad address low byte
		pop af
		ret

printrange:     ; print HX "-" (HX)+BC-1 to indicate range of an operation
		push bc
		call printhlx
		ld a,'-'
		mac_con_printc
		; push hl
		dec hl
		pop bc
		add hl,bc
		call printhlx
		; pop hl
		ret

printbiterr_iy:
		ld a,'7'
		ld b,8
	.showbit:
		bit 7,e
		jr z,.zero
		ld (ix+0),a
		jr .cont
	.zero:
		ld (ix+0),'.'
	.cont:
		inc ix
		dec a
		rlc e
		djnz .showbit

		iyret


; Fill screen with hex 0h to ffh over and over again. Should see all possible characters. 
chartest:
		ld hl,VBASE	; start of video ram
		ld bc,VSIZE	; video ram size - 1kB
		ld a,0

	.charloop:
		ld (hl),a	; copy A to byte pointed by HL
		inc a		; increments A
		cpi		    ; increments HL, decrements BC (and does a CP)
		jp pe, .charloop

		iyret

; Print the character set at the current location on the screen (pointed to by ix)
charset:
		ld a,ixh	; get the current location into hl
		ld h,a
		ld a,ixl
		ld l,a

		ld bc,$100	; one copy of the 256-byte character set
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


vramname:	dbz " 1K VRAM "
dram4name:	dbz " 4K DRAM "
dram16name:	dbz "16K DRAM "
vramstackmsg:	dbz "STACK IN VRAM ->"
bannermsg:	dbz "TRS-80 M1/M3 TEST ROM - FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
charsetmsg:	dbz "-CHARACTER SET-"
testingmsg:	dbz "..TEST.. "
okmsg:		dbz "---OK--- "
biterrmsg:	dbz "BIT ERRS "
haltmsg:	dbz " STACK ERROR! HALT!"
ok7msg:		dbz "OK! (7-BIT)"
msg7vram:	dbz "(7-bit)"
ramstackmsg:	dbz "OK! (USING FOR STACK)"
msgstack:	dbz "(USING FOR STACK)"
msgstacktest:	dbz "TESTING STACK AREA..."
; banks16msg:	db "TESTING 16K DRAM BANKS:", 0
; banks4msg:	db "TESTING 4K DRAM BANKS:", 0

;0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
;40-7F 7654321   80-BF 7654321   C0-FF 7654321

;0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
;Detected 4k DRAM bank size.
;
;4000-7FFF: OK!
;8000-BFFF: testing... 7---3--
;C000-FFFF: bit errors 7654321 (bank missing?)
;
;5000-5FFF: ..testing.. 7...3..
;4000-4FFF: OK!
;6000-6FFF: bit errors: 7654321 (bank missing?)
