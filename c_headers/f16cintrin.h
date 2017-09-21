/*===---- f16cintrin.h - F16C intrinsics -----------------------------------===
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

#if !defined __X86INTRIN_H && !defined __EMMINTRIN_H && !defined __IMMINTRIN_H
#error "Never use <f16cintrin.h> directly; include <emmintrin.h> instead."
#endif

#ifndef __F16CINTRIN_H
#define __F16CINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS \
  __attribute__((__always_inline__, __nodebug__, __target__("f16c")))

/// \brief Converts a 16-bit half-precision float value into a 32-bit float
///    value.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> VCVTPH2PS </c> instruction.
///
/// \param __a
///    A 16-bit half-precision float value.
/// \returns The converted 32-bit float value.
static __inline float __DEFAULT_FN_ATTRS
_cvtsh_ss(unsigned short __a)
{
  __v8hi v = {(short)__a, 0, 0, 0, 0, 0, 0, 0};
  __v4sf r = __builtin_ia32_vcvtph2ps(v);
  return r[0];
}

/// \brief Converts a 32-bit single-precision float value to a 16-bit
///    half-precision float value.
///
/// \headerfile <x86intrin.h>
///
/// \code
/// unsigned short _cvtss_sh(float a, const int imm);
/// \endcode
///
/// This intrinsic corresponds to the <c> VCVTPS2PH </c> instruction.
///
/// \param a
///    A 32-bit single-precision float value to be converted to a 16-bit
///    half-precision float value.
/// \param imm
///    An immediate value controlling rounding using bits [2:0]: \n
///    000: Nearest \n
///    001: Down \n
///    010: Up \n
///    011: Truncate \n
///    1XX: Use MXCSR.RC for rounding
/// \returns The converted 16-bit half-precision float value.
#define _cvtss_sh(a, imm)  \
  ((unsigned short)(((__v8hi)__builtin_ia32_vcvtps2ph((__v4sf){a, 0, 0, 0}, \
                                                      (imm)))[0]))

/// \brief Converts a 128-bit vector containing 32-bit float values into a
///    128-bit vector containing 16-bit half-precision float values.
///
/// \headerfile <x86intrin.h>
///
/// \code
/// __m128i _mm_cvtps_ph(__m128 a, const int imm);
/// \endcode
///
/// This intrinsic corresponds to the <c> VCVTPS2PH </c> instruction.
///
/// \param a
///    A 128-bit vector containing 32-bit float values.
/// \param imm
///    An immediate value controlling rounding using bits [2:0]: \n
///    000: Nearest \n
///    001: Down \n
///    010: Up \n
///    011: Truncate \n
///    1XX: Use MXCSR.RC for rounding
/// \returns A 128-bit vector containing converted 16-bit half-precision float
///    values. The lower 64 bits are used to store the converted 16-bit
///    half-precision floating-point values.
#define _mm_cvtps_ph(a, imm) \
  ((__m128i)__builtin_ia32_vcvtps2ph((__v4sf)(__m128)(a), (imm)))

/// \brief Converts a 128-bit vector containing 16-bit half-precision float
///    values into a 128-bit vector containing 32-bit float values.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> VCVTPH2PS </c> instruction.
///
/// \param __a
///    A 128-bit vector containing 16-bit half-precision float values. The lower
///    64 bits are used in the conversion.
/// \returns A 128-bit vector of [4 x float] containing converted float values.
static __inline __m128 __DEFAULT_FN_ATTRS
_mm_cvtph_ps(__m128i __a)
{
  return (__m128)__builtin_ia32_vcvtph2ps((__v8hi)__a);
}

#undef __DEFAULT_FN_ATTRS

#endif /* __F16CINTRIN_H */
