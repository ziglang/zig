// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_POINTER_TRAITS_H
#define _LIBCPP___MEMORY_POINTER_TRAITS_H

#include <__config>
#include <__cstddef/ptrdiff_t.h>
#include <__memory/addressof.h>
#include <__type_traits/conditional.h>
#include <__type_traits/conjunction.h>
#include <__type_traits/decay.h>
#include <__type_traits/detected_or.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_class.h>
#include <__type_traits/is_function.h>
#include <__type_traits/is_void.h>
#include <__type_traits/nat.h>
#include <__type_traits/void_t.h>
#include <__utility/declval.h>
#include <__utility/forward.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Ptr>
struct __pointer_traits_element_type_impl {};

template <template <class, class...> class _Sp, class _Tp, class... _Args>
struct __pointer_traits_element_type_impl<_Sp<_Tp, _Args...> > {
  using type _LIBCPP_NODEBUG = _Tp;
};

template <class _Ptr, class = void>
struct __pointer_traits_element_type : __pointer_traits_element_type_impl<_Ptr> {};

template <class _Ptr>
struct __pointer_traits_element_type<_Ptr, __void_t<typename _Ptr::element_type> > {
  using type _LIBCPP_NODEBUG = typename _Ptr::element_type;
};

template <class _Tp, class _Up>
struct __pointer_traits_rebind_impl {
  static_assert(false, "Cannot rebind pointer; did you forget to add a rebind member to your pointer?");
};

template <template <class, class...> class _Sp, class _Tp, class... _Args, class _Up>
struct __pointer_traits_rebind_impl<_Sp<_Tp, _Args...>, _Up> {
  using type _LIBCPP_NODEBUG = _Sp<_Up, _Args...>;
};

template <class _Tp, class _Up, class = void>
struct __pointer_traits_rebind : __pointer_traits_rebind_impl<_Tp, _Up> {};

template <class _Tp, class _Up>
struct __pointer_traits_rebind<_Tp, _Up, __void_t<typename _Tp::template rebind<_Up> > > {
#ifndef _LIBCPP_CXX03_LANG
  using type _LIBCPP_NODEBUG = typename _Tp::template rebind<_Up>;
#else
  using type _LIBCPP_NODEBUG = typename _Tp::template rebind<_Up>::other;
#endif
};

template <class _Tp>
using __difference_type_member _LIBCPP_NODEBUG = typename _Tp::difference_type;

template <class _Ptr, class = void>
struct __pointer_traits_impl {};

template <class _Ptr>
struct __pointer_traits_impl<_Ptr, __void_t<typename __pointer_traits_element_type<_Ptr>::type> > {
  typedef _Ptr pointer;
  typedef typename __pointer_traits_element_type<pointer>::type element_type;
  using difference_type = __detected_or_t<ptrdiff_t, __difference_type_member, pointer>;

#ifndef _LIBCPP_CXX03_LANG
  template <class _Up>
  using rebind = typename __pointer_traits_rebind<pointer, _Up>::type;
#else
  template <class _Up>
  struct rebind {
    typedef typename __pointer_traits_rebind<pointer, _Up>::type other;
  };
#endif // _LIBCPP_CXX03_LANG

public:
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 static pointer
  pointer_to(__conditional_t<is_void<element_type>::value, __nat, element_type>& __r) {
    return pointer::pointer_to(__r);
  }
};

template <class _Ptr>
struct pointer_traits : __pointer_traits_impl<_Ptr> {};

template <class _Tp>
struct pointer_traits<_Tp*> {
  typedef _Tp* pointer;
  typedef _Tp element_type;
  typedef ptrdiff_t difference_type;

#ifndef _LIBCPP_CXX03_LANG
  template <class _Up>
  using rebind = _Up*;
#else
  template <class _Up>
  struct rebind {
    typedef _Up* other;
  };
#endif

public:
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 static pointer
  pointer_to(__conditional_t<is_void<element_type>::value, __nat, element_type>& __r) _NOEXCEPT {
    return std::addressof(__r);
  }
};

#ifndef _LIBCPP_CXX03_LANG
template <class _From, class _To>
using __rebind_pointer_t _LIBCPP_NODEBUG = typename pointer_traits<_From>::template rebind<_To>;
#else
template <class _From, class _To>
using __rebind_pointer_t _LIBCPP_NODEBUG = typename pointer_traits<_From>::template rebind<_To>::other;
#endif

// to_address

template <class _Pointer, class = void>
struct __to_address_helper;

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR _Tp* __to_address(_Tp* __p) _NOEXCEPT {
  static_assert(!is_function<_Tp>::value, "_Tp is a function type");
  return __p;
}

template <class _Pointer, class = void>
struct _HasToAddress : false_type {};

template <class _Pointer>
struct _HasToAddress<_Pointer, decltype((void)pointer_traits<_Pointer>::to_address(std::declval<const _Pointer&>())) >
    : true_type {};

template <class _Pointer, class = void>
struct _HasArrow : false_type {};

template <class _Pointer>
struct _HasArrow<_Pointer, decltype((void)std::declval<const _Pointer&>().operator->()) > : true_type {};

template <class _Pointer>
struct _IsFancyPointer {
  static const bool value = _HasArrow<_Pointer>::value || _HasToAddress<_Pointer>::value;
};

// enable_if is needed here to avoid instantiating checks for fancy pointers on raw pointers
template <class _Pointer, __enable_if_t< _And<is_class<_Pointer>, _IsFancyPointer<_Pointer> >::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI
_LIBCPP_CONSTEXPR __decay_t<decltype(__to_address_helper<_Pointer>::__call(std::declval<const _Pointer&>()))>
__to_address(const _Pointer& __p) _NOEXCEPT {
  return __to_address_helper<_Pointer>::__call(__p);
}

template <class _Pointer, class>
struct __to_address_helper {
  _LIBCPP_HIDE_FROM_ABI
  _LIBCPP_CONSTEXPR static decltype(std::__to_address(std::declval<const _Pointer&>().operator->()))
  __call(const _Pointer& __p) _NOEXCEPT {
    return std::__to_address(__p.operator->());
  }
};

template <class _Pointer>
struct __to_address_helper<_Pointer,
                           decltype((void)pointer_traits<_Pointer>::to_address(std::declval<const _Pointer&>()))> {
  _LIBCPP_HIDE_FROM_ABI
  _LIBCPP_CONSTEXPR static decltype(pointer_traits<_Pointer>::to_address(std::declval<const _Pointer&>()))
  __call(const _Pointer& __p) _NOEXCEPT {
    return pointer_traits<_Pointer>::to_address(__p);
  }
};

#if _LIBCPP_STD_VER >= 20
template <class _Tp>
inline _LIBCPP_HIDE_FROM_ABI constexpr auto to_address(_Tp* __p) noexcept {
  return std::__to_address(__p);
}

template <class _Pointer>
inline _LIBCPP_HIDE_FROM_ABI constexpr auto to_address(const _Pointer& __p) noexcept
    -> decltype(std::__to_address(__p)) {
  return std::__to_address(__p);
}
#endif

#if _LIBCPP_STD_VER >= 23

template <class _Tp>
struct __pointer_of {};

template <class _Tp>
concept __has_pointer_member = requires { typename _Tp::pointer; };

template <class _Tp>
concept __has_element_type_member = requires { typename _Tp::element_type; };

template <class _Tp>
  requires __has_pointer_member<_Tp>
struct __pointer_of<_Tp> {
  using type _LIBCPP_NODEBUG = typename _Tp::pointer;
};

template <class _Tp>
  requires(!__has_pointer_member<_Tp> && __has_element_type_member<_Tp>)
struct __pointer_of<_Tp> {
  using type _LIBCPP_NODEBUG = typename _Tp::element_type*;
};

template <class _Tp>
  requires(!__has_pointer_member<_Tp> && !__has_element_type_member<_Tp> &&
           __has_element_type_member<pointer_traits<_Tp>>)
struct __pointer_of<_Tp> {
  using type _LIBCPP_NODEBUG = typename pointer_traits<_Tp>::element_type*;
};

template <typename _Tp>
using __pointer_of_t _LIBCPP_NODEBUG = typename __pointer_of<_Tp>::type;

template <typename _Tp, typename _Up>
using __pointer_of_or_t _LIBCPP_NODEBUG = __detected_or_t<_Up, __pointer_of_t, _Tp>;

template <class _Smart>
concept __resettable_smart_pointer = requires(_Smart __s) { __s.reset(); };

template <class _Smart, class _Pointer, class... _Args>
concept __resettable_smart_pointer_with_args = requires(_Smart __s, _Pointer __p, _Args... __args) {
  __s.reset(static_cast<__pointer_of_or_t<_Smart, _Pointer>>(__p), std::forward<_Args>(__args)...);
};

#endif

// This function ensures safe conversions between fancy pointers at compile-time, where we avoid casts from/to
// `__void_pointer` by obtaining the underlying raw pointer from the fancy pointer using `std::to_address`,
// then dereferencing it to retrieve the pointed-to object, and finally constructing the target fancy pointer
// to that object using the `std::pointer_traits<>::pinter_to` function.
template <class _PtrTo, class _PtrFrom>
_LIBCPP_CONSTEXPR_SINCE_CXX20 _LIBCPP_HIDE_FROM_ABI _PtrTo __static_fancy_pointer_cast(const _PtrFrom& __p) {
  using __ptr_traits   = pointer_traits<_PtrTo>;
  using __element_type = typename __ptr_traits::element_type;
  return __p ? __ptr_traits::pointer_to(*static_cast<__element_type*>(std::addressof(*__p)))
             : static_cast<_PtrTo>(nullptr);
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___MEMORY_POINTER_TRAITS_H
