const std = @import("../../std.zig");
const builtin = @import("builtin");
const windows = std.os.windows;
const mem = std.mem;
const testing = std.testing;

/// Wrapper around RtlDosPathNameToNtPathName_U for use in comparing
/// the behavior of RtlDosPathNameToNtPathName_U with wToPrefixedFileW
/// Note: RtlDosPathNameToNtPathName_U is not used in the Zig implementation
//        because it allocates.
fn RtlDosPathNameToNtPathName_U(path: [:0]const u16) !windows.PathSpace {
    var out: windows.UNICODE_STRING = undefined;
    const rc = windows.ntdll.RtlDosPathNameToNtPathName_U(path, &out, null, null);
    if (rc != windows.TRUE) return error.BadPathName;
    defer windows.ntdll.RtlFreeUnicodeString(&out);

    var path_space: windows.PathSpace = undefined;
    const out_path = out.Buffer.?[0 .. out.Length / 2];
    @memcpy(path_space.data[0..out_path.len], out_path);
    path_space.len = out.Length / 2;
    path_space.data[path_space.len] = 0;

    return path_space;
}

/// Test that the Zig conversion matches the expected_path (for instances where
/// the Zig implementation intentionally diverges from what RtlDosPathNameToNtPathName_U does).
fn testToPrefixedFileNoOracle(comptime path: []const u8, comptime expected_path: []const u8) !void {
    const path_utf16 = std.unicode.utf8ToUtf16LeStringLiteral(path);
    const expected_path_utf16 = std.unicode.utf8ToUtf16LeStringLiteral(expected_path);
    const actual_path = try windows.wToPrefixedFileW(null, path_utf16);
    std.testing.expectEqualSlices(u16, expected_path_utf16, actual_path.span()) catch |e| {
        std.debug.print("got '{s}', expected '{s}'\n", .{ std.unicode.fmtUtf16Le(actual_path.span()), std.unicode.fmtUtf16le(expected_path_utf16) });
        return e;
    };
}

/// Test that the Zig conversion matches the expected_path and that the
/// expected_path matches the conversion that RtlDosPathNameToNtPathName_U does.
fn testToPrefixedFileWithOracle(comptime path: []const u8, comptime expected_path: []const u8) !void {
    try testToPrefixedFileNoOracle(path, expected_path);
    try testToPrefixedFileOnlyOracle(path);
}

/// Test that the Zig conversion matches the conversion that RtlDosPathNameToNtPathName_U does.
fn testToPrefixedFileOnlyOracle(comptime path: []const u8) !void {
    const path_utf16 = std.unicode.utf8ToUtf16LeStringLiteral(path);
    const zig_result = try windows.wToPrefixedFileW(null, path_utf16);
    const win32_api_result = try RtlDosPathNameToNtPathName_U(path_utf16);
    std.testing.expectEqualSlices(u16, win32_api_result.span(), zig_result.span()) catch |e| {
        std.debug.print("got '{s}', expected '{s}'\n", .{ std.unicode.fmtUtf16Le(zig_result.span()), std.unicode.fmtUtf16le(win32_api_result.span()) });
        return e;
    };
}

test "toPrefixedFileW" {
    if (builtin.os.tag != .windows)
        return;

    // Most test cases come from https://googleprojectzero.blogspot.com/2016/02/the-definitive-guide-on-win32-to-nt.html
    // Note that these tests do not actually touch the filesystem or care about whether or not
    // any of the paths actually exist or are otherwise valid.

    // Drive Absolute
    try testToPrefixedFileWithOracle("X:\\ABC\\DEF", "\\??\\X:\\ABC\\DEF");
    try testToPrefixedFileWithOracle("X:\\", "\\??\\X:\\");
    try testToPrefixedFileWithOracle("X:\\ABC\\", "\\??\\X:\\ABC\\");
    // Trailing . and space characters are stripped
    try testToPrefixedFileWithOracle("X:\\ABC\\DEF. .", "\\??\\X:\\ABC\\DEF");
    try testToPrefixedFileWithOracle("X:/ABC/DEF", "\\??\\X:\\ABC\\DEF");
    try testToPrefixedFileWithOracle("X:\\ABC\\..\\XYZ", "\\??\\X:\\XYZ");
    try testToPrefixedFileWithOracle("X:\\ABC\\..\\..\\..", "\\??\\X:\\");
    // Drive letter casing is unchanged
    try testToPrefixedFileWithOracle("x:\\", "\\??\\x:\\");

    // Drive Relative
    // These tests depend on the CWD of the specified drive letter which can vary,
    // so instead we just test that the Zig implementation matches the result of
    // RtlDosPathNameToNtPathName_U.
    // TODO: Setting the =X: environment variable didn't seem to affect
    //       RtlDosPathNameToNtPathName_U, not sure why that is but getting that
    //       to work could be an avenue to making these cases environment-independent.
    // All -> are examples of the result if the X drive's cwd was X:\ABC
    try testToPrefixedFileOnlyOracle("X:DEF\\GHI"); // -> \??\X:\ABC\DEF\GHI
    try testToPrefixedFileOnlyOracle("X:"); // -> \??\X:\ABC
    try testToPrefixedFileOnlyOracle("X:DEF. ."); // -> \??\X:\ABC\DEF
    try testToPrefixedFileOnlyOracle("X:ABC\\..\\XYZ"); // -> \??\X:\ABC\XYZ
    try testToPrefixedFileOnlyOracle("X:ABC\\..\\..\\.."); // -> \??\X:\
    try testToPrefixedFileOnlyOracle("x:"); // -> \??\X:\ABC

    // Rooted
    // These tests depend on the drive letter of the CWD which can vary, so
    // instead we just test that the Zig implementation matches the result of
    // RtlDosPathNameToNtPathName_U.
    // TODO: Getting the CWD path, getting the drive letter from it, and using it to
    //       construct the expected NT paths could be an avenue to making these cases
    //       environment-independent and therefore able to use testToPrefixedFileWithOracle.
    // All -> are examples of the result if the CWD's drive letter was X
    try testToPrefixedFileOnlyOracle("\\ABC\\DEF"); // -> \??\X:\ABC\DEF
    try testToPrefixedFileOnlyOracle("\\"); // -> \??\X:\
    try testToPrefixedFileOnlyOracle("\\ABC\\DEF. ."); // -> \??\X:\ABC\DEF
    try testToPrefixedFileOnlyOracle("/ABC/DEF"); // -> \??\X:\ABC\DEF
    try testToPrefixedFileOnlyOracle("\\ABC\\..\\XYZ"); // -> \??\X:\XYZ
    try testToPrefixedFileOnlyOracle("\\ABC\\..\\..\\.."); // -> \??\X:\

    // Relative
    // These cases differ in functionality to RtlDosPathNameToNtPathName_U.
    // Relative paths remain relative if they don't have enough .. components
    // to error with TooManyParentDirs
    try testToPrefixedFileNoOracle("ABC\\DEF", "ABC\\DEF");
    // TODO: enable this if trailing . and spaces are stripped from relative paths
    //try testToPrefixedFileNoOracle("ABC\\DEF. .", "ABC\\DEF");
    try testToPrefixedFileNoOracle("ABC/DEF", "ABC\\DEF");
    try testToPrefixedFileNoOracle("./ABC/.././DEF", "DEF");
    // TooManyParentDirs, so resolved relative to the CWD
    // All -> are examples of the result if the CWD was X:\ABC\DEF
    try testToPrefixedFileOnlyOracle("..\\GHI"); // -> \??\X:\ABC\GHI
    try testToPrefixedFileOnlyOracle("GHI\\..\\..\\.."); // -> \??\X:\

    // UNC Absolute
    try testToPrefixedFileWithOracle("\\\\server\\share\\ABC\\DEF", "\\??\\UNC\\server\\share\\ABC\\DEF");
    try testToPrefixedFileWithOracle("\\\\server", "\\??\\UNC\\server");
    try testToPrefixedFileWithOracle("\\\\server\\share", "\\??\\UNC\\server\\share");
    try testToPrefixedFileWithOracle("\\\\server\\share\\ABC. .", "\\??\\UNC\\server\\share\\ABC");
    try testToPrefixedFileWithOracle("//server/share/ABC/DEF", "\\??\\UNC\\server\\share\\ABC\\DEF");
    try testToPrefixedFileWithOracle("\\\\server\\share\\ABC\\..\\XYZ", "\\??\\UNC\\server\\share\\XYZ");
    try testToPrefixedFileWithOracle("\\\\server\\share\\ABC\\..\\..\\..", "\\??\\UNC\\server\\share");

    // Local Device
    try testToPrefixedFileWithOracle("\\\\.\\COM20", "\\??\\COM20");
    try testToPrefixedFileWithOracle("\\\\.\\pipe\\mypipe", "\\??\\pipe\\mypipe");
    try testToPrefixedFileWithOracle("\\\\.\\X:\\ABC\\DEF. .", "\\??\\X:\\ABC\\DEF");
    try testToPrefixedFileWithOracle("\\\\.\\X:/ABC/DEF", "\\??\\X:\\ABC\\DEF");
    try testToPrefixedFileWithOracle("\\\\.\\X:\\ABC\\..\\XYZ", "\\??\\X:\\XYZ");
    // Can replace the first component of the path (contrary to drive absolute and UNC absolute paths)
    try testToPrefixedFileWithOracle("\\\\.\\X:\\ABC\\..\\..\\C:\\", "\\??\\C:\\");
    try testToPrefixedFileWithOracle("\\\\.\\pipe\\mypipe\\..\\notmine", "\\??\\pipe\\notmine");

    // Special-case device names
    // TODO: Enable once these are supported
    //       more cases to test here: https://googleprojectzero.blogspot.com/2016/02/the-definitive-guide-on-win32-to-nt.html
    //try testToPrefixedFileWithOracle("COM1", "\\??\\COM1");
    // Sometimes the special-cased device names are not respected
    try testToPrefixedFileWithOracle("\\\\.\\X:\\COM1", "\\??\\X:\\COM1");
    try testToPrefixedFileWithOracle("\\\\abc\\xyz\\COM1", "\\??\\UNC\\abc\\xyz\\COM1");

    // Verbatim
    // Left untouched except \\?\ is replaced by \??\
    try testToPrefixedFileWithOracle("\\\\?\\X:", "\\??\\X:");
    try testToPrefixedFileWithOracle("\\\\?\\X:\\COM1", "\\??\\X:\\COM1");
    try testToPrefixedFileWithOracle("\\\\?\\X:/ABC/DEF. .", "\\??\\X:/ABC/DEF. .");
    try testToPrefixedFileWithOracle("\\\\?\\X:\\ABC\\..\\..\\..", "\\??\\X:\\ABC\\..\\..\\..");
    // NT Namespace
    // Fully unmodified
    try testToPrefixedFileWithOracle("\\??\\X:", "\\??\\X:");
    try testToPrefixedFileWithOracle("\\??\\X:\\COM1", "\\??\\X:\\COM1");
    try testToPrefixedFileWithOracle("\\??\\X:/ABC/DEF. .", "\\??\\X:/ABC/DEF. .");
    try testToPrefixedFileWithOracle("\\??\\X:\\ABC\\..\\..\\..", "\\??\\X:\\ABC\\..\\..\\..");

    // 'Fake' Verbatim
    // If the prefix looks like the verbatim prefix but not all path separators in the
    // prefix are backslashes, then it gets canonicalized and the prefix is dropped in favor
    // of the NT prefix.
    try testToPrefixedFileWithOracle("//?/C:/ABC", "\\??\\C:\\ABC");
    // 'Fake' NT
    // If the prefix looks like the NT prefix but not all path separators in the prefix
    // are backslashes, then it gets canonicalized and the /??/ is not dropped but
    // rather treated as part of the path. In other words, the path is treated
    // as a rooted path, so the final path is resolved relative to the CWD's
    // drive letter.
    // The -> shows an example of the result if the CWD's drive letter was X
    try testToPrefixedFileOnlyOracle("/??/C:/ABC"); // -> \??\X:\??\C:\ABC

    // Root Local Device
    // \\. and \\? always get converted to \??\
    try testToPrefixedFileWithOracle("\\\\.", "\\??\\");
    try testToPrefixedFileWithOracle("\\\\?", "\\??\\");
    try testToPrefixedFileWithOracle("//?", "\\??\\");
    try testToPrefixedFileWithOracle("//.", "\\??\\");
}

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
        SockLen: std.posix.socklen_t,
        SendBuf: ?*const anyopaque,
        SendBufLen: windows.DWORD,
        BytesSent: *windows.DWORD,
        Overlapped: *windows.OVERLAPPED,
    ) callconv(windows.WINAPI) windows.BOOL;

    _ = windows.loadWinsockExtensionFunction(
        LPFN_CONNECTEX,
        try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0),
        windows.ws2_32.WSAID_CONNECTEX,
    ) catch |err| switch (err) {
        error.OperationNotSupported => unreachable,
        error.ShortRead => unreachable,
        else => |e| return e,
    };
}
