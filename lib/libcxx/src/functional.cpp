//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <functional>

_LIBCPP_BEGIN_NAMESPACE_STD

bad_function_call::~bad_function_call() noexcept {}

const char* bad_function_call::what() const noexcept { return "std::bad_function_call"; }

size_t __hash_memory(_LIBCPP_NOESCAPE const void* ptr, size_t size) noexcept {
  return __murmur2_or_cityhash<size_t>()(ptr, size);
}

_LIBCPP_END_NAMESPACE_STD
