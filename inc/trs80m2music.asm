; playmusic
; parameters:
;	hl = list of notes to play
; destroys: a,bc,hl
; preserves: de,ix

nop12 .macro
		jr	$+2
.endm

spt_playmusic:	
		pop	hl
		; fall through to playmusic

playmusic:	;music routine
		ret
; 	.getnote:
; 		ld	c,(hl)
; 		ld	a,c
; 		or	a
; 		jr	z,.end			; zero duration: we are done

; 		inc	hl
; 		ld	a,(hl)
; 		or	a
; 		jr	z,.rest			; zero frequency: rest


; 		ld	a,2
; 	.cycle:					; tone cycle.  First low part of square wave
; 		ld	b,(hl)
; 		out	($FF),a
; 	.loophalf:
; 		nop12
; 		djnz	.loophalf
; 		xor	3			; invert the cassette bits

; 		ld	b,(hl)
; 		out	($FF),a
; 	.loophalf2:
; 		nop12
; 		djnz	.loophalf2
; 		xor	3			; invert the cassette bits

; 		ld	b,(hl)
; 		out	($FF),a
; 	.loophalf3:
; 		nop12
; 		djnz	.loophalf3
; 		xor	3			; invert the cassette bits

; 		bit	1,a
; 		jr	nz,.cycle

; 		dec	c
; 		jr	nz,.cycle

; 	; 	ld	b,80
; 	; .between_inner:				; delay between notes
; 	; 	nop12
; 	; 	djnz	.between_inner

; 		jr	.nextnote

; 	.rest:
; 		ld	b,0
; 	.restloop:
; 		nop12
; 		nop12
; 		djnz	.restloop

; 		dec	c
; 		jr	nz,.rest


; 	.nextnote:
; 		ld	a,(hl)
; 		inc	hl

; 		jr	.getnote

; 	.end:
; 		ld	a,0
; 		out	($FF),a
; 		ret

tones_welcome:
		db	$60,$40
		db	$00,$00 ;end

tones_vram:	db	$10,$50 ;each note is first byte duration
		db	$10,$90 ;then next byte frequency -- the higher the second byte, the lower the frequency
		db	$10,$50
		db	$10,$90
		db	$10,$50
		db	$10,$90 
		db	$10,$50
		db	$60,$c0
		; db	$40,$00 ;rest
		db	$00,$00 ;end

; tones_vram:	db	$30,$60
; 		db	$10,$90 ;each note is first byte duration
; 		db	$20,$40 ;then next byte frequency -- the higher the second byte, the lower the frequency
; 		db	$10,$90
; 		db	$20,$40
; 		db	$30,$60
; 		;	db $30,$50
; 		;	db $f0,$c0
; 		db	$60,$00 ;rest
; 		db	$00,$00 ;end


; tones_sad:	db	$30,$50 ;each note is first byte duration
; 		db	$30,$60 ;then next byte frequency -- the higher the second byte, the lower the frequency
; 		db	$30,$70
; 		db	$30,$80
; 		db	$30,$90
; 		db	$30,$a0 
; 		db	$30,$b0
; 		db	$f0,$c0
; 		db	$00,$00 ;end

tones_vramgood:	db	$03,$c0 ;each note is first byte duration
		db	$03,$b0 ;then next byte frequency -- the higher the second byte, the lower the frequency
		db	$04,$a0 
		db	$04,$90 
		db	$04,$80
		db	$05,$70
		db	$05,$60
		db	$40,$50 
		;	db $40,$00 ;rest
		db	$00,$00 ;end


tones_bitgood:	db	$40,$30
		db	$20,$00 ;rest
		db	$00,$00 ;end

tones_bitbad:	db	$10,$C0
		db	$20,$00 ;rest
		db	$00,$00 ;end

tones_bytegood:	db	$FF,$30
		db	$00,$00 ;end

tones_bytebad:	db	$44,$C0
		db	$80,$00 ;rest
		db	$00,$00 ;end

tones_id1:	db	$40,$60
		db	$60,$00 ;rest
		db	$00,$00 ;end

tones_id2:	db	$40,$60
		db	$10,$00 ;rest
		db	$40,$60
		db	$60,$00 ;rest
		db	$00,$00 ;end

tones_id3:	db	$40,$60
		db	$10,$00 ;rest
		db	$40,$60
		db	$10,$00 ;rest
		db	$40,$60
		db	$60,$00 ;rest
		db	$00,$00 ;end
