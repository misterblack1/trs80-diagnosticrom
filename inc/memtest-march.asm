

;; test ram using march algorithm
;;  hl = current memory position under test (l is cleared... always start beginning of page)
;;  bc = bytes remaining to test (c is ignored... always test whole pages)
;;  a = value to test (useful cases: 0, 55h)
;; algorithm:
;;  write each location bottom to top with test value
;;  read each location bottom to top, compare to test value, then write complement
;;  read each location bottom to top, compare to complement, then write test value
;;  read each location top to bottom, compare to test value, then write complement
;;  read each location top to bottom, compare to complement, then write test value
;;  read each location top to bottom, compare to test value
memtestmarch:
        link_loadregs_all

        ld d,a              ; save normal and negated versions of the test value
        cpl                 ; create the complement
        ld e,a

    .fillloop:                  ; fill initial value upwards
        ld (hl),d
        cpi
        jp pe, .fillloop
    
    .up01:                  ; read value, write complement upwards
        link_loadregs
    .up01loop:                  
        ld a,(hl)
        cp d                ; compare to value
        jr nz, .bad0     ; memory changed, report
        ld (hl),e           ; write the complement
        cpi
        jp pe,.up01loop    ; repeat for all testing area
        
    .up10:                  ; read complement, write original value up
        link_loadregs
    .up10loop:
        ld a,(hl)
        cp e                ; compare to the complement
        jr nz, .bad1     ; memory changed, report
        ld (hl),d           ; fill with test value
        cpi
        jp pe, .up10loop
    
    .dn01:                  ; read test value, write complement down
        link_loadregs
        add hl,bc           ; move to end of the test area
        dec hl
    .dn01loop:
        ld a,(hl)
        cp d                ; compare to value
        jr nz, .bad0
        ld (hl),e           ; write complement
        cpd
        jp pe, .dn01loop

    .dn10:                  ; read ones, write zeros down
        link_loadregs
        add hl,bc           ; move to end of the test area
        dec hl
    .dn10loop:
        ld a,(hl)
        cp e
        jr nz, .bad1
        ld (hl),d
        cpd
        jp pe, .dn10loop
    
    .readzero:              ; final check that all are zero
        link_loadregs
        add hl,bc           ; move to end of the test area
        dec hl
if SIMERROR_MARCH
        ld (hl),42h         ; insert a synthetic error
endif
    .readzeroloop:
        ld a,(hl)
        cp d
        jp nz,.bad0
        cpd
        jp pe,.readzeroloop

    .done:
        iyret

    .bad0:
        xor d               ; calculate errored bits
        scf                 ; indicate error
        jr .done
    .bad1:
        xor e
        scf
        jr .done

