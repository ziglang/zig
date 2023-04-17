// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___EXPECTED_EXPECTED_H
#define _LIBCPP___EXPECTED_EXPECTED_H

#include <__assert>
#include <__config>
#include <__expected/bad_expected_access.h>
#include <__expected/unexpect.h>
#include <__expected/unexpected.h>
#include <__memory/addressof.h>
#include <__memory/construct_at.h>
#include <__type_traits/conjunction.h>
#include <__type_traits/disjunction.h>
#include <__type_traits/is_assignable.h>
#include <__type_traits/is_constructible.h>
#include <__type_traits/is_convertible.h>
#include <__type_traits/is_copy_assignable.h>
#include <__type_traits/is_copy_constructible.h>
#include <__type_traits/is_default_constructible.h>
#include <__type_traits/is_function.h>
#include <__type_traits/is_move_assignable.h>
#include <__type_traits/is_move_constructible.h>
#include <__type_traits/is_nothrow_constructible.h>
#include <__type_traits/is_nothrow_copy_assignable.h>
#include <__type_traits/is_nothrow_copy_constructible.h>
#include <__type_traits/is_nothrow_default_constructible.h>
#include <__type_traits/is_nothrow_move_assignable.h>
#include <__type_traits/is_nothrow_move_constructible.h>
#include <__type_traits/is_reference.h>
#include <__type_traits/is_same.h>
#include <__type_traits/is_swappable.h>
#include <__type_traits/is_trivially_copy_constructible.h>
#include <__type_traits/is_trivially_destructible.h>
#include <__type_traits/is_trivially_move_constructible.h>
#include <__type_traits/is_void.h>
#include <__type_traits/lazy.h>
#include <__type_traits/negation.h>
#include <__type_traits/remove_cv.h>
#include <__type_traits/remove_cvref.h>
#include <__utility/exception_guard.h>
#include <__utility/forward.h>
#include <__utility/in_place.h>
#include <__utility/move.h>
#include <__utility/swap.h>
#include <cstdlib> // for std::abort
#include <initializer_list>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER >= 23

_LIBCPP_BEGIN_NAMESPACE_STD

namespace __expected {

template <class _Err, class _Arg>
_LIBCPP_HIDE_FROM_ABI void __throw_bad_expected_access(_Arg&& __arg) {
#  ifndef _LIBCPP_NO_EXCEPTIONS
  throw bad_expected_access<_Err>(std::forward<_Arg>(__arg));
#  else
  (void)__arg;
  std::abort();
#  endif
}

} // namespace __expected

template <class _Tp, class _Err>
class expected {
  static_assert(
      !is_reference_v<_Tp> &&
          !is_function_v<_Tp> &&
          !is_same_v<remove_cv_t<_Tp>, in_place_t> &&
          !is_same_v<remove_cv_t<_Tp>, unexpect_t> &&
          !__is_std_unexpected<remove_cv_t<_Tp>>::value &&
          __valid_std_unexpected<_Err>::value
      ,
      "[expected.object.general] A program that instantiates the definition of template expected<T, E> for a "
      "reference type, a function type, or for possibly cv-qualified types in_place_t, unexpect_t, or a "
      "specialization of unexpected for the T parameter is ill-formed. A program that instantiates the "
      "definition of the template expected<T, E> with a type for the E parameter that is not a valid "
      "template argument for unexpected is ill-formed.");

  template <class _Up, class _OtherErr>
  friend class expected;

public:
  using value_type      = _Tp;
  using error_type      = _Err;
  using unexpected_type = unexpected<_Err>;

  template <class _Up>
  using rebind = expected<_Up, error_type>;

  // [expected.object.ctor], constructors
  _LIBCPP_HIDE_FROM_ABI constexpr expected()
    noexcept(is_nothrow_default_constructible_v<_Tp>) // strengthened
    requires is_default_constructible_v<_Tp>
      : __has_val_(true) {
    std::construct_at(std::addressof(__union_.__val_));
  }

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected&) = delete;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected&)
    requires(is_copy_constructible_v<_Tp> &&
             is_copy_constructible_v<_Err> &&
             is_trivially_copy_constructible_v<_Tp> &&
             is_trivially_copy_constructible_v<_Err>)
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected& __other)
    noexcept(is_nothrow_copy_constructible_v<_Tp> && is_nothrow_copy_constructible_v<_Err>) // strengthened
    requires(is_copy_constructible_v<_Tp> && is_copy_constructible_v<_Err> &&
             !(is_trivially_copy_constructible_v<_Tp> && is_trivially_copy_constructible_v<_Err>))
      : __has_val_(__other.__has_val_) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__val_), __other.__union_.__val_);
    } else {
      std::construct_at(std::addressof(__union_.__unex_), __other.__union_.__unex_);
    }
  }


  _LIBCPP_HIDE_FROM_ABI constexpr expected(expected&&)
    requires(is_move_constructible_v<_Tp> && is_move_constructible_v<_Err>
              && is_trivially_move_constructible_v<_Tp> && is_trivially_move_constructible_v<_Err>)
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(expected&& __other)
    noexcept(is_nothrow_move_constructible_v<_Tp> && is_nothrow_move_constructible_v<_Err>)
    requires(is_move_constructible_v<_Tp> && is_move_constructible_v<_Err> &&
             !(is_trivially_move_constructible_v<_Tp> && is_trivially_move_constructible_v<_Err>))
      : __has_val_(__other.__has_val_) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__val_), std::move(__other.__union_.__val_));
    } else {
      std::construct_at(std::addressof(__union_.__unex_), std::move(__other.__union_.__unex_));
    }
  }

private:
  template <class _Up, class _OtherErr, class _UfQual, class _OtherErrQual>
  using __can_convert =
      _And< is_constructible<_Tp, _UfQual>,
            is_constructible<_Err, _OtherErrQual>,
            _Not<is_constructible<_Tp, expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<_Tp, expected<_Up, _OtherErr>>>,
            _Not<is_constructible<_Tp, const expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<_Tp, const expected<_Up, _OtherErr>>>,
            _Not<is_convertible<expected<_Up, _OtherErr>&, _Tp>>,
            _Not<is_convertible<expected<_Up, _OtherErr>&&, _Tp>>,
            _Not<is_convertible<const expected<_Up, _OtherErr>&, _Tp>>,
            _Not<is_convertible<const expected<_Up, _OtherErr>&&, _Tp>>,
            _Not<is_constructible<unexpected<_Err>, expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<unexpected<_Err>, expected<_Up, _OtherErr>>>,
            _Not<is_constructible<unexpected<_Err>, const expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<unexpected<_Err>, const expected<_Up, _OtherErr>>> >;


public:
  template <class _Up, class _OtherErr>
    requires __can_convert<_Up, _OtherErr, const _Up&, const _OtherErr&>::value
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<const _Up&, _Tp> ||
                                           !is_convertible_v<const _OtherErr&, _Err>)
  expected(const expected<_Up, _OtherErr>& __other)
    noexcept(is_nothrow_constructible_v<_Tp, const _Up&> &&
             is_nothrow_constructible_v<_Err, const _OtherErr&>) // strengthened
      : __has_val_(__other.__has_val_) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__val_), __other.__union_.__val_);
    } else {
      std::construct_at(std::addressof(__union_.__unex_), __other.__union_.__unex_);
    }
  }

  template <class _Up, class _OtherErr>
    requires __can_convert<_Up, _OtherErr, _Up, _OtherErr>::value
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<_Up, _Tp> || !is_convertible_v<_OtherErr, _Err>)
  expected(expected<_Up, _OtherErr>&& __other)
    noexcept(is_nothrow_constructible_v<_Tp, _Up> && is_nothrow_constructible_v<_Err, _OtherErr>) // strengthened
      : __has_val_(__other.__has_val_) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__val_), std::move(__other.__union_.__val_));
    } else {
      std::construct_at(std::addressof(__union_.__unex_), std::move(__other.__union_.__unex_));
    }
  }

  template <class _Up = _Tp>
    requires(!is_same_v<remove_cvref_t<_Up>, in_place_t> && !is_same_v<expected, remove_cvref_t<_Up>> &&
             !__is_std_unexpected<remove_cvref_t<_Up>>::value && is_constructible_v<_Tp, _Up>)
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<_Up, _Tp>)
  expected(_Up&& __u)
    noexcept(is_nothrow_constructible_v<_Tp, _Up>) // strengthened
      : __has_val_(true) {
    std::construct_at(std::addressof(__union_.__val_), std::forward<_Up>(__u));
  }


  template <class _OtherErr>
    requires is_constructible_v<_Err, const _OtherErr&>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<const _OtherErr&, _Err>)
  expected(const unexpected<_OtherErr>& __unex)
    noexcept(is_nothrow_constructible_v<_Err, const _OtherErr&>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), __unex.error());
  }

  template <class _OtherErr>
    requires is_constructible_v<_Err, _OtherErr>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<_OtherErr, _Err>)
  expected(unexpected<_OtherErr>&& __unex)
    noexcept(is_nothrow_constructible_v<_Err, _OtherErr>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), std::move(__unex.error()));
  }

  template <class... _Args>
    requires is_constructible_v<_Tp, _Args...>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit expected(in_place_t, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Tp, _Args...>) // strengthened
      : __has_val_(true) {
    std::construct_at(std::addressof(__union_.__val_), std::forward<_Args>(__args)...);
  }

  template <class _Up, class... _Args>
    requires is_constructible_v< _Tp, initializer_list<_Up>&, _Args... >
  _LIBCPP_HIDE_FROM_ABI constexpr explicit
  expected(in_place_t, initializer_list<_Up> __il, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Tp, initializer_list<_Up>&, _Args...>) // strengthened
      : __has_val_(true) {
    std::construct_at(std::addressof(__union_.__val_), __il, std::forward<_Args>(__args)...);
  }

  template <class... _Args>
    requires is_constructible_v<_Err, _Args...>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit expected(unexpect_t, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Err, _Args...>)  // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), std::forward<_Args>(__args)...);
  }

  template <class _Up, class... _Args>
    requires is_constructible_v< _Err, initializer_list<_Up>&, _Args... >
  _LIBCPP_HIDE_FROM_ABI constexpr explicit
  expected(unexpect_t, initializer_list<_Up> __il, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Err, initializer_list<_Up>&, _Args...>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), __il, std::forward<_Args>(__args)...);
  }

  // [expected.object.dtor], destructor

  _LIBCPP_HIDE_FROM_ABI constexpr ~expected()
    requires(is_trivially_destructible_v<_Tp> && is_trivially_destructible_v<_Err>)
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr ~expected()
    requires(!is_trivially_destructible_v<_Tp> || !is_trivially_destructible_v<_Err>)
  {
    if (__has_val_) {
      std::destroy_at(std::addressof(__union_.__val_));
    } else {
      std::destroy_at(std::addressof(__union_.__unex_));
    }
  }

private:
  template <class _T1, class _T2, class... _Args>
  _LIBCPP_HIDE_FROM_ABI static constexpr void __reinit_expected(_T1& __newval, _T2& __oldval, _Args&&... __args) {
    if constexpr (is_nothrow_constructible_v<_T1, _Args...>) {
      std::destroy_at(std::addressof(__oldval));
      std::construct_at(std::addressof(__newval), std::forward<_Args>(__args)...);
    } else if constexpr (is_nothrow_move_constructible_v<_T1>) {
      _T1 __tmp(std::forward<_Args>(__args)...);
      std::destroy_at(std::addressof(__oldval));
      std::construct_at(std::addressof(__newval), std::move(__tmp));
    } else {
      static_assert(
          is_nothrow_move_constructible_v<_T2>,
          "To provide strong exception guarantee, T2 has to satisfy `is_nothrow_move_constructible_v` so that it can "
          "be reverted to the previous state in case an exception is thrown during the assignment.");
      _T2 __tmp(std::move(__oldval));
      std::destroy_at(std::addressof(__oldval));
      auto __trans =
          std::__make_exception_guard([&] { std::construct_at(std::addressof(__oldval), std::move(__tmp)); });
      std::construct_at(std::addressof(__newval), std::forward<_Args>(__args)...);
      __trans.__complete();
    }
  }

public:
  // [expected.object.assign], assignment
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const expected&) = delete;

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const expected& __rhs)
    noexcept(is_nothrow_copy_assignable_v<_Tp> &&
             is_nothrow_copy_constructible_v<_Tp> &&
             is_nothrow_copy_assignable_v<_Err> &&
             is_nothrow_copy_constructible_v<_Err>) // strengthened
    requires(is_copy_assignable_v<_Tp> &&
             is_copy_constructible_v<_Tp> &&
             is_copy_assignable_v<_Err> &&
             is_copy_constructible_v<_Err> &&
             (is_nothrow_move_constructible_v<_Tp> ||
              is_nothrow_move_constructible_v<_Err>))
  {
    if (__has_val_ && __rhs.__has_val_) {
      __union_.__val_ = __rhs.__union_.__val_;
    } else if (__has_val_) {
      __reinit_expected(__union_.__unex_, __union_.__val_, __rhs.__union_.__unex_);
    } else if (__rhs.__has_val_) {
      __reinit_expected(__union_.__val_, __union_.__unex_, __rhs.__union_.__val_);
    } else {
      __union_.__unex_ = __rhs.__union_.__unex_;
    }
    // note: only reached if no exception+rollback was done inside __reinit_expected
    __has_val_ = __rhs.__has_val_;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(expected&& __rhs)
    noexcept(is_nothrow_move_assignable_v<_Tp> &&
             is_nothrow_move_constructible_v<_Tp> &&
             is_nothrow_move_assignable_v<_Err> &&
             is_nothrow_move_constructible_v<_Err>)
    requires(is_move_constructible_v<_Tp> &&
             is_move_assignable_v<_Tp> &&
             is_move_constructible_v<_Err> &&
             is_move_assignable_v<_Err> &&
             (is_nothrow_move_constructible_v<_Tp> ||
              is_nothrow_move_constructible_v<_Err>))
  {
    if (__has_val_ && __rhs.__has_val_) {
      __union_.__val_ = std::move(__rhs.__union_.__val_);
    } else if (__has_val_) {
      __reinit_expected(__union_.__unex_, __union_.__val_, std::move(__rhs.__union_.__unex_));
    } else if (__rhs.__has_val_) {
      __reinit_expected(__union_.__val_, __union_.__unex_, std::move(__rhs.__union_.__val_));
    } else {
      __union_.__unex_ = std::move(__rhs.__union_.__unex_);
    }
    // note: only reached if no exception+rollback was done inside __reinit_expected
    __has_val_ = __rhs.__has_val_;
    return *this;
  }

  template <class _Up = _Tp>
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(_Up&& __v)
    requires(!is_same_v<expected, remove_cvref_t<_Up>> &&
             !__is_std_unexpected<remove_cvref_t<_Up>>::value &&
             is_constructible_v<_Tp, _Up> &&
             is_assignable_v<_Tp&, _Up> &&
             (is_nothrow_constructible_v<_Tp, _Up> ||
              is_nothrow_move_constructible_v<_Tp> ||
              is_nothrow_move_constructible_v<_Err>))
  {
    if (__has_val_) {
      __union_.__val_ = std::forward<_Up>(__v);
    } else {
      __reinit_expected(__union_.__val_, __union_.__unex_, std::forward<_Up>(__v));
      __has_val_ = true;
    }
    return *this;
  }

private:
  template <class _OtherErrQual>
  static constexpr bool __can_assign_from_unexpected =
      _And< is_constructible<_Err, _OtherErrQual>,
            is_assignable<_Err&, _OtherErrQual>,
            _Lazy<_Or,
                  is_nothrow_constructible<_Err, _OtherErrQual>,
                  is_nothrow_move_constructible<_Tp>,
                  is_nothrow_move_constructible<_Err>> >::value;

public:
  template <class _OtherErr>
    requires(__can_assign_from_unexpected<const _OtherErr&>)
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const unexpected<_OtherErr>& __un) {
    if (__has_val_) {
      __reinit_expected(__union_.__unex_, __union_.__val_, __un.error());
      __has_val_ = false;
    } else {
      __union_.__unex_ = __un.error();
    }
    return *this;
  }

  template <class _OtherErr>
    requires(__can_assign_from_unexpected<_OtherErr>)
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(unexpected<_OtherErr>&& __un) {
    if (__has_val_) {
      __reinit_expected(__union_.__unex_, __union_.__val_, std::move(__un.error()));
      __has_val_ = false;
    } else {
      __union_.__unex_ = std::move(__un.error());
    }
    return *this;
  }

  template <class... _Args>
    requires is_nothrow_constructible_v<_Tp, _Args...>
  _LIBCPP_HIDE_FROM_ABI constexpr _Tp& emplace(_Args&&... __args) noexcept {
    if (__has_val_) {
      std::destroy_at(std::addressof(__union_.__val_));
    } else {
      std::destroy_at(std::addressof(__union_.__unex_));
      __has_val_ = true;
    }
    return *std::construct_at(std::addressof(__union_.__val_), std::forward<_Args>(__args)...);
  }

  template <class _Up, class... _Args>
    requires is_nothrow_constructible_v< _Tp, initializer_list<_Up>&, _Args... >
  _LIBCPP_HIDE_FROM_ABI constexpr _Tp& emplace(initializer_list<_Up> __il, _Args&&... __args) noexcept {
    if (__has_val_) {
      std::destroy_at(std::addressof(__union_.__val_));
    } else {
      std::destroy_at(std::addressof(__union_.__unex_));
      __has_val_ = true;
    }
    return *std::construct_at(std::addressof(__union_.__val_), __il, std::forward<_Args>(__args)...);
  }


public:
  // [expected.object.swap], swap
  _LIBCPP_HIDE_FROM_ABI constexpr void swap(expected& __rhs)
    noexcept(is_nothrow_move_constructible_v<_Tp> &&
             is_nothrow_swappable_v<_Tp> &&
             is_nothrow_move_constructible_v<_Err> &&
             is_nothrow_swappable_v<_Err>)
    requires(is_swappable_v<_Tp> &&
             is_swappable_v<_Err> &&
             is_move_constructible_v<_Tp> &&
             is_move_constructible_v<_Err> &&
             (is_nothrow_move_constructible_v<_Tp> ||
              is_nothrow_move_constructible_v<_Err>))
  {
    auto __swap_val_unex_impl = [&](expected& __with_val, expected& __with_err) {
      if constexpr (is_nothrow_move_constructible_v<_Err>) {
        _Err __tmp(std::move(__with_err.__union_.__unex_));
        std::destroy_at(std::addressof(__with_err.__union_.__unex_));
        auto __trans = std::__make_exception_guard([&] {
          std::construct_at(std::addressof(__with_err.__union_.__unex_), std::move(__tmp));
        });
        std::construct_at(std::addressof(__with_err.__union_.__val_), std::move(__with_val.__union_.__val_));
        __trans.__complete();
        std::destroy_at(std::addressof(__with_val.__union_.__val_));
        std::construct_at(std::addressof(__with_val.__union_.__unex_), std::move(__tmp));
      } else {
        static_assert(is_nothrow_move_constructible_v<_Tp>,
                      "To provide strong exception guarantee, Tp has to satisfy `is_nothrow_move_constructible_v` so "
                      "that it can be reverted to the previous state in case an exception is thrown during swap.");
        _Tp __tmp(std::move(__with_val.__union_.__val_));
        std::destroy_at(std::addressof(__with_val.__union_.__val_));
        auto __trans = std::__make_exception_guard([&] {
          std::construct_at(std::addressof(__with_val.__union_.__val_), std::move(__tmp));
        });
        std::construct_at(std::addressof(__with_val.__union_.__unex_), std::move(__with_err.__union_.__unex_));
        __trans.__complete();
        std::destroy_at(std::addressof(__with_err.__union_.__unex_));
        std::construct_at(std::addressof(__with_err.__union_.__val_), std::move(__tmp));
      }
      __with_val.__has_val_ = false;
      __with_err.__has_val_ = true;
    };

    if (__has_val_) {
      if (__rhs.__has_val_) {
        using std::swap;
        swap(__union_.__val_, __rhs.__union_.__val_);
      } else {
        __swap_val_unex_impl(*this, __rhs);
      }
    } else {
      if (__rhs.__has_val_) {
        __swap_val_unex_impl(__rhs, *this);
      } else {
        using std::swap;
        swap(__union_.__unex_, __rhs.__union_.__unex_);
      }
    }
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr void swap(expected& __x, expected& __y)
    noexcept(noexcept(__x.swap(__y)))
    requires requires { __x.swap(__y); }
  {
    __x.swap(__y);
  }

  // [expected.object.obs], observers
  _LIBCPP_HIDE_FROM_ABI constexpr const _Tp* operator->() const noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator-> requires the expected to contain a value");
    return std::addressof(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Tp* operator->() noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator-> requires the expected to contain a value");
    return std::addressof(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Tp& operator*() const& noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator* requires the expected to contain a value");
    return __union_.__val_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Tp& operator*() & noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator* requires the expected to contain a value");
    return __union_.__val_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Tp&& operator*() const&& noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator* requires the expected to contain a value");
    return std::move(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Tp&& operator*() && noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator* requires the expected to contain a value");
    return std::move(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr explicit operator bool() const noexcept { return __has_val_; }

  _LIBCPP_HIDE_FROM_ABI constexpr bool has_value() const noexcept { return __has_val_; }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Tp& value() const& {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(__union_.__unex_);
    }
    return __union_.__val_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Tp& value() & {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(__union_.__unex_);
    }
    return __union_.__val_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Tp&& value() const&& {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(std::move(__union_.__unex_));
    }
    return std::move(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Tp&& value() && {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(std::move(__union_.__unex_));
    }
    return std::move(__union_.__val_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Err& error() const& noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return __union_.__unex_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Err& error() & noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return __union_.__unex_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Err&& error() const&& noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return std::move(__union_.__unex_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Err&& error() && noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return std::move(__union_.__unex_);
  }

  template <class _Up>
  _LIBCPP_HIDE_FROM_ABI constexpr _Tp value_or(_Up&& __v) const& {
    static_assert(is_copy_constructible_v<_Tp>, "value_type has to be copy constructible");
    static_assert(is_convertible_v<_Up, _Tp>, "argument has to be convertible to value_type");
    return __has_val_ ? __union_.__val_ : static_cast<_Tp>(std::forward<_Up>(__v));
  }

  template <class _Up>
  _LIBCPP_HIDE_FROM_ABI constexpr _Tp value_or(_Up&& __v) && {
    static_assert(is_move_constructible_v<_Tp>, "value_type has to be move constructible");
    static_assert(is_convertible_v<_Up, _Tp>, "argument has to be convertible to value_type");
    return __has_val_ ? std::move(__union_.__val_) : static_cast<_Tp>(std::forward<_Up>(__v));
  }

  // [expected.object.eq], equality operators
  template <class _T2, class _E2>
    requires(!is_void_v<_T2>)
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const expected& __x, const expected<_T2, _E2>& __y) {
    if (__x.__has_val_ != __y.__has_val_) {
      return false;
    } else {
      if (__x.__has_val_) {
        return __x.__union_.__val_ == __y.__union_.__val_;
      } else {
        return __x.__union_.__unex_ == __y.__union_.__unex_;
      }
    }
  }

  template <class _T2>
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const expected& __x, const _T2& __v) {
    return __x.__has_val_ && static_cast<bool>(__x.__union_.__val_ == __v);
  }

  template <class _E2>
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const expected& __x, const unexpected<_E2>& __e) {
    return !__x.__has_val_ && static_cast<bool>(__x.__union_.__unex_ == __e.error());
  }

private:
  struct __empty_t {};
  // use named union because [[no_unique_address]] cannot be applied to an unnamed union
  _LIBCPP_NO_UNIQUE_ADDRESS union __union_t {
    _LIBCPP_HIDE_FROM_ABI constexpr __union_t() : __empty_() {}

    _LIBCPP_HIDE_FROM_ABI constexpr ~__union_t()
      requires(is_trivially_destructible_v<_Tp> && is_trivially_destructible_v<_Err>)
    = default;

    // the expected's destructor handles this
    _LIBCPP_HIDE_FROM_ABI constexpr ~__union_t()
      requires(!is_trivially_destructible_v<_Tp> || !is_trivially_destructible_v<_Err>)
    {}

    _LIBCPP_NO_UNIQUE_ADDRESS __empty_t __empty_;
    _LIBCPP_NO_UNIQUE_ADDRESS _Tp __val_;
    _LIBCPP_NO_UNIQUE_ADDRESS _Err __unex_;
  } __union_;

  bool __has_val_;
};

template <class _Tp, class _Err>
  requires is_void_v<_Tp>
class expected<_Tp, _Err> {
  static_assert(__valid_std_unexpected<_Err>::value,
                "[expected.void.general] A program that instantiates expected<T, E> with a E that is not a "
                "valid argument for unexpected<E> is ill-formed");

  template <class, class>
  friend class expected;

  template <class _Up, class _OtherErr, class _OtherErrQual>
  using __can_convert =
      _And< is_void<_Up>,
            is_constructible<_Err, _OtherErrQual>,
            _Not<is_constructible<unexpected<_Err>, expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<unexpected<_Err>, expected<_Up, _OtherErr>>>,
            _Not<is_constructible<unexpected<_Err>, const expected<_Up, _OtherErr>&>>,
            _Not<is_constructible<unexpected<_Err>, const expected<_Up, _OtherErr>>>>;

public:
  using value_type      = _Tp;
  using error_type      = _Err;
  using unexpected_type = unexpected<_Err>;

  template <class _Up>
  using rebind = expected<_Up, error_type>;

  // [expected.void.ctor], constructors
  _LIBCPP_HIDE_FROM_ABI constexpr expected() noexcept : __has_val_(true) {}

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected&) = delete;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected&)
    requires(is_copy_constructible_v<_Err> && is_trivially_copy_constructible_v<_Err>)
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(const expected& __rhs)
    noexcept(is_nothrow_copy_constructible_v<_Err>) // strengthened
    requires(is_copy_constructible_v<_Err> && !is_trivially_copy_constructible_v<_Err>)
      : __has_val_(__rhs.__has_val_) {
    if (!__rhs.__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), __rhs.__union_.__unex_);
    }
  }

  _LIBCPP_HIDE_FROM_ABI constexpr expected(expected&&)
    requires(is_move_constructible_v<_Err> && is_trivially_move_constructible_v<_Err>)
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr expected(expected&& __rhs)
    noexcept(is_nothrow_move_constructible_v<_Err>)
    requires(is_move_constructible_v<_Err> && !is_trivially_move_constructible_v<_Err>)
      : __has_val_(__rhs.__has_val_) {
    if (!__rhs.__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), std::move(__rhs.__union_.__unex_));
    }
  }

  template <class _Up, class _OtherErr>
    requires __can_convert<_Up, _OtherErr, const _OtherErr&>::value
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<const _OtherErr&, _Err>)
  expected(const expected<_Up, _OtherErr>& __rhs)
    noexcept(is_nothrow_constructible_v<_Err, const _OtherErr&>) // strengthened
      : __has_val_(__rhs.__has_val_) {
    if (!__rhs.__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), __rhs.__union_.__unex_);
    }
  }

  template <class _Up, class _OtherErr>
    requires __can_convert<_Up, _OtherErr, _OtherErr>::value
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<_OtherErr, _Err>)
  expected(expected<_Up, _OtherErr>&& __rhs)
    noexcept(is_nothrow_constructible_v<_Err, _OtherErr>) // strengthened
      : __has_val_(__rhs.__has_val_) {
    if (!__rhs.__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), std::move(__rhs.__union_.__unex_));
    }
  }

  template <class _OtherErr>
    requires is_constructible_v<_Err, const _OtherErr&>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<const _OtherErr&, _Err>)
  expected(const unexpected<_OtherErr>& __unex)
    noexcept(is_nothrow_constructible_v<_Err, const _OtherErr&>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), __unex.error());
  }

  template <class _OtherErr>
    requires is_constructible_v<_Err, _OtherErr>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit(!is_convertible_v<_OtherErr, _Err>)
  expected(unexpected<_OtherErr>&& __unex)
    noexcept(is_nothrow_constructible_v<_Err, _OtherErr>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), std::move(__unex.error()));
  }

  _LIBCPP_HIDE_FROM_ABI constexpr explicit expected(in_place_t) noexcept : __has_val_(true) {}

  template <class... _Args>
    requires is_constructible_v<_Err, _Args...>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit expected(unexpect_t, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Err, _Args...>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), std::forward<_Args>(__args)...);
  }

  template <class _Up, class... _Args>
    requires is_constructible_v< _Err, initializer_list<_Up>&, _Args... >
  _LIBCPP_HIDE_FROM_ABI constexpr explicit expected(unexpect_t, initializer_list<_Up> __il, _Args&&... __args)
    noexcept(is_nothrow_constructible_v<_Err, initializer_list<_Up>&, _Args...>) // strengthened
      : __has_val_(false) {
    std::construct_at(std::addressof(__union_.__unex_), __il, std::forward<_Args>(__args)...);
  }

  // [expected.void.dtor], destructor

  _LIBCPP_HIDE_FROM_ABI constexpr ~expected()
    requires is_trivially_destructible_v<_Err>
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr ~expected()
    requires(!is_trivially_destructible_v<_Err>)
  {
    if (!__has_val_) {
      std::destroy_at(std::addressof(__union_.__unex_));
    }
  }

  // [expected.void.assign], assignment

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const expected&) = delete;

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const expected& __rhs)
    noexcept(is_nothrow_copy_assignable_v<_Err> && is_nothrow_copy_constructible_v<_Err>) // strengthened
    requires(is_copy_assignable_v<_Err> && is_copy_constructible_v<_Err>)
  {
    if (__has_val_) {
      if (!__rhs.__has_val_) {
        std::construct_at(std::addressof(__union_.__unex_), __rhs.__union_.__unex_);
        __has_val_ = false;
      }
    } else {
      if (__rhs.__has_val_) {
        std::destroy_at(std::addressof(__union_.__unex_));
        __has_val_ = true;
      } else {
        __union_.__unex_ = __rhs.__union_.__unex_;
      }
    }
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(expected&&) = delete;

  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(expected&& __rhs)
    noexcept(is_nothrow_move_assignable_v<_Err> &&
             is_nothrow_move_constructible_v<_Err>)
    requires(is_move_assignable_v<_Err> &&
             is_move_constructible_v<_Err>)
  {
    if (__has_val_) {
      if (!__rhs.__has_val_) {
        std::construct_at(std::addressof(__union_.__unex_), std::move(__rhs.__union_.__unex_));
        __has_val_ = false;
      }
    } else {
      if (__rhs.__has_val_) {
        std::destroy_at(std::addressof(__union_.__unex_));
        __has_val_ = true;
      } else {
        __union_.__unex_ = std::move(__rhs.__union_.__unex_);
      }
    }
    return *this;
  }

  template <class _OtherErr>
    requires(is_constructible_v<_Err, const _OtherErr&> && is_assignable_v<_Err&, const _OtherErr&>)
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(const unexpected<_OtherErr>& __un) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), __un.error());
      __has_val_ = false;
    } else {
      __union_.__unex_ = __un.error();
    }
    return *this;
  }

  template <class _OtherErr>
    requires(is_constructible_v<_Err, _OtherErr> && is_assignable_v<_Err&, _OtherErr>)
  _LIBCPP_HIDE_FROM_ABI constexpr expected& operator=(unexpected<_OtherErr>&& __un) {
    if (__has_val_) {
      std::construct_at(std::addressof(__union_.__unex_), std::move(__un.error()));
      __has_val_ = false;
    } else {
      __union_.__unex_ = std::move(__un.error());
    }
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void emplace() noexcept {
    if (!__has_val_) {
      std::destroy_at(std::addressof(__union_.__unex_));
      __has_val_ = true;
    }
  }

  // [expected.void.swap], swap
  _LIBCPP_HIDE_FROM_ABI constexpr void swap(expected& __rhs)
    noexcept(is_nothrow_move_constructible_v<_Err> && is_nothrow_swappable_v<_Err>)
    requires(is_swappable_v<_Err> && is_move_constructible_v<_Err>)
  {
    auto __swap_val_unex_impl = [&](expected& __with_val, expected& __with_err) {
      std::construct_at(std::addressof(__with_val.__union_.__unex_), std::move(__with_err.__union_.__unex_));
      std::destroy_at(std::addressof(__with_err.__union_.__unex_));
      __with_val.__has_val_ = false;
      __with_err.__has_val_ = true;
    };

    if (__has_val_) {
      if (!__rhs.__has_val_) {
        __swap_val_unex_impl(*this, __rhs);
      }
    } else {
      if (__rhs.__has_val_) {
        __swap_val_unex_impl(__rhs, *this);
      } else {
        using std::swap;
        swap(__union_.__unex_, __rhs.__union_.__unex_);
      }
    }
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr void swap(expected& __x, expected& __y)
    noexcept(noexcept(__x.swap(__y)))
    requires requires { __x.swap(__y); }
  {
    __x.swap(__y);
  }

  // [expected.void.obs], observers
  _LIBCPP_HIDE_FROM_ABI constexpr explicit operator bool() const noexcept { return __has_val_; }

  _LIBCPP_HIDE_FROM_ABI constexpr bool has_value() const noexcept { return __has_val_; }

  _LIBCPP_HIDE_FROM_ABI constexpr void operator*() const noexcept {
    _LIBCPP_ASSERT(__has_val_, "expected::operator* requires the expected to contain a value");
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void value() const& {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(__union_.__unex_);
    }
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void value() && {
    if (!__has_val_) {
      __expected::__throw_bad_expected_access<_Err>(std::move(__union_.__unex_));
    }
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Err& error() const& noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return __union_.__unex_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Err& error() & noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return __union_.__unex_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr const _Err&& error() const&& noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return std::move(__union_.__unex_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _Err&& error() && noexcept {
    _LIBCPP_ASSERT(!__has_val_, "expected::error requires the expected to contain an error");
    return std::move(__union_.__unex_);
  }

  // [expected.void.eq], equality operators
  template <class _T2, class _E2>
    requires is_void_v<_T2>
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const expected& __x, const expected<_T2, _E2>& __y) {
    if (__x.__has_val_ != __y.__has_val_) {
      return false;
    } else {
      return __x.__has_val_ || static_cast<bool>(__x.__union_.__unex_ == __y.__union_.__unex_);
    }
  }

  template <class _E2>
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const expected& __x, const unexpected<_E2>& __y) {
    return !__x.__has_val_ && static_cast<bool>(__x.__union_.__unex_ == __y.error());
  }

private:
  struct __empty_t {};
  // use named union because [[no_unique_address]] cannot be applied to an unnamed union
  _LIBCPP_NO_UNIQUE_ADDRESS union __union_t {
    _LIBCPP_HIDE_FROM_ABI constexpr __union_t() : __empty_() {}

    _LIBCPP_HIDE_FROM_ABI constexpr ~__union_t()
      requires(is_trivially_destructible_v<_Err>)
    = default;

    // the expected's destructor handles this
    _LIBCPP_HIDE_FROM_ABI constexpr ~__union_t()
      requires(!is_trivially_destructible_v<_Err>)
    {}

    _LIBCPP_NO_UNIQUE_ADDRESS __empty_t __empty_;
    _LIBCPP_NO_UNIQUE_ADDRESS _Err __unex_;
  } __union_;

  bool __has_val_;
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER >= 23

#endif // _LIBCPP___EXPECTED_EXPECTED_H
