pub fn build(b: *std.Build) !void {
    const run_zig_build = b.addSystemCommand(&[_][]const u8{
        b.graph.zig_exe,
        "build",
        "printfoo",
    });
    run_zig_build.setCwd(b.path("capital"));
    run_zig_build.expectStdOutEqual("Foo\n");
    b.default_step.dependOn(&run_zig_build.step);

    const printfoo = try b.allocator.create(std.Build.Step);
    printfoo.* = std.Build.Step.init(.{
        .id = .custom,
        .name = "printfoo",
        .owner = b,
        .makeFn = printFoo,
    });
    b.step("printfoo", "").dependOn(printfoo);
}

fn printFoo(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = step;
    _ = options;
    try std.io.getStdOut().writer().writeAll("Foo\n");
}

const std = @import("std");
