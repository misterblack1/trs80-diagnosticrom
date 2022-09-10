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

memtestmarch:
		xor	a
		ld	e,a			; reset error accumulator
		ld	d,a			; set the first testing value to 0

	checkabsent:					; quick test for completely missing bank
		memtest_ld_hl_base
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
		jr	mtm1
	.allbad:
		ld	e,$FF			; report all bits bad
		jr	mtm_done_bounce

	mtm1:
		memtest_loadregs
	mtm1loop:				; fill initial value upwards
		ld	(hl),d
		inc	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm1loop
	mtm2:					; read value, write complement upwards
		memtest_loadregs
	mtm2loop:
		ld	a,(hl)
		cp	d			; compare to value
		jr	z, mtm2cont		; memory changed, report
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		; ; cp	$FF
		; inc	a
		; jr	z,mtm_done_bounce	; quit early if all bits bad (a was $FF)
		ld	a,d			; reload a with correct value
	mtm2cont:
		cpl				; take the complement
		ld	(hl),a			; write the complement
		inc	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm2loop
		
	mtm3:					; read complement, write original value upwards
		memtest_loadregs
	mtm3loop:
		ld	a,(hl)
		cpl
		cp	d			; compare to the complement
		jr	z, mtm3cont		; memory changed, report
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		; ; cp	$FF
		; inc	a
		; jr	z,mtm_done_bounce	; quit early if all bits bad (a was $FF)
		ld	a,d			; reload a with correct value
	mtm3cont:
		ld	(hl),d			; fill with test value
		inc	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm3loop
		jr	mtm4
	
	mtm_done_bounce:
		jr	mtm_done
	mtm1_bounce:
		jr	mtm1

	mtm4:					; read test value, write complement downwards
		memtest_loadregs
		add	hl,bc			; move to end of the test area
		dec	hl
	mtm4loop:
		ld	a,(hl)
		cp	d			; compare to value
		jr	z, mtm4cont
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		; ; cp	$FF
		; inc	a
		; jr	z,mtm_done	; quit early if all bits bad (a was $FF)
		ld	a,d			; reload a with correct value
	mtm4cont:
		cpl				; take the complement
		ld	(hl),a			; write complement
		dec	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm4loop

	mtm5:					; read complement, write value downwards
		memtest_loadregs
		add	hl,bc			; move to end of the test area
		dec	hl
	mtm5loop:
		ld	a,(hl)
		cpl
		cp	d
		jr	z, mtm5cont
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		; ; cp	$FF
		; inc	a
		; jr	z,mtm_done	; quit early if all bits bad (a was $FF)
		ld	a,d			; reload a with correct value
	mtm5cont:
		ld	(hl),d
		dec	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm5loop
	
	mtm6:					; final check that all are zero
		memtest_loadregs
		add	hl,bc			; move to end of the test area
		dec	hl
	mtm6loop:
		ld	a,(hl)
		cp	d
		jr	z,mtm6cont
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		; ; cp	$FF
		; inc	a
		; jr	z,mtm_done	; quit early if all bits bad (a was $FF)
		ld	a,d			; reload a with correct value
	mtm6cont:
		dec	hl
		dec	bc
		ld	a,c
		or	b
		jr	nz,mtm6loop

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

memtestmarch_end equ $
;-----------------------------------------------------------------------------
