const std = @import("std");

/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn abs(val: c_int) c_int {
    return if (val == std.math.minInt(c_int)) val else @intCast(@abs(val));
}

pub inline fn assume(cond: bool) void {
    if (!cond) unreachable;
}

pub inline fn bswap16(val: u16) u16 {
    return @byteSwap(val);
}

pub inline fn bswap32(val: u32) u32 {
    return @byteSwap(val);
}

pub inline fn bswap64(val: u64) u64 {
    return @byteSwap(val);
}

pub inline fn ceilf(val: f32) f32 {
    return @ceil(val);
}

pub inline fn ceil(val: f64) f64 {
    return @ceil(val);
}

/// Returns the number of leading 0-bits in x, starting at the most significant bit position.
/// In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
pub inline fn clz(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @clz(val))));
}

pub inline fn constant_p(expr: anytype) c_int {
    _ = expr;
    return @intFromBool(false);
}

pub inline fn cosf(val: f32) f32 {
    return @cos(val);
}

pub inline fn cos(val: f64) f64 {
    return @cos(val);
}

/// Returns the number of trailing 0-bits in val, starting at the least significant bit position.
/// In C if `val` is 0, the result is undefined; in zig it's the number of bits in a c_uint
pub inline fn ctz(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @ctz(val))));
}

pub inline fn exp2f(val: f32) f32 {
    return @exp2(val);
}

pub inline fn exp2(val: f64) f64 {
    return @exp2(val);
}

pub inline fn expf(val: f32) f32 {
    return @exp(val);
}

pub inline fn exp(val: f64) f64 {
    return @exp(val);
}

/// The return value of __builtin_expect is `expr`. `c` is the expected value
/// of `expr` and is used as a hint to the compiler in C. Here it is unused.
pub inline fn expect(expr: c_long, c: c_long) c_long {
    _ = c;
    return expr;
}

pub inline fn fabsf(val: f32) f32 {
    return @abs(val);
}

pub inline fn fabs(val: f64) f64 {
    return @abs(val);
}

pub inline fn floorf(val: f32) f32 {
    return @floor(val);
}

pub inline fn floor(val: f64) f64 {
    return @floor(val);
}

pub inline fn has_builtin(func: anytype) c_int {
    _ = func;
    return @intFromBool(true);
}

pub inline fn huge_valf() f32 {
    return std.math.inf(f32);
}

pub inline fn inff() f32 {
    return std.math.inf(f32);
}

/// Similar to isinf, except the return value is -1 for an argument of -Inf and 1 for an argument of +Inf.
pub inline fn isinf_sign(x: anytype) c_int {
    if (!std.math.isInf(x)) return 0;
    return if (std.math.isPositiveInf(x)) 1 else -1;
}

pub inline fn isinf(x: anytype) c_int {
    return @intFromBool(std.math.isInf(x));
}

pub inline fn isnan(x: anytype) c_int {
    return @intFromBool(std.math.isNan(x));
}

/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn labs(val: c_long) c_long {
    return if (val == std.math.minInt(c_long)) val else @intCast(@abs(val));
}

/// Standard C Library bug: The absolute value of the most negative integer remains negative.
pub inline fn llabs(val: c_longlong) c_longlong {
    return if (val == std.math.minInt(c_longlong)) val else @intCast(@abs(val));
}

pub inline fn log10f(val: f32) f32 {
    return @log10(val);
}

pub inline fn log10(val: f64) f64 {
    return @log10(val);
}

pub inline fn log2f(val: f32) f32 {
    return @log2(val);
}

pub inline fn log2(val: f64) f64 {
    return @log2(val);
}

pub inline fn logf(val: f32) f32 {
    return @log(val);
}

pub inline fn log(val: f64) f64 {
    return @log(val);
}

pub inline fn memcpy_chk(
    noalias dst: ?*anyopaque,
    noalias src: ?*const anyopaque,
    len: usize,
    remaining: usize,
) ?*anyopaque {
    if (len > remaining) @panic("__builtin___memcpy_chk called with len > remaining");
    if (len > 0) @memcpy(
        @as([*]u8, @ptrCast(dst.?))[0..len],
        @as([*]const u8, @ptrCast(src.?)),
    );
    return dst;
}

pub inline fn memcpy(
    noalias dst: ?*anyopaque,
    noalias src: ?*const anyopaque,
    len: usize,
) ?*anyopaque {
    if (len > 0) @memcpy(
        @as([*]u8, @ptrCast(dst.?))[0..len],
        @as([*]const u8, @ptrCast(src.?)),
    );
    return dst;
}

pub inline fn memset_chk(
    dst: ?*anyopaque,
    val: c_int,
    len: usize,
    remaining: usize,
) ?*anyopaque {
    if (len > remaining) @panic("__builtin___memset_chk called with len > remaining");
    const dst_cast = @as([*c]u8, @ptrCast(dst));
    @memset(dst_cast[0..len], @as(u8, @bitCast(@as(i8, @truncate(val)))));
    return dst;
}

pub inline fn memset(dst: ?*anyopaque, val: c_int, len: usize) ?*anyopaque {
    const dst_cast = @as([*c]u8, @ptrCast(dst));
    @memset(dst_cast[0..len], @as(u8, @bitCast(@as(i8, @truncate(val)))));
    return dst;
}

pub fn mul_overflow(a: anytype, b: anytype, result: *@TypeOf(a, b)) c_int {
    const res = @mulWithOverflow(a, b);
    result.* = res[0];
    return res[1];
}

/// returns a quiet NaN. Quiet NaNs have many representations; tagp is used to select one in an
/// implementation-defined way.
/// This implementation is based on the description for nan provided in the GCC docs at
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
pub inline fn nanf(tagp: []const u8) f32 {
    const parsed = std.fmt.parseUnsigned(c_ulong, tagp, 0) catch 0;
    const bits: u23 = @truncate(parsed); // single-precision float trailing significand is 23 bits
    return @bitCast(@as(u32, bits) | @as(u32, @bitCast(std.math.nan(f32))));
}

pub inline fn object_size(ptr: ?*const anyopaque, ty: c_int) usize {
    _ = ptr;
    // clang semantics match gcc's: https://gcc.gnu.org/onlinedocs/gcc/Object-Size-Checking.html
    // If it is not possible to determine which objects ptr points to at compile time,
    // object_size should return (size_t) -1 for type 0 or 1 and (size_t) 0
    // for type 2 or 3.
    if (ty == 0 or ty == 1) return @as(usize, @bitCast(-@as(isize, 1)));
    if (ty == 2 or ty == 3) return 0;
    unreachable;
}

/// popcount of a c_uint will never exceed the capacity of a c_int
pub inline fn popcount(val: c_uint) c_int {
    @setRuntimeSafety(false);
    return @as(c_int, @bitCast(@as(c_uint, @popCount(val))));
}

pub inline fn roundf(val: f32) f32 {
    return @round(val);
}

pub inline fn round(val: f64) f64 {
    return @round(val);
}

pub inline fn signbitf(val: f32) c_int {
    return @intFromBool(std.math.signbit(val));
}

pub inline fn signbit(val: f64) c_int {
    return @intFromBool(std.math.signbit(val));
}

pub inline fn sinf(val: f32) f32 {
    return @sin(val);
}

pub inline fn sin(val: f64) f64 {
    return @sin(val);
}

pub inline fn sqrtf(val: f32) f32 {
    return @sqrt(val);
}

pub inline fn sqrt(val: f64) f64 {
    return @sqrt(val);
}

pub inline fn strcmp(s1: [*c]const u8, s2: [*c]const u8) c_int {
    return switch (std.mem.orderZ(u8, s1, s2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

pub inline fn strlen(s: [*c]const u8) usize {
    return std.mem.sliceTo(s, 0).len;
}

pub inline fn truncf(val: f32) f32 {
    return @trunc(val);
}

pub inline fn trunc(val: f64) f64 {
    return @trunc(val);
}

pub inline fn @"unreachable"() noreturn {
    unreachable;
}
