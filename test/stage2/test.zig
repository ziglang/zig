const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

// Self-hosted has differing levels of support for various architectures. For now we pass explicit
// target parameters to each test case. At some point we will take this to the next level and have
// a set of targets that all test cases run on unless specifically overridden. For now, each test
// case applies to only the specified target.

const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    try @import("cbe.zig").addCases(ctx);
    try @import("spu-ii.zig").addCases(ctx);
    try @import("arm.zig").addCases(ctx);
    try @import("aarch64.zig").addCases(ctx);
    try @import("llvm.zig").addCases(ctx);
    try @import("wasm.zig").addCases(ctx);
    try @import("darwin.zig").addCases(ctx);
    try @import("riscv64.zig").addCases(ctx);

    {
        var case = ctx.exe("hello world with updates", linux_x64);

        case.addError("", &[_][]const u8{"error: no entry point found"});

        // Incorrect return type
        case.addError(
            \\export fn _start() noreturn {
            \\}
        , &[_][]const u8{":2:1: error: expected noreturn, found void"});

        // Regular old hello world
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (14)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
        // Now change the message only
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );
        // Now we print it twice.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{rdx}" (104)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }

    {
        var case = ctx.exe("adding numbers at comptime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (10 + 4)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (@as(usize, 230) + @as(usize, 1)),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("adding numbers at runtime and comptime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    if (a + b != 7) unreachable;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        // comptime function call
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    return a + b;
            \\}
            \\
            \\const x = add(3, 4);
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (x - 7)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        // Inline function call
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: usize = 3;
            \\    const y = add(1, 2, x);
            \\    exit(y - 6);
            \\}
            \\
            \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
            \\    return a + b + c;
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("subtracting numbers at runtime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    sub(7, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn sub(a: u32, b: u32) void {
            \\    if (a - b != 3) unreachable;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
    {
        var case = ctx.exe("@TypeOf", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: usize = 0;
            \\    const z = @TypeOf(x, @as(u128, 5));
            \\    assert(z == u128);
            \\
            \\    exit();
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const z = @TypeOf(true);
            \\    assert(z == bool);
            \\
            \\    exit();
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addError(
            \\export fn _start() noreturn {
            \\    const z = @TypeOf(true, 1);
            \\    unreachable;
            \\}
        , &[_][]const u8{":2:15: error: incompatible types: 'bool' and 'comptime_int'"});
    }

    {
        var case = ctx.exe("multiplying numbers at runtime and comptime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    mul(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn mul(a: u32, b: u32) void {
            \\    if (a * b != 12) unreachable;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        // comptime function call
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    exit();
            \\}
            \\
            \\fn mul(a: u32, b: u32) u32 {
            \\    return a * b;
            \\}
            \\
            \\const x = mul(3, 4);
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (x - 12)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        // Inline function call
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: usize = 5;
            \\    const y = mul(2, 3, x);
            \\    exit(y - 30);
            \\}
            \\
            \\fn mul(a: usize, b: usize, c: usize) callconv(.Inline) usize {
            \\    return a * b * c;
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("assert function", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    assert(a + b == 7);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Tests copying a register. For the `c = a + b`, it has to
        // preserve both a and b, because they are both used later.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    const c = a + b; // 7
            \\    const d = a + c; // 10
            \\    const e = d + b; // 14
            \\    assert(e == 14);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // More stress on the liveness detection.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    const c = a + b; // 7
            \\    const d = a + c; // 10
            \\    const e = d + b; // 14
            \\    const f = d + e; // 24
            \\    const g = e + f; // 38
            \\    const h = f + g; // 62
            \\    const i = g + h; // 100
            \\    assert(i == 100);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Requires a second move. The register allocator should figure out to re-use rax.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(3, 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    const c = a + b; // 7
            \\    const d = a + c; // 10
            \\    const e = d + b; // 14
            \\    const f = d + e; // 24
            \\    const g = e + f; // 38
            \\    const h = f + g; // 62
            \\    const i = g + h; // 100
            \\    const j = i + d; // 110
            \\    assert(j == 110);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Now we test integer return values.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 7);
            \\    assert(add(20, 10) == 30);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    return a + b;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Local mutable variables.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 7);
            \\    assert(add(20, 10) == 30);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    var x: u32 = undefined;
            \\    x = 0;
            \\    x += a;
            \\    x += b;
            \\    return x;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Optionals
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const a: u32 = 2;
            \\    const b: ?u32 = a;
            \\    const c = b.?;
            \\    if (c != 2) unreachable;
            \\
            \\    exit();
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // While loops
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var i: u32 = 0;
            \\    while (i < 4) : (i += 1) print();
            \\    assert(i == 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
            \\          [arg3] "{rdx}" (6)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "hello\nhello\nhello\nhello\n",
        );

        // inline while requires the condition to be comptime known.
        case.addError(
            \\export fn _start() noreturn {
            \\    var i: u32 = 0;
            \\    inline while (i < 4) : (i += 1) print();
            \\    assert(i == 4);
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
            \\          [arg3] "{rdx}" (6)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , &[_][]const u8{":3:21: error: unable to resolve comptime value"});

        // Labeled blocks (no conditional branch)
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 20);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    const x: u32 = blk: {
            \\        const c = a + b; // 7
            \\        const d = a + c; // 10
            \\        const e = d + b; // 14
            \\        break :blk e;
            \\    };
            \\    const y = x + a; // 17
            \\    const z = y + a; // 20
            \\    return z;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // This catches a possible bug in the logic for re-using dying operands.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 116);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    const x: u32 = blk: {
            \\        const c = a + b; // 7
            \\        const d = a + c; // 10
            \\        const e = d + b; // 14
            \\        const f = d + e; // 24
            \\        const g = e + f; // 38
            \\        const h = f + g; // 62
            \\        const i = g + h; // 100
            \\        const j = i + d; // 110
            \\        break :blk j;
            \\    };
            \\    const y = x + a; // 113
            \\    const z = y + a; // 116
            \\    return z;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Spilling registers to the stack.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 1221);
            \\    assert(mul(3, 4) == 21609);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    const x: u32 = blk: {
            \\        const c = a + b; // 7
            \\        const d = a + c; // 10
            \\        const e = d + b; // 14
            \\        const f = d + e; // 24
            \\        const g = e + f; // 38
            \\        const h = f + g; // 62
            \\        const i = g + h; // 100
            \\        const j = i + d; // 110
            \\        const k = i + j; // 210
            \\        const l = j + k; // 320
            \\        const m = l + c; // 327
            \\        const n = m + d; // 337
            \\        const o = n + e; // 351
            \\        const p = o + f; // 375
            \\        const q = p + g; // 413
            \\        const r = q + h; // 475
            \\        const s = r + i; // 575
            \\        const t = s + j; // 685
            \\        const u = t + k; // 895
            \\        const v = u + l; // 1215
            \\        break :blk v;
            \\    };
            \\    const y = x + a; // 1218
            \\    const z = y + a; // 1221
            \\    return z;
            \\}
            \\
            \\fn mul(a: u32, b: u32) u32 {
            \\    const x: u32 = blk: {
            \\        const c = a * a * a * a; // 81
            \\        const d = a * a * a * b; // 108
            \\        const e = a * a * b * a; // 108
            \\        const f = a * a * b * b; // 144
            \\        const g = a * b * a * a; // 108
            \\        const h = a * b * a * b; // 144
            \\        const i = a * b * b * a; // 144
            \\        const j = a * b * b * b; // 192
            \\        const k = b * a * a * a; // 108
            \\        const l = b * a * a * b; // 144
            \\        const m = b * a * b * a; // 144
            \\        const n = b * a * b * b; // 192
            \\        const o = b * b * a * a; // 144
            \\        const p = b * b * a * b; // 192
            \\        const q = b * b * b * a; // 192
            \\        const r = b * b * b * b; // 256
            \\        const s = c + d + e + f + g + h + i + j + k + l + m + n + o + p + q + r; // 2401
            \\        break :blk s;
            \\    };
            \\    const y = x * a; // 7203
            \\    const z = y * a; // 21609
            \\    return z;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Reusing the registers of dead operands playing nicely with conditional branching.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(add(3, 4) == 791);
            \\    assert(add(4, 3) == 79);
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) u32 {
            \\    const x: u32 = if (a < b) blk: {
            \\        const c = a + b; // 7
            \\        const d = a + c; // 10
            \\        const e = d + b; // 14
            \\        const f = d + e; // 24
            \\        const g = e + f; // 38
            \\        const h = f + g; // 62
            \\        const i = g + h; // 100
            \\        const j = i + d; // 110
            \\        const k = i + j; // 210
            \\        const l = k + c; // 217
            \\        const m = l + d; // 227
            \\        const n = m + e; // 241
            \\        const o = n + f; // 265
            \\        const p = o + g; // 303
            \\        const q = p + h; // 365
            \\        const r = q + i; // 465
            \\        const s = r + j; // 575
            \\        const t = s + k; // 785
            \\        break :blk t;
            \\    } else blk: {
            \\        const t = b + b + a; // 10
            \\        const c = a + t; // 14
            \\        const d = c + t; // 24
            \\        const e = d + t; // 34
            \\        const f = e + t; // 44
            \\        const g = f + t; // 54
            \\        const h = c + g; // 68
            \\        break :blk h + b; // 71
            \\    };
            \\    const y = x + a; // 788, 75
            \\    const z = y + a; // 791, 79
            \\    return z;
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Character literals and multiline strings.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const ignore =
            \\        \\ cool thx
            \\        \\
            \\    ;
            \\    add('ぁ', '\x03');
            \\
            \\    exit();
            \\}
            \\
            \\fn add(a: u32, b: u32) void {
            \\    assert(a + b == 12356);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Global const.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    add(aa, bb);
            \\
            \\    exit();
            \\}
            \\
            \\const aa = 'ぁ';
            \\const bb = '\x03';
            \\
            \\fn add(a: u32, b: u32) void {
            \\    assert(a + b == 12356);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Array access.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert("hello"[0] == 'h');
            \\
            \\    exit();
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Array access to a global array.
        case.addCompareOutput(
            \\const hello = "hello".*;
            \\export fn _start() noreturn {
            \\    assert(hello[1] == 'e');
            \\
            \\    exit();
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // 64bit set stack
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var i: u64 = 0xFFEEDDCCBBAA9988;
            \\    assert(i == 0xFFEEDDCCBBAA9988);
            \\
            \\    exit();
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Basic for loop
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    for ("hello") |_| print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (1),
            \\          [arg1] "{rdi}" (1),
            \\          [arg2] "{rsi}" (@ptrToInt("hello\n")),
            \\          [arg3] "{rdx}" (6)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "hello\nhello\nhello\nhello\nhello\n",
        );
    }

    {
        var case = ctx.exe("basic import", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    @import("print.zig").print();
            \\    exit();
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (@as(usize, 0))
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
        try case.files.append(.{
            .src = 
            \\pub fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (@as(usize, 1)),
            \\          [arg1] "{rdi}" (@as(usize, 1)),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (@as(usize, 14))
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            ,
            .path = "print.zig",
        });
    }
    {
        var case = ctx.exe("import private", linux_x64);
        case.addError(
            \\export fn _start() noreturn {
            \\    @import("print.zig").print();
            \\    exit();
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (@as(usize, 0))
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            &.{":2:25: error: 'print' is private"},
        );
        try case.files.append(.{
            .src = 
            \\fn print() void {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (@as(usize, 1)),
            \\          [arg1] "{rdi}" (@as(usize, 1)),
            \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{rdx}" (@as(usize, 14))
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
            ,
            .path = "print.zig",
        });
    }

    ctx.compileError("function redefinition", linux_x64,
        \\// dummy comment
        \\fn entry() void {}
        \\fn entry() void {}
    , &[_][]const u8{
        ":3:4: error: redefinition of 'entry'",
        ":2:1: note: previous definition here",
    });

    ctx.compileError("global variable redefinition", linux_x64,
        \\// dummy comment
        \\var foo = false;
        \\var foo = true;
    , &[_][]const u8{
        ":3:5: error: redefinition of 'foo'",
        ":2:1: note: previous definition here",
    });

    ctx.compileError("compileError", linux_x64,
        \\export fn _start() noreturn {
        \\  @compileError("this is an error");
        \\  unreachable;
        \\}
    , &[_][]const u8{":2:3: error: this is an error"});

    {
        var case = ctx.obj("variable shadowing", linux_x64);
        case.addError(
            \\export fn _start() noreturn {
            \\    var i: u32 = 10;
            \\    var i: u32 = 10;
            \\    unreachable;
            \\}
        , &[_][]const u8{
            ":3:9: error: redefinition of 'i'",
            ":2:9: note: previous definition is here",
        });
        case.addError(
            \\var testing: i64 = 10;
            \\export fn _start() noreturn {
            \\    var testing: i64 = 20;
            \\    unreachable;
            \\}
        , &[_][]const u8{":3:9: error: redefinition of 'testing'"});
    }

    {
        // TODO make the test harness support checking the compile log output too
        var case = ctx.obj("@compileLog", linux_x64);
        // The other compile error prevents emission of a "found compile log" statement.
        case.addError(
            \\export fn _start() noreturn {
            \\    const b = true;
            \\    var f: u32 = 1;
            \\    @compileLog(b, 20, f, x);
            \\    @compileLog(1000);
            \\    var bruh: usize = true;
            \\    unreachable;
            \\}
            \\export fn other() void {
            \\    @compileLog(1234);
            \\}
            \\fn x() void {}
        , &[_][]const u8{
            ":6:23: error: expected usize, found bool",
        });

        // Now only compile log statements remain. One per Decl.
        case.addError(
            \\export fn _start() noreturn {
            \\    const b = true;
            \\    var f: u32 = 1;
            \\    @compileLog(b, 20, f, x);
            \\    @compileLog(1000);
            \\    unreachable;
            \\}
            \\export fn other() void {
            \\    @compileLog(1234);
            \\}
            \\fn x() void {}
        , &[_][]const u8{
            ":9:5: error: found compile log statement",
            ":4:5: note: also here",
        });
    }

    {
        var case = ctx.obj("extern variable has no type", linux_x64);
        case.addError(
            \\comptime {
            \\    _ = foo;
            \\}
            \\extern var foo: i32;
        , &[_][]const u8{":2:9: error: unable to resolve comptime value"});
        case.addError(
            \\export fn entry() void {
            \\    _ = foo;
            \\}
            \\extern var foo;
        , &[_][]const u8{":4:8: error: unable to infer variable type"});
    }

    {
        var case = ctx.exe("break/continue", linux_x64);

        // Break out of loop
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    while (true) {
            \\        break;
            \\    }
            \\
            \\    exit();
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    foo: while (true) {
            \\        break :foo;
            \\    }
            \\
            \\    exit();
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        // Continue in loop
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var i: u64 = 0;
            \\    while (true) : (i+=1) {
            \\        if (i == 4) exit();
            \\        continue;
            \\    }
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var i: u64 = 0;
            \\    foo: while (true) : (i+=1) {
            \\        if (i == 4) exit();
            \\        continue :foo;
            \\    }
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("unused labels", linux_x64);
        case.addError(
            \\comptime {
            \\    foo: {}
            \\}
        , &[_][]const u8{":2:5: error: unused block label"});
        case.addError(
            \\comptime {
            \\    foo: while (true) {}
            \\}
        , &[_][]const u8{":2:5: error: unused while loop label"});
        case.addError(
            \\comptime {
            \\    foo: for ("foo") |_| {}
            \\}
        , &[_][]const u8{":2:5: error: unused for loop label"});
        case.addError(
            \\comptime {
            \\    blk: {blk: {}}
            \\}
        , &[_][]const u8{
            ":2:11: error: redefinition of label 'blk'",
            ":2:5: note: previous definition is here",
        });
    }

    {
        var case = ctx.exe("bad inferred variable type", linux_x64);
        case.addError(
            \\export fn foo() void {
            \\    var x = null;
            \\}
        , &[_][]const u8{":2:9: error: variable of type '@Type(.Null)' must be const or comptime"});
    }

    {
        var case = ctx.exe("compile error in inline fn call fixed", linux_x64);
        case.addError(
            \\export fn _start() noreturn {
            \\    var x: usize = 3;
            \\    const y = add(10, 2, x);
            \\    exit(y - 6);
            \\}
            \\
            \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
            \\    if (a == 10) @compileError("bad");
            \\    return a + b + c;
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , &[_][]const u8{":8:18: error: bad"});

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: usize = 3;
            \\    const y = add(1, 2, x);
            \\    exit(y - 6);
            \\}
            \\
            \\fn add(a: usize, b: usize, c: usize) callconv(.Inline) usize {
            \\    if (a == 10) @compileError("bad");
            \\    return a + b + c;
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
    {
        var case = ctx.exe("recursive inline function", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const y = fibonacci(7);
            \\    exit(y - 21);
            \\}
            \\
            \\fn fibonacci(n: usize) callconv(.Inline) usize {
            \\    if (n <= 2) return n;
            \\    return fibonacci(n - 2) + fibonacci(n - 1);
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        // This additionally tests that the compile error reports the correct source location.
        // Without storing source locations relative to the owner decl, the compile error
        // here would be off by 2 bytes (from the "7" -> "999").
        case.addError(
            \\export fn _start() noreturn {
            \\    const y = fibonacci(999);
            \\    exit(y - 21);
            \\}
            \\
            \\fn fibonacci(n: usize) callconv(.Inline) usize {
            \\    if (n <= 2) return n;
            \\    return fibonacci(n - 2) + fibonacci(n - 1);
            \\}
            \\
            \\fn exit(code: usize) noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (code)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , &[_][]const u8{":8:21: error: evaluation exceeded 1000 backwards branches"});
    }
    {
        var case = ctx.exe("orelse at comptime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const i: ?u64 = 0;
            \\    const orelsed = i orelse 5;
            \\    assert(orelsed == 0);
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const i: ?u64 = null;
            \\    const orelsed = i orelse 5;
            \\    assert(orelsed == 5);
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("only 1 function and it gets updated", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (60), // exit
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231), // exit_group
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
    {
        var case = ctx.exe("passing u0 to function", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    doNothing(0);
            \\    exit();
            \\}
            \\fn doNothing(arg: u0) void {}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
    {
        var case = ctx.exe("catch at comptime", linux_x64);
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const i: anyerror!u64 = 0;
            \\    const caught = i catch 5;
            \\    assert(caught == 0);
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const i: anyerror!u64 = error.B;
            \\    const caught = i catch 5;
            \\    assert(caught == 5);
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const a: anyerror!comptime_int = 42;
            \\    const b: *const comptime_int = &(a catch unreachable);
            \\    assert(b.* == 42);
            \\
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable; // assertion failure
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , "");

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const a: anyerror!u32 = error.B;
            \\    _ = &(a catch |err| assert(err == error.B));
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , "");

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const a: anyerror!u32 = error.Bar;
            \\    a catch |err| assert(err == error.Bar);
            \\
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        , "");
    }
    {
        var case = ctx.exe("merge error sets", linux_x64);

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    const E = error{ A, B, D } || error { A, B, C };
            \\    const a = E.A;
            \\    const b = E.B;
            \\    const c = E.C;
            \\    const d = E.D;
            \\    const E2 = error { X, Y } || @TypeOf(error.Z);
            \\    const x = E2.X;
            \\    const y = E2.Y;
            \\    const z = E2.Z;
            \\    assert(anyerror || error { Z } == anyerror);
            \\    exit();
            \\}
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
            \\fn exit() noreturn {
            \\    asm volatile ("syscall"
            \\        :
            \\        : [number] "{rax}" (231),
            \\          [arg1] "{rdi}" (0)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }
}
