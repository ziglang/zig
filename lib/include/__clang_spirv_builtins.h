/*===---- spirv_builtin_vars.h - SPIR-V built-in ---------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __SPIRV_BUILTIN_VARS_H
#define __SPIRV_BUILTIN_VARS_H

#if __cplusplus >= 201103L
#define __SPIRV_NOEXCEPT noexcept
#else
#define __SPIRV_NOEXCEPT
#endif

#pragma push_macro("__size_t")
#pragma push_macro("__uint32_t")
#pragma push_macro("__uint64_t")
#define __size_t __SIZE_TYPE__
#define __uint32_t __UINT32_TYPE__

#define __SPIRV_overloadable __attribute__((overloadable))
#define __SPIRV_convergent __attribute__((convergent))
#define __SPIRV_inline __attribute__((always_inline))

#define __global __attribute__((opencl_global))
#define __local __attribute__((opencl_local))
#define __private __attribute__((opencl_private))
#define __constant __attribute__((opencl_constant))
#ifdef __SYCL_DEVICE_ONLY__
#define __generic
#else
#define __generic __attribute__((opencl_generic))
#endif

// Check if SPIR-V builtins are supported.
// As the translator doesn't use the LLVM intrinsics (which would be emitted if
// we use the SPIR-V builtins) we can't rely on the SPIRV32/SPIRV64 etc macros
// to establish if we can use the builtin alias. We disable builtin altogether
// if we do not intent to use the backend. So instead of use target macros, rely
// on a __has_builtin test.
#if (__has_builtin(__builtin_spirv_num_workgroups))
#define __SPIRV_BUILTIN_ALIAS(builtin)                                         \
  __attribute__((clang_builtin_alias(builtin)))
#else
#define __SPIRV_BUILTIN_ALIAS(builtin)
#endif

// Builtin IDs and sizes

extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_num_workgroups) __size_t
    __spirv_NumWorkgroups(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_workgroup_size) __size_t
    __spirv_WorkgroupSize(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_workgroup_id) __size_t
    __spirv_WorkgroupId(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_local_invocation_id) __size_t
    __spirv_LocalInvocationId(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_global_invocation_id) __size_t
    __spirv_GlobalInvocationId(int);

extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_global_size) __size_t
    __spirv_GlobalSize(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_global_offset) __size_t
    __spirv_GlobalOffset(int);
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_subgroup_size) __uint32_t
    __spirv_SubgroupSize();
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_subgroup_max_size) __uint32_t
    __spirv_SubgroupMaxSize();
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_num_subgroups) __uint32_t
    __spirv_NumSubgroups();
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_subgroup_id) __uint32_t
    __spirv_SubgroupId();
extern __SPIRV_BUILTIN_ALIAS(__builtin_spirv_subgroup_local_invocation_id)
    __uint32_t __spirv_SubgroupLocalInvocationId();

// OpGenericCastToPtrExplicit

extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__global void *__spirv_GenericCastToPtrExplicit_ToGlobal(__generic void *,
                                                         int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__global const void *
__spirv_GenericCastToPtrExplicit_ToGlobal(__generic const void *,
                                          int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__global volatile void *
__spirv_GenericCastToPtrExplicit_ToGlobal(__generic volatile void *,
                                          int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__global const volatile void *
__spirv_GenericCastToPtrExplicit_ToGlobal(__generic const volatile void *,
                                          int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__local void *__spirv_GenericCastToPtrExplicit_ToLocal(__generic void *,
                                                       int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__local const void *
__spirv_GenericCastToPtrExplicit_ToLocal(__generic const void *,
                                         int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__local volatile void *
__spirv_GenericCastToPtrExplicit_ToLocal(__generic volatile void *,
                                         int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__local const volatile void *
__spirv_GenericCastToPtrExplicit_ToLocal(__generic const volatile void *,
                                         int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__private void *
__spirv_GenericCastToPtrExplicit_ToPrivate(__generic void *,
                                           int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__private const void *
__spirv_GenericCastToPtrExplicit_ToPrivate(__generic const void *,
                                           int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__private volatile void *
__spirv_GenericCastToPtrExplicit_ToPrivate(__generic volatile void *,
                                           int) __SPIRV_NOEXCEPT;
extern __SPIRV_overloadable
__SPIRV_BUILTIN_ALIAS(__builtin_spirv_generic_cast_to_ptr_explicit)
__private const volatile void *
__spirv_GenericCastToPtrExplicit_ToPrivate(__generic const volatile void *,
                                           int) __SPIRV_NOEXCEPT;

// OpGenericCastToPtr

static __SPIRV_overloadable __SPIRV_inline __global void *
__spirv_GenericCastToPtr_ToGlobal(__generic void *p, int) __SPIRV_NOEXCEPT {
  return (__global void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __global const void *
__spirv_GenericCastToPtr_ToGlobal(__generic const void *p,
                                  int) __SPIRV_NOEXCEPT {
  return (__global const void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __global volatile void *
__spirv_GenericCastToPtr_ToGlobal(__generic volatile void *p,
                                  int) __SPIRV_NOEXCEPT {
  return (__global volatile void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __global const volatile void *
__spirv_GenericCastToPtr_ToGlobal(__generic const volatile void *p,
                                  int) __SPIRV_NOEXCEPT {
  return (__global const volatile void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __local void *
__spirv_GenericCastToPtr_ToLocal(__generic void *p, int) __SPIRV_NOEXCEPT {
  return (__local void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __local const void *
__spirv_GenericCastToPtr_ToLocal(__generic const void *p,
                                 int) __SPIRV_NOEXCEPT {
  return (__local const void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __local volatile void *
__spirv_GenericCastToPtr_ToLocal(__generic volatile void *p,
                                 int) __SPIRV_NOEXCEPT {
  return (__local volatile void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __local const volatile void *
__spirv_GenericCastToPtr_ToLocal(__generic const volatile void *p,
                                 int) __SPIRV_NOEXCEPT {
  return (__local const volatile void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __private void *
__spirv_GenericCastToPtr_ToPrivate(__generic void *p, int) __SPIRV_NOEXCEPT {
  return (__private void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __private const void *
__spirv_GenericCastToPtr_ToPrivate(__generic const void *p,
                                   int) __SPIRV_NOEXCEPT {
  return (__private const void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __private volatile void *
__spirv_GenericCastToPtr_ToPrivate(__generic volatile void *p,
                                   int) __SPIRV_NOEXCEPT {
  return (__private volatile void *)p;
}
static __SPIRV_overloadable __SPIRV_inline __private const volatile void *
__spirv_GenericCastToPtr_ToPrivate(__generic const volatile void *p,
                                   int) __SPIRV_NOEXCEPT {
  return (__private const volatile void *)p;
}

#pragma pop_macro("__size_t")
#pragma pop_macro("__uint32_t")
#pragma pop_macro("__uint64_t")

#undef __SPIRV_overloadable
#undef __SPIRV_convergent
#undef __SPIRV_inline

#undef __global
#undef __local
#undef __constant
#undef __generic

#undef __SPIRV_BUILTIN_ALIAS
#undef __SPIRV_NOEXCEPT

#endif /* __SPIRV_BUILTIN_VARS_H */
