; code: language=asm-collection tabSize=8
; Requirements:
; This function must be RELOCATABLE (only relative jumps), and use NO RAM or STACK.
; These restrictions lead to somewhat long-winded, repetative code.

;; March C- algorithm:
;;  1: (up w0) write each location bottom to top with test value
;;  2: (up r0,w1) read each location bottom to top, compare to test value, then write complement
;;  3: (up r1,w0) read each location bottom to top, compare to complement, then write test value
;;  4: (dn r0,w1) read each location top to bottom, compare to test value, then write complement
;;  5: (dn r1,w0) read each location top to bottom, compare to complement, then write test value
;;  6: (dn r0) read each location top to bottom, compare to test value

; Arguments:
;	hl = current memory position under test
;	bc = bytes remaining to test
;	iy = test data structure
; returns:
;	e = all errored bits found in this block/bank/range of memory
; destroys: a,bc,d,hl
; preserves: ix


memtest_init:
		xor	a
		ld	e,a			; reset error accumulator
		ret

memtest_absent:
		ld	b,h
		ld	c,1
		cpl				; A := FF
	.redo	ld	(hl),a			; write FF to base
		cpl				; A := 0
		ld	(bc),a			; write 00 to base+1
		cp	(hl)			; compare to base (should be FF, should not match)
		jr	z,.allbad		; if they match, all bits are bad, but double-check
		cp	0			; are we on the first round?
		jr	z,.redo			; yes, redo with reversed bits
		ret				; didn't find missing ram, exit without error
	.allbad:
		ld	e,$FF			; report all bits bad
		ret

memtest_march_w_up:
	.loop:					; fill upwards
		ld	(hl),d
		inc	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,.loop
		ret

memtest_march_rw_up:
	.loop:
		ld	a,(hl)
		cp	d			; compare to value
		jr	z, .cont		; memory changed, report
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		ld	a,d			; reload a with correct value
	.cont:
		cpl				; take the complement
		ld	(hl),a			; write the complement
		inc	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,.loop
		ret
		
memtest_march_rw_dn:
		add	hl,bc			; move to end of the test area
		dec	hl
	.loop:
		ld	a,(hl)
		cp	d			; compare to value
		jr	z, .cont
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		ld	a,d			; reload a with correct value
	.cont:
		cpl				; take the complement
		ld	(hl),a			; write complement
		dec	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,.loop
		ret

memtest_march_r_dn:
		add	hl,bc			; move to end of the test area
		dec	hl
	.loop:
		ld	a,(hl)
		cp	d
		jr	z,.cont
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		ld	a,d			; reload a with correct value
	.cont:
		dec	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,.loop
		ret


	mtmredo:
		ld	a,d	
		cp	0			; if our test value is 0
		ld	d,$55
		jr	z,mtm1_bounce		; then rerun the tests with value $55

	mtm_done:
		sub	a			; set carry flag if e is nonzero
		or	e
	mtm_return:
		ret	z
		scf
		ret

memtest_march:
		xor	a
		ld	e,a			; reset error accumulator

		push	hl			; save the test regs
		push	bc

		call	memtest_absent
		

		ld	d,0

	.redo:	

memtest_split_end equ $
;-----------------------------------------------------------------------------
