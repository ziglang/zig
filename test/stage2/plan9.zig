const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .x86_64,
        .os_tag = .plan9,
    };
    {
        var case = ctx.exe("plan9: exiting correctly", target);
        case.addCompareOutput("pub fn main() void {}", "");
    }
    {
        var case = ctx.exe("plan9: hello world", target);
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
