const std = @import("../../std.zig");
const builtin = @import("builtin");
const windows = std.os.windows;
const mem = std.mem;
const testing = std.testing;
const expect = testing.expect;

fn testRemoveDotDirs(str: []const u8, expected: []const u8) !void {
    const mutable = try testing.allocator.dupe(u8, str);
    defer testing.allocator.free(mutable);
    const actual = mutable[0..try windows.removeDotDirsSanitized(u8, mutable)];
    try testing.expect(mem.eql(u8, actual, expected));
}
fn testRemoveDotDirsError(err: anyerror, str: []const u8) !void {
    const mutable = try testing.allocator.dupe(u8, str);
    defer testing.allocator.free(mutable);
    try testing.expectError(err, windows.removeDotDirsSanitized(u8, mutable));
}
test "removeDotDirs" {
    try testRemoveDotDirs("", "");
    try testRemoveDotDirs(".", "");
    try testRemoveDotDirs(".\\", "");
    try testRemoveDotDirs(".\\.", "");
    try testRemoveDotDirs(".\\.\\", "");
    try testRemoveDotDirs(".\\.\\.", "");

    try testRemoveDotDirs("a", "a");
    try testRemoveDotDirs("a\\", "a\\");
    try testRemoveDotDirs("a\\b", "a\\b");
    try testRemoveDotDirs("a\\.", "a\\");
    try testRemoveDotDirs("a\\b\\.", "a\\b\\");
    try testRemoveDotDirs("a\\.\\b", "a\\b");

    try testRemoveDotDirs(".a", ".a");
    try testRemoveDotDirs(".a\\", ".a\\");
    try testRemoveDotDirs(".a\\.b", ".a\\.b");
    try testRemoveDotDirs(".a\\.", ".a\\");
    try testRemoveDotDirs(".a\\.\\.", ".a\\");
    try testRemoveDotDirs(".a\\.\\.\\.b", ".a\\.b");
    try testRemoveDotDirs(".a\\.\\.\\.b\\", ".a\\.b\\");

    try testRemoveDotDirsError(error.TooManyParentDirs, "..");
    try testRemoveDotDirsError(error.TooManyParentDirs, "..\\");
    try testRemoveDotDirsError(error.TooManyParentDirs, ".\\..\\");
    try testRemoveDotDirsError(error.TooManyParentDirs, ".\\.\\..\\");

    try testRemoveDotDirs("a\\..", "");
    try testRemoveDotDirs("a\\..\\", "");
    try testRemoveDotDirs("a\\..\\.", "");
    try testRemoveDotDirs("a\\..\\.\\", "");
    try testRemoveDotDirs("a\\..\\.\\.", "");
    try testRemoveDotDirsError(error.TooManyParentDirs, "a\\..\\.\\.\\..");

    try testRemoveDotDirs("a\\..\\.\\.\\b", "b");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\", "b\\");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..", "");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..\\", "");
    try testRemoveDotDirs("a\\..\\.\\.\\b\\.\\..\\.", "");
    try testRemoveDotDirsError(error.TooManyParentDirs, "a\\..\\.\\.\\b\\.\\..\\.\\..");

    try testRemoveDotDirs("a\\b\\..\\", "a\\");
    try testRemoveDotDirs("a\\b\\..\\c", "a\\c");
}

test "loadWinsockExtensionFunction" {
    _ = try windows.WSAStartup(2, 2);
    defer windows.WSACleanup() catch unreachable;

    const LPFN_CONNECTEX = *const fn (
        Socket: windows.ws2_32.SOCKET,
        SockAddr: *const windows.ws2_32.sockaddr,
        SockLen: std.os.socklen_t,
        SendBuf: ?*const anyopaque,
        SendBufLen: windows.DWORD,
        BytesSent: *windows.DWORD,
        Overlapped: *windows.OVERLAPPED,
    ) callconv(windows.WINAPI) windows.BOOL;

    _ = windows.loadWinsockExtensionFunction(
        LPFN_CONNECTEX,
        try std.os.socket(std.os.AF.INET, std.os.SOCK.DGRAM, 0),
        windows.ws2_32.WSAID_CONNECTEX,
    ) catch |err| switch (err) {
        error.OperationNotSupported => unreachable,
        error.ShortRead => unreachable,
        else => |e| return e,
    };
}
