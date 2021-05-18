.text
.global __m68k_read_tp
.type   __m68k_read_tp,@function
__m68k_read_tp:
	move.l #333,%d0
	trap #0
	move.l %d0,%a0
	rts
