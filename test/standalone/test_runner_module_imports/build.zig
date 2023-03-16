const std = @import("std");

pub fn build(b: *std.Build) void {
    const t = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });
    t.setTestRunner("test_runner/main.zig");

    const module1 = b.createModule(.{ .source_file = .{ .path = "module1/main.zig" } });
    const module2 = b.createModule(.{
        .source_file = .{ .path = "module2/main.zig" },
        .dependencies = &.{.{ .name = "module1", .module = module1 }},
    });

    t.addModule("module2", module2);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&t.run().step);
}
