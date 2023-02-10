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

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__MMX__)
#include <mmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SSE__)
#include <xmmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SSE2__)
#include <emmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SSE3__)
#include <pmmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SSSE3__)
#include <tmmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__SSE4_2__) || defined(__SSE4_1__))
#include <smmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AES__) || defined(__PCLMUL__))
#include <wmmintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__CLFLUSHOPT__)
#include <clflushoptintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__CLWB__)
#include <clwbintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX__)
#include <avxintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX2__)
#include <avx2intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__F16C__)
#include <f16cintrin.h>
#endif

/* No feature check desired due to internal checks */
#include <bmiintrin.h>

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__BMI2__)
#include <bmi2intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__LZCNT__)
#include <lzcntintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__POPCNT__)
#include <popcntintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__FMA__)
#include <fmaintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512F__)
#include <avx512fintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VL__)
#include <avx512vlintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512BW__)
#include <avx512bwintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512BITALG__)
#include <avx512bitalgintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512CD__)
#include <avx512cdintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VPOPCNTDQ__)
#include <avx512vpopcntdqintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512VPOPCNTDQ__))
#include <avx512vpopcntdqvlintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VNNI__)
#include <avx512vnniintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512VNNI__))
#include <avx512vlvnniintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVXVNNI__)
#include <avxvnniintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512DQ__)
#include <avx512dqintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512BITALG__))
#include <avx512vlbitalgintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512BW__))
#include <avx512vlbwintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512CD__))
#include <avx512vlcdintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512DQ__))
#include <avx512vldqintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512ER__)
#include <avx512erintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512IFMA__)
#include <avx512ifmaintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512IFMA__) && defined(__AVX512VL__))
#include <avx512ifmavlintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VBMI__)
#include <avx512vbmiintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VBMI__) && defined(__AVX512VL__))
#include <avx512vbmivlintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VBMI2__)
#include <avx512vbmi2intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VBMI2__) && defined(__AVX512VL__))
#include <avx512vlvbmi2intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512PF__)
#include <avx512pfintrin.h>
#endif

/*
 * FIXME: _Float16 type is legal only when HW support float16 operation.
 * We use __AVX512FP16__ to identify if float16 is supported or not, so
 * when float16 is not supported, the related header is not included.
 *
 */
#if defined(__AVX512FP16__)
#include <avx512fp16intrin.h>
#endif

#if defined(__AVX512FP16__) && defined(__AVX512VL__)
#include <avx512vlfp16intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512BF16__)
#include <avx512bf16intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512BF16__))
#include <avx512vlbf16intrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__PKU__)
#include <pkuintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__VPCLMULQDQ__)
#include <vpclmulqdqintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__VAES__)
#include <vaesintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__GFNI__)
#include <gfniintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__RDPID__)
/// Returns the value of the IA32_TSC_AUX MSR (0xc0000103).
///
/// \headerfile <immintrin.h>
///
/// This intrinsic corresponds to the <c> RDPID </c> instruction.
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("rdpid")))
_rdpid_u32(void) {
  return __builtin_ia32_rdpid();
}
#endif // __RDPID__

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__RDRND__)
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand16_step(unsigned short *__p)
{
  return (int)__builtin_ia32_rdrand16_step(__p);
}

static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand32_step(unsigned int *__p)
{
  return (int)__builtin_ia32_rdrand32_step(__p);
}

#ifdef __x86_64__
static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("rdrnd")))
_rdrand64_step(unsigned long long *__p)
{
  return (int)__builtin_ia32_rdrand64_step(__p);
}
#endif
#endif /* __RDRND__ */

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__FSGSBASE__)
#ifdef __x86_64__
static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readfsbase_u32(void)
{
  return __builtin_ia32_rdfsbase32();
}

static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readfsbase_u64(void)
{
  return __builtin_ia32_rdfsbase64();
}

static __inline__ unsigned int __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readgsbase_u32(void)
{
  return __builtin_ia32_rdgsbase32();
}

static __inline__ unsigned long long __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_readgsbase_u64(void)
{
  return __builtin_ia32_rdgsbase64();
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writefsbase_u32(unsigned int __V)
{
  __builtin_ia32_wrfsbase32(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writefsbase_u64(unsigned long long __V)
{
  __builtin_ia32_wrfsbase64(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writegsbase_u32(unsigned int __V)
{
  __builtin_ia32_wrgsbase32(__V);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("fsgsbase")))
_writegsbase_u64(unsigned long long __V)
{
  __builtin_ia32_wrgsbase64(__V);
}

#endif
#endif /* __FSGSBASE__ */

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__MOVBE__)

/* The structs used below are to force the load/store to be unaligned. This
 * is accomplished with the __packed__ attribute. The __may_alias__ prevents
 * tbaa metadata from being generated based on the struct and the type of the
 * field inside of it.
 */

static __inline__ short __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i16(void const * __P) {
  struct __loadu_i16 {
    unsigned short __v;
  } __attribute__((__packed__, __may_alias__));
  return (short)__builtin_bswap16(((const struct __loadu_i16*)__P)->__v);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i16(void * __P, short __D) {
  struct __storeu_i16 {
    unsigned short __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i16*)__P)->__v = __builtin_bswap16((unsigned short)__D);
}

static __inline__ int __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i32(void const * __P) {
  struct __loadu_i32 {
    unsigned int __v;
  } __attribute__((__packed__, __may_alias__));
  return (int)__builtin_bswap32(((const struct __loadu_i32*)__P)->__v);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i32(void * __P, int __D) {
  struct __storeu_i32 {
    unsigned int __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i32*)__P)->__v = __builtin_bswap32((unsigned int)__D);
}

#ifdef __x86_64__
static __inline__ long long __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_loadbe_i64(void const * __P) {
  struct __loadu_i64 {
    unsigned long long __v;
  } __attribute__((__packed__, __may_alias__));
  return (long long)__builtin_bswap64(((const struct __loadu_i64*)__P)->__v);
}

static __inline__ void __attribute__((__always_inline__, __nodebug__, __target__("movbe")))
_storebe_i64(void * __P, long long __D) {
  struct __storeu_i64 {
    unsigned long long __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __storeu_i64*)__P)->__v = __builtin_bswap64((unsigned long long)__D);
}
#endif
#endif /* __MOVBE */

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__RTM__)
#include <rtmintrin.h>
#include <xtestintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SHA__)
#include <shaintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__FXSR__)
#include <fxsrintrin.h>
#endif

/* No feature check desired due to internal MSC_VER checks */
#include <xsaveintrin.h>

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__XSAVEOPT__)
#include <xsaveoptintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__XSAVEC__)
#include <xsavecintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__XSAVES__)
#include <xsavesintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SHSTK__)
#include <cetintrin.h>
#endif

/* Some intrinsics inside adxintrin.h are available only on processors with ADX,
 * whereas others are also available at all times. */
#include <adxintrin.h>

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__RDSEED__)
#include <rdseedintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__WBNOINVD__)
#include <wbnoinvdintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__CLDEMOTE__)
#include <cldemoteintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__WAITPKG__)
#include <waitpkgintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__MOVDIRI__) || defined(__MOVDIR64B__)
#include <movdirintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__PCONFIG__)
#include <pconfigintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SGX__)
#include <sgxintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__PTWRITE__)
#include <ptwriteintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__INVPCID__)
#include <invpcidintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__KL__) || defined(__WIDEKL__)
#include <keylockerintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AMXTILE__) || defined(__AMXINT8__) || defined(__AMXBF16__)
#include <amxintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__AVX512VP2INTERSECT__)
#include <avx512vp2intersectintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    (defined(__AVX512VL__) && defined(__AVX512VP2INTERSECT__))
#include <avx512vlvp2intersectintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__ENQCMD__)
#include <enqcmdintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__SERIALIZE__)
#include <serializeintrin.h>
#endif

#if !(defined(_MSC_VER) || defined(__SCE__)) || __has_feature(modules) ||      \
    defined(__TSXLDTRK__)
#include <tsxldtrkintrin.h>
#endif

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
