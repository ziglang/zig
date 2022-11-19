// TODO get rid of _GNU_SOURCE
#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifdef __linux__
#include <sys/random.h>
#endif

#include <zstd.h>

#if defined(__APPLE__)
#define ZIG_TRIPLE_OS "macos"
#elif defined(_WIN32)
#define ZIG_TRIPLE_OS "windows"
#elif defined(__linux__)
#define ZIG_TRIPLE_OS "linux"
#elif defined(__FreeBSD__)
#define ZIG_TRIPLE_OS "freebsd"
#elif defined(__NetBSD__)
#define ZIG_TRIPLE_OS "netbsd"
#elif defined(__DragonFly__)
#define ZIG_TRIPLE_OS "dragonfly"
#elif defined(__OpenBSD__)
#define ZIG_TRIPLE_OS "openbsd"
#elif defined(__HAIKU__)
#define ZIG_TRIPLE_OS "haiku"
#elif defined(__sun)
#define ZIG_TRIPLE_OS "solaris"
#else
#error please add more os definitions above this line
#endif

#if defined(__x86_64__)
#define ZIG_TRIPLE_ARCH "x86_64"
#elif defined(__aarch64__)
#define ZIG_TRIPLE_ARCH "aarch64"
#elif defined(__ARM_EABI__)
#define ZIG_TRIPLE_ARCH "arm"
#else
#error please add more arch definitions above this line
#endif

enum wasi_errno_t {
    WASI_ESUCCESS = 0,
    WASI_E2BIG = 1,
    WASI_EACCES = 2,
    WASI_EADDRINUSE = 3,
    WASI_EADDRNOTAVAIL = 4,
    WASI_EAFNOSUPPORT = 5,
    WASI_EAGAIN = 6,
    WASI_EALREADY = 7,
    WASI_EBADF = 8,
    WASI_EBADMSG = 9,
    WASI_EBUSY = 10,
    WASI_ECANCELED = 11,
    WASI_ECHILD = 12,
    WASI_ECONNABORTED = 13,
    WASI_ECONNREFUSED = 14,
    WASI_ECONNRESET = 15,
    WASI_EDEADLK = 16,
    WASI_EDESTADDRREQ = 17,
    WASI_EDOM = 18,
    WASI_EDQUOT = 19,
    WASI_EEXIST = 20,
    WASI_EFAULT = 21,
    WASI_EFBIG = 22,
    WASI_EHOSTUNREACH = 23,
    WASI_EIDRM = 24,
    WASI_EILSEQ = 25,
    WASI_EINPROGRESS = 26,
    WASI_EINTR = 27,
    WASI_EINVAL = 28,
    WASI_EIO = 29,
    WASI_EISCONN = 30,
    WASI_EISDIR = 31,
    WASI_ELOOP = 32,
    WASI_EMFILE = 33,
    WASI_EMLINK = 34,
    WASI_EMSGSIZE = 35,
    WASI_EMULTIHOP = 36,
    WASI_ENAMETOOLONG = 37,
    WASI_ENETDOWN = 38,
    WASI_ENETRESET = 39,
    WASI_ENETUNREACH = 40,
    WASI_ENFILE = 41,
    WASI_ENOBUFS = 42,
    WASI_ENODEV = 43,
    WASI_ENOENT = 44,
    WASI_ENOEXEC = 45,
    WASI_ENOLCK = 46,
    WASI_ENOLINK = 47,
    WASI_ENOMEM = 48,
    WASI_ENOMSG = 49,
    WASI_ENOPROTOOPT = 50,
    WASI_ENOSPC = 51,
    WASI_ENOSYS = 52,
    WASI_ENOTCONN = 53,
    WASI_ENOTDIR = 54,
    WASI_ENOTEMPTY = 55,
    WASI_ENOTRECOVERABLE = 56,
    WASI_ENOTSOCK = 57,
    WASI_EOPNOTSUPP = 58,
    WASI_ENOTTY = 59,
    WASI_ENXIO = 60,
    WASI_EOVERFLOW = 61,
    WASI_EOWNERDEAD = 62,
    WASI_EPERM = 63,
    WASI_EPIPE = 64,
    WASI_EPROTO = 65,
    WASI_EPROTONOSUPPORT = 66,
    WASI_EPROTOTYPE = 67,
    WASI_ERANGE = 68,
    WASI_EROFS = 69,
    WASI_ESPIPE = 70,
    WASI_ESRCH = 71,
    WASI_ESTALE = 72,
    WASI_ETIMEDOUT = 73,
    WASI_ETXTBSY = 74,
    WASI_EXDEV = 75,
    WASI_ENOTCAPABLE = 76,
};

static void panic(const char *msg) {
    fprintf(stderr, "%s\n", msg);
    abort();
}

static uint32_t min_u32(uint32_t a, uint32_t b) {
    return (a < b) ? a : b;
}

static uint32_t rotl32(uint32_t n, unsigned c) {
    const unsigned mask = CHAR_BIT * sizeof(n) - 1;
    c &= mask & 31;
    return (n << c) | (n >> ((-c) & mask));
}

static uint32_t rotr32(uint32_t n, unsigned c) {
    const unsigned mask = CHAR_BIT * sizeof(n) - 1;
    c &= mask & 31;
    return (n >> c) | (n << ((-c) & mask));
}

static uint64_t rotl64(uint64_t n, unsigned c) {
    const unsigned mask = CHAR_BIT * sizeof(n) - 1;
    c &= mask & 63;
    return (n << c) | (n >> ((-c) & mask));
}

static uint64_t rotr64(uint64_t n, unsigned c) {
    const unsigned mask = CHAR_BIT * sizeof(n) - 1;
    c &= mask & 63;
    return (n >> c) | (n << ((-c) & mask));
}

static void *arena_alloc(size_t n) {
    void *ptr = malloc(n);
    if (!ptr) panic("out of memory");
#ifndef NDEBUG
    memset(ptr, 0xaa, n); // to match the zig version
#endif
    return ptr;
}

static int err_wrap(const char *prefix, int rc) {
    if (rc == -1) {
        perror(prefix);
        abort();
    }
    return rc;
}

static bool bs_isSet(const uint32_t *bitset, uint32_t index) {
    return (bitset[index >> 5] >> (index & 0x1f)) & 1;
}
static void bs_set(uint32_t *bitset, uint32_t index) {
    bitset[index >> 5] |= ((uint32_t)1 << (index & 0x1f));
}
static void bs_unset(uint32_t *bitset, uint32_t index) {
    bitset[index >> 5] &= ~((uint32_t)1 << (index & 0x1f));
}
static void bs_setValue(uint32_t *bitset, uint32_t index, bool value) {
    if (value) bs_set(bitset, index); else bs_unset(bitset, index);
}

struct ByteSlice {
    char *ptr;
    size_t len;
};

static struct ByteSlice read_file_alloc(const char *file_path) {
    FILE *f = fopen(file_path, "rb");
    if (!f) {
        fprintf(stderr, "failed to read %s: ", file_path);
        perror("");
        abort();
    }
    if (fseek(f, 0L, SEEK_END) == -1) panic("failed to seek");
    struct ByteSlice res;
    res.len = ftell(f);
    res.ptr = malloc(res.len);
    rewind(f);
    size_t amt_read = fread(res.ptr, 1, res.len, f);
    if (amt_read != res.len) panic("short read");
    fclose(f);
    return res;
}


struct Preopen {
    int wasi_fd; 
    int host_fd;
    const char *name;
    size_t name_len;
};

static struct Preopen preopens_buffer[10];
static size_t preopens_len = 0;

static void add_preopen(int wasi_fd, const char *name, int host_fd) {
    preopens_buffer[preopens_len].wasi_fd = wasi_fd;
    preopens_buffer[preopens_len].host_fd = host_fd;
    preopens_buffer[preopens_len].name = name;
    preopens_buffer[preopens_len].name_len = strlen(name);
    preopens_len += 1;
}

static const struct Preopen *find_preopen(int32_t wasi_fd) {
    for (size_t i = 0; i < preopens_len; i += 1) {
        const struct Preopen *preopen = &preopens_buffer[i];
        if (preopen->wasi_fd == wasi_fd) {
            return preopen;
        }
    }
    return NULL;
}

static const uint32_t max_memory = 2ul * 1024ul * 1024ul * 1024ul; // 2 GiB

static uint16_t read_u16_le(const char *ptr) {
    const uint8_t *u8_ptr = (const uint8_t *)ptr;
    return
        (((uint64_t)u8_ptr[0]) << 0x00) |
        (((uint64_t)u8_ptr[1]) << 0x08);
}

static int16_t read_i16_le(const char *ptr) {
    return read_u16_le(ptr);
}

static uint32_t read_u32_le(const char *ptr) {
    const uint8_t *u8_ptr = (const uint8_t *)ptr;
    return
        (((uint64_t)u8_ptr[0]) << 0x00) |
        (((uint64_t)u8_ptr[1]) << 0x08) |
        (((uint64_t)u8_ptr[2]) << 0x10) |
        (((uint64_t)u8_ptr[3]) << 0x18);
}

static uint32_t read_i32_le(const char *ptr) {
    return read_u32_le(ptr);
}

static uint64_t read_u64_le(const char *ptr) {
    const uint8_t *u8_ptr = (const uint8_t *)ptr;
    return
        (((uint64_t)u8_ptr[0]) << 0x00) |
        (((uint64_t)u8_ptr[1]) << 0x08) |
        (((uint64_t)u8_ptr[2]) << 0x10) |
        (((uint64_t)u8_ptr[3]) << 0x18) |
        (((uint64_t)u8_ptr[4]) << 0x20) |
        (((uint64_t)u8_ptr[5]) << 0x28) |
        (((uint64_t)u8_ptr[6]) << 0x30) |
        (((uint64_t)u8_ptr[7]) << 0x38);
}

static void write_u16_le(char *ptr, uint16_t x) {
    uint8_t *u8_ptr = (uint8_t*)ptr;
    u8_ptr[0] = (x >> 0x00);
    u8_ptr[1] = (x >> 0x08);
}

static void write_u32_le(char *ptr, uint32_t x) {
    uint8_t *u8_ptr = (uint8_t*)ptr;
    u8_ptr[0] = (x >> 0x00);
    u8_ptr[1] = (x >> 0x08);
    u8_ptr[2] = (x >> 0x10);
    u8_ptr[3] = (x >> 0x18);
}

static void write_u64_le(char *ptr, uint64_t x) {
    uint8_t *u8_ptr = (uint8_t*)ptr;
    u8_ptr[0] = (x >> 0x00);
    u8_ptr[1] = (x >> 0x08);
    u8_ptr[2] = (x >> 0x10);
    u8_ptr[3] = (x >> 0x18);
    u8_ptr[4] = (x >> 0x20);
    u8_ptr[5] = (x >> 0x28);
    u8_ptr[6] = (x >> 0x30);
    u8_ptr[7] = (x >> 0x38);
}

static uint32_t read32_uleb128(const char *ptr, uint32_t *i) {
    uint32_t result = 0;
    uint32_t shift = 0;

    for (;;) {
        uint32_t byte = ptr[*i];
        *i += 1;
        result |= ((byte & 0x7f) << shift);
        shift += 7;
        if ((byte & 0x80) == 0) return result;
        if (shift >= 32) panic("read32_uleb128 failed");
    }
}

static int64_t read64_ileb128(const char *ptr, uint32_t *i) {
    int64_t result = 0;
    uint32_t shift = 0;

    for (;;) {
        uint64_t byte = ptr[*i];
        *i += 1;
        result |= ((byte & 0x7f) << shift);
        shift += 7;
        if ((byte & 0x80) == 0) {
            if ((byte & 0x40) && (shift < 64)) {
                uint64_t extend = 0;
                result |= (~extend << shift);
            }
            return result;
        }
        if (shift >= 64) panic("read64_ileb128 failed");
    }
}

static int32_t read32_ileb128(const char *ptr, uint32_t *i) {
    return read64_ileb128(ptr, i);
}

static struct ByteSlice read_name(char *ptr, uint32_t *i) {
    uint32_t len = read32_uleb128(ptr, i);
    struct ByteSlice res;
    res.ptr = ptr + *i;
    res.len = len;
    *i += len;
    return res;
}

enum Section {
    Section_custom,
    Section_type,
    Section_import,
    Section_function,
    Section_table,
    Section_memory,
    Section_global,
    Section_export,
    Section_start,
    Section_element,
    Section_code,
    Section_data,
    Section_data_count,
};

enum Op {
    Op_unreachable,
    Op_br_void,
    Op_br_32,
    Op_br_64,
    Op_br_if_nez_void,
    Op_br_if_nez_32,
    Op_br_if_nez_64,
    Op_br_if_eqz_void,
    Op_br_if_eqz_32,
    Op_br_if_eqz_64,
    Op_br_table_void,
    Op_br_table_32,
    Op_br_table_64,
    Op_return_void,
    Op_return_32,
    Op_return_64,
    Op_call,
    Op_drop_32,
    Op_drop_64,
    Op_select_32,
    Op_select_64,
    Op_local_get_32,
    Op_local_get_64,
    Op_local_set_32,
    Op_local_set_64,
    Op_local_tee_32,
    Op_local_tee_64,
    Op_global_get_0_32,
    Op_global_get_32,
    Op_global_set_0_32,
    Op_global_set_32,
    Op_const_32,
    Op_const_64,
    Op_add_32,
    Op_and_32,
    Op_wasm,
    Op_wasm_prefixed,
};

enum WasmOp {
    WasmOp_unreachable = 0x00,
    WasmOp_nop = 0x01,
    WasmOp_block = 0x02,
    WasmOp_loop = 0x03,
    WasmOp_if = 0x04,
    WasmOp_else = 0x05,
    WasmOp_end = 0x0B,
    WasmOp_br = 0x0C,
    WasmOp_br_if = 0x0D,
    WasmOp_br_table = 0x0E,
    WasmOp_return = 0x0F,
    WasmOp_call = 0x10,
    WasmOp_call_indirect = 0x11,
    WasmOp_drop = 0x1A,
    WasmOp_select = 0x1B,
    WasmOp_local_get = 0x20,
    WasmOp_local_set = 0x21,
    WasmOp_local_tee = 0x22,
    WasmOp_global_get = 0x23,
    WasmOp_global_set = 0x24,
    WasmOp_i32_load = 0x28,
    WasmOp_i64_load = 0x29,
    WasmOp_f32_load = 0x2A,
    WasmOp_f64_load = 0x2B,
    WasmOp_i32_load8_s = 0x2C,
    WasmOp_i32_load8_u = 0x2D,
    WasmOp_i32_load16_s = 0x2E,
    WasmOp_i32_load16_u = 0x2F,
    WasmOp_i64_load8_s = 0x30,
    WasmOp_i64_load8_u = 0x31,
    WasmOp_i64_load16_s = 0x32,
    WasmOp_i64_load16_u = 0x33,
    WasmOp_i64_load32_s = 0x34,
    WasmOp_i64_load32_u = 0x35,
    WasmOp_i32_store = 0x36,
    WasmOp_i64_store = 0x37,
    WasmOp_f32_store = 0x38,
    WasmOp_f64_store = 0x39,
    WasmOp_i32_store8 = 0x3A,
    WasmOp_i32_store16 = 0x3B,
    WasmOp_i64_store8 = 0x3C,
    WasmOp_i64_store16 = 0x3D,
    WasmOp_i64_store32 = 0x3E,
    WasmOp_memory_size = 0x3F,
    WasmOp_memory_grow = 0x40,
    WasmOp_i32_const = 0x41,
    WasmOp_i64_const = 0x42,
    WasmOp_f32_const = 0x43,
    WasmOp_f64_const = 0x44,
    WasmOp_i32_eqz = 0x45,
    WasmOp_i32_eq = 0x46,
    WasmOp_i32_ne = 0x47,
    WasmOp_i32_lt_s = 0x48,
    WasmOp_i32_lt_u = 0x49,
    WasmOp_i32_gt_s = 0x4A,
    WasmOp_i32_gt_u = 0x4B,
    WasmOp_i32_le_s = 0x4C,
    WasmOp_i32_le_u = 0x4D,
    WasmOp_i32_ge_s = 0x4E,
    WasmOp_i32_ge_u = 0x4F,
    WasmOp_i64_eqz = 0x50,
    WasmOp_i64_eq = 0x51,
    WasmOp_i64_ne = 0x52,
    WasmOp_i64_lt_s = 0x53,
    WasmOp_i64_lt_u = 0x54,
    WasmOp_i64_gt_s = 0x55,
    WasmOp_i64_gt_u = 0x56,
    WasmOp_i64_le_s = 0x57,
    WasmOp_i64_le_u = 0x58,
    WasmOp_i64_ge_s = 0x59,
    WasmOp_i64_ge_u = 0x5A,
    WasmOp_f32_eq = 0x5B,
    WasmOp_f32_ne = 0x5C,
    WasmOp_f32_lt = 0x5D,
    WasmOp_f32_gt = 0x5E,
    WasmOp_f32_le = 0x5F,
    WasmOp_f32_ge = 0x60,
    WasmOp_f64_eq = 0x61,
    WasmOp_f64_ne = 0x62,
    WasmOp_f64_lt = 0x63,
    WasmOp_f64_gt = 0x64,
    WasmOp_f64_le = 0x65,
    WasmOp_f64_ge = 0x66,
    WasmOp_i32_clz = 0x67,
    WasmOp_i32_ctz = 0x68,
    WasmOp_i32_popcnt = 0x69,
    WasmOp_i32_add = 0x6A,
    WasmOp_i32_sub = 0x6B,
    WasmOp_i32_mul = 0x6C,
    WasmOp_i32_div_s = 0x6D,
    WasmOp_i32_div_u = 0x6E,
    WasmOp_i32_rem_s = 0x6F,
    WasmOp_i32_rem_u = 0x70,
    WasmOp_i32_and = 0x71,
    WasmOp_i32_or = 0x72,
    WasmOp_i32_xor = 0x73,
    WasmOp_i32_shl = 0x74,
    WasmOp_i32_shr_s = 0x75,
    WasmOp_i32_shr_u = 0x76,
    WasmOp_i32_rotl = 0x77,
    WasmOp_i32_rotr = 0x78,
    WasmOp_i64_clz = 0x79,
    WasmOp_i64_ctz = 0x7A,
    WasmOp_i64_popcnt = 0x7B,
    WasmOp_i64_add = 0x7C,
    WasmOp_i64_sub = 0x7D,
    WasmOp_i64_mul = 0x7E,
    WasmOp_i64_div_s = 0x7F,
    WasmOp_i64_div_u = 0x80,
    WasmOp_i64_rem_s = 0x81,
    WasmOp_i64_rem_u = 0x82,
    WasmOp_i64_and = 0x83,
    WasmOp_i64_or = 0x84,
    WasmOp_i64_xor = 0x85,
    WasmOp_i64_shl = 0x86,
    WasmOp_i64_shr_s = 0x87,
    WasmOp_i64_shr_u = 0x88,
    WasmOp_i64_rotl = 0x89,
    WasmOp_i64_rotr = 0x8A,
    WasmOp_f32_abs = 0x8B,
    WasmOp_f32_neg = 0x8C,
    WasmOp_f32_ceil = 0x8D,
    WasmOp_f32_floor = 0x8E,
    WasmOp_f32_trunc = 0x8F,
    WasmOp_f32_nearest = 0x90,
    WasmOp_f32_sqrt = 0x91,
    WasmOp_f32_add = 0x92,
    WasmOp_f32_sub = 0x93,
    WasmOp_f32_mul = 0x94,
    WasmOp_f32_div = 0x95,
    WasmOp_f32_min = 0x96,
    WasmOp_f32_max = 0x97,
    WasmOp_f32_copysign = 0x98,
    WasmOp_f64_abs = 0x99,
    WasmOp_f64_neg = 0x9A,
    WasmOp_f64_ceil = 0x9B,
    WasmOp_f64_floor = 0x9C,
    WasmOp_f64_trunc = 0x9D,
    WasmOp_f64_nearest = 0x9E,
    WasmOp_f64_sqrt = 0x9F,
    WasmOp_f64_add = 0xA0,
    WasmOp_f64_sub = 0xA1,
    WasmOp_f64_mul = 0xA2,
    WasmOp_f64_div = 0xA3,
    WasmOp_f64_min = 0xA4,
    WasmOp_f64_max = 0xA5,
    WasmOp_f64_copysign = 0xA6,
    WasmOp_i32_wrap_i64 = 0xA7,
    WasmOp_i32_trunc_f32_s = 0xA8,
    WasmOp_i32_trunc_f32_u = 0xA9,
    WasmOp_i32_trunc_f64_s = 0xAA,
    WasmOp_i32_trunc_f64_u = 0xAB,
    WasmOp_i64_extend_i32_s = 0xAC,
    WasmOp_i64_extend_i32_u = 0xAD,
    WasmOp_i64_trunc_f32_s = 0xAE,
    WasmOp_i64_trunc_f32_u = 0xAF,
    WasmOp_i64_trunc_f64_s = 0xB0,
    WasmOp_i64_trunc_f64_u = 0xB1,
    WasmOp_f32_convert_i32_s = 0xB2,
    WasmOp_f32_convert_i32_u = 0xB3,
    WasmOp_f32_convert_i64_s = 0xB4,
    WasmOp_f32_convert_i64_u = 0xB5,
    WasmOp_f32_demote_f64 = 0xB6,
    WasmOp_f64_convert_i32_s = 0xB7,
    WasmOp_f64_convert_i32_u = 0xB8,
    WasmOp_f64_convert_i64_s = 0xB9,
    WasmOp_f64_convert_i64_u = 0xBA,
    WasmOp_f64_promote_f32 = 0xBB,
    WasmOp_i32_reinterpret_f32 = 0xBC,
    WasmOp_i64_reinterpret_f64 = 0xBD,
    WasmOp_f32_reinterpret_i32 = 0xBE,
    WasmOp_f64_reinterpret_i64 = 0xBF,
    WasmOp_i32_extend8_s = 0xC0,
    WasmOp_i32_extend16_s = 0xC1,
    WasmOp_i64_extend8_s = 0xC2,
    WasmOp_i64_extend16_s = 0xC3,
    WasmOp_i64_extend32_s = 0xC4,

    WasmOp_prefixed = 0xFC,
};

enum WasmPrefixedOp {
    WasmPrefixedOp_i32_trunc_sat_f32_s = 0x00,
    WasmPrefixedOp_i32_trunc_sat_f32_u = 0x01,
    WasmPrefixedOp_i32_trunc_sat_f64_s = 0x02,
    WasmPrefixedOp_i32_trunc_sat_f64_u = 0x03,
    WasmPrefixedOp_i64_trunc_sat_f32_s = 0x04,
    WasmPrefixedOp_i64_trunc_sat_f32_u = 0x05,
    WasmPrefixedOp_i64_trunc_sat_f64_s = 0x06,
    WasmPrefixedOp_i64_trunc_sat_f64_u = 0x07,
    WasmPrefixedOp_memory_init = 0x08,
    WasmPrefixedOp_data_drop = 0x09,
    WasmPrefixedOp_memory_copy = 0x0A,
    WasmPrefixedOp_memory_fill = 0x0B,
    WasmPrefixedOp_table_init = 0x0C,
    WasmPrefixedOp_elem_drop = 0x0D,
    WasmPrefixedOp_table_copy = 0x0E,
    WasmPrefixedOp_table_grow = 0x0F,
    WasmPrefixedOp_table_size = 0x10,
    WasmPrefixedOp_table_fill = 0x11,
};

static const uint32_t wasm_page_size = 64 * 1024;

struct ProgramCounter {
    uint32_t opcode;
    uint32_t operand;
};

struct TypeInfo {
    uint32_t param_count;
    // bitset with param_count bits, indexed from lsb, 0 -> 32-bit, 1 -> 64-bit
    uint32_t param_types;
    uint32_t result_count;
    // bitset with result_count bits, indexed from lsb, 0 -> 32-bit, 1 -> 64-bit
    uint32_t result_types;
};

struct Function {
    // Index to start of code in opcodes/operands.
    struct ProgramCounter entry_pc;
    uint32_t type_idx;
    uint32_t locals_count;
    // multi-word bitset with vm->types[type_idx].param_count + locals_count bits
    // indexed from lsb of the first element, 0 -> 32-bit, 1 -> 64-bit
    uint32_t *local_types;
};

enum ImpMod {
    ImpMod_wasi_snapshot_preview1,
};

enum ImpName {
    ImpName_args_get,
    ImpName_args_sizes_get,
    ImpName_clock_time_get,
    ImpName_debug,
    ImpName_debug_slice,
    ImpName_environ_get,
    ImpName_environ_sizes_get,
    ImpName_fd_close,
    ImpName_fd_fdstat_get,
    ImpName_fd_filestat_get,
    ImpName_fd_filestat_set_size,
    ImpName_fd_filestat_set_times,
    ImpName_fd_pread,
    ImpName_fd_prestat_dir_name,
    ImpName_fd_prestat_get,
    ImpName_fd_pwrite,
    ImpName_fd_read,
    ImpName_fd_readdir,
    ImpName_fd_write,
    ImpName_path_create_directory,
    ImpName_path_filestat_get,
    ImpName_path_open,
    ImpName_path_remove_directory,
    ImpName_path_rename,
    ImpName_path_unlink_file,
    ImpName_proc_exit,
    ImpName_random_get,
};

struct Import {
    enum ImpMod mod;
    enum ImpName name;
    uint32_t type_idx;
};

struct VirtualMachine {
    uint64_t *stack;
    /// Points to one after the last stack item.
    uint32_t stack_top;
    struct ProgramCounter pc;
    /// Actual memory usage of the WASI code. The capacity is max_memory.
    uint32_t memory_len;
    const char *mod_ptr;
    uint8_t *opcodes;
    uint32_t *operands;
    struct Function *functions;
    /// Type index to start of type in module_bytes.
    struct TypeInfo *types;
    uint64_t *globals;
    char *memory;
    struct Import *imports;
    uint32_t imports_len;
    const char **args;
    uint32_t *table;
};

static int to_host_fd(int32_t wasi_fd) {
    const struct Preopen *preopen = find_preopen(wasi_fd);
    if (!preopen) return wasi_fd;
    return preopen->host_fd;
}

static enum wasi_errno_t to_wasi_err(int err) {
    switch (err) {
        case E2BIG: return WASI_E2BIG;
        case EACCES: return WASI_EACCES;
        case EADDRINUSE: return WASI_EADDRINUSE;
        case EADDRNOTAVAIL: return WASI_EADDRNOTAVAIL;
        case EAFNOSUPPORT: return WASI_EAFNOSUPPORT;
        case EAGAIN: return WASI_EAGAIN;
        case EALREADY: return WASI_EALREADY;
        case EBADF: return WASI_EBADF;
        case EBADMSG: return WASI_EBADMSG;
        case EBUSY: return WASI_EBUSY;
        case ECANCELED: return WASI_ECANCELED;
        case ECHILD: return WASI_ECHILD;
        case ECONNABORTED: return WASI_ECONNABORTED;
        case ECONNREFUSED: return WASI_ECONNREFUSED;
        case ECONNRESET: return WASI_ECONNRESET;
        case EDEADLK: return WASI_EDEADLK;
        case EDESTADDRREQ: return WASI_EDESTADDRREQ;
        case EDOM: return WASI_EDOM;
        case EDQUOT: return WASI_EDQUOT;
        case EEXIST: return WASI_EEXIST;
        case EFAULT: return WASI_EFAULT;
        case EFBIG: return WASI_EFBIG;
        case EHOSTUNREACH: return WASI_EHOSTUNREACH;
        case EIDRM: return WASI_EIDRM;
        case EILSEQ: return WASI_EILSEQ;
        case EINPROGRESS: return WASI_EINPROGRESS;
        case EINTR: return WASI_EINTR;
        case EINVAL: return WASI_EINVAL;
        case EIO: return WASI_EIO;
        case EISCONN: return WASI_EISCONN;
        case EISDIR: return WASI_EISDIR;
        case ELOOP: return WASI_ELOOP;
        case EMFILE: return WASI_EMFILE;
        case EMLINK: return WASI_EMLINK;
        case EMSGSIZE: return WASI_EMSGSIZE;
        case EMULTIHOP: return WASI_EMULTIHOP;
        case ENAMETOOLONG: return WASI_ENAMETOOLONG;
        case ENETDOWN: return WASI_ENETDOWN;
        case ENETRESET: return WASI_ENETRESET;
        case ENETUNREACH: return WASI_ENETUNREACH;
        case ENFILE: return WASI_ENFILE;
        case ENOBUFS: return WASI_ENOBUFS;
        case ENODEV: return WASI_ENODEV;
        case ENOENT: return WASI_ENOENT;
        case ENOEXEC: return WASI_ENOEXEC;
        case ENOLCK: return WASI_ENOLCK;
        case ENOLINK: return WASI_ENOLINK;
        case ENOMEM: return WASI_ENOMEM;
        case ENOMSG: return WASI_ENOMSG;
        case ENOPROTOOPT: return WASI_ENOPROTOOPT;
        case ENOSPC: return WASI_ENOSPC;
        case ENOSYS: return WASI_ENOSYS;
        case ENOTCONN: return WASI_ENOTCONN;
        case ENOTDIR: return WASI_ENOTDIR;
        case ENOTEMPTY: return WASI_ENOTEMPTY;
        case ENOTRECOVERABLE: return WASI_ENOTRECOVERABLE;
        case ENOTSOCK: return WASI_ENOTSOCK;
        case EOPNOTSUPP: return WASI_EOPNOTSUPP;
        case ENOTTY: return WASI_ENOTTY;
        case ENXIO: return WASI_ENXIO;
        case EOVERFLOW: return WASI_EOVERFLOW;
        case EOWNERDEAD: return WASI_EOWNERDEAD;
        case EPERM: return WASI_EPERM;
        case EPIPE: return WASI_EPIPE;
        case EPROTO: return WASI_EPROTO;
        case EPROTONOSUPPORT: return WASI_EPROTONOSUPPORT;
        case EPROTOTYPE: return WASI_EPROTOTYPE;
        case ERANGE: return WASI_ERANGE;
        case EROFS: return WASI_EROFS;
        case ESPIPE: return WASI_ESPIPE;
        case ESRCH: return WASI_ESRCH;
        case ESTALE: return WASI_ESTALE;
        case ETIMEDOUT: return WASI_ETIMEDOUT;
        case ETXTBSY: return WASI_ETXTBSY;
        case EXDEV: return WASI_EXDEV;
        default:
        fprintf(stderr, "unexpected errno: %s\n", strerror(err));
        abort();
    };
}

enum wasi_filetype_t {
    wasi_filetype_t_UNKNOWN,
    wasi_filetype_t_BLOCK_DEVICE,
    wasi_filetype_t_CHARACTER_DEVICE,
    wasi_filetype_t_DIRECTORY,
    wasi_filetype_t_REGULAR_FILE,
    wasi_filetype_t_SOCKET_DGRAM,
    wasi_filetype_t_SOCKET_STREAM,
    wasi_filetype_t_SYMBOLIC_LINK,
};

static const uint16_t WASI_O_CREAT = 0x0001;
static const uint16_t WASI_O_DIRECTORY = 0x0002;
static const uint16_t WASI_O_EXCL = 0x0004;
static const uint16_t WASI_O_TRUNC = 0x0008;

static const uint16_t WASI_FDFLAG_APPEND = 0x0001;
static const uint16_t WASI_FDFLAG_DSYNC = 0x0002;
static const uint16_t WASI_FDFLAG_NONBLOCK = 0x0004;
static const uint16_t WASI_FDFLAG_SYNC = 0x0010;

static const uint64_t WASI_RIGHT_FD_READ = 0x0000000000000002ull;
static const uint64_t WASI_RIGHT_FD_WRITE = 0x0000000000000040ull;

static enum wasi_filetype_t to_wasi_filetype(mode_t st_mode) {
    switch (st_mode & S_IFMT) {
        case S_IFBLK:
            return wasi_filetype_t_BLOCK_DEVICE;
        case S_IFCHR:
            return wasi_filetype_t_CHARACTER_DEVICE;
        case S_IFDIR:
            return wasi_filetype_t_DIRECTORY;
        case S_IFLNK:
            return wasi_filetype_t_SYMBOLIC_LINK;
        case S_IFREG:
            return wasi_filetype_t_REGULAR_FILE;
        default:
            return wasi_filetype_t_UNKNOWN;
    }
}

static uint64_t to_wasi_timestamp(struct timespec ts) {
    return ts.tv_sec * 1000000000ull + ts.tv_nsec;
}

/// const filestat_t = extern struct {
///     dev: device_t, u64
///     ino: inode_t, u64
///     filetype: filetype_t, u8
///     nlink: linkcount_t, u64
///     size: filesize_t, u64
///     atim: timestamp_t, u64
///     mtim: timestamp_t, u64
///     ctim: timestamp_t, u64
/// };
static enum wasi_errno_t finish_wasi_stat(struct VirtualMachine *vm,
        uint32_t buf, struct stat st)
{
    write_u64_le(vm->memory + buf + 0x00, 0); // device
    write_u64_le(vm->memory + buf + 0x08, st.st_ino);
    write_u64_le(vm->memory + buf + 0x10, to_wasi_filetype(st.st_mode));
    write_u64_le(vm->memory + buf + 0x18, 1); // nlink
    write_u64_le(vm->memory + buf + 0x20, st.st_size);
#if defined(__APPLE__)
    write_u64_le(vm->memory + buf + 0x28, to_wasi_timestamp(st.st_atimespec));
    write_u64_le(vm->memory + buf + 0x30, to_wasi_timestamp(st.st_mtimespec));
    write_u64_le(vm->memory + buf + 0x38, to_wasi_timestamp(st.st_ctimespec));
#else
    write_u64_le(vm->memory + buf + 0x28, to_wasi_timestamp(st.st_atim));
    write_u64_le(vm->memory + buf + 0x30, to_wasi_timestamp(st.st_mtim));
    write_u64_le(vm->memory + buf + 0x38, to_wasi_timestamp(st.st_ctim));
#endif

    return WASI_ESUCCESS;
}

/// fn args_sizes_get(argc: *usize, argv_buf_size: *usize) errno_t;
static enum wasi_errno_t wasi_args_sizes_get(struct VirtualMachine *vm,
    uint32_t argc, uint32_t argv_buf_size)
{
    uint32_t args_len = 0;
    size_t buf_size = 0;
    while (vm->args[args_len]) {
        buf_size += strlen(vm->args[args_len]) + 1;
        args_len += 1;
    }
    write_u32_le(vm->memory + argc, args_len);
    write_u32_le(vm->memory + argv_buf_size, buf_size);
    return WASI_ESUCCESS;
}

/// extern fn args_get(argv: [*][*:0]u8, argv_buf: [*]u8) errno_t;
static enum wasi_errno_t wasi_args_get(struct VirtualMachine *vm,
    uint32_t argv, uint32_t argv_buf) 
{
    uint32_t argv_buf_i = 0;
    uint32_t arg_i = 0;
    for (;; arg_i += 1) {
        const char *arg = vm->args[arg_i];
        if (!arg) break;
        // Write the arg to the buffer.
        uint32_t argv_ptr = argv_buf + argv_buf_i;
        uint32_t arg_len = strlen(arg) + 1;
        memcpy(vm->memory + argv_buf + argv_buf_i, arg, arg_len);
        argv_buf_i += arg_len;

        write_u32_le(vm->memory + argv + 4 * arg_i , argv_ptr);
    }
    return WASI_ESUCCESS;
}

/// extern fn random_get(buf: [*]u8, buf_len: usize) errno_t;
static enum wasi_errno_t wasi_random_get(struct VirtualMachine *vm,
    uint32_t buf, uint32_t buf_len) 
{
#ifdef __linux__
    if (getrandom(vm->memory + buf, buf_len, 0) != buf_len) {
        panic("getrandom failed");
    }
#else
    for (uint32_t i = 0; i < buf_len; i += 1) {
        vm->memory[buf + i] = rand();
    }
#endif
    return WASI_ESUCCESS;
}

/// fn fd_prestat_get(fd: fd_t, buf: *prestat_t) errno_t;
/// const prestat_t = extern struct {
///     pr_type: u8,
///     u: usize,
/// };
static enum wasi_errno_t wasi_fd_prestat_get(struct VirtualMachine *vm,
    int32_t fd, uint32_t buf)
{
    const struct Preopen *preopen = find_preopen(fd);
    if (!preopen) return WASI_EBADF;
    write_u32_le(vm->memory + buf + 0, 0);
    write_u32_le(vm->memory + buf + 4, preopen->name_len);
    return WASI_ESUCCESS;
}

/// fn fd_prestat_dir_name(fd: fd_t, path: [*]u8, path_len: usize) errno_t;
static enum wasi_errno_t wasi_fd_prestat_dir_name(struct VirtualMachine *vm,
        int32_t fd, uint32_t path, uint32_t path_len)
{
    const struct Preopen *preopen = find_preopen(fd);
    if (!preopen) return WASI_EBADF;
    if (path_len != preopen->name_len)
        panic("wasi_fd_prestat_dir_name expects correct name_len");
    memcpy(vm->memory + path, preopen->name, path_len);
    return WASI_ESUCCESS;
}

/// extern fn fd_close(fd: fd_t) errno_t;
static enum wasi_errno_t wasi_fd_close(struct VirtualMachine *vm, int32_t fd) {
    int host_fd = to_host_fd(fd);
    close(host_fd);
    return WASI_ESUCCESS;
}

static enum wasi_errno_t wasi_fd_read(
    struct VirtualMachine *vm,
    int32_t fd,
    uint32_t iovs, // [*]const iovec_t
    uint32_t iovs_len, // usize
    uint32_t nread // *usize
) {
    int host_fd = to_host_fd(fd);
    uint32_t i = 0;
    size_t total_read = 0;
    for (; i < iovs_len; i += 1) {
        uint32_t ptr = read_u32_le(vm->memory + iovs + i * 8 + 0);
        uint32_t len = read_u32_le(vm->memory + iovs + i * 8 + 4);
        ssize_t amt_read = read(host_fd, vm->memory + ptr, len);
        if (amt_read < 0) return to_wasi_err(errno);
        total_read += amt_read;
        if (amt_read != len) break;
    }
    write_u32_le(vm->memory + nread, total_read);
    return WASI_ESUCCESS;
}

/// extern fn fd_write(fd: fd_t, iovs: [*]const ciovec_t, iovs_len: usize, nwritten: *usize) errno_t;
/// const ciovec_t = extern struct {
///     base: [*]const u8,
///     len: usize,
/// };
static enum wasi_errno_t wasi_fd_write(struct VirtualMachine *vm,
        int32_t fd, uint32_t iovs, uint32_t iovs_len, uint32_t nwritten)
{
    int host_fd = to_host_fd(fd);
    size_t total_written = 0;
    for (uint32_t i = 0; i < iovs_len; i += 1) {
        uint32_t ptr = read_u32_le(vm->memory + iovs + i * 8 + 0);
        uint32_t len = read_u32_le(vm->memory + iovs + i * 8 + 4);
        ssize_t written = write(host_fd, vm->memory + ptr, len);
        if (written < 0) return to_wasi_err(errno);
        total_written += written;
        if (written != len) break;
    }
    write_u32_le(vm->memory + nwritten, total_written);
    return WASI_ESUCCESS;
}

static enum wasi_errno_t wasi_fd_pwrite(
    struct VirtualMachine *vm,
    int32_t fd,
    uint32_t iovs, // [*]const ciovec_t
    uint32_t iovs_len, // usize
    uint64_t offset, // wasi.filesize_t,
    uint32_t written_ptr // *usize
) {
    int host_fd = to_host_fd(fd);
    uint32_t i = 0;
    size_t written = 0;
    for (; i < iovs_len; i += 1) {
        uint32_t ptr = read_u32_le(vm->memory + iovs + i * 8 + 0);
        uint32_t len = read_u32_le(vm->memory + iovs + i * 8 + 4);
        ssize_t w = pwrite(host_fd, vm->memory + ptr, len, offset + written);
        if (w < 0) return to_wasi_err(errno);
        written += w;
        if (w != len) break;
    }
    write_u32_le(vm->memory + written_ptr, written);
    return WASI_ESUCCESS;
}

///extern fn path_open(
///    dirfd: fd_t,
///    dirflags: lookupflags_t,
///    path: [*]const u8,
///    path_len: usize,
///    oflags: oflags_t,
///    fs_rights_base: rights_t,
///    fs_rights_inheriting: rights_t,
///    fs_flags: fdflags_t,
///    fd: *fd_t,
///) errno_t;
static enum wasi_errno_t wasi_path_open(
    struct VirtualMachine *vm,
    int32_t dirfd,
    uint32_t dirflags, // wasi.lookupflags_t,
    uint32_t path,
    uint32_t path_len,
    uint16_t oflags, // wasi.oflags_t,
    uint64_t fs_rights_base, // wasi.rights_t,
    uint64_t fs_rights_inheriting, // wasi.rights_t,
    uint16_t fs_flags, // wasi.fdflags_t,
    uint32_t fd
) {
    char sub_path[PATH_MAX];
    memcpy(sub_path, vm->memory + path, path_len);
    sub_path[path_len] = 0;

    int host_fd = to_host_fd(dirfd);
    uint32_t flags =
        (((oflags & WASI_O_CREAT) != 0) ? O_CREAT : 0) |
        (((oflags & WASI_O_DIRECTORY) != 0) ? O_DIRECTORY : 0) |
        (((oflags & WASI_O_EXCL) != 0) ? O_EXCL : 0) |
        (((oflags & WASI_O_TRUNC) != 0) ? O_TRUNC : 0) |
        (((fs_flags & WASI_FDFLAG_APPEND) != 0) ? O_APPEND : 0) |
        (((fs_flags & WASI_FDFLAG_DSYNC) != 0) ? O_DSYNC : 0) |
        (((fs_flags & WASI_FDFLAG_NONBLOCK) != 0) ? O_NONBLOCK : 0) |
        (((fs_flags & WASI_FDFLAG_SYNC) != 0) ? O_SYNC : 0);

    if (((fs_rights_base & WASI_RIGHT_FD_READ) != 0) &&
        ((fs_rights_base & WASI_RIGHT_FD_WRITE) != 0))
    {
        flags |= O_RDWR;
    } else if ((fs_rights_base & WASI_RIGHT_FD_WRITE) != 0) {
        flags |= O_WRONLY;
    } else if ((fs_rights_base & WASI_RIGHT_FD_READ) != 0) {
        flags |= O_RDONLY; // no-op because O_RDONLY is 0
    }
    mode_t mode = 0644;
    int res_fd = openat(host_fd, sub_path, flags, mode);
    if (res_fd == -1) return to_wasi_err(errno);
    write_u32_le(vm->memory + fd, res_fd);
    return WASI_ESUCCESS;
}

static enum wasi_errno_t wasi_path_filestat_get(
    struct VirtualMachine *vm,
    int32_t fd,
    uint32_t flags, // wasi.lookupflags_t,
    uint32_t path, // [*]const u8
    uint32_t path_len, // usize
    uint32_t buf // *filestat_t
) {
    char sub_path[PATH_MAX];
    memcpy(sub_path, vm->memory + path, path_len);
    sub_path[path_len] = 0;

    int host_fd = to_host_fd(fd);
    struct stat st;
    if (fstatat(host_fd, sub_path, &st, 0) == -1) return to_wasi_err(errno);
    return finish_wasi_stat(vm, buf, st);
}

/// extern fn path_create_directory(fd: fd_t, path: [*]const u8, path_len: usize) errno_t;
static enum wasi_errno_t wasi_path_create_directory(struct VirtualMachine *vm,
        int32_t wasi_fd, uint32_t path, uint32_t path_len)
{
    char sub_path[PATH_MAX];
    memcpy(sub_path, vm->memory + path, path_len);
    sub_path[path_len] = 0;

    int host_fd = to_host_fd(wasi_fd);
    if (mkdirat(host_fd, sub_path, 0777) == -1) return to_wasi_err(errno);
    return WASI_ESUCCESS;
}

static enum wasi_errno_t wasi_path_rename(
    struct VirtualMachine *vm,
    int32_t old_fd,
    uint32_t old_path_ptr, // [*]const u8
    uint32_t old_path_len, // usize
    int32_t new_fd,
    uint32_t new_path_ptr, // [*]const u8
    uint32_t new_path_len // usize
) {
    char old_path[PATH_MAX];
    memcpy(old_path, vm->memory + old_path_ptr, old_path_len);
    old_path[old_path_len] = 0;

    char new_path[PATH_MAX];
    memcpy(new_path, vm->memory + new_path_ptr, new_path_len);
    new_path[new_path_len] = 0;

    int old_host_fd = to_host_fd(old_fd);
    int new_host_fd = to_host_fd(new_fd);
    if (renameat(old_host_fd, old_path, new_host_fd, new_path) == -1) return to_wasi_err(errno);
    return WASI_ESUCCESS;
}

/// extern fn fd_filestat_get(fd: fd_t, buf: *filestat_t) errno_t;
static enum wasi_errno_t wasi_fd_filestat_get(struct VirtualMachine *vm, int32_t fd, uint32_t buf) {
    int host_fd = to_host_fd(fd);
    struct stat st;
    if (fstat(host_fd, &st) == -1) return to_wasi_err(errno);
    return finish_wasi_stat(vm, buf, st);
}

static enum wasi_errno_t wasi_fd_filestat_set_size( struct VirtualMachine *vm,
        int32_t fd, uint64_t size)
{
    int host_fd = to_host_fd(fd);
    if (ftruncate(host_fd, size) == -1) return to_wasi_err(errno);
    return WASI_ESUCCESS;
}

/// pub extern "wasi_snapshot_preview1" fn fd_fdstat_get(fd: fd_t, buf: *fdstat_t) errno_t;
/// pub const fdstat_t = extern struct {
///     fs_filetype: filetype_t, u8
///     fs_flags: fdflags_t, u16
///     fs_rights_base: rights_t, u64
///     fs_rights_inheriting: rights_t, u64
/// };
static enum wasi_errno_t wasi_fd_fdstat_get(struct VirtualMachine *vm, int32_t fd, uint32_t buf) {
    int host_fd = to_host_fd(fd);
    struct stat st;
    if (fstat(host_fd, &st) == -1) return to_wasi_err(errno);
    write_u16_le(vm->memory + buf + 0x00, to_wasi_filetype(st.st_mode));
    write_u16_le(vm->memory + buf + 0x02, 0); // flags
    write_u64_le(vm->memory + buf + 0x08, UINT64_MAX); // rights_base
    write_u64_le(vm->memory + buf + 0x10, UINT64_MAX); // rights_inheriting
    return WASI_ESUCCESS;
}

/// extern fn clock_time_get(clock_id: clockid_t, precision: timestamp_t, timestamp: *timestamp_t) errno_t;
static enum wasi_errno_t wasi_clock_time_get(struct VirtualMachine *vm,
        uint32_t clock_id, uint64_t precision, uint32_t timestamp)
{
    if (clock_id != 1) panic("expected wasi_clock_time_get to use CLOCK_MONOTONIC");
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == -1) return to_wasi_err(errno);
    uint64_t wasi_ts = to_wasi_timestamp(ts);
    write_u64_le(vm->memory + timestamp, wasi_ts);
    return WASI_ESUCCESS;
}

///pub extern "wasi_snapshot_preview1" fn debug(string: [*:0]const u8, x: u64) void;
void wasi_debug(struct VirtualMachine *vm, uint32_t text, uint64_t n) {
    fprintf(stderr, "wasi_debug: '%s' number=%" PRIu64" %" PRIx64 "\n", vm->memory + text, n, n);
}

/// pub extern "wasi_snapshot_preview1" fn debug_slice(ptr: [*]const u8, len: usize) void;
void wasi_debug_slice(struct VirtualMachine *vm, uint32_t ptr, uint32_t len) {
    fprintf(stderr, "wasi_debug_slice: '%.*s'\n", len, vm->memory + ptr);
}

struct Label {
    enum WasmOp opcode;
    uint32_t stack_depth;
    struct TypeInfo type_info;
    // this is a UINT32_MAX terminated linked list that is stored in the operands array
    uint32_t ref_list;
    union {
        struct ProgramCounter loop_pc;
        uint32_t else_ref;
    } extra;
};

static uint32_t Label_operandCount(const struct Label *label) {
    if (label->opcode == WasmOp_loop) {
        return label->type_info.param_count;
    } else {
        return label->type_info.result_count;
    }
}

static bool Label_operandType(const struct Label *label, uint32_t index) {
    if (label->opcode == WasmOp_loop) {
        return bs_isSet(&label->type_info.param_types, index);
    } else {
        return bs_isSet(&label->type_info.result_types, index);
    }
}

static void vm_decodeCode(struct VirtualMachine *vm, struct Function *func, uint32_t *code_i,
    struct ProgramCounter *pc)
{
    const char *mod_ptr = vm->mod_ptr;
    uint8_t *opcodes = vm->opcodes;
    uint32_t *operands = vm->operands;
    struct TypeInfo *func_type_info = &vm->types[func->type_idx];

    uint32_t unreachable_depth = 0;
    uint32_t stack_depth = func_type_info->param_count + func->locals_count + 2;
    static uint32_t stack_types[1 << (12 - 3)];

    static struct Label labels[1 << 9];
#ifndef NDEBUG
    memset(labels, 0xaa, sizeof(struct Label) * (1 << 9)); // to match the zig version
#endif
    uint32_t label_i = 0;
    labels[label_i].opcode = WasmOp_block;
    labels[label_i].stack_depth = stack_depth;
    labels[label_i].type_info = vm->types[func->type_idx];
    labels[label_i].ref_list = UINT32_MAX;

    for (;;) {
        enum WasmOp opcode = (uint8_t)mod_ptr[*code_i];
        *code_i += 1;
        enum WasmPrefixedOp prefixed_opcode;
        if (opcode == WasmOp_prefixed) prefixed_opcode = read32_uleb128(mod_ptr, code_i);

        //fprintf(stderr, "decodeCode opcode=0x%x pc=%u:%u\n", opcode, pc->opcode, pc->operand);
        //struct ProgramCounter old_pc = *pc;

        uint32_t initial_stack_depth = stack_depth;
        if (unreachable_depth == 0) {
            switch (opcode) {
                case WasmOp_unreachable:
                case WasmOp_nop:
                case WasmOp_block:
                case WasmOp_loop:
                case WasmOp_else:
                case WasmOp_end:
                case WasmOp_br:
                case WasmOp_call:
                case WasmOp_return:
                break;

                case WasmOp_if:
                case WasmOp_br_if:
                case WasmOp_br_table:
                case WasmOp_call_indirect:
                case WasmOp_drop:
                case WasmOp_local_set:
                case WasmOp_global_set:
                stack_depth -= 1;
                break;

                case WasmOp_select:
                stack_depth -= 2;
                break;

                case WasmOp_local_get:
                case WasmOp_global_get:
                case WasmOp_memory_size:
                case WasmOp_i32_const:
                case WasmOp_i64_const:
                case WasmOp_f32_const:
                case WasmOp_f64_const:
                stack_depth += 1;
                break;

                case WasmOp_local_tee:
                case WasmOp_i32_load:
                case WasmOp_i64_load:
                case WasmOp_f32_load:
                case WasmOp_f64_load:
                case WasmOp_i32_load8_s:
                case WasmOp_i32_load8_u:
                case WasmOp_i32_load16_s:
                case WasmOp_i32_load16_u:
                case WasmOp_i64_load8_s:
                case WasmOp_i64_load8_u:
                case WasmOp_i64_load16_s:
                case WasmOp_i64_load16_u:
                case WasmOp_i64_load32_s:
                case WasmOp_i64_load32_u:
                case WasmOp_memory_grow:
                case WasmOp_i32_eqz:
                case WasmOp_i32_clz:
                case WasmOp_i32_ctz:
                case WasmOp_i32_popcnt:
                case WasmOp_i64_eqz:
                case WasmOp_i64_clz:
                case WasmOp_i64_ctz:
                case WasmOp_i64_popcnt:
                case WasmOp_f32_abs:
                case WasmOp_f32_neg:
                case WasmOp_f32_ceil:
                case WasmOp_f32_floor:
                case WasmOp_f32_trunc:
                case WasmOp_f32_nearest:
                case WasmOp_f32_sqrt:
                case WasmOp_f64_abs:
                case WasmOp_f64_neg:
                case WasmOp_f64_ceil:
                case WasmOp_f64_floor:
                case WasmOp_f64_trunc:
                case WasmOp_f64_nearest:
                case WasmOp_f64_sqrt:
                case WasmOp_i32_wrap_i64:
                case WasmOp_i32_trunc_f32_s:
                case WasmOp_i32_trunc_f32_u:
                case WasmOp_i32_trunc_f64_s:
                case WasmOp_i32_trunc_f64_u:
                case WasmOp_i64_extend_i32_s:
                case WasmOp_i64_extend_i32_u:
                case WasmOp_i64_trunc_f32_s:
                case WasmOp_i64_trunc_f32_u:
                case WasmOp_i64_trunc_f64_s:
                case WasmOp_i64_trunc_f64_u:
                case WasmOp_f32_convert_i32_s:
                case WasmOp_f32_convert_i32_u:
                case WasmOp_f32_convert_i64_s:
                case WasmOp_f32_convert_i64_u:
                case WasmOp_f32_demote_f64:
                case WasmOp_f64_convert_i32_s:
                case WasmOp_f64_convert_i32_u:
                case WasmOp_f64_convert_i64_s:
                case WasmOp_f64_convert_i64_u:
                case WasmOp_f64_promote_f32:
                case WasmOp_i32_reinterpret_f32:
                case WasmOp_i64_reinterpret_f64:
                case WasmOp_f32_reinterpret_i32:
                case WasmOp_f64_reinterpret_i64:
                case WasmOp_i32_extend8_s:
                case WasmOp_i32_extend16_s:
                case WasmOp_i64_extend8_s:
                case WasmOp_i64_extend16_s:
                case WasmOp_i64_extend32_s:
                break;

                case WasmOp_i32_store:
                case WasmOp_i64_store:
                case WasmOp_f32_store:
                case WasmOp_f64_store:
                case WasmOp_i32_store8:
                case WasmOp_i32_store16:
                case WasmOp_i64_store8:
                case WasmOp_i64_store16:
                case WasmOp_i64_store32:
                stack_depth -= 2;
                break;

                case WasmOp_i32_eq:
                case WasmOp_i32_ne:
                case WasmOp_i32_lt_s:
                case WasmOp_i32_lt_u:
                case WasmOp_i32_gt_s:
                case WasmOp_i32_gt_u:
                case WasmOp_i32_le_s:
                case WasmOp_i32_le_u:
                case WasmOp_i32_ge_s:
                case WasmOp_i32_ge_u:
                case WasmOp_i64_eq:
                case WasmOp_i64_ne:
                case WasmOp_i64_lt_s:
                case WasmOp_i64_lt_u:
                case WasmOp_i64_gt_s:
                case WasmOp_i64_gt_u:
                case WasmOp_i64_le_s:
                case WasmOp_i64_le_u:
                case WasmOp_i64_ge_s:
                case WasmOp_i64_ge_u:
                case WasmOp_f32_eq:
                case WasmOp_f32_ne:
                case WasmOp_f32_lt:
                case WasmOp_f32_gt:
                case WasmOp_f32_le:
                case WasmOp_f32_ge:
                case WasmOp_f64_eq:
                case WasmOp_f64_ne:
                case WasmOp_f64_lt:
                case WasmOp_f64_gt:
                case WasmOp_f64_le:
                case WasmOp_f64_ge:
                case WasmOp_i32_add:
                case WasmOp_i32_sub:
                case WasmOp_i32_mul:
                case WasmOp_i32_div_s:
                case WasmOp_i32_div_u:
                case WasmOp_i32_rem_s:
                case WasmOp_i32_rem_u:
                case WasmOp_i32_and:
                case WasmOp_i32_or:
                case WasmOp_i32_xor:
                case WasmOp_i32_shl:
                case WasmOp_i32_shr_s:
                case WasmOp_i32_shr_u:
                case WasmOp_i32_rotl:
                case WasmOp_i32_rotr:
                case WasmOp_i64_add:
                case WasmOp_i64_sub:
                case WasmOp_i64_mul:
                case WasmOp_i64_div_s:
                case WasmOp_i64_div_u:
                case WasmOp_i64_rem_s:
                case WasmOp_i64_rem_u:
                case WasmOp_i64_and:
                case WasmOp_i64_or:
                case WasmOp_i64_xor:
                case WasmOp_i64_shl:
                case WasmOp_i64_shr_s:
                case WasmOp_i64_shr_u:
                case WasmOp_i64_rotl:
                case WasmOp_i64_rotr:
                case WasmOp_f32_add:
                case WasmOp_f32_sub:
                case WasmOp_f32_mul:
                case WasmOp_f32_div:
                case WasmOp_f32_min:
                case WasmOp_f32_max:
                case WasmOp_f32_copysign:
                case WasmOp_f64_add:
                case WasmOp_f64_sub:
                case WasmOp_f64_mul:
                case WasmOp_f64_div:
                case WasmOp_f64_min:
                case WasmOp_f64_max:
                case WasmOp_f64_copysign:
                stack_depth -= 1;
                break;

                case WasmOp_prefixed:
                switch (prefixed_opcode) {
                    case WasmPrefixedOp_i32_trunc_sat_f32_s:
                    case WasmPrefixedOp_i32_trunc_sat_f32_u:
                    case WasmPrefixedOp_i32_trunc_sat_f64_s:
                    case WasmPrefixedOp_i32_trunc_sat_f64_u:
                    case WasmPrefixedOp_i64_trunc_sat_f32_s:
                    case WasmPrefixedOp_i64_trunc_sat_f32_u:
                    case WasmPrefixedOp_i64_trunc_sat_f64_s:
                    case WasmPrefixedOp_i64_trunc_sat_f64_u:
                    break;

                    case WasmPrefixedOp_memory_init:
                    case WasmPrefixedOp_memory_copy:
                    case WasmPrefixedOp_memory_fill:
                    case WasmPrefixedOp_table_init:
                    case WasmPrefixedOp_table_copy:
                    case WasmPrefixedOp_table_fill:
                    stack_depth -= 3;
                    break;

                    case WasmPrefixedOp_data_drop:
                    case WasmPrefixedOp_elem_drop:
                    break;

                    case WasmPrefixedOp_table_grow:
                    stack_depth -= 1;
                    break;

                    case WasmPrefixedOp_table_size:
                    stack_depth += 1;
                    break;

                    default: panic("unexpected prefixed opcode");
                }
                break;

                default: panic("unexpected opcode");
            }
            switch (opcode) {
                case WasmOp_unreachable:
                case WasmOp_nop:
                case WasmOp_block:
                case WasmOp_loop:
                case WasmOp_else:
                case WasmOp_end:
                case WasmOp_br:
                case WasmOp_call:
                case WasmOp_return:
                case WasmOp_if:
                case WasmOp_br_if:
                case WasmOp_br_table:
                case WasmOp_call_indirect:
                case WasmOp_drop:
                case WasmOp_select:
                case WasmOp_local_set:
                case WasmOp_local_get:
                case WasmOp_local_tee:
                case WasmOp_global_set:
                case WasmOp_global_get:
                case WasmOp_i32_store:
                case WasmOp_i64_store:
                case WasmOp_f32_store:
                case WasmOp_f64_store:
                case WasmOp_i32_store8:
                case WasmOp_i32_store16:
                case WasmOp_i64_store8:
                case WasmOp_i64_store16:
                case WasmOp_i64_store32:
                break;

                case WasmOp_i32_const:
                case WasmOp_f32_const:
                case WasmOp_memory_size:
                case WasmOp_i32_load:
                case WasmOp_f32_load:
                case WasmOp_i32_load8_s:
                case WasmOp_i32_load8_u:
                case WasmOp_i32_load16_s:
                case WasmOp_i32_load16_u:
                case WasmOp_memory_grow:
                case WasmOp_i32_eqz:
                case WasmOp_i32_clz:
                case WasmOp_i32_ctz:
                case WasmOp_i32_popcnt:
                case WasmOp_i64_eqz:
                case WasmOp_f32_abs:
                case WasmOp_f32_neg:
                case WasmOp_f32_ceil:
                case WasmOp_f32_floor:
                case WasmOp_f32_trunc:
                case WasmOp_f32_nearest:
                case WasmOp_f32_sqrt:
                case WasmOp_i32_wrap_i64:
                case WasmOp_i32_trunc_f32_s:
                case WasmOp_i32_trunc_f32_u:
                case WasmOp_i32_trunc_f64_s:
                case WasmOp_i32_trunc_f64_u:
                case WasmOp_f32_convert_i32_s:
                case WasmOp_f32_convert_i32_u:
                case WasmOp_f32_convert_i64_s:
                case WasmOp_f32_convert_i64_u:
                case WasmOp_f32_demote_f64:
                case WasmOp_i32_reinterpret_f32:
                case WasmOp_f32_reinterpret_i32:
                case WasmOp_i32_extend8_s:
                case WasmOp_i32_extend16_s:
                case WasmOp_i32_eq:
                case WasmOp_i32_ne:
                case WasmOp_i32_lt_s:
                case WasmOp_i32_lt_u:
                case WasmOp_i32_gt_s:
                case WasmOp_i32_gt_u:
                case WasmOp_i32_le_s:
                case WasmOp_i32_le_u:
                case WasmOp_i32_ge_s:
                case WasmOp_i32_ge_u:
                case WasmOp_i64_eq:
                case WasmOp_i64_ne:
                case WasmOp_i64_lt_s:
                case WasmOp_i64_lt_u:
                case WasmOp_i64_gt_s:
                case WasmOp_i64_gt_u:
                case WasmOp_i64_le_s:
                case WasmOp_i64_le_u:
                case WasmOp_i64_ge_s:
                case WasmOp_i64_ge_u:
                case WasmOp_f32_eq:
                case WasmOp_f32_ne:
                case WasmOp_f32_lt:
                case WasmOp_f32_gt:
                case WasmOp_f32_le:
                case WasmOp_f32_ge:
                case WasmOp_f64_eq:
                case WasmOp_f64_ne:
                case WasmOp_f64_lt:
                case WasmOp_f64_gt:
                case WasmOp_f64_le:
                case WasmOp_f64_ge:
                case WasmOp_i32_add:
                case WasmOp_i32_sub:
                case WasmOp_i32_mul:
                case WasmOp_i32_div_s:
                case WasmOp_i32_div_u:
                case WasmOp_i32_rem_s:
                case WasmOp_i32_rem_u:
                case WasmOp_i32_and:
                case WasmOp_i32_or:
                case WasmOp_i32_xor:
                case WasmOp_i32_shl:
                case WasmOp_i32_shr_s:
                case WasmOp_i32_shr_u:
                case WasmOp_i32_rotl:
                case WasmOp_i32_rotr:
                case WasmOp_f32_add:
                case WasmOp_f32_sub:
                case WasmOp_f32_mul:
                case WasmOp_f32_div:
                case WasmOp_f32_min:
                case WasmOp_f32_max:
                case WasmOp_f32_copysign:
                bs_unset(stack_types, stack_depth - 1);
                break;

                case WasmOp_i64_const:
                case WasmOp_f64_const:
                case WasmOp_i64_load:
                case WasmOp_f64_load:
                case WasmOp_i64_load8_s:
                case WasmOp_i64_load8_u:
                case WasmOp_i64_load16_s:
                case WasmOp_i64_load16_u:
                case WasmOp_i64_load32_s:
                case WasmOp_i64_load32_u:
                case WasmOp_i64_clz:
                case WasmOp_i64_ctz:
                case WasmOp_i64_popcnt:
                case WasmOp_f64_abs:
                case WasmOp_f64_neg:
                case WasmOp_f64_ceil:
                case WasmOp_f64_floor:
                case WasmOp_f64_trunc:
                case WasmOp_f64_nearest:
                case WasmOp_f64_sqrt:
                case WasmOp_i64_extend_i32_s:
                case WasmOp_i64_extend_i32_u:
                case WasmOp_i64_trunc_f32_s:
                case WasmOp_i64_trunc_f32_u:
                case WasmOp_i64_trunc_f64_s:
                case WasmOp_i64_trunc_f64_u:
                case WasmOp_f64_convert_i32_s:
                case WasmOp_f64_convert_i32_u:
                case WasmOp_f64_convert_i64_s:
                case WasmOp_f64_convert_i64_u:
                case WasmOp_f64_promote_f32:
                case WasmOp_i64_reinterpret_f64:
                case WasmOp_f64_reinterpret_i64:
                case WasmOp_i64_extend8_s:
                case WasmOp_i64_extend16_s:
                case WasmOp_i64_extend32_s:
                case WasmOp_i64_add:
                case WasmOp_i64_sub:
                case WasmOp_i64_mul:
                case WasmOp_i64_div_s:
                case WasmOp_i64_div_u:
                case WasmOp_i64_rem_s:
                case WasmOp_i64_rem_u:
                case WasmOp_i64_and:
                case WasmOp_i64_or:
                case WasmOp_i64_xor:
                case WasmOp_i64_shl:
                case WasmOp_i64_shr_s:
                case WasmOp_i64_shr_u:
                case WasmOp_i64_rotl:
                case WasmOp_i64_rotr:
                case WasmOp_f64_add:
                case WasmOp_f64_sub:
                case WasmOp_f64_mul:
                case WasmOp_f64_div:
                case WasmOp_f64_min:
                case WasmOp_f64_max:
                case WasmOp_f64_copysign:
                bs_set(stack_types, stack_depth - 1);
                break;

                case WasmOp_prefixed:
                switch (prefixed_opcode) {
                    case WasmPrefixedOp_memory_init:
                    case WasmPrefixedOp_memory_copy:
                    case WasmPrefixedOp_memory_fill:
                    case WasmPrefixedOp_table_init:
                    case WasmPrefixedOp_table_copy:
                    case WasmPrefixedOp_table_fill:
                    case WasmPrefixedOp_data_drop:
                    case WasmPrefixedOp_elem_drop:
                    break;

                    case WasmPrefixedOp_i32_trunc_sat_f32_s:
                    case WasmPrefixedOp_i32_trunc_sat_f32_u:
                    case WasmPrefixedOp_i32_trunc_sat_f64_s:
                    case WasmPrefixedOp_i32_trunc_sat_f64_u:
                    case WasmPrefixedOp_table_grow:
                    case WasmPrefixedOp_table_size:
                    bs_unset(stack_types, stack_depth - 1);
                    break;

                    case WasmPrefixedOp_i64_trunc_sat_f32_s:
                    case WasmPrefixedOp_i64_trunc_sat_f32_u:
                    case WasmPrefixedOp_i64_trunc_sat_f64_s:
                    case WasmPrefixedOp_i64_trunc_sat_f64_u:
                    bs_set(stack_types, stack_depth - 1);
                    break;

                    default: panic("unexpected prefixed opcode");
                }
                break;

                default: panic("unexpected opcode");
            }
        }

        switch (opcode) {
            case WasmOp_unreachable:
            if (unreachable_depth == 0) {
                opcodes[pc->opcode] = Op_unreachable;
                pc->opcode += 1;
            }
            break;

            case WasmOp_nop:
            case WasmOp_i32_reinterpret_f32:
            case WasmOp_i64_reinterpret_f64:
            case WasmOp_f32_reinterpret_i32:
            case WasmOp_f64_reinterpret_i64:
            break;

            case WasmOp_block:
            case WasmOp_loop:
            case WasmOp_if:
            {
                int64_t block_type = read64_ileb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    label_i += 1;
                    struct Label *label = &labels[label_i];
                    label->opcode = opcode;
                    if (block_type < 0) {
                        label->type_info.param_count = 0;
                        label->type_info.param_types = 0;
                        label->type_info.result_count = block_type != -0x40;
                        switch (block_type) {
                            case -0x40:
                            case -1:
                            case -3:
                                label->type_info.result_types = 0;
                                break;
                            case -2:
                            case -4:
                                label->type_info.result_types = UINT32_MAX;
                                break;
                            default: panic("unexpected param type");
                        }
                    } else {
                        label->type_info = vm->types[block_type];
                    }
                    label->stack_depth = stack_depth - label->type_info.param_count;
                    label->ref_list = UINT32_MAX;
                    switch (opcode) {
                        case WasmOp_block:
                        break;

                        case WasmOp_loop:
                        label->extra.loop_pc = *pc;
                        break;

                        case WasmOp_if:
                        opcodes[pc->opcode] = Op_br_if_eqz_void;
                        pc->opcode += 1;
                        operands[pc->operand] = 0;
                        label->extra.else_ref = pc->operand + 1;
                        pc->operand += 3;
                        break;

                        default: panic("unexpected label opcode");
                    }
                }
            }
            break;

            case WasmOp_else:
            if (unreachable_depth <= 1) {
                struct Label *label = &labels[label_i];
                assert(label->opcode == WasmOp_if);
                label->opcode = WasmOp_else;
                if (unreachable_depth == 0) {
                    uint32_t operand_count = Label_operandCount(label);
                    switch (operand_count) {
                        case 0:
                        opcodes[pc->opcode] = Op_br_void;
                        break;

                        case 1:
                        //fprintf(stderr, "label_i=%u operand_type=%d\n",
                        //        label_i, Label_operandType(label, 0));
                        if (Label_operandType(label, 0)) {
                            opcodes[pc->opcode] = Op_br_64;
                        } else {
                            opcodes[pc->opcode] = Op_br_32;
                        }
                        break;

                        default: panic("unexpected operand count");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = stack_depth - operand_count - label->stack_depth;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;
                    assert(stack_depth - label->type_info.result_count == label->stack_depth);
                } else unreachable_depth = 0;
                operands[label->extra.else_ref + 0] = pc->opcode;
                operands[label->extra.else_ref + 1] = pc->operand;
                stack_depth = label->stack_depth + label->type_info.param_count;
            }
            break;

            case WasmOp_end:
            if (unreachable_depth <= 1) {
                unreachable_depth = 0;
                struct Label *label = &labels[label_i];
                struct ProgramCounter *target_pc = (label->opcode == WasmOp_loop) ? &label->extra.loop_pc : pc;
                if (label->opcode == WasmOp_if) {
                    operands[label->extra.else_ref + 0] = target_pc->opcode;
                    operands[label->extra.else_ref + 1] = target_pc->operand;
                }
                uint32_t ref = label->ref_list;
                while (ref != UINT32_MAX) {
                    uint32_t next_ref = operands[ref];
                    operands[ref + 0] = target_pc->opcode;
                    operands[ref + 1] = target_pc->operand;
                    ref = next_ref;
                }
                stack_depth = label->stack_depth + label->type_info.result_count;

                if (label_i == 0) {
                    uint32_t operand_count = Label_operandCount(&labels[0]);
                    switch (operand_count) {
                        case 0:
                        opcodes[pc->opcode] = Op_return_void;
                        break;

                        case 1:
                        switch ((int)Label_operandType(&labels[0], 0)) {
                            case false: opcodes[pc->opcode] = Op_return_32; break;
                            case  true: opcodes[pc->opcode] = Op_return_64; break;
                        }
                        break;

                        default: panic("unexpected operand count");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = 2 + operand_count;
                    stack_depth -= operand_count;
                    assert(stack_depth == labels[0].stack_depth);
                    operands[pc->operand + 1] = stack_depth;
                    pc->operand += 2;
                    return;
                }
                label_i -= 1;
            } else unreachable_depth -= 1;
            break;

            case WasmOp_br:
            case WasmOp_br_if:
            {
                uint32_t label_idx = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    struct Label *label = &labels[label_i - label_idx];
                    uint32_t operand_count = Label_operandCount(label);
                    switch (opcode) {
                        case WasmOp_br:
                        switch (operand_count) {
                            case 0:
                            opcodes[pc->opcode] = Op_br_void;
                            break;

                            case 1:
                            switch ((int)Label_operandType(label, 0)) {
                                case false: opcodes[pc->opcode] = Op_br_32; break;
                                case  true: opcodes[pc->opcode] = Op_br_64; break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        break;

                        case WasmOp_br_if:
                        switch (operand_count) {
                            case 0:
                            opcodes[pc->opcode] = Op_br_if_nez_void;
                            break;

                            case 1:
                            switch ((int)Label_operandType(label, 0)) {
                                case false: opcodes[pc->opcode] = Op_br_if_nez_32; break;
                                case  true: opcodes[pc->opcode] = Op_br_if_nez_64; break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        break;

                        default: panic("unreachable");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = stack_depth - operand_count - label->stack_depth;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;
                }
            }
            break;

            case WasmOp_br_table:
            {
                uint32_t labels_len = read32_uleb128(mod_ptr, code_i);
                for (uint32_t i = 0; i <= labels_len; i += 1) {
                    uint32_t label_idx = read32_uleb128(mod_ptr, code_i);
                    if (unreachable_depth != 0) continue;
                    struct Label *label = &labels[label_i - label_idx];
                    uint32_t operand_count = Label_operandCount(label);
                    if (i == 0) {
                        switch (operand_count) {
                            case 0:
                            opcodes[pc->opcode] = Op_br_table_void;
                            break;

                            case 1:
                            switch ((int)Label_operandType(label, 0)) {
                                case false: opcodes[pc->opcode] = Op_br_table_32; break;
                                case  true: opcodes[pc->opcode] = Op_br_table_64; break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        pc->opcode += 1;
                        operands[pc->operand] = labels_len;
                        pc->operand += 1;
                    }
                    operands[pc->operand + 0] = stack_depth - operand_count - label->stack_depth;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;
                }
            }
            break;

            case WasmOp_call:
            {
                uint32_t fn_id = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_call;
                    pc->opcode += 1;
                    operands[pc->operand] = fn_id;
                    pc->operand += 1;
                    uint32_t type_idx = (fn_id < vm->imports_len) ?
                        vm->imports[fn_id].type_idx :
                        vm->functions[fn_id - vm->imports_len].type_idx;
                    struct TypeInfo *type_info = &vm->types[type_idx];
                    stack_depth -= type_info->param_count;
                    for (uint32_t result_i = 0; result_i < type_info->result_count; result_i += 1)
                        bs_setValue(stack_types, stack_depth + result_i,
                                    bs_isSet(&type_info->result_types, result_i));
                    stack_depth += type_info->result_count;
                }
            }
            break;

            case WasmOp_call_indirect:
            {
                uint32_t type_idx = read32_uleb128(mod_ptr, code_i);
                if (read32_uleb128(mod_ptr, code_i) != 0) panic("unexpected table index");
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm;
                    opcodes[pc->opcode + 1] = opcode;
                    pc->opcode += 2;
                    struct TypeInfo *type_info = &vm->types[type_idx];
                    stack_depth -= type_info->param_count;
                    for (uint32_t result_i = 0; result_i < type_info->result_count; result_i += 1)
                        bs_setValue(stack_types, stack_depth + result_i,
                                    bs_isSet(&type_info->result_types, result_i));
                    stack_depth += type_info->result_count;
                }
            }
            break;

            case WasmOp_return:
            if (unreachable_depth <= 1) {
                uint32_t operand_count = Label_operandCount(&labels[0]);
                switch (operand_count) {
                    case 0:
                    opcodes[pc->opcode] = Op_return_void;
                    break;

                    case 1:
                    switch ((int)Label_operandType(&labels[0], 0)) {
                        case false: opcodes[pc->opcode] = Op_return_32; break;
                        case  true: opcodes[pc->opcode] = Op_return_64; break;
                    }
                    break;

                    default: panic("unexpected operand count");
                }
                pc->opcode += 1;
                operands[pc->operand + 0] = 2 + stack_depth - labels[0].stack_depth;
                stack_depth -= operand_count;
                operands[pc->operand + 1] = stack_depth;
                pc->operand += 2;
            }
            break;

            case WasmOp_select:
            case WasmOp_drop:
            if (unreachable_depth == 0) {
                switch ((int)bs_isSet(stack_types, stack_depth)) {
                    case false:
                    switch (opcode) {
                        case WasmOp_select:
                        opcodes[pc->opcode] = Op_select_32;
                        break;

                        case WasmOp_drop:
                        opcodes[pc->opcode] = Op_drop_32;
                        break;

                        default: panic("unexpected opcode");
                    }
                    break;

                    case true:
                    switch (opcode) {
                        case WasmOp_select:
                        opcodes[pc->opcode] = Op_select_64;
                        break;

                        case WasmOp_drop:
                        opcodes[pc->opcode] = Op_drop_64;
                        break;

                        default: panic("unexpected opcode");
                    }
                    break;
                }
                pc->opcode += 1;
            }
            break;

            case WasmOp_local_get:
            case WasmOp_local_set:
            case WasmOp_local_tee:
            {
                uint32_t local_idx = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    bool local_type = bs_isSet(func->local_types, local_idx);
                    switch ((int)local_type) {
                        case false:
                        switch (opcode) {
                            case WasmOp_local_get:
                            opcodes[pc->opcode] = Op_local_get_32;
                            break;

                            case WasmOp_local_set:
                            opcodes[pc->opcode] = Op_local_set_32;
                            break;

                            case WasmOp_local_tee:
                            opcodes[pc->opcode] = Op_local_tee_32;
                            break;

                            default: panic("unexpected opcode");
                        }
                        break;

                        case true:
                        switch (opcode) {
                            case WasmOp_local_get:
                            opcodes[pc->opcode] = Op_local_get_64;
                            break;

                            case WasmOp_local_set:
                            opcodes[pc->opcode] = Op_local_set_64;
                            break;

                            case WasmOp_local_tee:
                            opcodes[pc->opcode] = Op_local_tee_64;
                            break;

                            default: panic("unexpected opcode");
                        }
                        break;
                    }
                    pc->opcode += 1;
                    operands[pc->operand] = initial_stack_depth - local_idx;
                    pc->operand += 1;
                    if (opcode == WasmOp_local_get) bs_setValue(stack_types, stack_depth - 1, local_type);
                }
            }
            break;

            case WasmOp_global_get:
            case WasmOp_global_set:
            {
                uint32_t global_idx = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    switch (global_idx) {
                        case 0:
                        switch (opcode) {
                            case WasmOp_global_get:
                            opcodes[pc->opcode] = Op_global_get_0_32;
                            break;

                            case WasmOp_global_set:
                            opcodes[pc->opcode] = Op_global_set_0_32;
                            break;

                            default: panic("unexpected opcode");
                        }
                        break;

                        default:
                        switch (opcode) {
                            case WasmOp_global_get:
                            opcodes[pc->opcode] = Op_global_get_32;
                            break;

                            case WasmOp_global_set:
                            opcodes[pc->opcode] = Op_global_set_32;
                            break;

                            default: panic("unexpected opcode");
                        }
                        break;
                    }
                    pc->opcode += 1;
                    if (global_idx != 0) {
                        operands[pc->operand] = global_idx;
                        pc->operand += 1;
                    }
                }
            }
            break;

            case WasmOp_i32_load:
            case WasmOp_i64_load:
            case WasmOp_f32_load:
            case WasmOp_f64_load:
            case WasmOp_i32_load8_s:
            case WasmOp_i32_load8_u:
            case WasmOp_i32_load16_s:
            case WasmOp_i32_load16_u:
            case WasmOp_i64_load8_s:
            case WasmOp_i64_load8_u:
            case WasmOp_i64_load16_s:
            case WasmOp_i64_load16_u:
            case WasmOp_i64_load32_s:
            case WasmOp_i64_load32_u:
            case WasmOp_i32_store:
            case WasmOp_i64_store:
            case WasmOp_f32_store:
            case WasmOp_f64_store:
            case WasmOp_i32_store8:
            case WasmOp_i32_store16:
            case WasmOp_i64_store8:
            case WasmOp_i64_store16:
            case WasmOp_i64_store32:
            {
                uint32_t alignment = read32_uleb128(mod_ptr, code_i);
                uint32_t offset = read32_uleb128(mod_ptr, code_i);
                (void)alignment;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm;
                    opcodes[pc->opcode + 1] = opcode;
                    pc->opcode += 2;
                    operands[pc->operand] = offset;
                    pc->operand += 1;
                }
            }
            break;

            case WasmOp_memory_size:
            case WasmOp_memory_grow:
            {
                if (mod_ptr[*code_i] != 0) panic("unexpected memory index");
                *code_i += 1;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm;
                    opcodes[pc->opcode + 1] = opcode;
                    pc->opcode += 2;
                }
            }
            break;

            case WasmOp_i32_const:
            {
                uint32_t x = read32_ileb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_const_32;
                    pc->opcode += 1;
                    operands[pc->operand] = x;
                    pc->operand += 1;
                }
            }
            break;

            case WasmOp_i64_const:
            {
                uint64_t x = read64_ileb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_const_64;
                    pc->opcode += 1;
                    operands[pc->operand + 0] = x & UINT32_MAX;
                    operands[pc->operand + 1] = (x >> 32) & UINT32_MAX;
                    pc->operand += 2;
                }
            }
            break;

            case WasmOp_f32_const:
            {
                uint32_t x;
                memcpy(&x, mod_ptr + *code_i, 4);
                *code_i += 4;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_const_32;
                    pc->opcode += 1;
                    operands[pc->operand] = x;
                    pc->operand += 1;
                }
            }
            break;

            case WasmOp_f64_const:
            {
                uint64_t x;
                memcpy(&x, mod_ptr + *code_i, 8);
                *code_i += 8;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_const_64;
                    pc->opcode += 1;
                    operands[pc->operand + 0] = x & UINT32_MAX;
                    operands[pc->operand + 1] = (x >> 32) & UINT32_MAX;
                    pc->operand += 2;
                }
            }
            break;

            case WasmOp_i32_add:
            opcodes[pc->opcode] = Op_add_32;
            pc->opcode += 1;
            break;

            case WasmOp_i32_and:
            opcodes[pc->opcode] = Op_and_32;
            pc->opcode += 1;
            break;

            default:
            if (unreachable_depth == 0) {
                opcodes[pc->opcode + 0] = Op_wasm;
                opcodes[pc->opcode + 1] = opcode;
                pc->opcode += 2;
            }
            break;

            case WasmOp_prefixed:
            switch (prefixed_opcode) {
                case WasmPrefixedOp_i32_trunc_sat_f32_s:
                case WasmPrefixedOp_i32_trunc_sat_f32_u:
                case WasmPrefixedOp_i32_trunc_sat_f64_s:
                case WasmPrefixedOp_i32_trunc_sat_f64_u:
                case WasmPrefixedOp_i64_trunc_sat_f32_s:
                case WasmPrefixedOp_i64_trunc_sat_f32_u:
                case WasmPrefixedOp_i64_trunc_sat_f64_s:
                case WasmPrefixedOp_i64_trunc_sat_f64_u:
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm_prefixed;
                    opcodes[pc->opcode + 1] = prefixed_opcode;
                    pc->opcode += 2;
                }
                break;

                case WasmPrefixedOp_memory_copy:
                if (mod_ptr[*code_i + 0] != 0 || mod_ptr[*code_i + 1] != 0)
                    panic("unexpected memory index");
                *code_i += 2;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm_prefixed;
                    opcodes[pc->opcode + 1] = prefixed_opcode;
                    pc->opcode += 2;
                }
                break;

                case WasmPrefixedOp_memory_fill:
                if (mod_ptr[*code_i] != 0) panic("unexpected memory index");
                *code_i += 1;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode + 0] = Op_wasm_prefixed;
                    opcodes[pc->opcode + 1] = prefixed_opcode;
                    pc->opcode += 2;
                }
                break;

                default: panic("unreachable");
            }
            break;
        }

        switch (opcode) {
            case WasmOp_unreachable:
            case WasmOp_return:
            case WasmOp_br:
            case WasmOp_br_table:
            if (unreachable_depth == 0) unreachable_depth = 1;
            break;

            default:
            break;
        }

        //for (uint32_t i = old_pc.opcode; i < pc->opcode; i += 1) {
        //    fprintf(stderr, "decoded opcode[%u] = %u\n", i, opcodes[i]);
        //}
        //for (uint32_t i = old_pc.operand; i < pc->operand; i += 1) {
        //    fprintf(stderr, "decoded operand[%u] = %u\n", i, operands[i]);
        //}
    }
}

static void vm_push_u32(struct VirtualMachine *vm, uint32_t value) {
    vm->stack[vm->stack_top] = value;
    vm->stack_top += 1;
}

static void vm_push_i32(struct VirtualMachine *vm, int32_t value) {
    return vm_push_u32(vm, value);
}

static void vm_push_u64(struct VirtualMachine *vm, uint64_t value) {
    vm->stack[vm->stack_top] = value;
    vm->stack_top += 1;
}

static void vm_push_i64(struct VirtualMachine *vm, int64_t value) {
    return vm_push_u64(vm, value);
}

static void vm_push_f32(struct VirtualMachine *vm, float value) {
    uint32_t integer;
    memcpy(&integer, &value, 4);
    return vm_push_u32(vm, integer);
}

static void vm_push_f64(struct VirtualMachine *vm, double value) {
    uint64_t integer;
    memcpy(&integer, &value, 8);
    return vm_push_u64(vm, integer);
}

static uint32_t vm_pop_u32(struct VirtualMachine *vm) {
    vm->stack_top -= 1;
    return vm->stack[vm->stack_top];
}

static int32_t vm_pop_i32(struct VirtualMachine *vm) {
    return vm_pop_u32(vm);
}

static uint64_t vm_pop_u64(struct VirtualMachine *vm) {
    vm->stack_top -= 1;
    return vm->stack[vm->stack_top];
}

static int64_t vm_pop_i64(struct VirtualMachine *vm) {
    return vm_pop_u64(vm);
}

static float vm_pop_f32(struct VirtualMachine *vm) {
    uint32_t integer = vm_pop_u32(vm);
    float result;
    memcpy(&result, &integer, 4);
    return result;
}

static double vm_pop_f64(struct VirtualMachine *vm) {
    uint64_t integer = vm_pop_u64(vm);
    double result;
    memcpy(&result, &integer, 8);
    return result;
}

static void vm_callImport(struct VirtualMachine *vm, struct Import import) {
    switch (import.mod) {
        case ImpMod_wasi_snapshot_preview1: switch (import.name) {
            case ImpName_fd_prestat_get:
            {
                uint32_t buf = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_prestat_get(vm, fd, buf));
            }
            break;
            case ImpName_fd_prestat_dir_name:
            {
                uint32_t path_len = vm_pop_u32(vm);
                uint32_t path = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_prestat_dir_name(vm, fd, path, path_len));
            }
            break;
            case ImpName_fd_close:
            {
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_close(vm, fd));
            }
            break;
            case ImpName_fd_read:
            {
                uint32_t nread = vm_pop_u32(vm);
                uint32_t iovs_len = vm_pop_u32(vm);
                uint32_t iovs = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_read(vm, fd, iovs, iovs_len, nread));
            }
            break;
            case ImpName_fd_filestat_get:
            {
                uint32_t buf = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_filestat_get(vm, fd, buf));
            }
            break;
            case ImpName_fd_filestat_set_size:
            {
                uint64_t size = vm_pop_u64(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_filestat_set_size(vm, fd, size));
            }
            break;
            case ImpName_fd_filestat_set_times:
            {
                panic("unexpected call to fd_filestat_set_times");
            }
            break;
            case ImpName_fd_fdstat_get:
            {
                uint32_t buf = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_fdstat_get(vm, fd, buf));
            }
            break;
            case ImpName_fd_readdir:
            {
                panic("unexpected call to fd_readdir");
            }
            break;
            case ImpName_fd_write:
            {
                uint32_t nwritten = vm_pop_u32(vm);
                uint32_t iovs_len = vm_pop_u32(vm);
                uint32_t iovs = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_write(vm, fd, iovs, iovs_len, nwritten));
            }
            break;
            case ImpName_fd_pwrite:
            {
                uint32_t nwritten = vm_pop_u32(vm);
                uint64_t offset = vm_pop_u64(vm);
                uint32_t iovs_len = vm_pop_u32(vm);
                uint32_t iovs = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_fd_pwrite(vm, fd, iovs, iovs_len, offset, nwritten));
            }
            break;
            case ImpName_proc_exit:
            {
                uint32_t code = vm_pop_u32(vm);
                exit(code);
            }
            break;
            case ImpName_args_sizes_get:
            {
                uint32_t argv_buf_size = vm_pop_u32(vm);
                uint32_t argc = vm_pop_u32(vm);
                vm_push_u32(vm, wasi_args_sizes_get(vm, argc, argv_buf_size));
            }
            break;
            case ImpName_args_get:
            {
                uint32_t argv_buf = vm_pop_u32(vm);
                uint32_t argv = vm_pop_u32(vm);
                vm_push_u32(vm, wasi_args_get(vm, argv, argv_buf));
            }
            break;
            case ImpName_random_get:
            {
                uint32_t buf_len = vm_pop_u32(vm);
                uint32_t buf = vm_pop_u32(vm);
                vm_push_u32(vm, wasi_random_get(vm, buf, buf_len));
            }
            break;
            case ImpName_environ_sizes_get:
            {
                panic("unexpected call to environ_sizes_get");
            }
            break;
            case ImpName_environ_get:
            {
                panic("unexpected call to environ_get");
            }
            break;
            case ImpName_path_filestat_get:
            {
                uint32_t buf = vm_pop_u32(vm);
                uint32_t path_len = vm_pop_u32(vm);
                uint32_t path = vm_pop_u32(vm);
                uint32_t flags = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_path_filestat_get(vm, fd, flags, path, path_len, buf));
            }
            break;
            case ImpName_path_create_directory:
            {
                uint32_t path_len = vm_pop_u32(vm);
                uint32_t path = vm_pop_u32(vm);
                int32_t fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_path_create_directory(vm, fd, path, path_len));
            }
            break;
            case ImpName_path_rename:
            {
                uint32_t new_path_len = vm_pop_u32(vm);
                uint32_t new_path = vm_pop_u32(vm);
                int32_t new_fd = vm_pop_i32(vm);
                uint32_t old_path_len = vm_pop_u32(vm);
                uint32_t old_path = vm_pop_u32(vm);
                int32_t old_fd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_path_rename(
                    vm,
                    old_fd,
                    old_path,
                    old_path_len,
                    new_fd,
                    new_path,
                    new_path_len
                ));
            }
            break;
            case ImpName_path_open:
            {
                uint32_t fd = vm_pop_u32(vm);
                uint32_t fs_flags = vm_pop_u32(vm);
                uint64_t fs_rights_inheriting = vm_pop_u64(vm);
                uint64_t fs_rights_base = vm_pop_u64(vm);
                uint32_t oflags = vm_pop_u32(vm);
                uint32_t path_len = vm_pop_u32(vm);
                uint32_t path = vm_pop_u32(vm);
                uint32_t dirflags = vm_pop_u32(vm);
                int32_t dirfd = vm_pop_i32(vm);
                vm_push_u32(vm, wasi_path_open(
                    vm,
                    dirfd,
                    dirflags,
                    path,
                    path_len,
                    oflags,
                    fs_rights_base,
                    fs_rights_inheriting,
                    fs_flags,
                    fd
                ));
            }
            break;
            case ImpName_path_remove_directory:
            {
                panic("unexpected call to path_remove_directory");
            }
            break;
            case ImpName_path_unlink_file:
            {
                panic("unexpected call to path_unlink_file");
            }
            break;
            case ImpName_clock_time_get:
            {
                uint32_t timestamp = vm_pop_u32(vm);
                uint64_t precision = vm_pop_u64(vm);
                uint32_t clock_id = vm_pop_u32(vm);
                vm_push_u32(vm, wasi_clock_time_get(vm, clock_id, precision, timestamp));
            }
            break;
            case ImpName_fd_pread:
            {
                panic("unexpected call to fd_pread");
            }
            break;
            case ImpName_debug:
            {
                uint64_t number = vm_pop_u64(vm);
                uint32_t text = vm_pop_u32(vm);
                wasi_debug(vm, text, number);
            }
            break;
            case ImpName_debug_slice:
            {
                uint32_t len = vm_pop_u32(vm);
                uint32_t ptr = vm_pop_u32(vm);
                wasi_debug_slice(vm, ptr, len);
            }
            break;
        }
        break;
    }
}

static void vm_call(struct VirtualMachine *vm, uint32_t fn_id) {
    if (fn_id < vm->imports_len) {
        struct Import imp = vm->imports[fn_id];
        return vm_callImport(vm, imp);
    }
    uint32_t fn_idx = fn_id - vm->imports_len;
    struct Function *func = &vm->functions[fn_idx];

    //struct TypeInfo *type_info = &vm->types[func->type_idx];
    //fprintf(stderr, "enter fn_id: %u, param_count: %u, result_count: %u, locals_count: %u\n",
    //    fn_id, type_info->param_count, type_info->result_count, func->locals_count);

    // Push zeroed locals to stack
    memset(vm->stack + vm->stack_top, 0, func->locals_count * sizeof(uint64_t));
    vm->stack_top += func->locals_count;

    vm_push_u32(vm, vm->pc.opcode);
    vm_push_u32(vm, vm->pc.operand);

    vm->pc = func->entry_pc;
}

static void vm_br_void(struct VirtualMachine *vm) {
    uint32_t stack_adjust = vm->operands[vm->pc.operand];

    vm->stack_top -= stack_adjust;

    vm->pc.opcode = vm->operands[vm->pc.operand + 1];
    vm->pc.operand = vm->operands[vm->pc.operand + 2];
}

static void vm_br_u32(struct VirtualMachine *vm) {
    uint32_t stack_adjust = vm->operands[vm->pc.operand];

    uint32_t result = vm_pop_u32(vm);
    vm->stack_top -= stack_adjust;
    vm_push_u32(vm, result);

    vm->pc.opcode = vm->operands[vm->pc.operand + 1];
    vm->pc.operand = vm->operands[vm->pc.operand + 2];
}

static void vm_br_u64(struct VirtualMachine *vm) {
    uint32_t stack_adjust = vm->operands[vm->pc.operand];

    uint64_t result = vm_pop_u64(vm);
    vm->stack_top -= stack_adjust;
    vm_push_u64(vm, result);

    vm->pc.opcode = vm->operands[vm->pc.operand + 1];
    vm->pc.operand = vm->operands[vm->pc.operand + 2];
}

static void vm_return_void(struct VirtualMachine *vm) {
    uint32_t ret_pc_offset = vm->operands[vm->pc.operand + 0];
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 1];

    vm->pc.opcode = vm->stack[vm->stack_top - ret_pc_offset];
    vm->pc.operand = vm->stack[vm->stack_top - ret_pc_offset + 1];

    vm->stack_top -= stack_adjust;
}

static void vm_return_u32(struct VirtualMachine *vm) {
    uint32_t ret_pc_offset = vm->operands[vm->pc.operand + 0];
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 1];

    vm->pc.opcode = vm->stack[vm->stack_top - ret_pc_offset];
    vm->pc.operand = vm->stack[vm->stack_top - ret_pc_offset + 1];

    uint32_t result = vm_pop_u32(vm);
    vm->stack_top -= stack_adjust;
    vm_push_u32(vm, result);
}

static void vm_return_u64(struct VirtualMachine *vm) {
    uint32_t ret_pc_offset = vm->operands[vm->pc.operand + 0];
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 1];

    vm->pc.opcode = vm->stack[vm->stack_top - ret_pc_offset];
    vm->pc.operand = vm->stack[vm->stack_top - ret_pc_offset + 1];

    uint64_t result = vm_pop_u64(vm);
    vm->stack_top -= stack_adjust;
    vm_push_u64(vm, result);
}

static void vm_run(struct VirtualMachine *vm) {
    uint8_t *opcodes = vm->opcodes;
    uint32_t *operands = vm->operands;
    struct ProgramCounter *pc = &vm->pc;
    for (;;) {
        enum Op op = opcodes[pc->opcode];
        pc->opcode += 1;
        //if (vm->stack_top > 0) {
        //    fprintf(stderr, "stack[%u]=%lx pc=%u:%u, op=%u\n", 
        //        vm->stack_top - 1, vm->stack[vm->stack_top - 1], pc->opcode, pc->operand, op);
        //}
        switch (op) {
            case Op_unreachable:
                panic("unreachable reached");

            case Op_br_void:
                vm_br_void(vm);
                break;

            case Op_br_32:
                vm_br_u32(vm);
                break;

            case Op_br_64:
                vm_br_u64(vm);
                break;

            case Op_br_if_nez_void:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_void(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_if_nez_32:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_u32(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_if_nez_64:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_u64(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_if_eqz_void:
                if (vm_pop_u32(vm) == 0) {
                    vm_br_void(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_if_eqz_32:
                if (vm_pop_u32(vm) == 0) {
                    vm_br_u32(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_if_eqz_64:
                if (vm_pop_u32(vm) == 0) {
                    vm_br_u64(vm);
                } else {
                    pc->operand += 3;
                }
                break;

            case Op_br_table_void:
                {
                    uint32_t index = min_u32(vm_pop_u32(vm), operands[pc->operand]);
                    pc->operand += 1 + index * 3;
                    vm_br_void(vm);
                }
                break;

            case Op_br_table_32:
                {
                    uint32_t index = min_u32(vm_pop_u32(vm), operands[pc->operand]);
                    pc->operand += 1 + index * 3;
                    vm_br_u32(vm);
                }
                break;

            case Op_br_table_64:
                {
                    uint32_t index = min_u32(vm_pop_u32(vm), operands[pc->operand]);
                    pc->operand += 1 + index * 3;
                    vm_br_u64(vm);
                }
                break;

            case Op_return_void:
                vm_return_void(vm);
                break;

            case Op_return_32:
                vm_return_u32(vm);
                break;

            case Op_return_64:
                vm_return_u64(vm);
                break;

            case Op_call:
                {
                    uint32_t fn_id = operands[pc->operand];
                    pc->operand += 1;
                    vm_call(vm, fn_id);
                }
                break;

            case Op_drop_32:
            case Op_drop_64:
                vm->stack_top -= 1;
                break;

            case Op_select_32:
                {
                    uint32_t c = vm_pop_u32(vm);
                    uint32_t b = vm_pop_u32(vm);
                    uint32_t a = vm_pop_u32(vm);
                    uint32_t result = (c != 0) ? a : b;
                    vm_push_u32(vm, result);
                }
                break;

            case Op_select_64:
                {
                    uint32_t c = vm_pop_u32(vm);
                    uint64_t b = vm_pop_u64(vm);
                    uint64_t a = vm_pop_u64(vm);
                    uint64_t result = (c != 0) ? a : b;
                    vm_push_u64(vm, result);
                }
                break;

            case Op_local_get_32:
                {
                    uint64_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    vm_push_u32(vm, *local);
                }
                break;

            case Op_local_get_64:
                {
                    uint64_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    vm_push_u64(vm, *local);
                }
                break;

            case Op_local_set_32:
                {
                    uint64_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    *local = vm_pop_u32(vm);
                }
                break;

            case Op_local_set_64:
                {
                    uint64_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    *local = vm_pop_u64(vm);
                }
                break;

            case Op_local_tee_32:
            case Op_local_tee_64:
                {
                    uint64_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    *local = vm->stack[vm->stack_top - 1];
                }
                break;

            case Op_global_get_0_32:
                vm_push_u32(vm, vm->globals[0]);
                break;

            case Op_global_get_32:
                {
                    uint32_t idx = operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u32(vm, vm->globals[idx]);
                }
                break;

            case Op_global_set_0_32:
                vm->globals[0] = vm_pop_u32(vm);
                break;

            case Op_global_set_32:
                {
                    uint32_t idx = operands[pc->operand];
                    pc->operand += 1;
                    vm->globals[idx] = vm_pop_u32(vm);
                }
                break;

            case Op_const_32:
                {
                    uint32_t x = operands[pc->operand];
                    pc->operand += 1;
                    vm_push_i32(vm, x);
                }
                break;

            case Op_const_64:
                {
                    uint64_t x = ((uint64_t)operands[pc->operand]) |
                        (((uint64_t)operands[pc->operand + 1]) << 32);
                    pc->operand += 2;
                    vm_push_i64(vm, x);
                }
                break;

            case Op_add_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs + rhs);
                }
                break;

            case Op_and_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs & rhs);
                }
                break;

            case Op_wasm:
                {
                    enum WasmOp wasm_op = opcodes[pc->opcode];
                    //fprintf(stderr, "op2=%x\n", wasm_op);
                    pc->opcode += 1;
                    switch (wasm_op) {
                        case WasmOp_unreachable:
                        case WasmOp_nop:
                        case WasmOp_block:
                        case WasmOp_loop:
                        case WasmOp_if:
                        case WasmOp_else:
                        case WasmOp_end:
                        case WasmOp_br:
                        case WasmOp_br_if:
                        case WasmOp_br_table:
                        case WasmOp_return:
                        case WasmOp_call:
                        case WasmOp_drop:
                        case WasmOp_select:
                        case WasmOp_local_get:
                        case WasmOp_local_set:
                        case WasmOp_local_tee:
                        case WasmOp_global_get:
                        case WasmOp_global_set:
                        case WasmOp_i32_const:
                        case WasmOp_i64_const:
                        case WasmOp_f32_const:
                        case WasmOp_f64_const:
                        case WasmOp_i32_add:
                        case WasmOp_i32_and:
                        case WasmOp_i32_reinterpret_f32:
                        case WasmOp_i64_reinterpret_f64:
                        case WasmOp_f32_reinterpret_i32:
                        case WasmOp_f64_reinterpret_i64:
                        case WasmOp_prefixed:
                            panic("not produced by decodeCode");
                            break;

                        case WasmOp_call_indirect:
                            {
                                uint32_t fn_id = vm->table[vm_pop_u32(vm)];
                                vm_call(vm, fn_id);
                            }
                            break;
                        case WasmOp_i32_load:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_u32(vm, read_u32_le(vm->memory + offset));
                            }
                            break;
                        case WasmOp_i64_load:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_u64(vm, read_u64_le(vm->memory + offset));
                            }
                            break;
                        case WasmOp_f32_load:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                uint32_t integer = read_u32_le(vm->memory + offset);
                                vm_push_u32(vm, integer);
                            }
                            break;
                        case WasmOp_f64_load:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                uint64_t integer = read_u64_le(vm->memory + offset);
                                vm_push_u64(vm, integer);
                            }
                            break;
                        case WasmOp_i32_load8_s:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_i32(vm, (int8_t)vm->memory[offset]);
                            }
                            break;
                        case WasmOp_i32_load8_u:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_u32(vm, (uint8_t)vm->memory[offset]);
                            }
                            break;
                        case WasmOp_i32_load16_s:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                int16_t integer = read_i16_le(vm->memory + offset);
                                vm_push_i32(vm, integer);
                            }
                            break;
                        case WasmOp_i32_load16_u:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                uint16_t integer = read_u16_le(vm->memory + offset);
                                vm_push_u32(vm, integer);
                            }
                            break;
                        case WasmOp_i64_load8_s:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_i64(vm, (int8_t)vm->memory[offset]);
                            }
                            break;
                        case WasmOp_i64_load8_u:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm_push_u64(vm, (uint8_t)vm->memory[offset]);
                            }
                            break;
                        case WasmOp_i64_load16_s:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                int16_t integer = read_i16_le(vm->memory + offset);
                                vm_push_i64(vm, integer);
                            }
                            break;
                        case WasmOp_i64_load16_u:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                uint16_t integer = read_u16_le(vm->memory + offset);
                                vm_push_u64(vm, integer);
                            }
                            break;
                        case WasmOp_i64_load32_s:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                int32_t integer = read_i32_le(vm->memory + offset);
                                vm_push_i64(vm, integer);
                            }
                            break;
                        case WasmOp_i64_load32_u:
                            {
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                uint32_t integer = read_u32_le(vm->memory + offset);
                                vm_push_u64(vm, integer);
                            }
                            break;
                        case WasmOp_i32_store:
                            {
                                uint32_t operand = vm_pop_u32(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u32_le(vm->memory + offset, operand);
                            }
                            break;
                        case WasmOp_i64_store:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u64_le(vm->memory + offset, operand);
                            }
                            break;
                        case WasmOp_f32_store:
                            {
                                uint32_t integer = vm_pop_u32(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u32_le(vm->memory + offset, integer);
                            }
                            break;
                        case WasmOp_f64_store:
                            {
                                uint64_t integer = vm_pop_u64(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u64_le(vm->memory + offset, integer);
                            }
                            break;
                        case WasmOp_i32_store8:
                            {
                                uint8_t small = vm_pop_u32(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm->memory[offset] = small;
                            }
                            break;
                        case WasmOp_i32_store16:
                            {
                                uint16_t small = vm_pop_u32(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u16_le(vm->memory + offset, small);
                            }
                            break;
                        case WasmOp_i64_store8:
                            {
                                uint8_t operand = vm_pop_u64(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                vm->memory[offset] = operand;
                            }
                            break;
                        case WasmOp_i64_store16:
                            {
                                uint16_t small = vm_pop_u64(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u16_le(vm->memory + offset, small);
                            }
                            break;
                        case WasmOp_i64_store32:
                            {
                                uint32_t small = vm_pop_u64(vm);
                                uint32_t offset = operands[pc->operand] + vm_pop_u32(vm);
                                pc->operand += 1;
                                write_u32_le(vm->memory + offset, small);
                            }
                            break;
                        case WasmOp_memory_size:
                            {
                                uint32_t page_count = vm->memory_len / wasm_page_size;
                                vm_push_u32(vm, page_count);
                            }
                            break;
                        case WasmOp_memory_grow:
                            {
                                uint32_t page_count = vm_pop_u32(vm);
                                uint32_t old_page_count = vm->memory_len / wasm_page_size;
                                uint32_t new_len = vm->memory_len + page_count * wasm_page_size;
                                if (new_len > max_memory) {
                                    vm_push_i32(vm, -1);
                                } else {
                                    vm->memory_len = new_len;
                                    vm_push_u32(vm, old_page_count);
                                }
                            }
                            break;
                        case WasmOp_i32_eqz:
                            {
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs == 0);
                            }
                            break;
                        case WasmOp_i32_eq:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs == rhs);
                            }
                            break;
                        case WasmOp_i32_ne:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs != rhs);
                            }
                            break;
                        case WasmOp_i32_lt_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_u32(vm, lhs < rhs);
                            }
                            break;
                        case WasmOp_i32_lt_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs < rhs);
                            }
                            break;
                        case WasmOp_i32_gt_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_i32_gt_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_i32_le_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_i32_le_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_i32_ge_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;
                        case WasmOp_i32_ge_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;
                        case WasmOp_i64_eqz:
                            {
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs == 0);
                            }
                            break;
                        case WasmOp_i64_eq:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs == rhs);
                            }
                            break;
                        case WasmOp_i64_ne:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs != rhs);
                            }
                            break;
                        case WasmOp_i64_lt_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_u32(vm, lhs < rhs);
                            }
                            break;
                        case WasmOp_i64_lt_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs < rhs);
                            }
                            break;
                        case WasmOp_i64_gt_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_i64_gt_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_i64_le_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_i64_le_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_i64_ge_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;
                        case WasmOp_i64_ge_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;
                        case WasmOp_f32_eq:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs == rhs);
                            }
                            break;
                        case WasmOp_f32_ne:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs != rhs);
                            }
                            break;
                        case WasmOp_f32_lt:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs < rhs);
                            }
                            break;
                        case WasmOp_f32_gt:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_f32_le:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_f32_ge:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;
                        case WasmOp_f64_eq:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs == rhs);
                            }
                            break;
                        case WasmOp_f64_ne:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs != rhs);
                            }
                            break;
                        case WasmOp_f64_lt:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_f64_gt:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs > rhs);
                            }
                            break;
                        case WasmOp_f64_le:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs <= rhs);
                            }
                            break;
                        case WasmOp_f64_ge:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_u32(vm, lhs >= rhs);
                            }
                            break;

                        case WasmOp_i32_clz:
                            {
                                uint32_t operand = vm_pop_u32(vm);
                                uint32_t result = (operand == 0) ? 32 : __builtin_clz(operand);
                                vm_push_u32(vm, result);
                            }
                            break;
                        case WasmOp_i32_ctz:
                            {
                                uint32_t operand = vm_pop_u32(vm);
                                uint32_t result = (operand == 0) ? 32 : __builtin_ctz(operand);
                                vm_push_u32(vm, result);
                            }
                            break;
                        case WasmOp_i32_popcnt:
                            {
                                uint32_t operand = vm_pop_u32(vm);
                                uint32_t result = __builtin_popcount(operand);
                                vm_push_u32(vm, result);
                            }
                            break;
                        case WasmOp_i32_sub:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs - rhs);
                            }
                            break;
                        case WasmOp_i32_mul:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs * rhs);
                            }
                            break;
                        case WasmOp_i32_div_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_i32(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_i32_div_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_i32_rem_s:
                            {
                                int32_t rhs = vm_pop_i32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_i32(vm, lhs % rhs);
                            }
                            break;
                        case WasmOp_i32_rem_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs % rhs);
                            }
                            break;
                        case WasmOp_i32_or:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs | rhs);
                            }
                            break;
                        case WasmOp_i32_xor:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs ^ rhs);
                            }
                            break;
                        case WasmOp_i32_shl:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs << (rhs & 0x1f));
                            }
                            break;
                        case WasmOp_i32_shr_s:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                int32_t lhs = vm_pop_i32(vm);
                                vm_push_i32(vm, lhs >> (rhs & 0x1f));
                            }
                            break;
                        case WasmOp_i32_shr_u:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, lhs >> (rhs & 0x1f));
                            }
                            break;
                        case WasmOp_i32_rotl:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, rotl32(lhs, rhs));
                            }
                            break;
                        case WasmOp_i32_rotr:
                            {
                                uint32_t rhs = vm_pop_u32(vm);
                                uint32_t lhs = vm_pop_u32(vm);
                                vm_push_u32(vm, rotr32(lhs, rhs ));
                            }
                            break;

                        case WasmOp_i64_clz:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                uint64_t result = (operand == 0) ? 64 : __builtin_clzll(operand);
                                vm_push_u64(vm, result);
                            }
                            break;
                        case WasmOp_i64_ctz:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                uint64_t result = (operand == 0) ? 64 : __builtin_ctzll(operand);
                                vm_push_u64(vm, result);
                            }
                            break;
                        case WasmOp_i64_popcnt:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                uint64_t result = __builtin_popcountll(operand);
                                vm_push_u64(vm, result);
                            }
                            break;
                        case WasmOp_i64_add:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs + rhs);
                            }
                            break;
                        case WasmOp_i64_sub:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs - rhs);
                            }
                            break;
                        case WasmOp_i64_mul:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs * rhs);
                            }
                            break;
                        case WasmOp_i64_div_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_i64(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_i64_div_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_i64_rem_s:
                            {
                                int64_t rhs = vm_pop_i64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_i64(vm, lhs % rhs);
                            }
                            break;
                        case WasmOp_i64_rem_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs % rhs);
                            }
                            break;
                        case WasmOp_i64_and:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs & rhs);
                            }
                            break;
                        case WasmOp_i64_or:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs | rhs);
                            }
                            break;
                        case WasmOp_i64_xor:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs ^ rhs);
                            }
                            break;
                        case WasmOp_i64_shl:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs << (rhs & 0x3f));
                            }
                            break;
                        case WasmOp_i64_shr_s:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                int64_t lhs = vm_pop_i64(vm);
                                vm_push_i64(vm, lhs >> (rhs & 0x3f));
                            }
                            break;
                        case WasmOp_i64_shr_u:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, lhs >> (rhs & 0x3f));
                            }
                            break;
                        case WasmOp_i64_rotl:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, rotl64(lhs, rhs));
                            }
                            break;
                        case WasmOp_i64_rotr:
                            {
                                uint64_t rhs = vm_pop_u64(vm);
                                uint64_t lhs = vm_pop_u64(vm);
                                vm_push_u64(vm, rotr64(lhs, rhs));
                            }
                            break;

                        case WasmOp_f32_abs:
                            {
                                vm_push_f32(vm, fabsf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_neg:
                            {
                                vm_push_f32(vm, -vm_pop_f32(vm));
                            }
                            break;
                        case WasmOp_f32_ceil:
                            {
                                vm_push_f32(vm, ceilf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_floor:
                            {
                                vm_push_f32(vm, floorf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_trunc:
                            {
                                vm_push_f32(vm, truncf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_nearest:
                            {
                                vm_push_f32(vm, roundf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_sqrt:
                            {
                                vm_push_f32(vm, sqrtf(vm_pop_f32(vm)));
                            }
                            break;
                        case WasmOp_f32_add:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, lhs + rhs);
                            }
                            break;
                        case WasmOp_f32_sub:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, lhs - rhs);
                            }
                            break;
                        case WasmOp_f32_mul:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, lhs * rhs);
                            }
                            break;
                        case WasmOp_f32_div:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_f32_min:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, (lhs < rhs) ? lhs : rhs);
                            }
                            break;
                        case WasmOp_f32_max:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, (lhs > rhs) ? lhs : rhs);
                            }
                            break;
                        case WasmOp_f32_copysign:
                            {
                                float rhs = vm_pop_f32(vm);
                                float lhs = vm_pop_f32(vm);
                                vm_push_f32(vm, copysignf(lhs, rhs));
                            }
                            break;
                        case WasmOp_f64_abs:
                            {
                                vm_push_f64(vm, fabs(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_neg:
                            {
                                vm_push_f64(vm, -vm_pop_f64(vm));
                            }
                            break;
                        case WasmOp_f64_ceil:
                            {
                                vm_push_f64(vm, ceil(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_floor:
                            {
                                vm_push_f64(vm, floor(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_trunc:
                            {
                                vm_push_f64(vm, trunc(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_nearest:
                            {
                                vm_push_f64(vm, round(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_sqrt:
                            {
                                vm_push_f64(vm, sqrt(vm_pop_f64(vm)));
                            }
                            break;
                        case WasmOp_f64_add:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, lhs + rhs);
                            }
                            break;
                        case WasmOp_f64_sub:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, lhs - rhs);
                            }
                            break;
                        case WasmOp_f64_mul:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, lhs * rhs);
                            }
                            break;
                        case WasmOp_f64_div:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, lhs / rhs);
                            }
                            break;
                        case WasmOp_f64_min:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, (lhs < rhs) ? lhs : rhs);
                            }
                            break;
                        case WasmOp_f64_max:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, (lhs > rhs) ? lhs : rhs);
                            }
                            break;
                        case WasmOp_f64_copysign:
                            {
                                double rhs = vm_pop_f64(vm);
                                double lhs = vm_pop_f64(vm);
                                vm_push_f64(vm, copysign(lhs, rhs));
                            }
                            break;

                        case WasmOp_i32_wrap_i64:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                vm_push_u32(vm, operand);
                            }
                            break;
                        case WasmOp_i32_trunc_f32_s:
                            {
                                float operand = vm_pop_f32(vm);
                                vm_push_i32(vm, truncf(operand));
                            }
                            break;
                        case WasmOp_i32_trunc_f32_u:
                            {
                                float operand = vm_pop_f32(vm);
                                vm_push_u32(vm, truncf(operand));
                            }
                            break;
                        case WasmOp_i32_trunc_f64_s:
                            {
                                double operand = vm_pop_f64(vm);
                                vm_push_i32(vm, trunc(operand));
                            }
                            break;
                        case WasmOp_i32_trunc_f64_u:
                            {
                                double operand = vm_pop_f64(vm);
                                vm_push_u32(vm, trunc(operand));
                            }
                            break;
                        case WasmOp_i64_extend_i32_s:
                            {
                                int32_t operand = vm_pop_i32(vm);
                                vm_push_i64(vm, operand);
                            }
                            break;
                        case WasmOp_i64_extend_i32_u:
                            {
                                uint64_t operand = vm_pop_u64(vm);
                                vm_push_u64(vm, operand);
                            }
                            break;
                        case WasmOp_i64_trunc_f32_s:
                            {
                                float operand = vm_pop_f32(vm);
                                vm_push_i64(vm, truncf(operand));
                            }
                            break;
                        case WasmOp_i64_trunc_f32_u:
                            {
                                float operand = vm_pop_f32(vm);
                                vm_push_u64(vm, truncf(operand));
                            }
                            break;
                        case WasmOp_i64_trunc_f64_s:
                            {
                                double operand = vm_pop_f64(vm);
                                vm_push_i64(vm, trunc(operand));
                            }
                            break;
                        case WasmOp_i64_trunc_f64_u:
                            {
                                double operand = vm_pop_f64(vm);
                                vm_push_u64(vm, trunc(operand));
                            }
                            break;
                        case WasmOp_f32_convert_i32_s:
                            {
                                vm_push_f32(vm, vm_pop_i32(vm));
                            }
                            break;
                        case WasmOp_f32_convert_i32_u:
                            {
                                vm_push_f32(vm, vm_pop_u32(vm));
                            }
                            break;
                        case WasmOp_f32_convert_i64_s:
                            {
                                vm_push_f32(vm, vm_pop_i64(vm));
                            }
                            break;
                        case WasmOp_f32_convert_i64_u:
                            {
                                vm_push_f32(vm, vm_pop_u64(vm));
                            }
                            break;
                        case WasmOp_f32_demote_f64:
                            {
                                vm_push_f32(vm, vm_pop_f64(vm));
                            }
                            break;
                        case WasmOp_f64_convert_i32_s:
                            {
                                vm_push_f64(vm, vm_pop_i32(vm));
                            }
                            break;
                        case WasmOp_f64_convert_i32_u:
                            {
                                vm_push_f64(vm, vm_pop_u32(vm));
                            }
                            break;
                        case WasmOp_f64_convert_i64_s:
                            {
                                vm_push_f64(vm, vm_pop_i64(vm));
                            }
                            break;
                        case WasmOp_f64_convert_i64_u:
                            {
                                vm_push_f64(vm, vm_pop_u64(vm));
                            }
                            break;
                        case WasmOp_f64_promote_f32:
                            {
                                vm_push_f64(vm, vm_pop_f32(vm));
                            }
                            break;

                        case WasmOp_i32_extend8_s:
                            {
                                int8_t operand = vm_pop_i32(vm);
                                vm_push_i32(vm, operand);
                            }
                            break;
                        case WasmOp_i32_extend16_s:
                            {
                                int16_t operand = vm_pop_i32(vm);
                                vm_push_i32(vm, operand);
                            }
                            break;
                        case WasmOp_i64_extend8_s:
                            {
                                int8_t operand = vm_pop_i64(vm);
                                vm_push_i64(vm, operand);
                            }
                            break;
                        case WasmOp_i64_extend16_s:
                            {
                                int16_t operand = vm_pop_i64(vm);
                                vm_push_i64(vm, operand);
                            }
                            break;
                        case WasmOp_i64_extend32_s:
                            {
                                int32_t operand = vm_pop_i64(vm);
                                vm_push_i64(vm, operand);
                            }
                            break;

                        default:
                            panic("unreachable");
                    }
                }
                break;

            case Op_wasm_prefixed:
                {
                    enum WasmPrefixedOp wasm_prefixed_op = opcodes[pc->opcode];
                    pc->opcode += 1;
                    switch (wasm_prefixed_op) {
                        case WasmPrefixedOp_i32_trunc_sat_f32_s:
                            panic("unreachable");
                        case WasmPrefixedOp_i32_trunc_sat_f32_u:
                            panic("unreachable");
                        case WasmPrefixedOp_i32_trunc_sat_f64_s:
                            panic("unreachable");
                        case WasmPrefixedOp_i32_trunc_sat_f64_u:
                            panic("unreachable");
                        case WasmPrefixedOp_i64_trunc_sat_f32_s:
                            panic("unreachable");
                        case WasmPrefixedOp_i64_trunc_sat_f32_u:
                            panic("unreachable");
                        case WasmPrefixedOp_i64_trunc_sat_f64_s:
                            panic("unreachable");
                        case WasmPrefixedOp_i64_trunc_sat_f64_u:
                            panic("unreachable");
                        case WasmPrefixedOp_memory_init:
                            panic("unreachable");
                        case WasmPrefixedOp_data_drop:
                            panic("unreachable");

                        case WasmPrefixedOp_memory_copy:
                            {
                                uint32_t n = vm_pop_u32(vm);
                                uint32_t src = vm_pop_u32(vm);
                                uint32_t dest = vm_pop_u32(vm);
                                assert(dest + n <= vm->memory_len);
                                assert(src + n <= vm->memory_len);
                                assert(src + n <= dest || dest + n <= src); // overlapping
                                memcpy(vm->memory + dest, vm->memory + src, n);
                            }
                            break;

                        case WasmPrefixedOp_memory_fill:
                            {
                                uint32_t n = vm_pop_u32(vm);
                                uint8_t value = vm_pop_u32(vm);
                                uint32_t dest = vm_pop_u32(vm);
                                assert(dest + n <= vm->memory_len);
                                memset(vm->memory + dest, value, n);
                            }
                            break;

                        case WasmPrefixedOp_table_init: panic("unreachable");
                        case WasmPrefixedOp_elem_drop: panic("unreachable");
                        case WasmPrefixedOp_table_copy: panic("unreachable");
                        case WasmPrefixedOp_table_grow: panic("unreachable");
                        case WasmPrefixedOp_table_size: panic("unreachable");
                        case WasmPrefixedOp_table_fill: panic("unreachable");
                        default: panic("unreachable");
                    }
                }
                break;

        }
    }
}

static size_t common_prefix(const char *a, const char *b) {
    size_t i = 0;
    for (; a[i] == b[i]; i += 1) {}
    return i;
}

int main(int argc, char **argv) {
    char *memory = mmap( NULL, max_memory, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);

    const char *zig_lib_dir_path = argv[1];
    const char *cmake_binary_dir_path = argv[2];
    const char *root_name = argv[3];
    size_t argv_i = 4;
    const char *wasm_file = argv[argv_i];

    size_t cwd_path_len = common_prefix(zig_lib_dir_path, cmake_binary_dir_path);
    const char *rel_cmake_bin_path = cmake_binary_dir_path + cwd_path_len;
    size_t rel_cmake_bin_path_len = strlen(rel_cmake_bin_path);

    const char *new_argv[30];
    char new_argv_buf[PATH_MAX + 1024];
    uint32_t new_argv_i = 0; 
    uint32_t new_argv_buf_i = 0;

    int cache_dir = -1;
    {
        char cache_dir_buf[PATH_MAX * 2];
        size_t i = 0;
        size_t cmake_binary_dir_path_len = strlen(cmake_binary_dir_path);

        memcpy(cache_dir_buf + i, cmake_binary_dir_path, cmake_binary_dir_path_len);
        i += cmake_binary_dir_path_len;

        cache_dir_buf[i] = '/';
        i += 1;

        memcpy(cache_dir_buf + i, "zig1-cache", strlen("zig1-cache"));
        i += strlen("zig1-cache");

        cache_dir_buf[i] = 0;

        mkdir(cache_dir_buf, 0777);
        cache_dir = err_wrap("opening cache dir",
                open(cache_dir_buf, O_DIRECTORY|O_RDONLY|O_CLOEXEC));
    }

    // Construct a new argv for the WASI code which has absolute paths
    // converted to relative paths, and has the target and terminal status
    // autodetected.

    // wasm file path
    new_argv[new_argv_i] = argv[argv_i];
    new_argv_i += 1;
    argv_i += 1;

    for(; argv[argv_i]; argv_i += 1) {
        new_argv[new_argv_i] = argv[argv_i];
        new_argv_i += 1;
    }

    {
        new_argv[new_argv_i] = "--name";
        new_argv_i += 1;

        new_argv[new_argv_i] = root_name;
        new_argv_i += 1;

        char *emit_bin_arg = new_argv_buf + new_argv_buf_i;
        memcpy(new_argv_buf + new_argv_buf_i, "-femit-bin=", strlen("-femit-bin="));
        new_argv_buf_i += strlen("-femit-bin=");
        memcpy(new_argv_buf + new_argv_buf_i, rel_cmake_bin_path, rel_cmake_bin_path_len);
        new_argv_buf_i += rel_cmake_bin_path_len;
        new_argv_buf[new_argv_buf_i] = '/';
        new_argv_buf_i += 1;
        memcpy(new_argv_buf + new_argv_buf_i, root_name, strlen(root_name));
        new_argv_buf_i += strlen(root_name);
        memcpy(new_argv_buf + new_argv_buf_i, ".c", 3);
        new_argv_buf_i += 3;

        new_argv[new_argv_i] = emit_bin_arg;
        new_argv_i += 1;
    }

    {
        new_argv[new_argv_i] = "--pkg-begin";
        new_argv_i += 1;

        new_argv[new_argv_i] = "build_options";
        new_argv_i += 1;

        char *build_options_path = new_argv_buf + new_argv_buf_i;
        memcpy(new_argv_buf + new_argv_buf_i, rel_cmake_bin_path, rel_cmake_bin_path_len);
        new_argv_buf_i += rel_cmake_bin_path_len;
        new_argv_buf[new_argv_buf_i] = '/';
        new_argv_buf_i += 1;
        memcpy(new_argv_buf + new_argv_buf_i, "config.zig", strlen("config.zig"));
        new_argv_buf_i += strlen("config.zig");
        new_argv_buf[new_argv_buf_i] = 0;
        new_argv_buf_i += 1;

        new_argv[new_argv_i] = build_options_path;
        new_argv_i += 1;

        new_argv[new_argv_i] = "--pkg-end";
        new_argv_i += 1;
    }

    {
        new_argv[new_argv_i] = "-target";
        new_argv_i += 1;

        new_argv[new_argv_i] = ZIG_TRIPLE_ARCH "-" ZIG_TRIPLE_OS;
        new_argv_i += 1;
    }

    if (isatty(STDERR_FILENO) != 0) {
        new_argv[new_argv_i] = "--color";
        new_argv_i += 1;

        new_argv[new_argv_i] = "on";
        new_argv_i += 1;
    }

    new_argv[new_argv_i] = NULL;

    const struct ByteSlice compressed_bytes = read_file_alloc(wasm_file);

    const size_t max_uncompressed_size = 2500000;
    char *mod_ptr = arena_alloc(max_uncompressed_size);
    size_t mod_len = ZSTD_decompress(mod_ptr, max_uncompressed_size,
            compressed_bytes.ptr, compressed_bytes.len);

    int cwd = err_wrap("opening cwd", open(".", O_DIRECTORY|O_RDONLY|O_CLOEXEC));
    int zig_lib_dir = err_wrap("opening zig lib dir", open(zig_lib_dir_path, O_DIRECTORY|O_RDONLY|O_CLOEXEC));

    add_preopen(0, "stdin", STDIN_FILENO);
    add_preopen(1, "stdout", STDOUT_FILENO);
    add_preopen(2, "stderr", STDERR_FILENO);
    add_preopen(3, ".", cwd);
    add_preopen(4, "/cache", cache_dir);
    add_preopen(5, "/lib", zig_lib_dir);

    uint32_t i = 0;

    if (mod_ptr[0] != 0 || mod_ptr[1] != 'a' || mod_ptr[2] != 's' || mod_ptr[3] != 'm') {
        panic("bad magic");
    }
    i += 4;

    uint32_t version = read_u32_le(mod_ptr + i);
    i += 4;
    if (version != 1) panic("bad wasm version");

    uint32_t section_starts[13];
    memset(&section_starts, 0, sizeof(uint32_t) * 13);

    while (i < mod_len) {
        uint8_t section_id = mod_ptr[i];
        i += 1;
        uint32_t section_len = read32_uleb128(mod_ptr, &i);
        section_starts[section_id] = i;
        i += section_len;
    }

    // Map type indexes to offsets into the module.
    struct TypeInfo *types;
    {
        i = section_starts[Section_type];
        uint32_t types_len = read32_uleb128(mod_ptr, &i);
        types = arena_alloc(sizeof(struct TypeInfo) * types_len);
        for (size_t type_i = 0; type_i < types_len; type_i += 1) {
            struct TypeInfo *info = &types[type_i];
            if (mod_ptr[i] != 0x60) panic("bad type byte");
            i += 1;

            info->param_count = read32_uleb128(mod_ptr, &i);
            if (info->param_count > 32) panic("found a type with over 32 parameters");
            info->param_types = 0;
            for (uint32_t param_i = 0; param_i < info->param_count; param_i += 1) {
                int64_t param_type = read64_ileb128(mod_ptr, &i);
                switch (param_type) {
                    case -1: case -3: bs_unset(&info->param_types, param_i); break;
                    case -2: case -4:   bs_set(&info->param_types, param_i); break;
                    default: panic("unexpected param type");
                }
            }

            info->result_count = read32_uleb128(mod_ptr, &i);
            info->result_types = 0;
            for (uint32_t result_i = 0; result_i < info->result_count; result_i += 1) {
                int64_t result_type = read64_ileb128(mod_ptr, &i);
                switch (result_type) {
                    case -1: case -3: bs_unset(&info->result_types, result_i); break;
                    case -2: case -4:   bs_set(&info->result_types, result_i); break;
                    default: panic("unexpected result type");
                }
            }
        }
    }

    // Count the imported functions so we can correct function references.
    struct Import *imports;
    uint32_t imports_len;
    {
        i = section_starts[Section_import];
        imports_len = read32_uleb128(mod_ptr, &i);
        imports = arena_alloc(sizeof(struct Import) * imports_len);
        for (size_t imp_i = 0; imp_i < imports_len; imp_i += 1) {
            struct Import *imp = &imports[imp_i];

            struct ByteSlice mod_name = read_name(mod_ptr, &i);
            if (mod_name.len == strlen("wasi_snapshot_preview1") &&
                memcmp(mod_name.ptr, "wasi_snapshot_preview1", mod_name.len) == 0) {
                imp->mod = ImpMod_wasi_snapshot_preview1;
            } else panic("unknown import module");

            struct ByteSlice sym_name = read_name(mod_ptr, &i);
            if (sym_name.len == strlen("args_get") &&
                memcmp(sym_name.ptr, "args_get", sym_name.len) == 0) {
                imp->name = ImpName_args_get;
            } else if (sym_name.len == strlen("args_sizes_get") &&
                memcmp(sym_name.ptr, "args_sizes_get", sym_name.len) == 0) {
                imp->name = ImpName_args_sizes_get;
            } else if (sym_name.len == strlen("clock_time_get") &&
                memcmp(sym_name.ptr, "clock_time_get", sym_name.len) == 0) {
                imp->name = ImpName_clock_time_get;
            } else if (sym_name.len == strlen("debug") &&
                memcmp(sym_name.ptr, "debug", sym_name.len) == 0) {
                imp->name = ImpName_debug;
            } else if (sym_name.len == strlen("debug_slice") &&
                memcmp(sym_name.ptr, "debug_slice", sym_name.len) == 0) {
                imp->name = ImpName_debug_slice;
            } else if (sym_name.len == strlen("environ_get") &&
                memcmp(sym_name.ptr, "environ_get", sym_name.len) == 0) {
                imp->name = ImpName_environ_get;
            } else if (sym_name.len == strlen("environ_sizes_get") &&
                memcmp(sym_name.ptr, "environ_sizes_get", sym_name.len) == 0) {
                imp->name = ImpName_environ_sizes_get;
            } else if (sym_name.len == strlen("fd_close") &&
                memcmp(sym_name.ptr, "fd_close", sym_name.len) == 0) {
                imp->name = ImpName_fd_close;
            } else if (sym_name.len == strlen("fd_fdstat_get") &&
                memcmp(sym_name.ptr, "fd_fdstat_get", sym_name.len) == 0) {
                imp->name = ImpName_fd_fdstat_get;
            } else if (sym_name.len == strlen("fd_filestat_get") &&
                memcmp(sym_name.ptr, "fd_filestat_get", sym_name.len) == 0) {
                imp->name = ImpName_fd_filestat_get;
            } else if (sym_name.len == strlen("fd_filestat_set_size") &&
                memcmp(sym_name.ptr, "fd_filestat_set_size", sym_name.len) == 0) {
                imp->name = ImpName_fd_filestat_set_size;
            } else if (sym_name.len == strlen("fd_filestat_set_times") &&
                memcmp(sym_name.ptr, "fd_filestat_set_times", sym_name.len) == 0) {
                imp->name = ImpName_fd_filestat_set_times;
            } else if (sym_name.len == strlen("fd_pread") &&
                memcmp(sym_name.ptr, "fd_pread", sym_name.len) == 0) {
                imp->name = ImpName_fd_pread;
            } else if (sym_name.len == strlen("fd_prestat_dir_name") &&
                memcmp(sym_name.ptr, "fd_prestat_dir_name", sym_name.len) == 0) {
                imp->name = ImpName_fd_prestat_dir_name;
            } else if (sym_name.len == strlen("fd_prestat_get") &&
                memcmp(sym_name.ptr, "fd_prestat_get", sym_name.len) == 0) {
                imp->name = ImpName_fd_prestat_get;
            } else if (sym_name.len == strlen("fd_pwrite") &&
                memcmp(sym_name.ptr, "fd_pwrite", sym_name.len) == 0) {
                imp->name = ImpName_fd_pwrite;
            } else if (sym_name.len == strlen("fd_read") &&
                memcmp(sym_name.ptr, "fd_read", sym_name.len) == 0) {
                imp->name = ImpName_fd_read;
            } else if (sym_name.len == strlen("fd_readdir") &&
                memcmp(sym_name.ptr, "fd_readdir", sym_name.len) == 0) {
                imp->name = ImpName_fd_readdir;
            } else if (sym_name.len == strlen("fd_write") &&
                memcmp(sym_name.ptr, "fd_write", sym_name.len) == 0) {
                imp->name = ImpName_fd_write;
            } else if (sym_name.len == strlen("path_create_directory") &&
                memcmp(sym_name.ptr, "path_create_directory", sym_name.len) == 0) {
                imp->name = ImpName_path_create_directory;
            } else if (sym_name.len == strlen("path_filestat_get") &&
                memcmp(sym_name.ptr, "path_filestat_get", sym_name.len) == 0) {
                imp->name = ImpName_path_filestat_get;
            } else if (sym_name.len == strlen("path_open") &&
                memcmp(sym_name.ptr, "path_open", sym_name.len) == 0) {
                imp->name = ImpName_path_open;
            } else if (sym_name.len == strlen("path_remove_directory") &&
                memcmp(sym_name.ptr, "path_remove_directory", sym_name.len) == 0) {
                imp->name = ImpName_path_remove_directory;
            } else if (sym_name.len == strlen("path_rename") &&
                memcmp(sym_name.ptr, "path_rename", sym_name.len) == 0) {
                imp->name = ImpName_path_rename;
            } else if (sym_name.len == strlen("path_unlink_file") &&
                memcmp(sym_name.ptr, "path_unlink_file", sym_name.len) == 0) {
                imp->name = ImpName_path_unlink_file;
            } else if (sym_name.len == strlen("proc_exit") &&
                memcmp(sym_name.ptr, "proc_exit", sym_name.len) == 0) {
                imp->name = ImpName_proc_exit;
            } else if (sym_name.len == strlen("random_get") &&
                memcmp(sym_name.ptr, "random_get", sym_name.len) == 0) {
                imp->name = ImpName_random_get;
            } else panic("unknown import name");

            uint32_t desc = read32_uleb128(mod_ptr, &i);
            if (desc != 0) panic("external kind not function");
            imp->type_idx = read32_uleb128(mod_ptr, &i);
        }
    }

    // Find _start in the exports
    uint32_t start_fn_idx;
    {
        i = section_starts[Section_export];
        uint32_t count = read32_uleb128(mod_ptr, &i);
        for (; count > 0; count -= 1) {
            struct ByteSlice name = read_name(mod_ptr, &i);
            uint32_t desc = read32_uleb128(mod_ptr, &i);
            start_fn_idx = read32_uleb128(mod_ptr, &i);
            if (desc == 0 && name.len == strlen("_start") &&
                memcmp(name.ptr, "_start", name.len) == 0)
            {
                break;
            }
        }
        if (count == 0) panic("_start symbol not found");
    }

    // Map function indexes to offsets into the module and type index.
    struct Function *functions;
    uint32_t functions_len;
    {
        i = section_starts[Section_function];
        functions_len = read32_uleb128(mod_ptr, &i);
        functions = arena_alloc(sizeof(struct Function) * functions_len);
        for (size_t func_i = 0; func_i < functions_len; func_i += 1) {
            struct Function *func = &functions[func_i];
            func->type_idx = read32_uleb128(mod_ptr, &i);
        }
    }

    // Allocate and initialize globals.
    uint64_t *globals;
    {
        i = section_starts[Section_global];
        uint32_t globals_len = read32_uleb128(mod_ptr, &i);
        globals = arena_alloc(sizeof(uint64_t) * globals_len);
        for (size_t glob_i = 0; glob_i < globals_len; glob_i += 1) {
            uint64_t *global = &globals[glob_i];
            uint32_t content_type = read32_uleb128(mod_ptr, &i);
            uint32_t mutability = read32_uleb128(mod_ptr, &i);
            if (mutability != 1) panic("expected mutable global");
            if (content_type != 0x7f) panic("unexpected content type");
            uint8_t opcode = mod_ptr[i];
            i += 1;
            if (opcode != WasmOp_i32_const) panic("expected i32_const op");
            uint32_t init = read32_ileb128(mod_ptr, &i);
            *global = (uint32_t)init;
        }
    }

    // Allocate and initialize memory.
    uint32_t memory_len;
    {
        i = section_starts[Section_memory];
        uint32_t memories_len = read32_uleb128(mod_ptr, &i);
        if (memories_len != 1) panic("unexpected memory count");
        uint32_t flags = read32_uleb128(mod_ptr, &i);
        (void)flags;
        memory_len = read32_uleb128(mod_ptr, &i) * wasm_page_size;

        i = section_starts[Section_data];
        uint32_t datas_count = read32_uleb128(mod_ptr, &i);
        for (; datas_count > 0; datas_count -= 1) {
            uint32_t mode = read32_uleb128(mod_ptr, &i);
            if (mode != 0) panic("expected mode 0");
            enum WasmOp opcode = mod_ptr[i];
            i += 1;
            if (opcode != WasmOp_i32_const) panic("expected opcode i32_const");
            uint32_t offset = read32_uleb128(mod_ptr, &i);
            enum WasmOp end = mod_ptr[i];
            if (end != WasmOp_end) panic("expected end opcode");
            i += 1;
            uint32_t bytes_len = read32_uleb128(mod_ptr, &i);
            memcpy(memory + offset, mod_ptr + i, bytes_len);
            i += bytes_len;
        }
    }

    uint32_t *table = NULL;
    {
        i = section_starts[Section_table];
        uint32_t table_count = read32_uleb128(mod_ptr, &i);
        if (table_count > 1) {
            panic("expected only one table section");
        } else if (table_count == 1) {
            uint32_t element_type = read32_uleb128(mod_ptr, &i);
            (void)element_type;
            uint32_t has_max = read32_uleb128(mod_ptr, &i);
            if (has_max != 1) panic("expected has_max==1");
            uint32_t initial = read32_uleb128(mod_ptr, &i);
            (void)initial;
            uint32_t maximum = read32_uleb128(mod_ptr, &i);

            i = section_starts[Section_element];
            uint32_t element_section_count = read32_uleb128(mod_ptr, &i);
            if (element_section_count != 1) panic("expected one element section");
            uint32_t flags = read32_uleb128(mod_ptr, &i);
            (void)flags;
            enum WasmOp opcode = mod_ptr[i];
            i += 1;
            if (opcode != WasmOp_i32_const) panic("expected op i32_const");
            uint32_t offset = read32_uleb128(mod_ptr, &i);
            enum WasmOp end = mod_ptr[i];
            if (end != WasmOp_end) panic("expected op end");
            i += 1;
            uint32_t elem_count = read32_uleb128(mod_ptr, &i);

            table = arena_alloc(sizeof(uint32_t) * maximum);
            memset(table, 0, sizeof(uint32_t) * maximum);

            for (uint32_t elem_i = 0; elem_i < elem_count; elem_i += 1) {
                table[elem_i + offset] = read32_uleb128(mod_ptr, &i);
            }
        }
    }

    struct VirtualMachine vm;
#ifndef NDEBUG
    memset(&vm, 0xaa, sizeof(struct VirtualMachine)); // to match the zig version
#endif
    vm.stack = arena_alloc(sizeof(uint64_t) * 10000000),
    vm.mod_ptr = mod_ptr;
    vm.opcodes = arena_alloc(2000000);
    vm.operands = arena_alloc(sizeof(uint32_t) * 2000000);
    vm.stack_top = 0;
    vm.functions = functions;
    vm.types = types;
    vm.globals = globals;
    vm.memory = memory;
    vm.memory_len = memory_len;
    vm.imports = imports;
    vm.imports_len = imports_len;
    vm.args = new_argv;
    vm.table = table;

    {
        uint32_t code_i = section_starts[Section_code];
        uint32_t codes_len = read32_uleb128(mod_ptr, &code_i);
        if (codes_len != functions_len) panic("code/function length mismatch");
        struct ProgramCounter pc;
        pc.opcode = 0;
        pc.operand = 0;
        for (uint32_t func_i = 0; func_i < functions_len; func_i += 1) {
            struct Function *func = &functions[func_i];
            uint32_t size = read32_uleb128(mod_ptr, &code_i);
            uint32_t code_begin = code_i;

            struct TypeInfo *type_info = &vm.types[func->type_idx];
            func->locals_count = 0;
            func->local_types = malloc(sizeof(uint32_t) * ((type_info->param_count + func->locals_count + 31) / 32));
            func->local_types[0] = type_info->param_types;

            for (uint32_t local_sets_count = read32_uleb128(mod_ptr, &code_i);
                 local_sets_count > 0; local_sets_count -= 1)
            {
                uint32_t set_count = read32_uleb128(mod_ptr, &code_i);
                int64_t local_type = read64_ileb128(mod_ptr, &code_i);

                uint32_t i = type_info->param_count + func->locals_count;
                func->locals_count += set_count;
                if ((type_info->param_count + func->locals_count + 31) / 32 > (i + 31) / 32)
                    func->local_types = realloc(func->local_types, sizeof(uint32_t) * ((type_info->param_count + func->locals_count + 31) / 32));
                for (; i < type_info->param_count + func->locals_count; i += 1)
                    switch (local_type) {
                        case -1: case -3: bs_unset(func->local_types, i); break;
                        case -2: case -4:   bs_set(func->local_types, i); break;
                        default: panic("unexpected local type");
                    }
            }

            //fprintf(stderr, "set up func %u with pc %u:%u\n", func->type_idx, pc.opcode, pc.operand);
            func->entry_pc = pc;
            vm_decodeCode(&vm, func, &code_i, &pc);
            if (code_i != code_begin + size) panic("bad code size");
        }
    }

    vm_call(&vm, start_fn_idx);
    vm_run(&vm);

    return 0;
}
