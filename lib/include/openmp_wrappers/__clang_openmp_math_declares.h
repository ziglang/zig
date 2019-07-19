/*===---- __clang_openmp_math_declares.h - OpenMP math declares ------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __CLANG_OPENMP_MATH_DECLARES_H__
#define __CLANG_OPENMP_MATH_DECLARES_H__

#ifndef _OPENMP
#error "This file is for OpenMP compilation only."
#endif

#if defined(__NVPTX__) && defined(_OPENMP)

#define __CUDA__

#if defined(__cplusplus)
  #include <__clang_cuda_math_forward_declares.h>
#endif

/// Include declarations for libdevice functions.
#include <__clang_cuda_libdevice_declares.h>
/// Provide definitions for these functions.
#include <__clang_cuda_device_functions.h>

#undef __CUDA__

#endif
#endif
