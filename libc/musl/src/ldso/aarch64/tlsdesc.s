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
	ldr x4,[x3]           // dtv[0]
	cmp x2,x4
	b.hi 1f
	ldr x2,[x3,x2,lsl #3] // dtv[p->modidx]
	ldr x0,[x0,#8]        // p->off
	add x0,x0,x2
2:	sub x0,x0,x1
	ldp x3,x4,[sp,#16]
	ldp x1,x2,[sp],#32
	ret

	// save all registers __tls_get_new may clobber
	// update sp in two steps because offset must be in [-512,509]
1:	stp x29,x30,[sp,#-160]!
	stp x5,x6,[sp,#16]
	stp x7,x8,[sp,#32]
	stp x9,x10,[sp,#48]
	stp x11,x12,[sp,#64]
	stp x13,x14,[sp,#80]
	stp x15,x16,[sp,#96]
	stp x17,x18,[sp,#112]
	stp q0,q1,[sp,#128]
	stp q2,q3,[sp,#-480]!
	stp q4,q5,[sp,#32]
	stp q6,q7,[sp,#64]
	stp q8,q9,[sp,#96]
	stp q10,q11,[sp,#128]
	stp q12,q13,[sp,#160]
	stp q14,q15,[sp,#192]
	stp q16,q17,[sp,#224]
	stp q18,q19,[sp,#256]
	stp q20,q21,[sp,#288]
	stp q22,q23,[sp,#320]
	stp q24,q25,[sp,#352]
	stp q26,q27,[sp,#384]
	stp q28,q29,[sp,#416]
	stp q30,q31,[sp,#448]
	bl __tls_get_new
	mrs x1,tpidr_el0
	ldp q4,q5,[sp,#32]
	ldp q6,q7,[sp,#64]
	ldp q8,q9,[sp,#96]
	ldp q10,q11,[sp,#128]
	ldp q12,q13,[sp,#160]
	ldp q14,q15,[sp,#192]
	ldp q16,q17,[sp,#224]
	ldp q18,q19,[sp,#256]
	ldp q20,q21,[sp,#288]
	ldp q22,q23,[sp,#320]
	ldp q24,q25,[sp,#352]
	ldp q26,q27,[sp,#384]
	ldp q28,q29,[sp,#416]
	ldp q30,q31,[sp,#448]
	ldp q2,q3,[sp],#480
	ldp x5,x6,[sp,#16]
	ldp x7,x8,[sp,#32]
	ldp x9,x10,[sp,#48]
	ldp x11,x12,[sp,#64]
	ldp x13,x14,[sp,#80]
	ldp x15,x16,[sp,#96]
	ldp x17,x18,[sp,#112]
	ldp q0,q1,[sp,#128]
	ldp x29,x30,[sp],#160
	b 2b
