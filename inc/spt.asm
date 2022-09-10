; code: lang=asm-collection tabSize=8
; spt_ld_bc:	pop 	bc
; 		ret

; spt_ld_hl:	pop 	hl
; 		ret

spt_select_test:
		pop	iy
		ret

; spt_ld_bchl:	pop 	bc
; 		pop 	hl
; 		ret

; spt_clr_e:	ld	e,0		; just clear reg e
; 		ret


spt_exit:	
		SPTHREAD_RESTORE
		ret


spt_jp:		pop	hl
		ld	sp,hl
		ret

spt_jp_nc:	pop	hl
		ret	c
		ld	sp,hl
		ret

spt_jp_c:	pop	hl
		ret	nc
		ld	sp,hl
		ret

; spt_jp_z:	pop	hl
; 		ret	nz
; 		ld	sp,hl
; 		ret



; ; attempt to create subroutine to replace SPTHREAD_ENTER macro
; ; the downside of these is that they destroy HL, which is a hard pill to swallow in
; ; ramless code
; ; notes:
; ; if a subroutine immediately JP's here, we know that:
; ;	(sp-2) contains the address of the routine that called us (because we got there by RET)
; ;	(sp-2)+3 contains the address we can jp back to in order to continue
; spt_enter:
; 		dec	sp
; 		dec	sp
; 		pop	hl
; 		SPTHREAD_ENTER
; 		jp	(hl)


; call an all-threaded subroutine
;	the parameter (pointed by SP) is where we are jumping
spt_call:
		pop	hl
		SPTHREAD_SAVE
		ld	sp,hl
		ret