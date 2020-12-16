/* ===-------- ia32intrin.h ---------------------------------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __X86INTRIN_H
#error "Never use <ia32intrin.h> directly; include <x86intrin.h> instead."
#endif

#ifndef __IA32INTRIN_H
#define __IA32INTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))
#define __DEFAULT_FN_ATTRS_SSE42 __attribute__((__always_inline__, __nodebug__, __target__("sse4.2")))

#if defined(__cplusplus) && (__cplusplus >= 201103L)
#define __DEFAULT_FN_ATTRS_CAST __attribute__((__always_inline__)) constexpr
#define __DEFAULT_FN_ATTRS_CONSTEXPR __DEFAULT_FN_ATTRS constexpr
#else
#define __DEFAULT_FN_ATTRS_CAST __attribute__((__always_inline__))
#define __DEFAULT_FN_ATTRS_CONSTEXPR __DEFAULT_FN_ATTRS
#endif

/** Find the first set bit starting from the lsb. Result is undefined if
 *  input is 0.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSF </c> instruction or the
 *  <c> TZCNT </c> instruction.
 *
 *  \param __A
 *     A 32-bit integer operand.
 *  \returns A 32-bit integer containing the bit number.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__bsfd(int __A) {
  return __builtin_ctz(__A);
}

/** Find the first set bit starting from the msb. Result is undefined if
 *  input is 0.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSR </c> instruction or the
 *  <c> LZCNT </c> instruction and an <c> XOR </c>.
 *
 *  \param __A
 *     A 32-bit integer operand.
 *  \returns A 32-bit integer containing the bit number.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__bsrd(int __A) {
  return 31 - __builtin_clz(__A);
}

/** Swaps the bytes in the input. Converting little endian to big endian or
 *  vice versa.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSWAP </c> instruction.
 *
 *  \param __A
 *     A 32-bit integer operand.
 *  \returns A 32-bit integer containing the swapped bytes.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__bswapd(int __A) {
  return __builtin_bswap32(__A);
}

static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
_bswap(int __A) {
  return __builtin_bswap32(__A);
}

#define _bit_scan_forward(A) __bsfd((A))
#define _bit_scan_reverse(A) __bsrd((A))

#ifdef __x86_64__
/** Find the first set bit starting from the lsb. Result is undefined if
 *  input is 0.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSF </c> instruction or the
 *  <c> TZCNT </c> instruction.
 *
 *  \param __A
 *     A 64-bit integer operand.
 *  \returns A 32-bit integer containing the bit number.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__bsfq(long long __A) {
  return __builtin_ctzll(__A);
}

/** Find the first set bit starting from the msb. Result is undefined if
 *  input is 0.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSR </c> instruction or the
 *  <c> LZCNT </c> instruction and an <c> XOR </c>.
 *
 *  \param __A
 *     A 64-bit integer operand.
 *  \returns A 32-bit integer containing the bit number.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__bsrq(long long __A) {
  return 63 - __builtin_clzll(__A);
}

/** Swaps the bytes in the input. Converting little endian to big endian or
 *  vice versa.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> BSWAP </c> instruction.
 *
 *  \param __A
 *     A 64-bit integer operand.
 *  \returns A 64-bit integer containing the swapped bytes.
 */
static __inline__ long long __DEFAULT_FN_ATTRS_CONSTEXPR
__bswapq(long long __A) {
  return __builtin_bswap64(__A);
}

#define _bswap64(A) __bswapq((A))
#endif

/** Counts the number of bits in the source operand having a value of 1.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> POPCNT </c> instruction or a
 *  a sequence of arithmetic and logic ops to calculate it.
 *
 *  \param __A
 *     An unsigned 32-bit integer operand.
 *  \returns A 32-bit integer containing the number of bits with value 1 in the
 *     source operand.
 */
static __inline__ int __DEFAULT_FN_ATTRS_CONSTEXPR
__popcntd(unsigned int __A)
{
  return __builtin_popcount(__A);
}

#define _popcnt32(A) __popcntd((A))

#ifdef __x86_64__
/** Counts the number of bits in the source operand having a value of 1.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> POPCNT </c> instruction or a
 *  a sequence of arithmetic and logic ops to calculate it.
 *
 *  \param __A
 *     An unsigned 64-bit integer operand.
 *  \returns A 64-bit integer containing the number of bits with value 1 in the
 *     source operand.
 */
static __inline__ long long __DEFAULT_FN_ATTRS_CONSTEXPR
__popcntq(unsigned long long __A)
{
  return __builtin_popcountll(__A);
}

#define _popcnt64(A) __popcntq((A))
#endif /* __x86_64__ */

#ifdef __x86_64__
static __inline__ unsigned long long __DEFAULT_FN_ATTRS
__readeflags(void)
{
  return __builtin_ia32_readeflags_u64();
}

static __inline__ void __DEFAULT_FN_ATTRS
__writeeflags(unsigned long long __f)
{
  __builtin_ia32_writeeflags_u64(__f);
}

#else /* !__x86_64__ */
static __inline__ unsigned int __DEFAULT_FN_ATTRS
__readeflags(void)
{
  return __builtin_ia32_readeflags_u32();
}

static __inline__ void __DEFAULT_FN_ATTRS
__writeeflags(unsigned int __f)
{
  __builtin_ia32_writeeflags_u32(__f);
}
#endif /* !__x86_64__ */

/** Cast a 32-bit float value to a 32-bit unsigned integer value
 *
 *  \headerfile <x86intrin.h>
 *  This intrinsic corresponds to the <c> VMOVD / MOVD </c> instruction in x86_64,
 *  and corresponds to the <c> VMOVL / MOVL </c> instruction in ia32.
 *
 *  \param __A
 *     A 32-bit float value.
 *  \returns a 32-bit unsigned integer containing the converted value.
 */
static __inline__ unsigned int __DEFAULT_FN_ATTRS_CAST
_castf32_u32(float __A) {
  return __builtin_bit_cast(unsigned int, __A);
}

/** Cast a 64-bit float value to a 64-bit unsigned integer value
 *
 *  \headerfile <x86intrin.h>
 *  This intrinsic corresponds to the <c> VMOVQ / MOVQ </c> instruction in x86_64,
 *  and corresponds to the <c> VMOVL / MOVL </c> instruction in ia32.
 *
 *  \param __A
 *     A 64-bit float value.
 *  \returns a 64-bit unsigned integer containing the converted value.
 */
static __inline__ unsigned long long __DEFAULT_FN_ATTRS_CAST
_castf64_u64(double __A) {
  return __builtin_bit_cast(unsigned long long, __A);
}

/** Cast a 32-bit unsigned integer value to a 32-bit float value
 *
 *  \headerfile <x86intrin.h>
 *  This intrinsic corresponds to the <c> VMOVQ / MOVQ </c> instruction in x86_64,
 *  and corresponds to the <c> FLDS </c> instruction in ia32.
 *
 *  \param __A
 *     A 32-bit unsigned integer value.
 *  \returns a 32-bit float value containing the converted value.
 */
static __inline__ float __DEFAULT_FN_ATTRS_CAST
_castu32_f32(unsigned int __A) {
  return __builtin_bit_cast(float, __A);
}

/** Cast a 64-bit unsigned integer value to a 64-bit float value
 *
 *  \headerfile <x86intrin.h>
 *  This intrinsic corresponds to the <c> VMOVQ / MOVQ </c> instruction in x86_64,
 *  and corresponds to the <c> FLDL </c> instruction in ia32.
 *
 *  \param __A
 *     A 64-bit unsigned integer value.
 *  \returns a 64-bit float value containing the converted value.
 */
static __inline__ double __DEFAULT_FN_ATTRS_CAST
_castu64_f64(unsigned long long __A) {
  return __builtin_bit_cast(double, __A);
}

/** Adds the unsigned integer operand to the CRC-32C checksum of the
 *     unsigned char operand.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> CRC32B </c> instruction.
 *
 *  \param __C
 *     An unsigned integer operand to add to the CRC-32C checksum of operand
 *     \a  __D.
 *  \param __D
 *     An unsigned 8-bit integer operand used to compute the CRC-32C checksum.
 *  \returns The result of adding operand \a __C to the CRC-32C checksum of
 *     operand \a __D.
 */
static __inline__ unsigned int __DEFAULT_FN_ATTRS_SSE42
__crc32b(unsigned int __C, unsigned char __D)
{
  return __builtin_ia32_crc32qi(__C, __D);
}

/** Adds the unsigned integer operand to the CRC-32C checksum of the
 *     unsigned short operand.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> CRC32W </c> instruction.
 *
 *  \param __C
 *     An unsigned integer operand to add to the CRC-32C checksum of operand
 *     \a  __D.
 *  \param __D
 *     An unsigned 16-bit integer operand used to compute the CRC-32C checksum.
 *  \returns The result of adding operand \a __C to the CRC-32C checksum of
 *     operand \a __D.
 */
static __inline__ unsigned int __DEFAULT_FN_ATTRS_SSE42
__crc32w(unsigned int __C, unsigned short __D)
{
  return __builtin_ia32_crc32hi(__C, __D);
}

/** Adds the unsigned integer operand to the CRC-32C checksum of the
 *     second unsigned integer operand.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> CRC32D </c> instruction.
 *
 *  \param __C
 *     An unsigned integer operand to add to the CRC-32C checksum of operand
 *     \a  __D.
 *  \param __D
 *     An unsigned 32-bit integer operand used to compute the CRC-32C checksum.
 *  \returns The result of adding operand \a __C to the CRC-32C checksum of
 *     operand \a __D.
 */
static __inline__ unsigned int __DEFAULT_FN_ATTRS_SSE42
__crc32d(unsigned int __C, unsigned int __D)
{
  return __builtin_ia32_crc32si(__C, __D);
}

#ifdef __x86_64__
/** Adds the unsigned integer operand to the CRC-32C checksum of the
 *     unsigned 64-bit integer operand.
 *
 *  \headerfile <x86intrin.h>
 *
 *  This intrinsic corresponds to the <c> CRC32Q </c> instruction.
 *
 *  \param __C
 *     An unsigned integer operand to add to the CRC-32C checksum of operand
 *     \a  __D.
 *  \param __D
 *     An unsigned 64-bit integer operand used to compute the CRC-32C checksum.
 *  \returns The result of adding operand \a __C to the CRC-32C checksum of
 *     operand \a __D.
 */
static __inline__ unsigned long long __DEFAULT_FN_ATTRS_SSE42
__crc32q(unsigned long long __C, unsigned long long __D)
{
  return __builtin_ia32_crc32di(__C, __D);
}
#endif /* __x86_64__ */

static __inline__ unsigned long long __DEFAULT_FN_ATTRS
__rdpmc(int __A) {
  return __builtin_ia32_rdpmc(__A);
}

/* __rdtscp */
static __inline__ unsigned long long __DEFAULT_FN_ATTRS
__rdtscp(unsigned int *__A) {
  return __builtin_ia32_rdtscp(__A);
}

#define _rdtsc() __rdtsc()

#define _rdpmc(A) __rdpmc(A)

static __inline__ void __DEFAULT_FN_ATTRS
_wbinvd(void) {
  __builtin_ia32_wbinvd();
}

static __inline__ unsigned char __DEFAULT_FN_ATTRS_CONSTEXPR
__rolb(unsigned char __X, int __C) {
  return __builtin_rotateleft8(__X, __C);
}

static __inline__ unsigned char __DEFAULT_FN_ATTRS_CONSTEXPR
__rorb(unsigned char __X, int __C) {
  return __builtin_rotateright8(__X, __C);
}

static __inline__ unsigned short __DEFAULT_FN_ATTRS_CONSTEXPR
__rolw(unsigned short __X, int __C) {
  return __builtin_rotateleft16(__X, __C);
}

static __inline__ unsigned short __DEFAULT_FN_ATTRS_CONSTEXPR
__rorw(unsigned short __X, int __C) {
  return __builtin_rotateright16(__X, __C);
}

static __inline__ unsigned int __DEFAULT_FN_ATTRS_CONSTEXPR
__rold(unsigned int __X, int __C) {
  return __builtin_rotateleft32(__X, __C);
}

static __inline__ unsigned int __DEFAULT_FN_ATTRS_CONSTEXPR
__rord(unsigned int __X, int __C) {
  return __builtin_rotateright32(__X, __C);
}

#ifdef __x86_64__
static __inline__ unsigned long long __DEFAULT_FN_ATTRS_CONSTEXPR
__rolq(unsigned long long __X, int __C) {
  return __builtin_rotateleft64(__X, __C);
}

static __inline__ unsigned long long __DEFAULT_FN_ATTRS_CONSTEXPR
__rorq(unsigned long long __X, int __C) {
  return __builtin_rotateright64(__X, __C);
}
#endif /* __x86_64__ */

#ifndef _MSC_VER
/* These are already provided as builtins for MSVC. */
/* Select the correct function based on the size of long. */
#ifdef __LP64__
#define _lrotl(a,b) __rolq((a), (b))
#define _lrotr(a,b) __rorq((a), (b))
#else
#define _lrotl(a,b) __rold((a), (b))
#define _lrotr(a,b) __rord((a), (b))
#endif
#define _rotl(a,b) __rold((a), (b))
#define _rotr(a,b) __rord((a), (b))
#endif // _MSC_VER

/* These are not builtins so need to be provided in all modes. */
#define _rotwl(a,b) __rolw((a), (b))
#define _rotwr(a,b) __rorw((a), (b))

#undef __DEFAULT_FN_ATTRS
#undef __DEFAULT_FN_ATTRS_CAST
#undef __DEFAULT_FN_ATTRS_SSE42
#undef __DEFAULT_FN_ATTRS_CONSTEXPR

#endif /* __IA32INTRIN_H */
