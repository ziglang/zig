/*===---- __clang_openmp_math.h - OpenMP target math support ---------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#if defined(__NVPTX__) && defined(_OPENMP)
/// TODO:
/// We are currently reusing the functionality of the Clang-CUDA code path
/// as an alternative to the host declarations provided by math.h and cmath.
/// This is suboptimal.
///
/// We should instead declare the device functions in a similar way, e.g.,
/// through OpenMP 5.0 variants, and afterwards populate the module with the
/// host declarations by unconditionally including the host math.h or cmath,
/// respectively. This is actually what the Clang-CUDA code path does, using
/// __device__ instead of variants to avoid redeclarations and get the desired
/// overload resolution.

#define __CUDA__

#if defined(__cplusplus)
  #include <__clang_cuda_cmath.h>
#endif

#undef __CUDA__

/// Magic macro for stopping the math.h/cmath host header from being included.
#define __CLANG_NO_HOST_MATH__

#endif

