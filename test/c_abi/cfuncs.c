#include <complex.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

void zig_panic(void);

static void assert_or_panic(bool ok) {
    if (!ok) {
        zig_panic();
    }
}

#if defined __powerpc__ && !defined _ARCH_PPC64
#  define ZIG_PPC32
#endif

#ifdef __riscv
#  ifdef _ILP32
#    define ZIG_RISCV32
#  else
#    define ZIG_RISCV64
#  endif
#endif

#if defined(__aarch64__) && defined(__linux__)
// TODO: https://github.com/ziglang/zig/issues/14908
#define ZIG_BUG_14908
#endif

#ifdef __i386__
#  define ZIG_NO_I128
#endif

#ifdef __arm__
#  define ZIG_NO_I128
#endif

#ifdef __mips__
#  define ZIG_NO_I128
#endif

#ifdef ZIG_PPC32
#  define ZIG_NO_I128
#endif

#ifdef ZIG_RISCV32
#  define ZIG_NO_I128
#endif

#ifdef __i386__
#  define ZIG_NO_COMPLEX
#endif

#ifdef __mips__
#  define ZIG_NO_COMPLEX
#endif

#ifdef __arm__
#  define ZIG_NO_COMPLEX
#endif

#ifdef __powerpc__
#  define ZIG_NO_COMPLEX
#endif

#ifdef __riscv
#  define ZIG_NO_COMPLEX
#endif

#ifdef __x86_64__
#define ZIG_NO_RAW_F16
#endif

#ifdef __i386__
#define ZIG_NO_RAW_F16
#endif

#ifdef __mips__
#define ZIG_NO_RAW_F16
#endif

#ifdef __riscv
#define ZIG_NO_RAW_F16
#endif

#ifdef __wasm__
#define ZIG_NO_RAW_F16
#endif

#ifdef __powerpc__
#define ZIG_NO_RAW_F16
#endif

#ifdef __aarch64__
#define ZIG_NO_F128
#endif

#ifdef __arm__
#define ZIG_NO_F128
#endif

#ifdef __mips__
#define ZIG_NO_F128
#endif

#ifdef __riscv
#define ZIG_NO_F128
#endif

#ifdef __powerpc__
#define ZIG_NO_F128
#endif

#ifdef __APPLE__
#define ZIG_NO_F128
#endif

#ifndef ZIG_NO_I128
struct i128 {
    __int128 value;
};

struct u128 {
    unsigned __int128 value;
};
#endif

void zig_u8(uint8_t);
void zig_u16(uint16_t);
void zig_u32(uint32_t);
void zig_u64(uint64_t);
#ifndef ZIG_NO_I128
void zig_struct_u128(struct u128);
#endif
void zig_i8(int8_t);
void zig_i16(int16_t);
void zig_i32(int32_t);
void zig_i64(int64_t);
#ifndef ZIG_NO_I128
void zig_struct_i128(struct i128);
#endif
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

struct Struct_u64_u64 {
    uint64_t a;
    uint64_t b;
};

struct Struct_u64_u64 zig_ret_struct_u64_u64(void);

void zig_struct_u64_u64_0(struct Struct_u64_u64);
void zig_struct_u64_u64_1(size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_2(size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_3(size_t, size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_4(size_t, size_t, size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_5(size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_6(size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_7(size_t, size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64);
void zig_struct_u64_u64_8(size_t, size_t, size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64);

struct Struct_u64_u64 c_ret_struct_u64_u64(void) {
    return (struct Struct_u64_u64){ 21, 22 };
}

void c_struct_u64_u64_0(struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 23);
    assert_or_panic(s.b == 24);
}
void c_struct_u64_u64_1(size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 25);
    assert_or_panic(s.b == 26);
}
void c_struct_u64_u64_2(size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 27);
    assert_or_panic(s.b == 28);
}
void c_struct_u64_u64_3(size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 29);
    assert_or_panic(s.b == 30);
}
void c_struct_u64_u64_4(size_t, size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 31);
    assert_or_panic(s.b == 32);
}
void c_struct_u64_u64_5(size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 33);
    assert_or_panic(s.b == 34);
}
void c_struct_u64_u64_6(size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 35);
    assert_or_panic(s.b == 36);
}
void c_struct_u64_u64_7(size_t, size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 37);
    assert_or_panic(s.b == 38);
}
void c_struct_u64_u64_8(size_t, size_t, size_t, size_t, size_t, size_t, size_t, size_t, struct Struct_u64_u64 s) {
    assert_or_panic(s.a == 39);
    assert_or_panic(s.b == 40);
}

struct Struct_f32f32_f32 {
    struct {
        float b, c;
    } a;
    float d;
};

struct Struct_f32f32_f32 zig_ret_struct_f32f32_f32(void);

void zig_struct_f32f32_f32(struct Struct_f32f32_f32);

struct Struct_f32f32_f32 c_ret_struct_f32f32_f32(void) {
    return (struct Struct_f32f32_f32){ { 1.0f, 2.0f }, 3.0f };
}

void c_struct_f32f32_f32(struct Struct_f32f32_f32 s) {
    assert_or_panic(s.a.b == 1.0f);
    assert_or_panic(s.a.c == 2.0f);
    assert_or_panic(s.d == 3.0f);
}

struct Struct_f32_f32f32 {
    float a;
    struct {
        float c, d;
    } b;
};

struct Struct_f32_f32f32 zig_ret_struct_f32_f32f32(void);

void zig_struct_f32_f32f32(struct Struct_f32_f32f32);

struct Struct_f32_f32f32 c_ret_struct_f32_f32f32(void) {
    return (struct Struct_f32_f32f32){ 1.0f, { 2.0f, 3.0f } };
}

void c_struct_f32_f32f32(struct Struct_f32_f32f32 s) {
    assert_or_panic(s.a == 1.0f);
    assert_or_panic(s.b.c == 2.0f);
    assert_or_panic(s.b.d == 3.0f);
}

struct Struct_u32_Union_u32_u32u32 {
    uint32_t a;
    union {
        struct {
            uint32_t d, e;
        } c;
    } b;
};

struct Struct_u32_Union_u32_u32u32 zig_ret_struct_u32_union_u32_u32u32(void);

void zig_struct_u32_union_u32_u32u32(struct Struct_u32_Union_u32_u32u32);

struct Struct_u32_Union_u32_u32u32 c_ret_struct_u32_union_u32_u32u32(void) {
    struct Struct_u32_Union_u32_u32u32 s;
    s.a = 1;
    s.b.c.d = 2;
    s.b.c.e = 3;
    return s;
}

void c_struct_u32_union_u32_u32u32(struct Struct_u32_Union_u32_u32u32 s) {
    assert_or_panic(s.a == 1);
    assert_or_panic(s.b.c.d == 2);
    assert_or_panic(s.b.c.e == 3);
}

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

struct MedStructInts {
    int32_t x;
    int32_t y;
    int32_t z;
};

void zig_med_struct_ints(struct MedStructInts);
struct MedStructInts zig_ret_med_struct_ints();

struct MedStructMixed {
    uint32_t a;
    float b;
    float c;
    uint32_t d;
};

void zig_med_struct_mixed(struct MedStructMixed);
struct MedStructMixed zig_ret_med_struct_mixed();

void zig_small_packed_struct(uint8_t);
#ifndef ZIG_NO_I128
void zig_big_packed_struct(__int128);
#endif

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

typedef float Vector2Float __attribute__((ext_vector_type(2)));
typedef float Vector4Float __attribute__((ext_vector_type(4)));

void c_vector_2_float(Vector2Float vec) {
    assert_or_panic(vec[0] == 1.0);
    assert_or_panic(vec[1] == 2.0);
}

void c_vector_4_float(Vector4Float vec) {
    assert_or_panic(vec[0] == 1.0);
    assert_or_panic(vec[1] == 2.0);
    assert_or_panic(vec[2] == 3.0);
    assert_or_panic(vec[3] == 4.0);
}

Vector2Float c_ret_vector_2_float(void) {
    return (Vector2Float){
        1.0,
        2.0,
    };
}
Vector4Float c_ret_vector_4_float(void) {
    return (Vector4Float){
        1.0,
        2.0,
        3.0,
        4.0,
    };
}

#if defined(ZIG_BACKEND_STAGE2_X86_64) || defined(ZIG_PPC32) || defined(__wasm__)

typedef bool Vector2Bool __attribute__((ext_vector_type(2)));
typedef bool Vector4Bool __attribute__((ext_vector_type(4)));
typedef bool Vector8Bool __attribute__((ext_vector_type(8)));
typedef bool Vector16Bool __attribute__((ext_vector_type(16)));
typedef bool Vector32Bool __attribute__((ext_vector_type(32)));
typedef bool Vector64Bool __attribute__((ext_vector_type(64)));
typedef bool Vector128Bool __attribute__((ext_vector_type(128)));
typedef bool Vector256Bool __attribute__((ext_vector_type(256)));
typedef bool Vector512Bool __attribute__((ext_vector_type(512)));

void c_vector_2_bool(Vector2Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == true);
}

void c_vector_4_bool(Vector4Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == true);
    assert_or_panic(vec[2] == false);
    assert_or_panic(vec[3] == true);
}

void c_vector_8_bool(Vector8Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == false);
    assert_or_panic(vec[2] == true);
    assert_or_panic(vec[3] == true);
    assert_or_panic(vec[4] == true);
    assert_or_panic(vec[5] == true);
    assert_or_panic(vec[6] == false);
    assert_or_panic(vec[7] == true);
}

void c_vector_16_bool(Vector16Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == false);
    assert_or_panic(vec[2] == false);
    assert_or_panic(vec[3] == false);
    assert_or_panic(vec[4] == true);
    assert_or_panic(vec[5] == false);
    assert_or_panic(vec[6] == true);
    assert_or_panic(vec[7] == true);
    assert_or_panic(vec[8] == true);
    assert_or_panic(vec[9] == true);
    assert_or_panic(vec[10] == true);
    assert_or_panic(vec[11] == true);
    assert_or_panic(vec[12] == false);
    assert_or_panic(vec[13] == false);
    assert_or_panic(vec[14] == false);
    assert_or_panic(vec[15] == false);
}

void c_vector_32_bool(Vector32Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == false);
    assert_or_panic(vec[2] == true);
    assert_or_panic(vec[3] == true);
    assert_or_panic(vec[4] == false);
    assert_or_panic(vec[5] == false);
    assert_or_panic(vec[6] == true);
    assert_or_panic(vec[7] == false);
    assert_or_panic(vec[8] == true);
    assert_or_panic(vec[9] == false);
    assert_or_panic(vec[10] == true);
    assert_or_panic(vec[11] == true);
    assert_or_panic(vec[12] == true);
    assert_or_panic(vec[13] == false);
    assert_or_panic(vec[14] == false);
    assert_or_panic(vec[15] == true);
    assert_or_panic(vec[16] == false);
    assert_or_panic(vec[17] == true);
    assert_or_panic(vec[18] == false);
    assert_or_panic(vec[19] == true);
    assert_or_panic(vec[20] == true);
    assert_or_panic(vec[21] == true);
    assert_or_panic(vec[22] == true);
    assert_or_panic(vec[23] == true);
    assert_or_panic(vec[24] == false);
    assert_or_panic(vec[25] == true);
    assert_or_panic(vec[26] == true);
    assert_or_panic(vec[27] == true);
    assert_or_panic(vec[28] == false);
    assert_or_panic(vec[29] == true);
    assert_or_panic(vec[30] == true);
    assert_or_panic(vec[31] == false);
}

void c_vector_64_bool(Vector64Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == true);
    assert_or_panic(vec[2] == true);
    assert_or_panic(vec[3] == false);
    assert_or_panic(vec[4] == true);
    assert_or_panic(vec[5] == false);
    assert_or_panic(vec[6] == false);
    assert_or_panic(vec[7] == false);
    assert_or_panic(vec[8] == true);
    assert_or_panic(vec[9] == false);
    assert_or_panic(vec[10] == false);
    assert_or_panic(vec[11] == false);
    assert_or_panic(vec[12] == false);
    assert_or_panic(vec[13] == true);
    assert_or_panic(vec[14] == true);
    assert_or_panic(vec[15] == true);
    assert_or_panic(vec[16] == true);
    assert_or_panic(vec[17] == false);
    assert_or_panic(vec[18] == false);
    assert_or_panic(vec[19] == true);
    assert_or_panic(vec[20] == false);
    assert_or_panic(vec[21] == true);
    assert_or_panic(vec[22] == false);
    assert_or_panic(vec[23] == true);
    assert_or_panic(vec[24] == true);
    assert_or_panic(vec[25] == true);
    assert_or_panic(vec[26] == true);
    assert_or_panic(vec[27] == true);
    assert_or_panic(vec[28] == true);
    assert_or_panic(vec[29] == true);
    assert_or_panic(vec[30] == false);
    assert_or_panic(vec[31] == false);
    assert_or_panic(vec[32] == true);
    assert_or_panic(vec[33] == true);
    assert_or_panic(vec[34] == false);
    assert_or_panic(vec[35] == true);
    assert_or_panic(vec[36] == false);
    assert_or_panic(vec[37] == false);
    assert_or_panic(vec[38] == true);
    assert_or_panic(vec[39] == true);
    assert_or_panic(vec[40] == true);
    assert_or_panic(vec[41] == false);
    assert_or_panic(vec[42] == false);
    assert_or_panic(vec[43] == true);
    assert_or_panic(vec[44] == true);
    assert_or_panic(vec[45] == false);
    assert_or_panic(vec[46] == true);
    assert_or_panic(vec[47] == false);
    assert_or_panic(vec[48] == true);
    assert_or_panic(vec[49] == false);
    assert_or_panic(vec[50] == false);
    assert_or_panic(vec[51] == true);
    assert_or_panic(vec[52] == false);
    assert_or_panic(vec[53] == true);
    assert_or_panic(vec[54] == true);
    assert_or_panic(vec[55] == true);
    assert_or_panic(vec[56] == true);
    assert_or_panic(vec[57] == true);
    assert_or_panic(vec[58] == false);
    assert_or_panic(vec[59] == false);
    assert_or_panic(vec[60] == true);
    assert_or_panic(vec[61] == false);
    assert_or_panic(vec[62] == true);
    assert_or_panic(vec[63] == false);
}

void c_vector_128_bool(Vector128Bool vec) {
    assert_or_panic(vec[0] == false);
    assert_or_panic(vec[1] == false);
    assert_or_panic(vec[2] == false);
    assert_or_panic(vec[3] == false);
    assert_or_panic(vec[4] == false);
    assert_or_panic(vec[5] == true);
    assert_or_panic(vec[6] == true);
    assert_or_panic(vec[7] == false);
    assert_or_panic(vec[8] == true);
    assert_or_panic(vec[9] == true);
    assert_or_panic(vec[10] == false);
    assert_or_panic(vec[11] == true);
    assert_or_panic(vec[12] == true);
    assert_or_panic(vec[13] == false);
    assert_or_panic(vec[14] == true);
    assert_or_panic(vec[15] == true);
    assert_or_panic(vec[16] == true);
    assert_or_panic(vec[17] == false);
    assert_or_panic(vec[18] == false);
    assert_or_panic(vec[19] == false);
    assert_or_panic(vec[20] == false);
    assert_or_panic(vec[21] == true);
    assert_or_panic(vec[22] == true);
    assert_or_panic(vec[23] == false);
    assert_or_panic(vec[24] == false);
    assert_or_panic(vec[25] == false);
    assert_or_panic(vec[26] == true);
    assert_or_panic(vec[27] == true);
    assert_or_panic(vec[28] == false);
    assert_or_panic(vec[29] == true);
    assert_or_panic(vec[30] == false);
    assert_or_panic(vec[31] == false);
    assert_or_panic(vec[32] == true);
    assert_or_panic(vec[33] == false);
    assert_or_panic(vec[34] == false);
    assert_or_panic(vec[35] == true);
    assert_or_panic(vec[36] == true);
    assert_or_panic(vec[37] == true);
    assert_or_panic(vec[38] == true);
    assert_or_panic(vec[39] == true);
    assert_or_panic(vec[40] == false);
    assert_or_panic(vec[41] == true);
    assert_or_panic(vec[42] == true);
    assert_or_panic(vec[43] == true);
    assert_or_panic(vec[44] == false);
    assert_or_panic(vec[45] == false);
    assert_or_panic(vec[46] == false);
    assert_or_panic(vec[47] == false);
    assert_or_panic(vec[48] == true);
    assert_or_panic(vec[49] == true);
    assert_or_panic(vec[50] == false);
    assert_or_panic(vec[51] == true);
    assert_or_panic(vec[52] == true);
    assert_or_panic(vec[53] == true);
    assert_or_panic(vec[54] == true);
    assert_or_panic(vec[55] == true);
    assert_or_panic(vec[56] == false);
    assert_or_panic(vec[57] == true);
    assert_or_panic(vec[58] == true);
    assert_or_panic(vec[59] == false);
    assert_or_panic(vec[60] == true);
    assert_or_panic(vec[61] == false);
    assert_or_panic(vec[62] == false);
    assert_or_panic(vec[63] == true);
    assert_or_panic(vec[64] == true);
    assert_or_panic(vec[65] == false);
    assert_or_panic(vec[66] == true);
    assert_or_panic(vec[67] == true);
    assert_or_panic(vec[68] == false);
    assert_or_panic(vec[69] == true);
    assert_or_panic(vec[70] == false);
    assert_or_panic(vec[71] == false);
    assert_or_panic(vec[72] == true);
    assert_or_panic(vec[73] == true);
    assert_or_panic(vec[74] == false);
    assert_or_panic(vec[75] == true);
    assert_or_panic(vec[76] == true);
    assert_or_panic(vec[77] == true);
    assert_or_panic(vec[78] == false);
    assert_or_panic(vec[79] == true);
    assert_or_panic(vec[80] == false);
    assert_or_panic(vec[81] == false);
    assert_or_panic(vec[82] == false);
    assert_or_panic(vec[83] == false);
    assert_or_panic(vec[84] == true);
    assert_or_panic(vec[85] == false);
    assert_or_panic(vec[86] == false);
    assert_or_panic(vec[87] == false);
    assert_or_panic(vec[88] == true);
    assert_or_panic(vec[89] == true);
    assert_or_panic(vec[90] == false);
    assert_or_panic(vec[91] == false);
    assert_or_panic(vec[92] == true);
    assert_or_panic(vec[93] == true);
    assert_or_panic(vec[94] == true);
    assert_or_panic(vec[95] == true);
    assert_or_panic(vec[96] == false);
    assert_or_panic(vec[97] == false);
    assert_or_panic(vec[98] == false);
    assert_or_panic(vec[99] == false);
    assert_or_panic(vec[100] == false);
    assert_or_panic(vec[101] == true);
    assert_or_panic(vec[102] == false);
    assert_or_panic(vec[103] == false);
    assert_or_panic(vec[104] == false);
    assert_or_panic(vec[105] == false);
    assert_or_panic(vec[106] == true);
    assert_or_panic(vec[107] == true);
    assert_or_panic(vec[108] == true);
    assert_or_panic(vec[109] == true);
    assert_or_panic(vec[110] == true);
    assert_or_panic(vec[111] == false);
    assert_or_panic(vec[112] == false);
    assert_or_panic(vec[113] == true);
    assert_or_panic(vec[114] == false);
    assert_or_panic(vec[115] == true);
    assert_or_panic(vec[116] == false);
    assert_or_panic(vec[117] == false);
    assert_or_panic(vec[118] == true);
    assert_or_panic(vec[119] == false);
    assert_or_panic(vec[120] == true);
    assert_or_panic(vec[121] == false);
    assert_or_panic(vec[122] == true);
    assert_or_panic(vec[123] == true);
    assert_or_panic(vec[124] == true);
    assert_or_panic(vec[125] == true);
    assert_or_panic(vec[126] == true);
    assert_or_panic(vec[127] == true);
}

// WASM: The following vector functions define too many Wasm locals for wasmtime in debug mode and are therefore disabled for the wasm target.
#if !defined(__wasm__)

void c_vector_256_bool(Vector256Bool vec) {
    assert_or_panic(vec[0] == false);
    assert_or_panic(vec[1] == true);
    assert_or_panic(vec[2] == true);
    assert_or_panic(vec[3] == false);
    assert_or_panic(vec[4] == false);
    assert_or_panic(vec[5] == true);
    assert_or_panic(vec[6] == true);
    assert_or_panic(vec[7] == true);
    assert_or_panic(vec[8] == false);
    assert_or_panic(vec[9] == true);
    assert_or_panic(vec[10] == true);
    assert_or_panic(vec[11] == true);
    assert_or_panic(vec[12] == false);
    assert_or_panic(vec[13] == true);
    assert_or_panic(vec[14] == false);
    assert_or_panic(vec[15] == true);
    assert_or_panic(vec[16] == false);
    assert_or_panic(vec[17] == false);
    assert_or_panic(vec[18] == true);
    assert_or_panic(vec[19] == true);
    assert_or_panic(vec[20] == false);
    assert_or_panic(vec[21] == true);
    assert_or_panic(vec[22] == false);
    assert_or_panic(vec[23] == false);
    assert_or_panic(vec[24] == false);
    assert_or_panic(vec[25] == true);
    assert_or_panic(vec[26] == true);
    assert_or_panic(vec[27] == false);
    assert_or_panic(vec[28] == false);
    assert_or_panic(vec[29] == true);
    assert_or_panic(vec[30] == true);
    assert_or_panic(vec[31] == false);
    assert_or_panic(vec[32] == true);
    assert_or_panic(vec[33] == false);
    assert_or_panic(vec[34] == false);
    assert_or_panic(vec[35] == true);
    assert_or_panic(vec[36] == false);
    assert_or_panic(vec[37] == true);
    assert_or_panic(vec[38] == false);
    assert_or_panic(vec[39] == true);
    assert_or_panic(vec[40] == true);
    assert_or_panic(vec[41] == true);
    assert_or_panic(vec[42] == true);
    assert_or_panic(vec[43] == false);
    assert_or_panic(vec[44] == false);
    assert_or_panic(vec[45] == true);
    assert_or_panic(vec[46] == false);
    assert_or_panic(vec[47] == false);
    assert_or_panic(vec[48] == false);
    assert_or_panic(vec[49] == false);
    assert_or_panic(vec[50] == false);
    assert_or_panic(vec[51] == false);
    assert_or_panic(vec[52] == true);
    assert_or_panic(vec[53] == true);
    assert_or_panic(vec[54] == true);
    assert_or_panic(vec[55] == true);
    assert_or_panic(vec[56] == true);
    assert_or_panic(vec[57] == true);
    assert_or_panic(vec[58] == false);
    assert_or_panic(vec[59] == true);
    assert_or_panic(vec[60] == true);
    assert_or_panic(vec[61] == false);
    assert_or_panic(vec[62] == false);
    assert_or_panic(vec[63] == true);
    assert_or_panic(vec[64] == false);
    assert_or_panic(vec[65] == false);
    assert_or_panic(vec[66] == false);
    assert_or_panic(vec[67] == false);
    assert_or_panic(vec[68] == false);
    assert_or_panic(vec[69] == false);
    assert_or_panic(vec[70] == true);
    assert_or_panic(vec[71] == true);
    assert_or_panic(vec[72] == true);
    assert_or_panic(vec[73] == false);
    assert_or_panic(vec[74] == false);
    assert_or_panic(vec[75] == false);
    assert_or_panic(vec[76] == true);
    assert_or_panic(vec[77] == false);
    assert_or_panic(vec[78] == true);
    assert_or_panic(vec[79] == true);
    assert_or_panic(vec[80] == false);
    assert_or_panic(vec[81] == false);
    assert_or_panic(vec[82] == true);
    assert_or_panic(vec[83] == true);
    assert_or_panic(vec[84] == false);
    assert_or_panic(vec[85] == true);
    assert_or_panic(vec[86] == true);
    assert_or_panic(vec[87] == true);
    assert_or_panic(vec[88] == true);
    assert_or_panic(vec[89] == true);
    assert_or_panic(vec[90] == true);
    assert_or_panic(vec[91] == true);
    assert_or_panic(vec[92] == false);
    assert_or_panic(vec[93] == true);
    assert_or_panic(vec[94] == true);
    assert_or_panic(vec[95] == false);
    assert_or_panic(vec[96] == false);
    assert_or_panic(vec[97] == true);
    assert_or_panic(vec[98] == true);
    assert_or_panic(vec[99] == false);
    assert_or_panic(vec[100] == true);
    assert_or_panic(vec[101] == false);
    assert_or_panic(vec[102] == false);
    assert_or_panic(vec[103] == true);
    assert_or_panic(vec[104] == false);
    assert_or_panic(vec[105] == true);
    assert_or_panic(vec[106] == true);
    assert_or_panic(vec[107] == true);
    assert_or_panic(vec[108] == true);
    assert_or_panic(vec[109] == true);
    assert_or_panic(vec[110] == false);
    assert_or_panic(vec[111] == false);
    assert_or_panic(vec[112] == false);
    assert_or_panic(vec[113] == false);
    assert_or_panic(vec[114] == true);
    assert_or_panic(vec[115] == true);
    assert_or_panic(vec[116] == false);
    assert_or_panic(vec[117] == true);
    assert_or_panic(vec[118] == false);
    assert_or_panic(vec[119] == false);
    assert_or_panic(vec[120] == true);
    assert_or_panic(vec[121] == false);
    assert_or_panic(vec[122] == false);
    assert_or_panic(vec[123] == true);
    assert_or_panic(vec[124] == false);
    assert_or_panic(vec[125] == true);
    assert_or_panic(vec[126] == true);
    assert_or_panic(vec[127] == true);
    assert_or_panic(vec[128] == true);
    assert_or_panic(vec[129] == false);
    assert_or_panic(vec[130] == true);
    assert_or_panic(vec[131] == true);
    assert_or_panic(vec[132] == false);
    assert_or_panic(vec[133] == false);
    assert_or_panic(vec[134] == true);
    assert_or_panic(vec[135] == false);
    assert_or_panic(vec[136] == false);
    assert_or_panic(vec[137] == true);
    assert_or_panic(vec[138] == false);
    assert_or_panic(vec[139] == true);
    assert_or_panic(vec[140] == false);
    assert_or_panic(vec[141] == true);
    assert_or_panic(vec[142] == true);
    assert_or_panic(vec[143] == true);
    assert_or_panic(vec[144] == true);
    assert_or_panic(vec[145] == false);
    assert_or_panic(vec[146] == true);
    assert_or_panic(vec[147] == false);
    assert_or_panic(vec[148] == false);
    assert_or_panic(vec[149] == false);
    assert_or_panic(vec[150] == true);
    assert_or_panic(vec[151] == true);
    assert_or_panic(vec[152] == true);
    assert_or_panic(vec[153] == true);
    assert_or_panic(vec[154] == true);
    assert_or_panic(vec[155] == false);
    assert_or_panic(vec[156] == true);
    assert_or_panic(vec[157] == false);
    assert_or_panic(vec[158] == false);
    assert_or_panic(vec[159] == false);
    assert_or_panic(vec[160] == true);
    assert_or_panic(vec[161] == true);
    assert_or_panic(vec[162] == false);
    assert_or_panic(vec[163] == true);
    assert_or_panic(vec[164] == true);
    assert_or_panic(vec[165] == false);
    assert_or_panic(vec[166] == false);
    assert_or_panic(vec[167] == false);
    assert_or_panic(vec[168] == false);
    assert_or_panic(vec[169] == true);
    assert_or_panic(vec[170] == false);
    assert_or_panic(vec[171] == true);
    assert_or_panic(vec[172] == false);
    assert_or_panic(vec[173] == false);
    assert_or_panic(vec[174] == false);
    assert_or_panic(vec[175] == false);
    assert_or_panic(vec[176] == true);
    assert_or_panic(vec[177] == true);
    assert_or_panic(vec[178] == true);
    assert_or_panic(vec[179] == false);
    assert_or_panic(vec[180] == true);
    assert_or_panic(vec[181] == false);
    assert_or_panic(vec[182] == true);
    assert_or_panic(vec[183] == true);
    assert_or_panic(vec[184] == false);
    assert_or_panic(vec[185] == false);
    assert_or_panic(vec[186] == true);
    assert_or_panic(vec[187] == false);
    assert_or_panic(vec[188] == false);
    assert_or_panic(vec[189] == false);
    assert_or_panic(vec[190] == false);
    assert_or_panic(vec[191] == true);
    assert_or_panic(vec[192] == true);
    assert_or_panic(vec[193] == true);
    assert_or_panic(vec[194] == true);
    assert_or_panic(vec[195] == true);
    assert_or_panic(vec[196] == true);
    assert_or_panic(vec[197] == true);
    assert_or_panic(vec[198] == false);
    assert_or_panic(vec[199] == true);
    assert_or_panic(vec[200] == false);
    assert_or_panic(vec[201] == false);
    assert_or_panic(vec[202] == true);
    assert_or_panic(vec[203] == false);
    assert_or_panic(vec[204] == true);
    assert_or_panic(vec[205] == true);
    assert_or_panic(vec[206] == true);
    assert_or_panic(vec[207] == false);
    assert_or_panic(vec[208] == false);
    assert_or_panic(vec[209] == true);
    assert_or_panic(vec[210] == true);
    assert_or_panic(vec[211] == true);
    assert_or_panic(vec[212] == false);
    assert_or_panic(vec[213] == true);
    assert_or_panic(vec[214] == true);
    assert_or_panic(vec[215] == true);
    assert_or_panic(vec[216] == true);
    assert_or_panic(vec[217] == true);
    assert_or_panic(vec[218] == false);
    assert_or_panic(vec[219] == false);
    assert_or_panic(vec[220] == false);
    assert_or_panic(vec[221] == false);
    assert_or_panic(vec[222] == false);
    assert_or_panic(vec[223] == true);
    assert_or_panic(vec[224] == true);
    assert_or_panic(vec[225] == false);
    assert_or_panic(vec[226] == true);
    assert_or_panic(vec[227] == false);
    assert_or_panic(vec[228] == false);
    assert_or_panic(vec[229] == true);
    assert_or_panic(vec[230] == false);
    assert_or_panic(vec[231] == true);
    assert_or_panic(vec[232] == false);
    assert_or_panic(vec[233] == false);
    assert_or_panic(vec[234] == false);
    assert_or_panic(vec[235] == true);
    assert_or_panic(vec[236] == false);
    assert_or_panic(vec[237] == false);
    assert_or_panic(vec[238] == false);
    assert_or_panic(vec[239] == true);
    assert_or_panic(vec[240] == true);
    assert_or_panic(vec[241] == true);
    assert_or_panic(vec[242] == true);
    assert_or_panic(vec[243] == true);
    assert_or_panic(vec[244] == true);
    assert_or_panic(vec[245] == false);
    assert_or_panic(vec[246] == false);
    assert_or_panic(vec[247] == true);
    assert_or_panic(vec[248] == false);
    assert_or_panic(vec[249] == true);
    assert_or_panic(vec[250] == true);
    assert_or_panic(vec[251] == false);
    assert_or_panic(vec[252] == true);
    assert_or_panic(vec[253] == true);
    assert_or_panic(vec[254] == true);
    assert_or_panic(vec[255] == false);
}

void c_vector_512_bool(Vector512Bool vec) {
    assert_or_panic(vec[0] == true);
    assert_or_panic(vec[1] == true);
    assert_or_panic(vec[2] == true);
    assert_or_panic(vec[3] == true);
    assert_or_panic(vec[4] == true);
    assert_or_panic(vec[5] == false);
    assert_or_panic(vec[6] == false);
    assert_or_panic(vec[7] == true);
    assert_or_panic(vec[8] == true);
    assert_or_panic(vec[9] == true);
    assert_or_panic(vec[10] == true);
    assert_or_panic(vec[11] == false);
    assert_or_panic(vec[12] == true);
    assert_or_panic(vec[13] == true);
    assert_or_panic(vec[14] == false);
    assert_or_panic(vec[15] == false);
    assert_or_panic(vec[16] == false);
    assert_or_panic(vec[17] == true);
    assert_or_panic(vec[18] == true);
    assert_or_panic(vec[19] == true);
    assert_or_panic(vec[20] == true);
    assert_or_panic(vec[21] == true);
    assert_or_panic(vec[22] == false);
    assert_or_panic(vec[23] == false);
    assert_or_panic(vec[24] == true);
    assert_or_panic(vec[25] == true);
    assert_or_panic(vec[26] == false);
    assert_or_panic(vec[27] == false);
    assert_or_panic(vec[28] == false);
    assert_or_panic(vec[29] == false);
    assert_or_panic(vec[30] == false);
    assert_or_panic(vec[31] == true);
    assert_or_panic(vec[32] == true);
    assert_or_panic(vec[33] == false);
    assert_or_panic(vec[34] == true);
    assert_or_panic(vec[35] == true);
    assert_or_panic(vec[36] == true);
    assert_or_panic(vec[37] == true);
    assert_or_panic(vec[38] == true);
    assert_or_panic(vec[39] == true);
    assert_or_panic(vec[40] == false);
    assert_or_panic(vec[41] == true);
    assert_or_panic(vec[42] == true);
    assert_or_panic(vec[43] == false);
    assert_or_panic(vec[44] == false);
    assert_or_panic(vec[45] == false);
    assert_or_panic(vec[46] == true);
    assert_or_panic(vec[47] == true);
    assert_or_panic(vec[48] == false);
    assert_or_panic(vec[49] == true);
    assert_or_panic(vec[50] == false);
    assert_or_panic(vec[51] == true);
    assert_or_panic(vec[52] == true);
    assert_or_panic(vec[53] == false);
    assert_or_panic(vec[54] == true);
    assert_or_panic(vec[55] == false);
    assert_or_panic(vec[56] == false);
    assert_or_panic(vec[57] == true);
    assert_or_panic(vec[58] == true);
    assert_or_panic(vec[59] == false);
    assert_or_panic(vec[60] == true);
    assert_or_panic(vec[61] == true);
    assert_or_panic(vec[62] == false);
    assert_or_panic(vec[63] == true);
    assert_or_panic(vec[64] == false);
    assert_or_panic(vec[65] == true);
    assert_or_panic(vec[66] == true);
    assert_or_panic(vec[67] == true);
    assert_or_panic(vec[68] == true);
    assert_or_panic(vec[69] == true);
    assert_or_panic(vec[70] == true);
    assert_or_panic(vec[71] == true);
    assert_or_panic(vec[72] == true);
    assert_or_panic(vec[73] == true);
    assert_or_panic(vec[74] == false);
    assert_or_panic(vec[75] == true);
    assert_or_panic(vec[76] == false);
    assert_or_panic(vec[77] == true);
    assert_or_panic(vec[78] == false);
    assert_or_panic(vec[79] == false);
    assert_or_panic(vec[80] == false);
    assert_or_panic(vec[81] == true);
    assert_or_panic(vec[82] == false);
    assert_or_panic(vec[83] == true);
    assert_or_panic(vec[84] == true);
    assert_or_panic(vec[85] == false);
    assert_or_panic(vec[86] == true);
    assert_or_panic(vec[87] == true);
    assert_or_panic(vec[88] == true);
    assert_or_panic(vec[89] == false);
    assert_or_panic(vec[90] == true);
    assert_or_panic(vec[91] == true);
    assert_or_panic(vec[92] == false);
    assert_or_panic(vec[93] == true);
    assert_or_panic(vec[94] == false);
    assert_or_panic(vec[95] == true);
    assert_or_panic(vec[96] == true);
    assert_or_panic(vec[97] == false);
    assert_or_panic(vec[98] == false);
    assert_or_panic(vec[99] == false);
    assert_or_panic(vec[100] == true);
    assert_or_panic(vec[101] == true);
    assert_or_panic(vec[102] == false);
    assert_or_panic(vec[103] == true);
    assert_or_panic(vec[104] == false);
    assert_or_panic(vec[105] == false);
    assert_or_panic(vec[106] == true);
    assert_or_panic(vec[107] == false);
    assert_or_panic(vec[108] == false);
    assert_or_panic(vec[109] == true);
    assert_or_panic(vec[110] == false);
    assert_or_panic(vec[111] == false);
    assert_or_panic(vec[112] == false);
    assert_or_panic(vec[113] == false);
    assert_or_panic(vec[114] == false);
    assert_or_panic(vec[115] == true);
    assert_or_panic(vec[116] == true);
    assert_or_panic(vec[117] == false);
    assert_or_panic(vec[118] == false);
    assert_or_panic(vec[119] == false);
    assert_or_panic(vec[120] == false);
    assert_or_panic(vec[121] == true);
    assert_or_panic(vec[122] == false);
    assert_or_panic(vec[123] == false);
    assert_or_panic(vec[124] == true);
    assert_or_panic(vec[125] == true);
    assert_or_panic(vec[126] == false);
    assert_or_panic(vec[127] == true);
    assert_or_panic(vec[128] == false);
    assert_or_panic(vec[129] == true);
    assert_or_panic(vec[130] == true);
    assert_or_panic(vec[131] == false);
    assert_or_panic(vec[132] == true);
    assert_or_panic(vec[133] == false);
    assert_or_panic(vec[134] == false);
    assert_or_panic(vec[135] == false);
    assert_or_panic(vec[136] == false);
    assert_or_panic(vec[137] == true);
    assert_or_panic(vec[138] == true);
    assert_or_panic(vec[139] == false);
    assert_or_panic(vec[140] == false);
    assert_or_panic(vec[141] == false);
    assert_or_panic(vec[142] == true);
    assert_or_panic(vec[143] == true);
    assert_or_panic(vec[144] == false);
    assert_or_panic(vec[145] == false);
    assert_or_panic(vec[146] == true);
    assert_or_panic(vec[147] == true);
    assert_or_panic(vec[148] == true);
    assert_or_panic(vec[149] == true);
    assert_or_panic(vec[150] == true);
    assert_or_panic(vec[151] == true);
    assert_or_panic(vec[152] == true);
    assert_or_panic(vec[153] == false);
    assert_or_panic(vec[154] == true);
    assert_or_panic(vec[155] == false);
    assert_or_panic(vec[156] == false);
    assert_or_panic(vec[157] == true);
    assert_or_panic(vec[158] == false);
    assert_or_panic(vec[159] == true);
    assert_or_panic(vec[160] == false);
    assert_or_panic(vec[161] == true);
    assert_or_panic(vec[162] == true);
    assert_or_panic(vec[163] == true);
    assert_or_panic(vec[164] == true);
    assert_or_panic(vec[165] == true);
    assert_or_panic(vec[166] == true);
    assert_or_panic(vec[167] == true);
    assert_or_panic(vec[168] == true);
    assert_or_panic(vec[169] == false);
    assert_or_panic(vec[170] == true);
    assert_or_panic(vec[171] == true);
    assert_or_panic(vec[172] == false);
    assert_or_panic(vec[173] == true);
    assert_or_panic(vec[174] == true);
    assert_or_panic(vec[175] == false);
    assert_or_panic(vec[176] == false);
    assert_or_panic(vec[177] == false);
    assert_or_panic(vec[178] == true);
    assert_or_panic(vec[179] == false);
    assert_or_panic(vec[180] == false);
    assert_or_panic(vec[181] == true);
    assert_or_panic(vec[182] == true);
    assert_or_panic(vec[183] == true);
    assert_or_panic(vec[184] == true);
    assert_or_panic(vec[185] == true);
    assert_or_panic(vec[186] == true);
    assert_or_panic(vec[187] == true);
    assert_or_panic(vec[188] == true);
    assert_or_panic(vec[189] == true);
    assert_or_panic(vec[190] == false);
    assert_or_panic(vec[191] == true);
    assert_or_panic(vec[192] == true);
    assert_or_panic(vec[193] == false);
    assert_or_panic(vec[194] == false);
    assert_or_panic(vec[195] == true);
    assert_or_panic(vec[196] == true);
    assert_or_panic(vec[197] == false);
    assert_or_panic(vec[198] == true);
    assert_or_panic(vec[199] == true);
    assert_or_panic(vec[200] == false);
    assert_or_panic(vec[201] == true);
    assert_or_panic(vec[202] == true);
    assert_or_panic(vec[203] == false);
    assert_or_panic(vec[204] == true);
    assert_or_panic(vec[205] == true);
    assert_or_panic(vec[206] == true);
    assert_or_panic(vec[207] == true);
    assert_or_panic(vec[208] == false);
    assert_or_panic(vec[209] == true);
    assert_or_panic(vec[210] == false);
    assert_or_panic(vec[211] == true);
    assert_or_panic(vec[212] == true);
    assert_or_panic(vec[213] == false);
    assert_or_panic(vec[214] == true);
    assert_or_panic(vec[215] == false);
    assert_or_panic(vec[216] == true);
    assert_or_panic(vec[217] == false);
    assert_or_panic(vec[218] == true);
    assert_or_panic(vec[219] == false);
    assert_or_panic(vec[220] == false);
    assert_or_panic(vec[221] == true);
    assert_or_panic(vec[222] == false);
    assert_or_panic(vec[223] == false);
    assert_or_panic(vec[224] == false);
    assert_or_panic(vec[225] == true);
    assert_or_panic(vec[226] == true);
    assert_or_panic(vec[227] == false);
    assert_or_panic(vec[228] == false);
    assert_or_panic(vec[229] == false);
    assert_or_panic(vec[230] == true);
    assert_or_panic(vec[231] == false);
    assert_or_panic(vec[232] == true);
    assert_or_panic(vec[233] == false);
    assert_or_panic(vec[234] == false);
    assert_or_panic(vec[235] == false);
    assert_or_panic(vec[236] == true);
    assert_or_panic(vec[237] == true);
    assert_or_panic(vec[238] == false);
    assert_or_panic(vec[239] == false);
    assert_or_panic(vec[240] == false);
    assert_or_panic(vec[241] == false);
    assert_or_panic(vec[242] == false);
    assert_or_panic(vec[243] == true);
    assert_or_panic(vec[244] == true);
    assert_or_panic(vec[245] == false);
    assert_or_panic(vec[246] == true);
    assert_or_panic(vec[247] == false);
    assert_or_panic(vec[248] == false);
    assert_or_panic(vec[249] == true);
    assert_or_panic(vec[250] == false);
    assert_or_panic(vec[251] == false);
    assert_or_panic(vec[252] == false);
    assert_or_panic(vec[253] == true);
    assert_or_panic(vec[254] == false);
    assert_or_panic(vec[255] == false);
    assert_or_panic(vec[256] == false);
    assert_or_panic(vec[257] == false);
    assert_or_panic(vec[258] == true);
    assert_or_panic(vec[259] == true);
    assert_or_panic(vec[260] == true);
    assert_or_panic(vec[261] == true);
    assert_or_panic(vec[262] == false);
    assert_or_panic(vec[263] == true);
    assert_or_panic(vec[264] == false);
    assert_or_panic(vec[265] == false);
    assert_or_panic(vec[266] == false);
    assert_or_panic(vec[267] == true);
    assert_or_panic(vec[268] == false);
    assert_or_panic(vec[269] == false);
    assert_or_panic(vec[270] == true);
    assert_or_panic(vec[271] == true);
    assert_or_panic(vec[272] == false);
    assert_or_panic(vec[273] == false);
    assert_or_panic(vec[274] == false);
    assert_or_panic(vec[275] == false);
    assert_or_panic(vec[276] == false);
    assert_or_panic(vec[277] == true);
    assert_or_panic(vec[278] == false);
    assert_or_panic(vec[279] == true);
    assert_or_panic(vec[280] == true);
    assert_or_panic(vec[281] == true);
    assert_or_panic(vec[282] == true);
    assert_or_panic(vec[283] == true);
    assert_or_panic(vec[284] == false);
    assert_or_panic(vec[285] == false);
    assert_or_panic(vec[286] == false);
    assert_or_panic(vec[287] == false);
    assert_or_panic(vec[288] == false);
    assert_or_panic(vec[289] == false);
    assert_or_panic(vec[290] == false);
    assert_or_panic(vec[291] == false);
    assert_or_panic(vec[292] == false);
    assert_or_panic(vec[293] == true);
    assert_or_panic(vec[294] == true);
    assert_or_panic(vec[295] == true);
    assert_or_panic(vec[296] == true);
    assert_or_panic(vec[297] == true);
    assert_or_panic(vec[298] == true);
    assert_or_panic(vec[299] == false);
    assert_or_panic(vec[300] == true);
    assert_or_panic(vec[301] == false);
    assert_or_panic(vec[302] == true);
    assert_or_panic(vec[303] == true);
    assert_or_panic(vec[304] == true);
    assert_or_panic(vec[305] == false);
    assert_or_panic(vec[306] == false);
    assert_or_panic(vec[307] == true);
    assert_or_panic(vec[308] == true);
    assert_or_panic(vec[309] == true);
    assert_or_panic(vec[310] == false);
    assert_or_panic(vec[311] == true);
    assert_or_panic(vec[312] == true);
    assert_or_panic(vec[313] == true);
    assert_or_panic(vec[314] == false);
    assert_or_panic(vec[315] == true);
    assert_or_panic(vec[316] == true);
    assert_or_panic(vec[317] == true);
    assert_or_panic(vec[318] == false);
    assert_or_panic(vec[319] == true);
    assert_or_panic(vec[320] == true);
    assert_or_panic(vec[321] == false);
    assert_or_panic(vec[322] == false);
    assert_or_panic(vec[323] == true);
    assert_or_panic(vec[324] == false);
    assert_or_panic(vec[325] == false);
    assert_or_panic(vec[326] == false);
    assert_or_panic(vec[327] == false);
    assert_or_panic(vec[328] == true);
    assert_or_panic(vec[329] == false);
    assert_or_panic(vec[330] == true);
    assert_or_panic(vec[331] == true);
    assert_or_panic(vec[332] == true);
    assert_or_panic(vec[333] == true);
    assert_or_panic(vec[334] == false);
    assert_or_panic(vec[335] == false);
    assert_or_panic(vec[336] == true);
    assert_or_panic(vec[337] == false);
    assert_or_panic(vec[338] == true);
    assert_or_panic(vec[339] == false);
    assert_or_panic(vec[340] == false);
    assert_or_panic(vec[341] == false);
    assert_or_panic(vec[342] == true);
    assert_or_panic(vec[343] == false);
    assert_or_panic(vec[344] == true);
    assert_or_panic(vec[345] == false);
    assert_or_panic(vec[346] == false);
    assert_or_panic(vec[347] == true);
    assert_or_panic(vec[348] == true);
    assert_or_panic(vec[349] == true);
    assert_or_panic(vec[350] == true);
    assert_or_panic(vec[351] == false);
    assert_or_panic(vec[352] == false);
    assert_or_panic(vec[353] == false);
    assert_or_panic(vec[354] == true);
    assert_or_panic(vec[355] == true);
    assert_or_panic(vec[356] == false);
    assert_or_panic(vec[357] == true);
    assert_or_panic(vec[358] == false);
    assert_or_panic(vec[359] == false);
    assert_or_panic(vec[360] == true);
    assert_or_panic(vec[361] == false);
    assert_or_panic(vec[362] == true);
    assert_or_panic(vec[363] == false);
    assert_or_panic(vec[364] == true);
    assert_or_panic(vec[365] == true);
    assert_or_panic(vec[366] == false);
    assert_or_panic(vec[367] == false);
    assert_or_panic(vec[368] == true);
    assert_or_panic(vec[369] == true);
    assert_or_panic(vec[370] == true);
    assert_or_panic(vec[371] == true);
    assert_or_panic(vec[372] == false);
    assert_or_panic(vec[373] == false);
    assert_or_panic(vec[374] == true);
    assert_or_panic(vec[375] == false);
    assert_or_panic(vec[376] == true);
    assert_or_panic(vec[377] == true);
    assert_or_panic(vec[378] == false);
    assert_or_panic(vec[379] == true);
    assert_or_panic(vec[380] == true);
    assert_or_panic(vec[381] == false);
    assert_or_panic(vec[382] == true);
    assert_or_panic(vec[383] == true);
    assert_or_panic(vec[384] == true);
    assert_or_panic(vec[385] == false);
    assert_or_panic(vec[386] == true);
    assert_or_panic(vec[387] == true);
    assert_or_panic(vec[388] == true);
    assert_or_panic(vec[389] == false);
    assert_or_panic(vec[390] == false);
    assert_or_panic(vec[391] == true);
    assert_or_panic(vec[392] == false);
    assert_or_panic(vec[393] == true);
    assert_or_panic(vec[394] == true);
    assert_or_panic(vec[395] == true);
    assert_or_panic(vec[396] == false);
    assert_or_panic(vec[397] == false);
    assert_or_panic(vec[398] == false);
    assert_or_panic(vec[399] == false);
    assert_or_panic(vec[400] == false);
    assert_or_panic(vec[401] == true);
    assert_or_panic(vec[402] == false);
    assert_or_panic(vec[403] == false);
    assert_or_panic(vec[404] == false);
    assert_or_panic(vec[405] == false);
    assert_or_panic(vec[406] == true);
    assert_or_panic(vec[407] == false);
    assert_or_panic(vec[408] == false);
    assert_or_panic(vec[409] == true);
    assert_or_panic(vec[410] == true);
    assert_or_panic(vec[411] == false);
    assert_or_panic(vec[412] == false);
    assert_or_panic(vec[413] == false);
    assert_or_panic(vec[414] == false);
    assert_or_panic(vec[415] == true);
    assert_or_panic(vec[416] == true);
    assert_or_panic(vec[417] == true);
    assert_or_panic(vec[418] == true);
    assert_or_panic(vec[419] == true);
    assert_or_panic(vec[420] == false);
    assert_or_panic(vec[421] == false);
    assert_or_panic(vec[422] == false);
    assert_or_panic(vec[423] == true);
    assert_or_panic(vec[424] == false);
    assert_or_panic(vec[425] == false);
    assert_or_panic(vec[426] == false);
    assert_or_panic(vec[427] == false);
    assert_or_panic(vec[428] == true);
    assert_or_panic(vec[429] == false);
    assert_or_panic(vec[430] == true);
    assert_or_panic(vec[431] == false);
    assert_or_panic(vec[432] == true);
    assert_or_panic(vec[433] == true);
    assert_or_panic(vec[434] == true);
    assert_or_panic(vec[435] == true);
    assert_or_panic(vec[436] == false);
    assert_or_panic(vec[437] == false);
    assert_or_panic(vec[438] == false);
    assert_or_panic(vec[439] == false);
    assert_or_panic(vec[440] == false);
    assert_or_panic(vec[441] == true);
    assert_or_panic(vec[442] == true);
    assert_or_panic(vec[443] == true);
    assert_or_panic(vec[444] == true);
    assert_or_panic(vec[445] == true);
    assert_or_panic(vec[446] == true);
    assert_or_panic(vec[447] == true);
    assert_or_panic(vec[448] == true);
    assert_or_panic(vec[449] == true);
    assert_or_panic(vec[450] == false);
    assert_or_panic(vec[451] == false);
    assert_or_panic(vec[452] == true);
    assert_or_panic(vec[453] == false);
    assert_or_panic(vec[454] == true);
    assert_or_panic(vec[455] == false);
    assert_or_panic(vec[456] == false);
    assert_or_panic(vec[457] == true);
    assert_or_panic(vec[458] == false);
    assert_or_panic(vec[459] == false);
    assert_or_panic(vec[460] == true);
    assert_or_panic(vec[461] == true);
    assert_or_panic(vec[462] == true);
    assert_or_panic(vec[463] == true);
    assert_or_panic(vec[464] == true);
    assert_or_panic(vec[465] == true);
    assert_or_panic(vec[466] == false);
    assert_or_panic(vec[467] == true);
    assert_or_panic(vec[468] == false);
    assert_or_panic(vec[469] == false);
    assert_or_panic(vec[470] == false);
    assert_or_panic(vec[471] == true);
    assert_or_panic(vec[472] == true);
    assert_or_panic(vec[473] == false);
    assert_or_panic(vec[474] == true);
    assert_or_panic(vec[475] == true);
    assert_or_panic(vec[476] == false);
    assert_or_panic(vec[477] == false);
    assert_or_panic(vec[478] == true);
    assert_or_panic(vec[479] == true);
    assert_or_panic(vec[480] == false);
    assert_or_panic(vec[481] == false);
    assert_or_panic(vec[482] == true);
    assert_or_panic(vec[483] == true);
    assert_or_panic(vec[484] == false);
    assert_or_panic(vec[485] == true);
    assert_or_panic(vec[486] == false);
    assert_or_panic(vec[487] == true);
    assert_or_panic(vec[488] == true);
    assert_or_panic(vec[489] == true);
    assert_or_panic(vec[490] == true);
    assert_or_panic(vec[491] == true);
    assert_or_panic(vec[492] == true);
    assert_or_panic(vec[493] == true);
    assert_or_panic(vec[494] == true);
    assert_or_panic(vec[495] == true);
    assert_or_panic(vec[496] == false);
    assert_or_panic(vec[497] == true);
    assert_or_panic(vec[498] == true);
    assert_or_panic(vec[499] == true);
    assert_or_panic(vec[500] == false);
    assert_or_panic(vec[501] == false);
    assert_or_panic(vec[502] == true);
    assert_or_panic(vec[503] == false);
    assert_or_panic(vec[504] == false);
    assert_or_panic(vec[505] == false);
    assert_or_panic(vec[506] == true);
    assert_or_panic(vec[507] == true);
    assert_or_panic(vec[508] == false);
    assert_or_panic(vec[509] == true);
    assert_or_panic(vec[510] == false);
    assert_or_panic(vec[511] == true);
}

#endif

Vector2Bool c_ret_vector_2_bool(void) {
    return (Vector2Bool){
        true,
        false,
    };
}

Vector4Bool c_ret_vector_4_bool(void) {
    return (Vector4Bool){
        true,
        false,
        true,
        false,
    };
}

Vector8Bool c_ret_vector_8_bool(void) {
    return (Vector8Bool){
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
    };
}

Vector16Bool c_ret_vector_16_bool(void) {
    return (Vector16Bool){
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
    };
}

Vector32Bool c_ret_vector_32_bool(void) {
    return (Vector32Bool){
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
    };
}

Vector64Bool c_ret_vector_64_bool(void) {
    return (Vector64Bool){
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
    };
}

Vector128Bool c_ret_vector_128_bool(void) {
    return (Vector128Bool){
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        true,
        false,
        true,
    };
}

Vector256Bool c_ret_vector_256_bool(void) {
    return (Vector256Bool){
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
    };
}

Vector512Bool c_ret_vector_512_bool(void) {
    return (Vector512Bool){
        false,
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        true,
        false,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        true,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        true,
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        true,
        false,
    };
}

void zig_vector_2_bool(Vector2Bool vec);
void zig_vector_4_bool(Vector4Bool vec);
void zig_vector_8_bool(Vector8Bool vec);
void zig_vector_16_bool(Vector16Bool vec);
void zig_vector_32_bool(Vector32Bool vec);
void zig_vector_64_bool(Vector64Bool vec);
void zig_vector_128_bool(Vector128Bool vec);
void zig_vector_256_bool(Vector256Bool vec);
void zig_vector_512_bool(Vector512Bool vec);

Vector2Bool zig_ret_vector_2_bool(void);
Vector4Bool zig_ret_vector_4_bool(void);
Vector8Bool zig_ret_vector_8_bool(void);
Vector16Bool zig_ret_vector_16_bool(void);
Vector32Bool zig_ret_vector_32_bool(void);
Vector64Bool zig_ret_vector_64_bool(void);
Vector128Bool zig_ret_vector_128_bool(void);
Vector256Bool zig_ret_vector_256_bool(void);
Vector512Bool zig_ret_vector_512_bool(void);

#endif

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

#ifndef ZIG_NO_I128
    {
        struct u128 s = {0xfffffffffffffffc};
        zig_struct_u128(s);
    }
#endif

#ifndef ZIG_BUG_14908
    zig_i8(-1);
    zig_i16(-2);
#endif
    zig_i32(-3);
    zig_i64(-4);

#ifndef ZIG_NO_I128
    {
        struct i128 s = {-6};
        zig_struct_i128(s);
    }
#endif

    zig_five_integers(12, 34, 56, 78, 90);

    zig_f32(12.34f);
    zig_f64(56.78);
    zig_longdouble(12.34l);
    zig_five_floats(1.0f, 2.0f, 3.0f, 4.0f, 5.0f);

    zig_ptr((void *)0xdeadbeefL);

    zig_bool(true);

#ifndef ZIG_NO_COMPLEX
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
#endif

#if !defined(__mips__) && !defined(ZIG_PPC32)
    {
        struct Struct_u64_u64 s = zig_ret_struct_u64_u64();
        assert_or_panic(s.a == 1);
        assert_or_panic(s.b == 2);
        zig_struct_u64_u64_0((struct Struct_u64_u64){ .a = 3, .b = 4 });
        zig_struct_u64_u64_1(0, (struct Struct_u64_u64){ .a = 5, .b = 6 });
        zig_struct_u64_u64_2(0, 1, (struct Struct_u64_u64){ .a = 7, .b = 8 });
        zig_struct_u64_u64_3(0, 1, 2, (struct Struct_u64_u64){ .a = 9, .b = 10 });
        zig_struct_u64_u64_4(0, 1, 2, 3, (struct Struct_u64_u64){ .a = 11, .b = 12 });
        zig_struct_u64_u64_5(0, 1, 2, 3, 4, (struct Struct_u64_u64){ .a = 13, .b = 14 });
        zig_struct_u64_u64_6(0, 1, 2, 3, 4, 5, (struct Struct_u64_u64){ .a = 15, .b = 16 });
        zig_struct_u64_u64_7(0, 1, 2, 3, 4, 5, 6, (struct Struct_u64_u64){ .a = 17, .b = 18 });
        zig_struct_u64_u64_8(0, 1, 2, 3, 4, 5, 6, 7, (struct Struct_u64_u64){ .a = 19, .b = 20 });
    }

#if !defined(ZIG_RISCV64)
    {
        struct Struct_f32f32_f32 s = zig_ret_struct_f32f32_f32();
        assert_or_panic(s.a.b == 1.0f);
        assert_or_panic(s.a.c == 2.0f);
        assert_or_panic(s.d == 3.0f);
        zig_struct_f32f32_f32((struct Struct_f32f32_f32){ { 1.0f, 2.0f }, 3.0f });
    }

    {
        struct Struct_f32_f32f32 s = zig_ret_struct_f32_f32f32();
        assert_or_panic(s.a == 1.0f);
        assert_or_panic(s.b.c == 2.0f);
        assert_or_panic(s.b.d == 3.0f);
        zig_struct_f32_f32f32((struct Struct_f32_f32f32){ 1.0f, { 2.0f, 3.0f } });
    }
#endif

#if !defined(__powerpc__)
    {
        struct Struct_u32_Union_u32_u32u32 s = zig_ret_struct_u32_union_u32_u32u32();
        assert_or_panic(s.a == 1);
        assert_or_panic(s.b.c.d == 2);
        assert_or_panic(s.b.c.e == 3);
        zig_struct_u32_union_u32_u32u32(s);
    }
#endif

    {
        struct BigStruct s = {1, 2, 3, 4, 5};
        zig_big_struct(s);
    }
#endif

#if !defined __i386__ && !defined __arm__ && !defined __aarch64__ && \
    !defined __mips__ && !defined __powerpc__ && !defined ZIG_RISCV64
    {
        struct SmallStructInts s = {1, 2, 3, 4};
        zig_small_struct_ints(s);
    }
#endif

#if !defined __arm__ && !defined __aarch64__ && \
    !defined __mips__ && !defined __powerpc__ && !defined ZIG_RISCV64
    {
        struct MedStructInts s = {1, 2, 3};
        zig_med_struct_ints(s);
    }
#endif

#ifndef ZIG_NO_I128
    {
        __int128 s = 0;
        s |= 1 << 0;
        s |= (__int128)2 << 64;
        zig_big_packed_struct(s);
    }
#endif

    {
        uint8_t s = 0;
        s |= 0 << 0;
        s |= 1 << 2;
        s |= 2 << 4;
        s |= 3 << 6;
        zig_small_packed_struct(s);
    }

#if !defined __i386__ && !defined __arm__ && !defined __mips__ && \
    !defined ZIG_PPC32 && !defined _ARCH_PPC64
    {
        struct SplitStructInts s = {1234, 100, 1337};
        zig_split_struct_ints(s);
    }
#endif

#if !defined __arm__ && !defined ZIG_PPC32 && !defined _ARCH_PPC64
    {
        struct MedStructMixed s = {1234, 100.0f, 1337.0f};
        zig_med_struct_mixed(s);
    }
#endif

#if !defined __i386__ && !defined __arm__ && !defined __mips__ && \
    !defined ZIG_PPC32 && !defined _ARCH_PPC64
    {
        struct SplitStructMixed s = {1234, 100, 1337.0f};
        zig_split_struct_mixed(s);
    }
#endif

#if !defined __mips__ && !defined ZIG_PPC32
    {
        struct BigStruct s = {30, 31, 32, 33, 34};
        struct BigStruct res = zig_big_struct_both(s);
        assert_or_panic(res.a == 20);
        assert_or_panic(res.b == 21);
        assert_or_panic(res.c == 22);
        assert_or_panic(res.d == 23);
        assert_or_panic(res.e == 24);
    }
#endif

#if !defined ZIG_PPC32 && !defined _ARCH_PPC64
    {
        struct Rect r1 = {1, 21, 16, 4};
        struct Rect r2 = {178, 189, 21, 15};
        zig_multiple_struct_ints(r1, r2);
    }
#endif

#if !defined __mips__ && !defined ZIG_PPC32
    {
        struct FloatRect r1 = {1, 21, 16, 4};
        struct FloatRect r2 = {178, 189, 21, 15};
        zig_multiple_struct_floats(r1, r2);
    }
#endif

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

#if defined(ZIG_BACKEND_STAGE2_X86_64) || defined(ZIG_PPC32)
    {
        zig_vector_2_bool((Vector2Bool){
            false,
            true,
        });

        Vector2Bool vec = zig_ret_vector_2_bool();
        assert_or_panic(vec[0] == false);
        assert_or_panic(vec[1] == false);
    }
    {
        zig_vector_4_bool((Vector4Bool){
            false,
            false,
            false,
            false,
        });

        Vector4Bool vec = zig_ret_vector_4_bool();
        assert_or_panic(vec[0] == false);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == true);
        assert_or_panic(vec[3] == true);
    }
    {
        zig_vector_8_bool((Vector8Bool){
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
        });

        Vector8Bool vec = zig_ret_vector_8_bool();
        assert_or_panic(vec[0] == false);
        assert_or_panic(vec[1] == false);
        assert_or_panic(vec[2] == false);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == true);
        assert_or_panic(vec[5] == false);
        assert_or_panic(vec[6] == false);
        assert_or_panic(vec[7] == false);
    }
    {
        zig_vector_16_bool((Vector16Bool){
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
        });

        Vector16Bool vec = zig_ret_vector_16_bool();
        assert_or_panic(vec[0] == false);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == false);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == false);
        assert_or_panic(vec[5] == true);
        assert_or_panic(vec[6] == false);
        assert_or_panic(vec[7] == false);
        assert_or_panic(vec[8] == true);
        assert_or_panic(vec[9] == false);
        assert_or_panic(vec[10] == false);
        assert_or_panic(vec[11] == false);
        assert_or_panic(vec[12] == false);
        assert_or_panic(vec[13] == true);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == false);
    }
    {
        zig_vector_32_bool((Vector32Bool){
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
        });

        Vector32Bool vec = zig_ret_vector_32_bool();
        assert_or_panic(vec[0] == false);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == false);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == true);
        assert_or_panic(vec[5] == false);
        assert_or_panic(vec[6] == true);
        assert_or_panic(vec[7] == true);
        assert_or_panic(vec[8] == true);
        assert_or_panic(vec[9] == true);
        assert_or_panic(vec[10] == true);
        assert_or_panic(vec[11] == true);
        assert_or_panic(vec[12] == false);
        assert_or_panic(vec[13] == false);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == false);
        assert_or_panic(vec[16] == false);
        assert_or_panic(vec[17] == false);
        assert_or_panic(vec[18] == true);
        assert_or_panic(vec[19] == true);
        assert_or_panic(vec[20] == true);
        assert_or_panic(vec[21] == false);
        assert_or_panic(vec[22] == true);
        assert_or_panic(vec[23] == false);
        assert_or_panic(vec[24] == true);
        assert_or_panic(vec[25] == false);
        assert_or_panic(vec[26] == false);
        assert_or_panic(vec[27] == true);
        assert_or_panic(vec[28] == false);
        assert_or_panic(vec[29] == false);
        assert_or_panic(vec[30] == true);
        assert_or_panic(vec[31] == true);
    }
    {
        zig_vector_64_bool((Vector64Bool){
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
        });

        Vector64Bool vec = zig_ret_vector_64_bool();
        assert_or_panic(vec[0] == true);
        assert_or_panic(vec[1] == false);
        assert_or_panic(vec[2] == true);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == false);
        assert_or_panic(vec[5] == true);
        assert_or_panic(vec[6] == false);
        assert_or_panic(vec[7] == true);
        assert_or_panic(vec[8] == true);
        assert_or_panic(vec[9] == false);
        assert_or_panic(vec[10] == true);
        assert_or_panic(vec[11] == false);
        assert_or_panic(vec[12] == true);
        assert_or_panic(vec[13] == false);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == true);
        assert_or_panic(vec[16] == false);
        assert_or_panic(vec[17] == false);
        assert_or_panic(vec[18] == true);
        assert_or_panic(vec[19] == true);
        assert_or_panic(vec[20] == false);
        assert_or_panic(vec[21] == false);
        assert_or_panic(vec[22] == true);
        assert_or_panic(vec[23] == false);
        assert_or_panic(vec[24] == false);
        assert_or_panic(vec[25] == true);
        assert_or_panic(vec[26] == true);
        assert_or_panic(vec[27] == true);
        assert_or_panic(vec[28] == true);
        assert_or_panic(vec[29] == true);
        assert_or_panic(vec[30] == false);
        assert_or_panic(vec[31] == false);
        assert_or_panic(vec[32] == true);
        assert_or_panic(vec[33] == true);
        assert_or_panic(vec[34] == true);
        assert_or_panic(vec[35] == true);
        assert_or_panic(vec[36] == false);
        assert_or_panic(vec[37] == true);
        assert_or_panic(vec[38] == false);
        assert_or_panic(vec[39] == true);
        assert_or_panic(vec[40] == true);
        assert_or_panic(vec[41] == true);
        assert_or_panic(vec[42] == true);
        assert_or_panic(vec[43] == true);
        assert_or_panic(vec[44] == false);
        assert_or_panic(vec[45] == false);
        assert_or_panic(vec[46] == false);
        assert_or_panic(vec[47] == true);
        assert_or_panic(vec[48] == true);
        assert_or_panic(vec[49] == true);
        assert_or_panic(vec[50] == false);
        assert_or_panic(vec[51] == true);
        assert_or_panic(vec[52] == true);
        assert_or_panic(vec[53] == true);
        assert_or_panic(vec[54] == false);
        assert_or_panic(vec[55] == false);
        assert_or_panic(vec[56] == false);
        assert_or_panic(vec[57] == true);
        assert_or_panic(vec[58] == false);
        assert_or_panic(vec[59] == false);
        assert_or_panic(vec[60] == true);
        assert_or_panic(vec[61] == false);
        assert_or_panic(vec[62] == true);
        assert_or_panic(vec[63] == false);
    }
    {
        zig_vector_128_bool((Vector128Bool){
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
        });

        Vector128Bool vec = zig_ret_vector_128_bool();
        assert_or_panic(vec[0] == true);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == false);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == false);
        assert_or_panic(vec[5] == true);
        assert_or_panic(vec[6] == true);
        assert_or_panic(vec[7] == false);
        assert_or_panic(vec[8] == false);
        assert_or_panic(vec[9] == true);
        assert_or_panic(vec[10] == false);
        assert_or_panic(vec[11] == false);
        assert_or_panic(vec[12] == false);
        assert_or_panic(vec[13] == true);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == true);
        assert_or_panic(vec[16] == true);
        assert_or_panic(vec[17] == false);
        assert_or_panic(vec[18] == false);
        assert_or_panic(vec[19] == true);
        assert_or_panic(vec[20] == true);
        assert_or_panic(vec[21] == true);
        assert_or_panic(vec[22] == true);
        assert_or_panic(vec[23] == true);
        assert_or_panic(vec[24] == false);
        assert_or_panic(vec[25] == false);
        assert_or_panic(vec[26] == true);
        assert_or_panic(vec[27] == true);
        assert_or_panic(vec[28] == true);
        assert_or_panic(vec[29] == false);
        assert_or_panic(vec[30] == false);
        assert_or_panic(vec[31] == true);
        assert_or_panic(vec[32] == true);
        assert_or_panic(vec[33] == false);
        assert_or_panic(vec[34] == true);
        assert_or_panic(vec[35] == true);
        assert_or_panic(vec[36] == true);
        assert_or_panic(vec[37] == false);
        assert_or_panic(vec[38] == true);
        assert_or_panic(vec[39] == true);
        assert_or_panic(vec[40] == true);
        assert_or_panic(vec[41] == false);
        assert_or_panic(vec[42] == true);
        assert_or_panic(vec[43] == true);
        assert_or_panic(vec[44] == false);
        assert_or_panic(vec[45] == false);
        assert_or_panic(vec[46] == false);
        assert_or_panic(vec[47] == true);
        assert_or_panic(vec[48] == false);
        assert_or_panic(vec[49] == false);
        assert_or_panic(vec[50] == false);
        assert_or_panic(vec[51] == false);
        assert_or_panic(vec[52] == true);
        assert_or_panic(vec[53] == false);
        assert_or_panic(vec[54] == true);
        assert_or_panic(vec[55] == false);
        assert_or_panic(vec[56] == true);
        assert_or_panic(vec[57] == false);
        assert_or_panic(vec[58] == false);
        assert_or_panic(vec[59] == true);
        assert_or_panic(vec[60] == true);
        assert_or_panic(vec[61] == true);
        assert_or_panic(vec[62] == true);
        assert_or_panic(vec[63] == true);
        assert_or_panic(vec[64] == false);
        assert_or_panic(vec[65] == false);
        assert_or_panic(vec[66] == false);
        assert_or_panic(vec[67] == true);
        assert_or_panic(vec[68] == true);
        assert_or_panic(vec[69] == false);
        assert_or_panic(vec[70] == true);
        assert_or_panic(vec[71] == true);
        assert_or_panic(vec[72] == false);
        assert_or_panic(vec[73] == true);
        assert_or_panic(vec[74] == true);
        assert_or_panic(vec[75] == false);
        assert_or_panic(vec[76] == false);
        assert_or_panic(vec[77] == true);
        assert_or_panic(vec[78] == false);
        assert_or_panic(vec[79] == true);
        assert_or_panic(vec[80] == false);
        assert_or_panic(vec[81] == false);
        assert_or_panic(vec[82] == true);
        assert_or_panic(vec[83] == true);
        assert_or_panic(vec[84] == false);
        assert_or_panic(vec[85] == true);
        assert_or_panic(vec[86] == false);
        assert_or_panic(vec[87] == false);
        assert_or_panic(vec[88] == true);
        assert_or_panic(vec[89] == true);
        assert_or_panic(vec[90] == true);
        assert_or_panic(vec[91] == true);
        assert_or_panic(vec[92] == true);
        assert_or_panic(vec[93] == false);
        assert_or_panic(vec[94] == false);
        assert_or_panic(vec[95] == true);
        assert_or_panic(vec[96] == false);
        assert_or_panic(vec[97] == false);
        assert_or_panic(vec[98] == true);
        assert_or_panic(vec[99] == true);
        assert_or_panic(vec[100] == true);
        assert_or_panic(vec[101] == true);
        assert_or_panic(vec[102] == true);
        assert_or_panic(vec[103] == true);
        assert_or_panic(vec[104] == true);
        assert_or_panic(vec[105] == false);
        assert_or_panic(vec[106] == false);
        assert_or_panic(vec[107] == true);
        assert_or_panic(vec[108] == false);
        assert_or_panic(vec[109] == false);
        assert_or_panic(vec[110] == true);
        assert_or_panic(vec[111] == false);
        assert_or_panic(vec[112] == false);
        assert_or_panic(vec[113] == true);
        assert_or_panic(vec[114] == false);
        assert_or_panic(vec[115] == false);
        assert_or_panic(vec[116] == false);
        assert_or_panic(vec[117] == false);
        assert_or_panic(vec[118] == false);
        assert_or_panic(vec[119] == false);
        assert_or_panic(vec[120] == true);
        assert_or_panic(vec[121] == true);
        assert_or_panic(vec[122] == true);
        assert_or_panic(vec[123] == false);
        assert_or_panic(vec[124] == true);
        assert_or_panic(vec[125] == false);
        assert_or_panic(vec[126] == false);
        assert_or_panic(vec[127] == true);
    }
    {
        zig_vector_256_bool((Vector256Bool){
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
        });

        Vector256Bool vec = zig_ret_vector_256_bool();
        assert_or_panic(vec[0] == true);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == true);
        assert_or_panic(vec[3] == false);
        assert_or_panic(vec[4] == true);
        assert_or_panic(vec[5] == false);
        assert_or_panic(vec[6] == false);
        assert_or_panic(vec[7] == true);
        assert_or_panic(vec[8] == false);
        assert_or_panic(vec[9] == false);
        assert_or_panic(vec[10] == false);
        assert_or_panic(vec[11] == false);
        assert_or_panic(vec[12] == false);
        assert_or_panic(vec[13] == false);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == false);
        assert_or_panic(vec[16] == true);
        assert_or_panic(vec[17] == false);
        assert_or_panic(vec[18] == true);
        assert_or_panic(vec[19] == false);
        assert_or_panic(vec[20] == false);
        assert_or_panic(vec[21] == true);
        assert_or_panic(vec[22] == true);
        assert_or_panic(vec[23] == false);
        assert_or_panic(vec[24] == false);
        assert_or_panic(vec[25] == true);
        assert_or_panic(vec[26] == true);
        assert_or_panic(vec[27] == false);
        assert_or_panic(vec[28] == true);
        assert_or_panic(vec[29] == true);
        assert_or_panic(vec[30] == true);
        assert_or_panic(vec[31] == false);
        assert_or_panic(vec[32] == true);
        assert_or_panic(vec[33] == false);
        assert_or_panic(vec[34] == true);
        assert_or_panic(vec[35] == false);
        assert_or_panic(vec[36] == true);
        assert_or_panic(vec[37] == false);
        assert_or_panic(vec[38] == true);
        assert_or_panic(vec[39] == false);
        assert_or_panic(vec[40] == false);
        assert_or_panic(vec[41] == false);
        assert_or_panic(vec[42] == true);
        assert_or_panic(vec[43] == true);
        assert_or_panic(vec[44] == true);
        assert_or_panic(vec[45] == false);
        assert_or_panic(vec[46] == false);
        assert_or_panic(vec[47] == false);
        assert_or_panic(vec[48] == true);
        assert_or_panic(vec[49] == false);
        assert_or_panic(vec[50] == true);
        assert_or_panic(vec[51] == false);
        assert_or_panic(vec[52] == true);
        assert_or_panic(vec[53] == false);
        assert_or_panic(vec[54] == true);
        assert_or_panic(vec[55] == true);
        assert_or_panic(vec[56] == false);
        assert_or_panic(vec[57] == false);
        assert_or_panic(vec[58] == false);
        assert_or_panic(vec[59] == true);
        assert_or_panic(vec[60] == true);
        assert_or_panic(vec[61] == true);
        assert_or_panic(vec[62] == false);
        assert_or_panic(vec[63] == true);
        assert_or_panic(vec[64] == false);
        assert_or_panic(vec[65] == true);
        assert_or_panic(vec[66] == false);
        assert_or_panic(vec[67] == true);
        assert_or_panic(vec[68] == true);
        assert_or_panic(vec[69] == false);
        assert_or_panic(vec[70] == true);
        assert_or_panic(vec[71] == false);
        assert_or_panic(vec[72] == true);
        assert_or_panic(vec[73] == true);
        assert_or_panic(vec[74] == false);
        assert_or_panic(vec[75] == false);
        assert_or_panic(vec[76] == false);
        assert_or_panic(vec[77] == false);
        assert_or_panic(vec[78] == false);
        assert_or_panic(vec[79] == false);
        assert_or_panic(vec[80] == false);
        assert_or_panic(vec[81] == false);
        assert_or_panic(vec[82] == false);
        assert_or_panic(vec[83] == true);
        assert_or_panic(vec[84] == false);
        assert_or_panic(vec[85] == false);
        assert_or_panic(vec[86] == false);
        assert_or_panic(vec[87] == true);
        assert_or_panic(vec[88] == false);
        assert_or_panic(vec[89] == true);
        assert_or_panic(vec[90] == true);
        assert_or_panic(vec[91] == false);
        assert_or_panic(vec[92] == false);
        assert_or_panic(vec[93] == true);
        assert_or_panic(vec[94] == true);
        assert_or_panic(vec[95] == false);
        assert_or_panic(vec[96] == false);
        assert_or_panic(vec[97] == true);
        assert_or_panic(vec[98] == false);
        assert_or_panic(vec[99] == false);
        assert_or_panic(vec[100] == false);
        assert_or_panic(vec[101] == false);
        assert_or_panic(vec[102] == false);
        assert_or_panic(vec[103] == false);
        assert_or_panic(vec[104] == false);
        assert_or_panic(vec[105] == true);
        assert_or_panic(vec[106] == true);
        assert_or_panic(vec[107] == false);
        assert_or_panic(vec[108] == true);
        assert_or_panic(vec[109] == false);
        assert_or_panic(vec[110] == true);
        assert_or_panic(vec[111] == true);
        assert_or_panic(vec[112] == false);
        assert_or_panic(vec[113] == false);
        assert_or_panic(vec[114] == false);
        assert_or_panic(vec[115] == false);
        assert_or_panic(vec[116] == false);
        assert_or_panic(vec[117] == false);
        assert_or_panic(vec[118] == false);
        assert_or_panic(vec[119] == true);
        assert_or_panic(vec[120] == true);
        assert_or_panic(vec[121] == true);
        assert_or_panic(vec[122] == false);
        assert_or_panic(vec[123] == true);
        assert_or_panic(vec[124] == true);
        assert_or_panic(vec[125] == false);
        assert_or_panic(vec[126] == false);
        assert_or_panic(vec[127] == true);
        assert_or_panic(vec[128] == true);
        assert_or_panic(vec[129] == true);
        assert_or_panic(vec[130] == true);
        assert_or_panic(vec[131] == true);
        assert_or_panic(vec[132] == false);
        assert_or_panic(vec[133] == true);
        assert_or_panic(vec[134] == true);
        assert_or_panic(vec[135] == false);
        assert_or_panic(vec[136] == false);
        assert_or_panic(vec[137] == true);
        assert_or_panic(vec[138] == true);
        assert_or_panic(vec[139] == false);
        assert_or_panic(vec[140] == true);
        assert_or_panic(vec[141] == false);
        assert_or_panic(vec[142] == true);
        assert_or_panic(vec[143] == false);
        assert_or_panic(vec[144] == true);
        assert_or_panic(vec[145] == true);
        assert_or_panic(vec[146] == true);
        assert_or_panic(vec[147] == true);
        assert_or_panic(vec[148] == false);
        assert_or_panic(vec[149] == false);
        assert_or_panic(vec[150] == false);
        assert_or_panic(vec[151] == true);
        assert_or_panic(vec[152] == false);
        assert_or_panic(vec[153] == true);
        assert_or_panic(vec[154] == false);
        assert_or_panic(vec[155] == true);
        assert_or_panic(vec[156] == true);
        assert_or_panic(vec[157] == false);
        assert_or_panic(vec[158] == true);
        assert_or_panic(vec[159] == true);
        assert_or_panic(vec[160] == true);
        assert_or_panic(vec[161] == true);
        assert_or_panic(vec[162] == true);
        assert_or_panic(vec[163] == false);
        assert_or_panic(vec[164] == false);
        assert_or_panic(vec[165] == true);
        assert_or_panic(vec[166] == false);
        assert_or_panic(vec[167] == true);
        assert_or_panic(vec[168] == true);
        assert_or_panic(vec[169] == true);
        assert_or_panic(vec[170] == true);
        assert_or_panic(vec[171] == false);
        assert_or_panic(vec[172] == true);
        assert_or_panic(vec[173] == true);
        assert_or_panic(vec[174] == true);
        assert_or_panic(vec[175] == true);
        assert_or_panic(vec[176] == true);
        assert_or_panic(vec[177] == true);
        assert_or_panic(vec[178] == true);
        assert_or_panic(vec[179] == false);
        assert_or_panic(vec[180] == true);
        assert_or_panic(vec[181] == false);
        assert_or_panic(vec[182] == false);
        assert_or_panic(vec[183] == false);
        assert_or_panic(vec[184] == true);
        assert_or_panic(vec[185] == false);
        assert_or_panic(vec[186] == true);
        assert_or_panic(vec[187] == true);
        assert_or_panic(vec[188] == false);
        assert_or_panic(vec[189] == true);
        assert_or_panic(vec[190] == false);
        assert_or_panic(vec[191] == true);
        assert_or_panic(vec[192] == false);
        assert_or_panic(vec[193] == true);
        assert_or_panic(vec[194] == false);
        assert_or_panic(vec[195] == false);
        assert_or_panic(vec[196] == true);
        assert_or_panic(vec[197] == true);
        assert_or_panic(vec[198] == true);
        assert_or_panic(vec[199] == true);
        assert_or_panic(vec[200] == true);
        assert_or_panic(vec[201] == true);
        assert_or_panic(vec[202] == true);
        assert_or_panic(vec[203] == false);
        assert_or_panic(vec[204] == true);
        assert_or_panic(vec[205] == false);
        assert_or_panic(vec[206] == false);
        assert_or_panic(vec[207] == true);
        assert_or_panic(vec[208] == true);
        assert_or_panic(vec[209] == false);
        assert_or_panic(vec[210] == false);
        assert_or_panic(vec[211] == false);
        assert_or_panic(vec[212] == true);
        assert_or_panic(vec[213] == true);
        assert_or_panic(vec[214] == true);
        assert_or_panic(vec[215] == false);
        assert_or_panic(vec[216] == false);
        assert_or_panic(vec[217] == true);
        assert_or_panic(vec[218] == true);
        assert_or_panic(vec[219] == true);
        assert_or_panic(vec[220] == true);
        assert_or_panic(vec[221] == false);
        assert_or_panic(vec[222] == true);
        assert_or_panic(vec[223] == false);
        assert_or_panic(vec[224] == true);
        assert_or_panic(vec[225] == true);
        assert_or_panic(vec[226] == true);
        assert_or_panic(vec[227] == false);
        assert_or_panic(vec[228] == false);
        assert_or_panic(vec[229] == false);
        assert_or_panic(vec[230] == false);
        assert_or_panic(vec[231] == false);
        assert_or_panic(vec[232] == true);
        assert_or_panic(vec[233] == true);
        assert_or_panic(vec[234] == false);
        assert_or_panic(vec[235] == false);
        assert_or_panic(vec[236] == false);
        assert_or_panic(vec[237] == true);
        assert_or_panic(vec[238] == true);
        assert_or_panic(vec[239] == false);
        assert_or_panic(vec[240] == true);
        assert_or_panic(vec[241] == true);
        assert_or_panic(vec[242] == true);
        assert_or_panic(vec[243] == false);
        assert_or_panic(vec[244] == true);
        assert_or_panic(vec[245] == true);
        assert_or_panic(vec[246] == false);
        assert_or_panic(vec[247] == true);
        assert_or_panic(vec[248] == false);
        assert_or_panic(vec[249] == false);
        assert_or_panic(vec[250] == true);
        assert_or_panic(vec[251] == true);
        assert_or_panic(vec[252] == false);
        assert_or_panic(vec[253] == true);
        assert_or_panic(vec[254] == false);
        assert_or_panic(vec[255] == true);
    }
    {
        zig_vector_512_bool((Vector512Bool){
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
        });

        Vector512Bool vec = zig_ret_vector_512_bool();
        assert_or_panic(vec[0] == true);
        assert_or_panic(vec[1] == true);
        assert_or_panic(vec[2] == true);
        assert_or_panic(vec[3] == true);
        assert_or_panic(vec[4] == false);
        assert_or_panic(vec[5] == true);
        assert_or_panic(vec[6] == false);
        assert_or_panic(vec[7] == true);
        assert_or_panic(vec[8] == true);
        assert_or_panic(vec[9] == true);
        assert_or_panic(vec[10] == false);
        assert_or_panic(vec[11] == true);
        assert_or_panic(vec[12] == false);
        assert_or_panic(vec[13] == false);
        assert_or_panic(vec[14] == false);
        assert_or_panic(vec[15] == true);
        assert_or_panic(vec[16] == true);
        assert_or_panic(vec[17] == false);
        assert_or_panic(vec[18] == false);
        assert_or_panic(vec[19] == false);
        assert_or_panic(vec[20] == true);
        assert_or_panic(vec[21] == true);
        assert_or_panic(vec[22] == false);
        assert_or_panic(vec[23] == false);
        assert_or_panic(vec[24] == false);
        assert_or_panic(vec[25] == false);
        assert_or_panic(vec[26] == true);
        assert_or_panic(vec[27] == false);
        assert_or_panic(vec[28] == false);
        assert_or_panic(vec[29] == false);
        assert_or_panic(vec[30] == true);
        assert_or_panic(vec[31] == true);
        assert_or_panic(vec[32] == true);
        assert_or_panic(vec[33] == true);
        assert_or_panic(vec[34] == false);
        assert_or_panic(vec[35] == false);
        assert_or_panic(vec[36] == false);
        assert_or_panic(vec[37] == true);
        assert_or_panic(vec[38] == true);
        assert_or_panic(vec[39] == true);
        assert_or_panic(vec[40] == false);
        assert_or_panic(vec[41] == false);
        assert_or_panic(vec[42] == true);
        assert_or_panic(vec[43] == false);
        assert_or_panic(vec[44] == false);
        assert_or_panic(vec[45] == true);
        assert_or_panic(vec[46] == false);
        assert_or_panic(vec[47] == false);
        assert_or_panic(vec[48] == true);
        assert_or_panic(vec[49] == true);
        assert_or_panic(vec[50] == true);
        assert_or_panic(vec[51] == true);
        assert_or_panic(vec[52] == false);
        assert_or_panic(vec[53] == false);
        assert_or_panic(vec[54] == false);
        assert_or_panic(vec[55] == true);
        assert_or_panic(vec[56] == false);
        assert_or_panic(vec[57] == true);
        assert_or_panic(vec[58] == false);
        assert_or_panic(vec[59] == true);
        assert_or_panic(vec[60] == true);
        assert_or_panic(vec[61] == false);
        assert_or_panic(vec[62] == false);
        assert_or_panic(vec[63] == true);
        assert_or_panic(vec[64] == true);
        assert_or_panic(vec[65] == false);
        assert_or_panic(vec[66] == true);
        assert_or_panic(vec[67] == false);
        assert_or_panic(vec[68] == false);
        assert_or_panic(vec[69] == false);
        assert_or_panic(vec[70] == true);
        assert_or_panic(vec[71] == true);
        assert_or_panic(vec[72] == true);
        assert_or_panic(vec[73] == true);
        assert_or_panic(vec[74] == true);
        assert_or_panic(vec[75] == false);
        assert_or_panic(vec[76] == true);
        assert_or_panic(vec[77] == false);
        assert_or_panic(vec[78] == true);
        assert_or_panic(vec[79] == true);
        assert_or_panic(vec[80] == true);
        assert_or_panic(vec[81] == true);
        assert_or_panic(vec[82] == true);
        assert_or_panic(vec[83] == false);
        assert_or_panic(vec[84] == true);
        assert_or_panic(vec[85] == true);
        assert_or_panic(vec[86] == false);
        assert_or_panic(vec[87] == true);
        assert_or_panic(vec[88] == false);
        assert_or_panic(vec[89] == false);
        assert_or_panic(vec[90] == true);
        assert_or_panic(vec[91] == false);
        assert_or_panic(vec[92] == true);
        assert_or_panic(vec[93] == false);
        assert_or_panic(vec[94] == false);
        assert_or_panic(vec[95] == false);
        assert_or_panic(vec[96] == true);
        assert_or_panic(vec[97] == true);
        assert_or_panic(vec[98] == false);
        assert_or_panic(vec[99] == true);
        assert_or_panic(vec[100] == true);
        assert_or_panic(vec[101] == false);
        assert_or_panic(vec[102] == true);
        assert_or_panic(vec[103] == false);
        assert_or_panic(vec[104] == true);
        assert_or_panic(vec[105] == false);
        assert_or_panic(vec[106] == true);
        assert_or_panic(vec[107] == false);
        assert_or_panic(vec[108] == false);
        assert_or_panic(vec[109] == true);
        assert_or_panic(vec[110] == false);
        assert_or_panic(vec[111] == false);
        assert_or_panic(vec[112] == true);
        assert_or_panic(vec[113] == false);
        assert_or_panic(vec[114] == true);
        assert_or_panic(vec[115] == false);
        assert_or_panic(vec[116] == true);
        assert_or_panic(vec[117] == false);
        assert_or_panic(vec[118] == false);
        assert_or_panic(vec[119] == true);
        assert_or_panic(vec[120] == true);
        assert_or_panic(vec[121] == true);
        assert_or_panic(vec[122] == false);
        assert_or_panic(vec[123] == true);
        assert_or_panic(vec[124] == false);
        assert_or_panic(vec[125] == false);
        assert_or_panic(vec[126] == true);
        assert_or_panic(vec[127] == true);
        assert_or_panic(vec[128] == false);
        assert_or_panic(vec[129] == true);
        assert_or_panic(vec[130] == true);
        assert_or_panic(vec[131] == false);
        assert_or_panic(vec[132] == true);
        assert_or_panic(vec[133] == true);
        assert_or_panic(vec[134] == false);
        assert_or_panic(vec[135] == true);
        assert_or_panic(vec[136] == true);
        assert_or_panic(vec[137] == false);
        assert_or_panic(vec[138] == false);
        assert_or_panic(vec[139] == false);
        assert_or_panic(vec[140] == true);
        assert_or_panic(vec[141] == false);
        assert_or_panic(vec[142] == true);
        assert_or_panic(vec[143] == false);
        assert_or_panic(vec[144] == false);
        assert_or_panic(vec[145] == false);
        assert_or_panic(vec[146] == true);
        assert_or_panic(vec[147] == false);
        assert_or_panic(vec[148] == true);
        assert_or_panic(vec[149] == false);
        assert_or_panic(vec[150] == false);
        assert_or_panic(vec[151] == true);
        assert_or_panic(vec[152] == false);
        assert_or_panic(vec[153] == true);
        assert_or_panic(vec[154] == true);
        assert_or_panic(vec[155] == false);
        assert_or_panic(vec[156] == true);
        assert_or_panic(vec[157] == true);
        assert_or_panic(vec[158] == false);
        assert_or_panic(vec[159] == true);
        assert_or_panic(vec[160] == true);
        assert_or_panic(vec[161] == false);
        assert_or_panic(vec[162] == false);
        assert_or_panic(vec[163] == false);
        assert_or_panic(vec[164] == true);
        assert_or_panic(vec[165] == false);
        assert_or_panic(vec[166] == true);
        assert_or_panic(vec[167] == true);
        assert_or_panic(vec[168] == true);
        assert_or_panic(vec[169] == true);
        assert_or_panic(vec[170] == false);
        assert_or_panic(vec[171] == true);
        assert_or_panic(vec[172] == false);
        assert_or_panic(vec[173] == false);
        assert_or_panic(vec[174] == true);
        assert_or_panic(vec[175] == true);
        assert_or_panic(vec[176] == true);
        assert_or_panic(vec[177] == false);
        assert_or_panic(vec[178] == false);
        assert_or_panic(vec[179] == false);
        assert_or_panic(vec[180] == true);
        assert_or_panic(vec[181] == false);
        assert_or_panic(vec[182] == false);
        assert_or_panic(vec[183] == true);
        assert_or_panic(vec[184] == true);
        assert_or_panic(vec[185] == false);
        assert_or_panic(vec[186] == true);
        assert_or_panic(vec[187] == false);
        assert_or_panic(vec[188] == true);
        assert_or_panic(vec[189] == true);
        assert_or_panic(vec[190] == true);
        assert_or_panic(vec[191] == true);
        assert_or_panic(vec[192] == true);
        assert_or_panic(vec[193] == true);
        assert_or_panic(vec[194] == true);
        assert_or_panic(vec[195] == false);
        assert_or_panic(vec[196] == false);
        assert_or_panic(vec[197] == false);
        assert_or_panic(vec[198] == false);
        assert_or_panic(vec[199] == false);
        assert_or_panic(vec[200] == true);
        assert_or_panic(vec[201] == false);
        assert_or_panic(vec[202] == true);
        assert_or_panic(vec[203] == false);
        assert_or_panic(vec[204] == true);
        assert_or_panic(vec[205] == true);
        assert_or_panic(vec[206] == false);
        assert_or_panic(vec[207] == false);
        assert_or_panic(vec[208] == false);
        assert_or_panic(vec[209] == true);
        assert_or_panic(vec[210] == true);
        assert_or_panic(vec[211] == true);
        assert_or_panic(vec[212] == false);
        assert_or_panic(vec[213] == false);
        assert_or_panic(vec[214] == true);
        assert_or_panic(vec[215] == true);
        assert_or_panic(vec[216] == true);
        assert_or_panic(vec[217] == false);
        assert_or_panic(vec[218] == false);
        assert_or_panic(vec[219] == true);
        assert_or_panic(vec[220] == false);
        assert_or_panic(vec[221] == true);
        assert_or_panic(vec[222] == true);
        assert_or_panic(vec[223] == false);
        assert_or_panic(vec[224] == true);
        assert_or_panic(vec[225] == false);
        assert_or_panic(vec[226] == false);
        assert_or_panic(vec[227] == true);
        assert_or_panic(vec[228] == false);
        assert_or_panic(vec[229] == false);
        assert_or_panic(vec[230] == true);
        assert_or_panic(vec[231] == true);
        assert_or_panic(vec[232] == false);
        assert_or_panic(vec[233] == true);
        assert_or_panic(vec[234] == true);
        assert_or_panic(vec[235] == true);
        assert_or_panic(vec[236] == true);
        assert_or_panic(vec[237] == true);
        assert_or_panic(vec[238] == false);
        assert_or_panic(vec[239] == true);
        assert_or_panic(vec[240] == false);
        assert_or_panic(vec[241] == false);
        assert_or_panic(vec[242] == true);
        assert_or_panic(vec[243] == false);
        assert_or_panic(vec[244] == true);
        assert_or_panic(vec[245] == false);
        assert_or_panic(vec[246] == true);
        assert_or_panic(vec[247] == false);
        assert_or_panic(vec[248] == true);
        assert_or_panic(vec[249] == true);
        assert_or_panic(vec[250] == true);
        assert_or_panic(vec[251] == true);
        assert_or_panic(vec[252] == true);
        assert_or_panic(vec[253] == false);
        assert_or_panic(vec[254] == false);
        assert_or_panic(vec[255] == false);
        assert_or_panic(vec[256] == false);
        assert_or_panic(vec[257] == false);
        assert_or_panic(vec[258] == false);
        assert_or_panic(vec[259] == true);
        assert_or_panic(vec[260] == true);
        assert_or_panic(vec[261] == true);
        assert_or_panic(vec[262] == true);
        assert_or_panic(vec[263] == false);
        assert_or_panic(vec[264] == false);
        assert_or_panic(vec[265] == false);
        assert_or_panic(vec[266] == true);
        assert_or_panic(vec[267] == false);
        assert_or_panic(vec[268] == true);
        assert_or_panic(vec[269] == false);
        assert_or_panic(vec[270] == true);
        assert_or_panic(vec[271] == true);
        assert_or_panic(vec[272] == true);
        assert_or_panic(vec[273] == true);
        assert_or_panic(vec[274] == true);
        assert_or_panic(vec[275] == true);
        assert_or_panic(vec[276] == false);
        assert_or_panic(vec[277] == false);
        assert_or_panic(vec[278] == true);
        assert_or_panic(vec[279] == true);
        assert_or_panic(vec[280] == false);
        assert_or_panic(vec[281] == false);
        assert_or_panic(vec[282] == false);
        assert_or_panic(vec[283] == false);
        assert_or_panic(vec[284] == true);
        assert_or_panic(vec[285] == true);
        assert_or_panic(vec[286] == true);
        assert_or_panic(vec[287] == false);
        assert_or_panic(vec[288] == false);
        assert_or_panic(vec[289] == false);
        assert_or_panic(vec[290] == true);
        assert_or_panic(vec[291] == false);
        assert_or_panic(vec[292] == true);
        assert_or_panic(vec[293] == true);
        assert_or_panic(vec[294] == false);
        assert_or_panic(vec[295] == true);
        assert_or_panic(vec[296] == true);
        assert_or_panic(vec[297] == true);
        assert_or_panic(vec[298] == false);
        assert_or_panic(vec[299] == true);
        assert_or_panic(vec[300] == true);
        assert_or_panic(vec[301] == false);
        assert_or_panic(vec[302] == false);
        assert_or_panic(vec[303] == true);
        assert_or_panic(vec[304] == false);
        assert_or_panic(vec[305] == false);
        assert_or_panic(vec[306] == true);
        assert_or_panic(vec[307] == true);
        assert_or_panic(vec[308] == true);
        assert_or_panic(vec[309] == true);
        assert_or_panic(vec[310] == false);
        assert_or_panic(vec[311] == false);
        assert_or_panic(vec[312] == false);
        assert_or_panic(vec[313] == false);
        assert_or_panic(vec[314] == false);
        assert_or_panic(vec[315] == true);
        assert_or_panic(vec[316] == false);
        assert_or_panic(vec[317] == false);
        assert_or_panic(vec[318] == true);
        assert_or_panic(vec[319] == false);
        assert_or_panic(vec[320] == false);
        assert_or_panic(vec[321] == true);
        assert_or_panic(vec[322] == true);
        assert_or_panic(vec[323] == true);
        assert_or_panic(vec[324] == true);
        assert_or_panic(vec[325] == false);
        assert_or_panic(vec[326] == false);
        assert_or_panic(vec[327] == false);
        assert_or_panic(vec[328] == true);
        assert_or_panic(vec[329] == true);
        assert_or_panic(vec[330] == false);
        assert_or_panic(vec[331] == true);
        assert_or_panic(vec[332] == true);
        assert_or_panic(vec[333] == false);
        assert_or_panic(vec[334] == false);
        assert_or_panic(vec[335] == true);
        assert_or_panic(vec[336] == true);
        assert_or_panic(vec[337] == false);
        assert_or_panic(vec[338] == true);
        assert_or_panic(vec[339] == true);
        assert_or_panic(vec[340] == true);
        assert_or_panic(vec[341] == false);
        assert_or_panic(vec[342] == false);
        assert_or_panic(vec[343] == false);
        assert_or_panic(vec[344] == true);
        assert_or_panic(vec[345] == true);
        assert_or_panic(vec[346] == false);
        assert_or_panic(vec[347] == true);
        assert_or_panic(vec[348] == false);
        assert_or_panic(vec[349] == true);
        assert_or_panic(vec[350] == false);
        assert_or_panic(vec[351] == false);
        assert_or_panic(vec[352] == true);
        assert_or_panic(vec[353] == false);
        assert_or_panic(vec[354] == true);
        assert_or_panic(vec[355] == false);
        assert_or_panic(vec[356] == false);
        assert_or_panic(vec[357] == false);
        assert_or_panic(vec[358] == false);
        assert_or_panic(vec[359] == false);
        assert_or_panic(vec[360] == true);
        assert_or_panic(vec[361] == true);
        assert_or_panic(vec[362] == false);
        assert_or_panic(vec[363] == false);
        assert_or_panic(vec[364] == false);
        assert_or_panic(vec[365] == false);
        assert_or_panic(vec[366] == true);
        assert_or_panic(vec[367] == false);
        assert_or_panic(vec[368] == true);
        assert_or_panic(vec[369] == false);
        assert_or_panic(vec[370] == true);
        assert_or_panic(vec[371] == true);
        assert_or_panic(vec[372] == false);
        assert_or_panic(vec[373] == true);
        assert_or_panic(vec[374] == true);
        assert_or_panic(vec[375] == true);
        assert_or_panic(vec[376] == true);
        assert_or_panic(vec[377] == true);
        assert_or_panic(vec[378] == false);
        assert_or_panic(vec[379] == true);
        assert_or_panic(vec[380] == false);
        assert_or_panic(vec[381] == true);
        assert_or_panic(vec[382] == true);
        assert_or_panic(vec[383] == true);
        assert_or_panic(vec[384] == true);
        assert_or_panic(vec[385] == true);
        assert_or_panic(vec[386] == false);
        assert_or_panic(vec[387] == true);
        assert_or_panic(vec[388] == true);
        assert_or_panic(vec[389] == false);
        assert_or_panic(vec[390] == true);
        assert_or_panic(vec[391] == false);
        assert_or_panic(vec[392] == true);
        assert_or_panic(vec[393] == false);
        assert_or_panic(vec[394] == true);
        assert_or_panic(vec[395] == false);
        assert_or_panic(vec[396] == true);
        assert_or_panic(vec[397] == false);
        assert_or_panic(vec[398] == false);
        assert_or_panic(vec[399] == true);
        assert_or_panic(vec[400] == true);
        assert_or_panic(vec[401] == true);
        assert_or_panic(vec[402] == true);
        assert_or_panic(vec[403] == false);
        assert_or_panic(vec[404] == false);
        assert_or_panic(vec[405] == true);
        assert_or_panic(vec[406] == false);
        assert_or_panic(vec[407] == false);
        assert_or_panic(vec[408] == false);
        assert_or_panic(vec[409] == true);
        assert_or_panic(vec[410] == false);
        assert_or_panic(vec[411] == true);
        assert_or_panic(vec[412] == true);
        assert_or_panic(vec[413] == false);
        assert_or_panic(vec[414] == true);
        assert_or_panic(vec[415] == true);
        assert_or_panic(vec[416] == false);
        assert_or_panic(vec[417] == true);
        assert_or_panic(vec[418] == true);
        assert_or_panic(vec[419] == false);
        assert_or_panic(vec[420] == false);
        assert_or_panic(vec[421] == true);
        assert_or_panic(vec[422] == false);
        assert_or_panic(vec[423] == false);
        assert_or_panic(vec[424] == true);
        assert_or_panic(vec[425] == false);
        assert_or_panic(vec[426] == true);
        assert_or_panic(vec[427] == false);
        assert_or_panic(vec[428] == false);
        assert_or_panic(vec[429] == true);
        assert_or_panic(vec[430] == false);
        assert_or_panic(vec[431] == true);
        assert_or_panic(vec[432] == true);
        assert_or_panic(vec[433] == false);
        assert_or_panic(vec[434] == true);
        assert_or_panic(vec[435] == false);
        assert_or_panic(vec[436] == true);
        assert_or_panic(vec[437] == false);
        assert_or_panic(vec[438] == true);
        assert_or_panic(vec[439] == false);
        assert_or_panic(vec[440] == false);
        assert_or_panic(vec[441] == true);
        assert_or_panic(vec[442] == true);
        assert_or_panic(vec[443] == false);
        assert_or_panic(vec[444] == true);
        assert_or_panic(vec[445] == true);
        assert_or_panic(vec[446] == false);
        assert_or_panic(vec[447] == true);
        assert_or_panic(vec[448] == true);
        assert_or_panic(vec[449] == false);
        assert_or_panic(vec[450] == false);
        assert_or_panic(vec[451] == false);
        assert_or_panic(vec[452] == false);
        assert_or_panic(vec[453] == false);
        assert_or_panic(vec[454] == true);
        assert_or_panic(vec[455] == false);
        assert_or_panic(vec[456] == false);
        assert_or_panic(vec[457] == true);
        assert_or_panic(vec[458] == false);
        assert_or_panic(vec[459] == true);
        assert_or_panic(vec[460] == false);
        assert_or_panic(vec[461] == false);
        assert_or_panic(vec[462] == false);
        assert_or_panic(vec[463] == true);
        assert_or_panic(vec[464] == false);
        assert_or_panic(vec[465] == true);
        assert_or_panic(vec[466] == false);
        assert_or_panic(vec[467] == false);
        assert_or_panic(vec[468] == false);
        assert_or_panic(vec[469] == false);
        assert_or_panic(vec[470] == true);
        assert_or_panic(vec[471] == true);
        assert_or_panic(vec[472] == false);
        assert_or_panic(vec[473] == true);
        assert_or_panic(vec[474] == true);
        assert_or_panic(vec[475] == false);
        assert_or_panic(vec[476] == false);
        assert_or_panic(vec[477] == true);
        assert_or_panic(vec[478] == true);
        assert_or_panic(vec[479] == true);
        assert_or_panic(vec[480] == false);
        assert_or_panic(vec[481] == false);
        assert_or_panic(vec[482] == true);
        assert_or_panic(vec[483] == false);
        assert_or_panic(vec[484] == false);
        assert_or_panic(vec[485] == false);
        assert_or_panic(vec[486] == true);
        assert_or_panic(vec[487] == true);
        assert_or_panic(vec[488] == false);
        assert_or_panic(vec[489] == false);
        assert_or_panic(vec[490] == false);
        assert_or_panic(vec[491] == false);
        assert_or_panic(vec[492] == false);
        assert_or_panic(vec[493] == true);
        assert_or_panic(vec[494] == true);
        assert_or_panic(vec[495] == true);
        assert_or_panic(vec[496] == true);
        assert_or_panic(vec[497] == false);
        assert_or_panic(vec[498] == false);
        assert_or_panic(vec[499] == false);
        assert_or_panic(vec[500] == true);
        assert_or_panic(vec[501] == false);
        assert_or_panic(vec[502] == true);
        assert_or_panic(vec[503] == true);
        assert_or_panic(vec[504] == true);
        assert_or_panic(vec[505] == true);
        assert_or_panic(vec[506] == false);
        assert_or_panic(vec[507] == false);
        assert_or_panic(vec[508] == true);
        assert_or_panic(vec[509] == true);
        assert_or_panic(vec[510] == false);
        assert_or_panic(vec[511] == false);
    }
#endif
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

#ifndef ZIG_NO_I128
void c_struct_u128(struct u128 x) {
    assert_or_panic(x.value == 0xfffffffffffffffcULL);
}
#endif

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

#ifndef ZIG_NO_I128
void c_struct_i128(struct i128 x) {
    assert_or_panic(x.value == -6);
}
#endif

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
    assert_or_panic(x == (void *)0xdeadbeefL);
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

void c_med_struct_ints(struct MedStructInts s) {
    assert_or_panic(s.x == 1);
    assert_or_panic(s.y == 2);
    assert_or_panic(s.z == 3);

    struct MedStructInts s2 = zig_ret_med_struct_ints();

    assert_or_panic(s2.x == 1);
    assert_or_panic(s2.y == 2);
    assert_or_panic(s2.z == 3);
}

struct MedStructInts c_ret_med_struct_ints() {
    struct MedStructInts s = {
        .x = 1,
        .y = 2,
        .z = 3,
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

#ifndef ZIG_NO_I128
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
#endif

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

typedef struct {
    uint32_t a;
    uint8_t padding[4];
    uint64_t b;
} StructWithArray;

void c_struct_with_array(StructWithArray x) {
    assert_or_panic(x.a == 1);
    assert_or_panic(x.b == 2);
}

StructWithArray c_ret_struct_with_array() {
    return (StructWithArray){4, {}, 155};
}

typedef struct {
    struct Point {
        double x;
        double y;
    } origin;
    struct Size {
        double width;
        double height;
    } size;
} FloatArrayStruct;

void c_float_array_struct(FloatArrayStruct x) {
    assert_or_panic(x.origin.x == 5);
    assert_or_panic(x.origin.y == 6);
    assert_or_panic(x.size.width == 7);
    assert_or_panic(x.size.height == 8);
}

FloatArrayStruct c_ret_float_array_struct() {
    FloatArrayStruct x;
    x.origin.x = 1;
    x.origin.y = 2;
    x.size.width = 3;
    x.size.height = 4;
    return x;
}

typedef uint32_t SmallVec __attribute__((vector_size(2 * sizeof(uint32_t))));

void c_small_vec(SmallVec vec) {
    assert_or_panic(vec[0] == 1);
    assert_or_panic(vec[1] == 2);
}

SmallVec c_ret_small_vec(void) {
    return (SmallVec){3, 4};
}

typedef size_t MediumVec __attribute__((vector_size(4 * sizeof(size_t))));

void c_medium_vec(MediumVec vec) {
    assert_or_panic(vec[0] == 1);
    assert_or_panic(vec[1] == 2);
    assert_or_panic(vec[2] == 3);
    assert_or_panic(vec[3] == 4);
}

MediumVec c_ret_medium_vec(void) {
    return (MediumVec){5, 6, 7, 8};
}

typedef size_t BigVec __attribute__((vector_size(8 * sizeof(size_t))));

void c_big_vec(BigVec vec) {
    assert_or_panic(vec[0] == 1);
    assert_or_panic(vec[1] == 2);
    assert_or_panic(vec[2] == 3);
    assert_or_panic(vec[3] == 4);
    assert_or_panic(vec[4] == 5);
    assert_or_panic(vec[5] == 6);
    assert_or_panic(vec[6] == 7);
    assert_or_panic(vec[7] == 8);
}

BigVec c_ret_big_vec(void) {
    return (BigVec){9, 10, 11, 12, 13, 14, 15, 16};
}

typedef struct {
    float x, y;
} Vector2;

void c_ptr_size_float_struct(Vector2 vec) {
    assert_or_panic(vec.x == 1);
    assert_or_panic(vec.y == 2);
}
Vector2 c_ret_ptr_size_float_struct(void) {
    return (Vector2){3, 4};
}

/// Tests for Double + Char struct
struct DC { double v1; char v2; };

int c_assert_DC(struct DC lv){
  if (lv.v1 != -0.25) return 1;
  if (lv.v2 != 15) return 2;
  return 0;
}
struct DC c_ret_DC(){
    struct DC lv = { .v1 = -0.25, .v2 = 15 };
    return lv;
}
int zig_assert_DC(struct DC);
int c_send_DC(){
    return zig_assert_DC(c_ret_DC());
}
struct DC zig_ret_DC();
int c_assert_ret_DC(){
    return c_assert_DC(zig_ret_DC());
}

/// Tests for Char + Float + Float struct
struct CFF { char v1; float v2; float v3; };

int c_assert_CFF(struct CFF lv){
  if (lv.v1 != 39) return 1;
  if (lv.v2 != 0.875) return 2;
  if (lv.v3 != 1.0) return 3;
  return 0;
}
struct CFF c_ret_CFF(){
    struct CFF lv = { .v1 = 39, .v2 = 0.875, .v3 = 1.0 };
    return lv;
}
int zig_assert_CFF(struct CFF);
int c_send_CFF(){
    return zig_assert_CFF(c_ret_CFF());
}
struct CFF zig_ret_CFF();
int c_assert_ret_CFF(){
    return c_assert_CFF(zig_ret_CFF());
}

struct PD { void* v1; double v2; };

int c_assert_PD(struct PD lv){
  if (lv.v1 != 0) return 1;
  if (lv.v2 != 0.5) return 2;
  return 0;
}
struct PD c_ret_PD(){
    struct PD lv = { .v1 = 0, .v2 = 0.5 };
    return lv;
}
int zig_assert_PD(struct PD);
int c_send_PD(){
    return zig_assert_PD(c_ret_PD());
}
struct PD zig_ret_PD();
int c_assert_ret_PD(){
    return c_assert_PD(zig_ret_PD());
}

struct ByRef {
    int val;
    int arr[15];
};
struct ByRef c_modify_by_ref_param(struct ByRef in) {
    in.val = 42;
    return in;
}

struct ByVal {
    struct {
        unsigned long x;
        unsigned long y;
        unsigned long z;
    } origin;
    struct {
        unsigned long width;
        unsigned long height;
        unsigned long depth;
    } size;
};

void c_func_ptr_byval(void *a, void *b, struct ByVal in, unsigned long c, void *d, unsigned long e) {
    assert_or_panic((intptr_t)a == 1);
    assert_or_panic((intptr_t)b == 2);

    assert_or_panic(in.origin.x == 9);
    assert_or_panic(in.origin.y == 10);
    assert_or_panic(in.origin.z == 11);
    assert_or_panic(in.size.width == 12);
    assert_or_panic(in.size.height == 13);
    assert_or_panic(in.size.depth == 14);

    assert_or_panic(c == 3);
    assert_or_panic((intptr_t)d == 4);
    assert_or_panic(e == 5);
}

#ifndef ZIG_NO_RAW_F16
__fp16 c_f16(__fp16 a) {
    assert_or_panic(a == 12);
    return 34;
}
#endif

typedef struct {
    __fp16 a;
} f16_struct;
f16_struct c_f16_struct(f16_struct a) {
    assert_or_panic(a.a == 12);
    return (f16_struct){34};
}

#if defined __x86_64__ || defined __i386__
typedef long double f80;
f80 c_f80(f80 a) {
    assert_or_panic((double)a == 12.34);
    return 56.78;
}
typedef struct {
    f80 a;
} f80_struct;
f80_struct c_f80_struct(f80_struct a) {
    assert_or_panic((double)a.a == 12.34);
    return (f80_struct){56.78};
}
typedef struct {
    f80 a;
    int b;
} f80_extra_struct;
f80_extra_struct c_f80_extra_struct(f80_extra_struct a) {
    assert_or_panic((double)a.a == 12.34);
    assert_or_panic(a.b == 42);
    return (f80_extra_struct){56.78, 24};
}
#endif

#ifndef ZIG_NO_F128
__float128 zig_f128(__float128 a);
__float128 c_f128(__float128 a) {
    assert_or_panic((double)a == 12.34);
    assert_or_panic(zig_f128(12) == 34);
    return 56.78;
}
typedef struct {
    __float128 a;
} f128_struct;
f128_struct zig_f128_struct(f128_struct a);
f128_struct c_f128_struct(f128_struct a) {
    assert_or_panic((double)a.a == 12.34);
    f128_struct b = zig_f128_struct((f128_struct){12345});
    assert_or_panic(b.a == 98765);
    return (f128_struct){56.78};
}

typedef struct {
    __float128 a, b;
} f128_f128_struct;
f128_f128_struct zig_f128_f128_struct(f128_f128_struct a);
f128_f128_struct c_f128_f128_struct(f128_f128_struct a) {
    assert_or_panic((double)a.a == 12.34);
    assert_or_panic((double)a.b == 87.65);
    f128_f128_struct b = zig_f128_f128_struct((f128_f128_struct){13, 57});
    assert_or_panic((double)b.a == 24);
    assert_or_panic((double)b.b == 68);
    return (f128_f128_struct){56.78, 43.21};
}
#endif

void __attribute__((stdcall)) stdcall_scalars(char a, short b, int c, float d, double e) {
    assert_or_panic(a == 1);
    assert_or_panic(b == 2);
    assert_or_panic(c == 3);
    assert_or_panic(d == 4.0);
    assert_or_panic(e == 5.0);
}

typedef struct {
    short x;
    short y;
} Coord2;

Coord2 __attribute__((stdcall)) stdcall_coord2(Coord2 a, Coord2 b, Coord2 c) {
    assert_or_panic(a.x == 0x1111);
    assert_or_panic(a.y == 0x2222);
    assert_or_panic(b.x == 0x3333);
    assert_or_panic(b.y == 0x4444);
    assert_or_panic(c.x == 0x5555);
    assert_or_panic(c.y == 0x6666);
    return (Coord2){123, 456};
}

void __attribute__((stdcall)) stdcall_big_union(union BigUnion x) {
    assert_or_panic(x.a.a == 1);
    assert_or_panic(x.a.b == 2);
    assert_or_panic(x.a.c == 3);
    assert_or_panic(x.a.d == 4);
}

#ifdef __x86_64__
struct ByRef __attribute__((ms_abi)) c_explict_win64(struct ByRef in) {
    in.val = 42;
    return in;
}

struct ByRef __attribute__((sysv_abi)) c_explict_sys_v(struct ByRef in) {
    in.val = 42;
    return in;
}
#endif


struct byval_tail_callsite_attr_Point {
    double x;
    double y;
} Point;
struct byval_tail_callsite_attr_Size {
    double width;
    double height;
} Size;
struct byval_tail_callsite_attr_Rect {
    struct byval_tail_callsite_attr_Point origin;
    struct byval_tail_callsite_attr_Size size;
};
double c_byval_tail_callsite_attr(struct byval_tail_callsite_attr_Rect in) {
    return in.size.width;
}
