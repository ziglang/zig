const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "create-file",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const run_random_with_sideeffects_first = b.addRunArtifact(exe);
        run_random_with_sideeffects_first.setName("run with side-effects (first)");
        run_random_with_sideeffects_first.has_side_effects = true;

        const run_random_with_sideeffects_second = b.addRunArtifact(exe);
        run_random_with_sideeffects_second.setName("run with side-effects (second)");
        run_random_with_sideeffects_second.has_side_effects = true;

        // ensure that "second" runs after "first"
        run_random_with_sideeffects_second.step.dependOn(&run_random_with_sideeffects_first.step);

        const first_output = run_random_with_sideeffects_first.addOutputFileArg("a.txt");
        const second_output = run_random_with_sideeffects_second.addOutputFileArg("a.txt");

        const expect_uncached_dependencies = CheckOutputCaching.init(b, false, &.{ first_output, second_output });
        test_step.dependOn(&expect_uncached_dependencies.step);

        const expect_unequal_output = CheckPathEquality.init(b, true, &.{ first_output, second_output });
        test_step.dependOn(&expect_unequal_output.step);

        const check_first_output = b.addCheckFile(first_output, .{ .expected_matches = &.{"a.txt"} });
        test_step.dependOn(&check_first_output.step);
        const check_second_output = b.addCheckFile(second_output, .{ .expected_matches = &.{"a.txt"} });
        test_step.dependOn(&check_second_output.step);
    }

    {
        const run_random_without_sideeffects_1 = b.addRunArtifact(exe);
        run_random_without_sideeffects_1.setName("run without side-effects (A)");

        const run_random_without_sideeffects_2 = b.addRunArtifact(exe);
        run_random_without_sideeffects_2.setName("run without side-effects (B)");

        run_random_without_sideeffects_2.step.dependOn(&run_random_without_sideeffects_1.step);

        const first_output = run_random_without_sideeffects_1.addOutputFileArg("a.txt");
        const second_output = run_random_without_sideeffects_2.addOutputFileArg("a.txt");

        const expect_cached_dependencies = CheckOutputCaching.init(b, true, &.{second_output});
        test_step.dependOn(&expect_cached_dependencies.step);

        const expect_equal_output = CheckPathEquality.init(b, true, &.{ first_output, second_output });
        test_step.dependOn(&expect_equal_output.step);

        const check_first_output = b.addCheckFile(first_output, .{ .expected_matches = &.{"a.txt"} });
        test_step.dependOn(&check_first_output.step);
        const check_second_output = b.addCheckFile(second_output, .{ .expected_matches = &.{"a.txt"} });
        test_step.dependOn(&check_second_output.step);
    }
}

const CheckOutputCaching = struct {
    step: std.Build.Step,
    expect_caching: bool,

    pub fn init(owner: *std.Build, expect_caching: bool, output_paths: []const std.Build.LazyPath) *CheckOutputCaching {
        const check = owner.allocator.create(CheckOutputCaching) catch @panic("OOM");
        check.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "check output caching",
                .owner = owner,
                .makeFn = make,
            }),
            .expect_caching = expect_caching,
        };
        for (output_paths) |output_path| {
            output_path.addStepDependencies(&check.step);
        }
        return check;
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const check: *CheckOutputCaching = @fieldParentPtr("step", step);

        for (step.dependencies.items) |dependency| {
            if (check.expect_caching) {
                if (dependency.result_cached) continue;
                return step.fail("expected '{s}' step to be cached, but it was not", .{dependency.name});
            } else {
                if (!dependency.result_cached) continue;
                return step.fail("expected '{s}' step to not be cached, but it was", .{dependency.name});
            }
        }
    }
};

const CheckPathEquality = struct {
    step: std.Build.Step,
    expected_equality: bool,
    output_paths: []const std.Build.LazyPath,

    pub fn init(owner: *std.Build, expected_equality: bool, output_paths: []const std.Build.LazyPath) *CheckPathEquality {
        const check = owner.allocator.create(CheckPathEquality) catch @panic("OOM");
        check.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "check output path equality",
                .owner = owner,
                .makeFn = make,
            }),
            .expected_equality = expected_equality,
            .output_paths = owner.allocator.dupe(std.Build.LazyPath, output_paths) catch @panic("OOM"),
        };
        for (output_paths) |output_path| {
            output_path.addStepDependencies(&check.step);
        }
        return check;
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        const check: *CheckPathEquality = @fieldParentPtr("step", step);
        std.debug.assert(check.output_paths.len != 0);
        for (check.output_paths[0 .. check.output_paths.len - 1], check.output_paths[1..]) |a, b| {
            try std.testing.expectEqual(check.expected_equality, std.mem.eql(u8, a.getPath(step.owner), b.getPath(step.owner)));
        }
    }
};
