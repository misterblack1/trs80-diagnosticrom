; memory test by Frank IZ8DWF method
; vim: ts=8

; test memory
; parameters:
; 	hl = start of ram to test
; 	bc = count of bytes to test
; 	a = 0 for regular test, >0 to start with complemented data (increase sequence length)
;	e = bits already found in error for this block
; returns:
;	e = bits in error updated
; 	carry flag = set if error, clear if test good
; 	if error, then:
; 		hl = address of ram detected bad if error
; 		a = bitmap showing which bits were in error
memtestrndwrite:
		link_loadregs_all
	.fillram:
		cp 00h
		jp nz,.wfn		; on second pass, start with complemented data
	.wf:
		ld ix,_random		; random data start
		ld d,251d		; size of random data
	.writef:
		ld a,(ix+0)
		ld (hl),a		; copy A to byte pointed by HL
		cpi			; increments HL, decrements BC (and does a CP)
		jp po,.endwrite		; we wrote all the available ram space
		inc ix			; increments the random data pointer
		dec d
		jp z,.wb		; jump to next "random mode"
		jp .writef		; 

	.wb:
		ld ix,_random+250d	; random data end
		ld d,251d		; size of random data
	.writeb:
		ld a,(ix+0)
		ld (hl),a		; copy A to byte pointed by HL
		cpi			; increments HL, decrements BC (and does a CP)
		jp po,.endwrite		; we wrote all the available ram space
		dec ix			; here we copy "backwards"
		dec d
		jp z,.wfn		; jump to next "random mode"
		jp .writeb		; 
	.wfn:
		ld ix,_random		; random data start
		ld d,251d		; size of random data
	.wrifn:	
		ld a,(ix+0)
		neg			; complement the read byte
		ld (hl),a		; copy A to byte pointed by HL
		cpi			; increments HL, decrements BC (and does a CP)
		jp po,.endwrite		; we wrote all the available ram space
		inc ix			; increments the random data pointer
		dec d
		jp z,.wbn		; jump to next "random mode"
		jp .wrifn		; 
	.wbn:
		ld ix,_random+250d	; random data end
		ld d,251d		; size of random data
	.wribn:	
		ld a,(ix+0)
		neg			; complement the read byte
		ld (hl),a		; copy A to byte pointed by HL
		cpi			; increments HL, decrements BC (and does a CP)
		jp po,.endwrite		; we wrote all the available ram space
		dec ix			; here we copy "backwards"
		dec d
		jp z,.wf		; jump to first "random mode"
		jp .wribn		; 

	.endwrite:			; now we compare what has been written
		link_loadregs_all
		cp 00h
if SIMERROR_RND
		ld (hl),0c5h
endif
		jp nz,.cfn		; on second pass, start with complemented data 
	.cf:
		ld ix,_random		; random data start
		ld d,251d		; size of random data
	.cpf:	
		ld a,(ix+0)
		cpi			; compares (HL) against A, inc HL, dec BC
		jp nz,.memerr		; a non zero flag means a ram error (address is HL-1)
		jp po,.endread		; we checked all the available ram space: loop (or exit)
		dec d
		jp z,.cb		; jump to next "random mode"
		inc ix
		jp .cpf
	.cb:
		ld ix,_random+250d	; random data end
		ld d,251d		; size of random data
	.cpb:	
		ld a,(ix+0)
		cpi			; compares (HL) against A, inc HL, dec BC
		jp nz,.memerr		; a non zero flag means a ram error (address is HL-1)
		jp po,.endread		; we checked all the available ram space: loop (or exit)
		dec d
		jp z,.cfn		; jump to next "random mode"
		dec ix			; random data backwards mode
		jp .cpb
	.cfn:
		ld ix,_random		; random data start
		ld d,251d		; size of random data
	.cpfn:	
		ld a,(ix+0)
		neg
		cpi			; compares (HL) against A, inc HL, dec BC
		jp nz,.memerr		; a non zero flag means a ram error (address is HL-1)
		jp po,.endread		; we checked all the available ram space: loop (or exit)
		dec d
		jp z,.cbn		; jump to next "random mode"
		inc ix 
		jp .cpfn
	.cbn:
		ld ix,_random+250d	; random data end
		ld d,251d		; size of random data
	.cpbn:
		ld a,(ix+0)
		neg
		cpi			; compares (HL) against A, inc HL, dec BC
		jp nz,.memerr		; a non zero flag means a ram error (address is HL-1)
		jp po,.endread		; we checked all the available ram space: loop (or exit)
		dec d
		jp z,.cf		; get back to the first "random mode"
		dec ix			; random data backwards mode
		jp .cpbn

	.endread: 


	.memgood:
		or a			; clear carry flag
		iyret

	.memerr:
		dec hl			; get the correct error address 
		xor (hl)		; calculate which bits were bad
		or e
		ld e,a			; store bits back into register e
		scf
		iyret



_random:
	db 0C4h, 0CAh, 0C0h, 07Eh, 05Ah, 061h, 029h, 049h, 08Eh, 02Dh
	db 08Bh, 0EAh, 0C5h, 030h, 002h, 031h, 0B3h, 0A7h, 0CEh, 02Fh
	db 0FBh, 052h, 036h, 007h, 09Eh, 0C5h, 0EAh, 0EFh, 06Ah, 00Bh
	db 0F6h, 07Ah, 02Bh, 0EAh, 0CBh, 0BCh, 023h, 0C9h, 06Dh, 058h
	db 048h, 0D9h, 0E5h, 096h, 0FFh, 0D9h, 015h, 078h, 07Ch, 01Fh
	db 058h, 04Ch, 0BEh, 04Fh, 0F4h, 0EDh, 0BEh, 0F1h, 0B6h, 0F4h
	db 0D5h, 0C2h, 024h, 012h, 042h, 0A0h, 089h, 06Dh, 0ECh, 017h
	db 0DAh, 075h, 0A5h, 0DCh, 021h, 0B0h, 0F7h, 02Bh, 012h, 0B5h
	db 0BFh, 02Ah, 0D6h, 0DDh, 036h, 049h, 0DDh, 0CBh, 0F6h, 010h
	db 0D5h, 095h, 00Eh, 0DEh, 029h, 048h, 02Bh, 07Bh, 062h, 0F7h
	db 018h, 0C1h, 023h, 03Bh, 0C3h, 045h, 086h, 067h, 09Eh, 04Eh
	db 05Ah, 0ACh, 0A0h, 057h, 09Fh, 0AEh, 016h, 06Dh, 013h, 01Eh
	db 005h, 0E1h, 001h, 07Fh, 096h, 07Ch, 0B8h, 027h, 082h, 090h
	db 07Fh, 02Ah, 0CDh, 0C2h, 02Eh, 05Bh, 053h, 04Eh, 043h, 092h
	db 0CBh, 0C8h, 0E5h, 07Ch, 0A0h, 02Ch, 079h, 0BFh, 09Fh, 098h
	db 0F8h, 0F8h, 04Eh, 045h, 0E9h, 050h, 00Dh, 0E8h, 0A7h, 042h
	db 01Fh, 0C8h, 094h, 044h, 077h, 00Dh, 0CCh, 011h, 0DFh, 0F7h
	db 07Ah, 064h, 014h, 038h, 0B0h, 00Fh, 02Ah, 06Ah, 0E0h, 012h
	db 0D5h, 09Ch, 037h, 0C1h, 019h, 0DAh, 0BBh, 09Eh, 0F8h, 092h
	db 0D1h, 007h, 07Eh, 0B6h, 031h, 09Fh, 0C0h, 0E3h, 038h, 0F5h
	db 01Bh, 05Dh, 098h, 0ACh, 007h, 009h, 06Fh, 09Ch, 091h, 0E0h
	db 033h, 04Dh, 091h, 015h, 053h, 02Bh, 00Ch, 0BDh, 0BFh, 04Bh
	db 0B6h, 00Ah, 0DCh, 045h, 011h, 080h, 0F9h, 08Dh, 0D2h, 0BEh
	db 05Bh, 0F0h, 00Eh, 031h, 071h, 031h, 02Ch, 0E2h, 0E5h, 003h
	db 0BBh, 0BCh, 092h, 09Bh, 0A0h, 0F7h, 0C0h, 00Bh, 002h, 0F9h
	db 01Bh
