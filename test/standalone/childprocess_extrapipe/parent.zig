const builtin = @import("builtin");
const std = @import("std");
const ChildProcess = std.ChildProcess;
const math = std.math;
const windows = std.os.windows;
const os = std.os;
const testing = std.testing;
const child_process = std.child_process;
const pipe_rd = child_process.pipe_rd;
const pipe_wr = child_process.pipe_wr;

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_state.deinit()) @panic("found memory leaks");
    const gpa = gpa_state.allocator();

    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const child_path = it.next() orelse unreachable;

    var pipe = try child_process.portablePipe();
    defer os.close(pipe[pipe_wr]);
    var child_proc: ChildProcess = undefined;
    // spawn block ensures read end of pipe always closed + shortly closed after spawn().
    {
        defer os.close(pipe[pipe_rd]);

        var buf: [os.handleCharSize]u8 = comptime [_]u8{0} ** os.handleCharSize;
        const s_handle = os.handleToString(pipe[pipe_rd], &buf) catch unreachable;
        child_proc = ChildProcess.init(
            &.{ child_path, s_handle },
            gpa,
        );

        // less time to leak read end of pipe => better
        try os.enableInheritance(pipe[pipe_rd]);
        try child_proc.spawn();
    }

    // check that inheritance was disabled for the handle the whole time
    const is_inheritable = try os.isInheritable(pipe[pipe_wr]);
    std.debug.assert(!is_inheritable);

    var file_out = std.fs.File{ .handle = pipe[pipe_wr] };
    const file_out_writer = file_out.writer();
    try file_out_writer.writeAll("test123\x17"); // ETB = \x17
    const ret_val = try child_proc.wait();
    try testing.expectEqual(ret_val, .{ .Exited = 0 });
}
