#include "buffer.hpp"
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

Buf *buf_sprintf(const char *format, ...) {
    va_list ap, ap2;
    va_start(ap, format);
    va_copy(ap2, ap);

    int len1 = vsnprintf(nullptr, 0, format, ap);
    assert(len1 >= 0);

    size_t required_size = len1 + 1;

    Buf *buf = buf_alloc_fixed(len1);

    int len2 = vsnprintf(buf_ptr(buf), required_size, format, ap2);
    assert(len2 == len1);

    va_end(ap2);
    va_end(ap);

    return buf;
}

void buf_appendf(Buf *buf, const char *format, ...) {
    va_list ap, ap2;
    va_start(ap, format);
    va_copy(ap2, ap);

    int len1 = vsnprintf(nullptr, 0, format, ap);
    assert(len1 >= 0);

    size_t required_size = len1 + 1;

    int orig_len = buf_len(buf);

    buf_resize(buf, orig_len + required_size);

    int len2 = vsnprintf(buf_ptr(buf) + orig_len, required_size, format, ap2);
    assert(len2 == len1);

    va_end(ap2);
    va_end(ap);
}
