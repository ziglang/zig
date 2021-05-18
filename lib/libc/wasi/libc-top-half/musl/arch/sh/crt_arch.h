#ifdef __SH_FDPIC__

__asm__(
".text \n"
".global " START " \n"
START ": \n"
"	tst r8, r8 \n"
"	bf 1f \n"
"	mov #68, r3 \n"
"	add r3, r3 \n"
"	mov #8, r4 \n"
"	swap.w r4, r4 \n"
"	trapa #31 \n"
"	nop \n"
"	nop \n"
"	nop \n"
"	nop \n"
"1:	nop \n"
#ifndef SHARED
"	mov r8, r4 \n"
"	mova 1f, r0 \n"
"	mov.l 1f, r5 \n"
"	mov.l 1f+4, r6 \n"
"	add r0, r5 \n"
"	mov.l 4f, r1 \n"
"5:	bsrf r1 \n"
"	 add r0, r6 \n"
"	mov r0, r12 \n"
#endif
"	mov r10, r5 \n"
"	mov r15, r4 \n"
"	mov.l r9, @-r15 \n"
"	mov.l r8, @-r15 \n"
"	mov #-16, r0 \n"
"	mov.l 2f, r1 \n"
"3:	bsrf r1 \n"
"	 and r0, r15 \n"
".align 2 \n"
"1:	.long __ROFIXUP_LIST__@PCREL \n"
"	.long __ROFIXUP_END__@PCREL + 4 \n"
"2:	.long " START "_c@PCREL - (3b+4-.) \n"
#ifndef SHARED
"4:	.long __fdpic_fixup@PCREL - (5b+4-.) \n"
#endif
);

#ifndef SHARED
#include "fdpic_crt.h"
#endif

#else

__asm__(
".text \n"
".global " START " \n"
START ": \n"
"	mova 1f, r0 \n"
"	mov.l 1f, r5 \n"
"	add r0, r5 \n"
"	mov r15, r4 \n"
"	mov #-16, r0 \n"
"	mov.l 2f, r1 \n"
"3:	bsrf r1 \n"
"	 and r0, r15 \n"
".align 2 \n"
".weak _DYNAMIC \n"
".hidden _DYNAMIC \n"
"1:	.long _DYNAMIC-. \n"
"2:	.long " START "_c@PCREL - (3b+4-.) \n"
);

#endif

/* used by gcc for switching the FPU between single and double precision */
#ifdef SHARED
__attribute__((__visibility__("hidden")))
#endif
const unsigned long __fpscr_values[2] = { 0, 0x80000 };
