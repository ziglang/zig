/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_WINDOWS_SDK_H
#define ZIG_WINDOWS_SDK_H

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

#include <stddef.h>

// ABI warning - src/windows_sdk.zig
struct ZigWindowsSDK {
    const char *path10_ptr;
    size_t path10_len;

    const char *version10_ptr;
    size_t version10_len;

    const char *path81_ptr;
    size_t path81_len;

    const char *version81_ptr;
    size_t version81_len;

    const char *msvc_lib_dir_ptr;
    size_t msvc_lib_dir_len;
};

// ABI warning - src/windows_sdk.zig
enum ZigFindWindowsSdkError {
    ZigFindWindowsSdkErrorNone,
    ZigFindWindowsSdkErrorOutOfMemory,
    ZigFindWindowsSdkErrorNotFound,
    ZigFindWindowsSdkErrorPathTooLong,
};

// ABI warning - src/windows_sdk.zig
ZIG_EXTERN_C enum ZigFindWindowsSdkError zig_find_windows_sdk(struct ZigWindowsSDK **out_sdk);

// ABI warning - src/windows_sdk.zig
ZIG_EXTERN_C void zig_free_windows_sdk(struct ZigWindowsSDK *sdk);

#endif
