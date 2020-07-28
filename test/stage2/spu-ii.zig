const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

const spu = std.zig.CrossTarget{
    .cpu_arch = .spu_2,
    .os_tag = .freestanding,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("SPU-II Basic Test", spu);
        // TODO: detect that this isn't noreturn, and implement astGenExpr
        // for the while(true){}
        case.addCompareOutput(
            \\fn killEmulator() noreturn {
            \\    // Probably kills the emulator, but no guarantee, so loop forever if it
            \\    // doesn't.
            \\    asm volatile ("undefined0");
            \\    // while (true) {}
            \\}
            \\
            \\export fn _start() noreturn {
            \\    killEmulator();
            \\}
        , "");
    }
}
