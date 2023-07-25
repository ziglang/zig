const std = @import("std");
const fs = std.fs;

const Build = std.Build;
const Step = std.Build.Step;

/// In this function the stderr mutex has already been locked.
pub fn dumpBadGetPathHelp(
    s: *Step,
    stderr: fs.File,
    src_builder: *Build,
    asking_step: ?*Step,
) anyerror!void {
    const w = stderr.writer();
    try w.print(
        \\getPath() was called on a GeneratedFile that wasn't built yet.
        \\  source package path: {s}
        \\  Is there a missing Step dependency on step '{s}'?
        \\
    , .{
        src_builder.build_root.path orelse ".",
        s.name,
    });

    const tty_config = std.io.tty.detectConfig(stderr);
    tty_config.setColor(w, .red) catch {};
    try stderr.writeAll("    The step was created by this stack trace:\n");
    tty_config.setColor(w, .reset) catch {};

    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        try w.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        return;
    };
    const ally = debug_info.allocator;
    std.debug.writeStackTrace(s.getStackTrace(), w, ally, debug_info, tty_config) catch |err| {
        try stderr.writer().print("Unable to dump stack trace: {s}\n", .{@errorName(err)});
        return;
    };
    if (asking_step) |as| {
        tty_config.setColor(w, .red) catch {};
        try stderr.writeAll("    The step that is missing a dependency on the above step was created by this stack trace:\n");
        tty_config.setColor(w, .reset) catch {};

        std.debug.writeStackTrace(as.getStackTrace(), w, ally, debug_info, tty_config) catch |err| {
            try stderr.writer().print("Unable to dump stack trace: {s}\n", .{@errorName(err)});
            return;
        };
    }

    tty_config.setColor(w, .red) catch {};
    try stderr.writeAll("    Hope that helps. Proceeding to panic.\n");
    tty_config.setColor(w, .reset) catch {};
}
