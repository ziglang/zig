#ifndef INPUT_STREAM_H
#define INPUT_STREAM_H

#include "panic.h"
#include "wasm.h"

#include <zstd.h>

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct InputStream {
    FILE *stream;
    ZSTD_DStream *ds;
    ZSTD_outBuffer out;
    ZSTD_inBuffer in;
    size_t pos;
};

static void InputStream_open(struct InputStream *self, const char *path) {
    self->stream = fopen(path, "rb");
    if (self->stream == NULL) panic("unable to open input file");
    self->ds = ZSTD_createDStream();
    if (self->ds == NULL) panic("unable to create zstd context");
    size_t in_size = ZSTD_initDStream(self->ds);
    if (ZSTD_isError(in_size)) panic(ZSTD_getErrorName(in_size));
    self->out.size = ZSTD_DStreamOutSize();
    self->out.dst = malloc(self->out.size + ZSTD_DStreamInSize());
    if (self->out.dst == NULL) panic("unable to allocate input buffers");
    self->out.pos = 0;
    self->in.src = (const char *)self->out.dst + self->out.size;
    self->in.size = fread((void *)self->in.src, 1, in_size, self->stream);
    self->in.pos = 0;
    self->pos = 0;
}

static void InputStream_close(struct InputStream *self) {
    free(self->out.dst);
    ZSTD_freeDStream(self->ds);
    fclose(self->stream);
}

static bool InputStream_atEnd(struct InputStream *self) {
    while (self->pos >= self->out.pos) {
        self->out.pos = 0;
        self->pos = 0;
        size_t in_size = ZSTD_decompressStream(self->ds, &self->out, &self->in);
        if (ZSTD_isError(in_size)) panic(ZSTD_getErrorName(in_size));
        if (self->in.pos >= self->in.size) {
            size_t max_in_size = ZSTD_DStreamInSize();
            if (in_size > max_in_size) in_size = max_in_size;
            self->in.size = fread((void *)self->in.src, 1, in_size, self->stream);
            self->in.pos = 0;
            if (self->in.pos >= self->in.size) return true;
        }
    }
    return false;
}

static uint8_t InputStream_readByte(struct InputStream *self) {
    if (InputStream_atEnd(self)) panic("unexpected end of input stream");
    uint8_t value = ((uint8_t *)self->out.dst)[self->pos];
    self->pos += 1;
    return value;
}

static uint32_t InputStream_readLittle_u32(struct InputStream *self) {
    uint32_t value = 0;
    value |= (uint32_t)InputStream_readByte(self) << 0;
    value |= (uint32_t)InputStream_readByte(self) << 8;
    value |= (uint32_t)InputStream_readByte(self) << 16;
    value |= (uint32_t)InputStream_readByte(self) << 24;
    return value;
}

static uint64_t InputStream_readLittle_u64(struct InputStream *self) {
    uint64_t value = 0;
    value |= (uint64_t)InputStream_readByte(self) << 0;
    value |= (uint64_t)InputStream_readByte(self) << 8;
    value |= (uint64_t)InputStream_readByte(self) << 16;
    value |= (uint64_t)InputStream_readByte(self) << 24;
    value |= (uint64_t)InputStream_readByte(self) << 32;
    value |= (uint64_t)InputStream_readByte(self) << 40;
    value |= (uint64_t)InputStream_readByte(self) << 48;
    value |= (uint64_t)InputStream_readByte(self) << 56;
    return value;
}

static float InputStream_readLittle_f32(struct InputStream *self) {
    uint32_t value = InputStream_readLittle_u32(self);
    float result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static double InputStream_readLittle_f64(struct InputStream *self) {
    uint64_t value = InputStream_readLittle_u64(self);
    double result;
    memcpy(&result, &value, sizeof(result));
    return result;
}

static uint32_t InputStream_readLeb128_u32(struct InputStream *self) {
    uint32_t value = 0;
    uint8_t shift = 0;
    uint8_t byte;
    do {
        byte = InputStream_readByte(self);
        assert(shift < 32);
        value |= (uint32_t)(byte & 0x7F) << shift;
        shift += 7;
    } while (byte & 0x80);
    return value;
}

static int32_t InputStream_readLeb128_i32(struct InputStream *self) {
    uint32_t value = 0;
    uint8_t shift = 0;
    uint8_t byte;
    do {
        byte = InputStream_readByte(self);
        assert(shift < 64);
        value |= (uint32_t)(byte & 0x7F) << shift;
        shift += 7;
    } while (byte & 0x80);
    if (shift < 32) {
        uint32_t mask = -((uint32_t)1 << shift);
        if (byte & 0x40) value |= mask; else value &= ~mask;
    }
    return (int32_t)value;
}

static int64_t InputStream_readLeb128_u64(struct InputStream *self) {
    uint64_t value = 0;
    uint8_t shift = 0;
    uint8_t byte;
    do {
        byte = InputStream_readByte(self);
        assert(shift < 64);
        value |= (uint64_t)(byte & 0x7F) << shift;
        shift += 7;
    } while (byte & 0x80);
    return value;
}

static int64_t InputStream_readLeb128_i64(struct InputStream *self) {
    uint64_t value = 0;
    uint8_t shift = 0;
    uint8_t byte;
    do {
        byte = InputStream_readByte(self);
        assert(shift < 64);
        value |= (uint64_t)(byte & 0x7F) << shift;
        shift += 7;
    } while (byte & 0x80);
    if (shift < 64) {
        uint64_t mask = -((uint64_t)1 << shift);
        if (byte & 0x40) value |= mask; else value &= ~mask;
    }
    return (int64_t)value;
}

static char *InputStream_readName(struct InputStream *self) {
    uint32_t len = InputStream_readLeb128_u32(self);
    char *name = malloc(len + 1);
    if (name == NULL) panic("out of memory");
    for (uint32_t i = 0; i < len; ) {
        if (InputStream_atEnd(self)) panic("unexpected end of input stream");
        size_t remaining = self->out.pos - self->pos;
        if (remaining > len - i) remaining = len - i;
        memcpy(&name[i], &((char *)self->out.dst)[self->pos], remaining);
        i += remaining;
        self->pos += remaining;
    }
    name[len] = '\0';
    return name;
}

static void InputStream_skipBytes(struct InputStream *self, size_t len) {
    for (size_t i = 0; i < len; ) {
        if (InputStream_atEnd(self)) panic("unexpected end of input stream");
        size_t remaining = self->out.pos - self->pos;
        if (remaining > len - i) remaining = len - i;
        i += remaining;
        self->pos += remaining;
    }
}

static uint32_t InputStream_skipToSection(struct InputStream *self, uint8_t expected_id) {
    while (true) {
        uint8_t id = InputStream_readByte(self);
        uint32_t size = InputStream_readLeb128_u32(self);
        if (id == expected_id) return size;
        InputStream_skipBytes(self, size);
    }
}

struct ResultType {
    uint32_t len;
    int8_t types[1];
};
static struct ResultType *InputStream_readResultType(struct InputStream *self) {
    uint32_t len = InputStream_readLeb128_u32(self);
    struct ResultType *result_type = malloc(offsetof(struct ResultType, types) + sizeof(int8_t) * len);
    if (result_type == NULL) panic("out of memory");
    result_type->len = len;
    for (uint32_t i = 0; i < len; i += 1) {
        int64_t val_type = InputStream_readLeb128_i64(self);
        switch (val_type) {
            case WasmValType_i32: case WasmValType_i64:
            case WasmValType_f32: case WasmValType_f64:
                break;

            default: panic("unsupported valtype");
        }
        result_type->types[i] = val_type;
    }
    return result_type;
}

struct Limits {
    uint32_t min;
    uint32_t max;
};
static struct Limits InputStream_readLimits(struct InputStream *self) {
    struct Limits limits;
    uint8_t kind = InputStream_readByte(self);
    limits.min = InputStream_readLeb128_u32(self);
    switch (kind) {
        case 0x00: limits.max = UINT32_MAX; break;
        case 0x01: limits.max = InputStream_readLeb128_u32(self); break;
        default: panic("unsupported limit kind");
    }
    return limits;
}

#endif /* INPUT_STREAM_H */
