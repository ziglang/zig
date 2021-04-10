const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const linux_arm = std.zig.CrossTarget{
    .cpu_arch = .arm,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("linux_arm hello world", linux_arm);
        // Regular old hello world
        case.addCompareOutput(
            \\export fn _start() noreturn {
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
            \\export fn _start() noreturn {
            \\    print(id(14));
            \\    exit();
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
        var case = ctx.exe("non-leaf functions", linux_arm);
        // Testing non-leaf functions
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    foo();
            \\    exit();
            \\}
            \\
            \\fn foo() void {
            \\    bar();
            \\}
            \\
            \\fn bar() void {}
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
            "",
        );
    }

    {
        var case = ctx.exe("arithmetic operations", linux_arm);

        // Add two numbers
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print(2, 4);
            \\    print(1, 7);
            \\    exit();
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
            "12345612345678",
        );

        // Subtract two numbers
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print(10, 5);
            \\    print(4, 3);
            \\    exit();
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
            "123451",
        );

        // Bitwise And
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print(8, 9);
            \\    print(3, 7);
            \\    exit();
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
            "12345678123",
        );

        // Bitwise Or
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print(4, 2);
            \\    print(3, 7);
            \\    exit();
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
            "1234561234567",
        );

        // Bitwise Xor
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print(42, 42);
            \\    print(3, 5);
            \\    exit();
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
            "123456",
        );
    }

    {
        var case = ctx.exe("if statements", linux_arm);
        // Simple if statement in assert
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: u32 = 123;
            \\    var y: u32 = 42;
            \\    assert(x > y);
            \\    exit();
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
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
            "",
        );
    }

    {
        var case = ctx.exe("while loops", linux_arm);
        // Simple while loop with assert
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    var x: u32 = 2020;
            \\    var i: u32 = 0;
            \\    while (x > 0) {
            \\        x -= 2;
            \\        i += 1;
            \\    }
            \\    assert(i == 1010);
            \\    exit();
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
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
            "",
        );
    }

    {
        var case = ctx.exe("integer multiplication", linux_arm);
        // Simple u32 integer multiplication
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(mul(1, 1) == 1);
            \\    assert(mul(42, 1) == 42);
            \\    assert(mul(1, 42) == 42);
            \\    assert(mul(123, 42) == 5166);
            \\    exit();
            \\}
            \\
            \\fn mul(x: u32, y: u32) u32 {
            \\    return x * y;
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
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
            "",
        );
    }

    {
        var case = ctx.exe("save function return values in callee preserved register", linux_arm);
        // Here, it is necessary to save the result of bar() into a
        // callee preserved register, otherwise it will be overwritten
        // by the first parameter to baz.
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    assert(foo() == 43);
            \\    exit();
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
            "",
        );
    }
}
