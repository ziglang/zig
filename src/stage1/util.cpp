/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "util.hpp"
#include "stage2.h"

#include <stdio.h>
#include <stdarg.h>

void zig_panic(const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    fflush(stderr);
    va_end(ap);
    stage2_panic("", 0);
    abort();
}

uint32_t int_hash(int i) {
    return (uint32_t)(i % UINT32_MAX);
}
bool int_eq(int a, int b) {
    return a == b;
}

uint32_t uint64_hash(uint64_t i) {
    return (uint32_t)(i % UINT32_MAX);
}

bool uint64_eq(uint64_t a, uint64_t b) {
    return a == b;
}

uint32_t ptr_hash(const void *ptr) {
    return (uint32_t)(((uintptr_t)ptr) % UINT32_MAX);
}

bool ptr_eq(const void *a, const void *b) {
    return a == b;
}

// Ported from std/mem.zig.
bool SplitIterator_isSplitByte(SplitIterator *self, uint8_t byte) {
    for (size_t i = 0; i < self->split_bytes.len; i += 1) {
        if (byte == self->split_bytes.ptr[i]) {
            return true;
        }
    }
    return false;
}

// Ported from std/mem.zig.
Optional<Slice<uint8_t>> SplitIterator_next(SplitIterator *self) {
    // move to beginning of token
    while (self->index < self->buffer.len &&
        SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t start = self->index;
    if (start == self->buffer.len) {
        return {};
    }

    // move to end of token
    while (self->index < self->buffer.len &&
        !SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t end = self->index;

    return Optional<Slice<uint8_t>>::some(self->buffer.slice(start, end));
}

// Ported from std/mem.zig.
// This one won't collapse multiple separators into one, so you could use it, for example,
// to parse Comma Separated Value format.
Optional<Slice<uint8_t>> SplitIterator_next_separate(SplitIterator *self) {
    // move to beginning of token
    if (self->index < self->buffer.len &&
        SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t start = self->index;
    if (start == self->buffer.len) {
        return {};
    }

    // move to end of token
    while (self->index < self->buffer.len &&
        !SplitIterator_isSplitByte(self, self->buffer.ptr[self->index]))
    {
        self->index += 1;
    }
    size_t end = self->index;

    return Optional<Slice<uint8_t>>::some(self->buffer.slice(start, end));
}

// Ported from std/mem.zig
Slice<uint8_t> SplitIterator_rest(SplitIterator *self) {
    // move to beginning of token
    size_t index = self->index;
    while (index < self->buffer.len && SplitIterator_isSplitByte(self, self->buffer.ptr[index])) {
        index += 1;
    }
    return self->buffer.sliceFrom(index);
}

// Ported from std/mem.zig
SplitIterator memSplit(Slice<uint8_t> buffer, Slice<uint8_t> split_bytes) {
    return SplitIterator{0, buffer, split_bytes};
}

void zig_pretty_print_bytes(FILE *f, double n) {
    if (n > 1024.0 * 1024.0 * 1024.0) {
        fprintf(f, "%.03f GiB", n / 1024.0 / 1024.0 / 1024.0);
        return;
    }
    if (n > 1024.0 * 1024.0) {
        fprintf(f, "%.03f MiB", n / 1024.0 / 1024.0);
        return;
    }
    if (n > 1024.0) {
        fprintf(f, "%.03f KiB", n / 1024.0);
        return;
    }
    fprintf(f, "%.03f bytes", n );
    return;
}

