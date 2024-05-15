// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_EXPERIMENTAL___SIMD_REFERENCE_H
#define _LIBCPP_EXPERIMENTAL___SIMD_REFERENCE_H

#include <__type_traits/is_assignable.h>
#include <__type_traits/is_same.h>
#include <__utility/forward.h>
#include <cstddef>
#include <experimental/__config>
#include <experimental/__simd/utility.h>

#if _LIBCPP_STD_VER >= 17 && defined(_LIBCPP_ENABLE_EXPERIMENTAL)

_LIBCPP_BEGIN_NAMESPACE_EXPERIMENTAL
inline namespace parallelism_v2 {
template <class _Tp, class _Storage, class _Vp>
class __simd_reference {
  template <class, class>
  friend class simd;
  template <class, class>
  friend class simd_mask;

  _Storage& __s_;
  size_t __idx_;

  _LIBCPP_HIDE_FROM_ABI __simd_reference(_Storage& __s, size_t __idx) : __s_(__s), __idx_(__idx) {}

  _LIBCPP_HIDE_FROM_ABI _Vp __get() const noexcept { return __s_.__get(__idx_); }

  _LIBCPP_HIDE_FROM_ABI void __set(_Vp __v) {
    if constexpr (is_same_v<_Vp, bool>)
      __s_.__set(__idx_, experimental::__set_all_bits<_Tp>(__v));
    else
      __s_.__set(__idx_, __v);
  }

public:
  using value_type = _Vp;

  __simd_reference()                        = delete;
  __simd_reference(const __simd_reference&) = delete;

  _LIBCPP_HIDE_FROM_ABI operator value_type() const noexcept { return __get(); }

  template <class _Up, enable_if_t<is_assignable_v<value_type&, _Up&&>, int> = 0>
  _LIBCPP_HIDE_FROM_ABI __simd_reference operator=(_Up&& __v) && noexcept {
    __set(static_cast<value_type>(std::forward<_Up>(__v)));
    return {__s_, __idx_};
  }
};

} // namespace parallelism_v2
_LIBCPP_END_NAMESPACE_EXPERIMENTAL

#endif // _LIBCPP_STD_VER >= 17 && defined(_LIBCPP_ENABLE_EXPERIMENTAL)
#endif // _LIBCPP_EXPERIMENTAL___SIMD_REFERENCE_H
