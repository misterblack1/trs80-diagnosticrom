
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
		call con_print
		call con_NL
		ret

;; display a message (Requires good VRAM; using VRAM as stack.  Does not require RAM.)
;;      (HL) = message location
;;      (IX) = screen memory location
con_print:
	.loop:
		ld a,(HL)       ; get message char
		or a            ; test for null
		jr z, .done     ; return if done
		ld (ix+0),A     ; store char
		inc ix          ; advance screen pointer
		inc hl          ; advance message pointer
		jr .loop        ; continue

	.done:
		ret

; print a single character
con_printc:
		mac_con_printc
		ret

con_printx:
		mac_con_printx
		ret

con_home:
		mac_con_home
		ret

con_col: ;; move to given column (reg a) in current line
		mac_con_col
		ret

con_CR: ;; carriage return on the current line
		mac_con_CR
		ret

con_NL: ;; go to the next line (includes CR)
		mac_con_NL
		ret

con_clear:
		; push bc
		mac_con_clear
		mac_con_home
		; pop bc
		ret


; con_printb:
; 		push af
; 		push bc

; 		ld b,a
; 		ld c,8
; 	.printbit:
; 		ld a,'0'
; 		; bit 7,b
; 		; jr z,.zero
; 		rl b
; 		jr nc,.zero
; 		inc a
; 	.zero:
; 		call con_printc
; 		dec c
; 		jr nz,.printbit

; 		pop bc
; 		pop af
; 		ret
