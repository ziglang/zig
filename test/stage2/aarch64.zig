const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const macos_aarch64 = std.zig.CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .macos,
};

const linux_aarch64 = std.zig.CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("hello world with updates", macos_aarch64);

        // Regular old hello world
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) void;
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit(0);
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("Hello, World!\n");
            \\    const len = 14;
            \\    write(1, msg, len);
            \\}
        ,
            "Hello, World!\n",
        );

        // Now change the message only
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) void;
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit(0);
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    write(1, msg, len);
            \\}
        ,
            "What is up? This is a longer message that will force the data to be relocated in virtual address space.\n",
        );

        // Now we print it twice.
        case.addCompareOutput(
            \\extern "c" fn write(usize, usize, usize) void;
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\export fn _start() noreturn {
            \\    print();
            \\    print();
            \\
            \\    exit(0);
            \\}
            \\
            \\fn print() void {
            \\    const msg = @ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n");
            \\    const len = 104;
            \\    write(1, msg, len);
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }

    {
        var case = ctx.exe("linux_aarch64 hello world", linux_aarch64);
        // Regular old hello world
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\    exit();
            \\}
            \\
            \\fn doNothing() void {}
            \\
            \\fn answer() u64 {
            \\    return 0x1234abcd1234abcd;
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
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("svc #0"
            \\        :
            \\        : [number] "{x8}" (93),
            \\          [arg1] "{x0}" (0)
            \\        : "memory", "cc"
            \\    );
            \\    unreachable;
            \\}
        ,
            "Hello, World!\n",
        );
    }

    {
        var case = ctx.exe("exit fn taking argument", macos_aarch64);

        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    exit(0);
            \\}
            \\
            \\fn exit(ret: usize) noreturn {
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (1),
            \\          [arg1] "{x0}" (ret)
            \\        : "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            "",
        );
    }

    {
        var case = ctx.exe("exit fn taking argument", linux_aarch64);

        case.addCompareOutput(
            \\export fn _start() noreturn {
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
        var case = ctx.exe("only libc exit", macos_aarch64);

        // This test case covers an infrequent scenarion where the string table *may* be relocated
        // into the position preceeding the symbol table which results in a dyld error.
        case.addCompareOutput(
            \\extern "c" fn exit(usize) noreturn;
            \\
            \\export fn _start() noreturn {
            \\    exit(0);
            \\}
        ,
            "",
        );
    }
}
