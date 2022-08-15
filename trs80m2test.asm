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
		di
		im 	1

		ld	a,$80		; enable video memory access
		out	($FF),a

clear_screen:
		ld	bc,$7FF
		ld	de,$FFFE
		ld 	hl,$FFFF
		ld	(hl),$20	; fill screen with space chars
		lddr

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

set_bank:				; run through the pages, putting the page number in the top 16 bytes of each page
		ld	a,$0F
	.bankloop:
		out	($FF),a

		ld	hl,$FFFF
		ld	b,$02
	.writeloop:
		ld	(hl),a
		dec 	hl
		djnz	.writeloop

		dec	a
		jr	nz,.bankloop
	
swap_bank:
		ld	a,$00
		out	($FF),a		

		ld	a,$01
		out	($A8),a		; swap the low andhigh banks

		ld	a,$01
		out	($FF),a		

		ld	a,$02
		out	($FF),a		

		ld	a,$00
		out	($A8),a		; swap the low andhigh banks

		ld	a,$01
		out	($FF),a		

copy_rom:	; copy the rom to the ram that is hiding behind it
		ld	hl,0
		ld	de,0
		ld	bc,rom_end
		ldir

		ld	a,$00
		out	($F9),a		; disable ROM at $0000-$07FF

relocate_code:
		ld	hl,prerelocated_continue
		ld	de,$FFFF-relocated_len
		ld	bc,relocated_len
		ldir

		jp	relocated_continue

haltmachine:
		halt
		jr	haltmachine


prerelocated_continue equ $
	.phase $FFFF-relocated_len
relocated_continue:
		ld	sp,$-relocated_continue

		; this code running  near the end of RAM ($FFxx) in page 1
		; (port $FF has been written $01"

		ld	a,$00
		out	($F9),a		; disable ROM at $0000-$07FF

		ld	a,$01
		out	($A8),a		; switch to banking $0000-$7FFF

		ld	a,$00
		out	($FF),a		; should map page 0 into $0000-$7FFF but actually unmaps $8000-$FFFF

		ld	a,$02		; But this this seems to still switch $8000-$FFFF
		out	($FF),a

		ld	a,$00
		out	($A8),a		; swap the low andhigh banks

		ld	a,$00
		out	($FF),a		

		ld	a,$01
		out	($FF),a

		ld	a,$01
		out	($A8),a		; swap the low andhigh banks

		ld	a,$00
		out	($FF),a		

		ld	a,$01
		out	($FF),a

	.relocated_halt:
		halt
		jr	.relocated_halt

		db	"HERE WE ARE"

relocated_len equ $-relocated_continue
	.dephase




crtc_setup_table:
		db $63			; Horizontal Total = 99
		db $50			; Horizontal Displayed = 80
		db $55			; H Sync Position = 85
		db $08			; Sync Width = 8
		db $19			; Vertical Total = 25
		db $00			; V Total Adjust = 0
		db $18			; Vertical Displayed = 24
		db $18			; Vertical Sync Position = 24
		db $00			; Interlace Mode and Skew = 0
		db $09			; Max Scan Line Address = 9
		db $65			; Cursor Start = 5 (b6:blink on, b5=blink period ct
		db $09			; Cursor End = 9
		db $00			; Start Address H = 0
		db $00			; Start Address L = 0
		db $03			; Cursor H (HL = $3E9)
crtc_setup_last	db $E9			; Cursor H (decimal 1001, center of screen)

rom_end equ $