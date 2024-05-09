//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ATOMIC_ATOMIC_SYNC_H
#define _LIBCPP___ATOMIC_ATOMIC_SYNC_H

#include <__atomic/contention_t.h>
#include <__atomic/cxx_atomic_impl.h>
#include <__atomic/memory_order.h>
#include <__availability>
#include <__chrono/duration.h>
#include <__config>
#include <__memory/addressof.h>
#include <__thread/poll_with_backoff.h>
#include <__threading_support>
#include <__type_traits/decay.h>
#include <cstring>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#ifndef _LIBCPP_HAS_NO_THREADS

_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void __cxx_atomic_notify_one(void const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void __cxx_atomic_notify_all(void const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI __cxx_contention_t __libcpp_atomic_monitor(void const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void __libcpp_atomic_wait(void const volatile*, __cxx_contention_t);

_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void
__cxx_atomic_notify_one(__cxx_atomic_contention_t const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void
__cxx_atomic_notify_all(__cxx_atomic_contention_t const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI __cxx_contention_t
__libcpp_atomic_monitor(__cxx_atomic_contention_t const volatile*);
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_EXPORTED_FROM_ABI void
__libcpp_atomic_wait(__cxx_atomic_contention_t const volatile*, __cxx_contention_t);

template <class _Atp, class _Fn>
struct __libcpp_atomic_wait_backoff_impl {
  _Atp* __a;
  _Fn __test_fn;
  _LIBCPP_AVAILABILITY_SYNC
  _LIBCPP_HIDE_FROM_ABI bool operator()(chrono::nanoseconds __elapsed) const {
    if (__elapsed > chrono::microseconds(64)) {
      auto const __monitor = std::__libcpp_atomic_monitor(__a);
      if (__test_fn())
        return true;
      std::__libcpp_atomic_wait(__a, __monitor);
    } else if (__elapsed > chrono::microseconds(4))
      __libcpp_thread_yield();
    else {
    } // poll
    return false;
  }
};

template <class _Atp, class _Fn>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_wait(_Atp* __a, _Fn&& __test_fn) {
  __libcpp_atomic_wait_backoff_impl<_Atp, __decay_t<_Fn> > __backoff_fn = {__a, __test_fn};
  return std::__libcpp_thread_poll_with_backoff(__test_fn, __backoff_fn);
}

#else // _LIBCPP_HAS_NO_THREADS

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_notify_all(__cxx_atomic_impl<_Tp> const volatile*) {}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_notify_one(__cxx_atomic_impl<_Tp> const volatile*) {}
template <class _Atp, class _Fn>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_wait(_Atp*, _Fn&& __test_fn) {
  return std::__libcpp_thread_poll_with_backoff(__test_fn, __spinning_backoff_policy());
}

#endif // _LIBCPP_HAS_NO_THREADS

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_nonatomic_compare_equal(_Tp const& __lhs, _Tp const& __rhs) {
  return std::memcmp(std::addressof(__lhs), std::addressof(__rhs), sizeof(_Tp)) == 0;
}

template <class _Atp, class _Tp>
struct __cxx_atomic_wait_test_fn_impl {
  _Atp* __a;
  _Tp __val;
  memory_order __order;
  _LIBCPP_HIDE_FROM_ABI bool operator()() const {
    return !std::__cxx_nonatomic_compare_equal(std::__cxx_atomic_load(__a, __order), __val);
  }
};

template <class _Atp, class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI bool
__cxx_atomic_wait(_Atp* __a, _Tp const __val, memory_order __order) {
  __cxx_atomic_wait_test_fn_impl<_Atp, _Tp> __test_fn = {__a, __val, __order};
  return std::__cxx_atomic_wait(__a, __test_fn);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ATOMIC_ATOMIC_SYNC_H
