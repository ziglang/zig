/*
 This Software is provided under the Zope Public License (ZPL) Version 2.1.

 Copyright (c) 2009, 2010 by the mingw-w64 project

 See the AUTHORS file for the list of contributors to the mingw-w64 project.

 This license has been certified as open source. It has also been designated
 as GPL compatible by the Free Software Foundation (FSF).

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   1. Redistributions in source code must retain the accompanying copyright
      notice, this list of conditions, and the following disclaimer.
   2. Redistributions in binary form must reproduce the accompanying
      copyright notice, this list of conditions, and the following disclaimer
      in the documentation and/or other materials provided with the
      distribution.
   3. Names of the copyright holders must not be used to endorse or promote
      products derived from this software without prior written permission
      from the copyright holders.
   4. The right to distribute this software or to use it for any purpose does
      not give you the right to use Servicemarks (sm) or Trademarks (tm) of
      the copyright holders.  Use of them is covered by separate agreement
      with the copyright holders.
   5. If any files are modified, you must cause the modified files to carry
      prominent notices stating that you changed the files and the date of
      any change.

 Disclaimer

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY EXPRESSED
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "../complex/complex_internal.h"
#include <errno.h>

static long double c0 = 1.44268798828125L; // INV_LN2
static long double c1 = 7.05260771340735992468e-6L;

static long double
__expl_internal (long double x)
{
  long double res = 0.0L;
  asm volatile (
       "fldl2e\n\t"             /* 1  log2(e)         */
       "fmul %%st(1),%%st\n\t"  /* 1  x log2(e)       */

#ifdef __x86_64__
    "subq $8, %%rsp\n"
    "fnstcw 4(%%rsp)\n"
    "movzwl 4(%%rsp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%rsp)\n"
    "fldcw (%%rsp)\n"
    "frndint\n\t"            /* 1  i               */
    "fld %%st(1)\n\t"        /* 2  x               */
    "frndint\n\t"            /* 2  xi              */
    "fldcw 4(%%rsp)\n"
    "addq $8, %%rsp\n"
#else
    "push %%eax\n\tsubl $8, %%esp\n"
    "fnstcw 4(%%esp)\n"
    "movzwl 4(%%esp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%esp)\n"
    "fldcw (%%esp)\n"
    "frndint\n\t"            /* 1  i               */
    "fld %%st(1)\n\t"        /* 2  x               */
    "frndint\n\t"            /* 2  xi              */
    "fldcw 4(%%esp)\n"
    "addl $8, %%esp\n\tpop %%eax\n"
#endif
       "fld %%st(1)\n\t"        /* 3  i               */
       "fldt %2\n\t"            /* 4  c0              */
       "fld %%st(2)\n\t"        /* 5  xi              */
       "fmul %%st(1),%%st\n\t"  /* 5  c0 xi           */
       "fsubp %%st,%%st(2)\n\t" /* 4  f = c0 xi  - i  */
       "fld %%st(4)\n\t"        /* 5  x               */
       "fsub %%st(3),%%st\n\t"  /* 5  xf = x - xi     */
       "fmulp %%st,%%st(1)\n\t" /* 4  c0 xf           */
       "faddp %%st,%%st(1)\n\t" /* 3  f = f + c0 xf   */
       "fldt %3\n\t"            /* 4                  */
       "fmul %%st(4),%%st\n\t"  /* 4  c1 * x          */
       "faddp %%st,%%st(1)\n\t" /* 3  f = f + c1 * x  */
       "f2xm1\n\t"		/* 3 2^(fract(x * log2(e))) - 1 */
       "fld1\n\t"               /* 4 1.0              */
       "faddp\n\t"		/* 3 2^(fract(x * log2(e))) */
       "fstp	%%st(1)\n\t"    /* 2  */
       "fscale\n\t"	        /* 2 scale factor is st(1); e^x */
       "fstp	%%st(1)\n\t"    /* 1  */
       "fstp	%%st(1)\n\t"    /* 0  */
       : "=t" (res) : "0" (x), "m" (c0), "m" (c1) : "ax", "dx");
  return res;
}

__FLT_TYPE
__FLT_ABI(exp) (__FLT_TYPE x)
{
  int x_class = fpclassify (x);
  if (x_class == FP_NAN)
    {
      __FLT_RPT_DOMAIN ("exp", x, 0.0, x);
      return x;
    }
  else if (x_class == FP_INFINITE)
    {
      __FLT_TYPE r = (signbit (x) ? __FLT_CST (0.0) : __FLT_HUGE_VAL);
      __FLT_RPT_ERANGE ("exp", x, 0.0, r, signbit (x));
      return r;
    }
  else if (x_class == FP_ZERO)
    {
      return __FLT_CST (1.0);
    }
  else if (x > __FLT_MAXLOG)
    {
      __FLT_RPT_ERANGE ("exp", x, 0.0, __FLT_HUGE_VAL, 1);
      return __FLT_HUGE_VAL;
    }
  else if (x < __FLT_MINLOG)
    {
      return __FLT_CST(0.0);
    }
  else
    return (__FLT_TYPE) __expl_internal ((long double) x);
}
