.text
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,%function
__tlsdesc_static:
	ld a0,8(a0)
	jr t0

.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,%function
__tlsdesc_dynamic:
	add sp,sp,-16
	sd t1,(sp)
	sd t2,8(sp)

	ld t2,-8(tp) # t2=dtv

	ld a0,8(a0)  # a0=&{modidx,off}
	ld t1,8(a0)  # t1=off
	ld a0,(a0)   # a0=modidx
	sll a0,a0,3  # a0=8*modidx

	add a0,a0,t2 # a0=dtv+8*modidx
	ld a0,(a0)   # a0=dtv[modidx]
	add a0,a0,t1 # a0=dtv[modidx]+off
	sub a0,a0,tp # a0=dtv[modidx]+off-tp

	ld t1,(sp)
	ld t2,8(sp)
	add sp,sp,16
	jr t0
