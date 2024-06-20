const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const LazyPath = Build.LazyPath;
const Step = Build.Step;
const Run = Step.Run;
const WriteFile = Step.WriteFile;

pub fn build(b: *Build) void {
    const nb_files = b.option(u32, "nb_files", "Number of c files to generate.") orelse 10;

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    // generate c files
    const files = b.allocator.alloc(LazyPath, nb_files) catch unreachable;
    defer b.allocator.free(files);
    {
        for (files[0 .. nb_files - 1], 1..nb_files) |*file, i| {
            const wf = WriteFile.create(b);
            file.* = wf.add(b.fmt("src_{}.c", .{i}), b.fmt(
                \\extern int foo_0();
                \\extern int bar_{}();
                \\extern int one_{};
                \\int one_{} = 1;
                \\int foo_{}() {{ return one_{} + foo_0(); }}
                \\int bar_{}() {{ return bar_{}(); }}
            , .{ i - 1, i - 1, i, i, i - 1, i, i - 1 }));
        }

        {
            const wf = WriteFile.create(b);
            files[nb_files - 1] = wf.add("src_last.c", b.fmt(
                \\extern int foo_0();
                \\extern int bar_{}();
                \\extern int one_{};
                \\int foo_last() {{ return one_{} + foo_0(); }}
                \\int bar_last() {{ return bar_{}(); }}
            , .{ nb_files - 1, nb_files - 1, nb_files - 1, nb_files - 1 }));
        }
    }

    add(b, test_step, files, .Debug);
    add(b, test_step, files, .ReleaseSafe);
    add(b, test_step, files, .ReleaseSmall);
    add(b, test_step, files, .ReleaseFast);
}

fn add(b: *Build, test_step: *Step, files: []const LazyPath, optimize: std.builtin.OptimizeMode) void {
    const flags = [_][]const u8{
        "-Wall",
        "-std=c11",
    };

    // all files at once
    {
        const mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        for (files) |file| {
            mod.addCSourceFile(.{ .file = file, .flags = &flags });
        }

        const exe = b.addExecutable2(.{
            .name = "test1",
            .root_module = mod,
        });

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.skip_foreign_checks = true;
        run_cmd.expectExitCode(0);

        test_step.dependOn(&run_cmd.step);
    }

    // using static librairies
    {
        const a_mod = b.createModule(.{
            .root_source_file = null,
            .target = b.graph.host,
            .optimize = optimize,
        });
        const b_mod = b.createModule(.{
            .root_source_file = null,
            .target = b.graph.host,
            .optimize = optimize,
        });
        for (files, 1..) |file, i| {
            const lib_mod = if (i & 1 == 0) a_mod else b_mod;
            lib_mod.addCSourceFile(.{ .file = file, .flags = &flags });
        }

        const a_lib = b.addLibrary(.{
            .name = "test2_a",
            .root_module = a_mod,
            .linkage = .static,
        });
        const b_lib = b.addLibrary(.{
            .name = "test2_b",
            .root_module = b_mod,
            .linkage = .static,
        });

        const main_mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        main_mod.linkLibrary(a_lib);
        main_mod.linkLibrary(b_lib);

        const exe = b.addExecutable2(.{
            .name = "test2",
            .root_module = main_mod,
        });

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.skip_foreign_checks = true;
        run_cmd.expectExitCode(0);

        test_step.dependOn(&run_cmd.step);
    }

    // using static librairies and object files
    {
        const a_mod = b.createModule(.{
            .root_source_file = null,
            .target = b.graph.host,
            .optimize = optimize,
        });
        const b_mod = b.createModule(.{
            .root_source_file = null,
            .target = b.graph.host,
            .optimize = optimize,
        });
        for (files, 1..) |file, i| {
            const obj_mod = b.createModule(.{
                .root_source_file = null,
                .target = b.graph.host,
                .optimize = optimize,
            });
            obj_mod.addCSourceFile(.{ .file = file, .flags = &flags });

            const obj = b.addObject2(.{
                .name = b.fmt("obj_{}", .{i}),
                .root_module = obj_mod,
            });

            const lib_mod = if (i & 1 == 0) a_mod else b_mod;
            lib_mod.addObject(obj);
        }

        const a_lib = b.addLibrary(.{
            .name = "test3_a",
            .root_module = a_mod,
            .linkage = .static,
        });
        const b_lib = b.addLibrary(.{
            .name = "test3_b",
            .root_module = b_mod,
            .linkage = .static,
        });

        const main_mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        main_mod.linkLibrary(a_lib);
        main_mod.linkLibrary(b_lib);

        const exe = b.addExecutable2(.{
            .name = "test3",
            .root_module = main_mod,
        });

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.skip_foreign_checks = true;
        run_cmd.expectExitCode(0);

        test_step.dependOn(&run_cmd.step);
    }
}
