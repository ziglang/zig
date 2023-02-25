#undef linux

#ifndef __STDC_WANT_IEC_60559_TYPES_EXT__
#define __STDC_WANT_IEC_60559_TYPES_EXT__
#endif
#include <float.h>
#include <limits.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

#if _MSC_VER
#include <intrin.h>
#elif defined(__i386__) || defined(__x86_64__)
#include <cpuid.h>
#endif

#if !defined(__cplusplus) && __STDC_VERSION__ <= 201710L
#if __STDC_VERSION__ >= 199901L
#include <stdbool.h>
#else
typedef char bool;
#define false 0
#define true  1
#endif
#endif

#if defined(__has_builtin)
#define zig_has_builtin(builtin) __has_builtin(__builtin_##builtin)
#else
#define zig_has_builtin(builtin) 0
#endif

#if defined(__has_attribute)
#define zig_has_attribute(attribute) __has_attribute(attribute)
#else
#define zig_has_attribute(attribute) 0
#endif

#if __STDC_VERSION__ >= 201112L
#define zig_threadlocal _Thread_local
#elif defined(__GNUC__)
#define zig_threadlocal __thread
#elif _MSC_VER
#define zig_threadlocal __declspec(thread)
#else
#define zig_threadlocal zig_threadlocal_unavailable
#endif

#if defined(__clang__)
#define zig_clang
#elif defined(__GNUC__)
#define zig_gnuc
#endif

#if _MSC_VER
#define zig_const_arr
#define zig_callconv(c) __##c
#else
#define zig_const_arr static const
#define zig_callconv(c) __attribute__((c))
#endif

#if zig_has_attribute(naked) || defined(zig_gnuc)
#define zig_naked_decl __attribute__((naked))
#define zig_naked __attribute__((naked))
#elif defined(_MSC_VER)
#define zig_naked_decl
#define zig_naked __declspec(naked)
#else
#define zig_naked_decl zig_naked_unavailable
#define zig_naked zig_naked_unavailable
#endif

#if zig_has_attribute(cold)
#define zig_cold __attribute__((cold))
#else
#define zig_cold
#endif

#if zig_has_attribute(flatten)
#define zig_maybe_flatten __attribute__((flatten))
#else
#define zig_maybe_flatten
#endif

#if zig_has_attribute(noinline)
#define zig_never_inline __attribute__((noinline)) zig_maybe_flatten
#elif defined(_MSC_VER)
#define zig_never_inline __declspec(noinline) zig_maybe_flatten
#else
#define zig_never_inline zig_never_inline_unavailable
#endif

#if zig_has_attribute(not_tail_called)
#define zig_never_tail __attribute__((not_tail_called)) zig_never_inline
#else
#define zig_never_tail zig_never_tail_unavailable
#endif

#if zig_has_attribute(always_inline)
#define zig_always_tail __attribute__((musttail))
#else
#define zig_always_tail zig_always_tail_unavailable
#endif

#if __STDC_VERSION__ >= 199901L
#define zig_restrict restrict
#elif defined(__GNUC__)
#define zig_restrict __restrict
#else
#define zig_restrict
#endif

#if __STDC_VERSION__ >= 201112L
#define zig_align(alignment) _Alignas(alignment)
#elif zig_has_attribute(aligned)
#define zig_align(alignment) __attribute__((aligned(alignment)))
#elif _MSC_VER
#define zig_align(alignment) __declspec(align(alignment))
#else
#define zig_align zig_align_unavailable
#endif

#if zig_has_attribute(aligned)
#define zig_under_align(alignment) __attribute__((aligned(alignment)))
#elif _MSC_VER
#define zig_under_align(alignment) zig_align(alignment)
#else
#define zig_align zig_align_unavailable
#endif

#if zig_has_attribute(aligned)
#define zig_align_fn(alignment) __attribute__((aligned(alignment)))
#elif _MSC_VER
#define zig_align_fn(alignment)
#else
#define zig_align_fn zig_align_fn_unavailable
#endif

#if zig_has_attribute(packed)
#define zig_packed(definition) __attribute__((packed)) definition
#elif _MSC_VER
#define zig_packed(definition) __pragma(pack(1)) definition __pragma(pack())
#else
#define zig_packed(definition) zig_packed_unavailable
#endif

#if zig_has_attribute(section)
#define zig_linksection(name, def, ...) def __attribute__((section(name)))
#elif _MSC_VER
#define zig_linksection(name, def, ...) __pragma(section(name, __VA_ARGS__)) __declspec(allocate(name)) def
#else
#define zig_linksection(name, def, ...) zig_linksection_unavailable
#endif

#if zig_has_builtin(unreachable) || defined(zig_gnuc)
#define zig_unreachable() __builtin_unreachable()
#else
#define zig_unreachable()
#endif

#if defined(__cplusplus)
#define zig_extern extern "C"
#else
#define zig_extern extern
#endif

#if zig_has_attribute(alias)
#define zig_export(sig, symbol, name) zig_extern sig __attribute__((alias(symbol)))
#elif _MSC_VER
#if _M_X64
#define zig_export(sig, symbol, name) sig;\
    __pragma(comment(linker, "/alternatename:" name "=" symbol ))
#else /*_M_X64 */
#define zig_export(sig, symbol, name) sig;\
    __pragma(comment(linker, "/alternatename:_" name "=_" symbol ))
#endif /*_M_X64 */
#else
#define zig_export(sig, symbol, name) __asm(name " = " symbol)
#endif

#if zig_has_builtin(debugtrap)
#define zig_breakpoint() __builtin_debugtrap()
#elif zig_has_builtin(trap) || defined(zig_gnuc)
#define zig_breakpoint() __builtin_trap()
#elif defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
#define zig_breakpoint() __debugbreak()
#elif defined(__i386__) || defined(__x86_64__)
#define zig_breakpoint() __asm__ volatile("int $0x03");
#else
#define zig_breakpoint() raise(SIGTRAP)
#endif

#if zig_has_builtin(return_address) || defined(zig_gnuc)
#define zig_return_address() __builtin_extract_return_addr(__builtin_return_address(0))
#elif defined(_MSC_VER)
#define zig_return_address() _ReturnAddress()
#else
#define zig_return_address() 0
#endif

#if zig_has_builtin(frame_address) || defined(zig_gnuc)
#define zig_frame_address() __builtin_frame_address(0)
#else
#define zig_frame_address() 0
#endif

#if zig_has_builtin(prefetch) || defined(zig_gnuc)
#define zig_prefetch(addr, rw, locality) __builtin_prefetch(addr, rw, locality)
#else
#define zig_prefetch(addr, rw, locality)
#endif

#if zig_has_builtin(memory_size) && zig_has_builtin(memory_grow)
#define zig_wasm_memory_size(index) __builtin_wasm_memory_size(index)
#define zig_wasm_memory_grow(index, delta) __builtin_wasm_memory_grow(index, delta)
#else
#define zig_wasm_memory_size(index) zig_unimplemented()
#define zig_wasm_memory_grow(index, delta) zig_unimplemented()
#endif

#define zig_concat(lhs, rhs) lhs##rhs
#define zig_expand_concat(lhs, rhs) zig_concat(lhs, rhs)

#if __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_ATOMICS__)
#include <stdatomic.h>
#define zig_atomic(type) _Atomic(type)
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail, type) atomic_compare_exchange_strong_explicit(obj, &(expected), desired, succ, fail)
#define   zig_cmpxchg_weak(obj, expected, desired, succ, fail, type) atomic_compare_exchange_weak_explicit  (obj, &(expected), desired, succ, fail)
#define zig_atomicrmw_xchg(obj, arg, order, type) atomic_exchange_explicit  (obj, arg, order)
#define  zig_atomicrmw_add(obj, arg, order, type) atomic_fetch_add_explicit (obj, arg, order)
#define  zig_atomicrmw_sub(obj, arg, order, type) atomic_fetch_sub_explicit (obj, arg, order)
#define   zig_atomicrmw_or(obj, arg, order, type) atomic_fetch_or_explicit  (obj, arg, order)
#define  zig_atomicrmw_xor(obj, arg, order, type) atomic_fetch_xor_explicit (obj, arg, order)
#define  zig_atomicrmw_and(obj, arg, order, type) atomic_fetch_and_explicit (obj, arg, order)
#define zig_atomicrmw_nand(obj, arg, order, type) __atomic_fetch_nand       (obj, arg, order)
#define  zig_atomicrmw_min(obj, arg, order, type) __atomic_fetch_min        (obj, arg, order)
#define  zig_atomicrmw_max(obj, arg, order, type) __atomic_fetch_max        (obj, arg, order)
#define   zig_atomic_store(obj, arg, order, type) atomic_store_explicit     (obj, arg, order)
#define    zig_atomic_load(obj,      order, type) atomic_load_explicit      (obj,      order)
#define zig_fence(order) atomic_thread_fence(order)
#elif defined(__GNUC__)
#define memory_order_relaxed __ATOMIC_RELAXED
#define memory_order_consume __ATOMIC_CONSUME
#define memory_order_acquire __ATOMIC_ACQUIRE
#define memory_order_release __ATOMIC_RELEASE
#define memory_order_acq_rel __ATOMIC_ACQ_REL
#define memory_order_seq_cst __ATOMIC_SEQ_CST
#define zig_atomic(type) type
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail, type) __atomic_compare_exchange_n(obj, &(expected), desired, false, succ, fail)
#define   zig_cmpxchg_weak(obj, expected, desired, succ, fail, type) __atomic_compare_exchange_n(obj, &(expected), desired, true , succ, fail)
#define zig_atomicrmw_xchg(obj, arg, order, type) __atomic_exchange_n(obj, arg, order)
#define  zig_atomicrmw_add(obj, arg, order, type) __atomic_fetch_add (obj, arg, order)
#define  zig_atomicrmw_sub(obj, arg, order, type) __atomic_fetch_sub (obj, arg, order)
#define   zig_atomicrmw_or(obj, arg, order, type) __atomic_fetch_or  (obj, arg, order)
#define  zig_atomicrmw_xor(obj, arg, order, type) __atomic_fetch_xor (obj, arg, order)
#define  zig_atomicrmw_and(obj, arg, order, type) __atomic_fetch_and (obj, arg, order)
#define zig_atomicrmw_nand(obj, arg, order, type) __atomic_fetch_nand(obj, arg, order)
#define  zig_atomicrmw_min(obj, arg, order, type) __atomic_fetch_min (obj, arg, order)
#define  zig_atomicrmw_max(obj, arg, order, type) __atomic_fetch_max (obj, arg, order)
#define   zig_atomic_store(obj, arg, order, type) __atomic_store_n   (obj, arg, order)
#define    zig_atomic_load(obj,      order, type) __atomic_load_n    (obj,      order)
#define zig_fence(order) __atomic_thread_fence(order)
#elif _MSC_VER && (_M_IX86 || _M_X64)
#define memory_order_relaxed 0
#define memory_order_consume 1
#define memory_order_acquire 2
#define memory_order_release 3
#define memory_order_acq_rel 4
#define memory_order_seq_cst 5
#define zig_atomic(type) type
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail, type) zig_expand_concat(zig_msvc_cmpxchg_, type)(obj, &(expected), desired)
#define   zig_cmpxchg_weak(obj, expected, desired, succ, fail, type) zig_cmpxchg_strong(obj, expected, desired, succ, fail, type)
#define zig_atomicrmw_xchg(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_xchg_, type)(obj, arg)
#define  zig_atomicrmw_add(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_add_, type)(obj, arg)
#define  zig_atomicrmw_sub(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_sub_, type)(obj, arg)
#define   zig_atomicrmw_or(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_or_, type)(obj, arg)
#define  zig_atomicrmw_xor(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_xor_, type)(obj, arg)
#define  zig_atomicrmw_and(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_and_, type)(obj, arg)
#define zig_atomicrmw_nand(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_nand_, type)(obj, arg)
#define  zig_atomicrmw_min(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_min_, type)(obj, arg)
#define  zig_atomicrmw_max(obj, arg, order, type) zig_expand_concat(zig_msvc_atomicrmw_max_, type)(obj, arg)
#define   zig_atomic_store(obj, arg, order, type) zig_expand_concat(zig_msvc_atomic_store_, type)(obj, arg)
#define    zig_atomic_load(obj,      order, type) zig_expand_concat(zig_msvc_atomic_load_, type)(obj)
#if _M_X64
#define zig_fence(order) __faststorefence()
#else
#define zig_fence(order) zig_msvc_atomic_barrier()
#endif

// TODO: _MSC_VER && (_M_ARM || _M_ARM64)
#else
#define memory_order_relaxed 0
#define memory_order_consume 1
#define memory_order_acquire 2
#define memory_order_release 3
#define memory_order_acq_rel 4
#define memory_order_seq_cst 5
#define zig_atomic(type) type
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail, type) zig_unimplemented()
#define   zig_cmpxchg_weak(obj, expected, desired, succ, fail, type) zig_unimplemented()
#define zig_atomicrmw_xchg(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_add(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_sub(obj, arg, order, type) zig_unimplemented()
#define   zig_atomicrmw_or(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_xor(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_and(obj, arg, order, type) zig_unimplemented()
#define zig_atomicrmw_nand(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_min(obj, arg, order, type) zig_unimplemented()
#define  zig_atomicrmw_max(obj, arg, order, type) zig_unimplemented()
#define   zig_atomic_store(obj, arg, order, type) zig_unimplemented()
#define    zig_atomic_load(obj,      order, type) zig_unimplemented()
#define zig_fence(order) zig_unimplemented()
#endif

#if __STDC_VERSION__ >= 201112L
#define zig_noreturn _Noreturn
#elif zig_has_attribute(noreturn) || defined(zig_gnuc)
#define zig_noreturn __attribute__((noreturn))
#elif _MSC_VER
#define zig_noreturn __declspec(noreturn)
#else
#define zig_noreturn
#endif

#define zig_bitSizeOf(T) (CHAR_BIT * sizeof(T))

#define zig_compiler_rt_abbrev_uint32_t si
#define zig_compiler_rt_abbrev_int32_t  si
#define zig_compiler_rt_abbrev_uint64_t di
#define zig_compiler_rt_abbrev_int64_t  di
#define zig_compiler_rt_abbrev_zig_u128 ti
#define zig_compiler_rt_abbrev_zig_i128 ti
#define zig_compiler_rt_abbrev_zig_f16  hf
#define zig_compiler_rt_abbrev_zig_f32  sf
#define zig_compiler_rt_abbrev_zig_f64  df
#define zig_compiler_rt_abbrev_zig_f80  xf
#define zig_compiler_rt_abbrev_zig_f128 tf

zig_extern void *memcpy (void *zig_restrict, void const *zig_restrict, size_t);
zig_extern void *memset (void *, int, size_t);

/* ===================== 8/16/32/64-bit Integer Support ===================== */

#if __STDC_VERSION__ >= 199901L || _MSC_VER
#include <stdint.h>
#else

#if SCHAR_MIN == ~0x7F && SCHAR_MAX == 0x7F && UCHAR_MAX == 0xFF
typedef unsigned      char uint8_t;
typedef   signed      char  int8_t;
#define  INT8_C(c) c
#define UINT8_C(c) c##U
#elif SHRT_MIN == ~0x7F && SHRT_MAX == 0x7F && USHRT_MAX == 0xFF
typedef unsigned     short uint8_t;
typedef   signed     short  int8_t;
#define  INT8_C(c) c
#define UINT8_C(c) c##U
#elif INT_MIN == ~0x7F && INT_MAX == 0x7F && UINT_MAX == 0xFF
typedef unsigned       int uint8_t;
typedef   signed       int  int8_t;
#define  INT8_C(c) c
#define UINT8_C(c) c##U
#elif LONG_MIN == ~0x7F && LONG_MAX == 0x7F && ULONG_MAX == 0xFF
typedef unsigned      long uint8_t;
typedef   signed      long  int8_t;
#define  INT8_C(c) c##L
#define UINT8_C(c) c##LU
#elif LLONG_MIN == ~0x7F && LLONG_MAX == 0x7F && ULLONG_MAX == 0xFF
typedef unsigned long long uint8_t;
typedef   signed long long  int8_t;
#define  INT8_C(c) c##LL
#define UINT8_C(c) c##LLU
#endif
#define  INT8_MIN (~INT8_C(0x7F))
#define  INT8_MAX ( INT8_C(0x7F))
#define UINT8_MAX ( INT8_C(0xFF))

#if SCHAR_MIN == ~0x7FFF && SCHAR_MAX == 0x7FFF && UCHAR_MAX == 0xFFFF
typedef unsigned      char uint16_t;
typedef   signed      char  int16_t;
#define  INT16_C(c) c
#define UINT16_C(c) c##U
#elif SHRT_MIN == ~0x7FFF && SHRT_MAX == 0x7FFF && USHRT_MAX == 0xFFFF
typedef unsigned     short uint16_t;
typedef   signed     short  int16_t;
#define  INT16_C(c) c
#define UINT16_C(c) c##U
#elif INT_MIN == ~0x7FFF && INT_MAX == 0x7FFF && UINT_MAX == 0xFFFF
typedef unsigned       int uint16_t;
typedef   signed       int  int16_t;
#define  INT16_C(c) c
#define UINT16_C(c) c##U
#elif LONG_MIN == ~0x7FFF && LONG_MAX == 0x7FFF && ULONG_MAX == 0xFFFF
typedef unsigned      long uint16_t;
typedef   signed      long  int16_t;
#define  INT16_C(c) c##L
#define UINT16_C(c) c##LU
#elif LLONG_MIN == ~0x7FFF && LLONG_MAX == 0x7FFF && ULLONG_MAX == 0xFFFF
typedef unsigned long long uint16_t;
typedef   signed long long  int16_t;
#define  INT16_C(c) c##LL
#define UINT16_C(c) c##LLU
#endif
#define  INT16_MIN (~INT16_C(0x7FFF))
#define  INT16_MAX ( INT16_C(0x7FFF))
#define UINT16_MAX ( INT16_C(0xFFFF))

#if SCHAR_MIN == ~0x7FFFFFFF && SCHAR_MAX == 0x7FFFFFFF && UCHAR_MAX == 0xFFFFFFFF
typedef unsigned      char uint32_t;
typedef   signed      char  int32_t;
#define  INT32_C(c) c
#define UINT32_C(c) c##U
#elif SHRT_MIN == ~0x7FFFFFFF && SHRT_MAX == 0x7FFFFFFF && USHRT_MAX == 0xFFFFFFFF
typedef unsigned     short uint32_t;
typedef   signed     short  int32_t;
#define  INT32_C(c) c
#define UINT32_C(c) c##U
#elif INT_MIN == ~0x7FFFFFFF && INT_MAX == 0x7FFFFFFF && UINT_MAX == 0xFFFFFFFF
typedef unsigned       int uint32_t;
typedef   signed       int  int32_t;
#define  INT32_C(c) c
#define UINT32_C(c) c##U
#elif LONG_MIN == ~0x7FFFFFFF && LONG_MAX == 0x7FFFFFFF && ULONG_MAX == 0xFFFFFFFF
typedef unsigned      long uint32_t;
typedef   signed      long  int32_t;
#define  INT32_C(c) c##L
#define UINT32_C(c) c##LU
#elif LLONG_MIN == ~0x7FFFFFFF && LLONG_MAX == 0x7FFFFFFF && ULLONG_MAX == 0xFFFFFFFF
typedef unsigned long long uint32_t;
typedef   signed long long  int32_t;
#define  INT32_C(c) c##LL
#define UINT32_C(c) c##LLU
#endif
#define  INT32_MIN (~INT32_C(0x7FFFFFFF))
#define  INT32_MAX ( INT32_C(0x7FFFFFFF))
#define UINT32_MAX ( INT32_C(0xFFFFFFFF))

#if SCHAR_MIN == ~0x7FFFFFFFFFFFFFFF && SCHAR_MAX == 0x7FFFFFFFFFFFFFFF && UCHAR_MAX == 0xFFFFFFFFFFFFFFFF
typedef unsigned      char uint64_t;
typedef   signed      char  int64_t;
#define  INT64_C(c) c
#define UINT64_C(c) c##U
#elif SHRT_MIN == ~0x7FFFFFFFFFFFFFFF && SHRT_MAX == 0x7FFFFFFFFFFFFFFF && USHRT_MAX == 0xFFFFFFFFFFFFFFFF
typedef unsigned     short uint64_t;
typedef   signed     short  int64_t;
#define  INT64_C(c) c
#define UINT64_C(c) c##U
#elif INT_MIN == ~0x7FFFFFFFFFFFFFFF && INT_MAX == 0x7FFFFFFFFFFFFFFF && UINT_MAX == 0xFFFFFFFFFFFFFFFF
typedef unsigned       int uint64_t;
typedef   signed       int  int64_t;
#define  INT64_C(c) c
#define UINT64_C(c) c##U
#elif LONG_MIN == ~0x7FFFFFFFFFFFFFFF && LONG_MAX == 0x7FFFFFFFFFFFFFFF && ULONG_MAX == 0xFFFFFFFFFFFFFFFF
typedef unsigned      long uint64_t;
typedef   signed      long  int64_t;
#define  INT64_C(c) c##L
#define UINT64_C(c) c##LU
#elif LLONG_MIN == ~0x7FFFFFFFFFFFFFFF && LLONG_MAX == 0x7FFFFFFFFFFFFFFF && ULLONG_MAX == 0xFFFFFFFFFFFFFFFF
typedef unsigned long long uint64_t;
typedef   signed long long  int64_t;
#define  INT64_C(c) c##LL
#define UINT64_C(c) c##LLU
#endif
#define  INT64_MIN (~INT64_C(0x7FFFFFFFFFFFFFFF))
#define  INT64_MAX ( INT64_C(0x7FFFFFFFFFFFFFFF))
#define UINT64_MAX ( INT64_C(0xFFFFFFFFFFFFFFFF))

typedef size_t uintptr_t;
typedef ptrdiff_t intptr_t;

#endif

#define zig_minInt_i8    INT8_MIN
#define zig_maxInt_i8    INT8_MAX
#define zig_minInt_u8   UINT8_C(0)
#define zig_maxInt_u8   UINT8_MAX
#define zig_minInt_i16  INT16_MIN
#define zig_maxInt_i16  INT16_MAX
#define zig_minInt_u16 UINT16_C(0)
#define zig_maxInt_u16 UINT16_MAX
#define zig_minInt_i32  INT32_MIN
#define zig_maxInt_i32  INT32_MAX
#define zig_minInt_u32 UINT32_C(0)
#define zig_maxInt_u32 UINT32_MAX
#define zig_minInt_i64  INT64_MIN
#define zig_maxInt_i64  INT64_MAX
#define zig_minInt_u64 UINT64_C(0)
#define zig_maxInt_u64 UINT64_MAX

#define zig_intLimit(s, w, limit, bits) zig_shr_##s##w(zig_##limit##Int_##s##w, w - (bits))
#define zig_minInt_i(w, bits) zig_intLimit(i, w, min, bits)
#define zig_maxInt_i(w, bits) zig_intLimit(i, w, max, bits)
#define zig_minInt_u(w, bits) zig_intLimit(u, w, min, bits)
#define zig_maxInt_u(w, bits) zig_intLimit(u, w, max, bits)

#define zig_int_operator(Type, RhsType, operation, operator) \
    static inline Type zig_##operation(Type lhs, RhsType rhs) { \
        return lhs operator rhs; \
    }
#define zig_int_basic_operator(Type, operation, operator) \
    zig_int_operator(Type,    Type, operation, operator)
#define zig_int_shift_operator(Type, operation, operator) \
    zig_int_operator(Type, uint8_t, operation, operator)
#define zig_int_helpers(w) \
    zig_int_basic_operator(uint##w##_t, and_u##w,  &) \
    zig_int_basic_operator( int##w##_t, and_i##w,  &) \
    zig_int_basic_operator(uint##w##_t,  or_u##w,  |) \
    zig_int_basic_operator( int##w##_t,  or_i##w,  |) \
    zig_int_basic_operator(uint##w##_t, xor_u##w,  ^) \
    zig_int_basic_operator( int##w##_t, xor_i##w,  ^) \
    zig_int_shift_operator(uint##w##_t, shl_u##w, <<) \
    zig_int_shift_operator( int##w##_t, shl_i##w, <<) \
    zig_int_shift_operator(uint##w##_t, shr_u##w, >>) \
\
    static inline int##w##_t zig_shr_i##w(int##w##_t lhs, uint8_t rhs) { \
        int##w##_t sign_mask = lhs < INT##w##_C(0) ? -INT##w##_C(1) : INT##w##_C(0); \
        return ((lhs ^ sign_mask) >> rhs) ^ sign_mask; \
    } \
\
    static inline uint##w##_t zig_not_u##w(uint##w##_t val, uint8_t bits) { \
        return val ^ zig_maxInt_u(w, bits); \
    } \
\
    static inline int##w##_t zig_not_i##w(int##w##_t val, uint8_t bits) { \
        (void)bits; \
        return ~val; \
    } \
\
    static inline uint##w##_t zig_wrap_u##w(uint##w##_t val, uint8_t bits) { \
        return val & zig_maxInt_u(w, bits); \
    } \
\
    static inline int##w##_t zig_wrap_i##w(int##w##_t val, uint8_t bits) { \
        return (val & UINT##w##_C(1) << (bits - UINT8_C(1))) != 0 \
            ? val | zig_minInt_i(w, bits) : val & zig_maxInt_i(w, bits); \
    } \
\
    zig_int_basic_operator(uint##w##_t, div_floor_u##w, /) \
\
    static inline int##w##_t zig_div_floor_i##w(int##w##_t lhs, int##w##_t rhs) { \
        return lhs / rhs - (((lhs ^ rhs) & (lhs % rhs)) < INT##w##_C(0)); \
    } \
\
    zig_int_basic_operator(uint##w##_t, mod_u##w, %) \
\
    static inline int##w##_t zig_mod_i##w(int##w##_t lhs, int##w##_t rhs) { \
        int##w##_t rem = lhs % rhs; \
        return rem + (((lhs ^ rhs) & rem) < INT##w##_C(0) ? rhs : INT##w##_C(0)); \
    } \
\
    static inline uint##w##_t zig_shlw_u##w(uint##w##_t lhs, uint8_t rhs, uint8_t bits) { \
        return zig_wrap_u##w(zig_shl_u##w(lhs, rhs), bits); \
    } \
\
    static inline int##w##_t zig_shlw_i##w(int##w##_t lhs, uint8_t rhs, uint8_t bits) { \
        return zig_wrap_i##w((int##w##_t)zig_shl_u##w((uint##w##_t)lhs, (uint##w##_t)rhs), bits); \
    } \
\
    static inline uint##w##_t zig_addw_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        return zig_wrap_u##w(lhs + rhs, bits); \
    } \
\
    static inline int##w##_t zig_addw_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        return zig_wrap_i##w((int##w##_t)((uint##w##_t)lhs + (uint##w##_t)rhs), bits); \
    } \
\
    static inline uint##w##_t zig_subw_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        return zig_wrap_u##w(lhs - rhs, bits); \
    } \
\
    static inline int##w##_t zig_subw_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        return zig_wrap_i##w((int##w##_t)((uint##w##_t)lhs - (uint##w##_t)rhs), bits); \
    } \
\
    static inline uint##w##_t zig_mulw_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        return zig_wrap_u##w(lhs * rhs, bits); \
    } \
\
    static inline int##w##_t zig_mulw_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        return zig_wrap_i##w((int##w##_t)((uint##w##_t)lhs * (uint##w##_t)rhs), bits); \
    }
zig_int_helpers(8)
zig_int_helpers(16)
zig_int_helpers(32)
zig_int_helpers(64)

static inline bool zig_addo_u32(uint32_t *res, uint32_t lhs, uint32_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    uint32_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u32(full_res, bits);
    return overflow || full_res < zig_minInt_u(32, bits) || full_res > zig_maxInt_u(32, bits);
#else
    *res = zig_addw_u32(lhs, rhs, bits);
    return *res < lhs;
#endif
}

static inline void zig_vaddo_u32(uint8_t *ov, uint32_t *res, int n,
    const uint32_t *lhs, const uint32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_u32(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int32_t  __addosi4(int32_t lhs, int32_t rhs, int *overflow);
static inline bool zig_addo_i32(int32_t *res, int32_t lhs, int32_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    int32_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int32_t full_res = __addosi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i32(full_res, bits);
    return overflow || full_res < zig_minInt_i(32, bits) || full_res > zig_maxInt_i(32, bits);
}

static inline void zig_vaddo_i32(uint8_t *ov, int32_t *res, int n,
    const int32_t *lhs, const int32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_i32(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_addo_u64(uint64_t *res, uint64_t lhs, uint64_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    uint64_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u64(full_res, bits);
    return overflow || full_res < zig_minInt_u(64, bits) || full_res > zig_maxInt_u(64, bits);
#else
    *res = zig_addw_u64(lhs, rhs, bits);
    return *res < lhs;
#endif
}

static inline void zig_vaddo_u64(uint8_t *ov, uint64_t *res, int n,
    const uint64_t *lhs, const uint64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_u64(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int64_t  __addodi4(int64_t lhs, int64_t rhs, int *overflow);
static inline bool zig_addo_i64(int64_t *res, int64_t lhs, int64_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    int64_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int64_t full_res = __addodi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i64(full_res, bits);
    return overflow || full_res < zig_minInt_i(64, bits) || full_res > zig_maxInt_i(64, bits);
}

static inline void zig_vaddo_i64(uint8_t *ov, int64_t *res, int n,
    const int64_t *lhs, const int64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_i64(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_addo_u8(uint8_t *res, uint8_t lhs, uint8_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    uint8_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u8(full_res, bits);
    return overflow || full_res < zig_minInt_u(8, bits) || full_res > zig_maxInt_u(8, bits);
#else
    uint32_t full_res;
    bool overflow = zig_addo_u32(&full_res, lhs, rhs, bits);
    *res = (uint8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vaddo_u8(uint8_t *ov, uint8_t *res, int n,
    const uint8_t *lhs, const uint8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_u8(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_addo_i8(int8_t *res, int8_t lhs, int8_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    int8_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i8(full_res, bits);
    return overflow || full_res < zig_minInt_i(8, bits) || full_res > zig_maxInt_i(8, bits);
#else
    int32_t full_res;
    bool overflow = zig_addo_i32(&full_res, lhs, rhs, bits);
    *res = (int8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vaddo_i8(uint8_t *ov, int8_t *res, int n,
    const int8_t *lhs, const int8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_i8(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_addo_u16(uint16_t *res, uint16_t lhs, uint16_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    uint16_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u16(full_res, bits);
    return overflow || full_res < zig_minInt_u(16, bits) || full_res > zig_maxInt_u(16, bits);
#else
    uint32_t full_res;
    bool overflow = zig_addo_u32(&full_res, lhs, rhs, bits);
    *res = (uint16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vaddo_u16(uint8_t *ov, uint16_t *res, int n,
    const uint16_t *lhs, const uint16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_u16(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_addo_i16(int16_t *res, int16_t lhs, int16_t rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow) || defined(zig_gnuc)
    int16_t full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i16(full_res, bits);
    return overflow || full_res < zig_minInt_i(16, bits) || full_res > zig_maxInt_i(16, bits);
#else
    int32_t full_res;
    bool overflow = zig_addo_i32(&full_res, lhs, rhs, bits);
    *res = (int16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vaddo_i16(uint8_t *ov, int16_t *res, int n,
    const int16_t *lhs, const int16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_addo_i16(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_subo_u32(uint32_t *res, uint32_t lhs, uint32_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    uint32_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u32(full_res, bits);
    return overflow || full_res < zig_minInt_u(32, bits) || full_res > zig_maxInt_u(32, bits);
#else
    *res = zig_subw_u32(lhs, rhs, bits);
    return *res > lhs;
#endif
}

static inline void zig_vsubo_u32(uint8_t *ov, uint32_t *res, int n,
    const uint32_t *lhs, const uint32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_u32(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int32_t  __subosi4(int32_t lhs, int32_t rhs, int *overflow);
static inline bool zig_subo_i32(int32_t *res, int32_t lhs, int32_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    int32_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int32_t full_res = __subosi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i32(full_res, bits);
    return overflow || full_res < zig_minInt_i(32, bits) || full_res > zig_maxInt_i(32, bits);
}

static inline void zig_vsubo_i32(uint8_t *ov, int32_t *res, int n,
    const int32_t *lhs, const int32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_i32(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_subo_u64(uint64_t *res, uint64_t lhs, uint64_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    uint64_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u64(full_res, bits);
    return overflow || full_res < zig_minInt_u(64, bits) || full_res > zig_maxInt_u(64, bits);
#else
    *res = zig_subw_u64(lhs, rhs, bits);
    return *res > lhs;
#endif
}

static inline void zig_vsubo_u64(uint8_t *ov, uint64_t *res, int n,
    const uint64_t *lhs, const uint64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_u64(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int64_t  __subodi4(int64_t lhs, int64_t rhs, int *overflow);
static inline bool zig_subo_i64(int64_t *res, int64_t lhs, int64_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    int64_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int64_t full_res = __subodi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i64(full_res, bits);
    return overflow || full_res < zig_minInt_i(64, bits) || full_res > zig_maxInt_i(64, bits);
}

static inline void zig_vsubo_i64(uint8_t *ov, int64_t *res, int n,
    const int64_t *lhs, const int64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_i64(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_subo_u8(uint8_t *res, uint8_t lhs, uint8_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    uint8_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u8(full_res, bits);
    return overflow || full_res < zig_minInt_u(8, bits) || full_res > zig_maxInt_u(8, bits);
#else
    uint32_t full_res;
    bool overflow = zig_subo_u32(&full_res, lhs, rhs, bits);
    *res = (uint8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vsubo_u8(uint8_t *ov, uint8_t *res, int n,
    const uint8_t *lhs, const uint8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_u8(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_subo_i8(int8_t *res, int8_t lhs, int8_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    int8_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i8(full_res, bits);
    return overflow || full_res < zig_minInt_i(8, bits) || full_res > zig_maxInt_i(8, bits);
#else
    int32_t full_res;
    bool overflow = zig_subo_i32(&full_res, lhs, rhs, bits);
    *res = (int8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vsubo_i8(uint8_t *ov, int8_t *res, int n,
    const int8_t *lhs, const int8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_i8(&res[i], lhs[i], rhs[i], bits);
}


static inline bool zig_subo_u16(uint16_t *res, uint16_t lhs, uint16_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    uint16_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u16(full_res, bits);
    return overflow || full_res < zig_minInt_u(16, bits) || full_res > zig_maxInt_u(16, bits);
#else
    uint32_t full_res;
    bool overflow = zig_subo_u32(&full_res, lhs, rhs, bits);
    *res = (uint16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vsubo_u16(uint8_t *ov, uint16_t *res, int n,
    const uint16_t *lhs, const uint16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_u16(&res[i], lhs[i], rhs[i], bits);
}


static inline bool zig_subo_i16(int16_t *res, int16_t lhs, int16_t rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow) || defined(zig_gnuc)
    int16_t full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i16(full_res, bits);
    return overflow || full_res < zig_minInt_i(16, bits) || full_res > zig_maxInt_i(16, bits);
#else
    int32_t full_res;
    bool overflow = zig_subo_i32(&full_res, lhs, rhs, bits);
    *res = (int16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vsubo_i16(uint8_t *ov, int16_t *res, int n,
    const int16_t *lhs, const int16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_subo_i16(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_u32(uint32_t *res, uint32_t lhs, uint32_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    uint32_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u32(full_res, bits);
    return overflow || full_res < zig_minInt_u(32, bits) || full_res > zig_maxInt_u(32, bits);
#else
    *res = zig_mulw_u32(lhs, rhs, bits);
    return rhs != UINT32_C(0) && lhs > zig_maxInt_u(32, bits) / rhs;
#endif
}

static inline void zig_vmulo_u32(uint8_t *ov, uint32_t *res, int n,
    const uint32_t *lhs, const uint32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_u32(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int32_t  __mulosi4(int32_t lhs, int32_t rhs, int *overflow);
static inline bool zig_mulo_i32(int32_t *res, int32_t lhs, int32_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    int32_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int32_t full_res = __mulosi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i32(full_res, bits);
    return overflow || full_res < zig_minInt_i(32, bits) || full_res > zig_maxInt_i(32, bits);
}

static inline void zig_vmulo_i32(uint8_t *ov, int32_t *res, int n,
    const int32_t *lhs, const int32_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_i32(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_u64(uint64_t *res, uint64_t lhs, uint64_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    uint64_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u64(full_res, bits);
    return overflow || full_res < zig_minInt_u(64, bits) || full_res > zig_maxInt_u(64, bits);
#else
    *res = zig_mulw_u64(lhs, rhs, bits);
    return rhs != UINT64_C(0) && lhs > zig_maxInt_u(64, bits) / rhs;
#endif
}

static inline void zig_vmulo_u64(uint8_t *ov, uint64_t *res, int n,
    const uint64_t *lhs, const uint64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_u64(&res[i], lhs[i], rhs[i], bits);
}

zig_extern int64_t  __mulodi4(int64_t lhs, int64_t rhs, int *overflow);
static inline bool zig_mulo_i64(int64_t *res, int64_t lhs, int64_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    int64_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    int64_t full_res = __mulodi4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i64(full_res, bits);
    return overflow || full_res < zig_minInt_i(64, bits) || full_res > zig_maxInt_i(64, bits);
}

static inline void zig_vmulo_i64(uint8_t *ov, int64_t *res, int n,
    const int64_t *lhs, const int64_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_i64(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_u8(uint8_t *res, uint8_t lhs, uint8_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    uint8_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u8(full_res, bits);
    return overflow || full_res < zig_minInt_u(8, bits) || full_res > zig_maxInt_u(8, bits);
#else
    uint32_t full_res;
    bool overflow = zig_mulo_u32(&full_res, lhs, rhs, bits);
    *res = (uint8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vmulo_u8(uint8_t *ov, uint8_t *res, int n,
    const uint8_t *lhs, const uint8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_u8(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_i8(int8_t *res, int8_t lhs, int8_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    int8_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i8(full_res, bits);
    return overflow || full_res < zig_minInt_i(8, bits) || full_res > zig_maxInt_i(8, bits);
#else
    int32_t full_res;
    bool overflow = zig_mulo_i32(&full_res, lhs, rhs, bits);
    *res = (int8_t)full_res;
    return overflow;
#endif
}

static inline void zig_vmulo_i8(uint8_t *ov, int8_t *res, int n,
    const int8_t *lhs, const int8_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_i8(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_u16(uint16_t *res, uint16_t lhs, uint16_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    uint16_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u16(full_res, bits);
    return overflow || full_res < zig_minInt_u(16, bits) || full_res > zig_maxInt_u(16, bits);
#else
    uint32_t full_res;
    bool overflow = zig_mulo_u32(&full_res, lhs, rhs, bits);
    *res = (uint16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vmulo_u16(uint8_t *ov, uint16_t *res, int n,
    const uint16_t *lhs, const uint16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_u16(&res[i], lhs[i], rhs[i], bits);
}

static inline bool zig_mulo_i16(int16_t *res, int16_t lhs, int16_t rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow) || defined(zig_gnuc)
    int16_t full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_i16(full_res, bits);
    return overflow || full_res < zig_minInt_i(16, bits) || full_res > zig_maxInt_i(16, bits);
#else
    int32_t full_res;
    bool overflow = zig_mulo_i32(&full_res, lhs, rhs, bits);
    *res = (int16_t)full_res;
    return overflow;
#endif
}

static inline void zig_vmulo_i16(uint8_t *ov, int16_t *res, int n,
    const int16_t *lhs, const int16_t *rhs, uint8_t bits)
{
    for (int i = 0; i < n; ++i) ov[i] = zig_mulo_i16(&res[i], lhs[i], rhs[i], bits);
}

#define zig_int_builtins(w) \
    static inline bool zig_shlo_u##w(uint##w##_t *res, uint##w##_t lhs, uint8_t rhs, uint8_t bits) { \
        *res = zig_shlw_u##w(lhs, rhs, bits); \
        return lhs > zig_maxInt_u(w, bits) >> rhs; \
    } \
\
    static inline bool zig_shlo_i##w(int##w##_t *res, int##w##_t lhs, uint8_t rhs, uint8_t bits) { \
        *res = zig_shlw_i##w(lhs, rhs, bits); \
        int##w##_t mask = (int##w##_t)(UINT##w##_MAX << (bits - rhs - 1)); \
        return (lhs & mask) != INT##w##_C(0) && (lhs & mask) != mask; \
    } \
\
    static inline uint##w##_t zig_shls_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        uint##w##_t res; \
        if (rhs >= bits) return lhs != UINT##w##_C(0) ? zig_maxInt_u(w, bits) : lhs; \
        return zig_shlo_u##w(&res, lhs, (uint8_t)rhs, bits) ? zig_maxInt_u(w, bits) : res; \
    } \
\
    static inline int##w##_t zig_shls_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        int##w##_t res; \
        if ((uint##w##_t)rhs < (uint##w##_t)bits && !zig_shlo_i##w(&res, lhs, (uint8_t)rhs, bits)) return res; \
        return lhs < INT##w##_C(0) ? zig_minInt_i(w, bits) : zig_maxInt_i(w, bits); \
    } \
\
    static inline uint##w##_t zig_adds_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        uint##w##_t res; \
        return zig_addo_u##w(&res, lhs, rhs, bits) ? zig_maxInt_u(w, bits) : res; \
    } \
\
    static inline int##w##_t zig_adds_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        int##w##_t res; \
        if (!zig_addo_i##w(&res, lhs, rhs, bits)) return res; \
        return res >= INT##w##_C(0) ? zig_minInt_i(w, bits) : zig_maxInt_i(w, bits); \
    } \
\
    static inline uint##w##_t zig_subs_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        uint##w##_t res; \
        return zig_subo_u##w(&res, lhs, rhs, bits) ? zig_minInt_u(w, bits) : res; \
    } \
\
    static inline int##w##_t zig_subs_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        int##w##_t res; \
        if (!zig_subo_i##w(&res, lhs, rhs, bits)) return res; \
        return res >= INT##w##_C(0) ? zig_minInt_i(w, bits) : zig_maxInt_i(w, bits); \
    } \
\
    static inline uint##w##_t zig_muls_u##w(uint##w##_t lhs, uint##w##_t rhs, uint8_t bits) { \
        uint##w##_t res; \
        return zig_mulo_u##w(&res, lhs, rhs, bits) ? zig_maxInt_u(w, bits) : res; \
    } \
\
    static inline int##w##_t zig_muls_i##w(int##w##_t lhs, int##w##_t rhs, uint8_t bits) { \
        int##w##_t res; \
        if (!zig_mulo_i##w(&res, lhs, rhs, bits)) return res; \
        return (lhs ^ rhs) < INT##w##_C(0) ? zig_minInt_i(w, bits) : zig_maxInt_i(w, bits); \
    }
zig_int_builtins(8)
zig_int_builtins(16)
zig_int_builtins(32)
zig_int_builtins(64)

#define zig_builtin8(name, val) __builtin_##name(val)
typedef unsigned int zig_Builtin8;

#define zig_builtin16(name, val) __builtin_##name(val)
typedef unsigned int zig_Builtin16;

#if INT_MIN <= INT32_MIN
#define zig_builtin32(name, val) __builtin_##name(val)
typedef unsigned int zig_Builtin32;
#elif LONG_MIN <= INT32_MIN
#define zig_builtin32(name, val) __builtin_##name##l(val)
typedef unsigned long zig_Builtin32;
#endif

#if INT_MIN <= INT64_MIN
#define zig_builtin64(name, val) __builtin_##name(val)
typedef unsigned int zig_Builtin64;
#elif LONG_MIN <= INT64_MIN
#define zig_builtin64(name, val) __builtin_##name##l(val)
typedef unsigned long zig_Builtin64;
#elif LLONG_MIN <= INT64_MIN
#define zig_builtin64(name, val) __builtin_##name##ll(val)
typedef unsigned long long zig_Builtin64;
#endif

static inline uint8_t zig_byte_swap_u8(uint8_t val, uint8_t bits) {
    return zig_wrap_u8(val >> (8 - bits), bits);
}

static inline int8_t zig_byte_swap_i8(int8_t val, uint8_t bits) {
    return zig_wrap_i8((int8_t)zig_byte_swap_u8((uint8_t)val, bits), bits);
}

static inline uint16_t zig_byte_swap_u16(uint16_t val, uint8_t bits) {
    uint16_t full_res;
#if zig_has_builtin(bswap16) || defined(zig_gnuc)
    full_res = __builtin_bswap16(val);
#else
    full_res = (uint16_t)zig_byte_swap_u8((uint8_t)(val >>  0), 8) <<  8 |
               (uint16_t)zig_byte_swap_u8((uint8_t)(val >>  8), 8) >>  0;
#endif
    return zig_wrap_u16(full_res >> (16 - bits), bits);
}

static inline int16_t zig_byte_swap_i16(int16_t val, uint8_t bits) {
    return zig_wrap_i16((int16_t)zig_byte_swap_u16((uint16_t)val, bits), bits);
}

static inline uint32_t zig_byte_swap_u32(uint32_t val, uint8_t bits) {
    uint32_t full_res;
#if zig_has_builtin(bswap32) || defined(zig_gnuc)
    full_res = __builtin_bswap32(val);
#else
    full_res = (uint32_t)zig_byte_swap_u16((uint16_t)(val >>  0), 16) << 16 |
               (uint32_t)zig_byte_swap_u16((uint16_t)(val >> 16), 16) >>  0;
#endif
    return zig_wrap_u32(full_res >> (32 - bits), bits);
}

static inline int32_t zig_byte_swap_i32(int32_t val, uint8_t bits) {
    return zig_wrap_i32((int32_t)zig_byte_swap_u32((uint32_t)val, bits), bits);
}

static inline uint64_t zig_byte_swap_u64(uint64_t val, uint8_t bits) {
    uint64_t full_res;
#if zig_has_builtin(bswap64) || defined(zig_gnuc)
    full_res = __builtin_bswap64(val);
#else
    full_res = (uint64_t)zig_byte_swap_u32((uint32_t)(val >>  0), 32) << 32 |
               (uint64_t)zig_byte_swap_u32((uint32_t)(val >> 32), 32) >>  0;
#endif
    return zig_wrap_u64(full_res >> (64 - bits), bits);
}

static inline int64_t zig_byte_swap_i64(int64_t val, uint8_t bits) {
    return zig_wrap_i64((int64_t)zig_byte_swap_u64((uint64_t)val, bits), bits);
}

static inline uint8_t zig_bit_reverse_u8(uint8_t val, uint8_t bits) {
    uint8_t full_res;
#if zig_has_builtin(bitreverse8)
    full_res = __builtin_bitreverse8(val);
#else
    static uint8_t const lut[0x10] = {
        0x0, 0x8, 0x4, 0xc, 0x2, 0xa, 0x6, 0xe,
        0x1, 0x9, 0x5, 0xd, 0x3, 0xb, 0x7, 0xf
    };
    full_res = lut[val >> 0 & 0xF] << 4 | lut[val >> 4 & 0xF] << 0;
#endif
    return zig_wrap_u8(full_res >> (8 - bits), bits);
}

static inline int8_t zig_bit_reverse_i8(int8_t val, uint8_t bits) {
    return zig_wrap_i8((int8_t)zig_bit_reverse_u8((uint8_t)val, bits), bits);
}

static inline uint16_t zig_bit_reverse_u16(uint16_t val, uint8_t bits) {
    uint16_t full_res;
#if zig_has_builtin(bitreverse16)
    full_res = __builtin_bitreverse16(val);
#else
    full_res = (uint16_t)zig_bit_reverse_u8((uint8_t)(val >>  0), 8) <<  8 |
               (uint16_t)zig_bit_reverse_u8((uint8_t)(val >>  8), 8) >>  0;
#endif
    return zig_wrap_u16(full_res >> (16 - bits), bits);
}

static inline int16_t zig_bit_reverse_i16(int16_t val, uint8_t bits) {
    return zig_wrap_i16((int16_t)zig_bit_reverse_u16((uint16_t)val, bits), bits);
}

static inline uint32_t zig_bit_reverse_u32(uint32_t val, uint8_t bits) {
    uint32_t full_res;
#if zig_has_builtin(bitreverse32)
    full_res = __builtin_bitreverse32(val);
#else
    full_res = (uint32_t)zig_bit_reverse_u16((uint16_t)(val >>  0), 16) << 16 |
               (uint32_t)zig_bit_reverse_u16((uint16_t)(val >> 16), 16) >>  0;
#endif
    return zig_wrap_u32(full_res >> (32 - bits), bits);
}

static inline int32_t zig_bit_reverse_i32(int32_t val, uint8_t bits) {
    return zig_wrap_i32((int32_t)zig_bit_reverse_u32((uint32_t)val, bits), bits);
}

static inline uint64_t zig_bit_reverse_u64(uint64_t val, uint8_t bits) {
    uint64_t full_res;
#if zig_has_builtin(bitreverse64)
    full_res = __builtin_bitreverse64(val);
#else
    full_res = (uint64_t)zig_bit_reverse_u32((uint32_t)(val >>  0), 32) << 32 |
               (uint64_t)zig_bit_reverse_u32((uint32_t)(val >> 32), 32) >>  0;
#endif
    return zig_wrap_u64(full_res >> (64 - bits), bits);
}

static inline int64_t zig_bit_reverse_i64(int64_t val, uint8_t bits) {
    return zig_wrap_i64((int64_t)zig_bit_reverse_u64((uint64_t)val, bits), bits);
}

#define zig_builtin_popcount_common(w) \
    static inline uint8_t zig_popcount_i##w(int##w##_t val, uint8_t bits) { \
        return zig_popcount_u##w((uint##w##_t)val, bits); \
    }
#if zig_has_builtin(popcount) || defined(zig_gnuc)
#define zig_builtin_popcount(w) \
    static inline uint8_t zig_popcount_u##w(uint##w##_t val, uint8_t bits) { \
        (void)bits; \
        return zig_builtin##w(popcount, val); \
    } \
\
    zig_builtin_popcount_common(w)
#else
#define zig_builtin_popcount(w) \
    static inline uint8_t zig_popcount_u##w(uint##w##_t val, uint8_t bits) { \
        (void)bits; \
        uint##w##_t temp = val - ((val >> 1) & (UINT##w##_MAX / 3)); \
        temp = (temp & (UINT##w##_MAX / 5)) + ((temp >> 2) & (UINT##w##_MAX / 5)); \
        temp = (temp + (temp >> 4)) & (UINT##w##_MAX / 17); \
        return temp * (UINT##w##_MAX / 255) >> (w - 8); \
    } \
\
    zig_builtin_popcount_common(w)
#endif
zig_builtin_popcount(8)
zig_builtin_popcount(16)
zig_builtin_popcount(32)
zig_builtin_popcount(64)

#define zig_builtin_ctz_common(w) \
    static inline uint8_t zig_ctz_i##w(int##w##_t val, uint8_t bits) { \
        return zig_ctz_u##w((uint##w##_t)val, bits); \
    }
#if zig_has_builtin(ctz) || defined(zig_gnuc)
#define zig_builtin_ctz(w) \
    static inline uint8_t zig_ctz_u##w(uint##w##_t val, uint8_t bits) { \
        if (val == 0) return bits; \
        return zig_builtin##w(ctz, val); \
    } \
\
    zig_builtin_ctz_common(w)
#else
#define zig_builtin_ctz(w) \
    static inline uint8_t zig_ctz_u##w(uint##w##_t val, uint8_t bits) { \
        return zig_popcount_u##w(zig_not_u##w(val, bits) & zig_subw_u##w(val, 1, bits), bits); \
    } \
\
    zig_builtin_ctz_common(w)
#endif
zig_builtin_ctz(8)
zig_builtin_ctz(16)
zig_builtin_ctz(32)
zig_builtin_ctz(64)

#define zig_builtin_clz_common(w) \
    static inline uint8_t zig_clz_i##w(int##w##_t val, uint8_t bits) { \
        return zig_clz_u##w((uint##w##_t)val, bits); \
    }
#if zig_has_builtin(clz) || defined(zig_gnuc)
#define zig_builtin_clz(w) \
    static inline uint8_t zig_clz_u##w(uint##w##_t val, uint8_t bits) { \
        if (val == 0) return bits; \
        return zig_builtin##w(clz, val) - (zig_bitSizeOf(zig_Builtin##w) - bits); \
    } \
\
    zig_builtin_clz_common(w)
#else
#define zig_builtin_clz(w) \
    static inline uint8_t zig_clz_u##w(uint##w##_t val, uint8_t bits) { \
        return zig_ctz_u##w(zig_bit_reverse_u##w(val, bits), bits); \
    } \
\
    zig_builtin_clz_common(w)
#endif
zig_builtin_clz(8)
zig_builtin_clz(16)
zig_builtin_clz(32)
zig_builtin_clz(64)

/* ======================== 128-bit Integer Support ========================= */

#if !defined(zig_has_int128)
# if defined(__SIZEOF_INT128__)
#  define zig_has_int128 1
# else
#  define zig_has_int128 0
# endif
#endif

#if zig_has_int128

typedef unsigned __int128 zig_u128;
typedef   signed __int128 zig_i128;

#define zig_make_u128(hi, lo) ((zig_u128)(hi)<<64|(lo))
#define zig_make_i128(hi, lo) ((zig_i128)zig_make_u128(hi, lo))
#define zig_make_constant_u128(hi, lo) zig_make_u128(hi, lo)
#define zig_make_constant_i128(hi, lo) zig_make_i128(hi, lo)
#define zig_hi_u128(val) ((uint64_t)((val) >> 64))
#define zig_lo_u128(val) ((uint64_t)((val) >>  0))
#define zig_hi_i128(val) (( int64_t)((val) >> 64))
#define zig_lo_i128(val) ((uint64_t)((val) >>  0))
#define zig_bitcast_u128(val) ((zig_u128)(val))
#define zig_bitcast_i128(val) ((zig_i128)(val))
#define zig_cmp_int128(Type) \
    static inline int32_t zig_cmp_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return (lhs > rhs) - (lhs < rhs); \
    }
#define zig_bit_int128(Type, operation, operator) \
    static inline zig_##Type zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return lhs operator rhs; \
    }

#else /* zig_has_int128 */

#if __LITTLE_ENDIAN__ || _MSC_VER
typedef struct { zig_align(16) uint64_t lo; uint64_t hi; } zig_u128;
typedef struct { zig_align(16) uint64_t lo; int64_t hi; } zig_i128;
#else
typedef struct { zig_align(16) uint64_t hi; uint64_t lo; } zig_u128;
typedef struct { zig_align(16) int64_t hi; uint64_t lo; } zig_i128;
#endif

#define zig_make_u128(hi, lo) ((zig_u128){ .h##i = (hi), .l##o = (lo) })
#define zig_make_i128(hi, lo) ((zig_i128){ .h##i = (hi), .l##o = (lo) })

#if _MSC_VER /* MSVC doesn't allow struct literals in constant expressions */
#define zig_make_constant_u128(hi, lo) { .h##i = (hi), .l##o = (lo) }
#define zig_make_constant_i128(hi, lo) { .h##i = (hi), .l##o = (lo) }
#else /* But non-MSVC doesn't like the unprotected commas */
#define zig_make_constant_u128(hi, lo) zig_make_u128(hi, lo)
#define zig_make_constant_i128(hi, lo) zig_make_i128(hi, lo)
#endif
#define zig_hi_u128(val) ((val).hi)
#define zig_lo_u128(val) ((val).lo)
#define zig_hi_i128(val) ((val).hi)
#define zig_lo_i128(val) ((val).lo)
#define zig_bitcast_u128(val) zig_make_u128((uint64_t)(val).hi, (val).lo)
#define zig_bitcast_i128(val) zig_make_i128(( int64_t)(val).hi, (val).lo)
#define zig_cmp_int128(Type) \
    static inline int32_t zig_cmp_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return (lhs.hi == rhs.hi) \
            ? (lhs.lo > rhs.lo) - (lhs.lo < rhs.lo) \
            : (lhs.hi > rhs.hi) - (lhs.hi < rhs.hi); \
    }
#define zig_bit_int128(Type, operation, operator) \
    static inline zig_##Type zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return (zig_##Type){ .hi = lhs.hi operator rhs.hi, .lo = lhs.lo operator rhs.lo }; \
    }

#endif /* zig_has_int128 */

#define zig_minInt_u128 zig_make_u128(zig_minInt_u64, zig_minInt_u64)
#define zig_maxInt_u128 zig_make_u128(zig_maxInt_u64, zig_maxInt_u64)
#define zig_minInt_i128 zig_make_i128(zig_minInt_i64, zig_minInt_u64)
#define zig_maxInt_i128 zig_make_i128(zig_maxInt_i64, zig_maxInt_u64)

zig_cmp_int128(u128)
zig_cmp_int128(i128)

zig_bit_int128(u128, and, &)
zig_bit_int128(i128, and, &)

zig_bit_int128(u128,  or, |)
zig_bit_int128(i128,  or, |)

zig_bit_int128(u128, xor, ^)
zig_bit_int128(i128, xor, ^)

static inline zig_u128 zig_shr_u128(zig_u128 lhs, uint8_t rhs);

#if zig_has_int128

static inline zig_u128 zig_not_u128(zig_u128 val, uint8_t bits) {
    return val ^ zig_maxInt_u(128, bits);
}

static inline zig_i128 zig_not_i128(zig_i128 val, uint8_t bits) {
    (void)bits;
    return ~val;
}

static inline zig_u128 zig_shr_u128(zig_u128 lhs, uint8_t rhs) {
    return lhs >> rhs;
}

static inline zig_u128 zig_shl_u128(zig_u128 lhs, uint8_t rhs) {
    return lhs << rhs;
}

static inline zig_i128 zig_shr_i128(zig_i128 lhs, uint8_t rhs) {
    zig_i128 sign_mask = lhs < zig_make_i128(0, 0) ? -zig_make_i128(0, 1) : zig_make_i128(0, 0);
    return ((lhs ^ sign_mask) >> rhs) ^ sign_mask;
}

static inline zig_i128 zig_shl_i128(zig_i128 lhs, uint8_t rhs) {
    return lhs << rhs;
}

static inline zig_u128 zig_add_u128(zig_u128 lhs, zig_u128 rhs) {
    return lhs + rhs;
}

static inline zig_i128 zig_add_i128(zig_i128 lhs, zig_i128 rhs) {
    return lhs + rhs;
}

static inline zig_u128 zig_sub_u128(zig_u128 lhs, zig_u128 rhs) {
    return lhs - rhs;
}

static inline zig_i128 zig_sub_i128(zig_i128 lhs, zig_i128 rhs) {
    return lhs - rhs;
}

static inline zig_u128 zig_mul_u128(zig_u128 lhs, zig_u128 rhs) {
    return lhs * rhs;
}

static inline zig_i128 zig_mul_i128(zig_i128 lhs, zig_i128 rhs) {
    return lhs * rhs;
}

static inline zig_u128 zig_div_trunc_u128(zig_u128 lhs, zig_u128 rhs) {
    return lhs / rhs;
}

static inline zig_i128 zig_div_trunc_i128(zig_i128 lhs, zig_i128 rhs) {
    return lhs / rhs;
}

static inline zig_u128 zig_rem_u128(zig_u128 lhs, zig_u128 rhs) {
    return lhs % rhs;
}

static inline zig_i128 zig_rem_i128(zig_i128 lhs, zig_i128 rhs) {
    return lhs % rhs;
}

static inline zig_i128 zig_div_floor_i128(zig_i128 lhs, zig_i128 rhs) {
    return zig_div_trunc_i128(lhs, rhs) - (((lhs ^ rhs) & zig_rem_i128(lhs, rhs)) < zig_make_i128(0, 0));
}

static inline zig_i128 zig_mod_i128(zig_i128 lhs, zig_i128 rhs) {
    zig_i128 rem = zig_rem_i128(lhs, rhs);
    return rem + (((lhs ^ rhs) & rem) < zig_make_i128(0, 0) ? rhs : zig_make_i128(0, 0));
}

#else /* zig_has_int128 */

static inline zig_u128 zig_not_u128(zig_u128 val, uint8_t bits) {
    return (zig_u128){ .hi = zig_not_u64(val.hi, bits - UINT8_C(64)), .lo = zig_not_u64(val.lo, UINT8_C(64)) };
}

static inline zig_i128 zig_not_i128(zig_i128 val, uint8_t bits) {
    return (zig_i128){ .hi = zig_not_i64(val.hi, bits - UINT8_C(64)), .lo = zig_not_u64(val.lo, UINT8_C(64)) };
}

static inline zig_u128 zig_shr_u128(zig_u128 lhs, uint8_t rhs) {
    if (rhs == UINT8_C(0)) return lhs;
    if (rhs >= UINT8_C(64)) return (zig_u128){ .hi = zig_minInt_u64, .lo = lhs.hi >> (rhs - UINT8_C(64)) };
    return (zig_u128){ .hi = lhs.hi >> rhs, .lo = lhs.hi << (UINT8_C(64) - rhs) | lhs.lo >> rhs };
}

static inline zig_u128 zig_shl_u128(zig_u128 lhs, uint8_t rhs) {
    if (rhs == UINT8_C(0)) return lhs;
    if (rhs >= UINT8_C(64)) return (zig_u128){ .hi = lhs.lo << (rhs - UINT8_C(64)), .lo = zig_minInt_u64 };
    return (zig_u128){ .hi = lhs.hi << rhs | lhs.lo >> (UINT8_C(64) - rhs), .lo = lhs.lo << rhs };
}

static inline zig_i128 zig_shr_i128(zig_i128 lhs, uint8_t rhs) {
    if (rhs == UINT8_C(0)) return lhs;
    if (rhs >= UINT8_C(64)) return (zig_i128){ .hi = zig_shr_i64(lhs.hi, 63), .lo = zig_shr_i64(lhs.hi, (rhs - UINT8_C(64))) };
    return (zig_i128){ .hi = zig_shr_i64(lhs.hi, rhs), .lo = lhs.lo >> rhs | (uint64_t)lhs.hi << (UINT8_C(64) - rhs) };
}

static inline zig_i128 zig_shl_i128(zig_i128 lhs, uint8_t rhs) {
    if (rhs == UINT8_C(0)) return lhs;
    if (rhs >= UINT8_C(64)) return (zig_i128){ .hi = lhs.lo << (rhs - UINT8_C(64)), .lo = zig_minInt_u64 };
    return (zig_i128){ .hi = lhs.hi << rhs | lhs.lo >> (UINT8_C(64) - rhs), .lo = lhs.lo << rhs };
}

static inline zig_u128 zig_add_u128(zig_u128 lhs, zig_u128 rhs) {
    zig_u128 res;
    res.hi = lhs.hi + rhs.hi + zig_addo_u64(&res.lo, lhs.lo, rhs.lo, 64);
    return res;
}

static inline zig_i128 zig_add_i128(zig_i128 lhs, zig_i128 rhs) {
    zig_i128 res;
    res.hi = lhs.hi + rhs.hi + zig_addo_u64(&res.lo, lhs.lo, rhs.lo, 64);
    return res;
}

static inline zig_u128 zig_sub_u128(zig_u128 lhs, zig_u128 rhs) {
    zig_u128 res;
    res.hi = lhs.hi - rhs.hi - zig_subo_u64(&res.lo, lhs.lo, rhs.lo, 64);
    return res;
}

static inline zig_i128 zig_sub_i128(zig_i128 lhs, zig_i128 rhs) {
    zig_i128 res;
    res.hi = lhs.hi - rhs.hi - zig_subo_u64(&res.lo, lhs.lo, rhs.lo, 64);
    return res;
}

zig_extern zig_i128 __multi3(zig_i128 lhs, zig_i128 rhs);
static zig_i128 zig_mul_i128(zig_i128 lhs, zig_i128 rhs) {
    return __multi3(lhs, rhs);
}

static zig_u128 zig_mul_u128(zig_u128 lhs, zig_u128 rhs) {
    return zig_bitcast_u128(zig_mul_i128(zig_bitcast_i128(lhs), zig_bitcast_i128(rhs)));
}

zig_extern zig_u128 __udivti3(zig_u128 lhs, zig_u128 rhs);
static zig_u128 zig_div_trunc_u128(zig_u128 lhs, zig_u128 rhs) {
    return __udivti3(lhs, rhs);
};

zig_extern zig_i128 __divti3(zig_i128 lhs, zig_i128 rhs);
static zig_i128 zig_div_trunc_i128(zig_i128 lhs, zig_i128 rhs) {
    return __divti3(lhs, rhs);
};

zig_extern zig_u128 __umodti3(zig_u128 lhs, zig_u128 rhs);
static zig_u128 zig_rem_u128(zig_u128 lhs, zig_u128 rhs) {
    return __umodti3(lhs, rhs);
}

zig_extern zig_i128 __modti3(zig_i128 lhs, zig_i128 rhs);
static zig_i128 zig_rem_i128(zig_i128 lhs, zig_i128 rhs) {
    return __modti3(lhs, rhs);
}

static inline zig_i128 zig_mod_i128(zig_i128 lhs, zig_i128 rhs) {
    zig_i128 rem = zig_rem_i128(lhs, rhs);
    return zig_add_i128(rem, ((lhs.hi ^ rhs.hi) & rem.hi) < INT64_C(0) ? rhs : zig_make_i128(0, 0));
}

static inline zig_i128 zig_div_floor_i128(zig_i128 lhs, zig_i128 rhs) {
    return zig_sub_i128(zig_div_trunc_i128(lhs, rhs), zig_make_i128(0, zig_cmp_i128(zig_and_i128(zig_xor_i128(lhs, rhs), zig_rem_i128(lhs, rhs)), zig_make_i128(0, 0)) < INT32_C(0)));
}

#endif /* zig_has_int128 */

#define zig_div_floor_u128 zig_div_trunc_u128
#define zig_mod_u128 zig_rem_u128

static inline zig_u128 zig_nand_u128(zig_u128 lhs, zig_u128 rhs) {
    return zig_not_u128(zig_and_u128(lhs, rhs), 128);
}

static inline zig_u128 zig_min_u128(zig_u128 lhs, zig_u128 rhs) {
    return zig_cmp_u128(lhs, rhs) < INT32_C(0) ? lhs : rhs;
}

static inline zig_i128 zig_min_i128(zig_i128 lhs, zig_i128 rhs) {
    return zig_cmp_i128(lhs, rhs) < INT32_C(0) ? lhs : rhs;
}

static inline zig_u128 zig_max_u128(zig_u128 lhs, zig_u128 rhs) {
    return zig_cmp_u128(lhs, rhs) > INT32_C(0) ? lhs : rhs;
}

static inline zig_i128 zig_max_i128(zig_i128 lhs, zig_i128 rhs) {
    return zig_cmp_i128(lhs, rhs) > INT32_C(0) ? lhs : rhs;
}

static inline zig_u128 zig_wrap_u128(zig_u128 val, uint8_t bits) {
    return zig_and_u128(val, zig_maxInt_u(128, bits));
}

static inline zig_i128 zig_wrap_i128(zig_i128 val, uint8_t bits) {
    return zig_make_i128(zig_wrap_i64(zig_hi_i128(val), bits - UINT8_C(64)), zig_lo_i128(val));
}

static inline zig_u128 zig_shlw_u128(zig_u128 lhs, uint8_t rhs, uint8_t bits) {
    return zig_wrap_u128(zig_shl_u128(lhs, rhs), bits);
}

static inline zig_i128 zig_shlw_i128(zig_i128 lhs, uint8_t rhs, uint8_t bits) {
    return zig_wrap_i128(zig_bitcast_i128(zig_shl_u128(zig_bitcast_u128(lhs), rhs)), bits);
}

static inline zig_u128 zig_addw_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    return zig_wrap_u128(zig_add_u128(lhs, rhs), bits);
}

static inline zig_i128 zig_addw_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    return zig_wrap_i128(zig_bitcast_i128(zig_add_u128(zig_bitcast_u128(lhs), zig_bitcast_u128(rhs))), bits);
}

static inline zig_u128 zig_subw_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    return zig_wrap_u128(zig_sub_u128(lhs, rhs), bits);
}

static inline zig_i128 zig_subw_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    return zig_wrap_i128(zig_bitcast_i128(zig_sub_u128(zig_bitcast_u128(lhs), zig_bitcast_u128(rhs))), bits);
}

static inline zig_u128 zig_mulw_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    return zig_wrap_u128(zig_mul_u128(lhs, rhs), bits);
}

static inline zig_i128 zig_mulw_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    return zig_wrap_i128(zig_bitcast_i128(zig_mul_u128(zig_bitcast_u128(lhs), zig_bitcast_u128(rhs))), bits);
}

#if zig_has_int128

static inline bool zig_addo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow)
    zig_u128 full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u128(full_res, bits);
    return overflow || full_res < zig_minInt_u(128, bits) || full_res > zig_maxInt_u(128, bits);
#else
    *res = zig_addw_u128(lhs, rhs, bits);
    return *res < lhs;
#endif
}

zig_extern zig_i128  __addoti4(zig_i128 lhs, zig_i128 rhs, int *overflow);
static inline bool zig_addo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
#if zig_has_builtin(add_overflow)
    zig_i128 full_res;
    bool overflow = __builtin_add_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    zig_i128 full_res =  __addoti4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i128(full_res, bits);
    return overflow || full_res < zig_minInt_i(128, bits) || full_res > zig_maxInt_i(128, bits);
}

static inline bool zig_subo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow)
    zig_u128 full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u128(full_res, bits);
    return overflow || full_res < zig_minInt_u(128, bits) || full_res > zig_maxInt_u(128, bits);
#else
    *res = zig_subw_u128(lhs, rhs, bits);
    return *res > lhs;
#endif
}

zig_extern zig_i128  __suboti4(zig_i128 lhs, zig_i128 rhs, int *overflow);
static inline bool zig_subo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
#if zig_has_builtin(sub_overflow)
    zig_i128 full_res;
    bool overflow = __builtin_sub_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    zig_i128 full_res = __suboti4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i128(full_res, bits);
    return overflow || full_res < zig_minInt_i(128, bits) || full_res > zig_maxInt_i(128, bits);
}

static inline bool zig_mulo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow)
    zig_u128 full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
    *res = zig_wrap_u128(full_res, bits);
    return overflow || full_res < zig_minInt_u(128, bits) || full_res > zig_maxInt_u(128, bits);
#else
    *res = zig_mulw_u128(lhs, rhs, bits);
    return rhs != zig_make_u128(0, 0) && lhs > zig_maxInt_u(128, bits) / rhs;
#endif
}

zig_extern zig_i128  __muloti4(zig_i128 lhs, zig_i128 rhs, int *overflow);
static inline bool zig_mulo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
#if zig_has_builtin(mul_overflow)
    zig_i128 full_res;
    bool overflow = __builtin_mul_overflow(lhs, rhs, &full_res);
#else
    int overflow_int;
    zig_i128 full_res =  __muloti4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0;
#endif
    *res = zig_wrap_i128(full_res, bits);
    return overflow || full_res < zig_minInt_i(128, bits) || full_res > zig_maxInt_i(128, bits);
}

#else /* zig_has_int128 */

static inline bool zig_addo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    uint64_t hi;
    bool overflow = zig_addo_u64(&hi, lhs.hi, rhs.hi, bits - 64);
    return overflow ^ zig_addo_u64(&res->hi, hi, zig_addo_u64(&res->lo, lhs.lo, rhs.lo, 64), bits - 64);
}

static inline bool zig_addo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    int64_t hi;
    bool overflow = zig_addo_i64(&hi, lhs.hi, rhs.hi, bits - 64);
    return overflow ^ zig_addo_i64(&res->hi, hi, zig_addo_u64(&res->lo, lhs.lo, rhs.lo, 64), bits - 64);
}

static inline bool zig_subo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    uint64_t hi;
    bool overflow = zig_subo_u64(&hi, lhs.hi, rhs.hi, bits - 64);
    return overflow ^ zig_subo_u64(&res->hi, hi, zig_subo_u64(&res->lo, lhs.lo, rhs.lo, 64), bits - 64);
}

static inline bool zig_subo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    int64_t hi;
    bool overflow = zig_subo_i64(&hi, lhs.hi, rhs.hi, bits - 64);
    return overflow ^ zig_subo_i64(&res->hi, hi, zig_subo_u64(&res->lo, lhs.lo, rhs.lo, 64), bits - 64);
}

static inline bool zig_mulo_u128(zig_u128 *res, zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    *res = zig_mulw_u128(lhs, rhs, bits);
    return zig_cmp_u128(*res, zig_make_u128(0, 0)) != INT32_C(0) &&
        zig_cmp_u128(lhs, zig_div_trunc_u128(zig_maxInt_u(128, bits), rhs)) > INT32_C(0);
}

zig_extern zig_i128 __muloti4(zig_i128 lhs, zig_i128 rhs, int *overflow);
static inline bool zig_mulo_i128(zig_i128 *res, zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    int overflow_int;
    zig_i128 full_res = __muloti4(lhs, rhs, &overflow_int);
    bool overflow = overflow_int != 0 ||
        zig_cmp_i128(full_res, zig_minInt_i(128, bits)) < INT32_C(0) ||
        zig_cmp_i128(full_res, zig_maxInt_i(128, bits)) > INT32_C(0);
    *res = zig_wrap_i128(full_res, bits);
    return overflow;
}

#endif /* zig_has_int128 */

static inline bool zig_shlo_u128(zig_u128 *res, zig_u128 lhs, uint8_t rhs, uint8_t bits) {
    *res = zig_shlw_u128(lhs, rhs, bits);
    return zig_cmp_u128(lhs, zig_shr_u128(zig_maxInt_u(128, bits), rhs)) > INT32_C(0);
}

static inline bool zig_shlo_i128(zig_i128 *res, zig_i128 lhs, uint8_t rhs, uint8_t bits) {
    *res = zig_shlw_i128(lhs, rhs, bits);
    zig_i128 mask = zig_bitcast_i128(zig_shl_u128(zig_maxInt_u128, bits - rhs - UINT8_C(1)));
    return zig_cmp_i128(zig_and_i128(lhs, mask), zig_make_i128(0, 0)) != INT32_C(0) &&
           zig_cmp_i128(zig_and_i128(lhs, mask), mask) != INT32_C(0);
}

static inline zig_u128 zig_shls_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    zig_u128 res;
    if (zig_cmp_u128(rhs, zig_make_u128(0, bits)) >= INT32_C(0))
        return zig_cmp_u128(lhs, zig_make_u128(0, 0)) != INT32_C(0) ? zig_maxInt_u(128, bits) : lhs;
    return zig_shlo_u128(&res, lhs, (uint8_t)zig_lo_u128(rhs), bits) ? zig_maxInt_u(128, bits) : res;
}

static inline zig_i128 zig_shls_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    zig_i128 res;
    if (zig_cmp_u128(zig_bitcast_u128(rhs), zig_make_u128(0, bits)) < INT32_C(0) && !zig_shlo_i128(&res, lhs, (uint8_t)zig_lo_i128(rhs), bits)) return res;
    return zig_cmp_i128(lhs, zig_make_i128(0, 0)) < INT32_C(0) ? zig_minInt_i(128, bits) : zig_maxInt_i(128, bits);
}

static inline zig_u128 zig_adds_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    zig_u128 res;
    return zig_addo_u128(&res, lhs, rhs, bits) ? zig_maxInt_u(128, bits) : res;
}

static inline zig_i128 zig_adds_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    zig_i128 res;
    if (!zig_addo_i128(&res, lhs, rhs, bits)) return res;
    return zig_cmp_i128(res, zig_make_i128(0, 0)) >= INT32_C(0) ? zig_minInt_i(128, bits) : zig_maxInt_i(128, bits);
}

static inline zig_u128 zig_subs_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    zig_u128 res;
    return zig_subo_u128(&res, lhs, rhs, bits) ? zig_minInt_u(128, bits) : res;
}

static inline zig_i128 zig_subs_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    zig_i128 res;
    if (!zig_subo_i128(&res, lhs, rhs, bits)) return res;
    return zig_cmp_i128(res, zig_make_i128(0, 0)) >= INT32_C(0) ? zig_minInt_i(128, bits) : zig_maxInt_i(128, bits);
}

static inline zig_u128 zig_muls_u128(zig_u128 lhs, zig_u128 rhs, uint8_t bits) {
    zig_u128 res;
    return zig_mulo_u128(&res, lhs, rhs, bits) ? zig_maxInt_u(128, bits) : res;
}

static inline zig_i128 zig_muls_i128(zig_i128 lhs, zig_i128 rhs, uint8_t bits) {
    zig_i128 res;
    if (!zig_mulo_i128(&res, lhs, rhs, bits)) return res;
    return zig_cmp_i128(zig_xor_i128(lhs, rhs), zig_make_i128(0, 0)) < INT32_C(0) ? zig_minInt_i(128, bits) : zig_maxInt_i(128, bits);
}

static inline uint8_t zig_clz_u128(zig_u128 val, uint8_t bits) {
    if (bits <= UINT8_C(64)) return zig_clz_u64(zig_lo_u128(val), bits);
    if (zig_hi_u128(val) != 0) return zig_clz_u64(zig_hi_u128(val), bits - UINT8_C(64));
    return zig_clz_u64(zig_lo_u128(val), UINT8_C(64)) + (bits - UINT8_C(64));
}

static inline uint8_t zig_clz_i128(zig_i128 val, uint8_t bits) {
    return zig_clz_u128(zig_bitcast_u128(val), bits);
}

static inline uint8_t zig_ctz_u128(zig_u128 val, uint8_t bits) {
    if (zig_lo_u128(val) != 0) return zig_ctz_u64(zig_lo_u128(val), UINT8_C(64));
    return zig_ctz_u64(zig_hi_u128(val), bits - UINT8_C(64)) + UINT8_C(64);
}

static inline uint8_t zig_ctz_i128(zig_i128 val, uint8_t bits) {
    return zig_ctz_u128(zig_bitcast_u128(val), bits);
}

static inline uint8_t zig_popcount_u128(zig_u128 val, uint8_t bits) {
    return zig_popcount_u64(zig_hi_u128(val), bits - UINT8_C(64)) +
           zig_popcount_u64(zig_lo_u128(val), UINT8_C(64));
}

static inline uint8_t zig_popcount_i128(zig_i128 val, uint8_t bits) {
    return zig_popcount_u128(zig_bitcast_u128(val), bits);
}

static inline zig_u128 zig_byte_swap_u128(zig_u128 val, uint8_t bits) {
    zig_u128 full_res;
#if zig_has_builtin(bswap128)
    full_res = __builtin_bswap128(val);
#else
    full_res = zig_make_u128(zig_byte_swap_u64(zig_lo_u128(val), UINT8_C(64)),
                           zig_byte_swap_u64(zig_hi_u128(val), UINT8_C(64)));
#endif
    return zig_shr_u128(full_res, UINT8_C(128) - bits);
}

static inline zig_i128 zig_byte_swap_i128(zig_i128 val, uint8_t bits) {
    return zig_bitcast_i128(zig_byte_swap_u128(zig_bitcast_u128(val), bits));
}

static inline zig_u128 zig_bit_reverse_u128(zig_u128 val, uint8_t bits) {
    return zig_shr_u128(zig_make_u128(zig_bit_reverse_u64(zig_lo_u128(val), UINT8_C(64)),
                                    zig_bit_reverse_u64(zig_hi_u128(val), UINT8_C(64))),
                        UINT8_C(128) - bits);
}

static inline zig_i128 zig_bit_reverse_i128(zig_i128 val, uint8_t bits) {
    return zig_bitcast_i128(zig_bit_reverse_u128(zig_bitcast_u128(val), bits));
}

/* ========================= Floating Point Support ========================= */

#if _MSC_VER
#define zig_msvc_flt_inf ((double)(1e+300 * 1e+300))
#define zig_msvc_flt_inff ((float)(1e+300 * 1e+300))
#define zig_msvc_flt_infl ((long double)(1e+300 * 1e+300))
#define zig_msvc_flt_nan ((double)(zig_msvc_flt_inf * 0.f))
#define zig_msvc_flt_nanf ((float)(zig_msvc_flt_inf * 0.f))
#define zig_msvc_flt_nanl ((long double)(zig_msvc_flt_inf * 0.f))
#define __builtin_nan(str) nan(str)
#define __builtin_nanf(str) nanf(str)
#define __builtin_nanl(str) nanl(str)
#define __builtin_inf() zig_msvc_flt_inf
#define __builtin_inff() zig_msvc_flt_inff
#define __builtin_infl() zig_msvc_flt_infl
#endif

#if (zig_has_builtin(nan) && zig_has_builtin(nans) && zig_has_builtin(inf)) || defined(zig_gnuc)
#define zig_has_float_builtins 1
#define zig_make_special_f16(sign, name, arg, repr) sign zig_make_f16(__builtin_##name, )(arg)
#define zig_make_special_f32(sign, name, arg, repr) sign zig_make_f32(__builtin_##name, )(arg)
#define zig_make_special_f64(sign, name, arg, repr) sign zig_make_f64(__builtin_##name, )(arg)
#define zig_make_special_f80(sign, name, arg, repr) sign zig_make_f80(__builtin_##name, )(arg)
#define zig_make_special_f128(sign, name, arg, repr) sign zig_make_f128(__builtin_##name, )(arg)
#define zig_make_special_c_longdouble(sign, name, arg, repr) sign zig_make_c_longdouble(__builtin_##name, )(arg)
#else
#define zig_has_float_builtins 0
#define zig_make_special_f16(sign, name, arg, repr) zig_float_from_repr_f16(repr)
#define zig_make_special_f32(sign, name, arg, repr) zig_float_from_repr_f32(repr)
#define zig_make_special_f64(sign, name, arg, repr) zig_float_from_repr_f64(repr)
#define zig_make_special_f80(sign, name, arg, repr) zig_float_from_repr_f80(repr)
#define zig_make_special_f128(sign, name, arg, repr)  zig_float_from_repr_f128(repr)
#define zig_make_special_c_longdouble(sign, name, arg, repr) zig_float_from_repr_c_longdouble(repr)
#endif

#define zig_has_f16 1
#define zig_bitSizeOf_f16 16
#define zig_libc_name_f16(name) __##name##h
#define zig_make_special_constant_f16(sign, name, arg, repr) zig_make_special_f16(sign, name, arg, repr)
#if FLT_MANT_DIG == 11
typedef float zig_f16;
#define zig_make_f16(fp, repr) fp##f
#elif DBL_MANT_DIG == 11
typedef double zig_f16;
#define zig_make_f16(fp, repr) fp
#elif LDBL_MANT_DIG == 11
#define zig_bitSizeOf_c_longdouble 16
typedef uint16_t zig_repr_c_longdouble;
typedef long double zig_f16;
#define zig_make_f16(fp, repr) fp##l
#elif FLT16_MANT_DIG == 11 && (zig_has_builtin(inff16) || defined(zig_gnuc))
typedef _Float16 zig_f16;
#define zig_make_f16(fp, repr) fp##f16
#elif defined(__SIZEOF_FP16__)
typedef __fp16 zig_f16;
#define zig_make_f16(fp, repr) fp##f16
#else
#undef zig_has_f16
#define zig_has_f16 0
#define zig_bitSizeOf_repr_f16 16
typedef int16_t zig_f16;
#define zig_make_f16(fp, repr) repr
#undef zig_make_special_f16
#define zig_make_special_f16(sign, name, arg, repr) repr
#undef zig_make_special_constant_f16
#define zig_make_special_constant_f16(sign, name, arg, repr) repr
#endif

#define zig_has_f32 1
#define zig_bitSizeOf_f32 32
#define zig_libc_name_f32(name) name##f
#if _MSC_VER
#define zig_make_special_constant_f32(sign, name, arg, repr) sign zig_make_f32(zig_msvc_flt_##name, )
#else
#define zig_make_special_constant_f32(sign, name, arg, repr) zig_make_special_f32(sign, name, arg, repr)
#endif
#if FLT_MANT_DIG == 24
typedef float zig_f32;
#define zig_make_f32(fp, repr) fp##f
#elif DBL_MANT_DIG == 24
typedef double zig_f32;
#define zig_make_f32(fp, repr) fp
#elif LDBL_MANT_DIG == 24
#define zig_bitSizeOf_c_longdouble 32
typedef uint32_t zig_repr_c_longdouble;
typedef long double zig_f32;
#define zig_make_f32(fp, repr) fp##l
#elif FLT32_MANT_DIG == 24
typedef _Float32 zig_f32;
#define zig_make_f32(fp, repr) fp##f32
#else
#undef zig_has_f32
#define zig_has_f32 0
#define zig_bitSizeOf_repr_f32 32
typedef int32_t zig_f32;
#define zig_make_f32(fp, repr) repr
#undef zig_make_special_f32
#define zig_make_special_f32(sign, name, arg, repr) repr
#undef zig_make_special_constant_f32
#define zig_make_special_constant_f32(sign, name, arg, repr) repr
#endif

#define zig_has_f64 1
#define zig_bitSizeOf_f64 64
#define zig_libc_name_f64(name) name
#if _MSC_VER
#ifdef ZIG_TARGET_ABI_MSVC
#define zig_bitSizeOf_c_longdouble 64
typedef uint64_t zig_repr_c_longdouble;
#endif
#define zig_make_special_constant_f64(sign, name, arg, repr) sign zig_make_f64(zig_msvc_flt_##name, )
#else /* _MSC_VER */
#define zig_make_special_constant_f64(sign, name, arg, repr) zig_make_special_f64(sign, name, arg, repr)
#endif /* _MSC_VER */
#if FLT_MANT_DIG == 53
typedef float zig_f64;
#define zig_make_f64(fp, repr) fp##f
#elif DBL_MANT_DIG == 53
typedef double zig_f64;
#define zig_make_f64(fp, repr) fp
#elif LDBL_MANT_DIG == 53
#define zig_bitSizeOf_c_longdouble 64
typedef uint64_t zig_repr_c_longdouble;
typedef long double zig_f64;
#define zig_make_f64(fp, repr) fp##l
#elif FLT64_MANT_DIG == 53
typedef _Float64 zig_f64;
#define zig_make_f64(fp, repr) fp##f64
#elif FLT32X_MANT_DIG == 53
typedef _Float32x zig_f64;
#define zig_make_f64(fp, repr) fp##f32x
#else
#undef zig_has_f64
#define zig_has_f64 0
#define zig_bitSizeOf_repr_f64 64
typedef int64_t zig_f64;
#define zig_make_f64(fp, repr) repr
#undef zig_make_special_f64
#define zig_make_special_f64(sign, name, arg, repr) repr
#undef zig_make_special_constant_f64
#define zig_make_special_constant_f64(sign, name, arg, repr) repr
#endif

#define zig_has_f80 1
#define zig_bitSizeOf_f80 80
#define zig_libc_name_f80(name) __##name##x
#define zig_make_special_constant_f80(sign, name, arg, repr) zig_make_special_f80(sign, name, arg, repr)
#if FLT_MANT_DIG == 64
typedef float zig_f80;
#define zig_make_f80(fp, repr) fp##f
#elif DBL_MANT_DIG == 64
typedef double zig_f80;
#define zig_make_f80(fp, repr) fp
#elif LDBL_MANT_DIG == 64
#define zig_bitSizeOf_c_longdouble 80
typedef zig_u128 zig_repr_c_longdouble;
typedef long double zig_f80;
#define zig_make_f80(fp, repr) fp##l
#elif FLT80_MANT_DIG == 64
typedef _Float80 zig_f80;
#define zig_make_f80(fp, repr) fp##f80
#elif FLT64X_MANT_DIG == 64
typedef _Float64x zig_f80;
#define zig_make_f80(fp, repr) fp##f64x
#elif defined(__SIZEOF_FLOAT80__)
typedef __float80 zig_f80;
#define zig_make_f80(fp, repr) fp##l
#else
#undef zig_has_f80
#define zig_has_f80 0
#define zig_bitSizeOf_repr_f80 128
typedef zig_i128 zig_f80;
#define zig_make_f80(fp, repr) repr
#undef zig_make_special_f80
#define zig_make_special_f80(sign, name, arg, repr) repr
#undef zig_make_special_constant_f80
#define zig_make_special_constant_f80(sign, name, arg, repr) repr
#endif

#define zig_has_f128 1
#define zig_bitSizeOf_f128 128
#define zig_libc_name_f128(name) name##q
#define zig_make_special_constant_f128(sign, name, arg, repr) zig_make_special_f128(sign, name, arg, repr)
#if FLT_MANT_DIG == 113
typedef float zig_f128;
#define zig_make_f128(fp, repr) fp##f
#elif DBL_MANT_DIG == 113
typedef double zig_f128;
#define zig_make_f128(fp, repr) fp
#elif LDBL_MANT_DIG == 113
#define zig_bitSizeOf_c_longdouble 128
typedef zig_u128 zig_repr_c_longdouble;
typedef long double zig_f128;
#define zig_make_f128(fp, repr) fp##l
#elif FLT128_MANT_DIG == 113
typedef _Float128 zig_f128;
#define zig_make_f128(fp, repr) fp##f128
#elif FLT64X_MANT_DIG == 113
typedef _Float64x zig_f128;
#define zig_make_f128(fp, repr) fp##f64x
#elif defined(__SIZEOF_FLOAT128__)
typedef __float128 zig_f128;
#define zig_make_f128(fp, repr) fp##q
#undef zig_make_special_f128
#define zig_make_special_f128(sign, name, arg, repr) sign __builtin_##name##f128(arg)
#else
#undef zig_has_f128
#define zig_has_f128 0
#define zig_bitSizeOf_repr_f128 128
typedef zig_i128 zig_f128;
#define zig_make_f128(fp, repr) repr
#undef zig_make_special_f128
#define zig_make_special_f128(sign, name, arg, repr) repr
#undef zig_make_special_constant_f128
#define zig_make_special_constant_f128(sign, name, arg, repr) repr
#endif

#define zig_has_c_longdouble 1

#ifdef ZIG_TARGET_ABI_MSVC
#define zig_libc_name_c_longdouble(name) name
#else
#define zig_libc_name_c_longdouble(name) name##l
#endif

#define zig_make_special_constant_c_longdouble(sign, name, arg, repr) zig_make_special_c_longdouble(sign, name, arg, repr)
#ifdef zig_bitSizeOf_c_longdouble

#ifdef ZIG_TARGET_ABI_MSVC
#undef zig_bitSizeOf_c_longdouble
#define zig_bitSizeOf_c_longdouble 64
typedef uint64_t zig_repr_c_longdouble;
typedef zig_f64 zig_c_longdouble;
#define zig_make_c_longdouble(fp, repr) fp
#else
typedef long double zig_c_longdouble;
#define zig_make_c_longdouble(fp, repr) fp##l
#endif

#else /* zig_bitSizeOf_c_longdouble */

#undef zig_has_c_longdouble
#define zig_has_c_longdouble 0
#define zig_bitSizeOf_c_longdouble 80
typedef zig_u128 zig_repr_c_longdouble;
#define zig_compiler_rt_abbrev_c_longdouble zig_compiler_rt_abbrev_f80
#define zig_bitSizeOf_repr_c_longdouble 128
typedef zig_i128 zig_c_longdouble;
#define zig_make_c_longdouble(fp, repr) repr
#undef zig_make_special_c_longdouble
#define zig_make_special_c_longdouble(sign, name, arg, repr) repr
#undef zig_make_special_constant_c_longdouble
#define zig_make_special_constant_c_longdouble(sign, name, arg, repr) repr

#endif /* zig_bitSizeOf_c_longdouble */

#if !zig_has_float_builtins
#define zig_float_from_repr(Type, ReprType) \
    static inline zig_##Type zig_float_from_repr_##Type(ReprType repr) { \
        zig_##Type result; \
        memcpy(&result, &repr, sizeof(result)); \
        return result; \
    }

zig_float_from_repr(f16, uint16_t)
zig_float_from_repr(f32, uint32_t)
zig_float_from_repr(f64, uint64_t)
zig_float_from_repr(f80, zig_u128)
zig_float_from_repr(f128, zig_u128)
zig_float_from_repr(c_longdouble, zig_repr_c_longdouble)
#endif

#define zig_cast_f16 (zig_f16)
#define zig_cast_f32 (zig_f32)
#define zig_cast_f64 (zig_f64)

#if _MSC_VER && !zig_has_f128
#define zig_cast_f80
#define zig_cast_c_longdouble
#define zig_cast_f128
#else
#define zig_cast_f80 (zig_f80)
#define zig_cast_c_longdouble (zig_c_longdouble)
#define zig_cast_f128 (zig_f128)
#endif

#define zig_convert_builtin(ResType, operation, ArgType, version) \
    zig_extern ResType zig_expand_concat(zig_expand_concat(zig_expand_concat(__##operation, \
        zig_compiler_rt_abbrev_##ArgType), zig_compiler_rt_abbrev_##ResType), version)(ArgType);
zig_convert_builtin(zig_f16,  trunc,  zig_f32,  2)
zig_convert_builtin(zig_f16,  trunc,  zig_f64,  2)
zig_convert_builtin(zig_f16,  trunc,  zig_f80,  2)
zig_convert_builtin(zig_f16,  trunc,  zig_f128, 2)
zig_convert_builtin(zig_f32,  extend, zig_f16,  2)
zig_convert_builtin(zig_f32,  trunc,  zig_f64,  2)
zig_convert_builtin(zig_f32,  trunc,  zig_f80,  2)
zig_convert_builtin(zig_f32,  trunc,  zig_f128, 2)
zig_convert_builtin(zig_f64,  extend, zig_f16,  2)
zig_convert_builtin(zig_f64,  extend, zig_f32,  2)
zig_convert_builtin(zig_f64,  trunc,  zig_f80,  2)
zig_convert_builtin(zig_f64,  trunc,  zig_f128, 2)
zig_convert_builtin(zig_f80,  extend, zig_f16,  2)
zig_convert_builtin(zig_f80,  extend, zig_f32,  2)
zig_convert_builtin(zig_f80,  extend, zig_f64,  2)
zig_convert_builtin(zig_f80,  trunc,  zig_f128, 2)
zig_convert_builtin(zig_f128, extend, zig_f16,  2)
zig_convert_builtin(zig_f128, extend, zig_f32,  2)
zig_convert_builtin(zig_f128, extend, zig_f64,  2)
zig_convert_builtin(zig_f128, extend, zig_f80,  2)

#define zig_float_negate_builtin_0(Type) \
    static inline zig_##Type zig_neg_##Type(zig_##Type arg) { \
        return zig_expand_concat(zig_xor_i, zig_bitSizeOf_repr_##Type)( \
            arg, \
            zig_minInt_i(zig_bitSizeOf_repr_##Type, zig_bitSizeOf_##Type) \
        ); \
    }
#define zig_float_negate_builtin_1(Type) \
    static inline zig_##Type zig_neg_##Type(zig_##Type arg) { \
        return -arg; \
    }

#define zig_float_less_builtin_0(Type, operation) \
    zig_extern int32_t zig_expand_concat(zig_expand_concat(__##operation, \
        zig_compiler_rt_abbrev_zig_##Type), 2)(zig_##Type, zig_##Type); \
    static inline int32_t zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return zig_expand_concat(zig_expand_concat(__##operation, zig_compiler_rt_abbrev_zig_##Type), 2)(lhs, rhs); \
    }
#define zig_float_less_builtin_1(Type, operation) \
    static inline int32_t zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return (!(lhs <= rhs) - (lhs < rhs)); \
    }

#define zig_float_greater_builtin_0(Type, operation) \
    zig_float_less_builtin_0(Type, operation)
#define zig_float_greater_builtin_1(Type, operation) \
    static inline int32_t zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return ((lhs > rhs) - !(lhs >= rhs)); \
    }

#define zig_float_binary_builtin_0(Type, operation, operator) \
    zig_extern zig_##Type zig_expand_concat(zig_expand_concat(__##operation, \
        zig_compiler_rt_abbrev_zig_##Type), 3)(zig_##Type, zig_##Type); \
    static inline zig_##Type zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return zig_expand_concat(zig_expand_concat(__##operation, zig_compiler_rt_abbrev_zig_##Type), 3)(lhs, rhs); \
    }
#define zig_float_binary_builtin_1(Type, operation, operator) \
    static inline zig_##Type zig_##operation##_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return lhs operator rhs; \
    }

#define zig_float_builtins(Type) \
    zig_convert_builtin( int32_t, fix,     zig_##Type, ) \
    zig_convert_builtin(uint32_t, fixuns,  zig_##Type, ) \
    zig_convert_builtin( int64_t, fix,     zig_##Type, ) \
    zig_convert_builtin(uint64_t, fixuns,  zig_##Type, ) \
    zig_convert_builtin(zig_i128, fix,     zig_##Type, ) \
    zig_convert_builtin(zig_u128, fixuns,  zig_##Type, ) \
    zig_convert_builtin(zig_##Type, float,    int32_t, ) \
    zig_convert_builtin(zig_##Type, floatun, uint32_t, ) \
    zig_convert_builtin(zig_##Type, float,    int64_t, ) \
    zig_convert_builtin(zig_##Type, floatun, uint64_t, ) \
    zig_convert_builtin(zig_##Type, float,   zig_i128, ) \
    zig_convert_builtin(zig_##Type, floatun, zig_u128, ) \
    zig_expand_concat(zig_float_negate_builtin_,  zig_has_##Type)(Type) \
    zig_expand_concat(zig_float_less_builtin_,    zig_has_##Type)(Type, cmp) \
    zig_expand_concat(zig_float_less_builtin_,    zig_has_##Type)(Type, ne) \
    zig_expand_concat(zig_float_less_builtin_,    zig_has_##Type)(Type, eq) \
    zig_expand_concat(zig_float_less_builtin_,    zig_has_##Type)(Type, lt) \
    zig_expand_concat(zig_float_less_builtin_,    zig_has_##Type)(Type, le) \
    zig_expand_concat(zig_float_greater_builtin_, zig_has_##Type)(Type, gt) \
    zig_expand_concat(zig_float_greater_builtin_, zig_has_##Type)(Type, ge) \
    zig_expand_concat(zig_float_binary_builtin_,  zig_has_##Type)(Type, add, +) \
    zig_expand_concat(zig_float_binary_builtin_,  zig_has_##Type)(Type, sub, -) \
    zig_expand_concat(zig_float_binary_builtin_,  zig_has_##Type)(Type, mul, *) \
    zig_expand_concat(zig_float_binary_builtin_,  zig_has_##Type)(Type, div, /) \
    zig_extern zig_##Type zig_libc_name_##Type(sqrt)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(sin)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(cos)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(tan)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(exp)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(exp2)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(log)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(log2)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(log10)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(fabs)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(floor)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(ceil)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(round)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(trunc)(zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(fmod)(zig_##Type, zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(fmin)(zig_##Type, zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(fmax)(zig_##Type, zig_##Type); \
    zig_extern zig_##Type zig_libc_name_##Type(fma)(zig_##Type, zig_##Type, zig_##Type); \
\
    static inline zig_##Type zig_div_trunc_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return zig_libc_name_##Type(trunc)(zig_div_##Type(lhs, rhs)); \
    } \
\
    static inline zig_##Type zig_div_floor_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return zig_libc_name_##Type(floor)(zig_div_##Type(lhs, rhs)); \
    } \
\
    static inline zig_##Type zig_mod_##Type(zig_##Type lhs, zig_##Type rhs) { \
        return zig_sub_##Type(lhs, zig_mul_##Type(zig_div_floor_##Type(lhs, rhs), rhs)); \
    }
zig_float_builtins(f16)
zig_float_builtins(f32)
zig_float_builtins(f64)
zig_float_builtins(f80)
zig_float_builtins(f128)
zig_float_builtins(c_longdouble)

#if _MSC_VER && (_M_IX86 || _M_X64)

// TODO: zig_msvc_atomic_load should load 32 bit without interlocked on x86, and load 64 bit without interlocked on x64

#define zig_msvc_atomics(ZigType, Type, suffix) \
    static inline bool zig_msvc_cmpxchg_##ZigType(Type volatile* obj, Type* expected, Type desired) { \
        Type comparand = *expected; \
        Type initial = _InterlockedCompareExchange##suffix(obj, desired, comparand); \
        bool exchanged = initial == comparand; \
        if (!exchanged) { \
            *expected = initial; \
        } \
        return exchanged; \
    } \
    static inline Type zig_msvc_atomicrmw_xchg_##ZigType(Type volatile* obj, Type value) { \
        return _InterlockedExchange##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomicrmw_add_##ZigType(Type volatile* obj, Type value) { \
        return _InterlockedExchangeAdd##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomicrmw_sub_##ZigType(Type volatile* obj, Type value) { \
        bool success = false; \
        Type new; \
        Type prev; \
        while (!success) { \
            prev = *obj; \
            new = prev - value; \
            success = zig_msvc_cmpxchg_##ZigType(obj, &prev, new); \
        } \
        return prev; \
    } \
    static inline Type zig_msvc_atomicrmw_or_##ZigType(Type volatile* obj, Type value) { \
        return _InterlockedOr##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomicrmw_xor_##ZigType(Type volatile* obj, Type value) { \
        return _InterlockedXor##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomicrmw_and_##ZigType(Type volatile* obj, Type value) { \
        return _InterlockedAnd##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomicrmw_nand_##ZigType(Type volatile* obj, Type value) { \
        bool success = false; \
        Type new; \
        Type prev; \
        while (!success) { \
            prev = *obj; \
            new = ~(prev & value); \
            success = zig_msvc_cmpxchg_##ZigType(obj, &prev, new); \
        } \
        return prev; \
    } \
    static inline Type zig_msvc_atomicrmw_min_##ZigType(Type volatile* obj, Type value) { \
        bool success = false; \
        Type new; \
        Type prev; \
        while (!success) { \
            prev = *obj; \
            new = value < prev ? value : prev; \
            success = zig_msvc_cmpxchg_##ZigType(obj, &prev, new); \
        } \
        return prev; \
    } \
    static inline Type zig_msvc_atomicrmw_max_##ZigType(Type volatile* obj, Type value) { \
        bool success = false; \
        Type new; \
        Type prev; \
        while (!success) { \
            prev = *obj; \
            new = value > prev ? value : prev; \
            success = zig_msvc_cmpxchg_##ZigType(obj, &prev, new); \
        } \
        return prev; \
    } \
    static inline void zig_msvc_atomic_store_##ZigType(Type volatile* obj, Type value) { \
        _InterlockedExchange##suffix(obj, value); \
    } \
    static inline Type zig_msvc_atomic_load_##ZigType(Type volatile* obj) { \
        return _InterlockedOr##suffix(obj, 0); \
    }

zig_msvc_atomics( u8,  uint8_t,  8)
zig_msvc_atomics( i8,   int8_t,  8)
zig_msvc_atomics(u16, uint16_t, 16)
zig_msvc_atomics(i16,  int16_t, 16)
zig_msvc_atomics(u32, uint32_t,   )
zig_msvc_atomics(i32,  int32_t,   )

#if _M_X64
zig_msvc_atomics(u64, uint64_t, 64)
zig_msvc_atomics(i64,  int64_t, 64)
#endif

#define zig_msvc_flt_atomics(Type, ReprType, suffix) \
    static inline bool zig_msvc_cmpxchg_##Type(zig_##Type volatile* obj, zig_##Type* expected, zig_##Type desired) { \
        ReprType exchange; \
        ReprType comparand; \
        ReprType initial; \
        bool success; \
        memcpy(&comparand, expected, sizeof(comparand)); \
        memcpy(&exchange, &desired, sizeof(exchange)); \
        initial = _InterlockedCompareExchange##suffix((ReprType volatile*)obj, exchange, comparand); \
        success = initial == comparand; \
        if (!success) memcpy(expected, &initial, sizeof(*expected)); \
        return success; \
    } \
    static inline zig_##Type zig_msvc_atomicrmw_xchg_##Type(zig_##Type volatile* obj, zig_##Type value) { \
        ReprType repr; \
        ReprType initial; \
        zig_##Type result; \
        memcpy(&repr, &value, sizeof(repr)); \
        initial = _InterlockedExchange##suffix((ReprType volatile*)obj, repr); \
        memcpy(&result, &initial, sizeof(result)); \
        return result; \
    } \
    static inline zig_##Type zig_msvc_atomicrmw_add_##Type(zig_##Type volatile* obj, zig_##Type value) { \
        ReprType repr; \
        zig_##Type expected; \
        zig_##Type desired; \
        repr = *(ReprType volatile*)obj; \
        memcpy(&expected, &repr, sizeof(expected)); \
        do { \
            desired = expected + value; \
        } while (!zig_msvc_cmpxchg_##Type(obj, &expected, desired)); \
        return expected; \
    } \
    static inline zig_##Type zig_msvc_atomicrmw_sub_##Type(zig_##Type volatile* obj, zig_##Type value) { \
        ReprType repr; \
        zig_##Type expected; \
        zig_##Type desired; \
        repr = *(ReprType volatile*)obj; \
        memcpy(&expected, &repr, sizeof(expected)); \
        do { \
            desired = expected - value; \
        } while (!zig_msvc_cmpxchg_##Type(obj, &expected, desired)); \
        return expected; \
    }

zig_msvc_flt_atomics(f32, uint32_t,   )
#if _M_X64
zig_msvc_flt_atomics(f64, uint64_t, 64)
#endif

#if _M_IX86
static inline void zig_msvc_atomic_barrier() {
    int32_t barrier;
    __asm {
        xchg barrier, eax
    }
}

static inline void* zig_msvc_atomicrmw_xchg_p32(void** obj, void* arg) {
    return _InterlockedExchangePointer(obj, arg);
}

static inline void zig_msvc_atomic_store_p32(void** obj, void* arg) {
    _InterlockedExchangePointer(obj, arg);
}

static inline void* zig_msvc_atomic_load_p32(void** obj) {
    return (void*)_InterlockedOr((void*)obj, 0);
}

static inline bool zig_msvc_cmpxchg_p32(void** obj, void** expected, void* desired) {
    void* comparand = *expected;
    void* initial = _InterlockedCompareExchangePointer(obj, desired, comparand);
    bool exchanged = initial == comparand;
    if (!exchanged) {
        *expected = initial;
    }
    return exchanged;
}
#else /* _M_IX86 */
static inline void* zig_msvc_atomicrmw_xchg_p64(void** obj, void* arg) {
    return _InterlockedExchangePointer(obj, arg);
}

static inline void zig_msvc_atomic_store_p64(void** obj, void* arg) {
    _InterlockedExchangePointer(obj, arg);
}

static inline void* zig_msvc_atomic_load_p64(void** obj) {
    return (void*)_InterlockedOr64((void*)obj, 0);
}

static inline bool zig_msvc_cmpxchg_p64(void** obj, void** expected, void* desired) {
    void* comparand = *expected;
    void* initial = _InterlockedCompareExchangePointer(obj, desired, comparand);
    bool exchanged = initial == comparand;
    if (!exchanged) {
        *expected = initial;
    }
    return exchanged;
}

static inline bool zig_msvc_cmpxchg_u128(zig_u128 volatile* obj, zig_u128* expected, zig_u128 desired) {
    return _InterlockedCompareExchange128((int64_t volatile*)obj, desired.hi, desired.lo, (int64_t*)expected);
}

static inline bool zig_msvc_cmpxchg_i128(zig_i128 volatile* obj, zig_i128* expected, zig_i128 desired) {
    return _InterlockedCompareExchange128((int64_t volatile*)obj, desired.hi, desired.lo, (uint64_t*)expected);
}

#define zig_msvc_atomics_128xchg(Type) \
    static inline zig_##Type zig_msvc_atomicrmw_xchg_##Type(zig_##Type volatile* obj, zig_##Type value) { \
        bool success = false; \
        zig_##Type prev; \
        while (!success) { \
            prev = *obj; \
            success = zig_msvc_cmpxchg_##Type(obj, &prev, value); \
        } \
        return prev; \
    }

zig_msvc_atomics_128xchg(u128)
zig_msvc_atomics_128xchg(i128)

#define zig_msvc_atomics_128op(Type, operation) \
    static inline zig_##Type zig_msvc_atomicrmw_##operation##_##Type(zig_##Type volatile* obj, zig_##Type value) { \
        bool success = false; \
        zig_##Type new; \
        zig_##Type prev; \
        while (!success) { \
            prev = *obj; \
            new = zig_##operation##_##Type(prev, value); \
            success = zig_msvc_cmpxchg_##Type(obj, &prev, new); \
        } \
        return prev; \
    }

zig_msvc_atomics_128op(u128, add)
zig_msvc_atomics_128op(u128, sub)
zig_msvc_atomics_128op(u128, or)
zig_msvc_atomics_128op(u128, xor)
zig_msvc_atomics_128op(u128, and)
zig_msvc_atomics_128op(u128, nand)
zig_msvc_atomics_128op(u128, min)
zig_msvc_atomics_128op(u128, max)
#endif /* _M_IX86 */

#endif /* _MSC_VER && (_M_IX86 || _M_X64) */

/* ======================== Special Case Intrinsics ========================= */

#if (_MSC_VER && _M_X64) || defined(__x86_64__)

static inline void* zig_x86_64_windows_teb(void) {
#if _MSC_VER
    return (void*)__readgsqword(0x30);
#else
    void* teb;
    __asm volatile(" movq %%gs:0x30, %[ptr]": [ptr]"=r"(teb)::);
    return teb;
#endif
}

#elif (_MSC_VER && _M_IX86) || defined(__i386__) || defined(__X86__)

static inline void* zig_x86_windows_teb(void) {
#if _MSC_VER
    return (void*)__readfsdword(0x18);
#else
    void* teb;
    __asm volatile(" movl %%fs:0x18, %[ptr]": [ptr]"=r"(teb)::);
    return teb;
#endif
}

#endif

#if (_MSC_VER && (_M_IX86 || _M_X64)) || defined(__i386__) || defined(__x86_64__)

static inline void zig_x86_cpuid(uint32_t leaf_id, uint32_t subid, uint32_t* eax, uint32_t* ebx, uint32_t* ecx, uint32_t* edx) {
    uint32_t cpu_info[4];
#if _MSC_VER
    __cpuidex(cpu_info, leaf_id, subid);
#else
    __cpuid_count(leaf_id, subid, cpu_info[0], cpu_info[1], cpu_info[2], cpu_info[3]);
#endif
    *eax = cpu_info[0];
    *ebx = cpu_info[1];
    *ecx = cpu_info[2];
    *edx = cpu_info[3];
}

static inline uint32_t zig_x86_get_xcr0(void) {
#if _MSC_VER
    return (uint32_t)_xgetbv(0);
#else
    uint32_t eax;
    uint32_t edx;
    __asm__("xgetbv" : "=a"(eax), "=d"(edx) : "c"(0));
    return eax;
#endif
}

#endif
