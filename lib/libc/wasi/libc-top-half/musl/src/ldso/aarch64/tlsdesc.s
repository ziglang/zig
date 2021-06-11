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

// size_t __tlsdesc_dynamic(size_t *a)
// {
// 	struct {size_t modidx,off;} *p = (void*)a[1];
// 	size_t *dtv = *(size_t**)(tp - 8);
// 	return dtv[p->modidx] + p->off - tp;
// }
.global __tlsdesc_dynamic
.hidden __tlsdesc_dynamic
.type __tlsdesc_dynamic,@function
__tlsdesc_dynamic:
	stp x1,x2,[sp,#-16]!
	mrs x1,tpidr_el0      // tp
	ldr x0,[x0,#8]        // p
	ldp x0,x2,[x0]        // p->modidx, p->off
	sub x2,x2,x1          // p->off - tp
	ldr x1,[x1,#-8]       // dtv
	ldr x1,[x1,x0,lsl #3] // dtv[p->modidx]
	add x0,x1,x2          // dtv[p->modidx] + p->off - tp
	ldp x1,x2,[sp],#16
	ret
