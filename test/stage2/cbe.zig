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

        // Comptime return type and calling convention expected.
        case.addError(
            \\var x: i32 = 1234;
            \\export fn main() x {
            \\    return 0;
            \\}
            \\export fn foo() callconv(y) c_int {
            \\    return 0;
            \\}
            \\var y: i32 = 1234;
        , &.{
            ":2:18: error: unable to resolve comptime value",
            ":5:26: error: unable to resolve comptime value",
        });
    }

    {
        var case = ctx.exeFromCompiledC("var args", .{});

        case.addCompareOutput(
            \\extern fn printf(format: [*:0]const u8, ...) c_int;
            \\
            \\export fn main() c_int {
            \\    _ = printf("Hello, %s!\n", "world");
            \\    return 0;
            \\}
        , "Hello, world!" ++ std.cstr.line_sep);
    }

    {
        var case = ctx.exeFromCompiledC("@intToError", .{});

        case.addCompareOutput(
            \\pub export fn main() c_int {
            \\    // comptime checks
            \\    const a = error.A;
            \\    const b = error.B;
            \\    const c = @intToError(2);
            \\    const d = @intToError(1);
            \\    if (!(c == b)) unreachable;
            \\    if (!(a == d)) unreachable;
            \\    // runtime checks
            \\    var x = error.A;
            \\    var y = error.B;
            \\    var z = @intToError(2);
            \\    var f = @intToError(1);
            \\    if (!(y == z)) unreachable;
            \\    if (!(x == f)) unreachable;
            \\    return 0;
            \\}
        , "");
        case.addError(
            \\pub export fn main() c_int {
            \\    const c = @intToError(0);
            \\    return 0;
            \\}
        , &.{":2:27: error: integer value 0 represents no error"});
        case.addError(
            \\pub export fn main() c_int {
            \\    const c = @intToError(3);
            \\    return 0;
            \\}
        , &.{":2:27: error: integer value 3 represents no error"});
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

        // Switch expression missing else case.
        case.addError(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    const a: c_int = switch (cond) {
            \\        1 => 1,
            \\        2 => 2,
            \\        3 => 3,
            \\        4 => 4,
            \\    };
            \\    return a - 4;
            \\}
        , &.{":3:22: error: switch must handle all possibilities"});

        // Switch expression, has an unreachable prong.
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    const a: c_int = switch (cond) {
            \\        1 => 1,
            \\        2 => 2,
            \\        99...300, 12 => 3,
            \\        0 => 4,
            \\        13 => unreachable,
            \\        else => 5,
            \\    };
            \\    return a - 4;
            \\}
        , "");

        // Switch expression, has an unreachable prong and prongs write
        // to result locations.
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    var a: c_int = switch (cond) {
            \\        1 => 1,
            \\        2 => 2,
            \\        99...300, 12 => 3,
            \\        0 => 4,
            \\        13 => unreachable,
            \\        else => 5,
            \\    };
            \\    return a - 4;
            \\}
        , "");

        // Integer switch expression has duplicate case value.
        case.addError(
            \\export fn main() c_int {
            \\    var cond: c_int = 0;
            \\    const a: c_int = switch (cond) {
            \\        1 => 1,
            \\        2 => 2,
            \\        96, 11...13, 97 => 3,
            \\        0 => 4,
            \\        90, 12 => 100,
            \\        else => 5,
            \\    };
            \\    return a - 4;
            \\}
        , &.{
            ":8:13: error: duplicate switch value",
            ":6:15: note: previous value here",
        });

        // Boolean switch expression has duplicate case value.
        case.addError(
            \\export fn main() c_int {
            \\    var a: bool = false;
            \\    const b: c_int = switch (a) {
            \\        false => 1,
            \\        true => 2,
            \\        false => 3,
            \\    };
            \\}
        , &.{
            ":6:9: error: duplicate switch value",
        });

        // Sparse (no range capable) switch expression has duplicate case value.
        case.addError(
            \\export fn main() c_int {
            \\    const A: type = i32;
            \\    const b: c_int = switch (A) {
            \\        i32 => 1,
            \\        bool => 2,
            \\        f64, i32 => 3,
            \\        else => 4,
            \\    };
            \\}
        , &.{
            ":6:14: error: duplicate switch value",
            ":4:9: note: previous value here",
        });

        // Ranges not allowed for some kinds of switches.
        case.addError(
            \\export fn main() c_int {
            \\    const A: type = i32;
            \\    const b: c_int = switch (A) {
            \\        i32 => 1,
            \\        bool => 2,
            \\        f16...f64 => 3,
            \\        else => 4,
            \\    };
            \\}
        , &.{
            ":3:30: error: ranges not allowed when switching on type 'type'",
            ":6:12: note: range here",
        });

        // Switch expression has unreachable else prong.
        case.addError(
            \\export fn main() c_int {
            \\    var a: u2 = 0;
            \\    const b: i32 = switch (a) {
            \\        0 => 10,
            \\        1 => 20,
            \\        2 => 30,
            \\        3 => 40,
            \\        else => 50,
            \\    };
            \\}
        , &.{
            ":8:14: error: unreachable else prong; all cases already handled",
        });
    }
    //{
    //    var case = ctx.exeFromCompiledC("optionals", .{});

    //    // Simple while loop
    //    case.addCompareOutput(
    //        \\export fn main() c_int {
    //        \\    var count: c_int = 0;
    //        \\    var opt_ptr: ?*c_int = &count;
    //        \\    while (opt_ptr) |_| : (count += 1) {
    //        \\        if (count == 4) opt_ptr = null;
    //        \\    }
    //        \\    return count - 5;
    //        \\}
    //    , "");

    //    // Same with non pointer optionals
    //    case.addCompareOutput(
    //        \\export fn main() c_int {
    //        \\    var count: c_int = 0;
    //        \\    var opt_ptr: ?c_int = count;
    //        \\    while (opt_ptr) |_| : (count += 1) {
    //        \\        if (count == 4) opt_ptr = null;
    //        \\    }
    //        \\    return count - 5;
    //        \\}
    //    , "");
    //}

    {
        var case = ctx.exeFromCompiledC("errors", .{});
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var e1 = error.Foo;
            \\    var e2 = error.Bar;
            \\    assert(e1 != e2);
            \\    assert(e1 == error.Foo);
            \\    assert(e2 == error.Bar);
            \\    return 0;
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
        , "");
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var e: anyerror!c_int = 0;
            \\    const i = e catch 69;
            \\    return i;
            \\}
        , "");
        case.addCompareOutput(
            \\export fn main() c_int {
            \\    var e: anyerror!c_int = error.Foo;
            \\    const i = e catch 69;
            \\    return 69 - i;
            \\}
        , "");
    }

    {
        var case = ctx.exeFromCompiledC("structs", .{});
        case.addError(
            \\const Point = struct { x: i32, y: i32 };
            \\export fn main() c_int {
            \\    var p: Point = .{
            \\        .y = 24,
            \\        .x = 12,
            \\        .y = 24,
            \\    };
            \\    return p.y - p.x - p.x;
            \\}
        , &.{
            ":6:10: error: duplicate field",
            ":4:10: note: other field here",
        });
        case.addError(
            \\const Point = struct { x: i32, y: i32 };
            \\export fn main() c_int {
            \\    var p: Point = .{
            \\        .y = 24,
            \\    };
            \\    return p.y - p.x - p.x;
            \\}
        , &.{
            ":3:21: error: mising struct field: x",
            ":1:15: note: 'Point' declared here",
        });
        case.addError(
            \\const Point = struct { x: i32, y: i32 };
            \\export fn main() c_int {
            \\    var p: Point = .{
            \\        .x = 12,
            \\        .y = 24,
            \\        .z = 48,
            \\    };
            \\    return p.y - p.x - p.x;
            \\}
        , &.{
            ":6:10: error: no field named 'z' in struct 'Point'",
            ":1:15: note: 'Point' declared here",
        });
        case.addCompareOutput(
            \\const Point = struct { x: i32, y: i32 };
            \\export fn main() c_int {
            \\    var p: Point = .{
            \\        .x = 12,
            \\        .y = 24,
            \\    };
            \\    return p.y - p.x - p.x;
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
        \\ zig_breakpoint();
        \\ zig_unreachable();
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
