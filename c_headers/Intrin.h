/* ===-------- Intrin.h ---------------------------------------------------===
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

/* Only include this if we're compiling for the windows platform. */
#ifndef _MSC_VER
#include_next <Intrin.h>
#else

#ifndef __INTRIN_H
#define __INTRIN_H

/* First include the standard intrinsics. */
#if defined(__i386__) || defined(__x86_64__)
#include <x86intrin.h>
#endif

/* For the definition of jmp_buf. */
#if __STDC_HOSTED__
#include <setjmp.h>
#endif

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS __attribute__((__always_inline__, __nodebug__))

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__MMX__)
/* And the random ones that aren't in those files. */
__m64 _m_from_float(float);
__m64 _m_from_int(int _l);
void _m_prefetch(void *);
float _m_to_float(__m64);
int _m_to_int(__m64 _M);
#endif

/* Other assorted instruction intrinsics. */
void __addfsbyte(unsigned long, unsigned char);
void __addfsdword(unsigned long, unsigned long);
void __addfsword(unsigned long, unsigned short);
void __code_seg(const char *);
static __inline__
void __cpuid(int[4], int);
static __inline__
void __cpuidex(int[4], int, int);
void __debugbreak(void);
__int64 __emul(int, int);
unsigned __int64 __emulu(unsigned int, unsigned int);
void __cdecl __fastfail(unsigned int);
unsigned int __getcallerseflags(void);
static __inline__
void __halt(void);
unsigned char __inbyte(unsigned short);
void __inbytestring(unsigned short, unsigned char *, unsigned long);
void __incfsbyte(unsigned long);
void __incfsdword(unsigned long);
void __incfsword(unsigned long);
unsigned long __indword(unsigned short);
void __indwordstring(unsigned short, unsigned long *, unsigned long);
void __int2c(void);
void __invlpg(void *);
unsigned short __inword(unsigned short);
void __inwordstring(unsigned short, unsigned short *, unsigned long);
void __lidt(void *);
unsigned __int64 __ll_lshift(unsigned __int64, int);
__int64 __ll_rshift(__int64, int);
void __llwpcb(void *);
unsigned char __lwpins32(unsigned int, unsigned int, unsigned int);
void __lwpval32(unsigned int, unsigned int, unsigned int);
unsigned int __lzcnt(unsigned int);
unsigned short __lzcnt16(unsigned short);
static __inline__
void __movsb(unsigned char *, unsigned char const *, size_t);
static __inline__
void __movsd(unsigned long *, unsigned long const *, size_t);
static __inline__
void __movsw(unsigned short *, unsigned short const *, size_t);
void __nop(void);
void __nvreg_restore_fence(void);
void __nvreg_save_fence(void);
void __outbyte(unsigned short, unsigned char);
void __outbytestring(unsigned short, unsigned char *, unsigned long);
void __outdword(unsigned short, unsigned long);
void __outdwordstring(unsigned short, unsigned long *, unsigned long);
void __outword(unsigned short, unsigned short);
void __outwordstring(unsigned short, unsigned short *, unsigned long);
static __inline__
unsigned int __popcnt(unsigned int);
static __inline__
unsigned short __popcnt16(unsigned short);
unsigned long __readcr0(void);
unsigned long __readcr2(void);
static __inline__
unsigned long __readcr3(void);
unsigned long __readcr4(void);
unsigned long __readcr8(void);
unsigned int __readdr(unsigned int);
#ifdef __i386__
static __inline__
unsigned char __readfsbyte(unsigned long);
static __inline__
unsigned long __readfsdword(unsigned long);
static __inline__
unsigned __int64 __readfsqword(unsigned long);
static __inline__
unsigned short __readfsword(unsigned long);
#endif
static __inline__
unsigned __int64 __readmsr(unsigned long);
unsigned __int64 __readpmc(unsigned long);
unsigned long __segmentlimit(unsigned long);
void __sidt(void *);
void *__slwpcb(void);
static __inline__
void __stosb(unsigned char *, unsigned char, size_t);
static __inline__
void __stosd(unsigned long *, unsigned long, size_t);
static __inline__
void __stosw(unsigned short *, unsigned short, size_t);
void __svm_clgi(void);
void __svm_invlpga(void *, int);
void __svm_skinit(int);
void __svm_stgi(void);
void __svm_vmload(size_t);
void __svm_vmrun(size_t);
void __svm_vmsave(size_t);
void __ud2(void);
unsigned __int64 __ull_rshift(unsigned __int64, int);
void __vmx_off(void);
void __vmx_vmptrst(unsigned __int64 *);
void __wbinvd(void);
void __writecr0(unsigned int);
static __inline__
void __writecr3(unsigned int);
void __writecr4(unsigned int);
void __writecr8(unsigned int);
void __writedr(unsigned int, unsigned int);
void __writefsbyte(unsigned long, unsigned char);
void __writefsdword(unsigned long, unsigned long);
void __writefsqword(unsigned long, unsigned __int64);
void __writefsword(unsigned long, unsigned short);
void __writemsr(unsigned long, unsigned __int64);
static __inline__
void *_AddressOfReturnAddress(void);
static __inline__
unsigned char _BitScanForward(unsigned long *_Index, unsigned long _Mask);
static __inline__
unsigned char _BitScanReverse(unsigned long *_Index, unsigned long _Mask);
static __inline__
unsigned char _bittest(long const *, long);
static __inline__
unsigned char _bittestandcomplement(long *, long);
static __inline__
unsigned char _bittestandreset(long *, long);
static __inline__
unsigned char _bittestandset(long *, long);
unsigned __int64 __cdecl _byteswap_uint64(unsigned __int64);
unsigned long __cdecl _byteswap_ulong(unsigned long);
unsigned short __cdecl _byteswap_ushort(unsigned short);
void __cdecl _disable(void);
void __cdecl _enable(void);
long _InterlockedAddLargeStatistic(__int64 volatile *_Addend, long _Value);
static __inline__
long _InterlockedAnd(long volatile *_Value, long _Mask);
static __inline__
short _InterlockedAnd16(short volatile *_Value, short _Mask);
static __inline__
char _InterlockedAnd8(char volatile *_Value, char _Mask);
unsigned char _interlockedbittestandreset(long volatile *, long);
static __inline__
unsigned char _interlockedbittestandset(long volatile *, long);
static __inline__
long __cdecl _InterlockedCompareExchange(long volatile *_Destination,
                                         long _Exchange, long _Comparand);
long _InterlockedCompareExchange_HLEAcquire(long volatile *, long, long);
long _InterlockedCompareExchange_HLERelease(long volatile *, long, long);
static __inline__
short _InterlockedCompareExchange16(short volatile *_Destination,
                                    short _Exchange, short _Comparand);
static __inline__
__int64 _InterlockedCompareExchange64(__int64 volatile *_Destination,
                                      __int64 _Exchange, __int64 _Comparand);
__int64 _InterlockedcompareExchange64_HLEAcquire(__int64 volatile *, __int64,
                                                 __int64);
__int64 _InterlockedCompareExchange64_HLERelease(__int64 volatile *, __int64,
                                                 __int64);
static __inline__
char _InterlockedCompareExchange8(char volatile *_Destination, char _Exchange,
                                  char _Comparand);
void *_InterlockedCompareExchangePointer_HLEAcquire(void *volatile *, void *,
                                                    void *);
void *_InterlockedCompareExchangePointer_HLERelease(void *volatile *, void *,
                                                    void *);
static __inline__
long __cdecl _InterlockedDecrement(long volatile *_Addend);
static __inline__
short _InterlockedDecrement16(short volatile *_Addend);
long _InterlockedExchange(long volatile *_Target, long _Value);
static __inline__
short _InterlockedExchange16(short volatile *_Target, short _Value);
static __inline__
char _InterlockedExchange8(char volatile *_Target, char _Value);
static __inline__
long __cdecl _InterlockedExchangeAdd(long volatile *_Addend, long _Value);
long _InterlockedExchangeAdd_HLEAcquire(long volatile *, long);
long _InterlockedExchangeAdd_HLERelease(long volatile *, long);
static __inline__
short _InterlockedExchangeAdd16(short volatile *_Addend, short _Value);
__int64 _InterlockedExchangeAdd64_HLEAcquire(__int64 volatile *, __int64);
__int64 _InterlockedExchangeAdd64_HLERelease(__int64 volatile *, __int64);
static __inline__
char _InterlockedExchangeAdd8(char volatile *_Addend, char _Value);
static __inline__
long __cdecl _InterlockedIncrement(long volatile *_Addend);
static __inline__
short _InterlockedIncrement16(short volatile *_Addend);
static __inline__
long _InterlockedOr(long volatile *_Value, long _Mask);
static __inline__
short _InterlockedOr16(short volatile *_Value, short _Mask);
static __inline__
char _InterlockedOr8(char volatile *_Value, char _Mask);
static __inline__
long _InterlockedXor(long volatile *_Value, long _Mask);
static __inline__
short _InterlockedXor16(short volatile *_Value, short _Mask);
static __inline__
char _InterlockedXor8(char volatile *_Value, char _Mask);
void __cdecl _invpcid(unsigned int, void *);
static __inline__
unsigned long __cdecl _lrotl(unsigned long, int);
static __inline__
unsigned long __cdecl _lrotr(unsigned long, int);
static __inline__
static __inline__
void _ReadBarrier(void);
static __inline__
void _ReadWriteBarrier(void);
static __inline__
void *_ReturnAddress(void);
unsigned int _rorx_u32(unsigned int, const unsigned int);
static __inline__
unsigned int __cdecl _rotl(unsigned int _Value, int _Shift);
static __inline__
unsigned short _rotl16(unsigned short _Value, unsigned char _Shift);
static __inline__
unsigned __int64 __cdecl _rotl64(unsigned __int64 _Value, int _Shift);
static __inline__
unsigned char _rotl8(unsigned char _Value, unsigned char _Shift);
static __inline__
unsigned int __cdecl _rotr(unsigned int _Value, int _Shift);
static __inline__
unsigned short _rotr16(unsigned short _Value, unsigned char _Shift);
static __inline__
unsigned __int64 __cdecl _rotr64(unsigned __int64 _Value, int _Shift);
static __inline__
unsigned char _rotr8(unsigned char _Value, unsigned char _Shift);
int _sarx_i32(int, unsigned int);
#if __STDC_HOSTED__
int __cdecl _setjmp(jmp_buf);
#endif
unsigned int _shlx_u32(unsigned int, unsigned int);
unsigned int _shrx_u32(unsigned int, unsigned int);
void _Store_HLERelease(long volatile *, long);
void _Store64_HLERelease(__int64 volatile *, __int64);
void _StorePointer_HLERelease(void *volatile *, void *);
static __inline__
void _WriteBarrier(void);
unsigned __int32 xbegin(void);
void _xend(void);
static __inline__
#define _XCR_XFEATURE_ENABLED_MASK 0
unsigned __int64 __cdecl _xgetbv(unsigned int);
void __cdecl _xrstor(void const *, unsigned __int64);
void __cdecl _xsave(void *, unsigned __int64);
void __cdecl _xsaveopt(void *, unsigned __int64);
void __cdecl _xsetbv(unsigned int, unsigned __int64);

/* These additional intrinsics are turned on in x64/amd64/x86_64 mode. */
#ifdef __x86_64__
void __addgsbyte(unsigned long, unsigned char);
void __addgsdword(unsigned long, unsigned long);
void __addgsqword(unsigned long, unsigned __int64);
void __addgsword(unsigned long, unsigned short);
static __inline__
void __faststorefence(void);
void __incgsbyte(unsigned long);
void __incgsdword(unsigned long);
void __incgsqword(unsigned long);
void __incgsword(unsigned long);
unsigned char __lwpins64(unsigned __int64, unsigned int, unsigned int);
void __lwpval64(unsigned __int64, unsigned int, unsigned int);
unsigned __int64 __lzcnt64(unsigned __int64);
static __inline__
void __movsq(unsigned long long *, unsigned long long const *, size_t);
__int64 __mulh(__int64, __int64);
static __inline__
unsigned __int64 __popcnt64(unsigned __int64);
static __inline__
unsigned char __readgsbyte(unsigned long);
static __inline__
unsigned long __readgsdword(unsigned long);
static __inline__
unsigned __int64 __readgsqword(unsigned long);
unsigned short __readgsword(unsigned long);
unsigned __int64 __shiftleft128(unsigned __int64 _LowPart,
                                unsigned __int64 _HighPart,
                                unsigned char _Shift);
unsigned __int64 __shiftright128(unsigned __int64 _LowPart,
                                 unsigned __int64 _HighPart,
                                 unsigned char _Shift);
static __inline__
void __stosq(unsigned __int64 *, unsigned __int64, size_t);
unsigned char __vmx_on(unsigned __int64 *);
unsigned char __vmx_vmclear(unsigned __int64 *);
unsigned char __vmx_vmlaunch(void);
unsigned char __vmx_vmptrld(unsigned __int64 *);
unsigned char __vmx_vmread(size_t, size_t *);
unsigned char __vmx_vmresume(void);
unsigned char __vmx_vmwrite(size_t, size_t);
void __writegsbyte(unsigned long, unsigned char);
void __writegsdword(unsigned long, unsigned long);
void __writegsqword(unsigned long, unsigned __int64);
void __writegsword(unsigned long, unsigned short);
static __inline__
unsigned char _BitScanForward64(unsigned long *_Index, unsigned __int64 _Mask);
static __inline__
unsigned char _BitScanReverse64(unsigned long *_Index, unsigned __int64 _Mask);
static __inline__
unsigned char _bittest64(__int64 const *, __int64);
static __inline__
unsigned char _bittestandcomplement64(__int64 *, __int64);
static __inline__
unsigned char _bittestandreset64(__int64 *, __int64);
static __inline__
unsigned char _bittestandset64(__int64 *, __int64);
unsigned __int64 __cdecl _byteswap_uint64(unsigned __int64);
long _InterlockedAnd_np(long volatile *_Value, long _Mask);
short _InterlockedAnd16_np(short volatile *_Value, short _Mask);
__int64 _InterlockedAnd64_np(__int64 volatile *_Value, __int64 _Mask);
char _InterlockedAnd8_np(char volatile *_Value, char _Mask);
unsigned char _interlockedbittestandreset64(__int64 volatile *, __int64);
static __inline__
unsigned char _interlockedbittestandset64(__int64 volatile *, __int64);
long _InterlockedCompareExchange_np(long volatile *_Destination, long _Exchange,
                                    long _Comparand);
unsigned char _InterlockedCompareExchange128(__int64 volatile *_Destination,
                                             __int64 _ExchangeHigh,
                                             __int64 _ExchangeLow,
                                             __int64 *_CompareandResult);
unsigned char _InterlockedCompareExchange128_np(__int64 volatile *_Destination,
                                                __int64 _ExchangeHigh,
                                                __int64 _ExchangeLow,
                                                __int64 *_ComparandResult);
short _InterlockedCompareExchange16_np(short volatile *_Destination,
                                       short _Exchange, short _Comparand);
__int64 _InterlockedCompareExchange64_HLEAcquire(__int64 volatile *, __int64,
                                                 __int64);
__int64 _InterlockedCompareExchange64_HLERelease(__int64 volatile *, __int64,
                                                 __int64);
__int64 _InterlockedCompareExchange64_np(__int64 volatile *_Destination,
                                         __int64 _Exchange, __int64 _Comparand);
void *_InterlockedCompareExchangePointer(void *volatile *_Destination,
                                         void *_Exchange, void *_Comparand);
void *_InterlockedCompareExchangePointer_np(void *volatile *_Destination,
                                            void *_Exchange, void *_Comparand);
static __inline__
__int64 _InterlockedDecrement64(__int64 volatile *_Addend);
static __inline__
__int64 _InterlockedExchange64(__int64 volatile *_Target, __int64 _Value);
static __inline__
__int64 _InterlockedExchangeAdd64(__int64 volatile *_Addend, __int64 _Value);
void *_InterlockedExchangePointer(void *volatile *_Target, void *_Value);
static __inline__
__int64 _InterlockedIncrement64(__int64 volatile *_Addend);
long _InterlockedOr_np(long volatile *_Value, long _Mask);
short _InterlockedOr16_np(short volatile *_Value, short _Mask);
static __inline__
__int64 _InterlockedOr64(__int64 volatile *_Value, __int64 _Mask);
__int64 _InterlockedOr64_np(__int64 volatile *_Value, __int64 _Mask);
char _InterlockedOr8_np(char volatile *_Value, char _Mask);
long _InterlockedXor_np(long volatile *_Value, long _Mask);
short _InterlockedXor16_np(short volatile *_Value, short _Mask);
static __inline__
__int64 _InterlockedXor64(__int64 volatile *_Value, __int64 _Mask);
__int64 _InterlockedXor64_np(__int64 volatile *_Value, __int64 _Mask);
char _InterlockedXor8_np(char volatile *_Value, char _Mask);
static __inline__
__int64 _mul128(__int64 _Multiplier, __int64 _Multiplicand,
                __int64 *_HighProduct);
unsigned __int64 _rorx_u64(unsigned __int64, const unsigned int);
__int64 _sarx_i64(__int64, unsigned int);
#if __STDC_HOSTED__
int __cdecl _setjmpex(jmp_buf);
#endif
unsigned __int64 _shlx_u64(unsigned __int64, unsigned int);
unsigned __int64 _shrx_u64(unsigned __int64, unsigned int);
/*
 * Multiply two 64-bit integers and obtain a 64-bit result.
 * The low-half is returned directly and the high half is in an out parameter.
 */
static __inline__ unsigned __int64 __DEFAULT_FN_ATTRS
_umul128(unsigned __int64 _Multiplier, unsigned __int64 _Multiplicand,
         unsigned __int64 *_HighProduct) {
  unsigned __int128 _FullProduct =
      (unsigned __int128)_Multiplier * (unsigned __int128)_Multiplicand;
  *_HighProduct = _FullProduct >> 64;
  return _FullProduct;
}
static __inline__ unsigned __int64 __DEFAULT_FN_ATTRS
__umulh(unsigned __int64 _Multiplier, unsigned __int64 _Multiplicand) {
  unsigned __int128 _FullProduct =
      (unsigned __int128)_Multiplier * (unsigned __int128)_Multiplicand;
  return _FullProduct >> 64;
}
void __cdecl _xrstor64(void const *, unsigned __int64);
void __cdecl _xsave64(void *, unsigned __int64);
void __cdecl _xsaveopt64(void *, unsigned __int64);

#endif /* __x86_64__ */

/*----------------------------------------------------------------------------*\
|* Bit Twiddling
\*----------------------------------------------------------------------------*/
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_rotl8(unsigned char _Value, unsigned char _Shift) {
  _Shift &= 0x7;
  return _Shift ? (_Value << _Shift) | (_Value >> (8 - _Shift)) : _Value;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_rotr8(unsigned char _Value, unsigned char _Shift) {
  _Shift &= 0x7;
  return _Shift ? (_Value >> _Shift) | (_Value << (8 - _Shift)) : _Value;
}
static __inline__ unsigned short __DEFAULT_FN_ATTRS
_rotl16(unsigned short _Value, unsigned char _Shift) {
  _Shift &= 0xf;
  return _Shift ? (_Value << _Shift) | (_Value >> (16 - _Shift)) : _Value;
}
static __inline__ unsigned short __DEFAULT_FN_ATTRS
_rotr16(unsigned short _Value, unsigned char _Shift) {
  _Shift &= 0xf;
  return _Shift ? (_Value >> _Shift) | (_Value << (16 - _Shift)) : _Value;
}
static __inline__ unsigned int __DEFAULT_FN_ATTRS
_rotl(unsigned int _Value, int _Shift) {
  _Shift &= 0x1f;
  return _Shift ? (_Value << _Shift) | (_Value >> (32 - _Shift)) : _Value;
}
static __inline__ unsigned int __DEFAULT_FN_ATTRS
_rotr(unsigned int _Value, int _Shift) {
  _Shift &= 0x1f;
  return _Shift ? (_Value >> _Shift) | (_Value << (32 - _Shift)) : _Value;
}
static __inline__ unsigned long __DEFAULT_FN_ATTRS
_lrotl(unsigned long _Value, int _Shift) {
  _Shift &= 0x1f;
  return _Shift ? (_Value << _Shift) | (_Value >> (32 - _Shift)) : _Value;
}
static __inline__ unsigned long __DEFAULT_FN_ATTRS
_lrotr(unsigned long _Value, int _Shift) {
  _Shift &= 0x1f;
  return _Shift ? (_Value >> _Shift) | (_Value << (32 - _Shift)) : _Value;
}
static
__inline__ unsigned __int64 __DEFAULT_FN_ATTRS
_rotl64(unsigned __int64 _Value, int _Shift) {
  _Shift &= 0x3f;
  return _Shift ? (_Value << _Shift) | (_Value >> (64 - _Shift)) : _Value;
}
static
__inline__ unsigned __int64 __DEFAULT_FN_ATTRS
_rotr64(unsigned __int64 _Value, int _Shift) {
  _Shift &= 0x3f;
  return _Shift ? (_Value >> _Shift) | (_Value << (64 - _Shift)) : _Value;
}
/*----------------------------------------------------------------------------*\
|* Bit Counting and Testing
\*----------------------------------------------------------------------------*/
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_BitScanForward(unsigned long *_Index, unsigned long _Mask) {
  if (!_Mask)
    return 0;
  *_Index = __builtin_ctzl(_Mask);
  return 1;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_BitScanReverse(unsigned long *_Index, unsigned long _Mask) {
  if (!_Mask)
    return 0;
  *_Index = 31 - __builtin_clzl(_Mask);
  return 1;
}
static __inline__ unsigned short __DEFAULT_FN_ATTRS
__popcnt16(unsigned short _Value) {
  return __builtin_popcount((int)_Value);
}
static __inline__ unsigned int __DEFAULT_FN_ATTRS
__popcnt(unsigned int _Value) {
  return __builtin_popcount(_Value);
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittest(long const *_BitBase, long _BitPos) {
  return (*_BitBase >> _BitPos) & 1;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandcomplement(long *_BitBase, long _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase ^ (1 << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandreset(long *_BitBase, long _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase & ~(1 << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandset(long *_BitBase, long _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase | (1 << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_interlockedbittestandset(long volatile *_BitBase, long _BitPos) {
  long _PrevVal = __atomic_fetch_or(_BitBase, 1l << _BitPos, __ATOMIC_SEQ_CST);
  return (_PrevVal >> _BitPos) & 1;
}
#ifdef __x86_64__
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_BitScanForward64(unsigned long *_Index, unsigned __int64 _Mask) {
  if (!_Mask)
    return 0;
  *_Index = __builtin_ctzll(_Mask);
  return 1;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_BitScanReverse64(unsigned long *_Index, unsigned __int64 _Mask) {
  if (!_Mask)
    return 0;
  *_Index = 63 - __builtin_clzll(_Mask);
  return 1;
}
static __inline__
unsigned __int64 __DEFAULT_FN_ATTRS
__popcnt64(unsigned __int64 _Value) {
  return __builtin_popcountll(_Value);
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittest64(__int64 const *_BitBase, __int64 _BitPos) {
  return (*_BitBase >> _BitPos) & 1;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandcomplement64(__int64 *_BitBase, __int64 _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase ^ (1ll << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandreset64(__int64 *_BitBase, __int64 _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase & ~(1ll << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_bittestandset64(__int64 *_BitBase, __int64 _BitPos) {
  unsigned char _Res = (*_BitBase >> _BitPos) & 1;
  *_BitBase = *_BitBase | (1ll << _BitPos);
  return _Res;
}
static __inline__ unsigned char __DEFAULT_FN_ATTRS
_interlockedbittestandset64(__int64 volatile *_BitBase, __int64 _BitPos) {
  long long _PrevVal =
      __atomic_fetch_or(_BitBase, 1ll << _BitPos, __ATOMIC_SEQ_CST);
  return (_PrevVal >> _BitPos) & 1;
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Exchange Add
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedExchangeAdd8(char volatile *_Addend, char _Value) {
  return __atomic_fetch_add(_Addend, _Value, __ATOMIC_SEQ_CST);
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedExchangeAdd16(short volatile *_Addend, short _Value) {
  return __atomic_fetch_add(_Addend, _Value, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedExchangeAdd64(__int64 volatile *_Addend, __int64 _Value) {
  return __atomic_fetch_add(_Addend, _Value, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Exchange Sub
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedExchangeSub8(char volatile *_Subend, char _Value) {
  return __atomic_fetch_sub(_Subend, _Value, __ATOMIC_SEQ_CST);
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedExchangeSub16(short volatile *_Subend, short _Value) {
  return __atomic_fetch_sub(_Subend, _Value, __ATOMIC_SEQ_CST);
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedExchangeSub(long volatile *_Subend, long _Value) {
  return __atomic_fetch_sub(_Subend, _Value, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedExchangeSub64(__int64 volatile *_Subend, __int64 _Value) {
  return __atomic_fetch_sub(_Subend, _Value, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Increment
\*----------------------------------------------------------------------------*/
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedIncrement16(short volatile *_Value) {
  return __atomic_add_fetch(_Value, 1, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedIncrement64(__int64 volatile *_Value) {
  return __atomic_add_fetch(_Value, 1, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Decrement
\*----------------------------------------------------------------------------*/
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedDecrement16(short volatile *_Value) {
  return __atomic_sub_fetch(_Value, 1, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedDecrement64(__int64 volatile *_Value) {
  return __atomic_sub_fetch(_Value, 1, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked And
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedAnd8(char volatile *_Value, char _Mask) {
  return __atomic_and_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedAnd16(short volatile *_Value, short _Mask) {
  return __atomic_and_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedAnd(long volatile *_Value, long _Mask) {
  return __atomic_and_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedAnd64(__int64 volatile *_Value, __int64 _Mask) {
  return __atomic_and_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Or
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedOr8(char volatile *_Value, char _Mask) {
  return __atomic_or_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedOr16(short volatile *_Value, short _Mask) {
  return __atomic_or_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedOr(long volatile *_Value, long _Mask) {
  return __atomic_or_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedOr64(__int64 volatile *_Value, __int64 _Mask) {
  return __atomic_or_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Xor
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedXor8(char volatile *_Value, char _Mask) {
  return __atomic_xor_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedXor16(short volatile *_Value, short _Mask) {
  return __atomic_xor_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
static __inline__ long __DEFAULT_FN_ATTRS
_InterlockedXor(long volatile *_Value, long _Mask) {
  return __atomic_xor_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedXor64(__int64 volatile *_Value, __int64 _Mask) {
  return __atomic_xor_fetch(_Value, _Mask, __ATOMIC_SEQ_CST);
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Exchange
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedExchange8(char volatile *_Target, char _Value) {
  __atomic_exchange(_Target, &_Value, &_Value, __ATOMIC_SEQ_CST);
  return _Value;
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedExchange16(short volatile *_Target, short _Value) {
  __atomic_exchange(_Target, &_Value, &_Value, __ATOMIC_SEQ_CST);
  return _Value;
}
#ifdef __x86_64__
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedExchange64(__int64 volatile *_Target, __int64 _Value) {
  __atomic_exchange(_Target, &_Value, &_Value, __ATOMIC_SEQ_CST);
  return _Value;
}
#endif
/*----------------------------------------------------------------------------*\
|* Interlocked Compare Exchange
\*----------------------------------------------------------------------------*/
static __inline__ char __DEFAULT_FN_ATTRS
_InterlockedCompareExchange8(char volatile *_Destination,
                             char _Exchange, char _Comparand) {
  __atomic_compare_exchange(_Destination, &_Comparand, &_Exchange, 0,
                            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
  return _Comparand;
}
static __inline__ short __DEFAULT_FN_ATTRS
_InterlockedCompareExchange16(short volatile *_Destination,
                              short _Exchange, short _Comparand) {
  __atomic_compare_exchange(_Destination, &_Comparand, &_Exchange, 0,
                            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
  return _Comparand;
}
static __inline__ __int64 __DEFAULT_FN_ATTRS
_InterlockedCompareExchange64(__int64 volatile *_Destination,
                              __int64 _Exchange, __int64 _Comparand) {
  __atomic_compare_exchange(_Destination, &_Comparand, &_Exchange, 0,
                            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
  return _Comparand;
}
/*----------------------------------------------------------------------------*\
|* Barriers
\*----------------------------------------------------------------------------*/
#if defined(__i386__) || defined(__x86_64__)
static __inline__ void __DEFAULT_FN_ATTRS
__attribute__((__deprecated__("use other intrinsics or C++11 atomics instead")))
_ReadWriteBarrier(void) {
  __asm__ volatile ("" : : : "memory");
}
static __inline__ void __DEFAULT_FN_ATTRS
__attribute__((__deprecated__("use other intrinsics or C++11 atomics instead")))
_ReadBarrier(void) {
  __asm__ volatile ("" : : : "memory");
}
static __inline__ void __DEFAULT_FN_ATTRS
__attribute__((__deprecated__("use other intrinsics or C++11 atomics instead")))
_WriteBarrier(void) {
  __asm__ volatile ("" : : : "memory");
}
#endif
#ifdef __x86_64__
static __inline__ void __DEFAULT_FN_ATTRS
__faststorefence(void) {
  __asm__ volatile("lock orq $0, (%%rsp)" : : : "memory");
}
#endif
/*----------------------------------------------------------------------------*\
|* readfs, readgs
|* (Pointers in address space #256 and #257 are relative to the GS and FS
|* segment registers, respectively.)
\*----------------------------------------------------------------------------*/
#define __ptr_to_addr_space(__addr_space_nbr, __type, __offset)              \
    ((volatile __type __attribute__((__address_space__(__addr_space_nbr)))*) \
    (__offset))

#ifdef __i386__
static __inline__ unsigned char __DEFAULT_FN_ATTRS
__readfsbyte(unsigned long __offset) {
  return *__ptr_to_addr_space(257, unsigned char, __offset);
}
static __inline__ unsigned __int64 __DEFAULT_FN_ATTRS
__readfsqword(unsigned long __offset) {
  return *__ptr_to_addr_space(257, unsigned __int64, __offset);
}
static __inline__ unsigned short __DEFAULT_FN_ATTRS
__readfsword(unsigned long __offset) {
  return *__ptr_to_addr_space(257, unsigned short, __offset);
}
#endif
#ifdef __x86_64__
static __inline__ unsigned char __DEFAULT_FN_ATTRS
__readgsbyte(unsigned long __offset) {
  return *__ptr_to_addr_space(256, unsigned char, __offset);
}
static __inline__ unsigned long __DEFAULT_FN_ATTRS
__readgsdword(unsigned long __offset) {
  return *__ptr_to_addr_space(256, unsigned long, __offset);
}
static __inline__ unsigned __int64 __DEFAULT_FN_ATTRS
__readgsqword(unsigned long __offset) {
  return *__ptr_to_addr_space(256, unsigned __int64, __offset);
}
static __inline__ unsigned short __DEFAULT_FN_ATTRS
__readgsword(unsigned long __offset) {
  return *__ptr_to_addr_space(256, unsigned short, __offset);
}
#endif
#undef __ptr_to_addr_space
/*----------------------------------------------------------------------------*\
|* movs, stos
\*----------------------------------------------------------------------------*/
#if defined(__i386__) || defined(__x86_64__)
static __inline__ void __DEFAULT_FN_ATTRS
__movsb(unsigned char *__dst, unsigned char const *__src, size_t __n) {
  __asm__("rep movsb" : : "D"(__dst), "S"(__src), "c"(__n)
                        : "%edi", "%esi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__movsd(unsigned long *__dst, unsigned long const *__src, size_t __n) {
  __asm__("rep movsl" : : "D"(__dst), "S"(__src), "c"(__n)
                        : "%edi", "%esi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__movsw(unsigned short *__dst, unsigned short const *__src, size_t __n) {
  __asm__("rep movsh" : : "D"(__dst), "S"(__src), "c"(__n)
                        : "%edi", "%esi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__stosb(unsigned char *__dst, unsigned char __x, size_t __n) {
  __asm__("rep stosb" : : "D"(__dst), "a"(__x), "c"(__n)
                        : "%edi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__stosd(unsigned long *__dst, unsigned long __x, size_t __n) {
  __asm__("rep stosl" : : "D"(__dst), "a"(__x), "c"(__n)
                        : "%edi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__stosw(unsigned short *__dst, unsigned short __x, size_t __n) {
  __asm__("rep stosh" : : "D"(__dst), "a"(__x), "c"(__n)
                        : "%edi", "%ecx");
}
#endif
#ifdef __x86_64__
static __inline__ void __DEFAULT_FN_ATTRS
__movsq(unsigned long long *__dst, unsigned long long const *__src, size_t __n) {
  __asm__("rep movsq" : : "D"(__dst), "S"(__src), "c"(__n)
                        : "%edi", "%esi", "%ecx");
}
static __inline__ void __DEFAULT_FN_ATTRS
__stosq(unsigned __int64 *__dst, unsigned __int64 __x, size_t __n) {
  __asm__("rep stosq" : : "D"(__dst), "a"(__x), "c"(__n)
                        : "%edi", "%ecx");
}
#endif

/*----------------------------------------------------------------------------*\
|* Misc
\*----------------------------------------------------------------------------*/
static __inline__ void * __DEFAULT_FN_ATTRS
_AddressOfReturnAddress(void) {
  return (void*)((char*)__builtin_frame_address(0) + sizeof(void*));
}
static __inline__ void * __DEFAULT_FN_ATTRS
_ReturnAddress(void) {
  return __builtin_return_address(0);
}
#if defined(__i386__) || defined(__x86_64__)
static __inline__ void __DEFAULT_FN_ATTRS
__cpuid(int __info[4], int __level) {
  __asm__ ("cpuid" : "=a"(__info[0]), "=b" (__info[1]), "=c"(__info[2]), "=d"(__info[3])
                   : "a"(__level));
}
static __inline__ void __DEFAULT_FN_ATTRS
__cpuidex(int __info[4], int __level, int __ecx) {
  __asm__ ("cpuid" : "=a"(__info[0]), "=b" (__info[1]), "=c"(__info[2]), "=d"(__info[3])
                   : "a"(__level), "c"(__ecx));
}
static __inline__ unsigned __int64 __cdecl __DEFAULT_FN_ATTRS
_xgetbv(unsigned int __xcr_no) {
  unsigned int __eax, __edx;
  __asm__ ("xgetbv" : "=a" (__eax), "=d" (__edx) : "c" (__xcr_no));
  return ((unsigned __int64)__edx << 32) | __eax;
}
static __inline__ void __DEFAULT_FN_ATTRS
__halt(void) {
  __asm__ volatile ("hlt");
}
#endif

/*----------------------------------------------------------------------------*\
|* Privileged intrinsics
\*----------------------------------------------------------------------------*/
#if defined(__i386__) || defined(__x86_64__)
static __inline__ unsigned __int64 __DEFAULT_FN_ATTRS
__readmsr(unsigned long __register) {
  // Loads the contents of a 64-bit model specific register (MSR) specified in
  // the ECX register into registers EDX:EAX. The EDX register is loaded with
  // the high-order 32 bits of the MSR and the EAX register is loaded with the
  // low-order 32 bits. If less than 64 bits are implemented in the MSR being
  // read, the values returned to EDX:EAX in unimplemented bit locations are
  // undefined.
  unsigned long __edx;
  unsigned long __eax;
  __asm__ ("rdmsr" : "=d"(__edx), "=a"(__eax) : "c"(__register));
  return (((unsigned __int64)__edx) << 32) | (unsigned __int64)__eax;
}

static __inline__ unsigned long __DEFAULT_FN_ATTRS
__readcr3(void) {
  unsigned long __cr3_val;
  __asm__ __volatile__ ("mov %%cr3, %0" : "=q"(__cr3_val) : : "memory");
  return __cr3_val;
}

static __inline__ void __DEFAULT_FN_ATTRS
__writecr3(unsigned int __cr3_val) {
  __asm__ ("mov %0, %%cr3" : : "q"(__cr3_val) : "memory");
}
#endif

#ifdef __cplusplus
}
#endif

#undef __DEFAULT_FN_ATTRS

#endif /* __INTRIN_H */
#endif /* _MSC_VER */
