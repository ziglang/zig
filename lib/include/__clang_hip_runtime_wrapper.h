/*===---- __clang_hip_runtime_wrapper.h - HIP runtime support ---------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

/*
 * WARNING: This header is intended to be directly -include'd by
 * the compiler and is not supposed to be included by users.
 *
 */

#ifndef __CLANG_HIP_RUNTIME_WRAPPER_H__
#define __CLANG_HIP_RUNTIME_WRAPPER_H__

#if __HIP__

#include <cmath>
#include <cstdlib>
#include <stdlib.h>

#define __host__ __attribute__((host))
#define __device__ __attribute__((device))
#define __global__ __attribute__((global))
#define __shared__ __attribute__((shared))
#define __constant__ __attribute__((constant))

#if !defined(__cplusplus) || __cplusplus < 201103L
  #define nullptr NULL;
#endif

#if __HIP_ENABLE_DEVICE_MALLOC__
extern "C" __device__ void *__hip_malloc(size_t __size);
extern "C" __device__ void *__hip_free(void *__ptr);
static inline __device__ void *malloc(size_t __size) {
  return __hip_malloc(__size);
}
static inline __device__ void *free(void *__ptr) { return __hip_free(__ptr); }
#else
static inline __device__ void *malloc(size_t __size) {
  __builtin_trap();
  return nullptr;
}
static inline __device__ void *free(void *__ptr) {
  __builtin_trap();
  return nullptr;
}
#endif

#include <__clang_hip_libdevice_declares.h>
#include <__clang_hip_math.h>

#if !_OPENMP || __HIP_ENABLE_CUDA_WRAPPER_FOR_OPENMP__
#include <__clang_cuda_math_forward_declares.h>
#include <__clang_hip_cmath.h>
#include <__clang_cuda_complex_builtins.h>

#include <algorithm>
#include <complex>
#include <new>
#endif // !_OPENMP || __HIP_ENABLE_CUDA_WRAPPER_FOR_OPENMP__

#define __CLANG_HIP_RUNTIME_WRAPPER_INCLUDED__ 1

#endif // __HIP__
#endif // __CLANG_HIP_RUNTIME_WRAPPER_H__
