const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();
    const stdin = std.io.getStdIn();
    const stdin_reader = stdin.reader();
    const stdin_cont = try stdin_reader.readUntilDelimiterAlloc(gpa, '\n', 2_000);
    defer gpa.free(stdin_cont);
    var file_handle = file_handle: {
        if (builtin.target.os.tag == .windows) {
            var handle_int = try std.fmt.parseInt(usize, stdin_cont, 10);
            break :file_handle @intToPtr(windows.HANDLE, handle_int);
        } else {
            break :file_handle try std.fmt.parseInt(std.os.fd_t, stdin_cont, 10);
        }
    };
    if (builtin.target.os.tag == .windows) {
        // windows.HANDLE_FLAG_INHERIT is enabled
        var handle_flags: windows.DWORD = undefined;
        try windows.GetHandleInformation(file_handle, &handle_flags);
        try std.testing.expect(handle_flags & windows.HANDLE_FLAG_INHERIT != 0);
    } else {
        // FD_CLOEXEC is not set
        var fcntl_flags = try std.os.fcntl(file_handle, std.os.F.GETFD, 0);
        try std.testing.expect((fcntl_flags & std.os.FD_CLOEXEC) == 0);
    }
    try std.os.disableFileInheritance(file_handle);
    var extra_stream_in = std.fs.File{ .handle = file_handle };
    defer extra_stream_in.close();
    const extra_str_in_rd = extra_stream_in.reader();
    const all_extra_str_in = try extra_str_in_rd.readUntilDelimiterAlloc(gpa, '\x17', 20_000);
    defer gpa.free(all_extra_str_in);
    try std.testing.expectEqualSlices(u8, all_extra_str_in, "test123");
}
