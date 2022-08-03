


;; algorithm:
;;  1: write each location bottom to top with test value
;;  2: read each location bottom to top, compare to test value, then write complement
;;  3: read each location bottom to top, compare to complement, then write test value
;;  4: read each location top to bottom, compare to test value, then write complement
;;  5: read each location top to bottom, compare to complement, then write test value
;;  6: read each location top to bottom, compare to test value

; test ram using march algorithm. Arguments:
;	hl = current memory position under test (l is cleared... always start beginning of page)
;	bc = bytes remaining to test (c is ignored... always test whole pages)
; returns:
;	e = all errored bits found in this block/bank/range of memory
; destroys: a,bc,d,hl
; preserves: ix

memtestmarch:
		ld d,0				; set the first testing value to 0
	mtm1:
		link_loadregs
	mtm1loop:				; fill initial value upwards
		ld (hl),d
		cpi
		jp pe, mtm1loop
	mtm2:					; read value, write complement upwards
		link_loadregs
	mtm2loop:                  
		ld a,(hl)
		cp d				; compare to value
		jr z, mtm2cont			; memory changed, report
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		ld a,d				; reload a with correct value
	mtm2cont:
		cpl				; take the complement
		ld (hl),a			; write the complement
		cpi
		jp pe,mtm2loop			; repeat for all testing area
		
	mtm3:					; read complement, write original value upwards
		link_loadregs
	mtm3loop:
		ld a,(hl)
		cpl
		cp d				; compare to the complement
		jr z, mtm3cont			; memory changed, report
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		ld a,d
	mtm3cont:
		ld (hl),d			; fill with test value
		cpi
		jp pe, mtm3loop
	
	mtm4:					; read test value, write complement downwards
		link_loadregs
		add hl,bc			; move to end of the test area
		dec hl
	mtm4loop:
		ld a,(hl)
		cp d				; compare to value
		jr z, mtm4cont
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		ld a,d
	mtm4cont:
		cpl				; take the complement
		ld (hl),a			; write complement
		cpd
		jp pe, mtm4loop

	mtm5:					; read complement, write value downwards
		link_loadregs
		add hl,bc			; move to end of the test area
		dec hl
	mtm5loop:
		ld a,(hl)
		cpl
		cp d
		jr z, mtm5cont
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		ld a,d
	mtm5cont:
		ld (hl),d
		cpd
		jp pe, mtm5loop
	
	mtm6:					; final check that all are zero
		link_loadregs
		add hl,bc			; move to end of the test area
		dec hl
if SIMERROR_MARCH
		ld a,r
		ld (hl),a			; insert a synthetic error
endif
	mtm6loop:
		ld a,(hl)
		cp d
		jr z,mtm6cont
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		ld a,d
	mtm6cont:
		cpd
		jp pe,mtm6loop

	mtmredo:
		ld a,d	
		cp 0				; if our test value is 0
		ld d,$55
		jp z,mtm1				; then rerun the tests with value $55

	mtm_done:
		sub a				; set carry flag if e is nonzero
		or e
		jr z,mtm_return
		scf
	mtm_return:
		iyret

