/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_BUFFER_HPP
#define ZIG_BUFFER_HPP

#include "list.hpp"

#include <stdint.h>
#include <ctype.h>
#include <stdarg.h>

#define BUF_INIT {{0}}

// Note, you must call one of the alloc, init, or resize functions to have an
// initialized buffer. The assertions should help with this.
struct Buf {
    ZigList<char> list;
};

Buf *buf_sprintf(const char *format, ...)
    ATTRIBUTE_PRINTF(1, 2);
Buf *buf_vprintf(const char *format, va_list ap);

static inline size_t buf_len(const Buf *buf) {
    assert(buf);
    assert(buf->list.length);
    return buf->list.length - 1;
}

static inline char *buf_ptr(Buf *buf) {
    assert(buf);
    assert(buf->list.length);
    return buf->list.items;
}

static inline const char *buf_ptr(const Buf *buf) {
    assert(buf);
    assert(buf->list.length);
    return buf->list.items;
}

static inline void buf_resize(Buf *buf, size_t new_len) {
    buf->list.resize(new_len + 1);
    buf->list.at(buf_len(buf)) = 0;
}

static inline Buf *buf_alloc_fixed(size_t size) {
    Buf *buf = heap::c_allocator.create<Buf>();
    buf_resize(buf, size);
    return buf;
}

static inline Buf *buf_alloc(void) {
    return buf_alloc_fixed(0);
}

static inline void buf_deinit(Buf *buf) {
    buf->list.deinit();
}

static inline void buf_destroy(Buf *buf) {
    buf_deinit(buf);
    heap::c_allocator.destroy(buf);
}

static inline void buf_init_from_mem(Buf *buf, const char *ptr, size_t len) {
    assert(len != SIZE_MAX);
    buf->list.resize(len + 1);
    memcpy(buf_ptr(buf), ptr, len);
    buf->list.at(buf_len(buf)) = 0;
}

static inline void buf_init_from_str(Buf *buf, const char *str) {
    buf_init_from_mem(buf, str, strlen(str));
}

static inline void buf_init_from_buf(Buf *buf, Buf *other) {
    buf_init_from_mem(buf, buf_ptr(other), buf_len(other));
}

static inline Buf *buf_create_from_mem(const char *ptr, size_t len) {
    assert(len != SIZE_MAX);
    Buf *buf = heap::c_allocator.create<Buf>();
    buf_init_from_mem(buf, ptr, len);
    return buf;
}

static inline Buf *buf_create_from_slice(Slice<uint8_t> slice) {
    return buf_create_from_mem((const char *)slice.ptr, slice.len);
}

static inline Buf *buf_create_from_str(const char *str) {
    return buf_create_from_mem(str, strlen(str));
}

static inline Buf *buf_create_from_buf(Buf *buf) {
    return buf_create_from_mem(buf_ptr(buf), buf_len(buf));
}

static inline Buf *buf_slice(Buf *in_buf, size_t start, size_t end) {
    assert(in_buf->list.length);
    assert(start != SIZE_MAX);
    assert(end != SIZE_MAX);
    assert(start < buf_len(in_buf));
    assert(end <= buf_len(in_buf));
    Buf *out_buf = heap::c_allocator.create<Buf>();
    out_buf->list.resize(end - start + 1);
    memcpy(buf_ptr(out_buf), buf_ptr(in_buf) + start, end - start);
    out_buf->list.at(buf_len(out_buf)) = 0;
    return out_buf;
}

static inline void buf_append_mem(Buf *buf, const char *mem, size_t mem_len) {
    assert(buf->list.length);
    assert(mem_len != SIZE_MAX);
    size_t old_len = buf_len(buf);
    buf_resize(buf, old_len + mem_len);
    memcpy(buf_ptr(buf) + old_len, mem, mem_len);
    buf->list.at(buf_len(buf)) = 0;
}

static inline void buf_append_str(Buf *buf, const char *str) {
    assert(buf->list.length);
    buf_append_mem(buf, str, strlen(str));
}

static inline void buf_append_buf(Buf *buf, Buf *append_buf) {
    assert(buf->list.length);
    buf_append_mem(buf, buf_ptr(append_buf), buf_len(append_buf));
}

static inline void buf_append_char(Buf *buf, uint8_t c) {
    assert(buf->list.length);
    buf_append_mem(buf, (const char *)&c, 1);
}

void buf_appendf(Buf *buf, const char *format, ...)
    ATTRIBUTE_PRINTF(2, 3);

static inline bool buf_eql_mem(Buf *buf, const char *mem, size_t mem_len) {
    assert(buf->list.length);
    return mem_eql_mem(buf_ptr(buf), buf_len(buf), mem, mem_len);
}

static inline bool buf_eql_mem_ignore_case(Buf *buf, const char *mem, size_t mem_len) {
    assert(buf->list.length);
    return mem_eql_mem_ignore_case(buf_ptr(buf), buf_len(buf), mem, mem_len);
}

static inline bool buf_eql_str(Buf *buf, const char *str) {
    assert(buf->list.length);
    return buf_eql_mem(buf, str, strlen(str));
}

static inline bool buf_eql_str_ignore_case(Buf *buf, const char *str) {
    assert(buf->list.length);
    return buf_eql_mem_ignore_case(buf, str, strlen(str));
}

static inline bool buf_starts_with_mem(Buf *buf, const char *mem, size_t mem_len) {
    if (buf_len(buf) < mem_len) {
        return false;
    }
    return memcmp(buf_ptr(buf), mem, mem_len) == 0;
}

static inline bool buf_starts_with_buf(Buf *buf, Buf *sub) {
    return buf_starts_with_mem(buf, buf_ptr(sub), buf_len(sub));
}

static inline bool buf_starts_with_str(Buf *buf, const char *str) {
    return buf_starts_with_mem(buf, str, strlen(str));
}

static inline bool buf_ends_with_mem(Buf *buf, const char *mem, size_t mem_len) {
    return mem_ends_with_mem(buf_ptr(buf), buf_len(buf), mem, mem_len);
}

static inline bool buf_ends_with_str(Buf *buf, const char *str) {
    return buf_ends_with_mem(buf, str, strlen(str));
}

bool buf_eql_buf(Buf *buf, Buf *other);
uint32_t buf_hash(Buf *buf);

static inline void buf_upcase(Buf *buf) {
    for (size_t i = 0; i < buf_len(buf); i += 1) {
        buf_ptr(buf)[i] = (char)toupper(buf_ptr(buf)[i]);
    }
}

static inline Slice<uint8_t> buf_to_slice(Buf *buf) {
    return Slice<uint8_t>{reinterpret_cast<uint8_t*>(buf_ptr(buf)), buf_len(buf)};
}

static inline void buf_replace(Buf* buf, char from, char to) {
    const size_t count = buf_len(buf);
    char* ptr = buf_ptr(buf);
    for (size_t i = 0; i < count; ++i) {
        char& l = ptr[i];
        if (l == from)
            l = to;
    }
}

#endif
