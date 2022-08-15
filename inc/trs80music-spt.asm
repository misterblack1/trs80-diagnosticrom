; playmusic
; parameters:
;	hl = list of notes to play
; destroys: a,bc,hl
; preserves: de,ix

nop12 .macro
		jr $+2
.endm

spt_playmusic:	
		pop hl
		; fall through to playmusic

playmusic:	;music routine
	.getnote:
		ld c,(hl)
		ld a,c
		or a
		jr z,.end		; zero duration: we are done

		inc hl
		ld a,(hl)
		or a
		jr z,.rest		; zero frequency: rest

	.cycle:
		ld b,(hl)
		ld a,1
		out ($FF),a

	.looplo:
		nop12
		; nop
		; nop
		djnz .looplo
		
		ld b,(hl)
		ld a,2
		out ($FF),a

	.loophi:
		nop12
		; nop
		; nop
		djnz .loophi

		dec c
		jr nz,.cycle
		jr .next


	.rest:
		ld b,0
	.restloop1:
		nop12
		djnz .restloop1
	; .restloop2:
	; 	djnz .restloop2

		dec c
		jr nz,.rest


	.next:
		ld a,(hl)
		inc hl

	; delay between notes (needed?)
		; ld a,1
	; .between:
		ld b,80
	.between_inner:
		nop12
		djnz .between_inner
		; dec a
		; jr nz,.between

		jr .getnote

	.end:
		ld a,0
		out ($FF),a
		ret

welcomemusic:
		db $60,$40
		db $00,$00 ;end

sadvram:	db $30,$50 ;each note is first byte duration
		db $30,$90 ;then next byte frequency -- the higher the second byte, the lower the frequency
		db $30,$50
		db $30,$90
		db $30,$50
		db $30,$90 
		db $30,$50
		db $f0,$c0
		db $40,$00 ;rest
		db $00,$00 ;end

sadmusic:	db $30,$50 ;each note is first byte duration
		db $30,$60 ;then next byte frequency -- the higher the second byte, the lower the frequency
		db $30,$70
		db $30,$80
		db $30,$90
		db $30,$a0 
		db $30,$b0
		db $f0,$c0
		db $00,$00 ;end

happymusic:	db $15,$c0 ;each note is first byte duration
		db $16,$b0 ;then next byte frequency -- the higher the second byte, the lower the frequency
		db $17,$a0 
		db $18,$90 
		db $19,$80
		db $20,$70
		db $20,$60
		db $80,$50 
		db $40,$00 ;rest
		db $00,$00 ;end


bitgoodnotes:	db $40,$60, $FF,$30
		db $10,$00 ;rest
		db $00,$00 ;end

bitbadnotes:	db $40,$60, $44,$C0
		db $10,$00 ;rest
		db $00,$00 ;end

bytegoodnotes:	db $FF,$60
		db $FF,$30
		db $00,$00 ;end

bytebadnotes:	db $FF,$60
		db $44,$C0
		db $80,$00 ;rest
		db $00,$00 ;end
