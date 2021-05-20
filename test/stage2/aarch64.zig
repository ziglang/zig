const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const linux_aarch64 = std.zig.CrossTarget{
    .cpu_arch = .aarch64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("linux_aarch64 hello world", linux_aarch64);
        // Regular old hello world
        case.addCompareOutput(
            \\pub export fn _start() noreturn {
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
}
