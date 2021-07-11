const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    const x64: std.zig.CrossTarget = .{
        .cpu_arch = .x86_64,
        .os_tag = .plan9,
    };
    const aarch64: std.zig.CrossTarget = .{
        .cpu_arch = .aarch64,
        .os_tag = .plan9,
    };
    {
        var case = ctx.exe("plan9: exiting correctly x64", x64);
        case.addCompareOutput("pub fn main() void {}", "");
    }
    {
        var case = ctx.exe("plan9: exiting correctly arm", aarch64);
        case.addCompareOutput("pub fn main() void {}", "");
    }
    {
        var case = ctx.exe("plan9: hello world", x64);
        case.addCompareOutput(
            \\pub fn main() void {
            \\    const str = "Hello World!\n";
            \\    asm volatile (
            \\        \\push $0
            \\        \\push %%r10
            \\        \\push %%r11
            \\        \\push $1
            \\        \\push $0
            \\        \\syscall
            \\        \\pop %%r11
            \\        \\pop %%r11
            \\        \\pop %%r11
            \\        \\pop %%r11
            \\        \\pop %%r11
            \\        :
            \\        // pwrite
            \\        : [syscall_number] "{rbp}" (51),
            \\          [hey] "{r11}" (@ptrToInt(str)),
            \\          [strlen] "{r10}" (str.len)
            \\        : "rcx", "rbp", "r11", "memory"
            \\    );
            \\}
        , "");
    }
}
