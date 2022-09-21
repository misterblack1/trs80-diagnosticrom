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


	; .init_crtc:
	; 	ld	bc,$0FFC			; count $0F, port $FC crtc address reg
	; 	ld	hl,crtc_setup_table+crtc_setup_len-1
	; .loop:	ld	a,(hl)				; fetch bytes from setup table and send top to bottom
	; 	out	(c),b				; CRTC address register
	; 	out	($FD),a				; CRTC data register
	; 	dec	hl
	; 	dec	b
	; 	jp	p,.loop


test_vram:
		SPTHREAD_BEGIN				; set up to begin running threaded code
		dw vram_map_p1				; map in VRAM so we can print results
		; dw chartest_fullscreen
		dw con_clear
		dw chartest_once
		dw spinhalt

spinhalt:
	.here:	jr .here

vram_map_p1
		ld	a,$80		; enable video memory access
		jr	vram_apply
vram_map_p0:
		ld	a,$80		; enable video memory access
vram_apply:	out	($FF),a
		ret


sptc_print_charset:
		; MAC_SPT_CON_GOTO 20,-8
		; dw ld_a_0
		dw spt_charset_64_p16_start
		dw spt_charset_64_p16
		dw spt_charset_64_p16
		dw spt_charset_64_p16
		dw spt_exit

spt_charset_64_p16_start:
		ld	hl,VBASE+(VLINE*20)-8
		xor	a
spt_charset_64_p16:
		ld	bc,$10
		add	hl,bc
		ld	bc,$40
		; ld	bc,$10
		; add	ix,bc
		; ld	bc,$40
		jr	charset_here

chartest_once:
		xor	a
		ld	hl,VBASE
		ld	bc,$100
		jr	charset_here

chartest_fullscreen:
		xor	a
		ld	hl,VBASE
		ld	bc,VSIZE
charset_here:
	.charloop:
		ld	(hl),a
		; ld	(ix+0),a	; copy A to byte pointed by HL
		inc	a		; increments A
		; inc	ix
		cpi			; increments HL, decrements BC (and does a CP)
		jp	pe, .charloop
		ret


; V_END = (VBASE+VSIZE-1)



; msg_boot:	dbz "Booting "
; msg_hd:		dbz "HD"
; msg_fd:		dbz "FD"

labels_start:
label_vram:	dbz	" 2K VRAM "
label_dram16:	dbz	"16K DRAM "
label_bank16:	dbz	"16K page "

msg_dash:	dbz	"-"
msg_space:	dbz	" "
msg_banner:	dbiz	"TRS-80 M2 Test ROM - Frank IZ8DWF / Dave KI3V / Adrian Black"
msg_testok:	dbz	" --OK-- "
; msg_reloc:	dbz	"(reloc) "
msg_skipped:	dbz	" *skip* "
msg_biterrs:	dbz	" errors:"
msg_absent:	dbz	" absent:"
msg_dup:	dbz	"  DUP "
msg_testing:	db	" "
		dbi	" TEST "
		dbz	" "
; msg_testing:	db " ", " "+$80, "t"+$80, "e"+$80, "s"+$80, "t"+$80, " "+$80, " ", 0
status_backup equ $-msg_testing-1

; test parameter table. 2-byte entries:
; 1. size of test in bytes
; 2. starting address
; 3. bank to map before test
; 4. location in screen memory to start printing test data
; 5. address of string for announcing test
; tp_entrysize equ 10
tp_entrysize equ tp_low-tp_vram

COL1 = 2
COL2 = (COL1+40)

TP_SIZE equ 0
TP_BASE equ 1
TP_BANK equ 2
TP_LABEL equ 3
TP_POS equ 4
TP_GOTO equ 1

memtest_ld_bc_size .macro
		ld	b,(iy+TP_SIZE)
		ld	c,a
.endm

memtest_ld_hl_base .macro
		ld	h,(iy+TP_BASE)
		ld	l,a
.endm

memtest_loadregs .macro
		xor	a
		memtest_ld_bc_size
		memtest_ld_hl_base
.endm


tp_vram:	db	high VSIZE, high VBASE, $0, label_vram-labels_start
		dw	VBASE+( 2*VLINE)+COL1

tp_low:		db	$40, $00, $0, label_dram16-labels_start
		dw	VBASE+( 3*VLINE)+COL1
tp_rdest:	db	$40, $40, $0, label_dram16-labels_start
		dw	VBASE+( 4*VLINE)+COL1

tp_high:	db	$40, $80, $1, label_bank16-labels_start
		dw	VBASE+( 5*VLINE)+COL1
		db	$40, $C0, $1, label_bank16-labels_start
		dw	VBASE+( 6*VLINE)+COL1

		db	$00 
		dw	tp_high





.include "inc/memtestmarch.asm"


; .include "inc/trs80m2fdcboot.asm"
.include "inc/spt.asm"
.include "inc/trs80m13con.asm"
; include "inc/trs80m2music.asm"



crtc_setup_table:
		dc	16,0		; in model 4, this is a dummy table
