//===-- sanitizer_type_traits.h ---------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Implements a subset of C++ type traits. This is so we can avoid depending
// on system C++ headers.
//
//===----------------------------------------------------------------------===//
#ifndef SANITIZER_TYPE_TRAITS_H
#define SANITIZER_TYPE_TRAITS_H

namespace __sanitizer {

struct true_type {
  static const bool value = true;
};

struct false_type {
  static const bool value = false;
};

// is_same<T, U>
//
// Type trait to compare if types are the same.
// E.g.
//
// ```
// is_same<int,int>::value - True
// is_same<int,char>::value - False
// ```
template <typename T, typename U>
struct is_same : public false_type {};

template <typename T>
struct is_same<T, T> : public true_type {};

// conditional<B, T, F>
//
// Defines type as T if B is true or as F otherwise.
// E.g. the following is true
//
// ```
// is_same<int, conditional<true, int, double>::type>::value
// is_same<double, conditional<false, int, double>::type>::value
// ```
template <bool B, class T, class F>
struct conditional {
  using type = T;
};

template <class T, class F>
struct conditional<false, T, F> {
  using type = F;
};

}  // namespace __sanitizer

#endif
