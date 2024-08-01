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

#ifndef _STDIO_H
#error "Never include this file directly; instead, include <stdio.h>"
#endif

#include <stdarg.h>
#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__FORTIFY_COMPILATION)

#define FORMAT_PLACE_2 (2)
#define FORMAT_PLACE_3 (3)
#define VALIST_PLACE_0 (0)
#define VALIST_PLACE_3 (3)
#define VALIST_PLACE_4 (4)

size_t __fread_chk(void*, size_t, size_t, FILE*, size_t);
size_t __fwrite_chk(const void*, size_t, size_t, FILE*, size_t);
char* __fgets_chk(char*, int, FILE*, size_t);

__DIAGNOSE_FORTIFY_INLINE
size_t fread(void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf,
    size_t size, size_t count, FILE* stream)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNSAFE_CHK_MUL_OVERFLOW(size, count),
    "in call to 'fread', size * count overflows")
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), size * count),
    "in call to 'fread', size * count is too large for the given buffer")
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_MUL(bos, size, count)) {
        return __fread_chk(buf, size, count, stream, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(fread)(buf, size, count, stream);
}

__DIAGNOSE_FORTIFY_INLINE
size_t fwrite(const void* const __DIAGNOSE_PASS_OBJECT_SIZE0 buf,
    size_t size, size_t count, FILE* stream)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNSAFE_CHK_MUL_OVERFLOW(size, count),
    "in call to 'fwrite', size * count overflows")
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS0(buf), size * count),
    "in call to 'fwrite', size * count is too large for the given buffer")
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS0(buf);

    if (!__DIAGNOSE_BOS_TRIVIALLY_GE_MUL(bos, size, count)) {
        return __fwrite_chk(buf, size, count, stream, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(fwrite)(buf, size, count, stream);
}

__DIAGNOSE_FORTIFY_INLINE
char* fgets(char* const __DIAGNOSE_PASS_OBJECT_SIZE dest, int size, FILE* stream)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ERROR_IF(size < 0, "in call to 'fgets', size should not be less than 0")
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(dest), size),
    "in call to 'fgets', " SIZE_LARGER_THEN_DESTINATION_BUFFER)
{
#ifdef __FORTIFY_RUNTIME
    size_t bos = __DIAGNOSE_BOS(dest);

    if (!__DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND(bos, >=, (size_t)size, size >= 0)) {
        return __fgets_chk(dest, size, stream, bos);
    }
#endif
    return __DIAGNOSE_CALL_BYPASSING_FORTIFY(fgets)(dest, size, stream);
}

__DIAGNOSE_FORTIFY_INLINE __DIAGNOSE_PRINTFLIKE(FORMAT_PLACE_3, VALIST_PLACE_0)
int vsnprintf(char* const __DIAGNOSE_PASS_OBJECT_SIZE dest,
    size_t size, const char* format, va_list ap)
__DIAGNOSE_OVERLOAD
{
    size_t bos = __DIAGNOSE_BOS(dest);
    return __builtin___vsnprintf_chk(dest, size, 0, bos, format, ap);
}

__DIAGNOSE_FORTIFY_INLINE __DIAGNOSE_PRINTFLIKE(FORMAT_PLACE_2, VALIST_PLACE_0)
int vsprintf(char* const __DIAGNOSE_PASS_OBJECT_SIZE dest, const char* format, va_list ap)
__DIAGNOSE_OVERLOAD
{
    return __builtin___vsprintf_chk(dest, 0, __DIAGNOSE_BOS(dest), format, ap);
}

__DIAGNOSE_FORTIFY_VARIADIC __DIAGNOSE_PRINTFLIKE(FORMAT_PLACE_2, VALIST_PLACE_3)
int sprintf(char* const __DIAGNOSE_PASS_OBJECT_SIZE dest, const char* format, ...)
__DIAGNOSE_OVERLOAD
{
    va_list va_l;
    va_start(va_l, format);
    int result = __builtin___vsprintf_chk(dest, 0, __DIAGNOSE_BOS(dest), format, va_l);
    va_end(va_l);
    return result;
}

__DIAGNOSE_FORTIFY_VARIADIC __DIAGNOSE_PRINTFLIKE(FORMAT_PLACE_3, VALIST_PLACE_4)
int snprintf(char* const __DIAGNOSE_PASS_OBJECT_SIZE dest, size_t size, const char* format, ...)
__DIAGNOSE_OVERLOAD
{
    va_list va_l;
    va_start(va_l, format);
    int result = __builtin___vsnprintf_chk(dest, size, 0, __DIAGNOSE_BOS(dest), format, va_l);
    va_end(va_l);
    return result;
}

#endif // defined(__FORTIFY_COMPILATION)

#ifdef __cplusplus
}
#endif