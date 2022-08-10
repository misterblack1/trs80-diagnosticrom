
; con_row: ;; go to display line in reg a
; 		ld b,0		; put line num in bc
; 		ld c,a

; 		ld a,6		; 80cols = shift left 6, 40 - shift left 5
; 	.shiftloop:
; 		sla c		; 16-bit shift left
; 		rl b
; 		dec a
; 		jr nz, .shiftloop

; 		; rept 6
; 		; 	sla c
; 		; 	rl b
; 		; endm

; 		ld ix,VBASE     ; add this offset to the base
; 		add ix,bc

; 		ret


con_println:
		; call con_print
		iycall con_print_iy
		; call con_NL
		iycall con_NL_iy

		ret


;; display a message (Requires good VRAM; using VRAM as stack.  Does not require RAM.)
;;      (HL) = message location
;;      (IX) = screen memory location
_print .macro 
	.local loop, done
	.`loop:
		ld a,(HL)       ; get message char
		or a            ; test for null
		jr z, .`done     ; return if done
		ld (ix+0),A     ; store char
		inc ix          ; advance screen pointer
		inc hl          ; advance message pointer
		jr .`loop        ; continue

	.`done:
.endm

con_print_iy:
	_print
		iyret


; con_print:
; 		_print
; 		ret

; con_printc:
; 		mac_con_printc
; 		ret

; con_printx:
; 		mac_con_printx
; 		ret

; con_home:
; 		mac_con_home
; 		ret

; con_col: ;; move to given column (reg a) in current line
; 		mac_con_col
; 		ret

; con_CR: ;; carriage return on the current line
; 		mac_con_CR
; 		ret

; con_NL: ;; go to the next line (includes CR)
; 		mac_con_NL
; 		ret

con_NL_iy: ;; go to the next line (includes CR)
		mac_con_NL
		iyret

; con_clear:
; 		; push bc
; 		mac_con_clear
; 		mac_con_home
; 		; pop bc
; 		ret
_con_clear .macro
	.local loop
		; ld ix,VBASE
		ld hl,VBASE
		ld bc,VSIZE
	.`loop:
		; ld (ix+0),20h
		ld (hl),20h
		; inc ix
		cpi
		jp pe,.`loop

		ld ix,VBASE
.endm

con_clear_iy:
		_con_clear
		; mac_con_home
		iyret

_con_clear_eol .macro
	.local loop
		ld a,ixh
		ld h,a
		ld a,ixl
		ld l,a
		
	.`loop:
		mac_con_printchar " "
		ld a,ixl
		and 00111111b			; see if we are at the beginning of the line
		jr nz,.`loop

		ld a,h
		ld ixh,a
		ld a,l
		ld ixl,a
.endm

con_clear_eol_iy:
		_con_clear_eol
		iyret
