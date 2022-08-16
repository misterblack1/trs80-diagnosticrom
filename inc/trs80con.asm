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

mac_con_NL .macro
	.local skip
		ld a,ixl		; go to beginning of line
		and $c0			; then go to the next line
		add a,$40
		ld ixl,a		; store the low byte back
		jr nc,.`skip
		inc ixh			; fix up high byte if there was a carry
	.`skip:
.endm

con_NL:
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

spt_con_index:	pop bc
con_index:
		add ix,bc
		ret
