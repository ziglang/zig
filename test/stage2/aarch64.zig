const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const macos_aarch64 = std.zig.CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .macos,
};

pub fn addCases(ctx: *TestContext) !void {
    // TODO enable when we add codesigning to the self-hosted linker
    // related to #6971
    if (false) {
        var case = ctx.exe("hello world with updates", macos_aarch64);

        // Regular old hello world
        case.addCompareOutput(
            \\export fn _start() noreturn {
            \\    print();
            \\
            \\    exit();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (4),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{x2}" (14)
            \\        : "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (1),
            \\          [arg1] "{x0}" (0)
            \\        : "memory"
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
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (4),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{x2}" (104)
            \\        : "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (1),
            \\          [arg1] "{x0}" (0)
            \\        : "memory"
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
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (4),
            \\          [arg1] "{x0}" (1),
            \\          [arg2] "{x1}" (@ptrToInt("What is up? This is a longer message that will force the data to be relocated in virtual address space.\n")),
            \\          [arg3] "{x2}" (104)
            \\        : "memory"
            \\    );
            \\    return;
            \\}
            \\
            \\fn exit() noreturn {
            \\    asm volatile ("svc #0x80"
            \\        :
            \\        : [number] "{x16}" (1),
            \\          [arg1] "{x0}" (0)
            \\        : "memory"
            \\    );
            \\    unreachable;
            \\}
        ,
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\What is up? This is a longer message that will force the data to be relocated in virtual address space.
            \\
        );
    }
}
