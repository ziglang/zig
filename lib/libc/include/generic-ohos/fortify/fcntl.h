/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _FCNTL_H
#error "Never include this file directly; instead, include <fcntl.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

int __open_chk(const char*, int);
int __openat_chk(int, const char*, int);
#if defined(_LARGEFILE64_SOURCE) || defined(_GNU_SOURCE)
int __open64_chk(const char*, int);
int __openat64_chk(int, const char*, int);
#endif
/*
 * Even in musl FORTIFY, the following is the easiest way to call a real open.
 */
int __open_real(const char*, int, ...) __DIAGNOSE_RENAME(open);
int __openat_real(int, const char*, int, ...) __DIAGNOSE_RENAME(openat);
#if defined(_LARGEFILE64_SOURCE) || defined(_GNU_SOURCE)
int __open64_real(const char*, int, ...) __DIAGNOSE_RENAME(open64);
int __openat64_real(int, const char*, int, ...) __DIAGNOSE_RENAME(openat64);
#endif

#ifdef __FORTIFY_COMPILATION
__DIAGNOSE_FORTIFY_INLINE
int open(const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_OPEN_MODES_USEFUL(flags), "'open' " OPEN_TOO_FEW_ARGS_ERROR)
{
#ifdef __FORTIFY_RUNTIME
    return __open_chk(path, flags);
#else
    return __open_real(path, flags);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
int open(const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags, unsigned modes)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_WARNING_IF(!__DIAGNOSE_OPEN_MODES_USEFUL(flags) && modes, "'open' " OPEN_USELESS_MODES_WARNING)
{
    return __open_real(path, flags, modes);
}

__DIAGNOSE_FORTIFY_INLINE
int openat(int dirfd, const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_OPEN_MODES_USEFUL(flags), "'openat' " OPEN_TOO_FEW_ARGS_ERROR)
{
#ifdef __FORTIFY_RUNTIME
    return __openat_chk(dirfd, path, flags);
#else
    return __openat_real(dirfd, path, flags);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
int openat(int dirfd, const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags, mode_t modes)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_WARNING_IF(!__DIAGNOSE_OPEN_MODES_USEFUL(flags) && modes, "'openat' " OPEN_USELESS_MODES_WARNING)
{
    return __openat_real(dirfd, path, flags, modes);
}

#if defined(_LARGEFILE64_SOURCE) || defined(_GNU_SOURCE)
__DIAGNOSE_FORTIFY_INLINE
int open64(const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_OPEN_MODES_USEFUL(flags), "'open64' " OPEN_TOO_FEW_ARGS_ERROR)
{
#ifdef __FORTIFY_RUNTIME
    return __open64_chk(path, flags);
#else
    return __open64_real(path, flags);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
int open64(const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags, mode_t modes)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_WARNING_IF(!__DIAGNOSE_OPEN_MODES_USEFUL(flags) && modes, "'open64' " OPEN_USELESS_MODES_WARNING)
{
    return __open64_real(path, flags, modes);
}

__DIAGNOSE_FORTIFY_INLINE
int openat64(int dirfd, const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_OPEN_MODES_USEFUL(flags), "'openat64' " OPEN_TOO_FEW_ARGS_ERROR)
{
#ifdef __FORTIFY_RUNTIME
    return __openat64_chk(dirfd, path, flags);
#else
    return __openat64_real(dirfd, path, flags);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
int openat64(int dirfd, const char* const __DIAGNOSE_PASS_OBJECT_SIZE path, int flags, mode_t modes)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_WARNING_IF(!__DIAGNOSE_OPEN_MODES_USEFUL(flags) && modes, "'openat64' " OPEN_USELESS_MODES_WARNING)
{
    return __openat64_real(dirfd, path, flags, modes);
}
#endif

#endif

#ifdef __cplusplus
}
#endif