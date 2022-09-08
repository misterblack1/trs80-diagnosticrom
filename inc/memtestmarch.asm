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
		ld	e,0			; reset error accumulator
		ld	d,0			; set the first testing value to 0
	mtm1:
		memtest_loadregs
	mtm1loop:				; fill initial value upwards
		ld	(hl),d
		inc	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm1loop		; not $FF, keep going
		cp	c
		jr	nz,mtm1loop		; not $FF, keep going
	mtm2:					; read value, write complement upwards
		memtest_loadregs
	mtm2loop:
		ld	a,(hl)
		cp	d			; compare to value
		jr	z, mtm2cont		; memory changed, report
		xor	d			; calculate errored bits
		or	e				
		ld	e,a			; save error bits to e
		cp	$FF			; if we have already found all bits bad
		jr	z,mtm_done_bounce	; then quit
		ld	a,d			; reload a with correct value
	mtm2cont:
		cpl				; take the complement
		ld	(hl),a			; write the complement
		inc	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm2loop		; not $FF, keep going
		cp	c
		jr	nz,mtm2loop		; not $FF, keep going
		
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
		cp	$FF			; if we have already found all bits bad
		jr	z,mtm_done_bounce	; then quit
		ld	a,d			; reload a with correct value
	mtm3cont:
		ld	(hl),d			; fill with test value
		inc	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm3loop		; not $FF, keep going
		cp	c
		jr	nz,mtm3loop		; not $FF, keep going
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
		cp	$ff			; if we have already found all bits bad
		jr	z,mtm_done		; then quit
		ld	a,d			; reload a with correct value
	mtm4cont:
		cpl				; take the complement
		ld	(hl),a			; write complement
		dec	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm4loop		; not $FF, keep going
		cp	c
		jr	nz,mtm4loop		; not $FF, keep going

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
		cp	$ff			; if we have already found all bits bad
		jr	z,mtm_done		; then quit
		ld	a,d			; reload a with correct value
	mtm5cont:
		ld	(hl),d
		dec	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm5loop		; not $FF, keep going
		cp	c
		jr	nz,mtm5loop		; not $FF, keep going
	
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
		cp	$ff			; if we have already found all bits bad
		jr	z,mtm_done		; then quit
		ld	a,d			; reload a with correct value
	mtm6cont:
		dec	hl
		dec	bc
		xor	a			; keep going so long as bc doesn't become 0
		cp	b
		jr	nz,mtm6loop		; not $FF, keep going
		cp	c
		jr	nz,mtm6loop		; not $FF, keep going

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
