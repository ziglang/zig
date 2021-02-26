//===-- sanitizer_ptrauth.h -------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef SANITIZER_PTRAUTH_H
#define SANITIZER_PTRAUTH_H

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#else
// Copied from <ptrauth.h>
#define ptrauth_strip(__value, __key) __value
#define ptrauth_auth_data(__value, __old_key, __old_data) __value
#define ptrauth_string_discriminator(__string) ((int)0)
#endif

#endif // SANITIZER_PTRAUTH_H
