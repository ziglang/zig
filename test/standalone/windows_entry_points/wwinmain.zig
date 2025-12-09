const std = @import("std");

pub fn wWinMain(
    inst: std.os.windows.HINSTANCE,
    prev: ?std.os.windows.HINSTANCE,
    cmd_line: std.os.windows.LPWSTR,
    cmd_show: c_int,
) std.os.windows.INT {
    _ = inst;
    _ = prev;
    _ = cmd_line;
    _ = cmd_show;
    std.debug.print("hello from Zig wWinMain\n", .{});
    return 0;
}
