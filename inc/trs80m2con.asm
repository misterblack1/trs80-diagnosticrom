; code: language=asm-collection tabSize=8


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

mac_con_printc macro reg
		ld (ix+0), reg
		inc ix
endm

mac_itoh_nybble macro
		or $F0
		daa
		add a, $A0
		adc a, $40
endm

; mac_con_printx macro
; 		ld b,a			; save a copy of the number to convert
; 		rra			; get upper nybble
; 		rra
; 		rra
; 		rra
; 		mac_itoh_nybble		; convert to ascii
; 		mac_con_printc a
; 		ld a,b			; fetch lower nybble
; 		mac_itoh_nybble		; convert to ascii
; 		mac_con_printc a
; endm

con_printx:
		ld b,a			; save a copy of the number to convert
		rra			; get upper nybble
		rra
		rra
		rra
		mac_itoh_nybble		; convert to ascii
		mac_con_printc a
		ld a,b			; fetch lower nybble
con_printh:	mac_itoh_nybble		; convert to ascii
		mac_con_printc a
		ret


con_home:	ld ix,VBASE
		ret

spt_con_goto:	pop ix
		ret

con_NL:
		ld a,ixl		; go to beginning of line
		and $c0			; then go to the next line
		add a,$40
		ld ixl,a		; store the low byte back
		jr nc,.skip
		inc ixh			; fix up high byte if there was a carry
	.skip:
		ret

con_clear:
		ld hl,VBASE
		ld bc,VSIZE
con_clear_area:
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


; vram_unmap:
; 		ld	a,$00		; disable video memory access
; 		jr	vram_apply

vram_map:
		ld	a,$80		; enable video memory access
vram_apply:	out	($FF),a
		ret


crtc_setup_table:
		db $63			; $0: Horizontal Total = 99
		db $50			; $1: Horizontal Displayed = 80
		db $55			; $2: H Sync Position = 85
		db $08			; $3: Sync Width = 8
		db $19			; $4: Vertical Total = 25
		db $00			; $5: V Total Adjust = 0
		db $18			; $6: Vertical Displayed = 24
		db $18			; $7: Vertical Sync Position = 24
		db $00			; $8: Interlace Mode and Skew = 0
		db $09			; $9: Max Scan Line Address = 9
		db 00100101b	; $A:  Cursor Start = 5 (b6:blink on, b5=blink period ct)
		db $09			; $B: Cursor End = 9
		db $00			; $C: Start Address H = 0
		db $00			; $D: Start Address L = 0
		; db high ((VLINE*12)+39)	; $E: Cursor H (HL = $3E9)
		; db low ((VLINE*12)+39)	; $F: Cursor L (decimal 1001, center of screen)
		db high ((VLINE*21)+39)	; $E: Cursor H (HL = $3E9)
		db low ((VLINE*21)+39)	; $F: Cursor H (decimal 1001, center of screen)
crtc_setup_len equ $-crtc_setup_table


con_cursor_off:
		ld	d,00100101b
		jr	con_cursor_set
con_cursor_on:
		ld	d,01100101b	; turn on the cursor
con_cursor_set:
		ld	bc,$0AFC	; point at the CRTC address port
		out	(c),b		; select the cursor control register
		inc	c		; point at the CRTC data port
		ld	b,01100101b	; turn on the cursor
		out	(c),d
		ret

con_clear_kbd:
		ld	d,200
	.loop:
		in	a,(nmi_status_reg)
		bit	nmi_status_bit_kbd_int,a
		jr	z,.no_key
		in	a,(kbd_data_reg)
	.no_key:
		ld	b,0
	.delay:	djnz	.delay
		; ld	bc,128
		; call	delay_bc		; delay by 3333 t-states (833.25us @ 4MHz)
		dec	d
		jr	nz,.loop
		ret

; con_get_key:
; 		in	a,(nmi_status_reg)
; 		bit	nmi_status_bit_kbd_int,a
; 		jr	z,.nokey
; 		; xor	$80
; 		; bit	nmi_status_bit_kbd_int,a
; 		; jr	nz,.nokey
; 		in	a,(kbd_data_reg)
; 		ret
; 	.nokey: sub	a
; 		ret

; spt_check_key:
; 		pop	bc
; 		cp	c
; 		ret

; spt_jp_z:
; 		pop	hl
; 		ret	nz
; 		ld	sp,hl
; 		ret
