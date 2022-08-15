; Requirements:
; This function must be RELOCATABLE (only relative jumps), and use NO RAM or STACK.


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
;	iy = test data structure
; returns:
;	e = all errored bits found in this block/bank/range of memory
; destroys: a,bc,d,hl
; preserves: ix

_loadregs .macro
		ld c,(iy+0)
		ld b,(iy+1)
		ld l,(iy+2)
		ld h,(iy+3)
.endm

spt_memtestmarch:
		pop iy
		; ld e,0

memtestmarch:
		ld d,0				; set the first testing value to 0
	mtm1:
		_loadregs
	mtm1loop:				; fill initial value upwards
		ld (hl),d
		inc hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm1loop			; not $FF, keep going
		cp c
		jr nz,mtm1loop			; not $FF, keep going
		; cpi
		; jp pe, mtm1loop
	mtm2:					; read value, write complement upwards
		_loadregs
	mtm2loop:
		ld a,(hl)
		cp d				; compare to value
		jr z, mtm2cont			; memory changed, report
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		cp $ff				; if we have already found all bits bad
		jr z,mtm_done_bounce			; then quit
		ld a,d				; reload a with correct value
	mtm2cont:
		cpl				; take the complement
		ld (hl),a			; write the complement
		inc hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm2loop			; not $FF, keep going
		cp c
		jr nz,mtm2loop			; not $FF, keep going
		; cpi
		; jp pe,mtm2loop			; repeat for all testing area
		
	mtm3:					; read complement, write original value upwards
		_loadregs
	mtm3loop:
		ld a,(hl)
		cpl
		cp d				; compare to the complement
		jr z, mtm3cont			; memory changed, report
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		cp $ff				; if we have already found all bits bad
		jr z,mtm_done_bounce			; then quit
		ld a,d
	mtm3cont:
		ld (hl),d			; fill with test value
		ld a,$FF			; keep going so long as bc doesn't become -1 ($FFFF)
		inc hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm3loop			; not $FF, keep going
		cp c
		jr nz,mtm3loop			; not $FF, keep going
		; cpi
		; jp pe, mtm3loop
		jr mtm4
	
	mtm_done_bounce:
		jr mtm_done
	mtm1_bounce:
		jr mtm1

	mtm4:					; read test value, write complement downwards
		_loadregs
		add hl,bc			; move to end of the test area
		dec hl
	mtm4loop:
		ld a,(hl)
		cp d				; compare to value
		jr z, mtm4cont
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		cp $ff				; if we have already found all bits bad
		jr z,mtm_done			; then quit
		ld a,d
	mtm4cont:
		cpl				; take the complement
		ld (hl),a			; write complement
		dec hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm4loop			; not $FF, keep going
		cp c
		jr nz,mtm4loop			; not $FF, keep going
		; cpd
		; jp pe, mtm4loop

	mtm5:					; read complement, write value downwards
		_loadregs
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
		cp $ff				; if we have already found all bits bad
		jr z,mtm_done			; then quit
		ld a,d
	mtm5cont:
		ld (hl),d
		dec hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm5loop			; not $FF, keep going
		cp c
		jr nz,mtm5loop			; not $FF, keep going
		; cpd
		; jp pe, mtm5loop
	
	mtm6:					; final check that all are zero
		_loadregs
		add hl,bc			; move to end of the test area
		dec hl
	mtm6loop:
		ld a,(hl)
		cp d
		jr z,mtm6cont
		xor d				; calculate errored bits
		or e				
		ld e,a				; save error bits to e
		cp $ff				; if we have already found all bits bad
		jr z,mtm_done			; then quit
		ld a,d
	mtm6cont:
		dec hl
		dec bc
		xor a				; keep going so long as bc doesn't become -1 ($FFFF)
		cp b
		jr nz,mtm6loop			; not $FF, keep going
		cp c
		jr nz,mtm6loop			; not $FF, keep going
		; cpd
		; jp pe,mtm6loop

	mtmredo:
		ld a,d	
		cp 0				; if our test value is 0
		ld d,$55
		jr z,mtm1_bounce		; then rerun the tests with value $55

	mtm_done:
		sub a				; set carry flag if e is nonzero
		or e
	mtm_return:
		ret z
		scf
		ret

;-----------------------------------------------------------------------------
