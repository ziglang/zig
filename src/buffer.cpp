/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "buffer.hpp"
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

Buf *buf_vprintf(const char *format, va_list ap) {
    va_list ap2;
    va_copy(ap2, ap);

    int len1 = vsnprintf(nullptr, 0, format, ap);
    assert(len1 >= 0);

    size_t required_size = len1 + 1;

    Buf *buf = buf_alloc_fixed(len1);

    int len2 = vsnprintf(buf_ptr(buf), required_size, format, ap2);
    assert(len2 == len1);

    va_end(ap2);

    return buf;
}

Buf *buf_sprintf(const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    Buf *result = buf_vprintf(format, ap);
    va_end(ap);
    return result;
}

void buf_appendf(Buf *buf, const char *format, ...) {
    assert(buf->list.length);
    va_list ap, ap2;
    va_start(ap, format);
    va_copy(ap2, ap);

    int len1 = vsnprintf(nullptr, 0, format, ap);
    assert(len1 >= 0);

    size_t required_size = len1 + 1;

    size_t orig_len = buf_len(buf);

    buf_resize(buf, orig_len + len1);

    int len2 = vsnprintf(buf_ptr(buf) + orig_len, required_size, format, ap2);
    assert(len2 == len1);

    va_end(ap2);
    va_end(ap);
}

// these functions are not static inline so they can be better used as template parameters
bool buf_eql_buf(Buf *buf, Buf *other) {
    return buf_eql_mem(buf, buf_ptr(other), buf_len(other));
}

uint32_t buf_hash(Buf *buf) {
    assert(buf->list.length);
    size_t interval = buf->list.length / 256;
    if (interval == 0)
        interval = 1;
    // FNV 32-bit hash
    uint32_t h = 2166136261;
    for (size_t i = 0; i < buf_len(buf); i += interval) {
        h = h ^ ((uint8_t)buf->list.at(i));
        h = h * 16777619;
    }
    return h;
}
