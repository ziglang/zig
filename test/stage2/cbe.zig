const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exeFromCompiledC("hello world with updates", .{});

        // Regular old hello world
        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\export fn main() c_int {
            \\    _ = puts("hello world!");
            \\    return 0;
            \\}
        , "hello world!" ++ std.cstr.line_sep);

        // Now change the message only
        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\export fn main() c_int {
            \\    _ = puts("yo");
            \\    return 0;
            \\}
        , "yo" ++ std.cstr.line_sep);

        // Add an unused Decl
        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\export fn main() c_int {
            \\    _ = puts("yo!");
            \\    return 0;
            \\}
            \\fn unused() void {}
        , "yo!" ++ std.cstr.line_sep);
    }

    {
        var case = ctx.exeFromCompiledC("x86_64-linux inline assembly", linux_x64);

        // Exit with 0
        case.addCompareOutput(
            \\fn exitGood() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\    );
            \\    unreachable;
            \\}
            \\
            \\export fn main() c_int {
            \\    exitGood();
            \\}
        , "");

        // Pass a usize parameter to exit
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    exit(0);
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\    );
            \\    unreachable;
            \\}
        , "");

        // Change the parameter to u8
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    exit(0);
            \\}
            \\
            \\fn exit(code: u8) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\    );
            \\    unreachable;
            \\}
        , "");

        // Do some arithmetic at the exit callsite
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    exitMath(1);
            \\}
            \\
            \\fn exitMath(a: u8) noreturn {
            \\    exit(0 + a - a);
            \\}
            \\
            \\fn exit(code: u8) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\    );
            \\    unreachable;
            \\}
            \\
        , "");

        // Invert the arithmetic
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    exitMath(1);
            \\}
            \\
            \\fn exitMath(a: u8) noreturn {
            \\    exit(a + 0 - a);
            \\}
            \\
            \\fn exit(code: u8) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\    );
            \\    unreachable;
            \\}
            \\
        , "");
    }

    {
        var case = ctx.exeFromCompiledC("alloc and retptr", .{});

        case.addCompareOutput(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\fn addIndirect(a: i32, b: i32) i32 {
            \\    return add(a, b);
            \\}
            \\
            \\export fn main() c_int {
            \\    return addIndirect(1, 2) - 3;
            \\}
        , "");
    }

    {
        var case = ctx.exeFromCompiledC("inferred local const and var", .{});

        case.addCompareOutput(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\export fn main() c_int {
            \\    const x = add(1, 2);
            \\    var y = add(3, 0);
            \\    y -= x;
            \\    return y;
            \\}
        , "");
    }
    {
        var case = ctx.exeFromCompiledC("@setEvalBranchQuota", .{});

        case.addCompareOutput(
            \\export fn main() i32 {
            \\    @setEvalBranchQuota(1001);
            \\    const y = rec(1001);
            \\    return y - 1;
            \\}
            \\
            \\fn rec(n: usize) callconv(.Inline) usize {
            \\    if (n <= 1) return n;
            \\    return rec(n - 1);
            \\}
        , "");
    }
    {
        var case = ctx.exeFromCompiledC("control flow", .{});

        // Simple while loop
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var a: c_int = 0;
            \\    while (a < 5) : (a+=1) {}
            \\    return a - 5;
            \\}
        , "");
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var a = true;
            \\    while (!a) {}
            \\    return 0;
            \\}
        , "");

        // If expression
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    var a: c_int = @as(c_int, if (cond == 0)
            \\        2
            \\    else
            \\        3) + 9;
            \\    return a - 11;
            \\}
        , "");

        // Switch expression
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    var a: c_int = switch (cond) {
            \\        1 => 1,
            \\        2 => 2,
            \\        99...300, 12 => 3,
            \\        0 => 4,
            \\        else => 5,
            \\    };
            \\    return a - 4;
            \\}
        , "");
    }
    ctx.c("empty start function", linux_x64,
        \\export fn _start() noreturn {
        \\    unreachable;
        \\}
    ,
        \\ZIG_EXTERN_C zig_noreturn void _start(void);
        \\
        \\zig_noreturn void _start(void) {
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.h("simple header", linux_x64,
        \\export fn start() void{}
    ,
        \\ZIG_EXTERN_C void start(void);
        \\
    );
    ctx.h("header with single param function", linux_x64,
        \\export fn start(a: u8) void{}
    ,
        \\ZIG_EXTERN_C void start(uint8_t a0);
        \\
    );
    ctx.h("header with multiple param function", linux_x64,
        \\export fn start(a: u8, b: u8, c: u8) void{}
    ,
        \\ZIG_EXTERN_C void start(uint8_t a0, uint8_t a1, uint8_t a2);
        \\
    );
    ctx.h("header with u32 param function", linux_x64,
        \\export fn start(a: u32) void{}
    ,
        \\ZIG_EXTERN_C void start(uint32_t a0);
        \\
    );
    ctx.h("header with usize param function", linux_x64,
        \\export fn start(a: usize) void{}
    ,
        \\ZIG_EXTERN_C void start(uintptr_t a0);
        \\
    );
    ctx.h("header with bool param function", linux_x64,
        \\export fn start(a: bool) void{}
    ,
        \\ZIG_EXTERN_C void start(bool a0);
        \\
    );
    ctx.h("header with noreturn function", linux_x64,
        \\export fn start() noreturn {
        \\    unreachable;
        \\}
    ,
        \\ZIG_EXTERN_C zig_noreturn void start(void);
        \\
    );
    ctx.h("header with multiple functions", linux_x64,
        \\export fn a() void{}
        \\export fn b() void{}
        \\export fn c() void{}
    ,
        \\ZIG_EXTERN_C void a(void);
        \\ZIG_EXTERN_C void b(void);
        \\ZIG_EXTERN_C void c(void);
        \\
    );
    ctx.h("header with multiple includes", linux_x64,
        \\export fn start(a: u32, b: usize) void{}
    ,
        \\ZIG_EXTERN_C void start(uint32_t a0, uintptr_t a1);
        \\
    );
}
