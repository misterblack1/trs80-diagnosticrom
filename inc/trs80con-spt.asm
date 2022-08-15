
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


; con_println:
; 		iycall con_print_iy
; 		iycall con_NL_iy
; 		ret


;; display a message (Requires good VRAM; using VRAM as stack.  Does not require RAM.)
;;      (HL) = message location
;;      (IX) = screen memory location


spt_con_print:	pop hl
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

con_home:	ld ix,VBASE
		ret

spt_con_goto:	pop ix
		ret

; con_printc:
; 		mac_con_printc
; 		ret

; con_printx:
; 		mac_con_printx
; 		ret


con_col: ;; move to given column (reg a) in current line
		mac_con_col
		ret


con_NL: ;; go to the next line (includes CR)
		mac_con_NL
		ret

; con_NL_iy: ;; go to the next line (includes CR)
; 		mac_con_NL
; 		iyret

con_clear:
		ld hl,VBASE
		ld bc,VSIZE
	.loop:
		ld (hl),20h
		cpi
		jp pe,.loop

		ld ix,VBASE
		ret

con_clear_eol:
		ld a,ixh
		ld h,a
		ld a,ixl
		ld l,a
		
	.loop:
		mac_con_printchar " "
		ld a,ixl
		and 00111111b			; see if we are at the beginning of the line
		jr nz,.loop

		ld a,h
		ld ixh,a
		ld a,l
		ld ixl,a

		ret

con_print_iy:
	.loop:
		ld a,(HL)       ; get message char
		or a            ; test for null
		jr z, .done     ; return if done
		ld (ix+0),A     ; store char
		inc ix          ; advance screen pointer
		inc hl          ; advance message pointer
		jr .loop        ; continue

	.done:
		iyret

con_NL_iy: ;; go to the next line (includes CR)
		mac_con_NL
		iyret


spt_con_index:	pop bc
con_index:
		add ix,bc
		ret
