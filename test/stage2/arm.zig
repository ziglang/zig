const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const linux_arm = std.zig.CrossTarget{
    .cpu_arch = .arm,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("linux_arm hello world", linux_arm);
        // Hello world using _start and inline asm.
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
            \\    print();
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{r2}" (14)
            \\        : "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (1),
            \\          [arg1] "{r0}" (0)
            \\        : "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("parameters and return values", linux_arm);
        // Testing simple parameters and return values
        //
        // TODO: The parameters to the asm statement in print() had to
        // be in a specific order because otherwise the write to r0
        // would overwrite the len parameter which resides in r0
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(id(14));
            \\}
            \\
            \\fn id(x: u32) u32 {
            \\    return x;
            \\}
            \\
            \\fn print(len: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (len),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("Hello, World!\n"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("non-leaf functions", linux_arm);
        // Testing non-leaf functions
        case.addCompareOutput(
            \\pub fn main() void {
            \\    foo();
            \\}
            \\
            \\fn foo() void {
            \\    bar();
            \\}
            \\
            \\fn bar() void {}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("arithmetic operations", linux_arm);

        // Add two numbers
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(2, 4);
            \\    print(1, 7);
            \\}
            \\
            \\fn print(a: u32, b: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (a + b),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("123456789"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "12345612345678",
        );

        // Subtract two numbers
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(10, 5);
            \\    print(4, 3);
            \\}
            \\
            \\fn print(a: u32, b: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (a - b),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("123456789"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "123451",
        );

        // Bitwise And
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(8, 9);
            \\    print(3, 7);
            \\}
            \\
            \\fn print(a: u32, b: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (a & b),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("123456789"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "12345678123",
        );

        // Bitwise Or
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(4, 2);
            \\    print(3, 7);
            \\}
            \\
            \\fn print(a: u32, b: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (a | b),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("123456789"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "1234561234567",
        );

        // Bitwise Xor
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print(42, 42);
            \\    print(3, 5);
            \\}
            \\
            \\fn print(a: u32, b: u32) void {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg3] "{r2}" (a ^ b),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("123456789"))
            \\        : "memory"
            \\    );
            \\    return;
            \\}
        ,
            "123456",
        );

        // Bit Shift Left
        case.addCompareOutput(
            \\pub fn main() void {
            \\    var x: u32 = 1;
            \\    assert(x << 1 == 2);
            \\
            \\    x <<= 1;
            \\    assert(x << 2 == 8);
            \\    assert(x << 3 == 16);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
        ,
            "",
        );

        // Bit Shift Right
        case.addCompareOutput(
            \\pub fn main() void {
            \\    var a: u32 = 1024;
            \\    assert(a >> 1 == 512);
            \\
            \\    a >>= 1;
            \\    assert(a >> 2 == 128);
            \\    assert(a >> 3 == 64);
            \\    assert(a >> 4 == 32);
            \\    assert(a >> 5 == 16);
            \\    assert(a >> 6 == 8);
            \\    assert(a >> 7 == 4);
            \\    assert(a >> 8 == 2);
            \\    assert(a >> 9 == 1);
            \\}
            \\
            \\pub fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("if statements", linux_arm);
        // Simple if statement in assert
        case.addCompareOutput(
            \\pub fn main() void {
            \\    var x: u32 = 123;
            \\    var y: u32 = 42;
            \\    assert(x > y);
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("while loops", linux_arm);
        // Simple while loop with assert
        case.addCompareOutput(
            \\pub fn main() void {
            \\    var x: u32 = 2020;
            \\    var i: u32 = 0;
            \\    while (x > 0) {
            \\        x -= 2;
            \\        i += 1;
            \\    }
            \\    assert(i == 1010);
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("integer multiplication", linux_arm);
        // Simple u32 integer multiplication
        case.addCompareOutput(
            \\pub fn main() void {
            \\    assert(mul(1, 1) == 1);
            \\    assert(mul(42, 1) == 42);
            \\    assert(mul(1, 42) == 42);
            \\    assert(mul(123, 42) == 5166);
            \\}
            \\
            \\fn mul(x: u32, y: u32) u32 {
            \\    return x * y;
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("save function return values in callee preserved register", linux_arm);
        // Here, it is necessary to save the result of bar() into a
        // callee preserved register, otherwise it will be overwritten
        // by the first parameter to baz.
        case.addCompareOutput(
            \\pub fn main() void {
            \\    assert(foo() == 43);
            \\}
            \\
            \\fn foo() u32 {
            \\    return bar() + baz(42);
            \\}
            \\
            \\fn bar() u32 {
            \\    return 1;
            \\}
            \\
            \\fn baz(x: u32) u32 {
            \\    return x;
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("enums", linux_arm);
        case.addCompareOutput(
            \\const Number = enum { one, two, three };
            \\
            \\pub fn main() void {
            \\    var x: Number = .one;
            \\    var y = Number.two;
            \\    var z = @intToEnum(Number, 2);
            \\    assert(@enumToInt(x) == 0);
            \\    assert(@enumToInt(y) == 1);
            \\    assert(@enumToInt(z) == 2);
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
        ,
            "",
        );

        case.addCompareOutput(
            \\const Number = enum { one, two, three };
            \\
            \\pub fn main() void {
            \\    var x: Number = .one;
            \\    var y = Number.two;
            \\    assert(@enumToInt(x) < @enumToInt(y));
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable; // assertion failure
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("recursive fibonacci", linux_arm);
        case.addCompareOutput(
            \\pub fn main() void {
            \\    assert(fib(0) == 0);
            \\    assert(fib(1) == 1);
            \\    assert(fib(2) == 1);
            \\    assert(fib(3) == 2);
            \\    assert(fib(10) == 55);
            \\    assert(fib(20) == 6765);
            \\}
            \\
            \\fn fib(n: u32) u32 {
            \\    if (n < 2) {
            \\        return n;
            \\    } else {
            \\        return fib(n - 2) + fib(n - 1);
            \\    }
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("spilling registers", linux_arm);
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

        case.addCompareOutput(
            \\pub fn main() void {
            \\    assert(addMul(3, 4) == 357747496);
            \\}
            \\
            \\fn addMul(a: u32, b: u32) u32 {
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
            \\        const m = l * d; // 2170     
            \\        const n = m + e; // 2184     
            \\        const o = n * f; // 52416    
            \\        const p = o + g; // 52454    
            \\        const q = p * h; // 3252148  
            \\        const r = q + i; // 3252248  
            \\        const s = r * j; // 357747280
            \\        const t = s + k; // 357747490
            \\        break :blk t;
            \\    };
            \\    const y = x + a; // 357747493
            \\    const z = y + a; // 357747496
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

    {
        var case = ctx.exe("print u32s", linux_arm);
        case.addCompareOutput(
            \\pub fn main() void {
            \\    printNumberHex(0x00000000);
            \\    printNumberHex(0xaaaaaaaa);
            \\    printNumberHex(0xdeadbeef);
            \\    printNumberHex(0x31415926);
            \\}
            \\
            \\fn printNumberHex(x: u32) void {
            \\    var i: u5 = 28;
            \\    while (true) : (i -= 4) {
            \\        const digit = (x >> i) & 0xf;
            \\        asm volatile ("svc #0"
            \\            :
            \\            : [number] "{r7}" (4),
            \\              [arg1] "{r0}" (1),
            \\              [arg2] "{r1}" (@ptrToInt("0123456789abcdef") + digit),
            \\              [arg3] "{r2}" (1)
            \\            : "memory"
            \\        );
            \\
            \\        if (i == 0) break;
            \\    }
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{r7}" (4),
            \\          [arg1] "{r0}" (1),
            \\          [arg2] "{r1}" (@ptrToInt("\n")),
            \\          [arg3] "{r2}" (1)
            \\        : "memory"
            \\    );
            \\}
        ,
            \\00000000
            \\aaaaaaaa
            \\deadbeef
            \\31415926
            \\
            ,
        );
    }
}
