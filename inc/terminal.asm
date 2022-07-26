
con_row: ;; go to display line in reg a
        push af
        push bc
        ld b,0          ; put line num in bc
        ld c,a

        ld a,6          ; 80cols = shift left 6, 40 - shift left 5
    .shiftloop:
        sla c           ; 16-bit shift left
        rl b
        dec a
        jr nz, .shiftloop

        ld ix,VBASE     ; add this offset to the base
        add ix,bc

        pop bc
        pop af
        ret

con_col: ;; move to given column (reg a) in current line
        call con_CR
        push bc
        ld b,0
        ld c,a
        add ix,bc
        pop bc
        ret

con_CR: ;; carriage return on the current line
        push af
        ld a,ixl
        and 0c0h
        ld ixl,a
        pop af
        ret

con_NL: ;; go to the next line (includes return)
        call con_CR
        push af
        ld a,040h       ; forward a line (80 cols: 40h, 40 cols: 20h)
        call con_col
        pop af
        ret


con_println:
        call con_print
        call con_NL
        ret

;; display a message (Requires good VRAM; using VRAM as stack.  Does not require RAM.)
;;      (HL) = message location
;;      (IX) = screen memory location
;; TODO: try using CPIR
con_print:
        push hl

    .loop:
        ld a,(HL)       ; get message char
        or a            ; test for null
        jr z, .done     ; return if done
        ld (ix+0),A     ; store char
        inc ix          ; advance screen pointer
        inc hl          ; advance message pointer
        jr .loop        ; continue

    .done:
        pop hl
        ret

; print a single character
con_printc:
        ; push af
        ld (ix+0), a
        inc ix
        ; pop af
        ret


con_printb:
        push af
        push bc

        ld b,a
        ld c,8
    .printbit:
        ld a,'0'
        ; bit 7,b
        ; jr z,.zero
        rl b
        jr nc,.zero
        inc a
    .zero:
        call con_printc
        dec c
        jr nz,.printbit

        pop bc
        pop af
        ret

;; display a hex byte
;;      a = byte
;;      (ix) = screen memory location
con_printx:
        push af

        ; shift high nybble down and print
        srl a
        srl a
        srl a
        srl a
        call .printnybble

        ; mask low nybble and print
        pop af
        push af
        and 0fh
        call .printnybble
        
        pop af
        ret

    .printnybble:
        sub 0ah     ; is it a letter?
        jp p,.letter
        add '0'+0ah ; choose the number
        jr .print
    .letter:
        add 41h    ; choose the letter
    .print:
        call con_printc
        ret

con_home:
        ld ix,VBASE
        ret

con_clear:
        push bc
        push ix

        ld ix,VBASE
        ld bc,VSIZE-2
    .loop:
        ld (ix+0),20h
        inc ix
        cpi
        jp pe,.loop

        pop ix
        pop bc
        ret

com_clear_eol:
        push af
        push bc
        push ix

    .loop:
        ld (ix+0),20h
        cpi
        ld a,(1<<6)-1
        and ixl
        jp nz,.loop

        pop ix
        pop bc
        pop af
        ret

; hex:            defb "0123456789ABCDEF"