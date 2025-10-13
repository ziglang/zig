// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___CONFIGURATION_ABI_H
#define _LIBCPP___CONFIGURATION_ABI_H

/* zig patch: instead of including __config_site, zig adds -D flags when compiling */
#include <__configuration/compiler.h>
#include <__configuration/platform.h>

#ifndef _LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER
#  pragma GCC system_header
#endif

// FIXME: ABI detection should be done via compiler builtin macros. This
// is just a placeholder until Clang implements such macros. For now assume
// that Windows compilers pretending to be MSVC++ target the Microsoft ABI,
// and allow the user to explicitly specify the ABI to handle cases where this
// heuristic falls short.
#if _LIBCPP_ABI_FORCE_ITANIUM && _LIBCPP_ABI_FORCE_MICROSOFT
#  error "Only one of _LIBCPP_ABI_FORCE_ITANIUM and _LIBCPP_ABI_FORCE_MICROSOFT can be true"
#elif _LIBCPP_ABI_FORCE_ITANIUM
#  define _LIBCPP_ABI_ITANIUM
#elif _LIBCPP_ABI_FORCE_MICROSOFT
#  define _LIBCPP_ABI_MICROSOFT
#else
#  if defined(_WIN32) && defined(_MSC_VER)
#    define _LIBCPP_ABI_MICROSOFT
#  else
#    define _LIBCPP_ABI_ITANIUM
#  endif
#endif

#if _LIBCPP_ABI_VERSION >= 2
// TODO: Move the description of the remaining ABI flags to ABIGuarantees.rst or remove them.

// Override the default return value of exception::what() for bad_function_call::what()
// with a string that is specific to bad_function_call (see http://wg21.link/LWG2233).
// This is an ABI break on platforms that sign and authenticate vtable function pointers
// because it changes the mangling of the virtual function located in the vtable, which
// changes how it gets signed.
#  define _LIBCPP_ABI_BAD_FUNCTION_CALL_GOOD_WHAT_MESSAGE
// According to the Standard, `bitset::operator[] const` returns bool
#  define _LIBCPP_ABI_BITSET_VECTOR_BOOL_CONST_SUBSCRIPT_RETURN_BOOL

// In LLVM 20, we've changed to take these ABI breaks unconditionally. These flags only exist in case someone is running
// into the static_asserts we added to catch the ABI break and don't care that it is one.
// TODO(LLVM 22): Remove these flags
#  define _LIBCPP_ABI_LIST_REMOVE_NODE_POINTER_UB
#  define _LIBCPP_ABI_TREE_REMOVE_NODE_POINTER_UB
#  define _LIBCPP_ABI_FIX_UNORDERED_NODE_POINTER_UB
#  define _LIBCPP_ABI_FORWARD_LIST_REMOVE_NODE_POINTER_UB

// These flags are documented in ABIGuarantees.rst
#  define _LIBCPP_ABI_ALTERNATE_STRING_LAYOUT
#  define _LIBCPP_ABI_DO_NOT_EXPORT_BASIC_STRING_COMMON
#  define _LIBCPP_ABI_DO_NOT_EXPORT_VECTOR_BASE_COMMON
#  define _LIBCPP_ABI_DO_NOT_EXPORT_TO_CHARS_BASE_10
#  define _LIBCPP_ABI_ENABLE_SHARED_PTR_TRIVIAL_ABI
#  define _LIBCPP_ABI_ENABLE_UNIQUE_PTR_TRIVIAL_ABI
#  define _LIBCPP_ABI_FIX_CITYHASH_IMPLEMENTATION
#  define _LIBCPP_ABI_FIX_UNORDERED_CONTAINER_SIZE_TYPE
#  define _LIBCPP_ABI_INCOMPLETE_TYPES_IN_DEQUE
#  define _LIBCPP_ABI_IOS_ALLOW_ARBITRARY_FILL_VALUE
#  define _LIBCPP_ABI_NO_COMPRESSED_PAIR_PADDING
#  define _LIBCPP_ABI_NO_FILESYSTEM_INLINE_NAMESPACE
#  define _LIBCPP_ABI_NO_ITERATOR_BASES
#  define _LIBCPP_ABI_NO_RANDOM_DEVICE_COMPATIBILITY_LAYOUT
#  define _LIBCPP_ABI_OPTIMIZED_FUNCTION
#  define _LIBCPP_ABI_REGEX_CONSTANTS_NONZERO
#  define _LIBCPP_ABI_STRING_OPTIMIZED_EXTERNAL_INSTANTIATION
#  define _LIBCPP_ABI_USE_WRAP_ITER_IN_STD_ARRAY
#  define _LIBCPP_ABI_USE_WRAP_ITER_IN_STD_STRING_VIEW
#  define _LIBCPP_ABI_VARIANT_INDEX_TYPE_OPTIMIZATION

#elif _LIBCPP_ABI_VERSION == 1
#  if !(defined(_LIBCPP_OBJECT_FORMAT_COFF) || defined(_LIBCPP_OBJECT_FORMAT_XCOFF))
// Enable compiling copies of now inline methods into the dylib to support
// applications compiled against older libraries. This is unnecessary with
// COFF dllexport semantics, since dllexport forces a non-inline definition
// of inline functions to be emitted anyway. Our own non-inline copy would
// conflict with the dllexport-emitted copy, so we disable it. For XCOFF,
// the linker will take issue with the symbols in the shared object if the
// weak inline methods get visibility (such as from -fvisibility-inlines-hidden),
// so disable it.
#    define _LIBCPP_DEPRECATED_ABI_LEGACY_LIBRARY_DEFINITIONS_FOR_INLINE_FUNCTIONS
#  endif
// Feature macros for disabling pre ABI v1 features. All of these options
// are deprecated.
#  if defined(__FreeBSD__)
#    define _LIBCPP_DEPRECATED_ABI_DISABLE_PAIR_TRIVIAL_COPY_CTOR
#  endif
#endif

// We had some bugs where we use [[no_unique_address]] together with construct_at,
// which causes UB as the call on construct_at could write to overlapping subobjects
//
// https://github.com/llvm/llvm-project/issues/70506
// https://github.com/llvm/llvm-project/issues/70494
//
// To fix the bug we had to change the ABI of some classes to remove [[no_unique_address]] under certain conditions.
// The macro below is used for all classes whose ABI have changed as part of fixing these bugs.
#define _LIBCPP_ABI_LLVM18_NO_UNIQUE_ADDRESS __attribute__((__abi_tag__("llvm18_nua")))

// [[msvc::no_unique_address]] seems to mostly affect empty classes, so the padding scheme for Itanium doesn't work.
#if defined(_LIBCPP_ABI_MICROSOFT) && !defined(_LIBCPP_ABI_NO_COMPRESSED_PAIR_PADDING)
#  define _LIBCPP_ABI_NO_COMPRESSED_PAIR_PADDING
#endif

// Tracks the bounds of the array owned by std::unique_ptr<T[]>, allowing it to trap when accessed out-of-bounds.
// Note that limited bounds checking is also available outside of this ABI configuration, but only some categories
// of types can be checked.
//
// ABI impact: This causes the layout of std::unique_ptr<T[]> to change and its size to increase.
//             This also affects the representation of a few library types that use std::unique_ptr
//             internally, such as the unordered containers.
// #define _LIBCPP_ABI_BOUNDED_UNIQUE_PTR

#if defined(_LIBCPP_COMPILER_CLANG_BASED)
#  if defined(__APPLE__)
#    if defined(__i386__) || defined(__x86_64__)
// use old string layout on x86_64 and i386
#    elif defined(__arm__)
// use old string layout on arm (which does not include aarch64/arm64), except on watch ABIs
#      if defined(__ARM_ARCH_7K__) && __ARM_ARCH_7K__ >= 2
#        define _LIBCPP_ABI_ALTERNATE_STRING_LAYOUT
#      endif
#    else
#      define _LIBCPP_ABI_ALTERNATE_STRING_LAYOUT
#    endif
#  endif
#endif

#endif // _LIBCPP___CONFIGURATION_ABI_H
