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

static uint32_t read_u32_le(const char *ptr) {
    const uint8_t *u8_ptr = (const uint8_t *)ptr;
    return
        (((uint64_t)u8_ptr[0]) << 0x00) |
        (((uint64_t)u8_ptr[1]) << 0x08) |
        (((uint64_t)u8_ptr[2]) << 0x10) |
        (((uint64_t)u8_ptr[3]) << 0x18);
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
    Op_br_nez_void,
    Op_br_nez_32,
    Op_br_nez_64,
    Op_br_eqz_void,
    Op_br_eqz_32,
    Op_br_eqz_64,
    Op_br_table_void,
    Op_br_table_32,
    Op_br_table_64,
    Op_return_void,
    Op_return_32,
    Op_return_64,
    Op_call_import,
    Op_call_func,
    Op_call_indirect,
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
    Op_load_0_8,
    Op_load_8,
    Op_load_0_16,
    Op_load_16,
    Op_load_0_32,
    Op_load_32,
    Op_load_0_64,
    Op_load_64,
    Op_store_0_8,
    Op_store_8,
    Op_store_0_16,
    Op_store_16,
    Op_store_0_32,
    Op_store_32,
    Op_store_0_64,
    Op_store_64,
    Op_mem_size,
    Op_mem_grow,
    Op_const_0_32,
    Op_const_0_64,
    Op_const_1_32,
    Op_const_1_64,
    Op_const_32,
    Op_const_64,
    Op_const_umax_32,
    Op_const_umax_64,
    Op_eqz_32,
    Op_eq_32,
    Op_ne_32,
    Op_slt_32,
    Op_ult_32,
    Op_sgt_32,
    Op_ugt_32,
    Op_sle_32,
    Op_ule_32,
    Op_sge_32,
    Op_uge_32,
    Op_eqz_64,
    Op_eq_64,
    Op_ne_64,
    Op_slt_64,
    Op_ult_64,
    Op_sgt_64,
    Op_ugt_64,
    Op_sle_64,
    Op_ule_64,
    Op_sge_64,
    Op_uge_64,
    Op_feq_32,
    Op_fne_32,
    Op_flt_32,
    Op_fgt_32,
    Op_fle_32,
    Op_fge_32,
    Op_feq_64,
    Op_fne_64,
    Op_flt_64,
    Op_fgt_64,
    Op_fle_64,
    Op_fge_64,
    Op_clz_32,
    Op_ctz_32,
    Op_popcnt_32,
    Op_add_32,
    Op_sub_32,
    Op_mul_32,
    Op_sdiv_32,
    Op_udiv_32,
    Op_srem_32,
    Op_urem_32,
    Op_and_32,
    Op_or_32,
    Op_xor_32,
    Op_shl_32,
    Op_ashr_32,
    Op_lshr_32,
    Op_rol_32,
    Op_ror_32,
    Op_clz_64,
    Op_ctz_64,
    Op_popcnt_64,
    Op_add_64,
    Op_sub_64,
    Op_mul_64,
    Op_sdiv_64,
    Op_udiv_64,
    Op_srem_64,
    Op_urem_64,
    Op_and_64,
    Op_or_64,
    Op_xor_64,
    Op_shl_64,
    Op_ashr_64,
    Op_lshr_64,
    Op_rol_64,
    Op_ror_64,
    Op_fabs_32,
    Op_fneg_32,
    Op_ceil_32,
    Op_floor_32,
    Op_trunc_32,
    Op_nearest_32,
    Op_sqrt_32,
    Op_fadd_32,
    Op_fsub_32,
    Op_fmul_32,
    Op_fdiv_32,
    Op_fmin_32,
    Op_fmax_32,
    Op_copysign_32,
    Op_fabs_64,
    Op_fneg_64,
    Op_ceil_64,
    Op_floor_64,
    Op_trunc_64,
    Op_nearest_64,
    Op_sqrt_64,
    Op_fadd_64,
    Op_fsub_64,
    Op_fmul_64,
    Op_fdiv_64,
    Op_fmin_64,
    Op_fmax_64,
    Op_copysign_64,
    Op_ftos_32_32,
    Op_ftou_32_32,
    Op_ftos_32_64,
    Op_ftou_32_64,
    Op_sext_64_32,
    Op_ftos_64_32,
    Op_ftou_64_32,
    Op_ftos_64_64,
    Op_ftou_64_64,
    Op_stof_32_32,
    Op_utof_32_32,
    Op_stof_32_64,
    Op_utof_32_64,
    Op_ftof_32_64,
    Op_stof_64_32,
    Op_utof_64_32,
    Op_stof_64_64,
    Op_utof_64_64,
    Op_ftof_64_32,
    Op_sext8_32,
    Op_sext16_32,
    Op_sext8_64,
    Op_sext16_64,
    Op_sext32_64,
    Op_memcpy,
    Op_memset,

    Op_wrap_32_64 = Op_drop_32,
    Op_zext_64_32 = Op_const_0_32,
    Op_last = Op_memset,
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
    uint32_t id;
    // Index to start of code in opcodes/operands.
    struct ProgramCounter entry_pc;
    uint32_t type_idx;
    uint32_t locals_size;
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
    uint32_t *stack;
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
    fprintf(stderr, "wasi_debug: '%s' number=%" PRIu64 " %" PRIx64 "\n", vm->memory + text, n, n);
}

/// pub extern "wasi_snapshot_preview1" fn debug_slice(ptr: [*]const u8, len: usize) void;
void wasi_debug_slice(struct VirtualMachine *vm, uint32_t ptr, uint32_t len) {
    fprintf(stderr, "wasi_debug_slice: '%.*s'\n", len, vm->memory + ptr);
}

enum StackType {
    ST_32,
    ST_64,
};

struct Label {
    enum WasmOp opcode;
    uint32_t stack_index;
    uint32_t stack_offset;
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

static enum StackType Label_operandType(const struct Label *label, uint32_t index) {
    if (label->opcode == WasmOp_loop) {
        return bs_isSet(&label->type_info.param_types, index);
    } else {
        return bs_isSet(&label->type_info.result_types, index);
    }
}

#define max_stack_depth (1 << 12)

struct StackInfo {
    uint32_t top_index;
    uint32_t top_offset;
    uint32_t types[max_stack_depth >> 5];
    uint32_t offsets[max_stack_depth];
};

static enum StackType si_top(const struct StackInfo *si) {
    return bs_isSet(si->types, si->top_index - 1);
}

static enum StackType si_local(const struct StackInfo *si, uint32_t local_idx) {
    return bs_isSet(si->types, local_idx);
}

static void si_push(struct StackInfo *si, enum StackType entry_type) {
    bs_setValue(si->types, si->top_index, entry_type);
    si->offsets[si->top_index] = si->top_offset;
    si->top_index += 1;
    si->top_offset += 1 + entry_type;
}

static void si_pop(struct StackInfo *si, enum StackType entry_type) {
    assert(si_top(si) == entry_type);
    si->top_index -= 1;
    si->top_offset -= 1 + entry_type;
    assert(si->top_offset == si->offsets[si->top_index]);
}

static void vm_decodeCode(struct VirtualMachine *vm, struct TypeInfo *func_type_info,
    uint32_t *code_i, struct ProgramCounter *pc, struct StackInfo *stack)
{
    const char *mod_ptr = vm->mod_ptr;
    uint8_t *opcodes = vm->opcodes;
    uint32_t *operands = vm->operands;

    // push return address
    uint32_t frame_size = stack->top_offset;
    si_push(stack, ST_32);
    si_push(stack, ST_32);

    uint32_t unreachable_depth = 0;
    uint32_t label_i = 0;
    static struct Label labels[1 << 9];
#ifndef NDEBUG
    memset(labels, 0xaa, sizeof(struct Label) * (1 << 9)); // to match the zig version
#endif
    labels[label_i].opcode = WasmOp_block;
    labels[label_i].stack_index = stack->top_index;
    labels[label_i].stack_offset = stack->top_offset;
    labels[label_i].type_info = *func_type_info;
    labels[label_i].ref_list = UINT32_MAX;

    enum {
        State_default,
        State_bool_not,
    } state = State_default;

    for (;;) {
        assert(stack->top_index >= labels[0].stack_index);
        assert(stack->top_offset >= labels[0].stack_offset);
        enum WasmOp opcode = (uint8_t)mod_ptr[*code_i];
        *code_i += 1;
        enum WasmPrefixedOp prefixed_opcode;
        if (opcode == WasmOp_prefixed) prefixed_opcode = read32_uleb128(mod_ptr, code_i);

        //fprintf(stderr, "decodeCode opcode=0x%x pc=%u:%u\n", opcode, pc->opcode, pc->operand);
        //struct ProgramCounter old_pc = *pc;

        if (unreachable_depth == 0)
            switch (opcode) {
                case WasmOp_unreachable:
                case WasmOp_nop:
                case WasmOp_block:
                case WasmOp_loop:
                case WasmOp_else:
                case WasmOp_end:
                case WasmOp_br:
                case WasmOp_return:
                case WasmOp_call:
                case WasmOp_local_get:
                case WasmOp_local_set:
                case WasmOp_local_tee:
                case WasmOp_global_get:
                case WasmOp_global_set:
                case WasmOp_drop:
                case WasmOp_select:
                break; // handled manually below

                case WasmOp_if:
                case WasmOp_br_if:
                case WasmOp_br_table:
                case WasmOp_call_indirect:
                si_pop(stack, ST_32);
                break;

                case WasmOp_memory_size:
                case WasmOp_i32_const:
                case WasmOp_f32_const:
                si_push(stack, ST_32);
                break;

                case WasmOp_i64_const:
                case WasmOp_f64_const:
                si_push(stack, ST_64);
                break;

                case WasmOp_i32_load:
                case WasmOp_f32_load:
                case WasmOp_i32_load8_s:
                case WasmOp_i32_load8_u:
                case WasmOp_i32_load16_s:
                case WasmOp_i32_load16_u:
                si_pop(stack, ST_32);
                si_push(stack, ST_32);
                break;

                case WasmOp_i64_load:
                case WasmOp_f64_load:
                case WasmOp_i64_load8_s:
                case WasmOp_i64_load8_u:
                case WasmOp_i64_load16_s:
                case WasmOp_i64_load16_u:
                case WasmOp_i64_load32_s:
                case WasmOp_i64_load32_u:
                si_pop(stack, ST_32);
                si_push(stack, ST_64);
                break;

                case WasmOp_memory_grow:
                case WasmOp_i32_eqz:
                case WasmOp_i32_clz:
                case WasmOp_i32_ctz:
                case WasmOp_i32_popcnt:
                case WasmOp_f32_abs:
                case WasmOp_f32_neg:
                case WasmOp_f32_ceil:
                case WasmOp_f32_floor:
                case WasmOp_f32_trunc:
                case WasmOp_f32_nearest:
                case WasmOp_f32_sqrt:
                case WasmOp_i32_trunc_f32_s:
                case WasmOp_i32_trunc_f32_u:
                case WasmOp_f32_convert_i32_s:
                case WasmOp_f32_convert_i32_u:
                case WasmOp_i32_reinterpret_f32:
                case WasmOp_f32_reinterpret_i32:
                case WasmOp_i32_extend8_s:
                case WasmOp_i32_extend16_s:
                si_pop(stack, ST_32);
                si_push(stack, ST_32);
                break;

                case WasmOp_i64_eqz:
                case WasmOp_i32_wrap_i64:
                case WasmOp_i32_trunc_f64_s:
                case WasmOp_i32_trunc_f64_u:
                case WasmOp_f32_convert_i64_s:
                case WasmOp_f32_convert_i64_u:
                case WasmOp_f32_demote_f64:
                si_pop(stack, ST_64);
                si_push(stack, ST_32);
                break;

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
                case WasmOp_i64_trunc_f64_s:
                case WasmOp_i64_trunc_f64_u:
                case WasmOp_f64_convert_i64_s:
                case WasmOp_f64_convert_i64_u:
                case WasmOp_i64_reinterpret_f64:
                case WasmOp_f64_reinterpret_i64:
                case WasmOp_i64_extend8_s:
                case WasmOp_i64_extend16_s:
                case WasmOp_i64_extend32_s:
                si_pop(stack, ST_64);
                si_push(stack, ST_64);
                break;

                case WasmOp_i64_extend_i32_s:
                case WasmOp_i64_extend_i32_u:
                case WasmOp_i64_trunc_f32_s:
                case WasmOp_i64_trunc_f32_u:
                case WasmOp_f64_convert_i32_s:
                case WasmOp_f64_convert_i32_u:
                case WasmOp_f64_promote_f32:
                si_pop(stack, ST_32);
                si_push(stack, ST_64);
                break;

                case WasmOp_i32_store:
                case WasmOp_f32_store:
                case WasmOp_i32_store8:
                case WasmOp_i32_store16:
                si_pop(stack, ST_32);
                si_pop(stack, ST_32);
                break;

                case WasmOp_i64_store:
                case WasmOp_f64_store:
                case WasmOp_i64_store8:
                case WasmOp_i64_store16:
                case WasmOp_i64_store32:
                si_pop(stack, ST_64);
                si_pop(stack, ST_32);
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
                case WasmOp_f32_eq:
                case WasmOp_f32_ne:
                case WasmOp_f32_lt:
                case WasmOp_f32_gt:
                case WasmOp_f32_le:
                case WasmOp_f32_ge:
                si_pop(stack, ST_32);
                si_pop(stack, ST_32);
                si_push(stack, ST_32);
                break;

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
                case WasmOp_f64_eq:
                case WasmOp_f64_ne:
                case WasmOp_f64_lt:
                case WasmOp_f64_gt:
                case WasmOp_f64_le:
                case WasmOp_f64_ge:
                si_pop(stack, ST_64);
                si_pop(stack, ST_64);
                si_push(stack, ST_32);
                break;

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
                si_pop(stack, ST_32);
                si_pop(stack, ST_32);
                si_push(stack, ST_32);
                break;

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
                si_pop(stack, ST_64);
                si_pop(stack, ST_64);
                si_push(stack, ST_64);
                break;

                case WasmOp_prefixed:
                switch (prefixed_opcode) {
                    case WasmPrefixedOp_i32_trunc_sat_f32_s:
                    case WasmPrefixedOp_i32_trunc_sat_f32_u:
                    si_pop(stack, ST_32);
                    si_push(stack, ST_32);
                    break;

                    case WasmPrefixedOp_i32_trunc_sat_f64_s:
                    case WasmPrefixedOp_i32_trunc_sat_f64_u:
                    si_pop(stack, ST_64);
                    si_push(stack, ST_32);
                    break;

                    case WasmPrefixedOp_i64_trunc_sat_f32_s:
                    case WasmPrefixedOp_i64_trunc_sat_f32_u:
                    si_pop(stack, ST_32);
                    si_push(stack, ST_64);
                    break;

                    case WasmPrefixedOp_i64_trunc_sat_f64_s:
                    case WasmPrefixedOp_i64_trunc_sat_f64_u:
                    si_pop(stack, ST_64);
                    si_push(stack, ST_64);
                    break;

                    case WasmPrefixedOp_memory_init:
                    case WasmPrefixedOp_memory_copy:
                    case WasmPrefixedOp_memory_fill:
                    case WasmPrefixedOp_table_init:
                    case WasmPrefixedOp_table_copy:
                    si_pop(stack, ST_32);
                    si_pop(stack, ST_32);
                    si_pop(stack, ST_32);
                    break;

                    case WasmPrefixedOp_table_fill:
                    si_pop(stack, ST_32);
                    panic("si_pop(stack, unreachable);");
                    si_pop(stack, ST_32);
                    break;

                    case WasmPrefixedOp_data_drop:
                    case WasmPrefixedOp_elem_drop:
                    break;

                    case WasmPrefixedOp_table_grow:
                    si_pop(stack, ST_32);
                    panic("si_pop(stack, unreachable);");
                    si_push(stack, ST_32);
                    break;

                    case WasmPrefixedOp_table_size:
                    si_push(stack, ST_32);
                    break;

                    default: panic("unexpected prefixed opcode");
                }
                break;

                default: panic("unexpected opcode");
            }
        switch (opcode) {
            case WasmOp_unreachable:
            if (unreachable_depth == 0) {
                opcodes[pc->opcode] = Op_unreachable;
                pc->opcode += 1;
                unreachable_depth += 1;
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
                    } else label->type_info = vm->types[block_type];

                    uint32_t param_i = label->type_info.param_count;
                    while (param_i > 0) {
                        param_i -= 1;
                        si_pop(stack, bs_isSet(&label->type_info.param_types, param_i));
                    }
                    label->stack_index = stack->top_index;
                    label->stack_offset = stack->top_offset;
                    label->ref_list = UINT32_MAX;
                    for (; param_i < label->type_info.param_count; param_i += 1)
                        si_push(stack, bs_isSet(&label->type_info.param_types, param_i));

                    switch (opcode) {
                        case WasmOp_block:
                        break;

                        case WasmOp_loop:
                        label->extra.loop_pc = *pc;
                        break;

                        case WasmOp_if:
                        if (state == State_bool_not) {
                            pc->opcode -= 1;
                            opcodes[pc->opcode] = Op_br_nez_void;
                        } else opcodes[pc->opcode] = Op_br_eqz_void;
                        pc->opcode += 1;
                        operands[pc->operand] = 0;
                        label->extra.else_ref = pc->operand + 1;
                        pc->operand += 3;
                        break;

                        default: panic("unexpected label opcode");
                    }
                } else unreachable_depth += 1;
            }
            break;

            case WasmOp_else:
            if (unreachable_depth <= 1) {
                struct Label *label = &labels[label_i];
                assert(label->opcode == WasmOp_if);
                label->opcode = WasmOp_else;

                if (unreachable_depth == 0) {
                    uint32_t operand_count = Label_operandCount(label);
                    for (uint32_t operand_i = operand_count; operand_i > 0; ) {
                        operand_i -= 1;
                        si_pop(stack, Label_operandType(label, operand_i));
                    }
                    assert(stack->top_index == label->stack_index);
                    assert(stack->top_offset == label->stack_offset);

                    switch (operand_count) {
                        case 0:
                        opcodes[pc->opcode] = Op_br_void;
                        break;

                        case 1:
                        //fprintf(stderr, "label_i=%u operand_type=%d\n",
                        //        label_i, Label_operandType(label, 0));
                        switch (Label_operandType(label, 0)) {
                            case ST_32: opcodes[pc->opcode] = Op_br_32; break;
                            case ST_64: opcodes[pc->opcode] = Op_br_64; break;
                        }
                        break;

                        default: panic("unexpected operand count");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = stack->top_offset - label->stack_offset;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;
                } else unreachable_depth = 0;

                operands[label->extra.else_ref + 0] = pc->opcode;
                operands[label->extra.else_ref + 1] = pc->operand;
                for (uint32_t param_i = 0; param_i < label->type_info.param_count; param_i += 1)
                    si_push(stack, bs_isSet(&label->type_info.param_types, param_i));
            }
            break;

            case WasmOp_end:
            if (unreachable_depth <= 1) {
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

                if (unreachable_depth == 0) {
                    for (uint32_t result_i = label->type_info.result_count; result_i > 0; ) {
                        result_i -= 1;
                        si_pop(stack, bs_isSet(&label->type_info.result_types, result_i));
                    }
                } else unreachable_depth = 0;

                if (label_i == 0) {
                    assert(stack->top_index == label->stack_index);
                    assert(stack->top_offset == label->stack_offset);

                    switch (labels[0].type_info.result_count) {
                        case 0:
                        opcodes[pc->opcode] = Op_return_void;
                        break;

                        case 1:
                        switch ((enum StackType)bs_isSet(&labels[0].type_info.result_types, 0)) {
                            case ST_32: opcodes[pc->opcode] = Op_return_32; break;
                            case ST_64: opcodes[pc->opcode] = Op_return_64; break;
                        }
                        break;

                        default: panic("unexpected operand count");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = stack->top_offset - labels[0].stack_offset;
                    operands[pc->operand + 1] = frame_size;
                    pc->operand += 2;
                    return;
                }
                label_i -= 1;

                stack->top_index = label->stack_index;
                stack->top_offset = label->stack_offset;
                for (uint32_t result_i = 0; result_i < label->type_info.result_count; result_i += 1)
                    si_push(stack, bs_isSet(&label->type_info.result_types, result_i));
            } else unreachable_depth -= 1;
            break;

            case WasmOp_br:
            case WasmOp_br_if:
            {
                uint32_t label_idx = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    struct Label *label = &labels[label_i - label_idx];
                    uint32_t operand_count = Label_operandCount(label);
                    uint32_t operand_i = operand_count;
                    while (operand_i > 0) {
                        operand_i -= 1;
                        si_pop(stack, Label_operandType(label, operand_i));
                    }

                    switch (opcode) {
                        case WasmOp_br:
                        switch (operand_count) {
                            case 0:
                            opcodes[pc->opcode] = Op_br_void;
                            break;

                            case 1:
                            switch (Label_operandType(label, 0)) {
                                case ST_32: opcodes[pc->opcode] = Op_br_32; break;
                                case ST_64: opcodes[pc->opcode] = Op_br_64; break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        break;

                        case WasmOp_br_if:
                        switch (operand_count) {
                            case 0:
                            if (state == State_bool_not) {
                                pc->opcode -= 1;
                                opcodes[pc->opcode] = Op_br_eqz_void;
                            } else opcodes[pc->opcode] = Op_br_nez_void;
                            break;

                            case 1:
                            switch (Label_operandType(label, 0)) {
                                case ST_32:
                                if (state == State_bool_not) {
                                    pc->opcode -= 1;
                                    opcodes[pc->opcode] = Op_br_eqz_32;
                                } else opcodes[pc->opcode] = Op_br_nez_32;
                                break;

                                case ST_64:
                                if (state == State_bool_not) {
                                    pc->opcode -= 1;
                                    opcodes[pc->opcode] = Op_br_eqz_64;
                                } else opcodes[pc->opcode] = Op_br_nez_64;
                                break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        break;

                        default: panic("unexpected opcode");
                    }
                    pc->opcode += 1;
                    operands[pc->operand + 0] = stack->top_offset - label->stack_offset;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;

                    switch (opcode) {
                        case WasmOp_br:
                        unreachable_depth += 1;
                        break;

                        case WasmOp_br_if:
                        for (; operand_i < operand_count; operand_i += 1)
                            si_push(stack, Label_operandType(label, operand_i));
                        break;

                        default: panic("unexpected opcode");
                    }
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
                    if (i == 0) {
                        uint32_t operand_count = Label_operandCount(label);
                        for (uint32_t operand_i = operand_count; operand_i > 0; ) {
                            operand_i -= 1;
                            si_pop(stack, Label_operandType(label, operand_i));
                        }

                        switch (operand_count) {
                            case 0:
                            opcodes[pc->opcode] = Op_br_table_void;
                            break;

                            case 1:
                            switch (Label_operandType(label, 0)) {
                                case ST_32: opcodes[pc->opcode] = Op_br_table_32; break;
                                case ST_64: opcodes[pc->opcode] = Op_br_table_64; break;
                            }
                            break;

                            default: panic("unexpected operand count");
                        }
                        pc->opcode += 1;
                        operands[pc->operand] = labels_len;
                        pc->operand += 1;
                    }
                    operands[pc->operand + 0] = stack->top_offset - label->stack_offset;
                    operands[pc->operand + 1] = label->ref_list;
                    label->ref_list = pc->operand + 1;
                    pc->operand += 3;
                }
                if (unreachable_depth == 0) unreachable_depth += 1;
            }
            break;

            case WasmOp_return:
            if (unreachable_depth == 0) {
                for (uint32_t result_i = labels[0].type_info.result_count; result_i > 0; ) {
                    result_i -= 1;
                    si_pop(stack, bs_isSet(&labels[0].type_info.result_types, result_i));
                }

                switch (labels[0].type_info.result_count) {
                    case 0:
                    opcodes[pc->opcode] = Op_return_void;
                    break;

                    case 1:
                    switch ((enum StackType)bs_isSet(&labels[0].type_info.result_types, 0)) {
                        case ST_32: opcodes[pc->opcode] = Op_return_32; break;
                        case ST_64: opcodes[pc->opcode] = Op_return_64; break;
                    }
                    break;

                    default: panic("unexpected operand count");
                }
                pc->opcode += 1;
                operands[pc->operand + 0] = stack->top_offset - labels[0].stack_offset;
                operands[pc->operand + 1] = frame_size;
                pc->operand += 2;
                unreachable_depth += 1;
            }
            break;

            case WasmOp_call:
            {
                uint32_t fn_id = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    uint32_t type_idx;
                    if (fn_id < vm->imports_len) {
                        opcodes[pc->opcode + 0] = Op_call_import;
                        opcodes[pc->opcode + 1] = fn_id;
                        pc->opcode += 2;
                        type_idx = vm->imports[fn_id].type_idx;
                    } else {
                        uint32_t fn_idx = fn_id - vm->imports_len;
                        opcodes[pc->opcode] = Op_call_func;
                        pc->opcode += 1;
                        operands[pc->operand] = fn_idx;
                        pc->operand += 1;
                        type_idx = vm->functions[fn_idx].type_idx;
                    }
                    struct TypeInfo *type_info = &vm->types[type_idx];

                    for (uint32_t param_i = type_info->param_count; param_i > 0; ) {
                        param_i -= 1;
                        si_pop(stack, bs_isSet(&type_info->param_types, param_i));
                    }
                    for (uint32_t result_i = 0; result_i < type_info->result_count; result_i += 1)
                        si_push(stack, bs_isSet(&type_info->result_types, result_i));
                }
            }
            break;

            case WasmOp_call_indirect:
            {
                uint32_t type_idx = read32_uleb128(mod_ptr, code_i);
                if (read32_uleb128(mod_ptr, code_i) != 0) panic("unexpected table index");
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_call_indirect;
                    pc->opcode += 1;

                    struct TypeInfo *type_info = &vm->types[type_idx];
                    for (uint32_t param_i = type_info->param_count; param_i > 0; ) {
                        param_i -= 1;
                        si_pop(stack, bs_isSet(&type_info->param_types, param_i));
                    }
                    for (uint32_t result_i = 0; result_i < type_info->result_count; result_i += 1)
                        si_push(stack, bs_isSet(&type_info->result_types, result_i));
                }
            }
            break;

            case WasmOp_select:
            case WasmOp_drop:
            if (unreachable_depth == 0) {
                if (opcode == WasmOp_select) si_pop(stack, ST_32);
                enum StackType operand_type = si_top(stack);
                si_pop(stack, operand_type);
                if (opcode == WasmOp_select) {
                    si_pop(stack, operand_type);
                    si_push(stack, operand_type);
                }
                switch (opcode) {
                    case WasmOp_select:
                    switch (operand_type) {
                        case ST_32: opcodes[pc->opcode] = Op_select_32; break;
                        case ST_64: opcodes[pc->opcode] = Op_select_64; break;
                    }
                    break;

                    case WasmOp_drop:
                    switch (operand_type) {
                        case ST_32: opcodes[pc->opcode] = Op_drop_32; break;
                        case ST_64: opcodes[pc->opcode] = Op_drop_64; break;
                    }
                    break;

                    default: panic("unexpected opcode");
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
                    enum StackType local_type = si_local(stack, local_idx);
                    switch (opcode) {
                        case WasmOp_local_get:
                        switch (local_type) {
                            case ST_32: opcodes[pc->opcode] = Op_local_get_32; break;
                            case ST_64: opcodes[pc->opcode] = Op_local_get_64; break;
                        }
                        break;

                        case WasmOp_local_set:
                        switch (local_type) {
                            case ST_32: opcodes[pc->opcode] = Op_local_set_32; break;
                            case ST_64: opcodes[pc->opcode] = Op_local_set_64; break;
                        }
                        break;

                        case WasmOp_local_tee:
                        switch (local_type) {
                            case ST_32: opcodes[pc->opcode] = Op_local_tee_32; break;
                            case ST_64: opcodes[pc->opcode] = Op_local_tee_64; break;
                        }
                        break;

                        default: panic("unexpected opcode");
                    }
                    pc->opcode += 1;
                    operands[pc->operand] = stack->top_offset - stack->offsets[local_idx];
                    pc->operand += 1;
                    switch (opcode) {
                        case WasmOp_local_get:
                        si_push(stack, local_type);
                        break;

                        case WasmOp_local_set:
                        si_pop(stack, local_type);
                        break;

                        case WasmOp_local_tee:
                        si_pop(stack, local_type);
                        si_push(stack, local_type);
                        break;

                        default: panic("unexpected opcode");
                    }
                }
            }
            break;

            case WasmOp_global_get:
            case WasmOp_global_set:
            {
                uint32_t global_idx = read32_uleb128(mod_ptr, code_i);
                if (unreachable_depth == 0) {
                    enum StackType global_type = ST_32; // all globals assumed to be 32-bit
                    switch (opcode) {
                        case WasmOp_global_get:
                        switch (global_idx) {
                            case 0: opcodes[pc->opcode] = Op_global_get_0_32; break;
                            default: opcodes[pc->opcode] = Op_global_get_32; break;
                        }
                        break;

                        case WasmOp_global_set:
                        switch (global_idx) {
                            case 0: opcodes[pc->opcode] = Op_global_set_0_32; break;
                            default: opcodes[pc->opcode] = Op_global_set_32; break;
                        }
                        break;

                        default: panic("unexpected opcode");
                    }
                    pc->opcode += 1;
                    if (global_idx != 0) {
                        operands[pc->operand] = global_idx;
                        pc->operand += 1;
                    }
                    switch (opcode) {
                        case WasmOp_global_get:
                        si_push(stack, global_type);
                        break;

                        case WasmOp_global_set:
                        si_pop(stack, global_type);
                        break;

                        default: panic("unexpected opcode");
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
                    switch (opcode) {
                        default: break;

                        case WasmOp_i64_store8: case WasmOp_i64_store16: case WasmOp_i64_store32:
                        opcodes[pc->opcode] = Op_drop_32;
                        pc->opcode += 1;
                        break;
                    }
                    switch (opcode) {
                        case WasmOp_i32_load8_s: case WasmOp_i32_load8_u:
                        case WasmOp_i64_load8_s: case WasmOp_i64_load8_u:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_load_0_8; break;
                            default: opcodes[pc->opcode] = Op_load_8; break;
                        }
                        break;

                        case WasmOp_i32_load16_s: case WasmOp_i32_load16_u:
                        case WasmOp_i64_load16_s: case WasmOp_i64_load16_u:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_load_0_16; break;
                            default: opcodes[pc->opcode] = Op_load_16; break;
                        }
                        break;

                        case WasmOp_i32_load: case WasmOp_f32_load:
                        case WasmOp_i64_load32_s: case WasmOp_i64_load32_u:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_load_0_32; break;
                            default: opcodes[pc->opcode] = Op_load_32; break;
                        }
                        break;

                        case WasmOp_i64_load: case WasmOp_f64_load:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_load_0_64; break;
                            default: opcodes[pc->opcode] = Op_load_64; break;
                        }
                        break;

                        case WasmOp_i32_store8: case WasmOp_i64_store8:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_store_0_8; break;
                            default: opcodes[pc->opcode] = Op_store_8; break;
                        }
                        break;

                        case WasmOp_i32_store16: case WasmOp_i64_store16:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_store_0_16; break;
                            default: opcodes[pc->opcode] = Op_store_16; break;
                        }
                        break;

                        case WasmOp_i32_store: case WasmOp_f32_store: case WasmOp_i64_store32:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_store_0_32; break;
                            default: opcodes[pc->opcode] = Op_store_32; break;
                        }
                        break;

                        case WasmOp_i64_store: case WasmOp_f64_store:
                        switch (offset) {
                            case 0: opcodes[pc->opcode] = Op_store_0_64; break;
                            default: opcodes[pc->opcode] = Op_store_64; break;
                        }
                        break;

                        default: panic("unexpected opcode");
                    }
                    pc->opcode += 1;
                    switch (offset) {
                        case 0: break;

                        default:
                        operands[pc->operand] = offset;
                        pc->operand += 1;
                        break;
                    }
                    switch (opcode) {
                        default: break;

                        case WasmOp_i32_load8_s: case WasmOp_i64_load8_s:
                        opcodes[pc->opcode] = Op_sext8_32;
                        pc->opcode += 1;
                        break;

                        case WasmOp_i32_load16_s: case WasmOp_i64_load16_s:
                        opcodes[pc->opcode] = Op_sext16_32;
                        pc->opcode += 1;
                        break;
                    }
                    switch (opcode) {
                        default: break;

                        case WasmOp_i64_load8_s: case WasmOp_i64_load16_s: case WasmOp_i64_load32_s:
                        opcodes[pc->opcode] = Op_sext_64_32;
                        pc->opcode += 1;
                        break;

                        case WasmOp_i64_load8_u: case WasmOp_i64_load16_u: case WasmOp_i64_load32_u:
                        opcodes[pc->opcode] = Op_zext_64_32;
                        pc->opcode += 1;
                        break;
                    }
                }
            }
            break;

            case WasmOp_memory_size:
            case WasmOp_memory_grow:
            {
                if (mod_ptr[*code_i] != 0) panic("unexpected memory index");
                *code_i += 1;
                if (unreachable_depth == 0) {
                    switch (opcode) {
                        case WasmOp_memory_size: opcodes[pc->opcode] = Op_mem_size; break;
                        case WasmOp_memory_grow: opcodes[pc->opcode] = Op_mem_grow; break;
                        default: panic("unexpected opcode");
                    }
                    pc->opcode += 1;
                }
            }
            break;

            case WasmOp_i32_const:
            case WasmOp_f32_const:
            {
                uint32_t value;
                switch (opcode) {
                    case WasmOp_i32_const: value = read32_ileb128(mod_ptr, code_i); break;

                    case WasmOp_f32_const:
                    value = read_u32_le(&mod_ptr[*code_i]);
                    *code_i += sizeof(value);
                    break;

                    default: panic("unexpected opcode");
                }
                if (unreachable_depth == 0) {
                    switch (value) {
                        case 0: opcodes[pc->opcode] = Op_const_0_32; break;
                        case 1: opcodes[pc->opcode] = Op_const_1_32; break;

                        default:
                        opcodes[pc->opcode] = Op_const_32;
                        operands[pc->operand] = value;
                        pc->operand += 1;
                        break;

                        case UINT32_MAX: opcodes[pc->opcode] = Op_const_umax_32; break;
                    }
                    pc->opcode += 1;
                }
            }
            break;

            case WasmOp_i64_const:
            case WasmOp_f64_const:
            {
                uint64_t value;
                switch (opcode) {
                    case WasmOp_i64_const: value = read64_ileb128(mod_ptr, code_i); break;

                    case WasmOp_f64_const:
                    value = read_u64_le(&mod_ptr[*code_i]);
                    *code_i += sizeof(value);
                    break;

                    default: panic("unexpected opcode");
                }

                if (unreachable_depth == 0) {
                    switch (value) {
                        case 0: opcodes[pc->opcode] = Op_const_0_64; break;
                        case 1: opcodes[pc->opcode] = Op_const_1_64; break;

                        default:
                        opcodes[pc->opcode] = Op_const_64;
                        operands[pc->operand + 0] = (uint32_t)(value >> 0);
                        operands[pc->operand + 1] = (uint32_t)(value >> 32);
                        pc->operand += 2;
                        break;

                        case UINT64_MAX: opcodes[pc->opcode] = Op_const_umax_64; break;
                    }
                    pc->opcode += 1;
                }
            }
            break;

            default:
            if (unreachable_depth == 0) {
                switch (opcode) {
                    case WasmOp_i32_eqz:           opcodes[pc->opcode] = Op_eqz_32;      break;
                    case WasmOp_i32_eq:            opcodes[pc->opcode] = Op_eq_32;       break;
                    case WasmOp_i32_ne:            opcodes[pc->opcode] = Op_ne_32;       break;
                    case WasmOp_i32_lt_s:          opcodes[pc->opcode] = Op_slt_32;      break;
                    case WasmOp_i32_lt_u:          opcodes[pc->opcode] = Op_ult_32;      break;
                    case WasmOp_i32_gt_s:          opcodes[pc->opcode] = Op_sgt_32;      break;
                    case WasmOp_i32_gt_u:          opcodes[pc->opcode] = Op_ugt_32;      break;
                    case WasmOp_i32_le_s:          opcodes[pc->opcode] = Op_sle_32;      break;
                    case WasmOp_i32_le_u:          opcodes[pc->opcode] = Op_ule_32;      break;
                    case WasmOp_i32_ge_s:          opcodes[pc->opcode] = Op_sge_32;      break;
                    case WasmOp_i32_ge_u:          opcodes[pc->opcode] = Op_uge_32;      break;
                    case WasmOp_i64_eqz:           opcodes[pc->opcode] = Op_eqz_64;      break;
                    case WasmOp_i64_eq:            opcodes[pc->opcode] = Op_eq_64;       break;
                    case WasmOp_i64_ne:            opcodes[pc->opcode] = Op_ne_64;       break;
                    case WasmOp_i64_lt_s:          opcodes[pc->opcode] = Op_slt_64;      break;
                    case WasmOp_i64_lt_u:          opcodes[pc->opcode] = Op_ult_64;      break;
                    case WasmOp_i64_gt_s:          opcodes[pc->opcode] = Op_sgt_64;      break;
                    case WasmOp_i64_gt_u:          opcodes[pc->opcode] = Op_ugt_64;      break;
                    case WasmOp_i64_le_s:          opcodes[pc->opcode] = Op_sle_64;      break;
                    case WasmOp_i64_le_u:          opcodes[pc->opcode] = Op_ule_64;      break;
                    case WasmOp_i64_ge_s:          opcodes[pc->opcode] = Op_sge_64;      break;
                    case WasmOp_i64_ge_u:          opcodes[pc->opcode] = Op_uge_64;      break;
                    case WasmOp_f32_eq:            opcodes[pc->opcode] = Op_feq_32;      break;
                    case WasmOp_f32_ne:            opcodes[pc->opcode] = Op_fne_32;      break;
                    case WasmOp_f32_lt:            opcodes[pc->opcode] = Op_flt_32;      break;
                    case WasmOp_f32_gt:            opcodes[pc->opcode] = Op_fgt_32;      break;
                    case WasmOp_f32_le:            opcodes[pc->opcode] = Op_fle_32;      break;
                    case WasmOp_f32_ge:            opcodes[pc->opcode] = Op_fge_32;      break;
                    case WasmOp_f64_eq:            opcodes[pc->opcode] = Op_feq_64;      break;
                    case WasmOp_f64_ne:            opcodes[pc->opcode] = Op_fne_64;      break;
                    case WasmOp_f64_lt:            opcodes[pc->opcode] = Op_flt_64;      break;
                    case WasmOp_f64_gt:            opcodes[pc->opcode] = Op_fgt_64;      break;
                    case WasmOp_f64_le:            opcodes[pc->opcode] = Op_fle_64;      break;
                    case WasmOp_f64_ge:            opcodes[pc->opcode] = Op_fge_64;      break;
                    case WasmOp_i32_clz:           opcodes[pc->opcode] = Op_clz_32;      break;
                    case WasmOp_i32_ctz:           opcodes[pc->opcode] = Op_ctz_32;      break;
                    case WasmOp_i32_popcnt:        opcodes[pc->opcode] = Op_popcnt_32;   break;
                    case WasmOp_i32_add:           opcodes[pc->opcode] = Op_add_32;      break;
                    case WasmOp_i32_sub:           opcodes[pc->opcode] = Op_sub_32;      break;
                    case WasmOp_i32_mul:           opcodes[pc->opcode] = Op_mul_32;      break;
                    case WasmOp_i32_div_s:         opcodes[pc->opcode] = Op_sdiv_32;     break;
                    case WasmOp_i32_div_u:         opcodes[pc->opcode] = Op_udiv_32;     break;
                    case WasmOp_i32_rem_s:         opcodes[pc->opcode] = Op_srem_32;     break;
                    case WasmOp_i32_rem_u:         opcodes[pc->opcode] = Op_urem_32;     break;
                    case WasmOp_i32_and:           opcodes[pc->opcode] = Op_and_32;      break;
                    case WasmOp_i32_or:            opcodes[pc->opcode] = Op_or_32;       break;
                    case WasmOp_i32_xor:           opcodes[pc->opcode] = Op_xor_32;      break;
                    case WasmOp_i32_shl:           opcodes[pc->opcode] = Op_shl_32;      break;
                    case WasmOp_i32_shr_s:         opcodes[pc->opcode] = Op_ashr_32;     break;
                    case WasmOp_i32_shr_u:         opcodes[pc->opcode] = Op_lshr_32;     break;
                    case WasmOp_i32_rotl:          opcodes[pc->opcode] = Op_rol_32;      break;
                    case WasmOp_i32_rotr:          opcodes[pc->opcode] = Op_ror_32;      break;
                    case WasmOp_i64_clz:           opcodes[pc->opcode] = Op_clz_64;      break;
                    case WasmOp_i64_ctz:           opcodes[pc->opcode] = Op_ctz_64;      break;
                    case WasmOp_i64_popcnt:        opcodes[pc->opcode] = Op_popcnt_64;   break;
                    case WasmOp_i64_add:           opcodes[pc->opcode] = Op_add_64;      break;
                    case WasmOp_i64_sub:           opcodes[pc->opcode] = Op_sub_64;      break;
                    case WasmOp_i64_mul:           opcodes[pc->opcode] = Op_mul_64;      break;
                    case WasmOp_i64_div_s:         opcodes[pc->opcode] = Op_sdiv_64;     break;
                    case WasmOp_i64_div_u:         opcodes[pc->opcode] = Op_udiv_64;     break;
                    case WasmOp_i64_rem_s:         opcodes[pc->opcode] = Op_srem_64;     break;
                    case WasmOp_i64_rem_u:         opcodes[pc->opcode] = Op_urem_64;     break;
                    case WasmOp_i64_and:           opcodes[pc->opcode] = Op_and_64;      break;
                    case WasmOp_i64_or:            opcodes[pc->opcode] = Op_or_64;       break;
                    case WasmOp_i64_xor:           opcodes[pc->opcode] = Op_xor_64;      break;
                    case WasmOp_i64_shl:           opcodes[pc->opcode] = Op_shl_64;      break;
                    case WasmOp_i64_shr_s:         opcodes[pc->opcode] = Op_ashr_64;     break;
                    case WasmOp_i64_shr_u:         opcodes[pc->opcode] = Op_lshr_64;     break;
                    case WasmOp_i64_rotl:          opcodes[pc->opcode] = Op_rol_64;      break;
                    case WasmOp_i64_rotr:          opcodes[pc->opcode] = Op_ror_64;      break;
                    case WasmOp_f32_abs:           opcodes[pc->opcode] = Op_fabs_32;     break;
                    case WasmOp_f32_neg:           opcodes[pc->opcode] = Op_fneg_32;     break;
                    case WasmOp_f32_ceil:          opcodes[pc->opcode] = Op_ceil_32;     break;
                    case WasmOp_f32_floor:         opcodes[pc->opcode] = Op_floor_32;    break;
                    case WasmOp_f32_trunc:         opcodes[pc->opcode] = Op_trunc_32;    break;
                    case WasmOp_f32_nearest:       opcodes[pc->opcode] = Op_nearest_32;  break;
                    case WasmOp_f32_sqrt:          opcodes[pc->opcode] = Op_sqrt_32;     break;
                    case WasmOp_f32_add:           opcodes[pc->opcode] = Op_fadd_32;     break;
                    case WasmOp_f32_sub:           opcodes[pc->opcode] = Op_fsub_32;     break;
                    case WasmOp_f32_mul:           opcodes[pc->opcode] = Op_fmul_32;     break;
                    case WasmOp_f32_div:           opcodes[pc->opcode] = Op_fdiv_32;     break;
                    case WasmOp_f32_min:           opcodes[pc->opcode] = Op_fmin_32;     break;
                    case WasmOp_f32_max:           opcodes[pc->opcode] = Op_fmax_32;     break;
                    case WasmOp_f32_copysign:      opcodes[pc->opcode] = Op_copysign_32; break;
                    case WasmOp_f64_abs:           opcodes[pc->opcode] = Op_fabs_64;     break;
                    case WasmOp_f64_neg:           opcodes[pc->opcode] = Op_fneg_64;     break;
                    case WasmOp_f64_ceil:          opcodes[pc->opcode] = Op_ceil_64;     break;
                    case WasmOp_f64_floor:         opcodes[pc->opcode] = Op_floor_64;    break;
                    case WasmOp_f64_trunc:         opcodes[pc->opcode] = Op_trunc_64;    break;
                    case WasmOp_f64_nearest:       opcodes[pc->opcode] = Op_nearest_64;  break;
                    case WasmOp_f64_sqrt:          opcodes[pc->opcode] = Op_sqrt_64;     break;
                    case WasmOp_f64_add:           opcodes[pc->opcode] = Op_fadd_64;     break;
                    case WasmOp_f64_sub:           opcodes[pc->opcode] = Op_fsub_64;     break;
                    case WasmOp_f64_mul:           opcodes[pc->opcode] = Op_fmul_64;     break;
                    case WasmOp_f64_div:           opcodes[pc->opcode] = Op_fdiv_64;     break;
                    case WasmOp_f64_min:           opcodes[pc->opcode] = Op_fmin_64;     break;
                    case WasmOp_f64_max:           opcodes[pc->opcode] = Op_fmax_64;     break;
                    case WasmOp_f64_copysign:      opcodes[pc->opcode] = Op_copysign_64; break;
                    case WasmOp_i32_wrap_i64:      opcodes[pc->opcode] = Op_wrap_32_64;  break;
                    case WasmOp_i32_trunc_f32_s:   opcodes[pc->opcode] = Op_ftos_32_32;  break;
                    case WasmOp_i32_trunc_f32_u:   opcodes[pc->opcode] = Op_ftou_32_32;  break;
                    case WasmOp_i32_trunc_f64_s:   opcodes[pc->opcode] = Op_ftos_32_64;  break;
                    case WasmOp_i32_trunc_f64_u:   opcodes[pc->opcode] = Op_ftou_32_64;  break;
                    case WasmOp_i64_extend_i32_s:  opcodes[pc->opcode] = Op_sext_64_32;  break;
                    case WasmOp_i64_extend_i32_u:  opcodes[pc->opcode] = Op_zext_64_32;  break;
                    case WasmOp_i64_trunc_f32_s:   opcodes[pc->opcode] = Op_ftos_64_32;  break;
                    case WasmOp_i64_trunc_f32_u:   opcodes[pc->opcode] = Op_ftou_64_32;  break;
                    case WasmOp_i64_trunc_f64_s:   opcodes[pc->opcode] = Op_ftos_64_64;  break;
                    case WasmOp_i64_trunc_f64_u:   opcodes[pc->opcode] = Op_ftou_64_64;  break;
                    case WasmOp_f32_convert_i32_s: opcodes[pc->opcode] = Op_stof_32_32;  break;
                    case WasmOp_f32_convert_i32_u: opcodes[pc->opcode] = Op_utof_32_32;  break;
                    case WasmOp_f32_convert_i64_s: opcodes[pc->opcode] = Op_stof_32_64;  break;
                    case WasmOp_f32_convert_i64_u: opcodes[pc->opcode] = Op_utof_32_64;  break;
                    case WasmOp_f32_demote_f64:    opcodes[pc->opcode] = Op_ftof_32_64;  break;
                    case WasmOp_f64_convert_i32_s: opcodes[pc->opcode] = Op_stof_64_32;  break;
                    case WasmOp_f64_convert_i32_u: opcodes[pc->opcode] = Op_utof_64_32;  break;
                    case WasmOp_f64_convert_i64_s: opcodes[pc->opcode] = Op_stof_64_64;  break;
                    case WasmOp_f64_convert_i64_u: opcodes[pc->opcode] = Op_utof_64_64;  break;
                    case WasmOp_f64_promote_f32:   opcodes[pc->opcode] = Op_ftof_64_32;  break;
                    case WasmOp_i32_extend8_s:     opcodes[pc->opcode] = Op_sext8_32;    break;
                    case WasmOp_i32_extend16_s:    opcodes[pc->opcode] = Op_sext16_32;   break;
                    case WasmOp_i64_extend8_s:     opcodes[pc->opcode] = Op_sext8_64;    break;
                    case WasmOp_i64_extend16_s:    opcodes[pc->opcode] = Op_sext16_64;   break;
                    case WasmOp_i64_extend32_s:    opcodes[pc->opcode] = Op_sext32_64;   break;
                    default: panic("unexpected opcode");
                }
                pc->opcode += 1;
            }
            break;

            case WasmOp_prefixed:
            switch (prefixed_opcode) {
                case WasmPrefixedOp_memory_copy:
                if (mod_ptr[*code_i + 0] != 0 || mod_ptr[*code_i + 1] != 0)
                    panic("unexpected memory index");
                *code_i += 2;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_memcpy;
                    pc->opcode += 1;
                }
                break;

                case WasmPrefixedOp_memory_fill:
                if (mod_ptr[*code_i] != 0) panic("unexpected memory index");
                *code_i += 1;
                if (unreachable_depth == 0) {
                    opcodes[pc->opcode] = Op_memset;
                    pc->opcode += 1;
                }
                break;

                default: panic("unexpected opcode");
            }
            break;
        }
        switch (opcode) {
            default:             state = State_default;  break;
            case WasmOp_i32_eqz: state = State_bool_not; break;
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
    vm->stack[vm->stack_top + 0] = value;
    vm->stack_top += 1;
}

static void vm_push_i32(struct VirtualMachine *vm, int32_t value) {
    vm_push_u32(vm, (uint32_t)value);
}

static void vm_push_u64(struct VirtualMachine *vm, uint64_t value) {
    vm->stack[vm->stack_top + 0] = (uint32_t)(value >> 0);
    vm->stack[vm->stack_top + 1] = (uint32_t)(value >> 32);
    vm->stack_top += 2;
}

static void vm_push_i64(struct VirtualMachine *vm, int64_t value) {
    vm_push_u64(vm, (uint64_t)value);
}

static void vm_push_f32(struct VirtualMachine *vm, float value) {
    uint32_t integer;
    memcpy(&integer, &value, sizeof(integer));
    vm_push_u32(vm, integer);
}

static void vm_push_f64(struct VirtualMachine *vm, double value) {
    uint64_t integer;
    memcpy(&integer, &value, sizeof(integer));
    vm_push_u64(vm, integer);
}

static uint32_t vm_pop_u32(struct VirtualMachine *vm) {
    vm->stack_top -= 1;
    return vm->stack[vm->stack_top + 0];
}

static int32_t vm_pop_i32(struct VirtualMachine *vm) {
    return (int32_t)vm_pop_u32(vm);
}

static uint64_t vm_pop_u64(struct VirtualMachine *vm) {
    vm->stack_top -= 2;
    return vm->stack[vm->stack_top + 0] | (uint64_t)vm->stack[vm->stack_top + 1] << 32;
}

static int64_t vm_pop_i64(struct VirtualMachine *vm) {
    return (int64_t)vm_pop_u64(vm);
}

static float vm_pop_f32(struct VirtualMachine *vm) {
    uint32_t integer = vm_pop_u32(vm);
    float result;
    memcpy(&result, &integer, sizeof(result));
    return result;
}

static double vm_pop_f64(struct VirtualMachine *vm) {
    uint64_t integer = vm_pop_u64(vm);
    double result;
    memcpy(&result, &integer, sizeof(result));
    return result;
}

static void vm_callImport(struct VirtualMachine *vm, const struct Import *import) {
    switch (import->mod) {
        case ImpMod_wasi_snapshot_preview1: switch (import->name) {
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

static void vm_call(struct VirtualMachine *vm, const struct Function *func) {
    //struct TypeInfo *type_info = &vm->types[func->type_idx];
    //fprintf(stderr, "enter fn_id: %u, param_count: %u, result_count: %u, locals_size: %u\n",
    //    func->id, type_info->param_count, type_info->result_count, func->locals_size);

    // Push zeroed locals to stack
    memset(&vm->stack[vm->stack_top], 0, func->locals_size * sizeof(uint32_t));
    vm->stack_top += func->locals_size;

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
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 0];
    uint32_t frame_size = vm->operands[vm->pc.operand + 1];

    vm->stack_top -= stack_adjust;
    vm->pc.operand = vm_pop_u32(vm);
    vm->pc.opcode = vm_pop_u32(vm);

    vm->stack_top -= frame_size;
}

static void vm_return_u32(struct VirtualMachine *vm) {
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 0];
    uint32_t frame_size = vm->operands[vm->pc.operand + 1];

    uint32_t result = vm_pop_u32(vm);

    vm->stack_top -= stack_adjust;
    vm->pc.operand = vm_pop_u32(vm);
    vm->pc.opcode = vm_pop_u32(vm);

    vm->stack_top -= frame_size;
    vm_push_u32(vm, result);
}

static void vm_return_u64(struct VirtualMachine *vm) {
    uint32_t stack_adjust = vm->operands[vm->pc.operand + 0];
    uint32_t frame_size = vm->operands[vm->pc.operand + 1];

    uint64_t result = vm_pop_u64(vm);

    vm->stack_top -= stack_adjust;
    vm->pc.operand = vm_pop_u32(vm);
    vm->pc.opcode = vm_pop_u32(vm);

    vm->stack_top -= frame_size;
    vm_push_u64(vm, result);
}

static void vm_run(struct VirtualMachine *vm) {
    uint8_t *opcodes = vm->opcodes;
    uint32_t *operands = vm->operands;
    struct ProgramCounter *pc = &vm->pc;
    uint32_t global_0 = vm->globals[0];
    for (;;) {
        enum Op op = opcodes[pc->opcode];
        //fprintf(stderr, "stack[%u:%u]=%x:%x pc=%x:%x op=%u\n",
        //    vm->stack_top - 2, vm->stack_top - 1,
        //    vm->stack[vm->stack_top - 2], vm->stack[vm->stack_top - 1],
        //    pc->opcode, pc->operand, op);
        pc->opcode += 1;
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
            case Op_br_nez_void:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_void(vm);
                } else {
                    pc->operand += 3;
                }
                break;
            case Op_br_nez_32:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_u32(vm);
                } else {
                    pc->operand += 3;
                }
                break;
            case Op_br_nez_64:
                if (vm_pop_u32(vm) != 0) {
                    vm_br_u64(vm);
                } else {
                    pc->operand += 3;
                }
                break;
            case Op_br_eqz_void:
                if (vm_pop_u32(vm) == 0) {
                    vm_br_void(vm);
                } else {
                    pc->operand += 3;
                }
                break;
            case Op_br_eqz_32:
                if (vm_pop_u32(vm) == 0) {
                    vm_br_u32(vm);
                } else {
                    pc->operand += 3;
                }
                break;
            case Op_br_eqz_64:
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
            case Op_call_import:
                {
                    uint8_t import_idx = opcodes[pc->opcode];
                    pc->opcode += 1;
                    vm_callImport(vm, &vm->imports[import_idx]);
                }
                break;
            case Op_call_func:
                {
                    uint32_t func_idx = operands[pc->operand];
                    pc->operand += 1;
                    vm_call(vm, &vm->functions[func_idx]);
                }
                break;
            case Op_call_indirect:
                {
                    uint32_t fn_id = vm->table[vm_pop_u32(vm)];
                    if (fn_id < vm->imports_len)
                        vm_callImport(vm, &vm->imports[fn_id]);
                    else
                        vm_call(vm, &vm->functions[fn_id - vm->imports_len]);
                }
                break;

            case Op_drop_32:
                vm->stack_top -= 1;
                break;
            case Op_drop_64:
                vm->stack_top -= 2;
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
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    vm_push_u32(vm, *local);
                }
                break;
            case Op_local_get_64:
                {
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    vm_push_u64(vm, local[0] | (uint64_t)local[1] << 32);
                }
                break;
            case Op_local_set_32:
                {
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    *local = vm_pop_u32(vm);
                }
                break;
            case Op_local_set_64:
                {
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    uint64_t value = vm_pop_u64(vm);
                    local[0] = (uint32_t)(value >> 0);
                    local[1] = (uint32_t)(value >> 32);
                }
                break;
            case Op_local_tee_32:
                {
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    *local = vm->stack[vm->stack_top - 1];
                }
                break;
            case Op_local_tee_64:
                {
                    uint32_t *local = &vm->stack[vm->stack_top - operands[pc->operand]];
                    pc->operand += 1;
                    local[0] = vm->stack[vm->stack_top - 2];
                    local[1] = vm->stack[vm->stack_top - 1];
                }
                break;

            case Op_global_get_0_32:
                vm_push_u32(vm, global_0);
                break;
            case Op_global_get_32:
                {
                    uint32_t idx = operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u32(vm, vm->globals[idx]);
                }
                break;
            case Op_global_set_0_32:
                global_0 = vm_pop_u32(vm);
                break;
            case Op_global_set_32:
                {
                    uint32_t idx = operands[pc->operand];
                    pc->operand += 1;
                    vm->globals[idx] = vm_pop_u32(vm);
                }
                break;

            case Op_load_0_8:
                {
                    uint32_t address = vm_pop_u32(vm);
                    vm_push_u32(vm, (uint8_t)vm->memory[address]);
                }
                break;
            case Op_load_8:
                {
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u32(vm, (uint8_t)vm->memory[address]);
                }
                break;
            case Op_load_0_16:
                {
                    uint32_t address = vm_pop_u32(vm);
                    vm_push_u32(vm, read_u16_le(&vm->memory[address]));
                }
                break;
            case Op_load_16:
                {
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u32(vm, read_u16_le(&vm->memory[address]));
                }
                break;
            case Op_load_0_32:
                {
                    uint32_t address = vm_pop_u32(vm);
                    vm_push_u32(vm, read_u32_le(&vm->memory[address]));
                }
                break;
            case Op_load_32:
                {
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u32(vm, read_u32_le(&vm->memory[address]));
                }
                break;
            case Op_load_0_64:
                {
                    uint32_t address = vm_pop_u32(vm);
                    vm_push_u64(vm, read_u64_le(&vm->memory[address]));
                }
                break;
            case Op_load_64:
                {
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    vm_push_u64(vm, read_u64_le(&vm->memory[address]));
                }
                break;
            case Op_store_0_8:
                {
                    uint8_t value = (uint8_t)vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm);
                    vm->memory[address] = value;
                }
                break;
            case Op_store_8:
                {
                    uint8_t value = (uint8_t)vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    vm->memory[address] = value;
                }
                break;
            case Op_store_0_16:
                {
                    uint16_t value = (uint16_t)vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm);
                    write_u16_le(&vm->memory[address], value);
                }
                break;
            case Op_store_16:
                {
                    uint16_t value = (uint16_t)vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    write_u16_le(&vm->memory[address], value);
                }
                break;
            case Op_store_0_32:
                {
                    uint32_t value = vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm);
                    write_u32_le(&vm->memory[address], value);
                }
                break;
            case Op_store_32:
                {
                    uint32_t value = vm_pop_u32(vm);
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    write_u32_le(&vm->memory[address], value);
                }
                break;
            case Op_store_0_64:
                {
                    uint64_t value = vm_pop_u64(vm);
                    uint32_t address = vm_pop_u32(vm);
                    write_u64_le(&vm->memory[address], value);
                }
                break;
            case Op_store_64:
                {
                    uint64_t value = vm_pop_u64(vm);
                    uint32_t address = vm_pop_u32(vm) + operands[pc->operand];
                    pc->operand += 1;
                    write_u64_le(&vm->memory[address], value);
                }
                break;
            case Op_mem_size:
                vm_push_u32(vm, vm->memory_len / wasm_page_size);
                break;
            case Op_mem_grow:
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

            case Op_const_0_32:
                vm_push_i32(vm, 0);
                break;
            case Op_const_0_64:
                vm_push_i64(vm, 0);
                break;
            case Op_const_1_32:
                vm_push_i32(vm, 1);
                break;
            case Op_const_1_64:
                vm_push_i64(vm, 1);
                break;
            case Op_const_32:
                {
                    uint32_t value = operands[pc->operand];
                    pc->operand += 1;
                    vm_push_i32(vm, value);
                }
                break;
            case Op_const_64:
                {
                    uint64_t value = ((uint64_t)operands[pc->operand]) |
                        (((uint64_t)operands[pc->operand + 1]) << 32);
                    pc->operand += 2;
                    vm_push_i64(vm, value);
                }
                break;
            case Op_const_umax_32:
                vm_push_i32(vm, -1);
                break;
            case Op_const_umax_64:
                vm_push_i64(vm, -1);
                break;

            case Op_eqz_32:
                {
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs == 0);
                }
                break;
            case Op_eq_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs == rhs);
                }
                break;
            case Op_ne_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs != rhs);
                }
                break;
            case Op_slt_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_u32(vm, lhs < rhs);
                }
                break;
            case Op_ult_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs < rhs);
                }
                break;
            case Op_sgt_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_ugt_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_sle_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_ule_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_sge_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;
            case Op_uge_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;

            case Op_eqz_64:
                {
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs == 0);
                }
                break;
            case Op_eq_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs == rhs);
                }
                break;
            case Op_ne_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs != rhs);
                }
                break;
            case Op_slt_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_u32(vm, lhs < rhs);
                }
                break;
            case Op_ult_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs < rhs);
                }
                break;
            case Op_sgt_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_ugt_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_sle_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_ule_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_sge_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;
            case Op_uge_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;

            case Op_feq_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs == rhs);
                }
                break;
            case Op_fne_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs != rhs);
                }
                break;
            case Op_flt_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs < rhs);
                }
                break;
            case Op_fgt_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_fle_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_fge_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;

            case Op_feq_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs == rhs);
                }
                break;
            case Op_fne_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs != rhs);
                }
                break;
            case Op_flt_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_fgt_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs > rhs);
                }
                break;
            case Op_fle_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs <= rhs);
                }
                break;
            case Op_fge_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_u32(vm, lhs >= rhs);
                }
                break;

            case Op_clz_32:
                {
                    uint32_t operand = vm_pop_u32(vm);
                    uint32_t result = (operand == 0) ? 32 : __builtin_clz(operand);
                    vm_push_u32(vm, result);
                }
                break;
            case Op_ctz_32:
                {
                    uint32_t operand = vm_pop_u32(vm);
                    uint32_t result = (operand == 0) ? 32 : __builtin_ctz(operand);
                    vm_push_u32(vm, result);
                }
                break;
            case Op_popcnt_32:
                {
                    uint32_t operand = vm_pop_u32(vm);
                    uint32_t result = __builtin_popcount(operand);
                    vm_push_u32(vm, result);
                }
                break;
            case Op_add_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs + rhs);
                }
                break;
            case Op_sub_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs - rhs);
                }
                break;
            case Op_mul_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs * rhs);
                }
                break;
            case Op_sdiv_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_i32(vm, lhs / rhs);
                }
                break;
            case Op_udiv_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs / rhs);
                }
                break;
            case Op_srem_32:
                {
                    int32_t rhs = vm_pop_i32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_i32(vm, lhs % rhs);
                }
                break;
            case Op_urem_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs % rhs);
                }
                break;
            case Op_and_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs & rhs);
                }
                break;
            case Op_or_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs | rhs);
                }
                break;
            case Op_xor_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs ^ rhs);
                }
                break;
            case Op_shl_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs << (rhs & 0x1f));
                }
                break;
            case Op_ashr_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    int32_t lhs = vm_pop_i32(vm);
                    vm_push_i32(vm, lhs >> (rhs & 0x1f));
                }
                break;
            case Op_lshr_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, lhs >> (rhs & 0x1f));
                }
                break;
            case Op_rol_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, rotl32(lhs, rhs));
                }
                break;
            case Op_ror_32:
                {
                    uint32_t rhs = vm_pop_u32(vm);
                    uint32_t lhs = vm_pop_u32(vm);
                    vm_push_u32(vm, rotr32(lhs, rhs));
                }
                break;

            case Op_clz_64:
                {
                    uint64_t operand = vm_pop_u64(vm);
                    uint64_t result = (operand == 0) ? 64 : __builtin_clzll(operand);
                    vm_push_u64(vm, result);
                }
                break;
            case Op_ctz_64:
                {
                    uint64_t operand = vm_pop_u64(vm);
                    uint64_t result = (operand == 0) ? 64 : __builtin_ctzll(operand);
                    vm_push_u64(vm, result);
                }
                break;
            case Op_popcnt_64:
                {
                    uint64_t operand = vm_pop_u64(vm);
                    uint64_t result = __builtin_popcountll(operand);
                    vm_push_u64(vm, result);
                }
                break;
            case Op_add_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs + rhs);
                }
                break;
            case Op_sub_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs - rhs);
                }
                break;
            case Op_mul_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs * rhs);
                }
                break;
            case Op_sdiv_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_i64(vm, lhs / rhs);
                }
                break;
            case Op_udiv_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs / rhs);
                }
                break;
            case Op_srem_64:
                {
                    int64_t rhs = vm_pop_i64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_i64(vm, lhs % rhs);
                }
                break;
            case Op_urem_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs % rhs);
                }
                break;
            case Op_and_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs & rhs);
                }
                break;
            case Op_or_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs | rhs);
                }
                break;
            case Op_xor_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs ^ rhs);
                }
                break;
            case Op_shl_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs << (rhs & 0x3f));
                }
                break;
            case Op_ashr_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    int64_t lhs = vm_pop_i64(vm);
                    vm_push_i64(vm, lhs >> (rhs & 0x3f));
                }
                break;
            case Op_lshr_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, lhs >> (rhs & 0x3f));
                }
                break;
            case Op_rol_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, rotl64(lhs, rhs));
                }
                break;
            case Op_ror_64:
                {
                    uint64_t rhs = vm_pop_u64(vm);
                    uint64_t lhs = vm_pop_u64(vm);
                    vm_push_u64(vm, rotr64(lhs, rhs));
                }
                break;

            case Op_fabs_32:
                vm_push_f32(vm, fabsf(vm_pop_f32(vm)));
                break;
            case Op_fneg_32:
                vm_push_f32(vm, -vm_pop_f32(vm));
                break;
            case Op_ceil_32:
                vm_push_f32(vm, ceilf(vm_pop_f32(vm)));
                break;
            case Op_floor_32:
                vm_push_f32(vm, floorf(vm_pop_f32(vm)));
                break;
            case Op_trunc_32:
                vm_push_f32(vm, truncf(vm_pop_f32(vm)));
                break;
            case Op_nearest_32:
                vm_push_f32(vm, roundf(vm_pop_f32(vm)));
                break;
            case Op_sqrt_32:
                vm_push_f32(vm, sqrtf(vm_pop_f32(vm)));
                break;
            case Op_fadd_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, lhs + rhs);
                }
                break;
            case Op_fsub_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, lhs - rhs);
                }
                break;
            case Op_fmul_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, lhs * rhs);
                }
                break;
            case Op_fdiv_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, lhs / rhs);
                }
                break;
            case Op_fmin_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, fminf(lhs, rhs));
                }
                break;
            case Op_fmax_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, fmaxf(lhs, rhs));
                }
                break;
            case Op_copysign_32:
                {
                    float rhs = vm_pop_f32(vm);
                    float lhs = vm_pop_f32(vm);
                    vm_push_f32(vm, copysignf(lhs, rhs));
                }
                break;

            case Op_fabs_64:
                vm_push_f64(vm, fabs(vm_pop_f64(vm)));
                break;
            case Op_fneg_64:
                vm_push_f64(vm, -vm_pop_f64(vm));
                break;
            case Op_ceil_64:
                vm_push_f64(vm, ceil(vm_pop_f64(vm)));
                break;
            case Op_floor_64:
                vm_push_f64(vm, floor(vm_pop_f64(vm)));
                break;
            case Op_trunc_64:
                vm_push_f64(vm, trunc(vm_pop_f64(vm)));
                break;
            case Op_nearest_64:
                vm_push_f64(vm, round(vm_pop_f64(vm)));
                break;
            case Op_sqrt_64:
                vm_push_f64(vm, sqrt(vm_pop_f64(vm)));
                break;
            case Op_fadd_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, lhs + rhs);
                }
                break;
            case Op_fsub_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, lhs - rhs);
                }
                break;
            case Op_fmul_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, lhs * rhs);
                }
                break;
            case Op_fdiv_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, lhs / rhs);
                }
                break;
            case Op_fmin_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, fmin(lhs, rhs));
                }
                break;
            case Op_fmax_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, fmax(lhs, rhs));
                }
                break;
            case Op_copysign_64:
                {
                    double rhs = vm_pop_f64(vm);
                    double lhs = vm_pop_f64(vm);
                    vm_push_f64(vm, copysign(lhs, rhs));
                }
                break;

            case Op_ftos_32_32: vm_push_f32(vm,    (float)vm_pop_i32(vm)); break;
            case Op_ftou_32_32: vm_push_f32(vm,    (float)vm_pop_u32(vm)); break;
            case Op_ftos_32_64: vm_push_f32(vm,    (float)vm_pop_i64(vm)); break;
            case Op_ftou_32_64: vm_push_f32(vm,    (float)vm_pop_u64(vm)); break;
            case Op_sext_64_32: vm_push_i64(vm,           vm_pop_i32(vm)); break;
            case Op_ftos_64_32: vm_push_i64(vm,  (int64_t)vm_pop_f32(vm)); break;
            case Op_ftou_64_32: vm_push_u64(vm, (uint64_t)vm_pop_f32(vm)); break;
            case Op_ftos_64_64: vm_push_i64(vm,  (int64_t)vm_pop_f64(vm)); break;
            case Op_ftou_64_64: vm_push_u64(vm, (uint64_t)vm_pop_f64(vm)); break;
            case Op_stof_32_32: vm_push_f32(vm,    (float)vm_pop_i32(vm)); break;
            case Op_utof_32_32: vm_push_f32(vm,    (float)vm_pop_u32(vm)); break;
            case Op_stof_32_64: vm_push_f32(vm,    (float)vm_pop_i64(vm)); break;
            case Op_utof_32_64: vm_push_f32(vm,    (float)vm_pop_u64(vm)); break;
            case Op_ftof_32_64: vm_push_f32(vm,    (float)vm_pop_f64(vm)); break;
            case Op_stof_64_32: vm_push_f64(vm,   (double)vm_pop_i32(vm)); break;
            case Op_utof_64_32: vm_push_f64(vm,   (double)vm_pop_u32(vm)); break;
            case Op_stof_64_64: vm_push_f64(vm,   (double)vm_pop_i64(vm)); break;
            case Op_utof_64_64: vm_push_f64(vm,   (double)vm_pop_u64(vm)); break;
            case Op_ftof_64_32: vm_push_f64(vm,   (double)vm_pop_f32(vm)); break;
            case Op_sext8_32:   vm_push_i32(vm,   (int8_t)vm_pop_i32(vm)); break;
            case Op_sext16_32:  vm_push_i32(vm,  (int16_t)vm_pop_i32(vm)); break;
            case Op_sext8_64:   vm_push_i64(vm,   (int8_t)vm_pop_i64(vm)); break;
            case Op_sext16_64:  vm_push_i64(vm,  (int16_t)vm_pop_i64(vm)); break;
            case Op_sext32_64:  vm_push_i64(vm,  (int32_t)vm_pop_i64(vm)); break;

            case Op_memcpy:
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
            case Op_memset:
                {
                    uint32_t n = vm_pop_u32(vm);
                    uint8_t value = (uint8_t)vm_pop_u32(vm);
                    uint32_t dest = vm_pop_u32(vm);
                    assert(dest + n <= vm->memory_len);
                    memset(vm->memory + dest, value, n);
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

    for (; argv[argv_i]; argv_i += 1) {
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
            func->id = imports_len + func_i;
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
    vm.stack = arena_alloc(sizeof(uint32_t) * 10000000),
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
        struct StackInfo stack;
        for (uint32_t func_i = 0; func_i < functions_len; func_i += 1) {
            struct Function *func = &functions[func_i];
            uint32_t size = read32_uleb128(mod_ptr, &code_i);
            uint32_t code_begin = code_i;

            stack.top_index = 0;
            stack.top_offset = 0;
            struct TypeInfo *type_info = &vm.types[func->type_idx];
            for (uint32_t param_i = 0; param_i < type_info->param_count; param_i += 1)
                si_push(&stack, bs_isSet(&type_info->param_types, param_i));
            uint32_t params_size = stack.top_offset;

            for (uint32_t local_sets_count = read32_uleb128(mod_ptr, &code_i);
                 local_sets_count > 0; local_sets_count -= 1)
            {
                uint32_t local_set_count = read32_uleb128(mod_ptr, &code_i);
                enum StackType local_type;
                switch (read64_ileb128(mod_ptr, &code_i)) {
                    case -1: case -3: local_type = ST_32; break;
                    case -2: case -4: local_type = ST_64; break;
                    default: panic("unexpected local type");
                }
                for (; local_set_count > 0; local_set_count -= 1)
                    si_push(&stack, local_type);
            }
            func->locals_size = stack.top_offset - params_size;

            func->entry_pc = pc;
            //fprintf(stderr, "decoding func id %u with pc %u:%u\n", func->id, pc.opcode, pc.operand);
            vm_decodeCode(&vm, type_info, &code_i, &pc, &stack);
            if (code_i != code_begin + size) panic("bad code size");
        }
        //fprintf(stderr, "%u opcodes\n%u operands\n", pc.opcode, pc.operand);
    }

    vm_call(&vm, &vm.functions[start_fn_idx - imports_len]);
    vm_run(&vm);

    return 0;
}
