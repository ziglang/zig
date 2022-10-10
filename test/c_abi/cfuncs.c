#include <inttypes.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <complex.h>

void zig_panic();

static void assert_or_panic(bool ok) {
    if (!ok) {
        zig_panic();
    }
}

struct i128 {
    __int128 value;
};

struct u128 {
    unsigned __int128 value;
};

void zig_u8(uint8_t);
void zig_u16(uint16_t);
void zig_u32(uint32_t);
void zig_u64(uint64_t);
void zig_struct_u128(struct u128);
void zig_i8(int8_t);
void zig_i16(int16_t);
void zig_i32(int32_t);
void zig_i64(int64_t);
void zig_struct_i128(struct i128);
void zig_five_integers(int32_t, int32_t, int32_t, int32_t, int32_t);

void zig_f32(float);
void zig_f64(double);
void zig_longdouble(long double);
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

// Note: These two functions match the signature of __mulsc3 and __muldc3 in compiler-rt (and libgcc)
float complex zig_cmultf_comp(float a_r, float a_i, float b_r, float b_i);
double complex zig_cmultd_comp(double a_r, double a_i, double b_r, double b_i);

float complex zig_cmultf(float complex a, float complex b);
double complex zig_cmultd(double complex a, double complex b);

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
struct SmallStructInts zig_ret_small_struct_ints();

struct MedStructMixed {
    uint32_t a;
    float b;
    float c;
    uint32_t d;
};

void zig_med_struct_mixed(struct MedStructMixed);
struct MedStructMixed zig_ret_med_struct_mixed();

void zig_small_packed_struct(uint8_t);
void zig_big_packed_struct(__int128);

struct SplitStructInts {
    uint64_t a;
    uint8_t b;
    uint32_t c;
};
void zig_split_struct_ints(struct SplitStructInts);

struct SplitStructMixed {
    uint64_t a;
    uint8_t b;
    float c;
};
void zig_split_struct_mixed(struct SplitStructMixed);
struct SplitStructMixed zig_ret_split_struct_mixed();

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

typedef struct Rect {
    uint32_t left;
    uint32_t right;
    uint32_t top;
    uint32_t bottom;
} Rect;

void zig_multiple_struct_ints(struct Rect, struct Rect);

typedef struct FloatRect {
    float left;
    float right;
    float top;
    float bottom;
} FloatRect;

void zig_multiple_struct_floats(struct FloatRect, struct FloatRect);

void run_c_tests(void) {
    zig_u8(0xff);
    zig_u16(0xfffe);
    zig_u32(0xfffffffd);
    zig_u64(0xfffffffffffffffc);
    {
        struct u128 s = {0xfffffffffffffffc};
        zig_struct_u128(s);
    }

    zig_i8(-1);
    zig_i16(-2);
    zig_i32(-3);
    zig_i64(-4);
    {
        struct i128 s = {-6};
        zig_struct_i128(s);
    }
    zig_five_integers(12, 34, 56, 78, 90);

    zig_f32(12.34f);
    zig_f64(56.78);
    zig_longdouble(12.34l);
    zig_five_floats(1.0f, 2.0f, 3.0f, 4.0f, 5.0f);

    zig_ptr((void*)0xdeadbeefL);

    zig_bool(true);

    // TODO: Resolve https://github.com/ziglang/zig/issues/8465
    //{
    //    float complex a = 1.25f + I * 2.6f;
    //    float complex b = 11.3f - I * 1.5f;
    //    float complex z = zig_cmultf(a, b);
    //    assert_or_panic(creal(z) == 1.5f);
    //    assert_or_panic(cimag(z) == 13.5f);
    //}

    {
        double complex a = 1.25 + I * 2.6;
        double complex b = 11.3 - I * 1.5;
        double complex z = zig_cmultd(a, b);
        assert_or_panic(creal(z) == 1.5);
        assert_or_panic(cimag(z) == 13.5);
    }

    {
        float a_r = 1.25f;
        float a_i = 2.6f;
        float b_r = 11.3f;
        float b_i = -1.5f;
        float complex z = zig_cmultf_comp(a_r, a_i, b_r, b_i);
        assert_or_panic(creal(z) == 1.5f);
        assert_or_panic(cimag(z) == 13.5f);
    }

    {
        double a_r = 1.25;
        double a_i = 2.6;
        double b_r = 11.3;
        double b_i = -1.5;
        double complex z = zig_cmultd_comp(a_r, a_i, b_r, b_i);
        assert_or_panic(creal(z) == 1.5);
        assert_or_panic(cimag(z) == 13.5);
    }

    {
        struct BigStruct s = {1, 2, 3, 4, 5};
        zig_big_struct(s);
    }

    {
        struct SmallStructInts s = {1, 2, 3, 4};
        zig_small_struct_ints(s);
    }

    {
        __int128 s = 0;
        s |= 1 << 0;
        s |= (__int128)2 << 64;
        zig_big_packed_struct(s);
    }

    {
        uint8_t s = 0;
        s |= 0 << 0;
        s |= 1 << 2;
        s |= 2 << 4;
        s |= 3 << 6;
        zig_small_packed_struct(s);
    }

    {
        struct SplitStructInts s = {1234, 100, 1337};
        zig_split_struct_ints(s);
    }

    {
        struct MedStructMixed s = {1234, 100.0f, 1337.0f};
        zig_med_struct_mixed(s);
    }

    {
        struct SplitStructMixed s = {1234, 100, 1337.0f};
        zig_split_struct_mixed(s);
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
        struct Rect r1 = {1, 21, 16, 4};
        struct Rect r2 = {178, 189, 21, 15};
        zig_multiple_struct_ints(r1, r2);
    }

    {
        struct FloatRect r1 = {1, 21, 16, 4};
        struct FloatRect r2 = {178, 189, 21, 15};
        zig_multiple_struct_floats(r1, r2);
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

void c_struct_u128(struct u128 x) {
    assert_or_panic(x.value == 0xfffffffffffffffcULL);
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

void c_struct_i128(struct i128 x) {
    assert_or_panic(x.value == -6);
}

void c_f32(float x) {
    assert_or_panic(x == 12.34f);
}

void c_f64(double x) {
    assert_or_panic(x == 56.78);
}

void c_long_double(long double x) {
    assert_or_panic(x == 12.34l);
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

float complex c_cmultf_comp(float a_r, float a_i, float b_r, float b_i) {
    assert_or_panic(a_r == 1.25f);
    assert_or_panic(a_i == 2.6f);
    assert_or_panic(b_r == 11.3f);
    assert_or_panic(b_i == -1.5f);

    return 1.5f + I * 13.5f;
}

double complex c_cmultd_comp(double a_r, double a_i, double b_r, double b_i) {
    assert_or_panic(a_r == 1.25);
    assert_or_panic(a_i == 2.6);
    assert_or_panic(b_r == 11.3);
    assert_or_panic(b_i == -1.5);

    return 1.5 + I * 13.5;
}

float complex c_cmultf(float complex a, float complex b) {
    assert_or_panic(creal(a) == 1.25f);
    assert_or_panic(cimag(a) == 2.6f);
    assert_or_panic(creal(b) == 11.3f);
    assert_or_panic(cimag(b) == -1.5f);

    return 1.5f + I * 13.5f;
}

double complex c_cmultd(double complex a, double complex b) {
    assert_or_panic(creal(a) == 1.25);
    assert_or_panic(cimag(a) == 2.6);
    assert_or_panic(creal(b) == 11.3);
    assert_or_panic(cimag(b) == -1.5);

    return 1.5 + I * 13.5;
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

    struct SmallStructInts y = zig_ret_small_struct_ints();

    assert_or_panic(y.a == 1);
    assert_or_panic(y.b == 2);
    assert_or_panic(y.c == 3);
    assert_or_panic(y.d == 4);
}

struct SmallStructInts c_ret_small_struct_ints() {
    struct SmallStructInts s = {
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
    return s;
}

void c_med_struct_mixed(struct MedStructMixed x) {
    assert_or_panic(x.a == 1234);
    assert_or_panic(x.b == 100.0f);
    assert_or_panic(x.c == 1337.0f);

    struct MedStructMixed y = zig_ret_med_struct_mixed();

    assert_or_panic(y.a == 1234);
    assert_or_panic(y.b == 100.0f);
    assert_or_panic(y.c == 1337.0f);
}

struct MedStructMixed c_ret_med_struct_mixed() {
    struct MedStructMixed s = {
        .a = 1234,
        .b = 100.0,
        .c = 1337.0,
    };
    return s;
}

void c_split_struct_ints(struct SplitStructInts x) {
    assert_or_panic(x.a == 1234);
    assert_or_panic(x.b == 100);
    assert_or_panic(x.c == 1337);
}

void c_split_struct_mixed(struct SplitStructMixed x) {
    assert_or_panic(x.a == 1234);
    assert_or_panic(x.b == 100);
    assert_or_panic(x.c == 1337.0f);
    struct SplitStructMixed y = zig_ret_split_struct_mixed();

    assert_or_panic(y.a == 1234);
    assert_or_panic(y.b == 100);
    assert_or_panic(y.c == 1337.0f);
}

uint8_t c_ret_small_packed_struct() {
    uint8_t s = 0;
    s |= 0 << 0;
    s |= 1 << 2;
    s |= 2 << 4;
    s |= 3 << 6;
    return s;
}

void c_small_packed_struct(uint8_t x) {
    assert_or_panic(((x >> 0) & 0x3) == 0);
    assert_or_panic(((x >> 2) & 0x3) == 1);
    assert_or_panic(((x >> 4) & 0x3) == 2);
    assert_or_panic(((x >> 6) & 0x3) == 3);
}

__int128 c_ret_big_packed_struct() {
    __int128 s = 0;
    s |= 1 << 0;
    s |= (__int128)2 << 64;
    return s;
}

void c_big_packed_struct(__int128 x) {
    assert_or_panic(((x >> 0) & 0xFFFFFFFFFFFFFFFF) == 1);
    assert_or_panic(((x >> 64) & 0xFFFFFFFFFFFFFFFF) == 2);
}

struct SplitStructMixed c_ret_split_struct_mixed() {
    struct SplitStructMixed s = {
        .a = 1234,
        .b = 100,
        .c = 1337.0f,
    };
    return s;
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

void c_multiple_struct_ints(Rect x, Rect y) {
    assert_or_panic(x.left == 1);
    assert_or_panic(x.right == 21);
    assert_or_panic(x.top == 16);
    assert_or_panic(x.bottom == 4);
    assert_or_panic(y.left == 178);
    assert_or_panic(y.right == 189);
    assert_or_panic(y.top == 21);
    assert_or_panic(y.bottom == 15);
}

void c_multiple_struct_floats(FloatRect x, FloatRect y) {
    assert_or_panic(x.left == 1);
    assert_or_panic(x.right == 21);
    assert_or_panic(x.top == 16);
    assert_or_panic(x.bottom == 4);
    assert_or_panic(y.left == 178);
    assert_or_panic(y.right == 189);
    assert_or_panic(y.top == 21);
    assert_or_panic(y.bottom == 15);
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
