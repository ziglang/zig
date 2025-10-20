/*===---- immintrin.h - Intel intrinsics -----------------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __IMMINTRIN_H
#define __IMMINTRIN_H

#if !defined(__i386__) && !defined(__x86_64__)
#error "This header is only meant to be used on x86 and x64 architecture"
#endif

#include <x86gprintrin.h>

#include <mmintrin.h>

#include <xmmintrin.h>

#include <emmintrin.h>

#include <pmmintrin.h>

#include <tmmintrin.h>

#include <smmintrin.h>

#include <wmmintrin.h>

#include <clflushoptintrin.h>

#include <clwbintrin.h>

#include <avxintrin.h>

#include <avx2intrin.h>

#include <f16cintrin.h>

#include <bmiintrin.h>

#include <bmi2intrin.h>

#include <lzcntintrin.h>

#include <popcntintrin.h>

#include <fmaintrin.h>

#include <avx512fintrin.h>

#include <avx512vlintrin.h>

#include <avx512bwintrin.h>

#include <avx512bitalgintrin.h>

#include <avx512cdintrin.h>

#include <avx512vpopcntdqintrin.h>

#include <avx512vpopcntdqvlintrin.h>

#include <avx512vnniintrin.h>

#include <avx512vlvnniintrin.h>

#include <avxvnniintrin.h>

#include <avx512dqintrin.h>

#include <avx512vlbitalgintrin.h>

#include <avx512vlbwintrin.h>

#include <avx512vlcdintrin.h>

#include <avx512vldqintrin.h>

#include <avx512ifmaintrin.h>

#include <avx512ifmavlintrin.h>

#include <avxifmaintrin.h>

#include <avx512vbmiintrin.h>

#include <avx512vbmivlintrin.h>

#include <avx512vbmi2intrin.h>

#include <avx512vlvbmi2intrin.h>

#include <avx512fp16intrin.h>

#include <avx512vlfp16intrin.h>

#include <avx512bf16intrin.h>

#include <avx512vlbf16intrin.h>

#include <pkuintrin.h>

#include <vpclmulqdqintrin.h>

#include <vaesintrin.h>

#include <gfniintrin.h>

#include <avxvnniint8intrin.h>

#include <avxneconvertintrin.h>

#include <sha512intrin.h>

#include <sm3intrin.h>

#include <sm4intrin.h>

#include <avxvnniint16intrin.h>

/// Reads the value of the IA32_TSC_AUX MSR (0xc0000103).
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDPID </c> instruction.
///
/// \returns The 32-bit contents of the MSR.
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("rdpid")))
_rdpid_u32(void) {
  return __builtin_ia32_rdpid();
}

/// Returns a 16-bit hardware-generated random value.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDRAND </c> instruction.
///
/// \param __p
///    A pointer to a 16-bit memory location to place the random value.
/// \returns 1 if the value was successfully generated, 0 otherwise.
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand16_step(unsigned short *__p)
{
  return (int)__builtin_ia32_rdrand16_step(__p);
}

/// Returns a 32-bit hardware-generated random value.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDRAND </c> instruction.
///
/// \param __p
///    A pointer to a 32-bit memory location to place the random value.
/// \returns 1 if the value was successfully generated, 0 otherwise.
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand32_step(unsigned int *__p)
{
  return (int)__builtin_ia32_rdrand32_step(__p);
}

/// Returns a 64-bit hardware-generated random value.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDRAND </c> instruction.
///
/// \param __p
///    A pointer to a 64-bit memory location to place the random value.
/// \returns 1 if the value was successfully generated, 0 otherwise.
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand64_step(unsigned long long *__p)
{
#ifdef __x86_64__
  return (int)__builtin_ia32_rdrand64_step(__p);
#else
  // We need to emulate the functionality of 64-bit rdrand with 2 32-bit
  // rdrand instructions.
  unsigned int __lo, __hi;
  unsigned int __res_lo = __builtin_ia32_rdrand32_step(&__lo);
  unsigned int __res_hi = __builtin_ia32_rdrand32_step(&__hi);
  if (__res_lo && __res_hi) {
    *__p = ((unsigned long long)__hi << 32) | (unsigned long long)__lo;
    return 1;
  } else {
    *__p = 0;
    return 0;
  }
#endif
}

#ifdef __x86_64__
/// Reads the FS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDFSBASE </c> instruction.
///
/// \returns The lower 32 bits of the FS base register.
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readfsbase_u32(void)
{
  return __builtin_ia32_rdfsbase32();
}

/// Reads the FS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDFSBASE </c> instruction.
///
/// \returns The contents of the FS base register.
static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readfsbase_u64(void)
{
  return __builtin_ia32_rdfsbase64();
}

/// Reads the GS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDGSBASE </c> instruction.
///
/// \returns The lower 32 bits of the GS base register.
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readgsbase_u32(void)
{
  return __builtin_ia32_rdgsbase32();
}

/// Reads the GS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDGSBASE </c> instruction.
///
/// \returns The contents of the GS base register.
static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readgsbase_u64(void)
{
  return __builtin_ia32_rdgsbase64();
}

/// Modifies the FS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> WRFSBASE </c> instruction.
///
/// \param __V
///    Value to use for the lower 32 bits of the FS base register.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writefsbase_u32(unsigned int __V)
{
  __builtin_ia32_wrfsbase32(__V);
}

/// Modifies the FS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> WRFSBASE </c> instruction.
///
/// \param __V
///    Value to use for the FS base register.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writefsbase_u64(unsigned long long __V)
{
  __builtin_ia32_wrfsbase64(__V);
}

/// Modifies the GS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> WRGSBASE </c> instruction.
///
/// \param __V
///    Value to use for the lower 32 bits of the GS base register.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writegsbase_u32(unsigned int __V)
{
  __builtin_ia32_wrgsbase32(__V);
}

/// Modifies the GS base register.
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> WRFSBASE </c> instruction.
///
/// \param __V
///    Value to use for GS base register.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writegsbase_u64(unsigned long long __V)
{
  __builtin_ia32_wrgsbase64(__V);
}

#endif

/* The structs used below are to force the load/store to be unaligned. This
 * is accomplished with the __packed__ attribute. The __may_alias__ prevents
 * tbaa metadata from being generated based on the struct and the type of the
 * field inside of it.
 */

/// Load a 16-bit value from memory and swap its bytes.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the 16-bit value to load.
/// \returns The byte-swapped value.
static __inline__ short __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i16(void const * __P) {
  struct __loadu_i16 {
    unsigned short __v;
  } __attribute__((__packed__, __may_alias__));
  return (short)__builtin_bswap16(((const struct __loadu_i16*)__P)->__v);
}

/// Swap the bytes of a 16-bit value and store it to memory.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the memory for storing the swapped value.
/// \param __D
///    The 16-bit value to be byte-swapped.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i16(void * __P, short __D) {
  struct __storeu_i16 {
    unsigned short __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i16*)__P)->__v = __builtin_bswap16((unsigned short)__D);
}

/// Load a 32-bit value from memory and swap its bytes.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the 32-bit value to load.
/// \returns The byte-swapped value.
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i32(void const * __P) {
  struct __loadu_i32 {
    unsigned int __v;
  } __attribute__((__packed__, __may_alias__));
  return (int)__builtin_bswap32(((const struct __loadu_i32*)__P)->__v);
}

/// Swap the bytes of a 32-bit value and store it to memory.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the memory for storing the swapped value.
/// \param __D
///    The 32-bit value to be byte-swapped.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i32(void * __P, int __D) {
  struct __storeu_i32 {
    unsigned int __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i32*)__P)->__v = __builtin_bswap32((unsigned int)__D);
}

#ifdef __x86_64__
/// Load a 64-bit value from memory and swap its bytes.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the 64-bit value to load.
/// \returns The byte-swapped value.
static __inline__ long long __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i64(void const * __P) {
  struct __loadu_i64 {
    unsigned long long __v;
  } __attribute__((__packed__, __may_alias__));
  return (long long)__builtin_bswap64(((const struct __loadu_i64*)__P)->__v);
}

/// Swap the bytes of a 64-bit value and store it to memory.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the MOVBE instruction.
///
/// \param __P
///    A pointer to the memory for storing the swapped value.
/// \param __D
///    The 64-bit value to be byte-swapped.
static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i64(void * __P, long long __D) {
  struct __storeu_i64 {
    unsigned long long __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i64*)__P)->__v = __builtin_bswap64((unsigned long long)__D);
}
#endif

#include <rtmintrin.h>
#include <xtestintrin.h>

#include <shaintrin.h>

#include <fxsrintrin.h>

/* No feature check desired due to internal MSC_VER checks */
#include <xsaveintrin.h>

#include <xsaveoptintrin.h>

#include <xsavecintrin.h>

#include <xsavesintrin.h>

#include <cetintrin.h>

/* Intrinsics inside adcintrin.h are available at all times. */
#include <adcintrin.h>

#include <adxintrin.h>

#include <rdseedintrin.h>

#include <wbnoinvdintrin.h>

#include <cldemoteintrin.h>

#include <waitpkgintrin.h>

#include <movdirintrin.h>

#include <movrsintrin.h>

#include <movrs_avx10_2intrin.h>

#include <movrs_avx10_2_512intrin.h>

#include <pconfigintrin.h>

#include <sgxintrin.h>

#include <ptwriteintrin.h>

#include <invpcidintrin.h>

#include <keylockerintrin.h>

#include <amxintrin.h>

#include <amxfp16intrin.h>

#include <amxcomplexintrin.h>

#include <amxfp8intrin.h>

#include <amxtransposeintrin.h>

#include <amxmovrsintrin.h>

#include <amxmovrstransposeintrin.h>

#include <amxavx512intrin.h>

#include <amxtf32intrin.h>

#include <amxtf32transposeintrin.h>

#include <amxbf16transposeintrin.h>

#include <amxfp16transposeintrin.h>

#include <amxcomplextransposeintrin.h>

#include <avx512vp2intersectintrin.h>

#include <avx512vlvp2intersectintrin.h>

#include <avx10_2bf16intrin.h>
#include <avx10_2convertintrin.h>
#include <avx10_2copyintrin.h>
#include <avx10_2minmaxintrin.h>
#include <avx10_2niintrin.h>
#include <avx10_2satcvtdsintrin.h>
#include <avx10_2satcvtintrin.h>

#include <avx10_2_512bf16intrin.h>
#include <avx10_2_512convertintrin.h>
#include <avx10_2_512minmaxintrin.h>
#include <avx10_2_512niintrin.h>
#include <avx10_2_512satcvtdsintrin.h>
#include <avx10_2_512satcvtintrin.h>

#include <sm4evexintrin.h>

#include <enqcmdintrin.h>

#include <serializeintrin.h>

#include <tsxldtrkintrin.h>

#if defined(_MSC_VER) && __has_extension(gnu_asm)
/* Define the default attributes for these intrinsics */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))
#ifdef __cplusplus
extern "C" {
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Exchange HLE
\*----------------------------------------------------------------------------*/
#if defined(__i386__) || defined(__x86_64__)
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedExchange_HLEAcquire(long volatile *_Target, long _Value) {
  __asm__ __volatile__(".byte 0xf2 ; lock ; xchg {%0, %1|%1, %0}"
                       : "+r" (_Value), "+m" (*_Target) :: "memory");
  return _Value;
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedExchange_HLERelease(long volatile *_Target, long _Value) {
  __asm__ __volatile__(".byte 0xf3 ; lock ; xchg {%0, %1|%1, %0}"
                       : "+r" (_Value), "+m" (*_Target) :: "memory");
  return _Value;
}
#endif
#if defined(__x86_64__)
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedExchange64_HLEAcquire(__int64 volatile *_Target, __int64 _Value) {
  __asm__ __volatile__(".byte 0xf2 ; lock ; xchg {%0, %1|%1, %0}"
                       : "+r" (_Value), "+m" (*_Target) :: "memory");
  return _Value;
}
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedExchange64_HLERelease(__int64 volatile *_Target, __int64 _Value) {
  __asm__ __volatile__(".byte 0xf3 ; lock ; xchg {%0, %1|%1, %0}"
                       : "+r" (_Value), "+m" (*_Target) :: "memory");
  return _Value;
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Compare Exchange HLE
\*----------------------------------------------------------------------------*/
#if defined(__i386__) || defined(__x86_64__)
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedCompareExchange_HLEAcquire(long volatile *_Destination,
                              long _Exchange, long _Comparand) {
  __asm__ __volatile__(".byte 0xf2 ; lock ; cmpxchg {%2, %1|%1, %2}"
                       : "+a" (_Comparand), "+m" (*_Destination)
                       : "r" (_Exchange) : "memory");
  return _Comparand;
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedCompareExchange_HLERelease(long volatile *_Destination,
                              long _Exchange, long _Comparand) {
  __asm__ __volatile__(".byte 0xf3 ; lock ; cmpxchg {%2, %1|%1, %2}"
                       : "+a" (_Comparand), "+m" (*_Destination)
                       : "r" (_Exchange) : "memory");
  return _Comparand;
}
#endif
#if defined(__x86_64__)
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedCompareExchange64_HLEAcquire(__int64 volatile *_Destination,
                              __int64 _Exchange, __int64 _Comparand) {
  __asm__ __volatile__(".byte 0xf2 ; lock ; cmpxchg {%2, %1|%1, %2}"
                       : "+a" (_Comparand), "+m" (*_Destination)
                       : "r" (_Exchange) : "memory");
  return _Comparand;
}
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedCompareExchange64_HLERelease(__int64 volatile *_Destination,
                              __int64 _Exchange, __int64 _Comparand) {
  __asm__ __volatile__(".byte 0xf3 ; lock ; cmpxchg {%2, %1|%1, %2}"
                       : "+a" (_Comparand), "+m" (*_Destination)
                       : "r" (_Exchange) : "memory");
  return _Comparand;
}
#endif
#ifdef __cplusplus
}
#endif

#undef __DEFAULT_FN_ATTRS

#endif /* defined(_MSC_VER) && __has_extension(gnu_asm) */

#endif /* __IMMINTRIN_H */
