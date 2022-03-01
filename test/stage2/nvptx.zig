const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = addPtx(ctx, "nvptx: simple addition and subtraction");

        case.compiles(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\pub export fn add_and_substract(a: i32, out: *i32) callconv(.PtxKernel) void {
            \\    const x = add(a, 7);
            \\    var y = add(2, 0);
            \\    y -= x;
            \\    out.* = y;
            \\}
        );
    }

    {
        var case = addPtx(ctx, "nvptx: read special registers");

        case.compiles(
            \\fn threadIdX() usize {
            \\     var tid = asm volatile ("mov.u32 \t$0, %tid.x;"
            \\         : [ret] "=r" (-> u32),
            \\     );
            \\     return @as(usize, tid);
            \\}
            \\
            \\pub export fn special_reg(a: []const i32, out: []i32) callconv(.PtxKernel) void {
            \\    const i = threadIdX();
            \\    out[i] = a[i] + 7;
            \\}
        );
    }

    {
        var case = addPtx(ctx, "nvptx: address spaces");

        case.compiles(
            \\var x: i32 addrspace(.global) = 0;
            \\
            \\pub export fn increment(out: *i32) callconv(.PtxKernel) void {
            \\    x += 1;
            \\    out.* = x;
            \\}
        );
    }
}

const nvptx_target = std.zig.CrossTarget{
    .cpu_arch = .nvptx64,
    .os_tag = .cuda,
};

pub fn addPtx(
    ctx: *TestContext,
    name: []const u8,
) *TestContext.Case {
    ctx.cases.append(TestContext.Case{
        .name = name,
        .target = nvptx_target,
        .updates = std.ArrayList(TestContext.Update).init(ctx.cases.allocator),
        .output_mode = .Obj,
        .files = std.ArrayList(TestContext.File).init(ctx.cases.allocator),
        .link_libc = false,
        .backend = .llvm,
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}
