const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;
const build_options = @import("build_options");

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exeUsingLlvmBackend("simple addition and subtraction", linux_x64);

        case.addCompareOutput(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    var a: i32 = -5;
            \\    const x = add(a, 7);
            \\    var y = add(2, 0);
            \\    y -= x;
            \\    return y;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("shift right + left", linux_x64);

        case.addCompareOutput(
            \\pub export fn main() c_int {
            \\    var i: u32 = 16;
            \\    assert(i >> 1, 8);
            \\    return 0;
            \\}
            \\fn assert(a: u32, b: u32) void {
            \\    if (a != b) unreachable;
            \\}
        , "");
        case.addCompareOutput(
            \\pub export fn main() c_int {
            \\    var i: u32 = 16;
            \\    assert(i << 1, 32);
            \\    return 0;
            \\}
            \\fn assert(a: u32, b: u32) void {
            \\    if (a != b) unreachable;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("llvm hello world", linux_x64);

        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\
            \\pub export fn main() c_int {
            \\    _ = puts("hello world!");
            \\    return 0;
            \\}
        , "hello world!" ++ std.cstr.line_sep);
    }

    {
        var case = ctx.exeUsingLlvmBackend("simple if statement", linux_x64);

        case.addCompareOutput(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    assert(add(1,2) == 3);
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("blocks", linux_x64);

        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\fn foo(ok: bool) i32 {
            \\    const val: i32 = blk: {
            \\        var x: i32 = 1;
            \\        if (!ok) break :blk x + 9;
            \\        break :blk x + 19;
            \\    };
            \\    return val + 10;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    assert(foo(false) == 20);
            \\    assert(foo(true) == 30);
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("nested blocks", linux_x64);

        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\fn foo(ok: bool) i32 {
            \\    var val: i32 = blk: {
            \\        const val2: i32 = another: {
            \\            if (!ok) break :blk 10;
            \\            break :another 10;
            \\        };
            \\        break :blk val2 + 10;
            \\    };
            \\    return val;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    assert(foo(false) == 10);
            \\    assert(foo(true) == 20);
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("while loops", linux_x64);

        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    var sum: u32 = 0;
            \\    var i: u32 = 0;
            \\    while (i < 5) : (i += 1) {
            \\        sum += i;
            \\    }
            \\    assert(sum == 10);
            \\    assert(i == 5);
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("optionals", linux_x64);

        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    var opt_val: ?i32 = 10;
            \\    var null_val: ?i32 = null;
            \\
            \\    var val1: i32 = opt_val.?;
            \\    const val1_1: i32 = opt_val.?;
            \\    var ptr_val1 = &(opt_val.?);
            \\    const ptr_val1_1 = &(opt_val.?);
            \\
            \\    var val2: i32 = null_val orelse 20;
            \\    const val2_2: i32 = null_val orelse 20;
            \\
            \\    var value: i32 = 20;
            \\    var ptr_val2 = &(null_val orelse value);
            \\
            \\    const val3 = opt_val orelse 30;
            \\    var val3_var = opt_val orelse 30;
            \\
            \\    assert(val1 == 10);
            \\    assert(val1_1 == 10);
            \\    assert(ptr_val1.* == 10);
            \\    assert(ptr_val1_1.* == 10);
            \\
            \\    assert(val2 == 20);
            \\    assert(val2_2 == 20);
            \\    assert(ptr_val2.* == 20);
            \\
            \\    assert(val3 == 10);
            \\    assert(val3_var == 10);
            \\
            \\    (null_val orelse val2) = 1234;
            \\    assert(val2 == 1234);
            \\
            \\    (opt_val orelse val2) = 5678;
            \\    assert(opt_val.? == 5678);
            \\
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("for loop", linux_x64);

        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\pub export fn main() c_int {
            \\    var x: u32 = 0;
            \\    for ("hello") |_| {
            \\        x += 1;
            \\    }
            \\    assert("hello".len == x);
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("@rem", linux_x64);
        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\fn rem(lhs: i32, rhs: i32, expected: i32) bool {
            \\    return @rem(lhs, rhs) == expected;
            \\}
            \\pub export fn main() c_int {
            \\    assert(rem(-5, 3, -2));
            \\    assert(rem(5, 3, 2));
            \\    return 0;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("invalid address space coercion", linux_x64);
        case.addError(
            \\fn entry(a: *addrspace(.gs) i32) *i32 {
            \\    return a;
            \\}
            \\pub export fn main() void { _ = entry; }
        , &[_][]const u8{
            ":2:12: error: expected *i32, found *addrspace(.gs) i32",
        });
    }

    {
        var case = ctx.exeUsingLlvmBackend("pointer keeps address space", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.gs) i32) *addrspace(.gs) i32 {
            \\    return a;
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("pointer to explicit generic address space coerces to implicit pointer", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.generic) i32) *i32 {
            \\    return a;
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("pointers with different address spaces", linux_x64);
        case.addError(
            \\fn entry(a: *addrspace(.gs) i32) *addrspace(.fs) i32 {
            \\    return a;
            \\}
            \\pub export fn main() void { _ = entry; }
        , &[_][]const u8{
            ":2:12: error: expected *addrspace(.fs) i32, found *addrspace(.gs) i32",
        });
    }

    {
        var case = ctx.exeUsingLlvmBackend("pointers with different address spaces", linux_x64);
        case.addError(
            \\fn entry(a: ?*addrspace(.gs) i32) *i32 {
            \\    return a.?;
            \\}
            \\pub export fn main() void { _ = entry; }
        , &[_][]const u8{
            ":2:13: error: expected *i32, found *addrspace(.gs) i32",
        });
    }

    {
        var case = ctx.exeUsingLlvmBackend("invalid pointer keeps address space when taking address of dereference", linux_x64);
        case.addError(
            \\fn entry(a: *addrspace(.gs) i32) *i32 {
            \\    return &a.*;
            \\}
            \\pub export fn main() void { _ = entry; }
        , &[_][]const u8{
            ":2:12: error: expected *i32, found *addrspace(.gs) i32",
        });
    }

    {
        var case = ctx.exeUsingLlvmBackend("pointer keeps address space when taking address of dereference", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.gs) i32) *addrspace(.gs) i32 {
            \\    return &a.*;
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("address spaces pointer access chaining: array pointer", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.gs) [1]i32) *addrspace(.gs) i32 {
            \\    return &a[0];
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("address spaces pointer access chaining: pointer to optional array", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.gs) ?[1]i32) *addrspace(.gs) i32 {
            \\    return &a.*.?[0];
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("address spaces pointer access chaining: struct pointer", linux_x64);
        case.compiles(
            \\const A = struct{ a: i32 };
            \\fn entry(a: *addrspace(.gs) A) *addrspace(.gs) i32 {
            \\    return &a.a;
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("address spaces pointer access chaining: complex", linux_x64);
        case.compiles(
            \\const A = struct{ a: ?[1]i32 };
            \\fn entry(a: *addrspace(.gs) [1]A) *addrspace(.gs) i32 {
            \\    return &a[0].a.?[0];
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("dereferencing through multiple pointers with address spaces", linux_x64);
        case.compiles(
            \\fn entry(a: *addrspace(.fs) *addrspace(.gs) *i32) *i32 {
            \\    return a.*.*;
            \\}
            \\pub export fn main() void { _ = entry; }
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("f segment address space reading and writing", linux_x64);
        case.addCompareOutput(
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\fn setFs(value: c_ulong) void {
            \\    asm volatile (
            \\        \\syscall
            \\        :
            \\        : [number] "{rax}" (158),
            \\          [code] "{rdi}" (0x1002),
            \\          [val] "{rsi}" (value),
            \\        : "rcx", "r11", "memory"
            \\    );
            \\}
            \\
            \\fn getFs() c_ulong {
            \\    var result: c_ulong = undefined;
            \\    asm volatile (
            \\        \\syscall
            \\        :
            \\        : [number] "{rax}" (158),
            \\          [code] "{rdi}" (0x1003),
            \\          [ptr] "{rsi}" (@ptrToInt(&result)),
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return result;
            \\}
            \\
            \\var test_value: u64 = 12345;
            \\
            \\pub export fn main() c_int {
            \\    const orig_fs = getFs();
            \\
            \\    setFs(@ptrToInt(&test_value));
            \\    assert(getFs() == @ptrToInt(&test_value));
            \\
            \\    var test_ptr = @intToPtr(*allowzero addrspace(.fs) u64, 0);
            \\    assert(test_ptr.* == 12345);
            \\    test_ptr.* = 98765;
            \\    assert(test_value == 98765);
            \\
            \\    setFs(orig_fs);
            \\    return 0;
            \\}
        , "");
    }

    {
        // This worked in stage1 and we expressly do not want this to work in stage2
        var case = ctx.exeUsingLlvmBackend("any typed null to any typed optional", linux_x64);
        case.addError(
            \\pub export fn main() void {
            \\    var a: ?*anyopaque = undefined;
            \\    a = @as(?usize, null);
            \\}
        , &[_][]const u8{
            ":3:21: error: expected *anyopaque, found ?usize",
        });
    }
}
