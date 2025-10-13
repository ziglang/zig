pub const std_options: std.Options = .{
    .allow_stack_tracing = false,
};

pub fn main() !void {
    var st_buf: [8]usize = undefined;
    var buf: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buf);

    const captured_st = try foo(&stdout.interface, &st_buf);
    try std.debug.writeStackTrace(&captured_st, &stdout.interface, .no_color);
    try stdout.interface.print("stack trace index: {d}\n", .{captured_st.index});

    try stdout.interface.flush();
}
fn foo(w: *std.Io.Writer, st_buf: []usize) !std.builtin.StackTrace {
    try std.debug.writeCurrentStackTrace(.{}, w, .no_color);
    return std.debug.captureCurrentStackTrace(.{}, st_buf);
}

const std = @import("std");

// run
//
// Cannot print stack trace: stack tracing is disabled
// Cannot print stack trace: stack tracing is disabled
// stack trace index: 0
//
