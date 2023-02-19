const std = @import("std");
const build_options = @import("build_options");

pub const std_options = if (build_options.keep_sigpipe) struct {
    pub const keep_sigpipe = true;
} else struct {
    // intentionally not setting keep_sigpipe to ensure the default behavior is equivalent to false
};

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
