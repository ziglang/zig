const std = @import("std");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    {
        const codegen_exe = b.addExecutable(.{
            .name = "codegen",
            .target = b.host,
            .root_source_file = b.path("codegen.zig"),
        });
        const run_codegen = b.addRunArtifact(codegen_exe);
        const example_dir = run_codegen.addOutputDirectoryArg("example");

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
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "--build-file",
        });
        run.addFileArg(b.path("unpacktrue/build.zig"));
        run.addCheck(.{ .expect_stderr_match = "error: unpack cannot be set to true, omit it instead" });
        test_step.dependOn(&run.step);
    }

    {
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "fetch",
            "--no-unpack",
        });
        run.addFileArg(b.path("example/example_dep_file.txt"));
        run.expectStdOutEqual("12200f68aca70ebc76057200af436aab5720ec53a780713c5dc614825db42a39dbfb\n");
        test_step.dependOn(&run.step);
    }
}
