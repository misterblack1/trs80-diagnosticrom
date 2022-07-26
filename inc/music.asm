playmusic:	;music routine
if SILENCE
    iyret
endif

    playmusiccont1:
	ld c,(ix+0)
	ld a,c
	or a
	jp z, playmusicend ; we are done

    playmusiccont2:
	ld b,(ix+1)
	ld a,1
	out (0FFh), a

    playmusicloop1:
	djnz playmusicloop1
	
	ld b,(ix+1)
	ld a,2
	out (0ffH), a

    playmusicloop2:
	djnz playmusicloop2

    playmusicloop3:
	dec c
	jp nz, playmusiccont2

	ld a,(ix+1)

    playmusiccont3:
	inc ix
	inc ix

	ld bc,-1
	ld hl,30h

    playmusicloop4:
	add hl,bc
	jp c,playmusicloop4
	jp playmusiccont1

    playmusicend:
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

bit0notes:
	db 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit1notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit2notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit3notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit4notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit5notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit6notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h, 60h,40h, 0F0h,50h
	db 0h,0h ;end

bit7notes:
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h
	db 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0F0h,50h, 60h,40h, 0f0h,0c0h
	db 0h,0h ;end
