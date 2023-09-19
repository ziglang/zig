//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ATOMIC_ATOMIC_H
#define _LIBCPP___ATOMIC_ATOMIC_H

#include <__atomic/atomic_base.h>
#include <__atomic/check_memory_order.h>
#include <__atomic/cxx_atomic_impl.h>
#include <__atomic/memory_order.h>
#include <__config>
#include <__memory/addressof.h>
#include <__type_traits/is_function.h>
#include <__type_traits/is_same.h>
#include <__type_traits/remove_pointer.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct atomic
    : public __atomic_base<_Tp>
{
  using __base          = __atomic_base<_Tp>;
  using value_type      = _Tp;
  using difference_type = value_type;

#if _LIBCPP_STD_VER >= 20
    _LIBCPP_HIDE_FROM_ABI
    atomic() = default;
#else
    _LIBCPP_HIDE_FROM_ABI
    atomic() _NOEXCEPT = default;
#endif

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR atomic(_Tp __d) _NOEXCEPT : __base(__d) {}

    _LIBCPP_HIDE_FROM_ABI
    _Tp operator=(_Tp __d) volatile _NOEXCEPT
        {__base::store(__d); return __d;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp operator=(_Tp __d) _NOEXCEPT
        {__base::store(__d); return __d;}

    atomic& operator=(const atomic&) = delete;
    atomic& operator=(const atomic&) volatile = delete;
};

// atomic<T*>

template <class _Tp>
struct atomic<_Tp*>
    : public __atomic_base<_Tp*>
{
    using __base          = __atomic_base<_Tp*>;
    using value_type      = _Tp*;
    using difference_type = ptrdiff_t;

    _LIBCPP_HIDE_FROM_ABI
    atomic() _NOEXCEPT = default;

    _LIBCPP_HIDE_FROM_ABI
    _LIBCPP_CONSTEXPR atomic(_Tp* __d) _NOEXCEPT : __base(__d) {}

    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator=(_Tp* __d) volatile _NOEXCEPT
        {__base::store(__d); return __d;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator=(_Tp* __d) _NOEXCEPT
        {__base::store(__d); return __d;}

    _LIBCPP_HIDE_FROM_ABI
    _Tp* fetch_add(ptrdiff_t __op, memory_order __m = memory_order_seq_cst) volatile _NOEXCEPT {
        // __atomic_fetch_add accepts function pointers, guard against them.
        static_assert(!is_function<__remove_pointer_t<_Tp> >::value, "Pointer to function isn't allowed");
        return std::__cxx_atomic_fetch_add(std::addressof(this->__a_), __op, __m);
    }

    _LIBCPP_HIDE_FROM_ABI
    _Tp* fetch_add(ptrdiff_t __op, memory_order __m = memory_order_seq_cst) _NOEXCEPT {
        // __atomic_fetch_add accepts function pointers, guard against them.
        static_assert(!is_function<__remove_pointer_t<_Tp> >::value, "Pointer to function isn't allowed");
        return std::__cxx_atomic_fetch_add(std::addressof(this->__a_), __op, __m);
    }

    _LIBCPP_HIDE_FROM_ABI
    _Tp* fetch_sub(ptrdiff_t __op, memory_order __m = memory_order_seq_cst) volatile _NOEXCEPT {
        // __atomic_fetch_add accepts function pointers, guard against them.
        static_assert(!is_function<__remove_pointer_t<_Tp> >::value, "Pointer to function isn't allowed");
        return std::__cxx_atomic_fetch_sub(std::addressof(this->__a_), __op, __m);
    }

    _LIBCPP_HIDE_FROM_ABI
    _Tp* fetch_sub(ptrdiff_t __op, memory_order __m = memory_order_seq_cst) _NOEXCEPT {
        // __atomic_fetch_add accepts function pointers, guard against them.
        static_assert(!is_function<__remove_pointer_t<_Tp> >::value, "Pointer to function isn't allowed");
        return std::__cxx_atomic_fetch_sub(std::addressof(this->__a_), __op, __m);
    }

    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator++(int) volatile _NOEXCEPT            {return fetch_add(1);}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator++(int) _NOEXCEPT                     {return fetch_add(1);}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator--(int) volatile _NOEXCEPT            {return fetch_sub(1);}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator--(int) _NOEXCEPT                     {return fetch_sub(1);}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator++() volatile _NOEXCEPT               {return fetch_add(1) + 1;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator++() _NOEXCEPT                        {return fetch_add(1) + 1;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator--() volatile _NOEXCEPT               {return fetch_sub(1) - 1;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator--() _NOEXCEPT                        {return fetch_sub(1) - 1;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator+=(ptrdiff_t __op) volatile _NOEXCEPT {return fetch_add(__op) + __op;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator+=(ptrdiff_t __op) _NOEXCEPT          {return fetch_add(__op) + __op;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator-=(ptrdiff_t __op) volatile _NOEXCEPT {return fetch_sub(__op) - __op;}
    _LIBCPP_HIDE_FROM_ABI
    _Tp* operator-=(ptrdiff_t __op) _NOEXCEPT          {return fetch_sub(__op) - __op;}

    atomic& operator=(const atomic&) = delete;
    atomic& operator=(const atomic&) volatile = delete;
};

// atomic_is_lock_free

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_is_lock_free(const volatile atomic<_Tp>* __o) _NOEXCEPT
{
    return __o->is_lock_free();
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_is_lock_free(const atomic<_Tp>* __o) _NOEXCEPT
{
    return __o->is_lock_free();
}

// atomic_init

template <class _Tp>
_LIBCPP_DEPRECATED_IN_CXX20 _LIBCPP_HIDE_FROM_ABI
void
atomic_init(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    std::__cxx_atomic_init(std::addressof(__o->__a_), __d);
}

template <class _Tp>
_LIBCPP_DEPRECATED_IN_CXX20 _LIBCPP_HIDE_FROM_ABI
void
atomic_init(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    std::__cxx_atomic_init(std::addressof(__o->__a_), __d);
}

// atomic_store

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
void
atomic_store(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    __o->store(__d);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
void
atomic_store(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    __o->store(__d);
}

// atomic_store_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
void
atomic_store_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d, memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_STORE_MEMORY_ORDER(__m)
{
    __o->store(__d, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
void
atomic_store_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d, memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_STORE_MEMORY_ORDER(__m)
{
    __o->store(__d, __m);
}

// atomic_load

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_load(const volatile atomic<_Tp>* __o) _NOEXCEPT
{
    return __o->load();
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_load(const atomic<_Tp>* __o) _NOEXCEPT
{
    return __o->load();
}

// atomic_load_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_load_explicit(const volatile atomic<_Tp>* __o, memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_LOAD_MEMORY_ORDER(__m)
{
    return __o->load(__m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_load_explicit(const atomic<_Tp>* __o, memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_LOAD_MEMORY_ORDER(__m)
{
    return __o->load(__m);
}

// atomic_exchange

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_exchange(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->exchange(__d);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_exchange(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->exchange(__d);
}

// atomic_exchange_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_exchange_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d, memory_order __m) _NOEXCEPT
{
    return __o->exchange(__d, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_exchange_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __d, memory_order __m) _NOEXCEPT
{
    return __o->exchange(__d, __m);
}

// atomic_compare_exchange_weak

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_weak(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->compare_exchange_weak(*__e, __d);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_weak(atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->compare_exchange_weak(*__e, __d);
}

// atomic_compare_exchange_strong

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_strong(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->compare_exchange_strong(*__e, __d);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_strong(atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d) _NOEXCEPT
{
    return __o->compare_exchange_strong(*__e, __d);
}

// atomic_compare_exchange_weak_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_weak_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e,
                                      typename atomic<_Tp>::value_type __d,
                                      memory_order __s, memory_order __f) _NOEXCEPT
  _LIBCPP_CHECK_EXCHANGE_MEMORY_ORDER(__s, __f)
{
    return __o->compare_exchange_weak(*__e, __d, __s, __f);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_weak_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d,
                                      memory_order __s, memory_order __f) _NOEXCEPT
  _LIBCPP_CHECK_EXCHANGE_MEMORY_ORDER(__s, __f)
{
    return __o->compare_exchange_weak(*__e, __d, __s, __f);
}

// atomic_compare_exchange_strong_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_strong_explicit(volatile atomic<_Tp>* __o,
                                        typename atomic<_Tp>::value_type* __e, typename atomic<_Tp>::value_type __d,
                                        memory_order __s, memory_order __f) _NOEXCEPT
  _LIBCPP_CHECK_EXCHANGE_MEMORY_ORDER(__s, __f)
{
    return __o->compare_exchange_strong(*__e, __d, __s, __f);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
bool
atomic_compare_exchange_strong_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type* __e,
                                        typename atomic<_Tp>::value_type __d,
                                        memory_order __s, memory_order __f) _NOEXCEPT
  _LIBCPP_CHECK_EXCHANGE_MEMORY_ORDER(__s, __f)
{
    return __o->compare_exchange_strong(*__e, __d, __s, __f);
}

// atomic_wait

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_wait(const volatile atomic<_Tp>* __o,
                 typename atomic<_Tp>::value_type __v) _NOEXCEPT
{
    return __o->wait(__v);
}

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_wait(const atomic<_Tp>* __o,
                 typename atomic<_Tp>::value_type __v) _NOEXCEPT
{
    return __o->wait(__v);
}

// atomic_wait_explicit

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_wait_explicit(const volatile atomic<_Tp>* __o,
                          typename atomic<_Tp>::value_type __v,
                          memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_LOAD_MEMORY_ORDER(__m)
{
    return __o->wait(__v, __m);
}

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_wait_explicit(const atomic<_Tp>* __o,
                          typename atomic<_Tp>::value_type __v,
                          memory_order __m) _NOEXCEPT
  _LIBCPP_CHECK_LOAD_MEMORY_ORDER(__m)
{
    return __o->wait(__v, __m);
}

// atomic_notify_one

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_notify_one(volatile atomic<_Tp>* __o) _NOEXCEPT
{
    __o->notify_one();
}
template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_notify_one(atomic<_Tp>* __o) _NOEXCEPT
{
    __o->notify_one();
}

// atomic_notify_all

template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_notify_all(volatile atomic<_Tp>* __o) _NOEXCEPT
{
    __o->notify_all();
}
template <class _Tp>
_LIBCPP_AVAILABILITY_SYNC _LIBCPP_HIDE_FROM_ABI
void atomic_notify_all(atomic<_Tp>* __o) _NOEXCEPT
{
    __o->notify_all();
}

// atomic_fetch_add

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_fetch_add(volatile atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op) _NOEXCEPT
{
    return __o->fetch_add(__op);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp
atomic_fetch_add(atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op) _NOEXCEPT
{
    return __o->fetch_add(__op);
}

// atomic_fetch_add_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_add_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_add(__op, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_add_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_add(__op, __m);
}

// atomic_fetch_sub

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_sub(volatile atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op) _NOEXCEPT
{
    return __o->fetch_sub(__op);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_sub(atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op) _NOEXCEPT
{
    return __o->fetch_sub(__op);
}

// atomic_fetch_sub_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_sub_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_sub(__op, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
_Tp atomic_fetch_sub_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::difference_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_sub(__op, __m);
}

// atomic_fetch_and

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_and(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_and(__op);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_and(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_and(__op);
}

// atomic_fetch_and_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_and_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_and(__op, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_and_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_and(__op, __m);
}

// atomic_fetch_or

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_or(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_or(__op);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_or(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_or(__op);
}

// atomic_fetch_or_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_or_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_or(__op, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_or_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_or(__op, __m);
}

// atomic_fetch_xor

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_xor(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_xor(__op);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_xor(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op) _NOEXCEPT
{
    return __o->fetch_xor(__op);
}

// atomic_fetch_xor_explicit

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_xor_explicit(volatile atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_xor(__op, __m);
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI
typename enable_if
<
    is_integral<_Tp>::value && !is_same<_Tp, bool>::value,
    _Tp
>::type
atomic_fetch_xor_explicit(atomic<_Tp>* __o, typename atomic<_Tp>::value_type __op, memory_order __m) _NOEXCEPT
{
    return __o->fetch_xor(__op, __m);
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ATOMIC_ATOMIC_H
