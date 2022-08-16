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


; con_col: ;; move to given column (reg a) in current line
; 		mac_con_col
; 		ret


con_NL: ;; go to the next line (includes CR)
		mac_con_NL
		ret

con_clear:
		ld hl,VBASE
		ld bc,VSIZE
	.loop:
		ld (hl),20h
		cpi
		jp pe,.loop

		ld ix,VBASE
		ret

; con_clear_eol:
; 		ld a,ixh
; 		ld h,a
; 		ld a,ixl
; 		ld l,a
		
; 	.loop:
; 		mac_con_printchar " "
; 		ld a,ixl
; 		and 00111111b			; see if we are at the beginning of the line
; 		jr nz,.loop

; 		ld a,h
; 		ld ixh,a
; 		ld a,l
; 		ld ixl,a

; 		ret



spt_con_index:	pop bc
con_index:
		add ix,bc
		ret
