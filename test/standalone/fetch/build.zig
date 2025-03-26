const std = @import("std");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .target = b.graph.host,
        .root_source_file = b.path("codegen.zig"),
    });

    {
        const run_codegen = b.addRunArtifact(codegen_exe);
        const example_dir = run_codegen.addOutputDirectoryArg("example");
        run_codegen.addArg("N-V-__8AABkAAAD5UlwyjuMCRESo0AsKtkhnbeeaA8Ux-LTi");
        run_codegen.addArg("subpath/example_dep_file.txt");
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "install",
            "--build-file",
        });
        run.addFileArg(example_dir.path(b, "build.zig"));
        run.addArg("--prefix");
        const install_dir = run.addOutputDirectoryArg("install");
        const check_file = b.addCheckFile(install_dir.path(b, "example_dep_file.txt"), .{
            .expected_exact = "This is an example file.\n",
        });
        test_step.dependOn(&check_file.step);
    }

    {
        const run_codegen = b.addRunArtifact(codegen_exe);
        const example_dir = run_codegen.addOutputDirectoryArg("example");
        run_codegen.addArg("N-V-__8AABkAAAD5UlwyjuMCRESo0AsKtkhnbeeaA8Ux-LTi");
        run_codegen.addArg("../foo.txt");
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "install",
            "--build-file",
        });
        run.addFileArg(example_dir.path(b, "build.zig"));
        run.addCheck(.{ .expect_stderr_match = "error: no_unpack value may not contain '..' components" });
        test_step.dependOn(&run.step);
    }

    {
        const run_codegen = b.addRunArtifact(codegen_exe);
        const example_dir = run_codegen.addOutputDirectoryArg("example");
        run_codegen.addArg("N-V-__8AABkAAAD5UlwyjuMCRESo0AsKtkhnbeeaA8Ux-LTi");
        run_codegen.addArg("foo\\\\bar.txt");
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "install",
            "--build-file",
        });
        run.addFileArg(example_dir.path(b, "build.zig"));
        run.addCheck(.{ .expect_stderr_match = "error: no_unpack value may not contain backslashes" });
        test_step.dependOn(&run.step);
    }

    {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "fetch",
            "--no-unpack",
        });
        run.addFileArg(b.path("example/example_dep_file.txt"));
        run.expectStdOutEqual("N-V-__8AABkAAAAPaKynDrx2BXIAr0Nqq1cg7FOngHE8XcYU\n");
        test_step.dependOn(&run.step);
    }
    {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "fetch",
            "--no-unpack=subpath/example_dep_file.txt",
        });
        run.addFileArg(b.path("example/example_dep_file.txt"));
        run.expectStdOutEqual("N-V-__8AABkAAAD5UlwyjuMCRESo0AsKtkhnbeeaA8Ux-LTi\n");
        test_step.dependOn(&run.step);
    }
    {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "fetch",
            "--no-unpack=subpath/../example_dep_file.txt",
        });
        run.addFileArg(b.path("example/example_dep_file.txt"));
        run.addCheck(.{ .expect_stderr_match = "error: --no-unpack path may not contain '..' components" });
        test_step.dependOn(&run.step);
    }
    {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "fetch",
            "--no-unpack=subpath\\example_dep_file.txt",
        });
        run.addFileArg(b.path("example/example_dep_file.txt"));
        run.addCheck(.{ .expect_stderr_match = "error: --no-unpack path may not contain backslashes" });
        test_step.dependOn(&run.step);
    }
}
