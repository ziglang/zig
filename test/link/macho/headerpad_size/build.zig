const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.headerpad_size = 0x10000;

    const check = exe.checkObject(.macho);
    check.checkStart("sectname __text");
    check.checkNext("offset {offset}");
    check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });

    test_step.dependOn(&check.step);

    const run = exe.run();
    test_step.dependOn(&run.step);
}
