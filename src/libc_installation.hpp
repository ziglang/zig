/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_LIBC_INSTALLATION_HPP
#define ZIG_LIBC_INSTALLATION_HPP

#include <stdio.h>

#include "buffer.hpp"
#include "error.hpp"
#include "target.hpp"

// Must be synchronized with zig_libc_keys
struct ZigLibCInstallation {
    Buf include_dir;
    Buf crt_dir;
    Buf lib_dir;
    Buf static_lib_dir;
    Buf msvc_lib_dir;
    Buf kernel32_lib_dir;
    Buf dynamic_linker_path;
};

Error ATTRIBUTE_MUST_USE zig_libc_parse(ZigLibCInstallation *libc, Buf *libc_file,
        const ZigTarget *target, bool verbose);
void zig_libc_render(ZigLibCInstallation *self, FILE *file);

Error ATTRIBUTE_MUST_USE zig_libc_find_native(ZigLibCInstallation *self, bool verbose);

#endif
