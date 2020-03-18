/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"ilogbf.S"
	.text
	.p2align 4,,15
.globl __MINGW_USYMBOL(ilogbf)
	.def	__MINGW_USYMBOL(ilogbf);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc __MINGW_USYMBOL(ilogbf)
#endif
__MINGW_USYMBOL(ilogbf):
#ifdef __x86_64__
/* generated code for:
int
ilogbf (float x)
{
  __mingw_flt_type_t hlp;
  int hx, ix;

  hlp.x = x;
  hx = (int) hlp.val & 0x7fffffff;
  if (hx < 0x800000)
    {
      if (hx == 0)
        return 0x80000000;  // ilogb(0) = FP_ILOGB0
      for (ix = -126, hx <<= 8; hx > 0; hx <<= 1)
        ix -= 1;
      return ix;
    }
  if (hx < 0x7f800000)
    return (hx >> 23) - 127;
  return 0x7fffffff;
} */
        subq    $24, %rsp
        .seh_stackalloc 24
        .seh_endprologue
        movss   %xmm0, 12(%rsp)
        movl    12(%rsp), %edx
        andl    $2147483647, %edx
        cmpl    $8388607, %edx
        jg      .L2
        testl   %edx, %edx
        je      .L6
        sall    $8, %edx
        movl    $-126, %eax
        testl   %edx, %edx
        jle     .L3
        .p2align 4,,10
.L4:
        addl    %edx, %edx
        subl    $1, %eax
        testl   %edx, %edx
        jg      .L4
.L3:
        addq    $24, %rsp
        ret
        .p2align 4,,10
.L2:
        cmpl    $2139095039, %edx
        jle     .L10
        movl    $2147483647, %eax
        addq    $24, %rsp
        ret
        .p2align 4,,10
.L10:
        sarl    $23, %edx
        leal    -127(%rdx), %eax
        addq    $24, %rsp
        ret
.L6:
        movl    $-2147483648, %eax
        jmp     .L3
        .seh_endproc
#else
	flds	4(%esp)
/* I added the following ugly construct because ilogb(+-Inf) is
   required to return INT_MAX in ISO C99.
   -- jakub@redhat.com.  */
	fxam			/* Is NaN or +-Inf?  */
	fstsw   %ax
	movb    $0x45, %dh
	andb    %ah, %dh
	cmpb    $0x05, %dh
	je      1f		/* Is +-Inf, jump.  */
	cmpb    $0x01, %dh
	je      1f		/* Is Nan, jump.  */

	fxtract
	pushl	%eax
	fstp	%st

	fistpl	(%esp)
	fwait
	popl	%eax

	ret

1:	fstp	%st
	movl	$0x7fffffff, %eax
	ret
#endif
