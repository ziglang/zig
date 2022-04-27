const std = @import("std");
const CrossTarget = std.zig.CrossTarget;
const TestContext = @import("../../src/test.zig").TestContext;

const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};
const macos_x64 = CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .macos,
};
const all_targets: []const CrossTarget = &[_]CrossTarget{
    linux_x64,
    macos_x64,
};

pub fn addCases(ctx: *TestContext) !void {
    for (all_targets) |target| {
        // TODO port this to the new test harness
        var case = ctx.exe("basic import", target);
        case.addCompareOutput(
            \\pub fn main() void {
            \\    @import("print.zig").print();
            \\}
        ,
            "Hello, World!\n",
        );
        switch (target.getOsTag()) {
            .linux => try case.files.append(.{
                .src = 
                \\pub fn print() void {
                \\    asm volatile ("syscall"
                \\        :
                \\        : [number] "{rax}" (@as(usize, 1)),
                \\          [arg1] "{rdi}" (@as(usize, 1)),
                \\          [arg2] "{rsi}" (@ptrToInt("Hello, World!\n")),
                \\          [arg3] "{rdx}" (@as(usize, 14))
                \\        : "rcx", "r11", "memory"
                \\    );
                \\    return;
                \\}
                ,
                .path = "print.zig",
            }),
            .macos => try case.files.append(.{
                .src = 
                \\extern "c" fn write(usize, usize, usize) usize;
                \\
                \\pub fn print() void {
                \\    _ = write(1, @ptrToInt("Hello, World!\n"), 14);
                \\}
                ,
                .path = "print.zig",
            }),
            else => unreachable,
        }
    }
}
