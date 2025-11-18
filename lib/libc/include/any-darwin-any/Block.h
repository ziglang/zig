/*
 *  Block.h
 *
 * Copyright (c) 2008-2010 Apple Inc. All rights reserved.
 *
 * @APPLE_LLVM_LICENSE_HEADER@
 *
 */

#ifndef _Block_H_
#define _Block_H_

#if !defined(BLOCK_EXPORT)
#   if defined(__cplusplus)
#       define BLOCK_EXPORT extern "C" 
#   else
#       define BLOCK_EXPORT extern
#   endif
#endif

#include <TargetConditionals.h>
#include <sys/cdefs.h>

#if __cplusplus
extern "C" {
#endif

// Create a heap based copy of a Block or simply add a reference to an existing one.
// This must be paired with Block_release to recover memory, even when running
// under Objective-C Garbage Collection.
BLOCK_EXPORT void *__single _Block_copy(const void *__single aBlock);

// Lose the reference, and if heap based and last reference, recover the memory
BLOCK_EXPORT void _Block_release(const void *__single aBlock);

// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_assign(void *, const void *, const int);

// Used by the compiler. Do not call this function yourself.
BLOCK_EXPORT void _Block_object_dispose(const void *, const int);

// Used by the compiler. Do not use these variables yourself.
BLOCK_EXPORT void * _NSConcreteGlobalBlock[32];
BLOCK_EXPORT void * _NSConcreteStackBlock[32];

#if __cplusplus
}
#endif

// Type correct macros

#define Block_copy(...) ((__typeof(__VA_ARGS__))_Block_copy(__unsafe_forge_single(const void *, (const void *)(__VA_ARGS__))))
#define Block_release(...) _Block_release(__unsafe_forge_single(const void *, (const void *)(__VA_ARGS__)))


#endif
