//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_DATASIZEOF_H
#define _LIBCPP___TYPE_TRAITS_DATASIZEOF_H

#include <__config>
#include <__type_traits/is_class.h>
#include <__type_traits/is_final.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

// This trait provides the size of a type excluding any tail padding.
//
// It is useful in contexts where performing an operation using the full size of the class (including padding) may
// have unintended side effects, such as overwriting a derived class' member when writing the tail padding of a class
// through a pointer-to-base.

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
struct __libcpp_datasizeof {
#if __has_cpp_attribute(__no_unique_address__)
  template <class = char>
  struct _FirstPaddingByte {
    [[__no_unique_address__]] _Tp __v_;
    char __first_padding_byte_;
  };
#else
  template <bool = __libcpp_is_final<_Tp>::value || !is_class<_Tp>::value>
  struct _FirstPaddingByte : _Tp {
    char __first_padding_byte_;
  };

  template <>
  struct _FirstPaddingByte<true> {
    _Tp __v_;
    char __first_padding_byte_;
  };
#endif

  static const size_t value = offsetof(_FirstPaddingByte<>, __first_padding_byte_);
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_DATASIZEOF_H
