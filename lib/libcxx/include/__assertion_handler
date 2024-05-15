// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ASSERTION_HANDLER
#define _LIBCPP___ASSERTION_HANDLER

#include <__config>
#include <__verbose_abort>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_HARDENING_MODE == _LIBCPP_HARDENING_MODE_DEBUG

#  define _LIBCPP_ASSERTION_HANDLER(message) _LIBCPP_VERBOSE_ABORT("%s", message)

#else

// TODO(hardening): use `__builtin_verbose_trap(message)` once that becomes available.
#  define _LIBCPP_ASSERTION_HANDLER(message) ((void)message, __builtin_trap())

#endif // _LIBCPP_HARDENING_MODE == _LIBCPP_HARDENING_MODE_DEBUG

#endif // _LIBCPP___ASSERTION_HANDLER
