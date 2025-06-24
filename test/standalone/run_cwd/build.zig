pub fn build(b: *Build) void {
    const exe = b.addExecutable(.{
        .name = "check_file_exists",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = .Debug,
            .root_source_file = b.path("check_file_exists.zig"),
        }),
    });

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    test_step.dependOn(addCheck(b, exe, ".", null));
    test_step.dependOn(addCheck(b, exe, "..", b.path("..")));
    test_step.dependOn(addCheck(b, exe, "exe dir", exe.getEmittedBin().dirname()));
    test_step.dependOn(addCheck(b, exe, "exe dir/..", exe.getEmittedBin().dirname().dirname()));
    test_step.dependOn(addCheck(b, exe, "./empty_dir", b.path("empty_dir")));
}

fn addCheck(b: *Build, exe: *Build.Step.Compile, cwd_name: []const u8, opt_cwd: ?Build.LazyPath) *Build.Step {
    const run = b.addRunArtifact(exe);
    if (opt_cwd) |cwd| run.setCwd(cwd);
    run.addFileArg(b.path("file_that_exists.txt"));
    run.setName(b.fmt("check in '{s}'", .{cwd_name}));
    run.expectExitCode(0);
    return &run.step;
}

const Build = @import("std").Build;
