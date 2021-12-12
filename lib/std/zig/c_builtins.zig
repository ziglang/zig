const std = @import("std");

pub inline fn __builtin_bswap16(val: u16) u16 {
    return @byteSwap(u16, val);
}
pub inline fn __builtin_bswap32(val: u32) u32 {
    return @byteSwap(u32, val);
}
pub inline fn __builtin_bswap64(val: u64) u64 {
    return @byteSwap(u64, val);
}

pub inline fn __builtin_signbit(val: f64) c_int {
    return @boolToInt(std.math.signbit(val));
}
pub inline fn __builtin_signbitf(val: f32) c_int {
    return @boolToInt(std.math.signbit(val));
}

pub inline fn __builtin_popcount(val: c_uint) c_int {
    // popcount of a c_uint will never exceed the capacity of a c_int
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @popCount(c_uint, val)));
}
pub inline fn __builtin_ctz(val: c_uint) c_int {
    // Returns the number of trailing 0-bits in val, starting at the least significant bit position.
    // In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @ctz(c_uint, val)));
}
pub inline fn __builtin_clz(val: c_uint) c_int {
    // Returns the number of leading 0-bits in x, starting at the most significant bit position.
    // In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
    @setRuntimeSafety(false);
    return @bitCast(c_int, @as(c_uint, @clz(c_uint, val)));
}

pub inline fn __builtin_sqrt(val: f64) f64 {
    return @sqrt(val);
}
pub inline fn __builtin_sqrtf(val: f32) f32 {
    return @sqrt(val);
}

pub inline fn __builtin_sin(val: f64) f64 {
    return @sin(val);
}
pub inline fn __builtin_sinf(val: f32) f32 {
    return @sin(val);
}
pub inline fn __builtin_cos(val: f64) f64 {
    return @cos(val);
}
pub inline fn __builtin_cosf(val: f32) f32 {
    return @cos(val);
}

pub inline fn __builtin_exp(val: f64) f64 {
    return @exp(val);
}
pub inline fn __builtin_expf(val: f32) f32 {
    return @exp(val);
}
pub inline fn __builtin_exp2(val: f64) f64 {
    return @exp2(val);
}
pub inline fn __builtin_exp2f(val: f32) f32 {
    return @exp2(val);
}
pub inline fn __builtin_log(val: f64) f64 {
    return @log(val);
}
pub inline fn __builtin_logf(val: f32) f32 {
    return @log(val);
}
pub inline fn __builtin_log2(val: f64) f64 {
    return @log2(val);
}
pub inline fn __builtin_log2f(val: f32) f32 {
    return @log2(val);
}
pub inline fn __builtin_log10(val: f64) f64 {
    return @log10(val);
}
pub inline fn __builtin_log10f(val: f32) f32 {
    return @log10(val);
}

// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn __builtin_abs(val: c_int) c_int {
    return std.math.absInt(val) catch std.math.minInt(c_int);
}
pub inline fn __builtin_fabs(val: f64) f64 {
    return @fabs(val);
}
pub inline fn __builtin_fabsf(val: f32) f32 {
    return @fabs(val);
}

pub inline fn __builtin_floor(val: f64) f64 {
    return @floor(val);
}
pub inline fn __builtin_floorf(val: f32) f32 {
    return @floor(val);
}
pub inline fn __builtin_ceil(val: f64) f64 {
    return @ceil(val);
}
pub inline fn __builtin_ceilf(val: f32) f32 {
    return @ceil(val);
}
pub inline fn __builtin_trunc(val: f64) f64 {
    return @trunc(val);
}
pub inline fn __builtin_truncf(val: f32) f32 {
    return @trunc(val);
}
pub inline fn __builtin_round(val: f64) f64 {
    return @round(val);
}
pub inline fn __builtin_roundf(val: f32) f32 {
    return @round(val);
}

pub inline fn __builtin_strlen(s: [*c]const u8) usize {
    return std.mem.sliceTo(s, 0).len;
}
pub inline fn __builtin_strcmp(s1: [*c]const u8, s2: [*c]const u8) c_int {
    return @as(c_int, std.cstr.cmp(s1, s2));
}

pub inline fn __builtin_object_size(ptr: ?*const anyopaque, ty: c_int) usize {
    _ = ptr;
    // clang semantics match gcc's: https://gcc.gnu.org/onlinedocs/gcc/Object-Size-Checking.html
    // If it is not possible to determine which objects ptr points to at compile time,
    // __builtin_object_size should return (size_t) -1 for type 0 or 1 and (size_t) 0
    // for type 2 or 3.
    if (ty == 0 or ty == 1) return @bitCast(usize, -@as(isize, 1));
    if (ty == 2 or ty == 3) return 0;
    unreachable;
}

pub inline fn __builtin___memset_chk(
    dst: ?*anyopaque,
    val: c_int,
    len: usize,
    remaining: usize,
) ?*anyopaque {
    if (len > remaining) @panic("std.c.builtins.memset_chk called with len > remaining");
    return __builtin_memset(dst, val, len);
}

pub inline fn __builtin_memset(dst: ?*anyopaque, val: c_int, len: usize) ?*anyopaque {
    const dst_cast = @ptrCast([*c]u8, dst);
    @memset(dst_cast, @bitCast(u8, @truncate(i8, val)), len);
    return dst;
}

pub inline fn __builtin___memcpy_chk(
    noalias dst: ?*anyopaque,
    noalias src: ?*const anyopaque,
    len: usize,
    remaining: usize,
) ?*anyopaque {
    if (len > remaining) @panic("std.c.builtins.memcpy_chk called with len > remaining");
    return __builtin_memcpy(dst, src, len);
}

pub inline fn __builtin_memcpy(
    noalias dst: ?*anyopaque,
    noalias src: ?*const anyopaque,
    len: usize,
) ?*anyopaque {
    const dst_cast = @ptrCast([*c]u8, dst);
    const src_cast = @ptrCast([*c]const u8, src);

    @memcpy(dst_cast, src_cast, len);
    return dst;
}

/// The return value of __builtin_expect is `expr`. `c` is the expected value
/// of `expr` and is used as a hint to the compiler in C. Here it is unused.
pub inline fn __builtin_expect(expr: c_long, c: c_long) c_long {
    _ = c;
    return expr;
}

/// returns a quiet NaN. Quiet NaNs have many representations; tagp is used to select one in an
/// implementation-defined way.
/// This implementation is based on the description for __builtin_nan provided in the GCC docs at
/// https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html#index-_005f_005fbuiltin_005fnan
/// Comment is reproduced below:
/// Since ISO C99 defines this function in terms of strtod, which we do not implement, a description
/// of the parsing is in order.
/// The string is parsed as by strtol; that is, the base is recognized by leading ‘0’ or ‘0x’ prefixes.
/// The number parsed is placed in the significand such that the least significant bit of the number is
///    at the least significant bit of the significand.
/// The number is truncated to fit the significand field provided.
/// The significand is forced to be a quiet NaN.
///
/// If tagp contains any non-numeric characters, the function returns a NaN whose significand is zero.
/// If tagp is empty, the function returns a NaN whose significand is zero.
pub inline fn __builtin_nanf(tagp: []const u8) f32 {
    const parsed = std.fmt.parseUnsigned(c_ulong, tagp, 0) catch 0;
    const bits = @truncate(u23, parsed); // single-precision float trailing significand is 23 bits
    return @bitCast(f32, @as(u32, bits) | std.math.qnan_u32);
}

pub inline fn __builtin_huge_valf() f32 {
    return std.math.inf(f32);
}

pub inline fn __builtin_inff() f32 {
    return std.math.inf(f32);
}

pub inline fn __builtin_isnan(x: anytype) c_int {
    return @boolToInt(std.math.isNan(x));
}

pub inline fn __builtin_isinf(x: anytype) c_int {
    return @boolToInt(std.math.isInf(x));
}

/// Similar to isinf, except the return value is -1 for an argument of -Inf and 1 for an argument of +Inf.
pub inline fn __builtin_isinf_sign(x: anytype) c_int {
    if (!std.math.isInf(x)) return 0;
    return if (std.math.isPositiveInf(x)) 1 else -1;
}

// __builtin_alloca_with_align is not currently implemented.
// It is used in a run-translated-c test and a test-translate-c test to ensure that non-implemented
// builtins are correctly demoted. If you implement __builtin_alloca_with_align, please update the
// run-translated-c test and the test-translate-c test to use a different non-implemented builtin.
// pub fn __builtin_alloca_with_align(size: usize, alignment: usize) callconv(.Inline) *anyopaque {}
