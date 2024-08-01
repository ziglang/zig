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

#ifndef _UNISTD_H
#error "Never include this file directly; instead, include <unistd.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__FORTIFY_COMPILATION)

#define __DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(what, fn) \
    __DIAGNOSE_ERROR_IF((what) > FORTIFY_SSIZE_MAX, "in call to '" #fn "', '" #what "' must be <= FORTIFY_SSIZE_MAX")

#define __DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(what, objsize, fn) \
    __DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT((objsize), (what)), \
    "in call to '" #fn "', '" #what "' bytes overflows the given object")

#define __DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos_val, index)  \
    ((__DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND((bos_val), >=, (index), (bos_val) <= (FORTIFY_SSIZE_MAX)) && \
    __builtin_constant_p(index) && (index) <= (FORTIFY_SSIZE_MAX)))

char* __getcwd_chk(char*, size_t, size_t) ;

ssize_t __pread_chk(int, void*, size_t, off_t, size_t);
ssize_t __pread_real(int, void*, size_t, off_t) __DIAGNOSE_RENAME(pread);

ssize_t __pwrite_chk(int, const void*, size_t, off_t, size_t);
ssize_t __pwrite_real(int, const void*, size_t, off_t) __DIAGNOSE_RENAME(pwrite);

ssize_t __read_chk(int, void*, size_t, size_t);
ssize_t __write_chk(int, const void*, size_t, size_t);

ssize_t __readlink_chk(const char*, char*, size_t, size_t);
ssize_t __readlinkat_chk(int dirfd, const char*, char*, size_t, size_t);

#define __DIAGNOSE_PREAD_PREFIX(x) __pread_ ## x
#define __DIAGNOSE_PWRITE_PREFIX(x) __pwrite_ ## x

__DIAGNOSE_FORTIFY_INLINE
char* getcwd(char* const __DIAGNOSE_PASS_OBJECT_SIZE buf, size_t size)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(size, __DIAGNOSE_BOS(buf), getcwd)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE(bos, size)) {
        return __getcwd_chk(buf, size, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(getcwd)(buf, size);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t pread(int fd, void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf, size_t count, off_t offset)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(count, pread)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(count, __DIAGNOSE_BOS0(buf), pread)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, count)) {
        return __DIAGNOSE_PREAD_PREFIX(chk)(fd, buf, count, offset, bos);
    }
#endif
    return __DIAGNOSE_PREAD_PREFIX(real)(fd, buf, count, offset);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t pwrite(int fd, const void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf, size_t count, off_t offset)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(count, pwrite)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(count, __DIAGNOSE_BOS0(buf), pwrite)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, count)) {
        return __DIAGNOSE_PWRITE_PREFIX(chk)(fd, buf, count, offset, bos);
    }
#endif
    return __DIAGNOSE_PWRITE_PREFIX(real)(fd, buf, count, offset);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t read(int fd, void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf, size_t count)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(count, read)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(count, __DIAGNOSE_BOS0(buf), read)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, count)) {
        return __read_chk(fd, buf, count, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(read)(fd, buf, count);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t write(int fd, const void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf, size_t count)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(count, write)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(count, __DIAGNOSE_BOS0(buf), write)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, count)) {
        return __write_chk(fd, buf, count, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(write)(fd, buf, count);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t readlink(const char* path, char* const __DIAGNOSE_PASS_OBJECT_SIZE buf, size_t size)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(size, readlink)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(size, __DIAGNOSE_BOS(buf), readlink)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, size)) {
        return __readlink_chk(path, buf, size, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(readlink)(path, buf, size);
}

__DIAGNOSE_FORTIFY_INLINE
ssize_t readlinkat(int dirfd, const char* path, char* const __DIAGNOSE_PASS_OBJECT_SIZE buf, size_t size)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF_OVERFLOWS_SSIZET(size, readlinkat)
__DIAGNOSE_ERROR_IF_OVERFLOWS_OBJECTSIZE(size, __DIAGNOSE_BOS(buf), readlinkat)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_NO_OVERFLOW(bos, size)) {
        return __readlinkat_chk(dirfd, path, buf, size, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(readlinkat)(dirfd, path, buf, size);
}

#endif // defined(__FORTIFY_COMPILATION)

#ifdef __cplusplus
}
#endif