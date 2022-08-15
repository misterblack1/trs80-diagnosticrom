; spt_ld_bc:	pop 	bc
; 		ret

; spt_ld_hl:	pop 	hl
; 		ret

spt_ld_iy:	pop	iy
		ret

; spt_ld_bchl:	pop 	bc
; 		pop 	hl
; 		ret

spt_clr_e:	ld	e,0		; just clear reg e
		ret


; spt_exit:	ld	sp,iy		; resume from the thread location saved in iy
; 		ret

spt_exit:	
		spthread_restore
		ret


spt_jp:		pop	hl
		ld	sp,hl
		ret

spt_jp_nc:	pop	hl
		ret	c
		ld	sp,hl
		ret

spt_jp_z:	pop	hl
		ret	nz
		ld	sp,hl
		ret

; do_spt_call_hl:
; 		spthread_restore
; 		jp (hl)
