.include "inc/trs80diag.mac"


; SIMERROR_MARCH++
; SIMERROR_RND++
; SILENCE++

VBASE  equ 3c00h
VSIZE  equ 0400h
VLINE  equ 64
VREPEAT equ 2

VSTACK equ VBASE+VSIZE

DBASE  equ 04000H
DSIZE  equ 0C000H
DREPEAT equ 1h


        .org 0000h
reset:
        di		; mask INT
        im 1
        music welcomemusic
        jp diagnostics

; interrupt vectors: these need to be located at 38h and 66h, so there is little
; code space before them.  They should probably be present so that any incoming interrupts
; won't kill the test routines.  The INT vector is probably unnecessary but the NMI should
; be present. Put the main program after them; we've got 8k to work with for the main ROM.

        dc 0038h-$,0ffh ; fill empty space
        org 0038h	; INT vector
intvec: reti

        dc 0066h-$,0ffh ; fill empty space
        org 0066h	; NMI vector
nmivec: retn



;; main program
diagnostics:
        ld a,0
        out ($EC), a   ; set 64 char mode	

        ld a, 0	    ; byte to be written goes in A
        out (0f8h),a	; blank printer port for now

        ld a,($3800)    ; poke the keyboard
	
        iycall chartest ; show all characters on the screen

test_vram:
        ; jr .vramok    ; for testing, we can skip the vram test (in case we are forcing a simluated error)
	ld e,0
        link_memtest memtestmarch, VBASE, VSIZE, 00h
        jr c,.vrambad
        link_memtest memtestmarch, VBASE, VSIZE, 55h
        jr c,.vrambad
        jr .vramok

    .vrambad:
        music sadvram
        iycall chartest
        haltcpu


    .vramok:
        ld sp, VSTACK

        call con_clear
        call con_home
        ld hl,bannermsg
        call con_println
        ld hl,vramgoodmsg
        call con_print
        ld hl,ramstartmsg
        call con_println


test_dram:
        ld a,2
        call con_row

        link_memtest_block 04000h,04000h
        link_memtest_block 08000h,04000h
        link_memtest_block 0C000h,04000h
        link_memtest_block 04000h,0c000h
        jp test_dram



;; -------------------------------------------------------------------------------------------------
;; end of main program.


vram_report:

announceblock:
        call con_NL
        call printrange
        ret
    
announcetest:
        call con_print
        push ix
        ld hl,testingmsg
        call con_print
        pop ix
        ret




reportmem:
        call c,reportmemerr
        call nc,reportmemgood
        ; call con_NL
        ret


reportmemgood:
        ld hl,okmsg
        call con_print

        push ix
        music happymusic
        pop ix
        ret

reportmemerr:
	ld a,e
        call con_printb

        push ix
	music sadmusic
        pop ix
        scf
        ret

printhlx:
        push af
        ld a,h
        call con_printx ; print bad address high byte
        ld a,l
        call con_printx ; print bad address low byte
        pop af
        ret

printrange:     ; print HX "-" (HX)+BC-1 to indicate range of an operation
        push af
        call printhlx
        ld a,'-'
        call con_printc
        push hl
        dec hl
        add hl,bc
        call printhlx
        pop hl
        pop af
        ret


; Fill screen with hex 0h to ffh over and over again. Should see all possible characters. 
chartest:
        ld hl,VBASE	; start of video ram
        ld bc,VSIZE	; video ram size - 1kB

    .charloop:
        ld (hl),a	; copy A to byte pointed by HL
        inc a		; increments A
        cpi		    ; increments HL, decrements BC (and does a CP)
        jp pe, .charloop

        iyret


include "inc/memtest-rnd.asm"
include "inc/memtest-march.asm"
include "inc/trs80con.asm"
include "inc/trs80music.asm"


rndtestname:    db "  iz8dwf/rnd  ", 0
marchtestname:  db "  ki3v/march  ", 0
vramgoodmsg:    defb "VRAM good! Using VRAM for CPU stack.  ", 0
bannermsg:      defb "TRS-80 M1/M3 Test ROM - Frank IZ8DWF / Dave KI3V / Adrian Black", 0
ramstartmsg:    defb "Testing DRAM.", 0
ramgoodmsg:     defb "DRAM tests good!! Have a nice day.", 0
rambadmsg:      defb "DRAM problem found. Do you have 48k? HALTED!", 0
testingmsg:     defb "testing ", 0
okmsg:          defb "OK!     ", 0
haltmsg:        defb "Halted.", 0
