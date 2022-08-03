; playmusic
; parameters:
;	ix = list of notes to play
; destroys: a,bc,hl
; preserves: de,ix

playmusic:	;music routine
	if SILENCE
		iyret
	endif

	.getnote:
		; ld c,(ix+0)
		ld c,(hl)
		ld a,c
		or a
		jp z, .end ; we are done
		inc hl

	.cycle:
		; ld b,(ix+1)
		ld b,(hl)
		ld a,1
		out ($FF), a

	.looplo:
		djnz .looplo
		
		; ld b,(ix+1)
		ld b,(hl)
		ld a,2
		out ($FF), a

	.loophi:
		djnz .loophi

		dec c
		jp nz, .cycle

		; ld a,(ix+1)
		ld a,(hl)
		inc hl

		; inc ix
		; inc ix

	; ; delay between notes (needed?)
	; 	ld a,1
	; .between:
	; 	ld b,0
	; .between_inner:
	; 	djnz .between_inner
	; 	dec a
	; 	jr nz,.between

		jp .getnote

	.end:
		iyret

welcomemusic:
		db 60h,40h
		db 0h,0h ;end

sadvram:
		db 30h,50h ;each note is first byte duration
		db 30h,90h ;then next byte frequency -- the higher the second byte, the lower the frequency
		db 30h,50h
		db 30h,90h
		db 30h,50h
		db 030h,90h 
		db 030h,050h;
		db 0f0h,0c0h
		db 0h,0h ;end

sadmusic:
		db 30h,50h ;each note is first byte duration
		db 30h,60h ;then next byte frequency -- the higher the second byte, the lower the frequency
		db 30h,70h
		db 30h,80h
		db 30h,90h
		db 030h,0a0h 
		db 030h,0b0h;
		db 0f0h,0c0h
		db 0h,0h ;end

happymusic:
		db 30h,0c0h ;each note is first byte duration
		db 30h,0b0h ;each note is first byte duration
		db 30h,0a0h ;each note is first byte duration
		db 30h,90h ;then next byte frequency -- the higher the second byte, the lower the frequency
		db 30h,80h
		db 30h,70h
		db 30h,60h
		db 0F0h,50h 
		db 0h,0h ;end

; bit0notes:
; 	db 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit1notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit2notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit3notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit4notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit5notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit6notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h
; 	db 0h,0h ;end

; bit7notes:
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
; 	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h
; 	db 0h,0h ;end

bitgoodnotes:
		db $40,$60, $FF,$30
		db 0h,0h ;end

bitbadnotes:
		db $40,$60, $44,$C0
		db 0h,0h ;end
