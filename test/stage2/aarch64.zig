const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const TestContext = @import("../../src/test.zig").TestContext;

const linux_aarch64 = CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .linux,
};
const macos_aarch64 = CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .macos,
};

pub fn addCases(ctx: *TestContext) !void {
    // Linux tests
    {
        var case = ctx.exe("linux_aarch64 hello world", linux_aarch64);
        // Regular old hello world
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{x8}" (64),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{x2}" ("Hello, World!\n".len)
            \\        : "memory", "cc"
            \\    );
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("exit fn taking argument", linux_aarch64);

        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    exit(0);
            \\}
            \\
            \\fn exit(ret: usize) noreturn {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{x8}" (93),
            \\          [arg1] "{x0}" (ret)
            \\        : "memory", "cc"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("conditional branches", linux_aarch64);

        case.addCompareOutput(
            \\pub fn main() void {
            \\    foo(123);
            \\}
            \\
            \\fn foo(x: u64) void {
            \\    if (x > 42) {
            \\        print();
            \\    }
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{x8}" (64),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{x2}" ("Hello, World!\n".len),
            \\        : "memory", "cc"
            \\    );
            \\}
        ,
            "Hello, World!\n",
        );

        case.addCompareOutput(
            \\pub fn main() void {
            \\    foo(true);
            \\}
            \\
            \\fn foo(x: bool) void {
            \\    if (x) {
            \\        print();
            \\    }
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{x8}" (64),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{x2}" ("Hello, World!\n".len),
            \\        : "memory", "cc"
            \\    );
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("large add function", linux_aarch64);

        case.addCompareOutput(
            \\pub fn main() void {
            \\    assert(add(3, 4) == 791);
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
            \\    };
            \\    const y = x + a; // 788
            \\    const z = y + a; // 791
            \\    return z;
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    // macOS tests
    {
        var case = ctx.exe("hello world with updates", macos_aarch64);
        case.addError("", &[_][]const u8{
            ":108:9: error: struct 'tmp.tmp' has no member named 'main'",
        });

        // Incorrect return type
        case.addError(
            \\pub export fn main() noreturn {
            \\}
        , &[_][]const u8{
            ":2:1: error: expected noreturn, found void",
        });

        // Regular old hello world
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\pub export fn main() noreturn {
            \\    print();
            \\
            \\    exit(0);
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "Hello, World!\n",
        );

        // Now using start.zig without an explicit extern exit fn
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "Hello, World!\n",
        );

        // Print it 4 times and force growth and realloc.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\    print();
            \\    print();
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    _ = write(1, msg, len);
            \\}
        ,
            \\Hello, World!
            \\Hello, World!
            \\Hello, World!
            \\Hello, World!
            \\
        );

        // Print it once, and change the message.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    _ = write(1, msg, len);
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );

        // Now we print it twice.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) usize;
            \\
            \\pub fn main() void {
            \\    print();
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    _ = write(1, msg, len);
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }
}
