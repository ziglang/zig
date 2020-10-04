const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const spu = std.zig.CrossTarget{
    .cpu_arch = .spu_2,
    .os_tag = .freestanding,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("SPU-II Basic Test", spu);
        case.addCompareOutput(
            \\fn killEmulator() noreturn {
            \\    asm volatile ("undefined0");
            \\    unreachable;
            \\}
            \\
            \\export fn _start() noreturn {
            \\    killEmulator();
            \\}
        , "");
    }
}
