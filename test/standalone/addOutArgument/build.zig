const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const touch_exe = b.addExecutable("touch-file", "touch-file.zig");
    const verify_exe = b.addExecutable("verify-file", "verify-file.zig");

    const runner_touch = touch_exe.run();
    const out_file_source = runner_touch.addOutArgument("{s}", "testfile.txt");

    const runner_verify = verify_exe.run();

    // the addFileSourceArg must automatically create a dependency
    // on the `runner_touch` step.
    runner_verify.addFileSourceArg(out_file_source);

    b.getInstallStep().dependOn(&runner_verify.step);
}
