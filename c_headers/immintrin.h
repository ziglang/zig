/*===---- immintrin.h - Intel intrinsics -----------------------------------===
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __IMMINTRIN_H
#define __IMMINTRIN_H

#ifdef __MMX__
#include <mmintrin.h>
#endif

#ifdef __SSE__
#include <xmmintrin.h>
#endif

#ifdef __SSE2__
#include <emmintrin.h>
#endif

#ifdef __SSE3__
#include <pmmintrin.h>
#endif

#ifdef __SSSE3__
#include <tmmintrin.h>
#endif

#if defined (__SSE4_2__) || defined (__SSE4_1__)
#include <smmintrin.h>
#endif

#if defined (__AES__) || defined (__PCLMUL__)
#include <wmmintrin.h>
#endif

#ifdef __AVX__
#include <avxintrin.h>
#endif

#ifdef __AVX2__
#include <avx2intrin.h>
#endif

#ifdef __BMI__
#include <bmiintrin.h>
#endif

#ifdef __BMI2__
#include <bmi2intrin.h>
#endif

#ifdef __LZCNT__
#include <lzcntintrin.h>
#endif

#ifdef __FMA__
#include <fmaintrin.h>
#endif

#ifdef __AVX512F__
#include <avx512fintrin.h>
#endif

#ifdef __AVX512VL__
#include <avx512vlintrin.h>
#endif

#ifdef __AVX512BW__
#include <avx512bwintrin.h>
#endif

#ifdef __AVX512CD__
#include <avx512cdintrin.h>
#endif

#ifdef __AVX512DQ__
#include <avx512dqintrin.h>
#endif

#if defined (__AVX512VL__) && defined (__AVX512BW__)
#include <avx512vlbwintrin.h>
#endif

#if defined (__AVX512VL__) && defined (__AVX512DQ__)
#include <avx512vldqintrin.h>
#endif

#ifdef __AVX512ER__
#include <avx512erintrin.h>
#endif

#ifdef __RDRND__
static __inline__ int __attribute__((__always_inline__, __nodebug__))
_rdrand16_step(unsigned short *__p)
{
  return __builtin_ia32_rdrand16_step(__p);
}

static __inline__ int __attribute__((__always_inline__, __nodebug__))
_rdrand32_step(unsigned int *__p)
{
  return __builtin_ia32_rdrand32_step(__p);
}

#ifdef __x86_64__
static __inline__ int __attribute__((__always_inline__, __nodebug__))
_rdrand64_step(unsigned long long *__p)
{
  return __builtin_ia32_rdrand64_step(__p);
}
#endif
#endif /* __RDRND__ */

#ifdef __FSGSBASE__
#ifdef __x86_64__
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__))
_readfsbase_u32(void)
{
  return __builtin_ia32_rdfsbase32();
}

static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__))
_readfsbase_u64(void)
{
  return __builtin_ia32_rdfsbase64();
}

static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__))
_readgsbase_u32(void)
{
  return __builtin_ia32_rdgsbase32();
}

static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__))
_readgsbase_u64(void)
{
  return __builtin_ia32_rdgsbase64();
}

static __inline__ void __attribute__((__always_inline__, __nodebug__))
_writefsbase_u32(unsigned int __V)
{
  return __builtin_ia32_wrfsbase32(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__))
_writefsbase_u64(unsigned long long __V)
{
  return __builtin_ia32_wrfsbase64(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__))
_writegsbase_u32(unsigned int __V)
{
  return __builtin_ia32_wrgsbase32(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__))
_writegsbase_u64(unsigned long long __V)
{
  return __builtin_ia32_wrgsbase64(__V);
}
#endif
#endif /* __FSGSBASE__ */

#ifdef __RTM__
#include <rtmintrin.h>
#endif

#ifdef __RTM__
#include <xtestintrin.h>
#endif

#ifdef __SHA__
#include <shaintrin.h>
#endif

#include <fxsrintrin.h>

/* Some intrinsics inside adxintrin.h are available only on processors with ADX,
 * whereas others are also available at all times. */
#include <adxintrin.h>

#endif /* __IMMINTRIN_H */
