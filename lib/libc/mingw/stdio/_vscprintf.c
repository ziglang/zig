/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <windows.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* emulation of _vscprintf() via _vsnprintf() */
static int __cdecl emu_vscprintf(const char * __restrict__ format, va_list arglist)
{
    char *buffer, *new_buffer;
    size_t size;
    int ret = -1;

    /* if format is a null pointer, _vscprintf() returns -1 and sets errno to EINVAL */
    if (!format) {
        _set_errno(EINVAL);
        return -1;
    }

    /* size for _vsnprintf() must be non-zero and buffer must have place for terminating null character */
    size = strlen(format) * 2 + 1;
    buffer = malloc(size);

    if (!buffer) {
        _set_errno(ENOMEM);
        return -1;
    }

    /* if the number of characters to write is greater than size, _vsnprintf() returns -1 */
    while (size < SIZE_MAX/2 && (ret = _vsnprintf(buffer, size, format, arglist)) < 0) {
        /* in this case try with larger buffer */
        size *= 2;
        new_buffer = realloc(buffer, size);
        if (!new_buffer)
            break;
        buffer = new_buffer;
    }

    free(buffer);

    if (ret < 0) {
        _set_errno(ENOMEM);
        return -1;
    }

    return ret;
}

#ifndef __LIBMSVCRT_OS__

int (__cdecl *__MINGW_IMP_SYMBOL(_vscprintf))(const char * __restrict__, va_list) = emu_vscprintf;

#else

#include <msvcrt.h>

static int __cdecl init_vscprintf(const char * __restrict__ format, va_list arglist);

int (__cdecl *__MINGW_IMP_SYMBOL(_vscprintf))(const char * __restrict__, va_list) = init_vscprintf;

static int __cdecl init_vscprintf(const char * __restrict__ format, va_list arglist)
{
    HMODULE msvcrt = __mingw_get_msvcrt_handle();
    int (__cdecl *func)(const char * __restrict__, va_list) = NULL;

    if (msvcrt)
        func = (int (__cdecl *)(const char * __restrict__, va_list))GetProcAddress(msvcrt, "_vscprintf");

    if (!func)
        func = emu_vscprintf;

    return (__MINGW_IMP_SYMBOL(_vscprintf) = func)(format, arglist);
}

#endif

int __cdecl _vscprintf(const char * __restrict__ format, va_list arglist)
{
    return __MINGW_IMP_SYMBOL(_vscprintf)(format, arglist);
}
