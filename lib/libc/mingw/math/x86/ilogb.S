/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <_mingw_mac.h>

	.file	"ilogb.S"
	.text
	.p2align 4,,15
.globl __MINGW_USYMBOL(ilogb)
	.def	__MINGW_USYMBOL(ilogb);	.scl	2;	.type	32;	.endef
#ifdef __x86_64__
	.seh_proc __MINGW_USYMBOL(ilogb)
#endif
__MINGW_USYMBOL(ilogb):
#ifdef __x86_64__
/* Generated code by:
int
ilogb (double x)
{
  __mingw_dbl_type_t hlp;
  int hx, lx, ix;

  hlp.x = x;
  hx = hpl.lh.high & 0x7fffffff;
  if (hx < 0x100000)
    {
      lx = hlp.lh.low;
      if ((hx | lx) == 0)
        return 0x80000000;      // ilogb(0) = FP_ILOGB0
      // subnormal x
      if (hx == 0)
        {
          for (ix = -1043; lx > 0; lx <<= 1)
            ix -=1;
        }
      else
        {
          for (ix = -1022,hx <<= 11; hx > 0; hx <<= 1)
            ix -=1;
        }
      return ix;
    }
  if (hx < 0x7ff00000)
    return (hx >> 20) - 1023;
  lx = hlp.lh.low;
  return 0x7fffffff;
} */
        subq    $24, %rsp
        .seh_stackalloc 24
        .seh_endprologue
        movsd   %xmm0, 8(%rsp)
        movq    8(%rsp), %rdx
        shrq    $32, %rdx
        andl    $2147483647, %edx
        cmpl    $1048575, %edx
        jg      .L2
        movq    8(%rsp), %rcx
        movl    %edx, %eax
        orl     %ecx, %eax
        je      .L8
        testl   %edx, %edx
        jne     .L4
        testl   %ecx, %ecx
        movl    %ecx, %edx
        movl    $-1043, %eax
        jle     .L3
        .p2align 4,,10
.L5:
        addl    %edx, %edx
        subl    $1, %eax
        testl   %edx, %edx
        jg      .L5
        addq    $24, %rsp
        ret
        .p2align 4,,10
.L2:
        cmpl    $2146435071, %edx
        jle     .L13
        movl    $2147483647, %eax
.L3:
        addq    $24, %rsp
        ret
        .p2align 4,,10
.L4:
        sall    $11, %edx
        movl    $-1022, %eax
        testl   %edx, %edx
        jle     .L3
        .p2align 4,,10
.L6:
        addl    %edx, %edx
        subl    $1, %eax
        testl   %edx, %edx
        jg      .L6
        addq    $24, %rsp
        ret
        .p2align 4,,10
.L13:
        sarl    $20, %edx
        leal    -1023(%rdx), %eax
        addq    $24, %rsp
        ret
.L8:
        movl    $-2147483648, %eax
        jmp     .L3
        .seh_endproc
#else

	fldl	4(%esp)
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
	je      1f		/* Is NaN, jump.  */

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
