/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

void sincosl (long double __x, long double *p_sin, long double *p_cos);

void sincosl (long double __x, long double *p_sin, long double *p_cos)
{
  long double c, s;

  __asm__ __volatile__ ("fsincos\n\t"
    "fnstsw    %%ax\n\t"
    "testl     $0x400, %%eax\n\t"
    "jz        1f\n\t"
    "fldpi\n\t"
    "fadd      %%st(0)\n\t"
    "fxch      %%st(1)\n\t"
    "2: fprem1\n\t"
    "fnstsw    %%ax\n\t"
    "testl     $0x400, %%eax\n\t"
    "jnz       2b\n\t"
    "fstp      %%st(1)\n\t"
    "fsincos\n\t"
    "1:" : "=t" (c), "=u" (s) : "0" (__x) : "eax");
  *p_sin = s;
  *p_cos = c;
}
