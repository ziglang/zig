const std = @import("std");
const os = std.os;

pub fn build(b: *std.build.Builder) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    // TODO signal handling code has no business being in a build script.
    // this logic needs to move to a file called parent.zig which is
    // added as an executable.

    //if (!std.os.have_sigpipe_support) {
    //    return;
    //}

    // This test runs "breakpipe" as a child process and that process
    // depends on inheriting a SIGPIPE disposition of "default".
    {
        const act = os.Sigaction{
            .handler = .{ .handler = os.SIG.DFL },
            .mask = os.empty_sigset,
            .flags = 0,
        };
        try os.sigaction(os.SIG.PIPE, &act, null);
    }

    for ([_]bool{ false, true }) |keep_sigpipe| {
        const options = b.addOptions();
        options.addOption(bool, "keep_sigpipe", keep_sigpipe);
        const exe = b.addExecutable(.{
            .name = "breakpipe",
            .root_source_file = .{ .path = "breakpipe.zig" },
        });
        exe.addOptions("build_options", options);
        const run = b.addRunArtifact(exe);
        if (keep_sigpipe) {
            run.addCheck(.{ .expect_term = .{ .Signal = std.os.SIG.PIPE } });
        } else {
            run.addCheck(.{ .expect_stdout_exact = "BrokenPipe\n" });
            run.addCheck(.{ .expect_term = .{ .Exited = 123 } });
        }
        test_step.dependOn(&run.step);
    }
}
