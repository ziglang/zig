// size_t __tlsdesc_static(size_t *a)
// {
// 	return a[1];
// }
.global __tlsdesc_static
.hidden __tlsdesc_static
.type __tlsdesc_static,@function
__tlsdesc_static:
	ldr x0,[x0,#8]
	ret

.hidden __tls_get_new

// size_t __tlsdesc_dynamic(size_t *a)
// {
// 	struct {size_t modidx,off;} *p = (void*)a[1];
// 	size_t *dtv = *(size_t**)(tp - 8);
// 	if (p->modidx <= dtv[0])
// 		return dtv[p->modidx] + p->off - tp;
// 	return __tls_get_new(p) - tp;
// }
.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	stp x1,x2,[sp,#-32]!
	stp x3,x4,[sp,#16]
	mrs x1,tpidr_el0      // tp
	ldr x0,[x0,#8]        // p
	ldr x2,[x0]           // p->modidx
	ldr x3,[x1,#-8]       // dtv
	ldr x2,[x3,x2,lsl #3] // dtv[p->modidx]
	ldr x0,[x0,#8]        // p->off
	add x0,x0,x2
	sub x0,x0,x1
	ldp x3,x4,[sp,#16]
	ldp x1,x2,[sp],#32
	ret
