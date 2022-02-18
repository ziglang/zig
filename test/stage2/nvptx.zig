const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const nvptx = std.zig.CrossTarget{
    .cpu_arch = .nvptx64,
    .os_tag = .cuda,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exeUsingLlvmBackend("simple addition and subtraction", nvptx);

        case.compiles(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\pub export fn main(a: i32, out: *i32) callconv(.PtxKernel) void {
            \\    const x = add(a, 7);
            \\    var y = add(2, 0);
            \\    y -= x;
            \\    out.* = y;
            \\}
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("read special registers", nvptx);

        case.compiles(
            \\fn tid() usize {
            \\     var tid = asm volatile ("mov.u32 \t$0, %tid.x;"
            \\         : [ret] "=r" (-> u32),
            \\     );
            \\     return @as(usize, tid);
            \\}
            \\
            \\pub export fn main(a: []const i32, out: []i32) callconv(.PtxKernel) void {
            \\    const i = tid();
            \\    out[i] = a[i] + 7;
            \\}
        );
    }

    {
        var case = ctx.exeUsingLlvmBackend("address spaces", nvptx);

        case.compiles(
            \\var x: u32 addrspace(.global) = 0;
            \\
            \\pub export fn increment(out: *i32) callconv(.PtxKernel) void {
            \\    x += 1;
            \\    out.* = x;
            \\}
        );
    }
}
