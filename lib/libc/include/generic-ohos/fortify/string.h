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

#ifndef _STRING_H
#error "Never include this file directly; instead, include <string.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

void *__memchr_chk(const void* s, int c, size_t n, size_t actual_size);
void *__memrchr_chk(const void*, int, size_t, size_t);
size_t __strlcpy_chk(char*, const char*, size_t, size_t);
size_t __strlcat_chk(char*, const char*, size_t, size_t);
char *__strchr_chk(const char* p, int ch, size_t s_len);
char *__strrchr_chk(const char *p, int ch, size_t s_len);
size_t __strlen_chk(const char* s, size_t s_len);

#ifdef __FORTIFY_COMPILATION
__DIAGNOSE_FORTIFY_INLINE
char *strcpy(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char *src)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LE(__DIAGNOSE_BOS(dest), __builtin_strlen(src)),
    "'strcpy' " CALLED_WITH_STRING_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___strcpy_chk(dest, src, __DIAGNOSE_BOS(dest));
#else
    return __builtin_strcpy(dest, src);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
char *stpcpy(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char *src)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LE(__DIAGNOSE_BOS(dest), __builtin_strlen(src)),
    "'stpcpy' " CALLED_WITH_STRING_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___stpcpy_chk(dest, src, __DIAGNOSE_BOS(dest));
#else
    return __builtin_stpcpy(dest, src);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
void *memmove(void *const dest __DIAGNOSE_PASS_OBJECT_SIZE0, const void *src, size_t len)
__DIAGNOSE_OVERLOAD
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___memmove_chk(dest, src, len, __DIAGNOSE_BOS(dest));
#else
    return __builtin_memmove(dest, src, len);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
void *mempcpy(void *const dest __DIAGNOSE_PASS_OBJECT_SIZE, const void *src, size_t copy_amount)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(dest), copy_amount),
    "'mempcpy' " CALLED_WITH_STRING_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___mempcpy_chk(dest, src, copy_amount, __DIAGNOSE_BOS0(dest));
#else
    return __builtin_mempcpy(dest, src, copy_amount);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
char *strcat(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char *src)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LE(__DIAGNOSE_BOS(dest), __builtin_strlen(src)),
    "'strcat' " CALLED_WITH_STRING_BIGGER_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___strcat_chk(dest, src, __DIAGNOSE_BOS(dest));
#else
    return __builtin_strcat(dest, src);
#endif
}

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
char *strncat(char* const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char* src, size_t n)
__DIAGNOSE_OVERLOAD
{
    return __builtin___strncat_chk(dest, src, n, __DIAGNOSE_BOS(dest));
}
#endif

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
char *stpncpy(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE,
    const char *const src __DIAGNOSE_PASS_OBJECT_SIZE, size_t n)
__DIAGNOSE_OVERLOAD
{
    size_t bos_dest = __DIAGNOSE_BOS(dest);
    return __builtin___stpncpy_chk(dest, src, n, bos_dest);
}
#endif

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
char *strncpy(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE,
    const char *const src __DIAGNOSE_PASS_OBJECT_SIZE, size_t n)
__DIAGNOSE_OVERLOAD
{
    size_t bos_dest = __DIAGNOSE_BOS(dest);
    return __builtin___strncpy_chk(dest, src, n, bos_dest);
}
#endif

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
void *memcpy(void *const dest __DIAGNOSE_PASS_OBJECT_SIZE0, const void *src, size_t copy_amount)
__DIAGNOSE_OVERLOAD
{
    return __builtin___memcpy_chk(dest, src, copy_amount, __DIAGNOSE_BOS0(dest));
}
#endif

#if defined(_BSD_SOURCE) || defined(_GNU_SOURCE)
__DIAGNOSE_FORTIFY_INLINE
size_t strlcpy(char *const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char *src, size_t size)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(dest), size),
    "'strlcpy' called with size bigger than buffer")
{
#ifdef __FORTIFY_RUNTIME
    return __strlcpy_chk(dest, src, size, __DIAGNOSE_BOS(dest));
#else
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(strlcpy)(dest, src, size);
#endif
}

__DIAGNOSE_FORTIFY_INLINE
size_t strlcat(char* const dest __DIAGNOSE_PASS_OBJECT_SIZE, const char* src, size_t size)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(dest), size),
    "'strlcat' called with size bigger than buffer")
{
#ifdef __FORTIFY_RUNTIME
    return __strlcat_chk(dest, src, size, __DIAGNOSE_BOS(dest));
#else
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(strlcat)(dest, src, size);
#endif
}
#endif // defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

__DIAGNOSE_FORTIFY_INLINE
void *memset(void *const s __DIAGNOSE_PASS_OBJECT_SIZE0, int c, size_t n)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_WARNING_IF(c && !n, "'memset' will set 0 bytes; maybe the arguments got flipped?")
{
#ifdef __FORTIFY_RUNTIME
    return __builtin___memset_chk(s, c, n, __DIAGNOSE_BOS0(s));
#else
    return __builtin_memset(s, c, n);
#endif
}

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
void *memchr(const void *const s __DIAGNOSE_PASS_OBJECT_SIZE, int c, size_t n)
__DIAGNOSE_OVERLOAD
{
    size_t bos = __DIAGNOSE_BOS(s);
    if (__DIAGNOSE_BOS_TRIVIALLY_GE(bos, n)) {
        return __builtin_memchr(s, c, n);
    }
    return __memchr_chk(s, c, n, bos);
}
#endif // memchr __FORTIFY_RUNTIME

extern void* __memrchr_real(const void*, int, size_t) __DIAGNOSE_RENAME(memrchr);

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
void *memrchr(const void *const __DIAGNOSE_PASS_OBJECT_SIZE s, int c, size_t n)
__DIAGNOSE_OVERLOAD
{
    size_t bos = __DIAGNOSE_BOS(s);
    if (__DIAGNOSE_BOS_TRIVIALLY_GE(bos, n)) {
        return __memrchr_real(s, c, n);
    }
    return __memrchr_chk(s, c, n, bos);
}
#endif

__DIAGNOSE_FORTIFY_INLINE
char* strchr(const char* const s __DIAGNOSE_PASS_OBJECT_SIZE, int c)
__DIAGNOSE_OVERLOAD
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(s);

    if (bos != __DIAGNOSE_FORTIFY_UNKNOWN_SIZE) {
        return __strchr_chk(s, c, bos);
    }
#endif
    return __builtin_strchr(s, c);
}

__DIAGNOSE_FORTIFY_INLINE
char* strrchr(const char* const s __DIAGNOSE_PASS_OBJECT_SIZE, int c)
__DIAGNOSE_OVERLOAD
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(s);

    if (bos != __DIAGNOSE_FORTIFY_UNKNOWN_SIZE) {
        return __strrchr_chk(s, c, bos);
    }
#endif
    return __builtin_strrchr(s, c);
}

#ifdef __FORTIFY_RUNTIME
__DIAGNOSE_FORTIFY_INLINE
size_t strlen(const char* const s __DIAGNOSE_PASS_OBJECT_SIZE0)
__DIAGNOSE_OVERLOAD
{
    return __strlen_chk(s, __DIAGNOSE_BOS0(s));
}
#endif

#endif // __FORTIFY_COMPILATION
#ifdef __cplusplus
}
#endif