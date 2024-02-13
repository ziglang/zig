const std = @import("std");
const build_options = @import("build_options");

pub usingnamespace if (build_options.keep_sigpipe) struct {
    pub const std_options = .{
        .keep_sigpipe = true,
    };
} else struct {};

pub fn main() !void {
    const pipe = try std.os.pipe();
    std.os.close(pipe[0]);
    _ = std.os.write(pipe[1], "a") catch |err| switch (err) {
        error.BrokenPipe => {
            try std.io.getStdOut().writer().writeAll("BrokenPipe\n");
            std.os.exit(123);
        },
        else => |e| return e,
    };
    unreachable;
}
