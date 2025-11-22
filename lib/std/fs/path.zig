//! POSIX paths are arbitrary sequences of `u8` with no particular encoding.
//!
//! Windows paths are arbitrary sequences of `u16` (WTF-16).
//! For cross-platform APIs that deal with sequences of `u8`, Windows
//! paths are encoded by Zig as [WTF-8](https://wtf-8.codeberg.page/).
//! WTF-8 is a superset of UTF-8 that allows encoding surrogate codepoints,
//! which enables lossless roundtripping when converting to/from WTF-16
//! (as long as the WTF-8 encoded surrogate codepoints do not form a pair).
//!
//! WASI paths are sequences of valid Unicode scalar values,
//! which means that WASI is unable to handle paths that cannot be
//! encoded as well-formed UTF-8/UTF-16.
//! https://github.com/WebAssembly/wasi-filesystem/issues/17#issuecomment-1430639353

const builtin = @import("builtin");
const std = @import("../std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const windows = std.os.windows;
const process = std.process;
const native_os = builtin.target.os.tag;

pub const sep_windows: u8 = '\\';
pub const sep_posix: u8 = '/';
pub const sep = switch (native_os) {
    .windows, .uefi => sep_windows,
    else => sep_posix,
};

pub const sep_str_windows = "\\";
pub const sep_str_posix = "/";
pub const sep_str = switch (native_os) {
    .windows, .uefi => sep_str_windows,
    else => sep_str_posix,
};

pub const delimiter_windows: u8 = ';';
pub const delimiter_posix: u8 = ':';
pub const delimiter = if (native_os == .windows) delimiter_windows else delimiter_posix;

/// Returns if the given byte is a valid path separator
pub fn isSep(byte: u8) bool {
    return switch (native_os) {
        .windows => byte == '/' or byte == '\\',
        .uefi => byte == '\\',
        else => byte == '/',
    };
}

pub const PathType = enum {
    windows,
    uefi,
    posix,

    /// Returns true if `c` is a valid path separator for the `path_type`.
    /// If `T` is `u16`, `c` is assumed to be little-endian.
    pub inline fn isSep(comptime path_type: PathType, comptime T: type, c: T) bool {
        return switch (path_type) {
            .windows => c == mem.nativeToLittle(T, '/') or c == mem.nativeToLittle(T, '\\'),
            .posix => c == mem.nativeToLittle(T, '/'),
            .uefi => c == mem.nativeToLittle(T, '\\'),
        };
    }
};

/// This is different from mem.join in that the separator will not be repeated if
/// it is found at the end or beginning of a pair of consecutive paths.
fn joinSepMaybeZ(allocator: Allocator, separator: u8, comptime sepPredicate: fn (u8) bool, paths: []const []const u8, zero: bool) ![]u8 {
    if (paths.len == 0) return if (zero) try allocator.dupe(u8, &[1]u8{0}) else &[0]u8{};

    // Find first non-empty path index.
    const first_path_index = blk: {
        for (paths, 0..) |path, index| {
            if (path.len == 0) continue else break :blk index;
        }

        // All paths provided were empty, so return early.
        return if (zero) try allocator.dupe(u8, &[1]u8{0}) else &[0]u8{};
    };

    // Calculate length needed for resulting joined path buffer.
    const total_len = blk: {
        var sum: usize = paths[first_path_index].len;
        var prev_path = paths[first_path_index];
        assert(prev_path.len > 0);
        var i: usize = first_path_index + 1;
        while (i < paths.len) : (i += 1) {
            const this_path = paths[i];
            if (this_path.len == 0) continue;
            const prev_sep = sepPredicate(prev_path[prev_path.len - 1]);
            const this_sep = sepPredicate(this_path[0]);
            sum += @intFromBool(!prev_sep and !this_sep);
            sum += if (prev_sep and this_sep) this_path.len - 1 else this_path.len;
            prev_path = this_path;
        }

        if (zero) sum += 1;
        break :blk sum;
    };

    const buf = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buf);

    @memcpy(buf[0..paths[first_path_index].len], paths[first_path_index]);
    var buf_index: usize = paths[first_path_index].len;
    var prev_path = paths[first_path_index];
    assert(prev_path.len > 0);
    var i: usize = first_path_index + 1;
    while (i < paths.len) : (i += 1) {
        const this_path = paths[i];
        if (this_path.len == 0) continue;
        const prev_sep = sepPredicate(prev_path[prev_path.len - 1]);
        const this_sep = sepPredicate(this_path[0]);
        if (!prev_sep and !this_sep) {
            buf[buf_index] = separator;
            buf_index += 1;
        }
        const adjusted_path = if (prev_sep and this_sep) this_path[1..] else this_path;
        @memcpy(buf[buf_index..][0..adjusted_path.len], adjusted_path);
        buf_index += adjusted_path.len;
        prev_path = this_path;
    }

    if (zero) buf[buf.len - 1] = 0;

    // No need for shrink since buf is exactly the correct size.
    return buf;
}

/// Naively combines a series of paths with the native path separator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: Allocator, paths: []const []const u8) ![]u8 {
    return joinSepMaybeZ(allocator, sep, isSep, paths, false);
}

/// Naively combines a series of paths with the native path separator and null terminator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn joinZ(allocator: Allocator, paths: []const []const u8) ![:0]u8 {
    const out = try joinSepMaybeZ(allocator, sep, isSep, paths, true);
    return out[0 .. out.len - 1 :0];
}

pub fn fmtJoin(paths: []const []const u8) std.fmt.Alt([]const []const u8, formatJoin) {
    return .{ .data = paths };
}

fn formatJoin(paths: []const []const u8, w: *std.Io.Writer) std.Io.Writer.Error!void {
    const first_path_idx = for (paths, 0..) |p, idx| {
        if (p.len != 0) break idx;
    } else return;

    try w.writeAll(paths[first_path_idx]); // first component
    var prev_path = paths[first_path_idx];
    for (paths[first_path_idx + 1 ..]) |this_path| {
        if (this_path.len == 0) continue; // skip empty components
        const prev_sep = isSep(prev_path[prev_path.len - 1]);
        const this_sep = isSep(this_path[0]);
        if (!prev_sep and !this_sep) {
            try w.writeByte(sep);
        }
        if (prev_sep and this_sep) {
            try w.writeAll(this_path[1..]); // skip redundant separator
        } else {
            try w.writeAll(this_path);
        }
        prev_path = this_path;
    }
}

fn testJoinMaybeZUefi(paths: []const []const u8, expected: []const u8, zero: bool) !void {
    const uefiIsSep = struct {
        fn isSep(byte: u8) bool {
            return byte == '\\';
        }
    }.isSep;
    const actual = try joinSepMaybeZ(testing.allocator, sep_windows, uefiIsSep, paths, zero);
    defer testing.allocator.free(actual);
    try testing.expectEqualSlices(u8, expected, if (zero) actual[0 .. actual.len - 1 :0] else actual);
}

fn testJoinMaybeZWindows(paths: []const []const u8, expected: []const u8, zero: bool) !void {
    const windowsIsSep = struct {
        fn isSep(byte: u8) bool {
            return byte == '/' or byte == '\\';
        }
    }.isSep;
    const actual = try joinSepMaybeZ(testing.allocator, sep_windows, windowsIsSep, paths, zero);
    defer testing.allocator.free(actual);
    try testing.expectEqualSlices(u8, expected, if (zero) actual[0 .. actual.len - 1 :0] else actual);
}

fn testJoinMaybeZPosix(paths: []const []const u8, expected: []const u8, zero: bool) !void {
    const posixIsSep = struct {
        fn isSep(byte: u8) bool {
            return byte == '/';
        }
    }.isSep;
    const actual = try joinSepMaybeZ(testing.allocator, sep_posix, posixIsSep, paths, zero);
    defer testing.allocator.free(actual);
    try testing.expectEqualSlices(u8, expected, if (zero) actual[0 .. actual.len - 1 :0] else actual);
}

test join {
    {
        const actual: []u8 = try join(testing.allocator, &[_][]const u8{});
        defer testing.allocator.free(actual);
        try testing.expectEqualSlices(u8, "", actual);
    }
    {
        const actual: [:0]u8 = try joinZ(testing.allocator, &[_][]const u8{});
        defer testing.allocator.free(actual);
        try testing.expectEqualSlices(u8, "", actual);
    }
    for (&[_]bool{ false, true }) |zero| {
        try testJoinMaybeZWindows(&[_][]const u8{}, "", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\b", "c" }, "c:\\a\\b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\b", "c" }, "c:\\a\\b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\b\\", "\\c" }, "c:\\a\\b\\c", zero);

        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\", "a", "b\\", "c" }, "c:\\a\\b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\", "b\\", "c" }, "c:\\a\\b\\c", zero);

        try testJoinMaybeZWindows(
            &[_][]const u8{ "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std", "ab.zig" },
            "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std\\ab.zig",
            zero,
        );

        try testJoinMaybeZUefi(&[_][]const u8{ "EFI", "Boot", "bootx64.efi" }, "EFI\\Boot\\bootx64.efi", zero);
        try testJoinMaybeZUefi(&[_][]const u8{ "EFI\\Boot", "bootx64.efi" }, "EFI\\Boot\\bootx64.efi", zero);
        try testJoinMaybeZUefi(&[_][]const u8{ "EFI\\", "\\Boot", "bootx64.efi" }, "EFI\\Boot\\bootx64.efi", zero);
        try testJoinMaybeZUefi(&[_][]const u8{ "EFI\\", "\\Boot\\", "\\bootx64.efi" }, "EFI\\Boot\\bootx64.efi", zero);

        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\", "a", "b/", "c" }, "c:\\a\\b/c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a/", "b\\", "/c" }, "c:\\a/b\\c", zero);

        try testJoinMaybeZWindows(&[_][]const u8{ "", "c:\\", "", "", "a", "b\\", "c", "" }, "c:\\a\\b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a/", "", "b\\", "", "/c" }, "c:\\a/b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "", "" }, "", zero);

        try testJoinMaybeZPosix(&[_][]const u8{}, "", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "/a/b", "c" }, "/a/b/c", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "/a/b/", "c" }, "/a/b/c", zero);

        try testJoinMaybeZPosix(&[_][]const u8{ "/", "a", "b/", "c" }, "/a/b/c", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "/a/", "b/", "c" }, "/a/b/c", zero);

        try testJoinMaybeZPosix(
            &[_][]const u8{ "/home/andy/dev/zig/build/lib/zig/std", "ab.zig" },
            "/home/andy/dev/zig/build/lib/zig/std/ab.zig",
            zero,
        );

        try testJoinMaybeZPosix(&[_][]const u8{ "a", "/c" }, "a/c", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "a/", "/c" }, "a/c", zero);

        try testJoinMaybeZPosix(&[_][]const u8{ "", "/", "a", "", "b/", "c", "" }, "/a/b/c", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "/a/", "", "", "b/", "c" }, "/a/b/c", zero);
        try testJoinMaybeZPosix(&[_][]const u8{ "", "" }, "", zero);
    }
}

pub fn isAbsoluteZ(path_c: [*:0]const u8) bool {
    if (native_os == .windows) {
        return isAbsoluteWindowsZ(path_c);
    } else {
        return isAbsolutePosixZ(path_c);
    }
}

pub fn isAbsolute(path: []const u8) bool {
    if (native_os == .windows) {
        return isAbsoluteWindows(path);
    } else {
        return isAbsolutePosix(path);
    }
}

fn isAbsoluteWindowsImpl(comptime T: type, path: []const T) bool {
    return switch (windows.getWin32PathType(T, path)) {
        // Unambiguously absolute
        .drive_absolute, .unc_absolute, .local_device, .root_local_device => true,
        // Unambiguously relative
        .relative => false,
        // Ambiguous, more absolute than relative
        .rooted => true,
        // Ambiguous, more relative than absolute
        .drive_relative => false,
    };
}

pub fn isAbsoluteWindows(path: []const u8) bool {
    return isAbsoluteWindowsImpl(u8, path);
}

pub fn isAbsoluteWindowsW(path_w: [*:0]const u16) bool {
    return isAbsoluteWindowsImpl(u16, mem.sliceTo(path_w, 0));
}

pub fn isAbsoluteWindowsWtf16(path: []const u16) bool {
    return isAbsoluteWindowsImpl(u16, path);
}

pub fn isAbsoluteWindowsZ(path_c: [*:0]const u8) bool {
    return isAbsoluteWindowsImpl(u8, mem.sliceTo(path_c, 0));
}

pub fn isAbsolutePosix(path: []const u8) bool {
    return path.len > 0 and path[0] == sep_posix;
}

pub fn isAbsolutePosixZ(path_c: [*:0]const u8) bool {
    return isAbsolutePosix(mem.sliceTo(path_c, 0));
}

test isAbsoluteWindows {
    try testIsAbsoluteWindows("", false);
    try testIsAbsoluteWindows("/", true);
    try testIsAbsoluteWindows("//", true);
    try testIsAbsoluteWindows("//server", true);
    try testIsAbsoluteWindows("//server/file", true);
    try testIsAbsoluteWindows("\\\\server\\file", true);
    try testIsAbsoluteWindows("\\\\server", true);
    try testIsAbsoluteWindows("\\\\", true);
    try testIsAbsoluteWindows("c", false);
    try testIsAbsoluteWindows("c:", false);
    try testIsAbsoluteWindows("c:\\", true);
    try testIsAbsoluteWindows("c:/", true);
    try testIsAbsoluteWindows("c://", true);
    try testIsAbsoluteWindows("C:/Users/", true);
    try testIsAbsoluteWindows("C:\\Users\\", true);
    try testIsAbsoluteWindows("C:cwd/another", false);
    try testIsAbsoluteWindows("C:cwd\\another", false);
    try testIsAbsoluteWindows("λ:\\", true);
    try testIsAbsoluteWindows("λ:", false);
    try testIsAbsoluteWindows("\u{10000}:\\", false);
    try testIsAbsoluteWindows("directory/directory", false);
    try testIsAbsoluteWindows("directory\\directory", false);
    try testIsAbsoluteWindows("/usr/local", true);
}

test isAbsolutePosix {
    try testIsAbsolutePosix("", false);
    try testIsAbsolutePosix("/home/foo", true);
    try testIsAbsolutePosix("/home/foo/..", true);
    try testIsAbsolutePosix("bar/", false);
    try testIsAbsolutePosix("./baz", false);
}

fn testIsAbsoluteWindows(path: []const u8, expected_result: bool) !void {
    try testing.expectEqual(expected_result, isAbsoluteWindows(path));
    const path_w = try std.unicode.wtf8ToWtf16LeAllocZ(std.testing.allocator, path);
    defer std.testing.allocator.free(path_w);
    try testing.expectEqual(expected_result, isAbsoluteWindowsW(path_w));
    try testing.expectEqual(expected_result, isAbsoluteWindowsWtf16(path_w));
}

fn testIsAbsolutePosix(path: []const u8, expected_result: bool) !void {
    try testing.expectEqual(expected_result, isAbsolutePosix(path));
}

/// Deprecated; see `WindowsPath2`
pub const WindowsPath = struct {
    is_abs: bool,
    kind: Kind,
    disk_designator: []const u8,

    pub const Kind = enum {
        None,
        Drive,
        NetworkShare,
    };
};

/// Deprecated; see `parsePathWindows`
pub fn windowsParsePath(path: []const u8) WindowsPath {
    if (path.len >= 2 and path[1] == ':') {
        return WindowsPath{
            .is_abs = isAbsoluteWindows(path),
            .kind = WindowsPath.Kind.Drive,
            .disk_designator = path[0..2],
        };
    }
    if (path.len >= 1 and (path[0] == '/' or path[0] == '\\') and
        (path.len == 1 or (path[1] != '/' and path[1] != '\\')))
    {
        return WindowsPath{
            .is_abs = true,
            .kind = WindowsPath.Kind.None,
            .disk_designator = path[0..0],
        };
    }
    const relative_path = WindowsPath{
        .kind = WindowsPath.Kind.None,
        .disk_designator = &[_]u8{},
        .is_abs = false,
    };

    if (path.len >= 2 and PathType.windows.isSep(u8, path[0]) and PathType.windows.isSep(u8, path[1])) {
        const root_end = root_end: {
            var server_end = mem.indexOfAnyPos(u8, path, 2, "/\\") orelse break :root_end path.len;
            while (server_end < path.len and PathType.windows.isSep(u8, path[server_end])) server_end += 1;
            break :root_end mem.indexOfAnyPos(u8, path, server_end, "/\\") orelse path.len;
        };
        return WindowsPath{
            .is_abs = true,
            .kind = WindowsPath.Kind.NetworkShare,
            .disk_designator = path[0..root_end],
        };
    }
    return relative_path;
}

test windowsParsePath {
    {
        const parsed = windowsParsePath("//a/b");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "//a/b"));
    }
    {
        const parsed = windowsParsePath("\\\\a\\b");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "\\\\a\\b"));
    }
    {
        const parsed = windowsParsePath("\\\\a/b");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "\\\\a/b"));
    }
    {
        const parsed = windowsParsePath("\\/a\\");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "\\/a\\"));
    }
    {
        const parsed = windowsParsePath("\\\\a\\\\b");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "\\\\a\\\\b"));
    }
    {
        const parsed = windowsParsePath("\\\\a\\\\b\\c");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.NetworkShare);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "\\\\a\\\\b"));
    }
    {
        const parsed = windowsParsePath("/usr/local");
        try testing.expect(parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.None);
        try testing.expect(mem.eql(u8, parsed.disk_designator, ""));
    }
    {
        const parsed = windowsParsePath("c:../");
        try testing.expect(!parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.Drive);
        try testing.expect(mem.eql(u8, parsed.disk_designator, "c:"));
    }
}

/// On Windows, this calls `parsePathWindows` and on POSIX it calls `parsePathPosix`.
///
/// Returns a platform-specific struct with two fields: `root` and `kind`.
/// The `root` will be a slice of `path` (`/` for POSIX absolute paths, and things
/// like `C:\`, `\\server\share\`, etc for Windows paths).
/// If the path is of kind `.relative`, then `root` will be zero-length.
pub fn parsePath(path: []const u8) switch (native_os) {
    .windows => WindowsPath2(u8),
    else => PosixPath,
} {
    switch (native_os) {
        .windows => return parsePathWindows(u8, path),
        else => return parsePathPosix(path),
    }
}

const PosixPath = struct {
    kind: enum { relative, absolute },
    root: []const u8,
};

pub fn parsePathPosix(path: []const u8) PosixPath {
    const abs = isAbsolutePosix(path);
    return .{
        .kind = if (abs) .absolute else .relative,
        .root = if (abs) path[0..1] else path[0..0],
    };
}

test parsePathPosix {
    {
        const parsed = parsePathPosix("a/b");
        try testing.expectEqual(.relative, parsed.kind);
        try testing.expectEqualStrings("", parsed.root);
    }
    {
        const parsed = parsePathPosix("/a/b");
        try testing.expectEqual(.absolute, parsed.kind);
        try testing.expectEqualStrings("/", parsed.root);
    }
    {
        const parsed = parsePathPosix("///a/b");
        try testing.expectEqual(.absolute, parsed.kind);
        try testing.expectEqualStrings("/", parsed.root);
    }
}

pub fn WindowsPath2(comptime T: type) type {
    return struct {
        kind: windows.Win32PathType,
        root: []const T,
    };
}

pub fn parsePathWindows(comptime T: type, path: []const T) WindowsPath2(T) {
    const kind = windows.getWin32PathType(T, path);
    const root = root: switch (kind) {
        .drive_absolute, .drive_relative => {
            const drive_letter_len = getDriveLetter(T, path).len;
            break :root path[0 .. drive_letter_len + @as(usize, if (kind == .drive_absolute) 2 else 1)];
        },
        .relative => path[0..0],
        .local_device => path[0..4],
        .root_local_device => path,
        .rooted => path[0..1],
        .unc_absolute => {
            const unc = parseUNC(T, path);
            // There may be any number of path separators between the server and the share,
            // so take that into account by using pointer math to get the difference.
            var root_len = 2 + (unc.share.ptr - unc.server.ptr) + unc.share.len;
            if (unc.sep_after_share) root_len += 1;
            break :root path[0..root_len];
        },
    };
    return .{
        .kind = kind,
        .root = root,
    };
}

test parsePathWindows {
    {
        const path = "//a/b";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("//a/b", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\a\\b";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\\\a\\b", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\/a/b/c";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\/a/b/", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\a\\";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\\\a\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\a\\b\\";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\\\a\\b\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\a\\/b\\/";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\\\a\\/b\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\кириллица\\ελληνικά\\português";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.unc_absolute, parsed.kind);
        try testing.expectEqualStrings("\\\\кириллица\\ελληνικά\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "/usr/local";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.rooted, parsed.kind);
        try testing.expectEqualStrings("/", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\.";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.root_local_device, parsed.kind);
        try testing.expectEqualStrings("\\\\.", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\\\\.\\a";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.local_device, parsed.kind);
        try testing.expectEqualStrings("\\\\.\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "c:../";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.drive_relative, parsed.kind);
        try testing.expectEqualStrings("c:", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "C:\\../";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.drive_absolute, parsed.kind);
        try testing.expectEqualStrings("C:\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        // Non-ASCII code point that is encoded as one WTF-16 code unit is considered a valid drive letter
        const path = "€:\\";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.drive_absolute, parsed.kind);
        try testing.expectEqualStrings("€:\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "€:";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.drive_relative, parsed.kind);
        try testing.expectEqualStrings("€:", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        // But code points that are encoded as two WTF-16 code units are not
        const path = "\u{10000}:\\";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.relative, parsed.kind);
        try testing.expectEqualStrings("", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        const path = "\u{10000}:";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.relative, parsed.kind);
        try testing.expectEqualStrings("", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
    {
        // Paths are assumed to be in the Win32 namespace, so while this is
        // likely a NT namespace path, it's treated as a rooted path.
        const path = "\\??\\foo";
        const parsed = parsePathWindows(u8, path);
        try testing.expectEqual(.rooted, parsed.kind);
        try testing.expectEqualStrings("\\", parsed.root);
        try testWindowsParsePathHarmony(path);
    }
}

fn testWindowsParsePathHarmony(wtf8: []const u8) !void {
    var wtf16_buf: [256]u16 = undefined;
    const wtf16_len = try std.unicode.wtf8ToWtf16Le(&wtf16_buf, wtf8);
    const wtf16 = wtf16_buf[0..wtf16_len];

    const wtf8_parsed = parsePathWindows(u8, wtf8);
    const wtf16_parsed = parsePathWindows(u16, wtf16);

    var wtf8_buf: [256]u8 = undefined;
    const wtf16_root_as_wtf8_len = std.unicode.wtf16LeToWtf8(&wtf8_buf, wtf16_parsed.root);
    const wtf16_root_as_wtf8 = wtf8_buf[0..wtf16_root_as_wtf8_len];

    try std.testing.expectEqual(wtf8_parsed.kind, wtf16_parsed.kind);
    try std.testing.expectEqualStrings(wtf8_parsed.root, wtf16_root_as_wtf8);
}

/// Deprecated; use `parsePath`
pub fn diskDesignator(path: []const u8) []const u8 {
    if (native_os == .windows) {
        return diskDesignatorWindows(path);
    } else {
        return "";
    }
}

/// Deprecated; use `parsePathWindows`
pub fn diskDesignatorWindows(path: []const u8) []const u8 {
    return windowsParsePath(path).disk_designator;
}

fn WindowsUNC(comptime T: type) type {
    return struct {
        server: []const T,
        sep_after_server: bool,
        share: []const T,
        sep_after_share: bool,
    };
}

/// Asserts that `path` starts with two path separators
fn parseUNC(comptime T: type, path: []const T) WindowsUNC(T) {
    assert(path.len >= 2 and PathType.windows.isSep(T, path[0]) and PathType.windows.isSep(T, path[1]));
    const any_sep = switch (T) {
        u8 => "/\\",
        u16 => std.unicode.wtf8ToWtf16LeStringLiteral("/\\"),
        else => @compileError("only u8 (WTF-8) and u16 (WTF-16LE) are supported"),
    };
    // For the server, the first path separator after the initial two is always
    // the terminator of the server name, even if that means the server name is
    // zero-length.
    const server_end = mem.indexOfAnyPos(T, path, 2, any_sep) orelse return .{
        .server = path[2..path.len],
        .sep_after_server = false,
        .share = path[path.len..path.len],
        .sep_after_share = false,
    };
    // For the share, there can be any number of path separators between the server
    // and the share, so we want to skip over all of them instead of just looking for
    // the first one.
    var it = std.mem.tokenizeAny(T, path[server_end + 1 ..], any_sep);
    const share = it.next() orelse return .{
        .server = path[2..server_end],
        .sep_after_server = true,
        .share = path[server_end + 1 .. server_end + 1],
        .sep_after_share = false,
    };
    return .{
        .server = path[2..server_end],
        .sep_after_server = true,
        .share = share,
        .sep_after_share = it.index != it.buffer.len,
    };
}

test parseUNC {
    {
        const unc = parseUNC(u8, "//");
        try std.testing.expectEqualStrings("", unc.server);
        try std.testing.expect(!unc.sep_after_server);
        try std.testing.expectEqualStrings("", unc.share);
        try std.testing.expect(!unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "\\\\s");
        try std.testing.expectEqualStrings("s", unc.server);
        try std.testing.expect(!unc.sep_after_server);
        try std.testing.expectEqualStrings("", unc.share);
        try std.testing.expect(!unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "\\\\s/");
        try std.testing.expectEqualStrings("s", unc.server);
        try std.testing.expect(unc.sep_after_server);
        try std.testing.expectEqualStrings("", unc.share);
        try std.testing.expect(!unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "\\/server\\share");
        try std.testing.expectEqualStrings("server", unc.server);
        try std.testing.expect(unc.sep_after_server);
        try std.testing.expectEqualStrings("share", unc.share);
        try std.testing.expect(!unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "/\\server\\share/");
        try std.testing.expectEqualStrings("server", unc.server);
        try std.testing.expect(unc.sep_after_server);
        try std.testing.expectEqualStrings("share", unc.share);
        try std.testing.expect(unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "\\\\server/\\share\\/");
        try std.testing.expectEqualStrings("server", unc.server);
        try std.testing.expect(unc.sep_after_server);
        try std.testing.expectEqualStrings("share", unc.share);
        try std.testing.expect(unc.sep_after_share);
    }
    {
        const unc = parseUNC(u8, "\\\\server\\/\\\\");
        try std.testing.expectEqualStrings("server", unc.server);
        try std.testing.expect(unc.sep_after_server);
        try std.testing.expectEqualStrings("", unc.share);
        try std.testing.expect(!unc.sep_after_share);
    }
}

const DiskDesignatorKind = enum { drive, unc };

/// `p1` and `p2` are both assumed to be the `kind` provided.
fn compareDiskDesignators(comptime T: type, kind: DiskDesignatorKind, p1: []const T, p2: []const T) bool {
    const eql = switch (T) {
        u8 => windows.eqlIgnoreCaseWtf8,
        u16 => windows.eqlIgnoreCaseWtf16,
        else => @compileError("only u8 (WTF-8) and u16 (WTF-16LE) is supported"),
    };
    switch (kind) {
        .drive => {
            const drive_letter1 = getDriveLetter(T, p1);
            const drive_letter2 = getDriveLetter(T, p2);

            return eql(drive_letter1, drive_letter2);
        },
        .unc => {
            var unc1 = parseUNC(T, p1);
            var unc2 = parseUNC(T, p2);

            return eql(unc1.server, unc2.server) and
                eql(unc1.share, unc2.share);
        },
    }
}

/// `path` is assumed to be drive-relative or drive-absolute.
fn getDriveLetter(comptime T: type, path: []const T) []const T {
    const len: usize = switch (T) {
        // getWin32PathType will only return .drive_absolute/.drive_relative when there is
        // (1) a valid code point, and (2) a code point < U+10000, so we only need to
        // get the length determined by the first byte.
        u8 => std.unicode.utf8ByteSequenceLength(path[0]) catch unreachable,
        u16 => 1,
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
    return path[0..len];
}

test compareDiskDesignators {
    try testCompareDiskDesignators(true, .drive, "c:", "C:\\");
    try testCompareDiskDesignators(true, .drive, "C:\\", "C:");
    try testCompareDiskDesignators(false, .drive, "C:\\", "D:\\");
    // Case-insensitivity technically applies to non-ASCII drive letters
    try testCompareDiskDesignators(true, .drive, "λ:\\", "Λ:");

    try testCompareDiskDesignators(true, .unc, "\\\\server", "//server//");
    try testCompareDiskDesignators(true, .unc, "\\\\server\\\\share", "/\\server/share");
    try testCompareDiskDesignators(true, .unc, "\\\\server\\\\share", "/\\server/share\\\\foo");
    try testCompareDiskDesignators(false, .unc, "\\\\server\\sharefoo", "/\\server/share\\foo");
    try testCompareDiskDesignators(false, .unc, "\\\\serverfoo\\\\share", "//server/share");
    try testCompareDiskDesignators(false, .unc, "\\\\server\\", "//server/share");
}

fn testCompareDiskDesignators(expected_result: bool, kind: DiskDesignatorKind, p1: []const u8, p2: []const u8) !void {
    var wtf16_buf1: [256]u16 = undefined;
    const w1_len = try std.unicode.wtf8ToWtf16Le(&wtf16_buf1, p1);
    var wtf16_buf2: [256]u16 = undefined;
    const w2_len = try std.unicode.wtf8ToWtf16Le(&wtf16_buf2, p2);
    try std.testing.expectEqual(expected_result, compareDiskDesignators(u8, kind, p1, p2));
    try std.testing.expectEqual(expected_result, compareDiskDesignators(u16, kind, wtf16_buf1[0..w1_len], wtf16_buf2[0..w2_len]));
}

/// On Windows, this calls `resolveWindows` and on POSIX it calls `resolvePosix`.
pub fn resolve(allocator: Allocator, paths: []const []const u8) Allocator.Error![]u8 {
    if (native_os == .windows) {
        return resolveWindows(allocator, paths);
    } else {
        return resolvePosix(allocator, paths);
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and ".." to the best of its ability, but will not convert relative paths to
/// an absolute path, use std.fs.Dir.realpath instead.
/// ".." components may persist in the resolved path if the resolved path is relative or drive-relative.
/// Path separators are canonicalized to '\\' and drives are canonicalized to capital letters.
///
/// The result will not have a trailing path separator, except for the following scenarios:
/// - The resolved path is drive-absolute with no components (e.g. `C:\`).
/// - The resolved path is a UNC path with only a server name, and the input path contained a trailing separator
///   (e.g. `\\server\`).
/// - The resolved path is a UNC path with no components after the share name, and the input path contained a
///   trailing separator (e.g. `\\server\share\`).
///
/// Each drive has its own current working directory, which is only resolved via the paths provided.
/// In the scenario that the resolved path contains a drive-relative path that can't be resolved using the paths alone,
/// the result will be a drive-relative path.
/// Similarly, in the scenario that the resolved path contains a rooted path that can't be resolved using the paths alone,
/// the result will be a rooted path.
///
/// Note: all usage of this function should be audited due to the existence of symlinks.
/// Without performing actual syscalls, resolving `..` could be incorrect.
/// This API may break in the future: https://github.com/ziglang/zig/issues/13613
pub fn resolveWindows(allocator: Allocator, paths: []const []const u8) Allocator.Error![]u8 {
    // Avoid heap allocation when paths.len is <= @bitSizeOf(usize) * 2
    // (we use `* 3` because stackFallback uses 1 usize as a length)
    var bit_set_allocator_state = std.heap.stackFallback(@sizeOf(usize) * 3, allocator);
    const bit_set_allocator = bit_set_allocator_state.get();
    var relevant_paths = try std.bit_set.DynamicBitSetUnmanaged.initEmpty(bit_set_allocator, paths.len);
    defer relevant_paths.deinit(bit_set_allocator);

    // Iterate the paths backwards, marking the relevant paths along the way.
    // This also allows us to break from the loop whenever any earlier paths are known to be irrelevant.
    var first_path_i: usize = paths.len;
    const effective_root_path: WindowsPath2(u8) = root: {
        var last_effective_root_path: WindowsPath2(u8) = .{ .kind = .relative, .root = "" };
        var last_rooted_path_i: ?usize = null;
        var last_drive_relative_path_i: usize = undefined;
        while (first_path_i > 0) {
            first_path_i -= 1;
            const parsed = parsePathWindows(u8, paths[first_path_i]);
            switch (parsed.kind) {
                .unc_absolute, .root_local_device, .local_device => {
                    switch (last_effective_root_path.kind) {
                        .rooted => {},
                        .drive_relative => continue,
                        else => {
                            relevant_paths.set(first_path_i);
                        },
                    }
                    break :root parsed;
                },
                .drive_relative, .drive_absolute => {
                    switch (last_effective_root_path.kind) {
                        .drive_relative => if (!compareDiskDesignators(u8, .drive, parsed.root, last_effective_root_path.root)) {
                            continue;
                        } else if (last_rooted_path_i != null) {
                            break :root .{ .kind = .drive_absolute, .root = parsed.root };
                        },
                        .relative => last_effective_root_path = parsed,
                        .rooted => {
                            // This is the end of the line, since the rooted path will always be relative
                            // to this drive letter, and even if the current path is drive-relative, the
                            // rooted-ness makes that irrelevant.
                            //
                            // Therefore, force the kind of the effective root to be drive-absolute in order to
                            // properly resolve a rooted path against a drive-relative one, as the result should
                            // always be drive-absolute.
                            break :root .{ .kind = .drive_absolute, .root = parsed.root };
                        },
                        .drive_absolute, .unc_absolute, .root_local_device, .local_device => unreachable,
                    }
                    relevant_paths.set(first_path_i);
                    last_drive_relative_path_i = first_path_i;
                    if (parsed.kind == .drive_absolute) {
                        break :root parsed;
                    }
                },
                .relative => {
                    switch (last_effective_root_path.kind) {
                        .rooted => continue,
                        .relative => last_effective_root_path = parsed,
                        else => {},
                    }
                    relevant_paths.set(first_path_i);
                },
                .rooted => {
                    switch (last_effective_root_path.kind) {
                        .drive_relative => {},
                        .relative => last_effective_root_path = parsed,
                        .rooted => continue,
                        .drive_absolute, .unc_absolute, .root_local_device, .local_device => unreachable,
                    }
                    if (last_rooted_path_i == null) {
                        last_rooted_path_i = first_path_i;
                        relevant_paths.set(first_path_i);
                    }
                },
            }
        }
        // After iterating, if the pending effective root is drive-relative then that means
        // nothing has led to forcing a drive-absolute root (a path that allows resolving the
        // drive-specific CWD would cause an early break), so we now need to ignore all paths
        // before the most recent drive-relative one. For example, if we're resolving
        // { "\\rooted", "relative", "C:drive-relative" }
        // then the `\rooted` and `relative` needs to be ignored since we can't
        // know what the rooted path is rooted against as that'd require knowing the CWD.
        if (last_effective_root_path.kind == .drive_relative) {
            for (0..last_drive_relative_path_i) |i| {
                relevant_paths.unset(i);
            }
        }
        break :root last_effective_root_path;
    };

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    var want_path_sep_between_root_and_component = false;
    switch (effective_root_path.kind) {
        .root_local_device, .local_device => {
            try result.ensureUnusedCapacity(allocator, 3);
            result.appendSliceAssumeCapacity("\\\\");
            result.appendAssumeCapacity(effective_root_path.root[2]); // . or ?
            want_path_sep_between_root_and_component = true;
        },
        .drive_absolute, .drive_relative => {
            try result.ensureUnusedCapacity(allocator, effective_root_path.root.len);
            result.appendAssumeCapacity(std.ascii.toUpper(effective_root_path.root[0]));
            result.appendAssumeCapacity(':');
            if (effective_root_path.kind == .drive_absolute) {
                result.appendAssumeCapacity('\\');
            }
        },
        .unc_absolute => {
            const unc = parseUNC(u8, effective_root_path.root);

            const root_len = len: {
                var len: usize = 2 + unc.server.len + unc.share.len;
                if (unc.sep_after_server) len += 1;
                if (unc.sep_after_share) len += 1;
                break :len len;
            };
            try result.ensureUnusedCapacity(allocator, root_len);
            result.appendSliceAssumeCapacity("\\\\");
            if (unc.server.len > 0 or unc.sep_after_server) {
                result.appendSliceAssumeCapacity(unc.server);
                if (unc.sep_after_server)
                    result.appendAssumeCapacity('\\')
                else
                    want_path_sep_between_root_and_component = true;
            }
            if (unc.share.len > 0) {
                result.appendSliceAssumeCapacity(unc.share);
                if (unc.sep_after_share)
                    result.appendAssumeCapacity('\\')
                else
                    want_path_sep_between_root_and_component = true;
            }
        },
        .rooted => {
            try result.append(allocator, '\\');
        },
        .relative => {},
    }

    const root_len = result.items.len;
    var negative_count: usize = 0;
    for (paths[first_path_i..], first_path_i..) |path, i| {
        if (!relevant_paths.isSet(i)) continue;

        const parsed = parsePathWindows(u8, path);
        const skip_len = parsed.root.len;
        var it = mem.tokenizeAny(u8, path[skip_len..], "/\\");
        while (it.next()) |component| {
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                if (result.items.len == 0 or (result.items.len == root_len and effective_root_path.kind == .drive_relative)) {
                    negative_count += 1;
                    continue;
                }
                while (true) {
                    if (result.items.len == root_len) {
                        break;
                    }
                    const end_with_sep = PathType.windows.isSep(u8, result.items[result.items.len - 1]);
                    result.items.len -= 1;
                    if (end_with_sep) break;
                }
            } else if (result.items.len == root_len and !want_path_sep_between_root_and_component) {
                try result.appendSlice(allocator, component);
            } else {
                try result.ensureUnusedCapacity(allocator, 1 + component.len);
                result.appendAssumeCapacity('\\');
                result.appendSliceAssumeCapacity(component);
            }
        }
    }

    if (root_len != 0 and result.items.len == root_len and negative_count == 0) {
        return result.toOwnedSlice(allocator);
    }

    if (result.items.len == root_len) {
        if (negative_count == 0) {
            return allocator.dupe(u8, ".");
        }

        try result.ensureTotalCapacityPrecise(allocator, 3 * negative_count - 1);
        for (0..negative_count - 1) |_| {
            result.appendSliceAssumeCapacity("..\\");
        }
        result.appendSliceAssumeCapacity("..");
    } else {
        const dest = try result.addManyAt(allocator, root_len, 3 * negative_count);
        for (0..negative_count) |i| {
            dest[i * 3 ..][0..3].* = "..\\".*;
        }
    }

    return result.toOwnedSlice(allocator);
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and ".." to the best of its ability, but will not convert relative paths to
/// an absolute path, use std.fs.Dir.realpath instead.
/// ".." components may persist in the resolved path if the resolved path is relative.
/// The result does not have a trailing path separator.
/// This function does not perform any syscalls. Executing this series of path
/// lookups on the actual filesystem may produce different results due to
/// symlinks.
pub fn resolvePosix(allocator: Allocator, paths: []const []const u8) Allocator.Error![]u8 {
    assert(paths.len > 0);

    var result = std.array_list.Managed(u8).init(allocator);
    defer result.deinit();

    var negative_count: usize = 0;
    var is_abs = false;

    for (paths) |p| {
        if (isAbsolutePosix(p)) {
            is_abs = true;
            negative_count = 0;
            result.clearRetainingCapacity();
        }
        var it = mem.tokenizeScalar(u8, p, '/');
        while (it.next()) |component| {
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                if (result.items.len == 0) {
                    negative_count += @intFromBool(!is_abs);
                    continue;
                }
                while (true) {
                    const ends_with_slash = result.items[result.items.len - 1] == '/';
                    result.items.len -= 1;
                    if (ends_with_slash or result.items.len == 0) break;
                }
            } else if (result.items.len > 0 or is_abs) {
                try result.ensureUnusedCapacity(1 + component.len);
                result.appendAssumeCapacity('/');
                result.appendSliceAssumeCapacity(component);
            } else {
                try result.appendSlice(component);
            }
        }
    }

    if (result.items.len == 0) {
        if (is_abs) {
            return allocator.dupe(u8, "/");
        }
        if (negative_count == 0) {
            return allocator.dupe(u8, ".");
        } else {
            const real_result = try allocator.alloc(u8, 3 * negative_count - 1);
            var count = negative_count - 1;
            var i: usize = 0;
            while (count > 0) : (count -= 1) {
                real_result[i..][0..3].* = "../".*;
                i += 3;
            }
            real_result[i..][0..2].* = "..".*;
            return real_result;
        }
    }

    if (negative_count == 0) {
        return result.toOwnedSlice();
    } else {
        const real_result = try allocator.alloc(u8, 3 * negative_count + result.items.len);
        var count = negative_count;
        var i: usize = 0;
        while (count > 0) : (count -= 1) {
            real_result[i..][0..3].* = "../".*;
            i += 3;
        }
        @memcpy(real_result[i..][0..result.items.len], result.items);
        return real_result;
    }
}

test resolve {
    try testResolveWindows(&[_][]const u8{ "a", "..\\..\\.." }, "..\\..");
    try testResolveWindows(&[_][]const u8{ "..", "", "..\\..\\foo" }, "..\\..\\..\\foo");
    try testResolveWindows(&[_][]const u8{ "a\\b\\c\\", "..\\..\\.." }, ".");
    try testResolveWindows(&[_][]const u8{"."}, ".");
    try testResolveWindows(&[_][]const u8{""}, ".");

    try testResolvePosix(&[_][]const u8{ "a", "../../.." }, "../..");
    try testResolvePosix(&[_][]const u8{ "..", "", "../../foo" }, "../../../foo");
    try testResolvePosix(&[_][]const u8{ "a/b/c/", "../../.." }, ".");
    try testResolvePosix(&[_][]const u8{"."}, ".");
    try testResolvePosix(&[_][]const u8{""}, ".");
}

test resolveWindows {
    try testResolveWindows(
        &[_][]const u8{ "Z:\\", "/usr/local", "lib\\zig\\std\\array_list.zig" },
        "Z:\\usr\\local\\lib\\zig\\std\\array_list.zig",
    );
    try testResolveWindows(
        &[_][]const u8{ "z:\\", "usr/local", "lib\\zig" },
        "Z:\\usr\\local\\lib\\zig",
    );

    try testResolveWindows(&[_][]const u8{ "c:\\a\\b\\c", "/hi", "ok" }, "C:\\hi\\ok");
    try testResolveWindows(&[_][]const u8{ "c:\\a\\b\\c\\", ".\\..\\foo" }, "C:\\a\\b\\foo");
    try testResolveWindows(&[_][]const u8{ "c:/blah\\blah", "d:/games", "c:../a" }, "C:\\blah\\a");
    try testResolveWindows(&[_][]const u8{ "c:/blah\\blah", "d:/games", "C:../a" }, "C:\\blah\\a");
    try testResolveWindows(&[_][]const u8{ "c:/ignore", "d:\\a/b\\c/d", "\\e.exe" }, "D:\\e.exe");
    try testResolveWindows(&[_][]const u8{ "c:/ignore", "c:/some/file" }, "C:\\some\\file");
    // The first path "sets" the CWD, so the drive-relative path is then relative to that.
    try testResolveWindows(&[_][]const u8{ "d:/foo", "d:some/dir//", "D:another" }, "D:\\foo\\some\\dir\\another");
    try testResolveWindows(&[_][]const u8{ "//server/share", "..", "relative\\" }, "\\\\server\\share\\relative");
    try testResolveWindows(&[_][]const u8{ "\\\\server/share", "..", "relative\\" }, "\\\\server\\share\\relative");
    try testResolveWindows(&[_][]const u8{ "\\\\server/share/ignore", "//server/share/bar" }, "\\\\server\\share\\bar");
    try testResolveWindows(&[_][]const u8{ "\\/server\\share/", "..", "relative" }, "\\\\server\\share\\relative");
    try testResolveWindows(&[_][]const u8{ "\\\\server\\share", "C:drive-relative" }, "C:drive-relative");
    try testResolveWindows(&[_][]const u8{ "c:/", "//" }, "\\\\");
    try testResolveWindows(&[_][]const u8{ "c:/", "//server" }, "\\\\server");
    try testResolveWindows(&[_][]const u8{ "c:/", "//server/share" }, "\\\\server\\share");
    try testResolveWindows(&[_][]const u8{ "c:/", "//server//share////" }, "\\\\server\\share\\");
    try testResolveWindows(&[_][]const u8{ "c:/", "///some//dir" }, "\\\\\\some\\dir");
    try testResolveWindows(&[_][]const u8{ "c:foo", "bar" }, "C:foo\\bar");
    try testResolveWindows(&[_][]const u8{ "C:\\foo\\tmp.3\\", "..\\tmp.3\\cycles\\root.js" }, "C:\\foo\\tmp.3\\cycles\\root.js");
    // Drive-relative stays drive-relative if there's nothing to provide the drive-specific CWD
    try testResolveWindows(&[_][]const u8{ "relative", "d:foo" }, "D:foo");
    try testResolveWindows(&[_][]const u8{ "../..\\..", "d:foo" }, "D:foo");
    try testResolveWindows(&[_][]const u8{ "../..\\..", "\\rooted", "d:foo" }, "D:foo");
    try testResolveWindows(&[_][]const u8{ "C:\\foo", "../..\\..", "\\rooted", "d:foo" }, "D:foo");
    try testResolveWindows(&[_][]const u8{ "D:relevant", "../..\\..", "d:foo" }, "D:..\\..\\foo");
    try testResolveWindows(&[_][]const u8{ "D:relevant", "../..\\..", "\\\\.\\ignored", "C:\\ignored", "C:ignored", "\\\\ignored", "d:foo" }, "D:..\\..\\foo");
    try testResolveWindows(&[_][]const u8{ "ignored", "\\\\.\\ignored", "C:\\ignored", "C:ignored", "\\\\ignored", "d:foo" }, "D:foo");
    // Rooted paths remain rooted if there's no absolute path available to resolve the "root"
    try testResolveWindows(&[_][]const u8{ "/foo", "bar" }, "\\foo\\bar");
    // Rooted against a UNC path
    try testResolveWindows(&[_][]const u8{ "//server/share/ignore", "/foo", "bar" }, "\\\\server\\share\\foo\\bar");
    try testResolveWindows(&[_][]const u8{ "//server/share/", "/foo" }, "\\\\server\\share\\foo");
    try testResolveWindows(&[_][]const u8{ "//server/share", "/foo" }, "\\\\server\\share\\foo");
    try testResolveWindows(&[_][]const u8{ "//server/", "/foo" }, "\\\\server\\foo");
    try testResolveWindows(&[_][]const u8{ "//server", "/foo" }, "\\\\server\\foo");
    try testResolveWindows(&[_][]const u8{ "//", "/foo" }, "\\\\foo");
    // Rooted against a drive-relative path
    try testResolveWindows(&[_][]const u8{ "C:", "/foo", "bar" }, "C:\\foo\\bar");
    try testResolveWindows(&[_][]const u8{ "C:\\ignore", "C:", "/foo", "bar" }, "C:\\foo\\bar");
    try testResolveWindows(&[_][]const u8{ "C:\\ignore", "\\foo", "C:bar" }, "C:\\foo\\bar");
    // Only the last rooted path is relevant
    try testResolveWindows(&[_][]const u8{ "\\ignore", "\\foo" }, "\\foo");
    try testResolveWindows(&[_][]const u8{ "c:ignore", "ignore", "\\ignore", "\\foo" }, "C:\\foo");
    // Rooted is only relevant to a drive-relative if there's a previous drive-* path
    try testResolveWindows(&[_][]const u8{ "\\ignore", "C:foo" }, "C:foo");
    try testResolveWindows(&[_][]const u8{ "\\ignore", "\\ignore2", "C:foo" }, "C:foo");
    try testResolveWindows(&[_][]const u8{ "c:ignore", "\\ignore", "\\rooted", "C:foo" }, "C:\\rooted\\foo");
    try testResolveWindows(&[_][]const u8{ "c:\\ignore", "\\ignore", "\\rooted", "C:foo" }, "C:\\rooted\\foo");
    try testResolveWindows(&[_][]const u8{ "d:\\ignore", "\\ignore", "\\ignore2", "C:foo" }, "C:foo");
    // Root local device paths
    try testResolveWindows(&[_][]const u8{"\\/."}, "\\\\.");
    try testResolveWindows(&[_][]const u8{ "\\/.", "C:drive-relative" }, "C:drive-relative");
    try testResolveWindows(&[_][]const u8{"/\\?"}, "\\\\?");
    try testResolveWindows(&[_][]const u8{ "ignore", "c:\\ignore", "\\\\.", "foo" }, "\\\\.\\foo");
    try testResolveWindows(&[_][]const u8{ "ignore", "c:\\ignore", "\\\\?", "foo" }, "\\\\?\\foo");
    try testResolveWindows(&[_][]const u8{ "ignore", "c:\\ignore", "//.", "ignore", "\\foo" }, "\\\\.\\foo");
    try testResolveWindows(&[_][]const u8{ "ignore", "c:\\ignore", "\\\\?", "ignore", "\\foo" }, "\\\\?\\foo");

    // Keep relative paths relative.
    try testResolveWindows(&[_][]const u8{"a/b"}, "a\\b");
    try testResolveWindows(&[_][]const u8{".."}, "..");
    try testResolveWindows(&[_][]const u8{"../.."}, "..\\..");
    try testResolveWindows(&[_][]const u8{ "C:foo", "../.." }, "C:..");
    try testResolveWindows(&[_][]const u8{ "d:foo", "../..\\.." }, "D:..\\..");

    // Local device paths treat the \\.\ or \\?\ as the "root", everything afterwards is treated as a regular component.
    try testResolveWindows(&[_][]const u8{ "\\\\?\\C:\\foo", "../bar", "baz" }, "\\\\?\\C:\\bar\\baz");
    try testResolveWindows(&[_][]const u8{ "\\\\.\\C:/foo", "../../../../bar", "baz" }, "\\\\.\\bar\\baz");
    try testResolveWindows(&[_][]const u8{ "//./C:/foo", "../../../../bar", "baz" }, "\\\\.\\bar\\baz");
    try testResolveWindows(&[_][]const u8{ "\\\\.\\foo", ".." }, "\\\\.");
    try testResolveWindows(&[_][]const u8{ "\\\\.\\foo", "..\\.." }, "\\\\.");

    // Paths are assumed to be Win32, so paths that are likely NT paths are treated as a rooted path.
    try testResolveWindows(&[_][]const u8{ "\\??\\C:\\foo", "/bar", "baz" }, "\\bar\\baz");
    try testResolveWindows(&[_][]const u8{ "C:\\", "\\??\\C:\\foo", "bar" }, "C:\\??\\C:\\foo\\bar");
}

test resolvePosix {
    try testResolvePosix(&.{ "/a/b", "c" }, "/a/b/c");
    try testResolvePosix(&.{ "/a/b", "c", "//d", "e///" }, "/d/e");
    try testResolvePosix(&.{ "/a/b/c", "..", "../" }, "/a");
    try testResolvePosix(&.{ "/", "..", ".." }, "/");
    try testResolvePosix(&.{"/a/b/c/"}, "/a/b/c");

    try testResolvePosix(&.{ "/var/lib", "../", "file/" }, "/var/file");
    try testResolvePosix(&.{ "/var/lib", "/../", "file/" }, "/file");
    try testResolvePosix(&.{ "/some/dir", ".", "/absolute/" }, "/absolute");
    try testResolvePosix(&.{ "/foo/tmp.3/", "../tmp.3/cycles/root.js" }, "/foo/tmp.3/cycles/root.js");

    // Keep relative paths relative.
    try testResolvePosix(&.{"a/b"}, "a/b");
    try testResolvePosix(&.{"."}, ".");
    try testResolvePosix(&.{ ".", "src/test.zig", "..", "../test/cases.zig" }, "test/cases.zig");
}

fn testResolveWindows(paths: []const []const u8, expected: []const u8) !void {
    const actual = try resolveWindows(testing.allocator, paths);
    defer testing.allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}

fn testResolvePosix(paths: []const []const u8, expected: []const u8) !void {
    const actual = try resolvePosix(testing.allocator, paths);
    defer testing.allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}

/// Strip the last component from a file path.
///
/// If the path is a file in the current directory (no directory component)
/// then returns null.
///
/// If the path is the root directory, returns null.
pub fn dirname(path: []const u8) ?[]const u8 {
    if (native_os == .windows) {
        return dirnameWindows(path);
    } else {
        return dirnamePosix(path);
    }
}

pub fn dirnameWindows(path: []const u8) ?[]const u8 {
    return dirnameInner(.windows, path);
}

pub fn dirnamePosix(path: []const u8) ?[]const u8 {
    return dirnameInner(.posix, path);
}

fn dirnameInner(comptime path_type: PathType, path: []const u8) ?[]const u8 {
    var it = ComponentIterator(path_type, u8).init(path);
    _ = it.last() orelse return null;
    const up = it.previous() orelse return it.root();
    return up.path;
}

test dirnamePosix {
    try testDirnamePosix("/a/b/c", "/a/b");
    try testDirnamePosix("/a/b/c///", "/a/b");
    try testDirnamePosix("/a", "/");
    try testDirnamePosix("/", null);
    try testDirnamePosix("//", null);
    try testDirnamePosix("///", null);
    try testDirnamePosix("////", null);
    try testDirnamePosix("", null);
    try testDirnamePosix("a", null);
    try testDirnamePosix("a/", null);
    try testDirnamePosix("a//", null);
}

test dirnameWindows {
    try testDirnameWindows("c:\\", null);
    try testDirnameWindows("c:\\\\", null);
    try testDirnameWindows("c:\\foo", "c:\\");
    try testDirnameWindows("c:\\\\foo\\", "c:\\");
    try testDirnameWindows("c:\\foo\\bar", "c:\\foo");
    try testDirnameWindows("c:\\foo\\bar\\", "c:\\foo");
    try testDirnameWindows("c:\\\\foo\\bar\\baz", "c:\\\\foo\\bar");
    try testDirnameWindows("\\", null);
    try testDirnameWindows("\\foo", "\\");
    try testDirnameWindows("\\foo\\", "\\");
    try testDirnameWindows("\\foo\\bar", "\\foo");
    try testDirnameWindows("\\foo\\bar\\", "\\foo");
    try testDirnameWindows("\\foo\\bar\\baz", "\\foo\\bar");
    try testDirnameWindows("c:", null);
    try testDirnameWindows("c:foo", "c:");
    try testDirnameWindows("c:foo\\", "c:");
    try testDirnameWindows("c:foo\\bar", "c:foo");
    try testDirnameWindows("c:foo\\bar\\", "c:foo");
    try testDirnameWindows("c:foo\\bar\\baz", "c:foo\\bar");
    try testDirnameWindows("file:stream", null);
    try testDirnameWindows("dir\\file:stream", "dir");
    try testDirnameWindows("\\\\unc\\share", null);
    try testDirnameWindows("\\\\unc\\share\\\\", null);
    try testDirnameWindows("\\\\unc\\share\\foo", "\\\\unc\\share\\");
    try testDirnameWindows("\\\\unc\\share\\foo\\", "\\\\unc\\share\\");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar", "\\\\unc\\share\\foo");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar\\", "\\\\unc\\share\\foo");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar\\baz", "\\\\unc\\share\\foo\\bar");
    try testDirnameWindows("\\\\.", null);
    try testDirnameWindows("\\\\.\\", null);
    try testDirnameWindows("\\\\.\\device", "\\\\.\\");
    try testDirnameWindows("\\\\.\\device\\", "\\\\.\\");
    try testDirnameWindows("\\\\.\\device\\foo", "\\\\.\\device");
    try testDirnameWindows("\\\\?", null);
    try testDirnameWindows("\\\\?\\", null);
    try testDirnameWindows("\\\\?\\device", "\\\\?\\");
    try testDirnameWindows("\\\\?\\device\\", "\\\\?\\");
    try testDirnameWindows("\\\\?\\device\\foo", "\\\\?\\device");
    try testDirnameWindows("/a/b/", "/a");
    try testDirnameWindows("/a/b", "/a");
    try testDirnameWindows("/a", "/");
    try testDirnameWindows("", null);
    try testDirnameWindows("/", null);
    try testDirnameWindows("////", null);
    try testDirnameWindows("foo", null);
}

fn testDirnamePosix(input: []const u8, expected_output: ?[]const u8) !void {
    if (dirnamePosix(input)) |output| {
        try testing.expect(mem.eql(u8, output, expected_output.?));
    } else {
        try testing.expect(expected_output == null);
    }
}

fn testDirnameWindows(input: []const u8, expected_output: ?[]const u8) !void {
    if (dirnameWindows(input)) |output| {
        try testing.expectEqualStrings(expected_output.?, output);
    } else {
        try testing.expect(expected_output == null);
    }
}

pub fn basename(path: []const u8) []const u8 {
    if (native_os == .windows) {
        return basenameWindows(path);
    } else {
        return basenamePosix(path);
    }
}

pub fn basenamePosix(path: []const u8) []const u8 {
    return basenameInner(.posix, path);
}

pub fn basenameWindows(path: []const u8) []const u8 {
    return basenameInner(.windows, path);
}

fn basenameInner(comptime path_type: PathType, path: []const u8) []const u8 {
    var it = ComponentIterator(path_type, u8).init(path);
    const last = it.last() orelse return &[_]u8{};
    return last.name;
}

test basename {
    try testBasename("", "");
    try testBasename("/", "");
    try testBasename("/dir/basename.ext", "basename.ext");
    try testBasename("/basename.ext", "basename.ext");
    try testBasename("basename.ext", "basename.ext");
    try testBasename("basename.ext/", "basename.ext");
    try testBasename("basename.ext//", "basename.ext");
    try testBasename("/aaa/bbb", "bbb");
    try testBasename("/aaa/", "aaa");
    try testBasename("/aaa/b", "b");
    try testBasename("/a/b", "b");

    // For Windows, this is a UNC path that only has a server name component.
    try testBasename("//a", if (native_os == .windows) "" else "a");

    try testBasenamePosix("\\dir\\basename.ext", "\\dir\\basename.ext");
    try testBasenamePosix("\\basename.ext", "\\basename.ext");
    try testBasenamePosix("basename.ext", "basename.ext");
    try testBasenamePosix("basename.ext\\", "basename.ext\\");
    try testBasenamePosix("basename.ext\\\\", "basename.ext\\\\");
    try testBasenamePosix("foo", "foo");

    try testBasenameWindows("\\dir\\basename.ext", "basename.ext");
    try testBasenameWindows("\\basename.ext", "basename.ext");
    try testBasenameWindows("basename.ext", "basename.ext");
    try testBasenameWindows("basename.ext\\", "basename.ext");
    try testBasenameWindows("basename.ext\\\\", "basename.ext");
    try testBasenameWindows("foo", "foo");
    try testBasenameWindows("C:", "");
    try testBasenameWindows("C:.", ".");
    try testBasenameWindows("C:\\", "");
    try testBasenameWindows("C:\\dir\\base.ext", "base.ext");
    try testBasenameWindows("C:\\basename.ext", "basename.ext");
    try testBasenameWindows("C:basename.ext", "basename.ext");
    try testBasenameWindows("C:basename.ext\\", "basename.ext");
    try testBasenameWindows("C:basename.ext\\\\", "basename.ext");
    try testBasenameWindows("\\\\.", "");
    try testBasenameWindows("\\\\.\\", "");
    try testBasenameWindows("\\\\.\\basename.ext", "basename.ext");
    try testBasenameWindows("\\\\?", "");
    try testBasenameWindows("\\\\?\\", "");
    try testBasenameWindows("\\\\?\\basename.ext", "basename.ext");
    try testBasenameWindows("C:foo", "foo");
    try testBasenameWindows("file:stream", "file:stream");
}

fn testBasename(input: []const u8, expected_output: []const u8) !void {
    try testing.expectEqualSlices(u8, expected_output, basename(input));
}

fn testBasenamePosix(input: []const u8, expected_output: []const u8) !void {
    try testing.expectEqualSlices(u8, expected_output, basenamePosix(input));
}

fn testBasenameWindows(input: []const u8, expected_output: []const u8) !void {
    try testing.expectEqualSlices(u8, expected_output, basenameWindows(input));
}

pub const RelativeError = std.process.GetCwdAllocError;

/// Returns the relative path from `from` to `to`. If `from` and `to` each
/// resolve to the same path (after calling `resolve` on each), a zero-length
/// string is returned.
/// On Windows, the result is not guaranteed to be relative, as the paths may be
/// on different volumes. In that case, the result will be the canonicalized absolute
/// path of `to`.
pub fn relative(allocator: Allocator, from: []const u8, to: []const u8) RelativeError![]u8 {
    if (native_os == .windows) {
        return relativeWindows(allocator, from, to);
    } else {
        return relativePosix(allocator, from, to);
    }
}

pub fn relativeWindows(allocator: Allocator, from: []const u8, to: []const u8) ![]u8 {
    if (native_os != .windows) @compileError("this function relies on Windows-specific semantics");

    const parsed_from = parsePathWindows(u8, from);
    const parsed_to = parsePathWindows(u8, to);

    const result_is_always_to = x: {
        if (parsed_from.kind != parsed_to.kind) {
            break :x false;
        }
        switch (parsed_from.kind) {
            .drive_relative, .drive_absolute => {
                break :x !compareDiskDesignators(u8, .drive, parsed_from.root, parsed_to.root);
            },
            .unc_absolute => {
                break :x !compareDiskDesignators(u8, .unc, parsed_from.root, parsed_to.root);
            },
            .relative, .rooted, .local_device => break :x false,
            .root_local_device => break :x true,
        }
    };

    if (result_is_always_to) {
        return windowsResolveAgainstCwd(allocator, to, parsed_to);
    }

    const resolved_from = try windowsResolveAgainstCwd(allocator, from, parsed_from);
    defer allocator.free(resolved_from);
    var clean_up_resolved_to = true;
    const resolved_to = try windowsResolveAgainstCwd(allocator, to, parsed_to);
    defer if (clean_up_resolved_to) allocator.free(resolved_to);

    const parsed_resolved_from = parsePathWindows(u8, resolved_from);
    const parsed_resolved_to = parsePathWindows(u8, resolved_to);

    const result_is_to = x: {
        if (parsed_resolved_from.kind != parsed_resolved_to.kind) {
            break :x true;
        }
        switch (parsed_resolved_from.kind) {
            .drive_absolute, .drive_relative => {
                break :x !compareDiskDesignators(u8, .drive, parsed_resolved_from.root, parsed_resolved_to.root);
            },
            .unc_absolute => {
                break :x !compareDiskDesignators(u8, .unc, parsed_resolved_from.root, parsed_resolved_to.root);
            },
            .relative, .rooted, .local_device => break :x false,
            .root_local_device => break :x true,
        }
    };

    if (result_is_to) {
        clean_up_resolved_to = false;
        return resolved_to;
    }

    var from_it = mem.tokenizeAny(u8, resolved_from[parsed_resolved_from.root.len..], "/\\");
    var to_it = mem.tokenizeAny(u8, resolved_to[parsed_resolved_to.root.len..], "/\\");
    while (true) {
        const from_component = from_it.next() orelse return allocator.dupe(u8, to_it.rest());
        const to_rest = to_it.rest();
        if (to_it.next()) |to_component| {
            if (windows.eqlIgnoreCaseWtf8(from_component, to_component))
                continue;
        }
        var up_index_end = "..".len;
        while (from_it.next()) |_| {
            up_index_end += "\\..".len;
        }
        const result = try allocator.alloc(u8, up_index_end + @intFromBool(to_rest.len > 0) + to_rest.len);
        errdefer allocator.free(result);

        result[0..2].* = "..".*;
        var result_index: usize = 2;
        while (result_index < up_index_end) {
            result[result_index..][0..3].* = "\\..".*;
            result_index += 3;
        }

        var rest_it = mem.tokenizeAny(u8, to_rest, "/\\");
        while (rest_it.next()) |to_component| {
            result[result_index] = '\\';
            result_index += 1;
            @memcpy(result[result_index..][0..to_component.len], to_component);
            result_index += to_component.len;
        }

        return allocator.realloc(result, result_index);
    }
    return [_]u8{};
}

fn windowsResolveAgainstCwd(allocator: Allocator, path: []const u8, parsed: WindowsPath2(u8)) ![]u8 {
    // Space for 256 WTF-16 code units; potentially 3 WTF-8 bytes per WTF-16 code unit
    var temp_allocator_state = std.heap.stackFallback(256 * 3, allocator);
    return switch (parsed.kind) {
        .drive_absolute,
        .unc_absolute,
        .root_local_device,
        .local_device,
        => try resolveWindows(allocator, &.{path}),
        .relative => blk: {
            const temp_allocator = temp_allocator_state.get();

            const peb_cwd = windows.peb().ProcessParameters.CurrentDirectory.DosPath;
            const cwd_w = (peb_cwd.Buffer.?)[0 .. peb_cwd.Length / 2];

            const wtf8_len = std.unicode.calcWtf8Len(cwd_w);
            const wtf8_buf = try temp_allocator.alloc(u8, wtf8_len);
            defer temp_allocator.free(wtf8_buf);
            assert(std.unicode.wtf16LeToWtf8(wtf8_buf, cwd_w) == wtf8_len);

            break :blk try resolveWindows(allocator, &.{ wtf8_buf, path });
        },
        .rooted => blk: {
            const peb_cwd = windows.peb().ProcessParameters.CurrentDirectory.DosPath;
            const cwd_w = (peb_cwd.Buffer.?)[0 .. peb_cwd.Length / 2];
            const parsed_cwd = parsePathWindows(u16, cwd_w);
            switch (parsed_cwd.kind) {
                .drive_absolute => {
                    var drive_buf = "_:\\".*;
                    drive_buf[0] = @truncate(cwd_w[0]);
                    break :blk try resolveWindows(allocator, &.{ &drive_buf, path });
                },
                .unc_absolute => {
                    const temp_allocator = temp_allocator_state.get();
                    var root_buf = try temp_allocator.alloc(u8, parsed_cwd.root.len * 3);
                    defer temp_allocator.free(root_buf);

                    const wtf8_len = std.unicode.wtf16LeToWtf8(root_buf, parsed_cwd.root);
                    const root = root_buf[0..wtf8_len];
                    break :blk try resolveWindows(allocator, &.{ root, path });
                },
                // Effectively a malformed CWD, give up and just return a normalized path
                else => break :blk try resolveWindows(allocator, &.{path}),
            }
        },
        .drive_relative => blk: {
            const temp_allocator = temp_allocator_state.get();
            const drive_cwd = drive_cwd: {
                const peb_cwd = windows.peb().ProcessParameters.CurrentDirectory.DosPath;
                const cwd_w = (peb_cwd.Buffer.?)[0 .. peb_cwd.Length / 2];
                const parsed_cwd = parsePathWindows(u16, cwd_w);

                if (parsed_cwd.kind == .drive_absolute) {
                    const drive_letter_w = parsed_cwd.root[0];
                    const drive_letters_match = drive_letter_w <= 0x7F and
                        ascii.toUpper(@intCast(drive_letter_w)) == ascii.toUpper(parsed.root[0]);
                    if (drive_letters_match) {
                        const wtf8_len = std.unicode.calcWtf8Len(cwd_w);
                        const wtf8_buf = try temp_allocator.alloc(u8, wtf8_len);
                        assert(std.unicode.wtf16LeToWtf8(wtf8_buf, cwd_w) == wtf8_len);
                        break :drive_cwd wtf8_buf[0..];
                    }

                    // Per-drive CWD's are stored in special semi-hidden environment variables
                    // of the format `=<drive-letter>:`, e.g. `=C:`. This type of CWD is
                    // purely a shell concept, so there's no guarantee that it'll be set
                    // or that it'll even be accurate.
                    var key_buf = std.unicode.wtf8ToWtf16LeStringLiteral("=_:").*;
                    key_buf[1] = parsed.root[0];
                    if (std.process.getenvW(&key_buf)) |drive_cwd_w| {
                        const wtf8_len = std.unicode.calcWtf8Len(drive_cwd_w);
                        const wtf8_buf = try temp_allocator.alloc(u8, wtf8_len);
                        assert(std.unicode.wtf16LeToWtf8(wtf8_buf, drive_cwd_w) == wtf8_len);
                        break :drive_cwd wtf8_buf[0..];
                    }
                }

                const drive_buf = try temp_allocator.alloc(u8, 3);
                drive_buf[0] = parsed.root[0];
                drive_buf[1] = ':';
                drive_buf[2] = '\\';
                break :drive_cwd drive_buf;
            };
            defer temp_allocator.free(drive_cwd);
            break :blk try resolveWindows(allocator, &.{ drive_cwd, path });
        },
    };
}

pub fn relativePosix(allocator: Allocator, from: []const u8, to: []const u8) ![]u8 {
    if (native_os == .windows) @compileError("this function relies on semantics that do not apply to Windows");

    const cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    const resolved_from = try resolvePosix(allocator, &[_][]const u8{ cwd, from });
    defer allocator.free(resolved_from);
    const resolved_to = try resolvePosix(allocator, &[_][]const u8{ cwd, to });
    defer allocator.free(resolved_to);

    var from_it = mem.tokenizeScalar(u8, resolved_from, '/');
    var to_it = mem.tokenizeScalar(u8, resolved_to, '/');
    while (true) {
        const from_component = from_it.next() orelse return allocator.dupe(u8, to_it.rest());
        const to_rest = to_it.rest();
        if (to_it.next()) |to_component| {
            if (mem.eql(u8, from_component, to_component))
                continue;
        }
        var up_count: usize = 1;
        while (from_it.next()) |_| {
            up_count += 1;
        }
        const up_index_end = up_count * "../".len;
        const result = try allocator.alloc(u8, up_index_end + to_rest.len);
        errdefer allocator.free(result);

        var result_index: usize = 0;
        while (result_index < up_index_end) {
            result[result_index..][0..3].* = "../".*;
            result_index += 3;
        }
        if (to_rest.len == 0) {
            // shave off the trailing slash
            return allocator.realloc(result, result_index - 1);
        }

        @memcpy(result[result_index..][0..to_rest.len], to_rest);
        return result;
    }

    return [_]u8{};
}

test relative {
    if (native_os == .windows) {
        try testRelativeWindows("c:/blah\\blah", "d:/games", "D:\\games");
        try testRelativeWindows("c:/aaaa/bbbb", "c:/aaaa", "..");
        try testRelativeWindows("c:/aaaa/bbbb", "c:/cccc", "..\\..\\cccc");
        try testRelativeWindows("c:/aaaa/bbbb", "C:/aaaa/bbbb", "");
        try testRelativeWindows("c:/aaaa/bbbb", "c:/aaaa/cccc", "..\\cccc");
        try testRelativeWindows("c:/aaaa/", "c:/aaaa/cccc", "cccc");
        try testRelativeWindows("c:/", "c:\\aaaa\\bbbb", "aaaa\\bbbb");
        try testRelativeWindows("c:/aaaa/bbbb", "d:\\", "D:\\");
        try testRelativeWindows("c:/AaAa/bbbb", "c:/aaaa/bbbb", "");
        try testRelativeWindows("c:/aaaaa/", "c:/aaaa/cccc", "..\\aaaa\\cccc");
        try testRelativeWindows("C:\\foo\\bar\\baz\\quux", "C:\\", "..\\..\\..\\..");
        try testRelativeWindows("C:\\foo\\test", "C:\\foo\\test\\bar\\package.json", "bar\\package.json");
        try testRelativeWindows("C:\\foo\\bar\\baz-quux", "C:\\foo\\bar\\baz", "..\\baz");
        try testRelativeWindows("C:\\foo\\bar\\baz", "C:\\foo\\bar\\baz-quux", "..\\baz-quux");
        try testRelativeWindows("\\\\foo\\bar", "\\\\foo\\bar\\baz", "baz");
        try testRelativeWindows("\\\\foo\\bar\\baz", "\\\\foo\\bar", "..");
        try testRelativeWindows("\\\\foo\\bar\\baz-quux", "\\\\foo\\bar\\baz", "..\\baz");
        try testRelativeWindows("\\\\foo/bar\\baz-quux", "//foo\\bar/baz", "..\\baz");
        try testRelativeWindows("\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz-quux", "..\\baz-quux");
        try testRelativeWindows("C:\\baz-quux", "C:\\baz", "..\\baz");
        try testRelativeWindows("C:\\baz", "C:\\baz-quux", "..\\baz-quux");
        try testRelativeWindows("\\\\foo\\baz-quux", "\\\\foo\\baz", "\\\\foo\\baz");
        try testRelativeWindows("\\\\foo\\baz", "\\\\foo\\baz-quux", "\\\\foo\\baz-quux");
        try testRelativeWindows("C:\\baz", "\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz");
        try testRelativeWindows("\\\\foo\\bar\\baz", "C:\\baz", "C:\\baz");

        try testRelativeWindows("c:blah\\blah", "c:foo", "..\\..\\foo");
        try testRelativeWindows("c:foo", "c:foo\\bar", "bar");
        try testRelativeWindows("\\blah\\blah", "\\foo", "..\\..\\foo");
        try testRelativeWindows("\\foo", "\\foo\\bar", "bar");

        try testRelativeWindows("a/b/c", "a\\b", "..");
        try testRelativeWindows("a/b/c", "a", "..\\..");
        try testRelativeWindows("a/b/c", "a\\b\\c\\d", "d");

        try testRelativeWindows("\\\\FOO\\bar\\baz", "\\\\foo\\BAR\\BAZ", "");
        // Unicode-aware case-insensitive path comparison
        try testRelativeWindows("\\\\кириллица\\ελληνικά\\português", "\\\\КИРИЛЛИЦА\\ΕΛΛΗΝΙΚΆ\\PORTUGUÊS", "");
    } else {
        try testRelativePosix("/var/lib", "/var", "..");
        try testRelativePosix("/var/lib", "/bin", "../../bin");
        try testRelativePosix("/var/lib", "/var/lib", "");
        try testRelativePosix("/var/lib", "/var/apache", "../apache");
        try testRelativePosix("/var/", "/var/lib", "lib");
        try testRelativePosix("/", "/var/lib", "var/lib");
        try testRelativePosix("/foo/test", "/foo/test/bar/package.json", "bar/package.json");
        try testRelativePosix("/Users/a/web/b/test/mails", "/Users/a/web/b", "../..");
        try testRelativePosix("/foo/bar/baz-quux", "/foo/bar/baz", "../baz");
        try testRelativePosix("/foo/bar/baz", "/foo/bar/baz-quux", "../baz-quux");
        try testRelativePosix("/baz-quux", "/baz", "../baz");
        try testRelativePosix("/baz", "/baz-quux", "../baz-quux");
    }
}

fn testRelativePosix(from: []const u8, to: []const u8, expected_output: []const u8) !void {
    const result = try relativePosix(testing.allocator, from, to);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected_output, result);
}

fn testRelativeWindows(from: []const u8, to: []const u8, expected_output: []const u8) !void {
    const result = try relativeWindows(testing.allocator, from, to);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected_output, result);
}

/// Searches for a file extension separated by a `.` and returns the string after that `.`.
/// Files that end or start with `.` and have no other `.` in their name
/// are considered to have no extension, in which case this returns "".
/// Examples:
/// - `"main.zig"`      ⇒ `".zig"`
/// - `"src/main.zig"`  ⇒ `".zig"`
/// - `".gitignore"`    ⇒ `""`
/// - `".image.png"`    ⇒ `".png"`
/// - `"keep."`         ⇒ `"."`
/// - `"src.keep.me"`   ⇒ `".me"`
/// - `"/src/keep.me"`  ⇒ `".me"`
/// - `"/src/keep.me/"` ⇒ `".me"`
/// The returned slice is guaranteed to have its pointer within the start and end
/// pointer address range of `path`, even if it is length zero.
pub fn extension(path: []const u8) []const u8 {
    const filename = basename(path);
    const index = mem.lastIndexOfScalar(u8, filename, '.') orelse return path[path.len..];
    if (index == 0) return path[path.len..];
    return filename[index..];
}

fn testExtension(path: []const u8, expected: []const u8) !void {
    try testing.expectEqualStrings(expected, extension(path));
}

test extension {
    try testExtension("", "");
    try testExtension(".", "");
    try testExtension("a.", ".");
    try testExtension("abc.", ".");
    try testExtension(".a", "");
    try testExtension(".file", "");
    try testExtension(".gitignore", "");
    try testExtension(".image.png", ".png");
    try testExtension("file.ext", ".ext");
    try testExtension("file.ext.", ".");
    try testExtension("very-long-file.bruh", ".bruh");
    try testExtension("a.b.c", ".c");
    try testExtension("a.b.c/", ".c");

    try testExtension("/", "");
    try testExtension("/.", "");
    try testExtension("/a.", ".");
    try testExtension("/abc.", ".");
    try testExtension("/.a", "");
    try testExtension("/.file", "");
    try testExtension("/.gitignore", "");
    try testExtension("/file.ext", ".ext");
    try testExtension("/file.ext.", ".");
    try testExtension("/very-long-file.bruh", ".bruh");
    try testExtension("/a.b.c", ".c");
    try testExtension("/a.b.c/", ".c");

    try testExtension("/foo/bar/bam/", "");
    try testExtension("/foo/bar/bam/.", "");
    try testExtension("/foo/bar/bam/a.", ".");
    try testExtension("/foo/bar/bam/abc.", ".");
    try testExtension("/foo/bar/bam/.a", "");
    try testExtension("/foo/bar/bam/.file", "");
    try testExtension("/foo/bar/bam/.gitignore", "");
    try testExtension("/foo/bar/bam/file.ext", ".ext");
    try testExtension("/foo/bar/bam/file.ext.", ".");
    try testExtension("/foo/bar/bam/very-long-file.bruh", ".bruh");
    try testExtension("/foo/bar/bam/a.b.c", ".c");
    try testExtension("/foo/bar/bam/a.b.c/", ".c");
}

/// Returns the last component of this path without its extension (if any):
/// - "hello/world/lib.tar.gz" ⇒ "lib.tar"
/// - "hello/world/lib.tar"    ⇒ "lib"
/// - "hello/world/lib"        ⇒ "lib"
pub fn stem(path: []const u8) []const u8 {
    const filename = basename(path);
    const index = mem.lastIndexOfScalar(u8, filename, '.') orelse return filename[0..];
    if (index == 0) return path;
    return filename[0..index];
}

fn testStem(path: []const u8, expected: []const u8) !void {
    try testing.expectEqualStrings(expected, stem(path));
}

test stem {
    try testStem("hello/world/lib.tar.gz", "lib.tar");
    try testStem("hello/world/lib.tar", "lib");
    try testStem("hello/world/lib", "lib");
    try testStem("hello/lib/", "lib");
    try testStem("hello...", "hello..");
    try testStem("hello.", "hello");
    try testStem("/hello.", "hello");
    try testStem(".gitignore", ".gitignore");
    try testStem(".image.png", ".image");
    try testStem("file.ext", "file");
    try testStem("file.ext.", "file.ext");
    try testStem("a.b.c", "a.b");
    try testStem("a.b.c/", "a.b");
    try testStem(".a", ".a");
    try testStem("///", "");
    try testStem("..", ".");
    try testStem(".", ".");
    try testStem(" ", " ");
    try testStem("", "");
}

/// A path component iterator that can move forwards and backwards.
/// The 'root' of the path (`/` for POSIX, things like `C:\`, `\\server\share\`, etc
/// for Windows) is treated specially and will never be returned by any of the
/// `first`, `last`, `next`, or `previous` functions.
/// Multiple consecutive path separators are skipped (treated as a single separator)
/// when iterating.
/// All returned component names/paths are slices of the original path.
/// There is no normalization of paths performed while iterating.
pub fn ComponentIterator(comptime path_type: PathType, comptime T: type) type {
    return struct {
        path: []const T,
        /// Length of the root with at most one trailing path separator included (e.g. `C:/`).
        root_len: usize,
        /// Length of the root with all trailing path separators included (e.g. `C://///`).
        root_end_index: usize,
        start_index: usize = 0,
        end_index: usize = 0,

        const Self = @This();

        pub const Component = struct {
            /// The current component's path name, e.g. 'b'.
            /// This will never contain path separators.
            name: []const T,
            /// The full path up to and including the current component, e.g. '/a/b'
            /// This will never contain trailing path separators.
            path: []const T,
        };

        /// After `init`, `next` will return the first component after the root
        /// (there is no need to call `first` after `init`).
        /// To iterate backwards (from the end of the path to the beginning), call `last`
        /// after `init` and then iterate via `previous` calls.
        /// For Windows paths, paths are assumed to be in the Win32 namespace.
        pub fn init(path: []const T) Self {
            const root_len: usize = switch (path_type) {
                .posix, .uefi => posix: {
                    // Root on UEFI and POSIX only differs by the path separator
                    break :posix if (path.len > 0 and path_type.isSep(T, path[0])) 1 else 0;
                },
                .windows => windows: {
                    break :windows parsePathWindows(T, path).root.len;
                },
            };
            // If there are repeated path separators directly after the root,
            // keep track of that info so that they don't have to be dealt with when
            // iterating components.
            var root_end_index = root_len;
            for (path[root_len..]) |c| {
                if (!path_type.isSep(T, c)) break;
                root_end_index += 1;
            }
            return .{
                .path = path,
                .root_len = root_len,
                .root_end_index = root_end_index,
                .start_index = root_end_index,
                .end_index = root_end_index,
            };
        }

        /// Returns the root of the path if it is not a relative path, or null otherwise.
        /// For POSIX paths, this will be `/`.
        /// For Windows paths, this will be something like `C:\`, `\\server\share\`, etc.
        /// For UEFI paths, this will be `\`.
        pub fn root(self: Self) ?[]const T {
            if (self.root_end_index == 0) return null;
            return self.path[0..self.root_len];
        }

        /// Returns the first component (from the beginning of the path).
        /// For example, if the path is `/a/b/c` then this will return the `a` component.
        /// After calling `first`, `previous` will always return `null`, and `next` will return
        /// the component to the right of the one returned by `first`, if any exist.
        pub fn first(self: *Self) ?Component {
            self.start_index = self.root_end_index;
            self.end_index = self.start_index;
            while (self.end_index < self.path.len and !path_type.isSep(T, self.path[self.end_index])) {
                self.end_index += 1;
            }
            if (self.end_index == self.start_index) return null;
            return .{
                .name = self.path[self.start_index..self.end_index],
                .path = self.path[0..self.end_index],
            };
        }

        /// Returns the last component (from the end of the path).
        /// For example, if the path is `/a/b/c` then this will return the `c` component.
        /// After calling `last`, `next` will always return `null`, and `previous` will return
        /// the component to the left of the one returned by `last`, if any exist.
        pub fn last(self: *Self) ?Component {
            self.end_index = self.path.len;
            while (true) {
                if (self.end_index == self.root_end_index) {
                    self.start_index = self.end_index;
                    return null;
                }
                if (!path_type.isSep(T, self.path[self.end_index - 1])) break;
                self.end_index -= 1;
            }
            self.start_index = self.end_index;
            while (true) {
                if (self.start_index == self.root_end_index) break;
                if (path_type.isSep(T, self.path[self.start_index - 1])) break;
                self.start_index -= 1;
            }
            if (self.start_index == self.end_index) return null;
            return .{
                .name = self.path[self.start_index..self.end_index],
                .path = self.path[0..self.end_index],
            };
        }

        /// Returns the next component (the component to the right of the most recently
        /// returned component), or null if no such component exists.
        /// For example, if the path is `/a/b/c` and the most recently returned component
        /// is `b`, then this will return the `c` component.
        pub fn next(self: *Self) ?Component {
            const peek_result = self.peekNext() orelse return null;
            self.start_index = peek_result.path.len - peek_result.name.len;
            self.end_index = peek_result.path.len;
            return peek_result;
        }

        /// Like `next`, but does not modify the iterator state.
        pub fn peekNext(self: Self) ?Component {
            var start_index = self.end_index;
            while (start_index < self.path.len and path_type.isSep(T, self.path[start_index])) {
                start_index += 1;
            }
            var end_index = start_index;
            while (end_index < self.path.len and !path_type.isSep(T, self.path[end_index])) {
                end_index += 1;
            }
            if (start_index == end_index) return null;
            return .{
                .name = self.path[start_index..end_index],
                .path = self.path[0..end_index],
            };
        }

        /// Returns the previous component (the component to the left of the most recently
        /// returned component), or null if no such component exists.
        /// For example, if the path is `/a/b/c` and the most recently returned component
        /// is `b`, then this will return the `a` component.
        pub fn previous(self: *Self) ?Component {
            const peek_result = self.peekPrevious() orelse return null;
            self.start_index = peek_result.path.len - peek_result.name.len;
            self.end_index = peek_result.path.len;
            return peek_result;
        }

        /// Like `previous`, but does not modify the iterator state.
        pub fn peekPrevious(self: Self) ?Component {
            var end_index = self.start_index;
            while (true) {
                if (end_index == self.root_end_index) return null;
                if (!path_type.isSep(T, self.path[end_index - 1])) break;
                end_index -= 1;
            }
            var start_index = end_index;
            while (true) {
                if (start_index == self.root_end_index) break;
                if (path_type.isSep(T, self.path[start_index - 1])) break;
                start_index -= 1;
            }
            if (start_index == end_index) return null;
            return .{
                .name = self.path[start_index..end_index],
                .path = self.path[0..end_index],
            };
        }
    };
}

pub const NativeComponentIterator = ComponentIterator(switch (native_os) {
    .windows => .windows,
    .uefi => .uefi,
    else => .posix,
}, u8);

pub fn componentIterator(path: []const u8) NativeComponentIterator {
    return NativeComponentIterator.init(path);
}

test "ComponentIterator posix" {
    const PosixComponentIterator = ComponentIterator(.posix, u8);
    {
        const path = "a/b/c/";
        var it = PosixComponentIterator.init(path);
        try std.testing.expectEqual(0, it.root_len);
        try std.testing.expectEqual(0, it.root_end_index);
        try std.testing.expect(null == it.root());
        {
            try std.testing.expect(null == it.previous());

            const first_via_next = it.next().?;
            try std.testing.expectEqualStrings("a", first_via_next.name);
            try std.testing.expectEqualStrings("a", first_via_next.path);

            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("a", first.path);

            try std.testing.expect(null == it.previous());

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("a/b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("a/b/c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("a/b/c", last.path);

            try std.testing.expect(null == it.next());

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("a/b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "/a/b/c/";
        var it = PosixComponentIterator.init(path);
        try std.testing.expectEqual(1, it.root_len);
        try std.testing.expectEqual(1, it.root_end_index);
        try std.testing.expectEqualStrings("/", it.root().?);
        {
            try std.testing.expect(null == it.previous());

            const first_via_next = it.next().?;
            try std.testing.expectEqualStrings("a", first_via_next.name);
            try std.testing.expectEqualStrings("/a", first_via_next.path);

            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("/a", first.path);

            try std.testing.expect(null == it.previous());

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("/a/b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("/a/b/c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("/a/b/c", last.path);

            try std.testing.expect(null == it.next());

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("/a/b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("/a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "////a///b///c////";
        var it = PosixComponentIterator.init(path);
        try std.testing.expectEqual(1, it.root_len);
        try std.testing.expectEqual(4, it.root_end_index);
        try std.testing.expectEqualStrings("/", it.root().?);
        {
            try std.testing.expect(null == it.previous());

            const first_via_next = it.next().?;
            try std.testing.expectEqualStrings("a", first_via_next.name);
            try std.testing.expectEqualStrings("////a", first_via_next.path);

            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("////a", first.path);

            try std.testing.expect(null == it.previous());

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("////a///b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("////a///b///c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("////a///b///c", last.path);

            try std.testing.expect(null == it.next());

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("////a///b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("////a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "/";
        var it = PosixComponentIterator.init(path);
        try std.testing.expectEqual(1, it.root_len);
        try std.testing.expectEqual(1, it.root_end_index);
        try std.testing.expectEqualStrings("/", it.root().?);

        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.next());

        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.next());
    }

    {
        const path = "";
        var it = PosixComponentIterator.init(path);
        try std.testing.expectEqual(0, it.root_len);
        try std.testing.expectEqual(0, it.root_end_index);
        try std.testing.expect(null == it.root());

        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.next());

        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.next());
    }
}

test "ComponentIterator windows" {
    const WindowsComponentIterator = ComponentIterator(.windows, u8);
    {
        const path = "a/b\\c//";
        var it = WindowsComponentIterator.init(path);
        try std.testing.expectEqual(0, it.root_len);
        try std.testing.expectEqual(0, it.root_end_index);
        try std.testing.expect(null == it.root());
        {
            try std.testing.expect(null == it.previous());

            const first_via_next = it.next().?;
            try std.testing.expectEqualStrings("a", first_via_next.name);
            try std.testing.expectEqualStrings("a", first_via_next.path);

            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("a", first.path);

            try std.testing.expect(null == it.previous());

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("a/b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("a/b\\c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("a/b\\c", last.path);

            try std.testing.expect(null == it.next());

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("a/b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "C:\\a/b/c/";
        var it = WindowsComponentIterator.init(path);
        try std.testing.expectEqual(3, it.root_len);
        try std.testing.expectEqual(3, it.root_end_index);
        try std.testing.expectEqualStrings("C:\\", it.root().?);
        {
            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("C:\\a", first.path);

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("C:\\a/b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("C:\\a/b/c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("C:\\a/b/c", last.path);

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("C:\\a/b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("C:\\a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "C:\\\\//a/\\/\\b///c////";
        var it = WindowsComponentIterator.init(path);
        try std.testing.expectEqual(3, it.root_len);
        try std.testing.expectEqual(6, it.root_end_index);
        try std.testing.expectEqualStrings("C:\\", it.root().?);
        {
            const first = it.first().?;
            try std.testing.expectEqualStrings("a", first.name);
            try std.testing.expectEqualStrings("C:\\\\//a", first.path);

            const second = it.next().?;
            try std.testing.expectEqualStrings("b", second.name);
            try std.testing.expectEqualStrings("C:\\\\//a/\\/\\b", second.path);

            const third = it.next().?;
            try std.testing.expectEqualStrings("c", third.name);
            try std.testing.expectEqualStrings("C:\\\\//a/\\/\\b///c", third.path);

            try std.testing.expect(null == it.next());
        }
        {
            const last = it.last().?;
            try std.testing.expectEqualStrings("c", last.name);
            try std.testing.expectEqualStrings("C:\\\\//a/\\/\\b///c", last.path);

            const second_to_last = it.previous().?;
            try std.testing.expectEqualStrings("b", second_to_last.name);
            try std.testing.expectEqualStrings("C:\\\\//a/\\/\\b", second_to_last.path);

            const third_to_last = it.previous().?;
            try std.testing.expectEqualStrings("a", third_to_last.name);
            try std.testing.expectEqualStrings("C:\\\\//a", third_to_last.path);

            try std.testing.expect(null == it.previous());
        }
    }

    {
        const path = "/";
        var it = WindowsComponentIterator.init(path);
        try std.testing.expectEqual(1, it.root_len);
        try std.testing.expectEqual(1, it.root_end_index);
        try std.testing.expectEqualStrings("/", it.root().?);

        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.next());

        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.next());
    }

    {
        const path = "";
        var it = WindowsComponentIterator.init(path);
        try std.testing.expectEqual(0, it.root_len);
        try std.testing.expectEqual(0, it.root_end_index);
        try std.testing.expect(null == it.root());

        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.first());
        try std.testing.expect(null == it.next());

        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.previous());
        try std.testing.expect(null == it.last());
        try std.testing.expect(null == it.next());
    }
}

test "ComponentIterator windows WTF-16" {
    const WindowsComponentIterator = ComponentIterator(.windows, u16);
    const L = std.unicode.utf8ToUtf16LeStringLiteral;

    const path = L("C:\\a/b/c/");
    var it = WindowsComponentIterator.init(path);
    try std.testing.expectEqual(3, it.root_len);
    try std.testing.expectEqual(3, it.root_end_index);
    try std.testing.expectEqualSlices(u16, L("C:\\"), it.root().?);
    {
        const first = it.first().?;
        try std.testing.expectEqualSlices(u16, L("a"), first.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a"), first.path);

        const second = it.next().?;
        try std.testing.expectEqualSlices(u16, L("b"), second.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a/b"), second.path);

        const third = it.next().?;
        try std.testing.expectEqualSlices(u16, L("c"), third.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a/b/c"), third.path);

        try std.testing.expect(null == it.next());
    }
    {
        const last = it.last().?;
        try std.testing.expectEqualSlices(u16, L("c"), last.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a/b/c"), last.path);

        const second_to_last = it.previous().?;
        try std.testing.expectEqualSlices(u16, L("b"), second_to_last.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a/b"), second_to_last.path);

        const third_to_last = it.previous().?;
        try std.testing.expectEqualSlices(u16, L("a"), third_to_last.name);
        try std.testing.expectEqualSlices(u16, L("C:\\a"), third_to_last.path);

        try std.testing.expect(null == it.previous());
    }
}

test "ComponentIterator roots" {
    // UEFI
    {
        var it = ComponentIterator(.uefi, u8).init("\\\\a");
        try std.testing.expectEqualStrings("\\", it.root().?);

        it = ComponentIterator(.uefi, u8).init("//a");
        try std.testing.expect(null == it.root());
    }
    // POSIX
    {
        var it = ComponentIterator(.posix, u8).init("//a");
        try std.testing.expectEqualStrings("/", it.root().?);

        it = ComponentIterator(.posix, u8).init("\\\\a");
        try std.testing.expect(null == it.root());
    }
    // Windows
    {
        // Drive relative
        var it = ComponentIterator(.windows, u8).init("C:a");
        try std.testing.expectEqualStrings("C:", it.root().?);

        // Drive absolute
        it = ComponentIterator(.windows, u8).init("C:/a");
        try std.testing.expectEqualStrings("C:/", it.root().?);
        it = ComponentIterator(.windows, u8).init("C:\\a");
        try std.testing.expectEqualStrings("C:\\", it.root().?);
        it = ComponentIterator(.windows, u8).init("C:///a");
        try std.testing.expectEqualStrings("C:/", it.root().?);

        // Rooted
        it = ComponentIterator(.windows, u8).init("\\a");
        try std.testing.expectEqualStrings("\\", it.root().?);
        it = ComponentIterator(.windows, u8).init("/a");
        try std.testing.expectEqualStrings("/", it.root().?);

        // Root local device
        it = ComponentIterator(.windows, u8).init("\\\\.");
        try std.testing.expectEqualStrings("\\\\.", it.root().?);
        it = ComponentIterator(.windows, u8).init("//?");
        try std.testing.expectEqualStrings("//?", it.root().?);

        // UNC absolute
        it = ComponentIterator(.windows, u8).init("//");
        try std.testing.expectEqualStrings("//", it.root().?);
        it = ComponentIterator(.windows, u8).init("\\\\a");
        try std.testing.expectEqualStrings("\\\\a", it.root().?);
        it = ComponentIterator(.windows, u8).init("\\\\a\\b\\\\c");
        try std.testing.expectEqualStrings("\\\\a\\b\\", it.root().?);
        it = ComponentIterator(.windows, u8).init("//a");
        try std.testing.expectEqualStrings("//a", it.root().?);
        it = ComponentIterator(.windows, u8).init("//a/b//c");
        try std.testing.expectEqualStrings("//a/b/", it.root().?);
        // Malformed UNC path with empty server name
        it = ComponentIterator(.windows, u8).init("\\\\\\a\\b\\c");
        try std.testing.expectEqualStrings("\\\\\\a\\", it.root().?);
    }
}

/// Format a path encoded as bytes for display as UTF-8.
/// Returns a Formatter for the given path. The path will be converted to valid UTF-8
/// during formatting. This is a lossy conversion if the path contains any ill-formed UTF-8.
/// Ill-formed UTF-8 byte sequences are replaced by the replacement character (U+FFFD)
/// according to "U+FFFD Substitution of Maximal Subparts" from Chapter 3 of
/// the Unicode standard, and as specified by https://encoding.spec.whatwg.org/#utf-8-decoder
pub const fmtAsUtf8Lossy = std.unicode.fmtUtf8;

/// Format a path encoded as WTF-16 LE for display as UTF-8.
/// Return a Formatter for a (potentially ill-formed) UTF-16 LE path.
/// The path will be converted to valid UTF-8 during formatting. This is
/// a lossy conversion if the path contains any unpaired surrogates.
/// Unpaired surrogates are replaced by the replacement character (U+FFFD).
pub const fmtWtf16LeAsUtf8Lossy = std.unicode.fmtUtf16Le;
