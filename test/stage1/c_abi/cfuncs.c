#include <inttypes.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

void zig_panic();

static void assert_or_panic(bool ok) {
    if (!ok) {
        zig_panic();
    }
}

void zig_u8(uint8_t);
void zig_u16(uint16_t);
void zig_u32(uint32_t);
void zig_u64(uint64_t);
void zig_i8(int8_t);
void zig_i16(int16_t);
void zig_i32(int32_t);
void zig_i64(int64_t);
void zig_five_integers(int32_t, int32_t, int32_t, int32_t, int32_t);

void zig_f32(float);
void zig_f64(double);
void zig_five_floats(float, float, float, float, float);

bool zig_ret_bool();
uint8_t zig_ret_u8();
uint16_t zig_ret_u16();
uint32_t zig_ret_u32();
uint64_t zig_ret_u64();
int8_t zig_ret_i8();
int16_t zig_ret_i16();
int32_t zig_ret_i32();
int64_t zig_ret_i64();

void zig_ptr(void *);

void zig_bool(bool);

struct BigStruct {
    uint64_t a;
    uint64_t b;
    uint64_t c;
    uint64_t d;
    uint8_t e;
};

void zig_big_struct(struct BigStruct);

union BigUnion {
    struct BigStruct a;
};

void zig_big_union(union BigUnion);

struct SmallStructInts {
    uint8_t a;
    uint8_t b;
    uint8_t c;
    uint8_t d;
};
void zig_small_struct_ints(struct SmallStructInts);

struct SplitStructInts {
    uint64_t a;
    uint8_t b;
    uint32_t c;
};
void zig_split_struct_ints(struct SplitStructInts);

struct BigStruct zig_big_struct_both(struct BigStruct);

typedef struct Vector3 {
    float x;
    float y;
    float z;
} Vector3;

typedef struct Vector5 {
    float x;
    float y;
    float z;
    float w;
    float q;
} Vector5;

void run_c_tests(void) {
    zig_u8(0xff);
    zig_u16(0xfffe);
    zig_u32(0xfffffffd);
    zig_u64(0xfffffffffffffffc);

    zig_i8(-1);
    zig_i16(-2);
    zig_i32(-3);
    zig_i64(-4);
    zig_five_integers(12, 34, 56, 78, 90);

    zig_f32(12.34f);
    zig_f64(56.78);
    zig_five_floats(1.0f, 2.0f, 3.0f, 4.0f, 5.0f);

    zig_ptr((void*)0xdeadbeefL);

    zig_bool(true);

    {
        struct BigStruct s = {1, 2, 3, 4, 5};
        zig_big_struct(s);
    }

    {
        struct SmallStructInts s = {1, 2, 3, 4};
        zig_small_struct_ints(s);
    }

    {
        struct SplitStructInts s = {1234, 100, 1337};
        zig_split_struct_ints(s);
    }

    {
        struct BigStruct s = {30, 31, 32, 33, 34};
        struct BigStruct res = zig_big_struct_both(s);
        assert_or_panic(res.a == 20);
        assert_or_panic(res.b == 21);
        assert_or_panic(res.c == 22);
        assert_or_panic(res.d == 23);
        assert_or_panic(res.e == 24);
    }

    {
        assert_or_panic(zig_ret_bool() == 1);

        assert_or_panic(zig_ret_u8() == 0xff);
        assert_or_panic(zig_ret_u16() == 0xffff);
        assert_or_panic(zig_ret_u32() == 0xffffffff);
        assert_or_panic(zig_ret_u64() == 0xffffffffffffffff);

        assert_or_panic(zig_ret_i8() == -1);
        assert_or_panic(zig_ret_i16() == -1);
        assert_or_panic(zig_ret_i32() == -1);
        assert_or_panic(zig_ret_i64() == -1);
    }
}

void c_u8(uint8_t x) {
    assert_or_panic(x == 0xff);
}

void c_u16(uint16_t x) {
    assert_or_panic(x == 0xfffe);
}

void c_u32(uint32_t x) {
    assert_or_panic(x == 0xfffffffd);
}

void c_u64(uint64_t x) {
    assert_or_panic(x == 0xfffffffffffffffcULL);
}

void c_i8(int8_t x) {
    assert_or_panic(x == -1);
}

void c_i16(int16_t x) {
    assert_or_panic(x == -2);
}

void c_i32(int32_t x) {
    assert_or_panic(x == -3);
}

void c_i64(int64_t x) {
    assert_or_panic(x == -4);
}

void c_f32(float x) {
    assert_or_panic(x == 12.34f);
}

void c_f64(double x) {
    assert_or_panic(x == 56.78);
}

void c_ptr(void *x) {
    assert_or_panic(x == (void*)0xdeadbeefL);
}

void c_bool(bool x) {
    assert_or_panic(x);
}

void c_five_integers(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e) {
    assert_or_panic(a == 12);
    assert_or_panic(b == 34);
    assert_or_panic(c == 56);
    assert_or_panic(d == 78);
    assert_or_panic(e == 90);
}

void c_five_floats(float a, float b, float c, float d, float e) {
    assert_or_panic(a == 1.0);
    assert_or_panic(b == 2.0);
    assert_or_panic(c == 3.0);
    assert_or_panic(d == 4.0);
    assert_or_panic(e == 5.0);
}

void c_big_struct(struct BigStruct x) {
    assert_or_panic(x.a == 1);
    assert_or_panic(x.b == 2);
    assert_or_panic(x.c == 3);
    assert_or_panic(x.d == 4);
    assert_or_panic(x.e == 5);
}

void c_big_union(union BigUnion x) {
    assert_or_panic(x.a.a == 1);
    assert_or_panic(x.a.b == 2);
    assert_or_panic(x.a.c == 3);
    assert_or_panic(x.a.d == 4);
}

void c_small_struct_ints(struct SmallStructInts x) {
    assert_or_panic(x.a == 1);
    assert_or_panic(x.b == 2);
    assert_or_panic(x.c == 3);
    assert_or_panic(x.d == 4);
}

void c_split_struct_ints(struct SplitStructInts x) {
    assert_or_panic(x.a == 1234);
    assert_or_panic(x.b == 100);
    assert_or_panic(x.c == 1337);
}

struct BigStruct c_big_struct_both(struct BigStruct x) {
    assert_or_panic(x.a == 1);
    assert_or_panic(x.b == 2);
    assert_or_panic(x.c == 3);
    assert_or_panic(x.d == 4);
    assert_or_panic(x.e == 5);
    struct BigStruct y = {10, 11, 12, 13, 14};
    return y;
}

void c_small_struct_floats(Vector3 vec) {
    assert_or_panic(vec.x == 3.0);
    assert_or_panic(vec.y == 6.0);
    assert_or_panic(vec.z == 12.0);
}

void c_small_struct_floats_extra(Vector3 vec, const char *str) {
    assert_or_panic(vec.x == 3.0);
    assert_or_panic(vec.y == 6.0);
    assert_or_panic(vec.z == 12.0);
    assert_or_panic(!strcmp(str, "hello"));
}

void c_big_struct_floats(Vector5 vec) {
    assert_or_panic(vec.x == 76.0);
    assert_or_panic(vec.y == -1.0);
    assert_or_panic(vec.z == -12.0);
    assert_or_panic(vec.w == 69);
    assert_or_panic(vec.q == 55);
}

bool c_ret_bool() {
    return 1;
}
uint8_t c_ret_u8() {
    return 0xff;
}
uint16_t c_ret_u16() {
    return 0xffff;
}
uint32_t c_ret_u32() {
    return 0xffffffff;
}
uint64_t c_ret_u64() {
    return 0xffffffffffffffff;
}
int8_t c_ret_i8() {
    return -1;
}
int16_t c_ret_i16() {
    return -1;
}
int32_t c_ret_i32() {
    return -1;
}
int64_t c_ret_i64() {
    return -1;
}
