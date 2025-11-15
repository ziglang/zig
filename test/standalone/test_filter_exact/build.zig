pub fn build(b: *std.Build) !void {
    const root_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
    });

    const test_step = b.step("test", "Run the tests");

    const test_runner: std.Build.Step.Compile.TestRunner = .{
        .path = b.path("test_runner.zig"),
        .mode = .simple,
    };

    for (passing_filters) |filters| {
        const test_exe = b.addTest(.{
            .root_module = root_module,
            .filters = filters,
            .exact_filters = true,
            .test_runner = test_runner,
        });

        const run = b.addRunArtifact(test_exe);

        for (filters) |filter| {
            run.addCheck(.{ .expect_stdout_match = filter });
        }
        test_step.dependOn(&run.step);
    }

    var errors: std.ArrayListUnmanaged([]const u8) = .empty;

    for (misspelt_filters) |f| {
        const filters: [2][]const u8 = .{ f[0][0], if (f.len == 2) f[1][0] else undefined };

        const test_exe = b.addTest(.{
            .root_module = root_module,
            .filters = filters[0..f.len],
            .exact_filters = true,
        });

        try errors.append(b.allocator, "error: could not find all requested tests");
        for (f) |x| {
            if (x[1]) {
                try errors.append(b.allocator, b.fmt("note: no test '{s}' found", .{x[0]}));
            }
        }
        test_exe.expect_errors = .{ .exact = try errors.toOwnedSlice(b.allocator) };
        test_step.dependOn(&test_exe.step);
    }

    const fqn_clash_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("fqn_clash.zig"),
            .target = b.graph.host,
        }),
        .filters = &.{"fqn_clash.test.test.name"},
        .exact_filters = true,
        .test_runner = test_runner,
    });

    const fqn_run = b.addRunArtifact(fqn_clash_exe);
    fqn_run.expectStdOutEqual(
        \\fqn_clash.test.test.name
        \\fqn_clash.test.test.name
        \\
    );

    test_step.dependOn(&fqn_run.step);
}

const passing_filters = [_][]const []const u8{
    &.{"main.struct_name.test.testname"},
    &.{ "main.struct_name.test.testname", "main.test.struct_name.testname" },
    &.{ "main.test.struct_name.testname", "main.struct_name.test.testname" },
    &.{"main.test.struct_name.testname"},
};

const misspelt_filters = [_][]const struct { []const u8, bool }{
    &.{.{ "main.struct_name.test.testnam", true }},
    &.{.{ "ain.struct_name.test.testname", true }},
    &.{.{ "main.test.struct_name.testnam", true }},
    &.{.{ "ain.test.struct_name.testname", true }},

    &.{ .{ "main.struct_name.test.testnam", true }, .{ "main.test.struct_name.testname", false } },
    &.{ .{ "main.struct_name.test.testnam", true }, .{ "main.test.struct_name.testnam", true } },
    &.{ .{ "main.struct_name.test.testnam", true }, .{ "ain.test.struct_name.testname", true } },

    &.{ .{ "ain.struct_name.test.testname", true }, .{ "main.test.struct_name.testname", false } },
    &.{ .{ "ain.struct_name.test.testname", true }, .{ "main.test.struct_name.testnam", true } },
    &.{ .{ "ain.struct_name.test.testname", true }, .{ "ain.test.struct_name.testname", true } },

    &.{ .{ "main.test.struct_name.testnam", true }, .{ "main.struct_name.test.testname", false } },
    &.{ .{ "main.test.struct_name.testnam", true }, .{ "main.struct_name.test.testnam", true } },
    &.{ .{ "main.test.struct_name.testnam", true }, .{ "ain.struct_name.test.testname", true } },

    &.{ .{ "ain.test.struct_name.testname", true }, .{ "main.struct_name.test.testname", false } },
    &.{ .{ "ain.test.struct_name.testname", true }, .{ "main.struct_name.test.testnam", true } },
    &.{ .{ "ain.test.struct_name.testname", true }, .{ "ain.struct_name.test.testname", true } },

    &.{ .{ "main.struct_name.test.testname", false }, .{ "main.test.struct_name.testnam", true } },
    &.{ .{ "main.struct_name.test.testname", false }, .{ "ain.test.struct_name.testname", true } },

    &.{ .{ "main.test.struct_name.testname", false }, .{ "main.struct_name.test.testnam", true } },
    &.{ .{ "main.test.struct_name.testname", false }, .{ "ain.struct_name.test.testname", true } },
};

const std = @import("std");
