const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const dep1 = b.dependency("other", .{});

    const build_runner = @import("root");
    const deps = build_runner.dependencies;
    const zon_decls = @typeInfo(deps.packages).Struct.decls;
    const pkg = @field(deps.packages, zon_decls[0].name);
    const dep2 = b.dependencyFromBuildZig(pkg.build_zig, .{});

    std.debug.assert(dep1.module("add") == dep2.module("add"));
}
