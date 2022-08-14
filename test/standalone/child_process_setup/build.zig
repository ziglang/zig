const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("child_process_setup", "main.zig");
    exe.setTarget(target);
    const run = exe.run();
    run.stdout_action = .{
        .expect_exact = "child process waiting for pipe to close...\n" ++
            "pipe closed\n",
    };
    run.step.dependOn(&exe.step);
    const test_step = b.step("test", "Run the app");
    // TODO: implement ChildProcess.fork on darwin
    if (target.isDarwin())
        return;
    test_step.dependOn(&run.step);
}
