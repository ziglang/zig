// ARM specific builtins
const builtin = @import("builtin");
const is_test = builtin.is_test;

const __divmodsi4 = @import("int.zig").__divmodsi4;
const __udivmodsi4 = @import("int.zig").__udivmodsi4;
const __divmoddi4 = @import("int.zig").__divmoddi4;
const __udivmoddi4 = @import("int.zig").__udivmoddi4;

extern fn memset(dest: ?[*]u8, c: u8, n: usize) ?[*]u8;
extern fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) ?[*]u8;
extern fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8;

pub fn __aeabi_memcpy(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memcpy(dest, src, n);
}

pub fn __aeabi_memmove(dest: [*]u8, src: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memmove(dest, src, n);
}

pub fn __aeabi_memset(dest: [*]u8, n: usize, c: u8) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    // This is dentical to the standard `memset` definition but with the last
    // two arguments swapped
    _ = memset(dest, c, n);
}

pub fn __aeabi_memclr(dest: [*]u8, n: usize) callconv(.AAPCS) void {
    @setRuntimeSafety(false);
    _ = memset(dest, 0, n);
}
pub fn __aeabi_unwind_cpp_pr0() callconv(.C) void {
    unreachable;
}
pub fn __aeabi_unwind_cpp_pr1() callconv(.C) void {
    unreachable;
}
pub fn __aeabi_unwind_cpp_pr2() callconv(.C) void {
    unreachable;
}

pub fn __aeabi_uidivmod(n: u32, d: u32) callconv(.C) extern struct {
    q: u32,
    r: u32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uidivmod).ReturnType = undefined;
    result.q = __udivmodsi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_uldivmod(n: u64, d: u64) callconv(.C) extern struct {
    q: u64,
    r: u64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uldivmod).ReturnType = undefined;
    result.q = __udivmoddi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_idivmod(n: i32, d: i32) callconv(.C) extern struct {
    q: i32,
    r: i32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_idivmod).ReturnType = undefined;
    result.q = __divmodsi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_ldivmod(n: i64, d: i64) callconv(.C) extern struct {
    q: i64,
    r: i64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_ldivmod).ReturnType = undefined;
    result.q = __divmoddi4(n, d, &result.r);
    return result;
}
