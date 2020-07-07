const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.c11("empty start function", linux_x64,
        \\export fn _start() noreturn {}
    ,
        \\_Noreturn void _start(void) {}
        \\
    );
    ctx.c11("less empty start function", linux_x64,
        \\fn main() noreturn {}
        \\
        \\export fn _start() noreturn {
        \\	main();
        \\}
    ,
        \\_Noreturn void main(void);
        \\
        \\_Noreturn void _start(void) {
        \\	main();
        \\}
        \\
        \\_Noreturn void main(void) {}
        \\
    );
}
