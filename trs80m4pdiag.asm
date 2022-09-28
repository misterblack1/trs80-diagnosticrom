; code: language=asm-collection tabSize=8

VBASE  equ $3C00
VSIZE  equ $0400
VLINE  equ 64

.include "inc/z80.mac"
.include "inc/spt.mac"
.include "inc/m4p.inc"

; Notes on global register allocation:
;
; This ROM doesn't work like typical Z80 code, which assumes the presence of a stack.
; There may in fact be no working memory in the machine for holding the stack.
;
; An overall goal for this version of the code is to run in the absence of any working
; ram at all.  There is no stack and no RAM variables.  The only storage of variables
; is in registers, so the registers must be carefully preserved.
;
; Without a stack, that means either saving them to other registers and restoring before 
; jumping to other code (remembering there can be no CALLs when there is no stack) 
; or avoiding their use altogether.  These are extremely confining restrictions.
;
; Assembly purists will shudder at the extensive use of macros, but for sanity it
; cannot be avoided.
;
; Globally, the contents of these registers must be preserved
;	e = bit errors in the region of memory currently being tested
;	ix = current location in VRAM for printing messages
;	iy = current table entry for test parameters
;

REG_CRTC_ADDR	equ	$88
REG_CRTC_DATA	equ	$89


		.org 0000h				; z80 boot code starts at location 0
reset:
		di					; mask INT
		im	1				; use interrupt mode 1 for safety (Z80 was set to IM 0 by RESET)

	.m4p_init:
		xor	a				; Initialization continues here
		out	($E4),a				; NMI (external) mask -- no NMIs, please
		ld	a,$50				; Use 4 MHz clock, enable I/O bus
		out	($EC),a

		ld	a,$D0				; Terminate command w/o interrupt
		out	($F0),a				; to FDC

	.m4p_init_crtc:
		ld	c,REG_CRTC_ADDR			; CRTC Address Register
		ld	b,16				; Number of CRTC registers to program
		ld	hl,crtc_setup_table+15		; Point to data for register 15
	.crtclp:
		ld	a,(hl)				; Get data for CRTC register
		out	(c),b				; Send register number to CRTC addr register
		out	(REG_CRTC_DATA),a		; Send data to CRTC data register
		dec	hl				; Point to next byte of data
		djnz	.crtclp				; BUG: (this should be R0) Repeat for next register, down to R1


test_vram:
		SPTHREAD_BEGIN				; set up to begin running threaded code
		dw spt_playmusic, tones_welcome

		dw crtc_80p0
		dw spt_chartest
		dw crtc_80p1
		dw spt_chartest
		dw spt_pause, $0000
		dw spt_pause, $0000
		dw spt_pause, $0000
		dw spt_pause, $0000
		dw spt_pause, $0000
		dw spt_pause, $0000

		dw vram_map_p0
		dw spt_select_test, tp_vram0
		dw memtestmarch				; test the VRAM
		dw spt_jp_nc, .vram0_ok

	.vram_bad:
		dw spt_chartest
	.vram_bad_loop:
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_pause, $0000
		dw spt_jp,.vram_bad_loop

	.vram0_ok:
		dw spt_prepare_display
		MAC_SPT_CON_GOTO 1,0
		dw spt_announcetest 			; print results of VRAM tst
		dw spt_con_print, msg_testok
		dw spt_playmusic, tones_vramgood	; play the VRAM good tones

		dw vram_map_p1
		dw spt_select_test, tp_vram1
		dw memtestmarch				; test the VRAM
		dw spt_jp_nc, .vram1_ok
		dw vram_map_p0
		dw spt_jp, .vram_bad
	
	.vram1_ok:
		dw vram_map_p0
		MAC_SPT_CON_GOTO 2,0
		dw spt_announcetest 			; print results of VRAM tst
		dw spt_con_print, msg_testok
		dw spt_playmusic, tones_vramgood	; play the VRAM good tones


	.test_dram:
		dw map_dram0
		dw spt_select_test, tp_dram_lo		; load the first test
		MAC_SPT_CON_GOTO 4,0

	.loop:
		dw spt_call, sptc_runtest

		dw map_dram2
		dw spt_select_test, tp_bank_lo		; load the first test
		dw spt_call, sptc_runtest

		dw map_dram3
		dw spt_select_test, tp_bank_hi		; load the first test
		dw spt_call, sptc_runtest


	; .cont:
	; 	; dw spinhalt
		dw spt_tp_next, .test_dram
		dw spt_jp, .loop

	
	.halt:	dw spinhalt

spinhalt:
	.here:	jr .here


sptc_runtest:
		dw spt_announcetest 			; announce what test we are about to run
		dw memtestmarch				; test the current bank
		dw spt_jp_nc, .ok
		
		dw spt_con_print, msg_biterrs		; we have errors: print the bit string
		dw print_biterrs
		dw spt_play_testresult			; play the tones for bit errors
		dw spt_jp, .cont
	
	.ok:
		dw spt_con_print, msg_testok		; bank is good: print the OK message
		dw spt_play_testresult			; play the tones

	.cont:
		dw spt_exit


spt_prepare_display:
		SPTHREAD_ENTER
		dw con_clear
		dw spt_con_print, msg_banner		; print the banner
		dw con_NL
		dw spt_print_charset
		dw spt_exit


crtc_64:
		ld	a,OPREG_64
		out	(IOW_OPREG),a
		ret

crtc_80p0:
		ld	a,OPREG_80
		out	(IOW_OPREG),a
		ret

crtc_80p1:
		ld	a,OPREG_80|OPREG_VIDPAGE_1
		out	(IOW_OPREG),a
		ret

vram_map_p1
		ld	a,OPREG_VIDPAGE_1
		out	(IOW_OPREG),a
		ret
vram_map_p0:
		ld	a,0		; enable video memory access
		out	(IOW_OPREG),a
		ret

map_dram0:	
		xor	a		; send all zeros to OPREG to reset to mode 0 with ROM
		out	(IOW_OPREG),a
		ret

map_dram2:	ld	a,OPREG_DESPAGE_UPPER|OPREG_SRCPAGE_LOWER|OPREG_ENPAGE
		out	(IOW_OPREG),a
		ret

map_dram3:	ld	a,OPREG_DESPAGE_UPPER|OPREG_SRCPAGE_UPPER|OPREG_ENPAGE
		out	(IOW_OPREG),a
		ret


; load the label string address from the current test parameter table entry into hl
spt_ld_hl_tp_label:
		ld	l,(iy+TP_LABEL)
		ld	h,(iy+TP_LABEL+1)
		ret


; load the label string address from the current test parameter table entry into hl
spt_ld_hl_tp_tones:
		ld	l,(iy+TP_TONES)
		ld	h,(iy+TP_TONES+1)
		ret

; move to the next test parameter table entry
spt_tp_next:	pop	hl				; get the address to jump to if we are starting over
		ld 	bc,tp_entrysize			; find the next entry
		add 	iy,bc
		ld	a,(iy+TP_SIZE)			; is the length zero?
		add	a,(iy+TP_SIZE+1)
		ret	nz				; no, use it
		ld	c,(iy+TP_GOTO)			; yes, get the address of the first entry
		ld	b,(iy+TP_GOTO+1)
		ld	iy,0
		add	iy,bc
		; sub	a				; clear zero flag when restarting
		ld	sp,hl				; jump to the next location
		ret



spt_announcetest:
		; pop	hl				; get the message to be printed
		SPTHREAD_ENTER

		dw con_NL
		dw spt_ld_hl_tp_label
		dw con_print				; picks up message from hl
		dw spt_con_print, msg_testing
		dw spt_con_index, -status_backup
		dw spt_exit


print_biterrs:
		ld	a,'7'
		ld	b,8
	.showbit:
		rlc	e
		jr	nc,.zero
		ld	(ix+0),a
		jr	.cont
	.zero:
		ld	(ix+0),'.'
	.cont:
		inc	ix
		dec	a
		djnz	.showbit

		ret







spt_ld_bc:	pop 	bc
		ret

spt_print_charset:
		ld	a,ixh
		ld	h,a
		ld	a,ixl
		ld	l,a
		ld	a,0
		SPTHREAD_ENTER
		MAC_SPT_CON_GOTO 11,24
		dw spt_con_print, msg_charset		; show a copy of the character set
		MAC_SPT_CON_GOTO 12,0
		dw spt_ld_bc, $100
		dw do_charset_ix
		dw spt_exit

spt_chartest:
		ld	ix,VBASE
		ld	bc,VSIZE
		ld	a,0
do_charset_ix:
	.charloop:
		ld	(ix+0),a	; copy A to byte pointed by HL
		inc	a		; increments A
		inc	ix
		cpi			; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret




spt_play_testresult:
		SPTHREAD_SAVE				; save the stack pointer

		SPTHREAD_BEGIN
		dw spt_ld_hl_tp_tones			; play the ID tune for current bank
		dw playmusic
		dw spt_pause, $2000
		SPTHREAD_END

		ld	a,$FF
		cp	e
		jr	z,.allbad			; if all bits bad, play shorter tune

		cpl
		cp	e
		jr	z,.allgood			; if all bits good, play shorter tune

		ld	d,8				; play bit tune for each bit, high to low
	.showbit:
		rlc	e
		jr	nc,.zero
		ld	hl,tones_bitbad
		jr	.msbe_cont
	.zero:
		ld	hl,tones_bitgood
	.msbe_cont:
		SPTHREAD_BEGIN
		dw playmusic
		dw spt_pause, $2000
		SPTHREAD_END

		; pause $4000
		dec	d
		jr	nz,.showbit
		jr	.done
	.allbad:
		SPTHREAD_BEGIN
		dw spt_playmusic, tones_bytebad
		dw spt_pause, $8000
		SPTHREAD_END
		jr	.done
	.allgood:
		SPTHREAD_BEGIN
		dw spt_playmusic, tones_bytegood
		dw spt_pause, $8000
		SPTHREAD_END
	.done:
		SPTHREAD_RESTORE			; restore the stack pointer
		ret



spt_pause:							; pause by an amount specified in BC
		pop	bc
pause_bc:							; pause by BC*50-5+14 t-states
		ex	af,af'
	.loop:							
		nop12
		nop12
		dec	bc
		ld	a,b
		or	c
		jr	nz,.loop
		ex	af,af'
		ret





; V_END = (VBASE+VSIZE-1)



; msg_boot:	dbz "Booting "
; msg_hd:		dbz "HD"
; msg_fd:		dbz "FD"

labels_start:
msg_banner:	dbz " TRS-80 M4P TEST ROM -- FRANK IZ8DWF / DAVE KI3V / ADRIAN BLACK"
msg_charset:	dbz "-CHARACTER SET-"
label_vram0:	dbz " 1K VRAM P0 3C00-3FFF "
label_vram1:	dbz " 1K VRAM P1 3C00-3FFF "
label_dram_lo:	dbz "48K Lo DRAM 4000-FFFF "

label_bank_lo:	dbz "32K Bank Lo 8000-FFFF "
label_bank_hi:	dbz "32K Bank Hi 8000-FFFF "

msg_testok:	dbz	" --OK-- "
; msg_reloc:	dbz	"(reloc) "
msg_skipped:	dbz	" *skip* "
msg_biterrs:	dbz	" errors:"
msg_absent:	dbz	" absent:"
msg_testing:	dbz	" .TEST. "
; msg_testing:	db " ", " "+$80, "t"+$80, "e"+$80, "s"+$80, "t"+$80, " "+$80, " ", 0
status_backup equ $-msg_testing-1

; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. address of string for announcing test
; 4. address of tones for identifying the test audibly
tp_entrysize	equ	8

memtest_ld_bc_size .macro
		ld	c,(iy+TP_SIZE)
		ld	b,(iy+TP_SIZE+1)
.endm

memtest_ld_hl_base .macro
		ld	l,(iy+TP_BASE)
		ld	h,(iy+TP_BASE+1)
.endm

memtest_loadregs .macro
		memtest_ld_bc_size
		memtest_ld_hl_base
.endm



TP_SIZE equ 0
TP_BASE equ 2
; TP_BANK equ 2
TP_LABEL equ 4
; TP_POS equ 4
TP_TONES equ 6
TP_GOTO equ 2



tp_vram0:	dw	VSIZE, VBASE, label_vram0, tones_vram
tp_vram1:	dw	VSIZE, VBASE, label_vram1, tones_vram

tp_dram_lo:	dw	$C000, $4000, label_dram_lo, tones_id1
; tp_dram1:	dw	$8000, $8000, label_dram1, tones_id2
tp_bank_lo:	dw	$8000, $8000, label_bank_lo, tones_id2
tp_bank_hi:	dw	$8000, $8000, label_bank_hi, tones_id3
		dw	$0000, tp_dram_lo



.include "inc/memtestmarch.asm"


; .include "inc/trs80m2fdcboot.asm"
.include "inc/spt.asm"
.include "inc/trs80m13con.asm"
include "inc/trs80music.asm"


; tones_id4:	db	$40,$60
; 		db	$10,$00 ;rest
; 		db	$40,$60
; 		db	$10,$00 ;rest
; 		db	$40,$60
; 		db	$10,$00 ;rest
; 		db	$40,$60
; 		db	$60,$00 ;rest
; 		db	$00,$00 ;end


crtc_setup_table:
		dc	16,0		; in model 4, this is a dummy table
