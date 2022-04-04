const std = @import("std");

fn cmpFn(stdout: ?[]const u8) bool {
    std.debug.assert(stdout != null);
    const stdout_unwr: []const u8 = stdout.?;
    const expected = "/ok";
    if (!std.mem.eql(u8, expected, stdout_unwr[stdout_unwr.len - 3 .. stdout_unwr.len])) {
        std.debug.print(
            \\
            \\========= Expected this stderr: =========
            \\...{s}
            \\========= But found: ====================
            \\...{s}
            \\
        , .{ expected, stdout_unwr[stdout_unwr.len - 3 .. stdout_unwr.len] });
    }
    return true;
}
pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("write_path", "write_path.zig");
    const run_cmd = exe.run();
    run_cmd.stdout_action = .{
        .expect_custom = cmpFn,
    };
    //run_cmd.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run_cmd.step);
}
