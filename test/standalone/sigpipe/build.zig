const std = @import("std");
const os = std.os;

pub fn build(b: *std.build.Builder) !void {
    const test_step = b.step("test", "Run the tests");

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
        const run = exe.run();
        if (keep_sigpipe) {
            run.expected_term = .{ .Signal = std.os.SIG.PIPE };
        } else {
            run.stdout_action = .{ .expect_exact = "BrokenPipe\n" };
            run.expected_term = .{ .Exited = 123 };
        }
        test_step.dependOn(&run.step);
    }
}
