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
        std.debug.print("got '{f}', expected '{f}'\n", .{ std.unicode.fmtUtf16Le(actual_path.span()), std.unicode.fmtUtf16Le(expected_path_utf16) });
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
        std.debug.print("got '{f}', expected '{f}'\n", .{ std.unicode.fmtUtf16Le(zig_result.span()), std.unicode.fmtUtf16Le(win32_api_result.span()) });
        return e;
    };
}

test "toPrefixedFileW" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

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

const RTL_PATH_TYPE = enum(c_int) {
    Unknown,
    UncAbsolute,
    DriveAbsolute,
    DriveRelative,
    Rooted,
    Relative,
    LocalDevice,
    RootLocalDevice,
};

pub extern "ntdll" fn RtlDetermineDosPathNameType_U(
    Path: [*:0]const u16,
) callconv(.winapi) RTL_PATH_TYPE;

test "getWin32PathType vs RtlDetermineDosPathNameType_U" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var buf: std.ArrayList(u16) = .empty;
    defer buf.deinit(std.testing.allocator);

    var wtf8_buf: std.ArrayList(u8) = .empty;
    defer wtf8_buf.deinit(std.testing.allocator);

    var random = std.Random.DefaultPrng.init(std.testing.random_seed);
    const rand = random.random();

    for (0..1000) |_| {
        buf.clearRetainingCapacity();
        const path = try getRandomWtf16Path(std.testing.allocator, &buf, rand);
        wtf8_buf.clearRetainingCapacity();
        const wtf8_len = std.unicode.calcWtf8Len(path);
        try wtf8_buf.ensureTotalCapacity(std.testing.allocator, wtf8_len);
        wtf8_buf.items.len = wtf8_len;
        std.debug.assert(std.unicode.wtf16LeToWtf8(wtf8_buf.items, path) == wtf8_len);

        const windows_type = RtlDetermineDosPathNameType_U(path);
        const wtf16_type = windows.getWin32PathType(u16, path);
        const wtf8_type = windows.getWin32PathType(u8, wtf8_buf.items);

        checkPathType(windows_type, wtf16_type) catch |err| {
            std.debug.print("expected type {}, got {} for path: {f}\n", .{ windows_type, wtf16_type, std.unicode.fmtUtf16Le(path) });
            std.debug.print("path bytes:\n", .{});
            std.debug.dumpHex(std.mem.sliceAsBytes(path));
            return err;
        };

        if (wtf16_type != wtf8_type) {
            std.debug.print("type mismatch between wtf8: {} and wtf16: {} for path: {f}\n", .{ wtf8_type, wtf16_type, std.unicode.fmtUtf16Le(path) });
            std.debug.print("wtf-16 path bytes:\n", .{});
            std.debug.dumpHex(std.mem.sliceAsBytes(path));
            std.debug.print("wtf-8 path bytes:\n", .{});
            std.debug.dumpHex(std.mem.sliceAsBytes(wtf8_buf.items));
            return error.Wtf8Wtf16Mismatch;
        }
    }
}

fn checkPathType(windows_type: RTL_PATH_TYPE, zig_type: windows.Win32PathType) !void {
    const expected_windows_type: RTL_PATH_TYPE = switch (zig_type) {
        .unc_absolute => .UncAbsolute,
        .drive_absolute => .DriveAbsolute,
        .drive_relative => .DriveRelative,
        .rooted => .Rooted,
        .relative => .Relative,
        .local_device => .LocalDevice,
        .root_local_device => .RootLocalDevice,
    };
    if (windows_type != expected_windows_type) return error.PathTypeMismatch;
}

fn getRandomWtf16Path(allocator: std.mem.Allocator, buf: *std.ArrayList(u16), rand: std.Random) ![:0]const u16 {
    const Choice = enum {
        backslash,
        slash,
        control,
        printable,
        non_ascii,
    };

    const choices = rand.uintAtMostBiased(u16, 32);

    for (0..choices) |_| {
        const choice = rand.enumValue(Choice);
        const code_unit = switch (choice) {
            .backslash => '\\',
            .slash => '/',
            .control => switch (rand.uintAtMostBiased(u8, 0x20)) {
                0x20 => '\x7F',
                else => |b| b + 1, // no NUL
            },
            .printable => '!' + rand.uintAtMostBiased(u8, '~' - '!'),
            .non_ascii => rand.intRangeAtMostBiased(u16, 0x80, 0xFFFF),
        };
        try buf.append(allocator, std.mem.nativeToLittle(u16, code_unit));
    }

    try buf.append(allocator, 0);
    return buf.items[0 .. buf.items.len - 1 :0];
}
