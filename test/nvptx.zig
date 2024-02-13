const std = @import("std");
const Cases = @import("src/Cases.zig");

pub fn addCases(ctx: *Cases, b: *std.Build) !void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .nvptx64,
        .os_tag = .cuda,
    });

    {
        var case = addPtx(ctx, target, "simple addition and subtraction");

        case.addCompile(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\pub export fn add_and_substract(a: i32, out: *i32) callconv(.Kernel) void {
            \\    const x = add(a, 7);
            \\    var y = add(2, 0);
            \\    y -= x;
            \\    out.* = y;
            \\}
        );
    }

    {
        var case = addPtx(ctx, target, "read special registers");

        case.addCompile(
            \\fn threadIdX() u32 {
            \\    return asm ("mov.u32 \t%[r], %tid.x;"
            \\       : [r] "=r" (-> u32),
            \\    );
            \\}
            \\
            \\pub export fn special_reg(a: []const i32, out: []i32) callconv(.Kernel) void {
            \\    const i = threadIdX();
            \\    out[i] = a[i] + 7;
            \\}
        );
    }

    {
        var case = addPtx(ctx, target, "address spaces");

        case.addCompile(
            \\var x: i32 addrspace(.global) = 0;
            \\
            \\pub export fn increment(out: *i32) callconv(.Kernel) void {
            \\    x += 1;
            \\    out.* = x;
            \\}
        );
    }

    {
        var case = addPtx(ctx, target, "reduce in shared mem");
        case.addCompile(
            \\fn threadIdX() u32 {
            \\    return asm ("mov.u32 \t%[r], %tid.x;"
            \\       : [r] "=r" (-> u32),
            \\    );
            \\}
            \\
            \\ var _sdata: [1024]f32 addrspace(.shared) = undefined;
            \\ pub export fn reduceSum(d_x: []const f32, out: *f32) callconv(.Kernel) void {
            \\     var sdata: *addrspace(.generic) [1024]f32 = @addrSpaceCast(&_sdata);
            \\     const tid: u32 = threadIdX();
            \\     var sum = d_x[tid];
            \\     sdata[tid] = sum;
            \\     asm volatile ("bar.sync \t0;");
            \\     var s: u32 = 512;
            \\     while (s > 0) : (s = s >> 1) {
            \\         if (tid < s) {
            \\             sum += sdata[tid + s];
            \\             sdata[tid] = sum;
            \\         }
            \\         asm volatile ("bar.sync \t0;");
            \\     }
            \\
            \\     if (tid == 0) {
            \\         out.* = sum;
            \\     }
            \\ }
        );
    }
}

fn addPtx(ctx: *Cases, target: std.Build.ResolvedTarget, name: []const u8) *Cases.Case {
    ctx.cases.append(.{
        .name = name,
        .target = target,
        .updates = std.ArrayList(Cases.Update).init(ctx.cases.allocator),
        .output_mode = .Obj,
        .deps = std.ArrayList(Cases.DepModule).init(ctx.cases.allocator),
        .link_libc = false,
        .backend = .llvm,
        // Bug in Debug mode
        .optimize_mode = .ReleaseSafe,
    }) catch @panic("out of memory");
    return &ctx.cases.items[ctx.cases.items.len - 1];
}
