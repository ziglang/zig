//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ATOMIC_CXX_ATOMIC_IMPL_H
#define _LIBCPP___ATOMIC_CXX_ATOMIC_IMPL_H

#include <__atomic/is_always_lock_free.h>
#include <__atomic/memory_order.h>
#include <__config>
#include <__memory/addressof.h>
#include <__type_traits/conditional.h>
#include <__type_traits/is_assignable.h>
#include <__type_traits/is_trivially_copyable.h>
#include <__type_traits/remove_const.h>
#include <cstddef>
#include <cstring>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if defined(_LIBCPP_HAS_GCC_ATOMIC_IMP) || defined(_LIBCPP_ATOMIC_ONLY_USE_BUILTINS)

// [atomics.types.generic]p1 guarantees _Tp is trivially copyable. Because
// the default operator= in an object is not volatile, a byte-by-byte copy
// is required.
template <typename _Tp, typename _Tv, __enable_if_t<is_assignable<_Tp&, _Tv>::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_assign_volatile(_Tp& __a_value, _Tv const& __val) {
  __a_value = __val;
}
template <typename _Tp, typename _Tv, __enable_if_t<is_assignable<_Tp&, _Tv>::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_assign_volatile(_Tp volatile& __a_value, _Tv volatile const& __val) {
  volatile char* __to         = reinterpret_cast<volatile char*>(std::addressof(__a_value));
  volatile char* __end        = __to + sizeof(_Tp);
  volatile const char* __from = reinterpret_cast<volatile const char*>(std::addressof(__val));
  while (__to != __end)
    *__to++ = *__from++;
}

#endif

#if defined(_LIBCPP_HAS_GCC_ATOMIC_IMP)

template <typename _Tp>
struct __cxx_atomic_base_impl {
  _LIBCPP_HIDE_FROM_ABI
#  ifndef _LIBCPP_CXX03_LANG
  __cxx_atomic_base_impl() _NOEXCEPT = default;
#  else
  __cxx_atomic_base_impl() _NOEXCEPT : __a_value() {
  }
#  endif // _LIBCPP_CXX03_LANG
  _LIBCPP_CONSTEXPR explicit __cxx_atomic_base_impl(_Tp value) _NOEXCEPT : __a_value(value) {}
  _Tp __a_value;
};

_LIBCPP_HIDE_FROM_ABI inline _LIBCPP_CONSTEXPR int __to_gcc_order(memory_order __order) {
  // Avoid switch statement to make this a constexpr.
  return __order == memory_order_relaxed
           ? __ATOMIC_RELAXED
           : (__order == memory_order_acquire
                  ? __ATOMIC_ACQUIRE
                  : (__order == memory_order_release
                         ? __ATOMIC_RELEASE
                         : (__order == memory_order_seq_cst
                                ? __ATOMIC_SEQ_CST
                                : (__order == memory_order_acq_rel ? __ATOMIC_ACQ_REL : __ATOMIC_CONSUME))));
}

_LIBCPP_HIDE_FROM_ABI inline _LIBCPP_CONSTEXPR int __to_gcc_failure_order(memory_order __order) {
  // Avoid switch statement to make this a constexpr.
  return __order == memory_order_relaxed
           ? __ATOMIC_RELAXED
           : (__order == memory_order_acquire
                  ? __ATOMIC_ACQUIRE
                  : (__order == memory_order_release
                         ? __ATOMIC_RELAXED
                         : (__order == memory_order_seq_cst
                                ? __ATOMIC_SEQ_CST
                                : (__order == memory_order_acq_rel ? __ATOMIC_ACQUIRE : __ATOMIC_CONSUME))));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __val) {
  __cxx_atomic_assign_volatile(__a->__a_value, __val);
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(__cxx_atomic_base_impl<_Tp>* __a, _Tp __val) {
  __a->__a_value = __val;
}

_LIBCPP_HIDE_FROM_ABI inline void __cxx_atomic_thread_fence(memory_order __order) {
  __atomic_thread_fence(__to_gcc_order(__order));
}

_LIBCPP_HIDE_FROM_ABI inline void __cxx_atomic_signal_fence(memory_order __order) {
  __atomic_signal_fence(__to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_store(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __val, memory_order __order) {
  __atomic_store(std::addressof(__a->__a_value), std::addressof(__val), __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_store(__cxx_atomic_base_impl<_Tp>* __a, _Tp __val, memory_order __order) {
  __atomic_store(std::addressof(__a->__a_value), std::addressof(__val), __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_load(const volatile __cxx_atomic_base_impl<_Tp>* __a, memory_order __order) {
  _Tp __ret;
  __atomic_load(std::addressof(__a->__a_value), std::addressof(__ret), __to_gcc_order(__order));
  return __ret;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_load_inplace(const volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp* __dst, memory_order __order) {
  __atomic_load(std::addressof(__a->__a_value), __dst, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_load_inplace(const __cxx_atomic_base_impl<_Tp>* __a, _Tp* __dst, memory_order __order) {
  __atomic_load(std::addressof(__a->__a_value), __dst, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_load(const __cxx_atomic_base_impl<_Tp>* __a, memory_order __order) {
  _Tp __ret;
  __atomic_load(std::addressof(__a->__a_value), std::addressof(__ret), __to_gcc_order(__order));
  return __ret;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_exchange(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __value, memory_order __order) {
  _Tp __ret;
  __atomic_exchange(
      std::addressof(__a->__a_value), std::addressof(__value), std::addressof(__ret), __to_gcc_order(__order));
  return __ret;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_exchange(__cxx_atomic_base_impl<_Tp>* __a, _Tp __value, memory_order __order) {
  _Tp __ret;
  __atomic_exchange(
      std::addressof(__a->__a_value), std::addressof(__value), std::addressof(__ret), __to_gcc_order(__order));
  return __ret;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    volatile __cxx_atomic_base_impl<_Tp>* __a,
    _Tp* __expected,
    _Tp __value,
    memory_order __success,
    memory_order __failure) {
  return __atomic_compare_exchange(
      std::addressof(__a->__a_value),
      __expected,
      std::addressof(__value),
      false,
      __to_gcc_order(__success),
      __to_gcc_failure_order(__failure));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    __cxx_atomic_base_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order __success, memory_order __failure) {
  return __atomic_compare_exchange(
      std::addressof(__a->__a_value),
      __expected,
      std::addressof(__value),
      false,
      __to_gcc_order(__success),
      __to_gcc_failure_order(__failure));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    volatile __cxx_atomic_base_impl<_Tp>* __a,
    _Tp* __expected,
    _Tp __value,
    memory_order __success,
    memory_order __failure) {
  return __atomic_compare_exchange(
      std::addressof(__a->__a_value),
      __expected,
      std::addressof(__value),
      true,
      __to_gcc_order(__success),
      __to_gcc_failure_order(__failure));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    __cxx_atomic_base_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order __success, memory_order __failure) {
  return __atomic_compare_exchange(
      std::addressof(__a->__a_value),
      __expected,
      std::addressof(__value),
      true,
      __to_gcc_order(__success),
      __to_gcc_failure_order(__failure));
}

template <typename _Tp>
struct __skip_amt {
  enum { value = 1 };
};

template <typename _Tp>
struct __skip_amt<_Tp*> {
  enum { value = sizeof(_Tp) };
};

// FIXME: Haven't figured out what the spec says about using arrays with
// atomic_fetch_add. Force a failure rather than creating bad behavior.
template <typename _Tp>
struct __skip_amt<_Tp[]> {};
template <typename _Tp, int n>
struct __skip_amt<_Tp[n]> {};

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_add(volatile __cxx_atomic_base_impl<_Tp>* __a, _Td __delta, memory_order __order) {
  return __atomic_fetch_add(std::addressof(__a->__a_value), __delta * __skip_amt<_Tp>::value, __to_gcc_order(__order));
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_add(__cxx_atomic_base_impl<_Tp>* __a, _Td __delta, memory_order __order) {
  return __atomic_fetch_add(std::addressof(__a->__a_value), __delta * __skip_amt<_Tp>::value, __to_gcc_order(__order));
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_sub(volatile __cxx_atomic_base_impl<_Tp>* __a, _Td __delta, memory_order __order) {
  return __atomic_fetch_sub(std::addressof(__a->__a_value), __delta * __skip_amt<_Tp>::value, __to_gcc_order(__order));
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_sub(__cxx_atomic_base_impl<_Tp>* __a, _Td __delta, memory_order __order) {
  return __atomic_fetch_sub(std::addressof(__a->__a_value), __delta * __skip_amt<_Tp>::value, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_and(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_and(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_and(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_and(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_or(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_or(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_or(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_or(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_xor(volatile __cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_xor(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_xor(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) {
  return __atomic_fetch_xor(std::addressof(__a->__a_value), __pattern, __to_gcc_order(__order));
}

#  define __cxx_atomic_is_lock_free(__s) __atomic_is_lock_free(__s, 0)

#elif defined(_LIBCPP_HAS_C_ATOMIC_IMP)

template <typename _Tp>
struct __cxx_atomic_base_impl {
  _LIBCPP_HIDE_FROM_ABI
#  ifndef _LIBCPP_CXX03_LANG
  __cxx_atomic_base_impl() _NOEXCEPT = default;
#  else
  __cxx_atomic_base_impl() _NOEXCEPT : __a_value() {
  }
#  endif // _LIBCPP_CXX03_LANG
  _LIBCPP_CONSTEXPR explicit __cxx_atomic_base_impl(_Tp __value) _NOEXCEPT : __a_value(__value) {}
  _LIBCPP_DISABLE_EXTENSION_WARNING _Atomic(_Tp) __a_value;
};

#  define __cxx_atomic_is_lock_free(__s) __c11_atomic_is_lock_free(__s)

_LIBCPP_HIDE_FROM_ABI inline void __cxx_atomic_thread_fence(memory_order __order) _NOEXCEPT {
  __c11_atomic_thread_fence(static_cast<__memory_order_underlying_t>(__order));
}

_LIBCPP_HIDE_FROM_ABI inline void __cxx_atomic_signal_fence(memory_order __order) _NOEXCEPT {
  __c11_atomic_signal_fence(static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __val) _NOEXCEPT {
  __c11_atomic_init(std::addressof(__a->__a_value), __val);
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(__cxx_atomic_base_impl<_Tp>* __a, _Tp __val) _NOEXCEPT {
  __c11_atomic_init(std::addressof(__a->__a_value), __val);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_store(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __val, memory_order __order) _NOEXCEPT {
  __c11_atomic_store(std::addressof(__a->__a_value), __val, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_store(__cxx_atomic_base_impl<_Tp>* __a, _Tp __val, memory_order __order) _NOEXCEPT {
  __c11_atomic_store(std::addressof(__a->__a_value), __val, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_load(__cxx_atomic_base_impl<_Tp> const volatile* __a, memory_order __order) _NOEXCEPT {
  using __ptr_type = __remove_const_t<decltype(__a->__a_value)>*;
  return __c11_atomic_load(
      const_cast<__ptr_type>(std::addressof(__a->__a_value)), static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_load(__cxx_atomic_base_impl<_Tp> const* __a, memory_order __order) _NOEXCEPT {
  using __ptr_type = __remove_const_t<decltype(__a->__a_value)>*;
  return __c11_atomic_load(
      const_cast<__ptr_type>(std::addressof(__a->__a_value)), static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_load_inplace(__cxx_atomic_base_impl<_Tp> const volatile* __a, _Tp* __dst, memory_order __order) _NOEXCEPT {
  using __ptr_type = __remove_const_t<decltype(__a->__a_value)>*;
  *__dst           = __c11_atomic_load(
      const_cast<__ptr_type>(std::addressof(__a->__a_value)), static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_load_inplace(__cxx_atomic_base_impl<_Tp> const* __a, _Tp* __dst, memory_order __order) _NOEXCEPT {
  using __ptr_type = __remove_const_t<decltype(__a->__a_value)>*;
  *__dst           = __c11_atomic_load(
      const_cast<__ptr_type>(std::addressof(__a->__a_value)), static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_exchange(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __value, memory_order __order) _NOEXCEPT {
  return __c11_atomic_exchange(
      std::addressof(__a->__a_value), __value, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_exchange(__cxx_atomic_base_impl<_Tp>* __a, _Tp __value, memory_order __order) _NOEXCEPT {
  return __c11_atomic_exchange(
      std::addressof(__a->__a_value), __value, static_cast<__memory_order_underlying_t>(__order));
}

_LIBCPP_HIDE_FROM_ABI inline _LIBCPP_CONSTEXPR memory_order __to_failure_order(memory_order __order) {
  // Avoid switch statement to make this a constexpr.
  return __order == memory_order_release
           ? memory_order_relaxed
           : (__order == memory_order_acq_rel ? memory_order_acquire : __order);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    __cxx_atomic_base_impl<_Tp> volatile* __a,
    _Tp* __expected,
    _Tp __value,
    memory_order __success,
    memory_order __failure) _NOEXCEPT {
  return __c11_atomic_compare_exchange_strong(
      std::addressof(__a->__a_value),
      __expected,
      __value,
      static_cast<__memory_order_underlying_t>(__success),
      static_cast<__memory_order_underlying_t>(__to_failure_order(__failure)));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    __cxx_atomic_base_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order __success, memory_order __failure)
    _NOEXCEPT {
  return __c11_atomic_compare_exchange_strong(
      std::addressof(__a->__a_value),
      __expected,
      __value,
      static_cast<__memory_order_underlying_t>(__success),
      static_cast<__memory_order_underlying_t>(__to_failure_order(__failure)));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    __cxx_atomic_base_impl<_Tp> volatile* __a,
    _Tp* __expected,
    _Tp __value,
    memory_order __success,
    memory_order __failure) _NOEXCEPT {
  return __c11_atomic_compare_exchange_weak(
      std::addressof(__a->__a_value),
      __expected,
      __value,
      static_cast<__memory_order_underlying_t>(__success),
      static_cast<__memory_order_underlying_t>(__to_failure_order(__failure)));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    __cxx_atomic_base_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order __success, memory_order __failure)
    _NOEXCEPT {
  return __c11_atomic_compare_exchange_weak(
      std::addressof(__a->__a_value),
      __expected,
      __value,
      static_cast<__memory_order_underlying_t>(__success),
      static_cast<__memory_order_underlying_t>(__to_failure_order(__failure)));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_add(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_add(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_add(__cxx_atomic_base_impl<_Tp>* __a, _Tp __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_add(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp*
__cxx_atomic_fetch_add(__cxx_atomic_base_impl<_Tp*> volatile* __a, ptrdiff_t __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_add(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp*
__cxx_atomic_fetch_add(__cxx_atomic_base_impl<_Tp*>* __a, ptrdiff_t __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_add(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_sub(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_sub(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_sub(__cxx_atomic_base_impl<_Tp>* __a, _Tp __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_sub(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp*
__cxx_atomic_fetch_sub(__cxx_atomic_base_impl<_Tp*> volatile* __a, ptrdiff_t __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_sub(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp*
__cxx_atomic_fetch_sub(__cxx_atomic_base_impl<_Tp*>* __a, ptrdiff_t __delta, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_sub(
      std::addressof(__a->__a_value), __delta, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_and(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_and(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_and(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_and(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_or(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_or(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_or(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_or(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_xor(__cxx_atomic_base_impl<_Tp> volatile* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_xor(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}
template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_xor(__cxx_atomic_base_impl<_Tp>* __a, _Tp __pattern, memory_order __order) _NOEXCEPT {
  return __c11_atomic_fetch_xor(
      std::addressof(__a->__a_value), __pattern, static_cast<__memory_order_underlying_t>(__order));
}

#endif // _LIBCPP_HAS_GCC_ATOMIC_IMP, _LIBCPP_HAS_C_ATOMIC_IMP

#ifdef _LIBCPP_ATOMIC_ONLY_USE_BUILTINS

template <typename _Tp>
struct __cxx_atomic_lock_impl {
  _LIBCPP_HIDE_FROM_ABI __cxx_atomic_lock_impl() _NOEXCEPT : __a_value(), __a_lock(0) {}
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR explicit __cxx_atomic_lock_impl(_Tp value) _NOEXCEPT
      : __a_value(value),
        __a_lock(0) {}

  _Tp __a_value;
  mutable __cxx_atomic_base_impl<_LIBCPP_ATOMIC_FLAG_TYPE> __a_lock;

  _LIBCPP_HIDE_FROM_ABI void __lock() const volatile {
    while (1 == __cxx_atomic_exchange(&__a_lock, _LIBCPP_ATOMIC_FLAG_TYPE(true), memory_order_acquire))
      /*spin*/;
  }
  _LIBCPP_HIDE_FROM_ABI void __lock() const {
    while (1 == __cxx_atomic_exchange(&__a_lock, _LIBCPP_ATOMIC_FLAG_TYPE(true), memory_order_acquire))
      /*spin*/;
  }
  _LIBCPP_HIDE_FROM_ABI void __unlock() const volatile {
    __cxx_atomic_store(&__a_lock, _LIBCPP_ATOMIC_FLAG_TYPE(false), memory_order_release);
  }
  _LIBCPP_HIDE_FROM_ABI void __unlock() const {
    __cxx_atomic_store(&__a_lock, _LIBCPP_ATOMIC_FLAG_TYPE(false), memory_order_release);
  }
  _LIBCPP_HIDE_FROM_ABI _Tp __read() const volatile {
    __lock();
    _Tp __old;
    __cxx_atomic_assign_volatile(__old, __a_value);
    __unlock();
    return __old;
  }
  _LIBCPP_HIDE_FROM_ABI _Tp __read() const {
    __lock();
    _Tp __old = __a_value;
    __unlock();
    return __old;
  }
  _LIBCPP_HIDE_FROM_ABI void __read_inplace(_Tp* __dst) const volatile {
    __lock();
    __cxx_atomic_assign_volatile(*__dst, __a_value);
    __unlock();
  }
  _LIBCPP_HIDE_FROM_ABI void __read_inplace(_Tp* __dst) const {
    __lock();
    *__dst = __a_value;
    __unlock();
  }
};

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __val) {
  __cxx_atomic_assign_volatile(__a->__a_value, __val);
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_init(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __val) {
  __a->__a_value = __val;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_store(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __val, memory_order) {
  __a->__lock();
  __cxx_atomic_assign_volatile(__a->__a_value, __val);
  __a->__unlock();
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_store(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __val, memory_order) {
  __a->__lock();
  __a->__a_value = __val;
  __a->__unlock();
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_load(const volatile __cxx_atomic_lock_impl<_Tp>* __a, memory_order) {
  return __a->__read();
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_load(const __cxx_atomic_lock_impl<_Tp>* __a, memory_order) {
  return __a->__read();
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void
__cxx_atomic_load(const volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __dst, memory_order) {
  __a->__read_inplace(__dst);
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI void __cxx_atomic_load(const __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __dst, memory_order) {
  __a->__read_inplace(__dst);
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_exchange(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __value, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, __value);
  __a->__unlock();
  return __old;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_exchange(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __value, memory_order) {
  __a->__lock();
  _Tp __old      = __a->__a_value;
  __a->__a_value = __value;
  __a->__unlock();
  return __old;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order, memory_order) {
  _Tp __temp;
  __a->__lock();
  __cxx_atomic_assign_volatile(__temp, __a->__a_value);
  bool __ret = (std::memcmp(&__temp, __expected, sizeof(_Tp)) == 0);
  if (__ret)
    __cxx_atomic_assign_volatile(__a->__a_value, __value);
  else
    __cxx_atomic_assign_volatile(*__expected, __a->__a_value);
  __a->__unlock();
  return __ret;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_strong(
    __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order, memory_order) {
  __a->__lock();
  bool __ret = (std::memcmp(&__a->__a_value, __expected, sizeof(_Tp)) == 0);
  if (__ret)
    std::memcpy(&__a->__a_value, &__value, sizeof(_Tp));
  else
    std::memcpy(__expected, &__a->__a_value, sizeof(_Tp));
  __a->__unlock();
  return __ret;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order, memory_order) {
  _Tp __temp;
  __a->__lock();
  __cxx_atomic_assign_volatile(__temp, __a->__a_value);
  bool __ret = (std::memcmp(&__temp, __expected, sizeof(_Tp)) == 0);
  if (__ret)
    __cxx_atomic_assign_volatile(__a->__a_value, __value);
  else
    __cxx_atomic_assign_volatile(*__expected, __a->__a_value);
  __a->__unlock();
  return __ret;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI bool __cxx_atomic_compare_exchange_weak(
    __cxx_atomic_lock_impl<_Tp>* __a, _Tp* __expected, _Tp __value, memory_order, memory_order) {
  __a->__lock();
  bool __ret = (std::memcmp(&__a->__a_value, __expected, sizeof(_Tp)) == 0);
  if (__ret)
    std::memcpy(&__a->__a_value, &__value, sizeof(_Tp));
  else
    std::memcpy(__expected, &__a->__a_value, sizeof(_Tp));
  __a->__unlock();
  return __ret;
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_add(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Td __delta, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, _Tp(__old + __delta));
  __a->__unlock();
  return __old;
}
template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_add(__cxx_atomic_lock_impl<_Tp>* __a, _Td __delta, memory_order) {
  __a->__lock();
  _Tp __old = __a->__a_value;
  __a->__a_value += __delta;
  __a->__unlock();
  return __old;
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp*
__cxx_atomic_fetch_add(volatile __cxx_atomic_lock_impl<_Tp*>* __a, ptrdiff_t __delta, memory_order) {
  __a->__lock();
  _Tp* __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, __old + __delta);
  __a->__unlock();
  return __old;
}
template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp* __cxx_atomic_fetch_add(__cxx_atomic_lock_impl<_Tp*>* __a, ptrdiff_t __delta, memory_order) {
  __a->__lock();
  _Tp* __old = __a->__a_value;
  __a->__a_value += __delta;
  __a->__unlock();
  return __old;
}

template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_sub(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Td __delta, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, _Tp(__old - __delta));
  __a->__unlock();
  return __old;
}
template <typename _Tp, typename _Td>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_sub(__cxx_atomic_lock_impl<_Tp>* __a, _Td __delta, memory_order) {
  __a->__lock();
  _Tp __old = __a->__a_value;
  __a->__a_value -= __delta;
  __a->__unlock();
  return __old;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_and(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, _Tp(__old & __pattern));
  __a->__unlock();
  return __old;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_and(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old = __a->__a_value;
  __a->__a_value &= __pattern;
  __a->__unlock();
  return __old;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_or(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, _Tp(__old | __pattern));
  __a->__unlock();
  return __old;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_or(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old = __a->__a_value;
  __a->__a_value |= __pattern;
  __a->__unlock();
  return __old;
}

template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp
__cxx_atomic_fetch_xor(volatile __cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old;
  __cxx_atomic_assign_volatile(__old, __a->__a_value);
  __cxx_atomic_assign_volatile(__a->__a_value, _Tp(__old ^ __pattern));
  __a->__unlock();
  return __old;
}
template <typename _Tp>
_LIBCPP_HIDE_FROM_ABI _Tp __cxx_atomic_fetch_xor(__cxx_atomic_lock_impl<_Tp>* __a, _Tp __pattern, memory_order) {
  __a->__lock();
  _Tp __old = __a->__a_value;
  __a->__a_value ^= __pattern;
  __a->__unlock();
  return __old;
}

template <typename _Tp,
          typename _Base = typename conditional<__libcpp_is_always_lock_free<_Tp>::__value,
                                                __cxx_atomic_base_impl<_Tp>,
                                                __cxx_atomic_lock_impl<_Tp> >::type>
#else
template <typename _Tp, typename _Base = __cxx_atomic_base_impl<_Tp> >
#endif //_LIBCPP_ATOMIC_ONLY_USE_BUILTINS
struct __cxx_atomic_impl : public _Base {
  static_assert(is_trivially_copyable<_Tp>::value, "std::atomic<T> requires that 'T' be a trivially copyable type");

  _LIBCPP_HIDE_FROM_ABI __cxx_atomic_impl() _NOEXCEPT = default;
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR explicit __cxx_atomic_impl(_Tp __value) _NOEXCEPT : _Base(__value) {}
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ATOMIC_CXX_ATOMIC_IMPL_H
