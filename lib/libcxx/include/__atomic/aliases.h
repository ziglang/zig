//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ATOMIC_ALIASES_H
#define _LIBCPP___ATOMIC_ALIASES_H

#include <__atomic/atomic.h>
#include <__atomic/atomic_lock_free.h>
#include <__atomic/contention_t.h>
#include <__atomic/is_always_lock_free.h>
#include <__config>
#include <__type_traits/conditional.h>
#include <cstddef>
#include <cstdint>
#include <cstdlib>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

using atomic_bool   = atomic<bool>;
using atomic_char   = atomic<char>;
using atomic_schar  = atomic<signed char>;
using atomic_uchar  = atomic<unsigned char>;
using atomic_short  = atomic<short>;
using atomic_ushort = atomic<unsigned short>;
using atomic_int    = atomic<int>;
using atomic_uint   = atomic<unsigned int>;
using atomic_long   = atomic<long>;
using atomic_ulong  = atomic<unsigned long>;
using atomic_llong  = atomic<long long>;
using atomic_ullong = atomic<unsigned long long>;
#ifndef _LIBCPP_HAS_NO_CHAR8_T
using atomic_char8_t = atomic<char8_t>;
#endif
using atomic_char16_t = atomic<char16_t>;
using atomic_char32_t = atomic<char32_t>;
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
using atomic_wchar_t = atomic<wchar_t>;
#endif

using atomic_int_least8_t   = atomic<int_least8_t>;
using atomic_uint_least8_t  = atomic<uint_least8_t>;
using atomic_int_least16_t  = atomic<int_least16_t>;
using atomic_uint_least16_t = atomic<uint_least16_t>;
using atomic_int_least32_t  = atomic<int_least32_t>;
using atomic_uint_least32_t = atomic<uint_least32_t>;
using atomic_int_least64_t  = atomic<int_least64_t>;
using atomic_uint_least64_t = atomic<uint_least64_t>;

using atomic_int_fast8_t   = atomic<int_fast8_t>;
using atomic_uint_fast8_t  = atomic<uint_fast8_t>;
using atomic_int_fast16_t  = atomic<int_fast16_t>;
using atomic_uint_fast16_t = atomic<uint_fast16_t>;
using atomic_int_fast32_t  = atomic<int_fast32_t>;
using atomic_uint_fast32_t = atomic<uint_fast32_t>;
using atomic_int_fast64_t  = atomic<int_fast64_t>;
using atomic_uint_fast64_t = atomic<uint_fast64_t>;

using atomic_int8_t   = atomic< int8_t>;
using atomic_uint8_t  = atomic<uint8_t>;
using atomic_int16_t  = atomic< int16_t>;
using atomic_uint16_t = atomic<uint16_t>;
using atomic_int32_t  = atomic< int32_t>;
using atomic_uint32_t = atomic<uint32_t>;
using atomic_int64_t  = atomic< int64_t>;
using atomic_uint64_t = atomic<uint64_t>;

using atomic_intptr_t  = atomic<intptr_t>;
using atomic_uintptr_t = atomic<uintptr_t>;
using atomic_size_t    = atomic<size_t>;
using atomic_ptrdiff_t = atomic<ptrdiff_t>;
using atomic_intmax_t  = atomic<intmax_t>;
using atomic_uintmax_t = atomic<uintmax_t>;

// atomic_*_lock_free : prefer the contention type most highly, then the largest lock-free type

#if _LIBCPP_STD_VER >= 17
#  define _LIBCPP_CONTENTION_LOCK_FREE ::std::__libcpp_is_always_lock_free<__cxx_contention_t>::__value
#else
#  define _LIBCPP_CONTENTION_LOCK_FREE false
#endif

#if ATOMIC_LLONG_LOCK_FREE == 2
using __libcpp_signed_lock_free = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, long long>;
using __libcpp_unsigned_lock_free =
    __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, unsigned long long>;
#elif ATOMIC_INT_LOCK_FREE == 2
using __libcpp_signed_lock_free   = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, int>;
using __libcpp_unsigned_lock_free = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, unsigned int>;
#elif ATOMIC_SHORT_LOCK_FREE == 2
using __libcpp_signed_lock_free   = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, short>;
using __libcpp_unsigned_lock_free = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, unsigned short>;
#elif ATOMIC_CHAR_LOCK_FREE == 2
using __libcpp_signed_lock_free   = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, char>;
using __libcpp_unsigned_lock_free = __conditional_t<_LIBCPP_CONTENTION_LOCK_FREE, __cxx_contention_t, unsigned char>;
#else
// No signed/unsigned lock-free types
#  define _LIBCPP_NO_LOCK_FREE_TYPES
#endif

#if !defined(_LIBCPP_NO_LOCK_FREE_TYPES)
using atomic_signed_lock_free   = atomic<__libcpp_signed_lock_free>;
using atomic_unsigned_lock_free = atomic<__libcpp_unsigned_lock_free>;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ATOMIC_ALIASES_H
