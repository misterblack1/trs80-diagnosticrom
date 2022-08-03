.include "inc/trs80diag.mac"


; SIMERROR_MARCH++
; SIMERROR_RND++
; SILENCE++

VBASE  equ 3c00h
VSIZE  equ 0400h
VLINE  equ 64
VREPEAT equ 2

VSTACK equ VBASE+VSIZE

DBASE  equ 04000H
DSIZE  equ 0C000H
DREPEAT equ 1h


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

		ld a, 0		; byte to be written goes in A
		out (0f8h),a	; blank printer port for now

		iycall chartest	; show all characters on the screen

	.test_vram:
		ld e,0
		link_memtest memtestmarch, VBASE, VSIZE, 00h
		jp nc,.vramok

		; we know the VRAM isn't good on all 8 bits.  Check if it is just bit 6
		ld a,(1<<6)
		and e
		jp z,vrambad	; VRAM is really bad, not just bit 6.  Report via tones.
		jp vram_7bit	; VRAM is no good for stack, but OK for printing
		ld sp, VSTACK

	.stackok:
		mac_con_clear
		mac_con_println bannermsg
		mac_con_print vramgoodmsg
		mac_con_println ramstartmsg

		; print the character set starting at line 11
		mac_con_row 10
		push ix
		pop hl

		ld bc,$100
		ld a,0
	.charloop:
		ld (hl),a	; copy A to byte pointed by HL
		inc a		; increments A
		cpi		; increments HL, decrements BC (and does a CP)
		jp pe, .charloop


stack_good:
		mac_con_row 2

		link_memtest_block $4000,$4000
		link_memtest_block $8000,$4000
		link_memtest_block $C000,$4000
		; link_memtest_block $4000,$C000
		jp stack_good

vram_7bit:
		link_memtest memtestmarch, $4000, $1000, 0	; test first 4k of RAM

		jp vrambad


;; -------------------------------------------------------------------------------------------------
;; end of main program.


_soundbiterr macro bitnum
	local zero,cont
		pause $4000

		bit bitnum,e
		jr z,.`zero

		music bitbadnotes
		jr .`cont
	.`zero:
		music bitgoodnotes
	.`cont:
endm

vrambad:
		iycall chartest
		music sadvram
		pause $4000

		irpc bn,76543210
			_soundbiterr bn
		endm
		haltcpu


announceblock:
		mac_con_NL
		call printrange
		ret
	
announcetest:
		call con_print
		push ix
		mac_con_print testingmsg
		pop ix
		ret




reportmem:
		call c,reportmemerr
		call nc,reportmemgood
		ret


reportmemgood:
		mac_con_print okmsg
		music happymusic
		ret

reportmemerr:
	ld a,e
		call printbiterr
		music sadmusic
		scf
		ret

printhlx:
		push af
		ld a,h
		call con_printx ; print bad address high byte
		ld a,l
		call con_printx ; print bad address low byte
		pop af
		ret

printrange:     ; print HX "-" (HX)+BC-1 to indicate range of an operation
		call printhlx
		ld a,'-'
		mac_con_printc
		; push hl
		dec hl
		add hl,bc
		call printhlx
		; pop hl
		ret

_printbiterr macro bitnum
	local zero,cont
		bit bitnum,e
		jr z,.`zero
		ld (ix+0),'0'+bitnum
		jr .`cont
	.`zero:
		ld (ix+0),'.'
	.`cont:
		inc ix
endm

printbiterr:
		_printbiterr 7
		_printbiterr 6
		_printbiterr 5
		_printbiterr 4
		_printbiterr 3
		_printbiterr 2
		_printbiterr 1
		_printbiterr 0
		ret


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


include "inc/memtest-rnd.asm"
include "inc/memtest-march.asm"
include "inc/trs80con.asm"
include "inc/trs80music.asm"


rndtestname:    db "  iz8dwf/rnd  ", 0
marchtestname:  db "  ki3v/march  ", 0
vramgoodmsg:    defb "VRAM good! Using VRAM for CPU stack.  ", 0
bannermsg:      defb "TRS-80 M1/M3 Test ROM - Frank IZ8DWF / Dave KI3V / Adrian Black", 0
ramstartmsg:    defb "Testing DRAM.", 0
ramgoodmsg:     defb "DRAM tests good!! Have a nice day.", 0
rambadmsg:      defb "DRAM problem found. Do you have 48k? HALTED!", 0
testingmsg:     defb "testing ", 0
okmsg:          defb "OK!     ", 0
haltmsg:        defb "Halted.", 0
