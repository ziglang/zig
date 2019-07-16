/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
 #include <_mingw_mac.h>

	.file	"floorf.S"
	.text
	.p2align 4,,15
	.globl __MINGW_USYMBOL(floorf)
	.def	__MINGW_USYMBOL(floorf);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc __MINGW_USYMBOL(floorf)
#endif
__MINGW_USYMBOL(floorf):
#if defined(_AMD64_) || defined(__x86_64__)
        subq    $40, %rsp
        .seh_stackalloc 40
        .seh_endprologue
        unpcklps        %xmm0, %xmm0
        cvtps2pd        %xmm0, %xmm0
        call    floor
        unpcklpd        %xmm0, %xmm0
        cvtpd2ps        %xmm0, %xmm0
        addq    $40, %rsp
        ret
        .seh_endproc
        .def    __MINGW_USYMBOL(floor);  .scl    2;      .type   32;     .endef
#elif defined(_X86_) || defined(__i386__)
	flds	4(%esp)
	subl	$8,%esp

	fstcw	4(%esp)			/* store fpu control word */

	/* We use here %edx although only the low 1 bits are defined.
	   But none of the operations should care and they are faster
	   than the 16 bit operations.  */
	movl	$0x400,%edx		/* round towards -oo */
	orl	4(%esp),%edx
	andl	$0xf7ff,%edx
	movl	%edx,(%esp)
	fldcw	(%esp)			/* load modified control word */

	frndint				/* round */

	fldcw	4(%esp)			/* restore original control word */

	addl	$8,%esp
	ret
#endif
