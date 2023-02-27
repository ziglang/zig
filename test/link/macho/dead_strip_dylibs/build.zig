const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    {
        // Without -dead_strip_dylibs we expect `-la` to include liba.dylib in the final executable
        const exe = createScenario(b, optimize);

        const check = exe.checkObject(.macho);
        check.checkStart("cmd LOAD_DYLIB");
        check.checkNext("name {*}Cocoa");

        check.checkStart("cmd LOAD_DYLIB");
        check.checkNext("name {*}libobjc{*}.dylib");

        test_step.dependOn(&check.step);

        const run_cmd = exe.run();
        test_step.dependOn(&run_cmd.step);
    }

    {
        // With -dead_strip_dylibs, we should include liba.dylib as it's unreachable
        const exe = createScenario(b, optimize);
        exe.dead_strip_dylibs = true;

        const run_cmd = exe.run();
        run_cmd.expected_term = .{ .Exited = @bitCast(u8, @as(i8, -2)) }; // should fail
        test_step.dependOn(&run_cmd.step);
    }
}

fn createScenario(b: *std.Build, optimize: std.builtin.OptimizeMode) *std.Build.CompileStep {
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    exe.linkFramework("Cocoa");
    return exe;
}
