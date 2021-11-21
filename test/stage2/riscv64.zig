const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const linux_riscv64 = std.zig.CrossTarget{
    .cpu_arch = .riscv64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("riscv64 hello world", linux_riscv64);
        // Regular old hello world
        case.addCompareOutput(
            \\pub fn main() void {
            \\    print();
            \\}
            \\
            \\fn print() void {
            \\    asm volatile ("ecall"
            \\        :
            \\        : [number] "{a7}" (64),
            \\          [arg1] "{a0}" (1),
            \\          [arg2] "{a1}" (@ptrToInt("Hello, World!\n")),
            \\          [arg3] "{a2}" ("Hello, World!\n".len)
            \\        : "rcx", "r11", "memory"
            \\    );
            \\    return;
            \\}
        ,
            "Hello, World!\n",
        );
    }
}
