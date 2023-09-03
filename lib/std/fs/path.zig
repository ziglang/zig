const builtin = @import("builtin");
const std = @import("../std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;
const Allocator = mem.Allocator;
const math = std.math;
const windows = std.os.windows;
const os = std.os;
const fs = std.fs;
const process = std.process;
const native_os = builtin.target.os.tag;

pub const sep_windows = '\\';
pub const sep_posix = '/';
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

pub const delimiter_windows = ';';
pub const delimiter_posix = ':';
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
    pub inline fn isSep(comptime path_type: PathType, comptime T: type, c: T) bool {
        return switch (path_type) {
            .windows => c == '/' or c == '\\',
            .posix => c == '/',
            .uefi => c == '\\',
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

test "join" {
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
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\b\\", "c" }, "c:\\a\\b\\c", zero);

        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\", "a", "b\\", "c" }, "c:\\a\\b\\c", zero);
        try testJoinMaybeZWindows(&[_][]const u8{ "c:\\a\\", "b\\", "c" }, "c:\\a\\b\\c", zero);

        try testJoinMaybeZWindows(
            &[_][]const u8{ "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std", "io.zig" },
            "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std\\io.zig",
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
            &[_][]const u8{ "/home/andy/dev/zig/build/lib/zig/std", "io.zig" },
            "/home/andy/dev/zig/build/lib/zig/std/io.zig",
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
    if (path.len < 1)
        return false;

    if (path[0] == '/')
        return true;

    if (path[0] == '\\')
        return true;

    if (path.len < 3)
        return false;

    if (path[1] == ':') {
        if (path[2] == '/')
            return true;
        if (path[2] == '\\')
            return true;
    }

    return false;
}

pub fn isAbsoluteWindows(path: []const u8) bool {
    return isAbsoluteWindowsImpl(u8, path);
}

pub fn isAbsoluteWindowsW(path_w: [*:0]const u16) bool {
    return isAbsoluteWindowsImpl(u16, mem.sliceTo(path_w, 0));
}

pub fn isAbsoluteWindowsWTF16(path: []const u16) bool {
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

test "isAbsoluteWindows" {
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
    try testIsAbsoluteWindows("directory/directory", false);
    try testIsAbsoluteWindows("directory\\directory", false);
    try testIsAbsoluteWindows("/usr/local", true);
}

test "isAbsolutePosix" {
    try testIsAbsolutePosix("", false);
    try testIsAbsolutePosix("/home/foo", true);
    try testIsAbsolutePosix("/home/foo/..", true);
    try testIsAbsolutePosix("bar/", false);
    try testIsAbsolutePosix("./baz", false);
}

fn testIsAbsoluteWindows(path: []const u8, expected_result: bool) !void {
    try testing.expectEqual(expected_result, isAbsoluteWindows(path));
}

fn testIsAbsolutePosix(path: []const u8, expected_result: bool) !void {
    try testing.expectEqual(expected_result, isAbsolutePosix(path));
}

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
    if (path.len < "//a/b".len) {
        return relative_path;
    }

    inline for ("/\\") |this_sep| {
        const two_sep = [_]u8{ this_sep, this_sep };
        if (mem.startsWith(u8, path, &two_sep)) {
            if (path[2] == this_sep) {
                return relative_path;
            }

            var it = mem.tokenizeScalar(u8, path, this_sep);
            _ = (it.next() orelse return relative_path);
            _ = (it.next() orelse return relative_path);
            return WindowsPath{
                .is_abs = isAbsoluteWindows(path),
                .kind = WindowsPath.Kind.NetworkShare,
                .disk_designator = path[0..it.index],
            };
        }
    }
    return relative_path;
}

test "windowsParsePath" {
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
        const parsed = windowsParsePath("\\\\a\\");
        try testing.expect(!parsed.is_abs);
        try testing.expect(parsed.kind == WindowsPath.Kind.None);
        try testing.expect(mem.eql(u8, parsed.disk_designator, ""));
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

pub fn diskDesignator(path: []const u8) []const u8 {
    if (native_os == .windows) {
        return diskDesignatorWindows(path);
    } else {
        return "";
    }
}

pub fn diskDesignatorWindows(path: []const u8) []const u8 {
    return windowsParsePath(path).disk_designator;
}

fn networkShareServersEql(ns1: []const u8, ns2: []const u8) bool {
    const sep1 = ns1[0];
    const sep2 = ns2[0];

    var it1 = mem.tokenizeScalar(u8, ns1, sep1);
    var it2 = mem.tokenizeScalar(u8, ns2, sep2);

    return windows.eqlIgnoreCaseUtf8(it1.next().?, it2.next().?);
}

fn compareDiskDesignators(kind: WindowsPath.Kind, p1: []const u8, p2: []const u8) bool {
    switch (kind) {
        WindowsPath.Kind.None => {
            assert(p1.len == 0);
            assert(p2.len == 0);
            return true;
        },
        WindowsPath.Kind.Drive => {
            return ascii.toUpper(p1[0]) == ascii.toUpper(p2[0]);
        },
        WindowsPath.Kind.NetworkShare => {
            const sep1 = p1[0];
            const sep2 = p2[0];

            var it1 = mem.tokenizeScalar(u8, p1, sep1);
            var it2 = mem.tokenizeScalar(u8, p2, sep2);

            return windows.eqlIgnoreCaseUtf8(it1.next().?, it2.next().?) and windows.eqlIgnoreCaseUtf8(it1.next().?, it2.next().?);
        },
    }
}

/// On Windows, this calls `resolveWindows` and on POSIX it calls `resolvePosix`.
pub fn resolve(allocator: Allocator, paths: []const []const u8) ![]u8 {
    if (native_os == .windows) {
        return resolveWindows(allocator, paths);
    } else {
        return resolvePosix(allocator, paths);
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and "..", but will not convert relative path to absolute path, use std.fs.Dir.realpath instead.
/// The result does not have a trailing path separator.
/// Each drive has its own current working directory.
/// Path separators are canonicalized to '\\' and drives are canonicalized to capital letters.
/// Note: all usage of this function should be audited due to the existence of symlinks.
/// Without performing actual syscalls, resolving `..` could be incorrect.
/// This API may break in the future: https://github.com/ziglang/zig/issues/13613
pub fn resolveWindows(allocator: Allocator, paths: []const []const u8) ![]u8 {
    assert(paths.len > 0);

    // determine which disk designator we will result with, if any
    var result_drive_buf = "_:".*;
    var disk_designator: []const u8 = "";
    var drive_kind = WindowsPath.Kind.None;
    var have_abs_path = false;
    var first_index: usize = 0;
    for (paths, 0..) |p, i| {
        const parsed = windowsParsePath(p);
        if (parsed.is_abs) {
            have_abs_path = true;
            first_index = i;
        }
        switch (parsed.kind) {
            .Drive => {
                result_drive_buf[0] = ascii.toUpper(parsed.disk_designator[0]);
                disk_designator = result_drive_buf[0..];
                drive_kind = WindowsPath.Kind.Drive;
            },
            .NetworkShare => {
                disk_designator = parsed.disk_designator;
                drive_kind = WindowsPath.Kind.NetworkShare;
            },
            .None => {},
        }
    }

    // if we will result with a disk designator, loop again to determine
    // which is the last time the disk designator is absolutely specified, if any
    // and count up the max bytes for paths related to this disk designator
    if (drive_kind != WindowsPath.Kind.None) {
        have_abs_path = false;
        first_index = 0;
        var correct_disk_designator = false;

        for (paths, 0..) |p, i| {
            const parsed = windowsParsePath(p);
            if (parsed.kind != WindowsPath.Kind.None) {
                if (parsed.kind == drive_kind) {
                    correct_disk_designator = compareDiskDesignators(drive_kind, disk_designator, parsed.disk_designator);
                } else {
                    continue;
                }
            }
            if (!correct_disk_designator) {
                continue;
            }
            if (parsed.is_abs) {
                first_index = i;
                have_abs_path = true;
            }
        }
    }

    // Allocate result and fill in the disk designator.
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    const disk_designator_len: usize = l: {
        if (!have_abs_path) break :l 0;
        switch (drive_kind) {
            .Drive => {
                try result.appendSlice(disk_designator);
                break :l disk_designator.len;
            },
            .NetworkShare => {
                var it = mem.tokenizeAny(u8, paths[first_index], "/\\");
                const server_name = it.next().?;
                const other_name = it.next().?;

                try result.ensureUnusedCapacity(2 + 1 + server_name.len + other_name.len);
                result.appendSliceAssumeCapacity("\\\\");
                result.appendSliceAssumeCapacity(server_name);
                result.appendAssumeCapacity('\\');
                result.appendSliceAssumeCapacity(other_name);

                break :l result.items.len;
            },
            .None => {
                break :l 1;
            },
        }
    };

    var correct_disk_designator = true;
    var negative_count: usize = 0;

    for (paths[first_index..]) |p| {
        const parsed = windowsParsePath(p);

        if (parsed.kind != .None) {
            if (parsed.kind == drive_kind) {
                const dd = result.items[0..disk_designator_len];
                correct_disk_designator = compareDiskDesignators(drive_kind, dd, parsed.disk_designator);
            } else {
                continue;
            }
        }
        if (!correct_disk_designator) {
            continue;
        }
        var it = mem.tokenizeAny(u8, p[parsed.disk_designator.len..], "/\\");
        while (it.next()) |component| {
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                if (result.items.len == 0) {
                    negative_count += 1;
                    continue;
                }
                while (true) {
                    if (result.items.len == disk_designator_len) {
                        break;
                    }
                    const end_with_sep = switch (result.items[result.items.len - 1]) {
                        '\\', '/' => true,
                        else => false,
                    };
                    result.items.len -= 1;
                    if (end_with_sep or result.items.len == 0) break;
                }
            } else if (!have_abs_path and result.items.len == 0) {
                try result.appendSlice(component);
            } else {
                try result.ensureUnusedCapacity(1 + component.len);
                result.appendAssumeCapacity('\\');
                result.appendSliceAssumeCapacity(component);
            }
        }
    }

    if (disk_designator_len != 0 and result.items.len == disk_designator_len) {
        try result.append('\\');
        return result.toOwnedSlice();
    }

    if (result.items.len == 0) {
        if (negative_count == 0) {
            return allocator.dupe(u8, ".");
        } else {
            const real_result = try allocator.alloc(u8, 3 * negative_count - 1);
            var count = negative_count - 1;
            var i: usize = 0;
            while (count > 0) : (count -= 1) {
                real_result[i..][0..3].* = "..\\".*;
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
            real_result[i..][0..3].* = "..\\".*;
            i += 3;
        }
        @memcpy(real_result[i..][0..result.items.len], result.items);
        return real_result;
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and "..", but will not convert relative path to absolute path, use std.fs.Dir.realpath instead.
/// The result does not have a trailing path separator.
/// This function does not perform any syscalls. Executing this series of path
/// lookups on the actual filesystem may produce different results due to
/// symlinks.
pub fn resolvePosix(allocator: Allocator, paths: []const []const u8) Allocator.Error![]u8 {
    assert(paths.len > 0);

    var result = std.ArrayList(u8).init(allocator);
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

test "resolve" {
    try testResolveWindows(&[_][]const u8{ "a\\b\\c\\", "..\\..\\.." }, ".");
    try testResolveWindows(&[_][]const u8{"."}, ".");

    try testResolvePosix(&[_][]const u8{ "a/b/c/", "../../.." }, ".");
    try testResolvePosix(&[_][]const u8{"."}, ".");
}

test "resolveWindows" {
    try testResolveWindows(
        &[_][]const u8{ "Z:\\", "/usr/local", "lib\\zig\\std\\array_list.zig" },
        "Z:\\usr\\local\\lib\\zig\\std\\array_list.zig",
    );
    try testResolveWindows(
        &[_][]const u8{ "z:\\", "usr/local", "lib\\zig" },
        "Z:\\usr\\local\\lib\\zig",
    );

    try testResolveWindows(&[_][]const u8{ "c:\\a\\b\\c", "/hi", "ok" }, "C:\\hi\\ok");
    try testResolveWindows(&[_][]const u8{ "c:/blah\\blah", "d:/games", "c:../a" }, "C:\\blah\\a");
    try testResolveWindows(&[_][]const u8{ "c:/blah\\blah", "d:/games", "C:../a" }, "C:\\blah\\a");
    try testResolveWindows(&[_][]const u8{ "c:/ignore", "d:\\a/b\\c/d", "\\e.exe" }, "D:\\e.exe");
    try testResolveWindows(&[_][]const u8{ "c:/ignore", "c:/some/file" }, "C:\\some\\file");
    try testResolveWindows(&[_][]const u8{ "d:/ignore", "d:some/dir//" }, "D:\\ignore\\some\\dir");
    try testResolveWindows(&[_][]const u8{ "//server/share", "..", "relative\\" }, "\\\\server\\share\\relative");
    try testResolveWindows(&[_][]const u8{ "c:/", "//" }, "C:\\");
    try testResolveWindows(&[_][]const u8{ "c:/", "//dir" }, "C:\\dir");
    try testResolveWindows(&[_][]const u8{ "c:/", "//server/share" }, "\\\\server\\share\\");
    try testResolveWindows(&[_][]const u8{ "c:/", "//server//share" }, "\\\\server\\share\\");
    try testResolveWindows(&[_][]const u8{ "c:/", "///some//dir" }, "C:\\some\\dir");
    try testResolveWindows(&[_][]const u8{ "C:\\foo\\tmp.3\\", "..\\tmp.3\\cycles\\root.js" }, "C:\\foo\\tmp.3\\cycles\\root.js");

    // Keep relative paths relative.
    try testResolveWindows(&[_][]const u8{"a/b"}, "a\\b");
}

test "resolvePosix" {
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
    if (path.len == 0)
        return null;

    const root_slice = diskDesignatorWindows(path);
    if (path.len == root_slice.len)
        return null;

    const have_root_slash = path.len > root_slice.len and (path[root_slice.len] == '/' or path[root_slice.len] == '\\');

    var end_index: usize = path.len - 1;

    while (path[end_index] == '/' or path[end_index] == '\\') {
        if (end_index == 0)
            return null;
        end_index -= 1;
    }

    while (path[end_index] != '/' and path[end_index] != '\\') {
        if (end_index == 0)
            return null;
        end_index -= 1;
    }

    if (have_root_slash and end_index == root_slice.len) {
        end_index += 1;
    }

    if (end_index == 0)
        return null;

    return path[0..end_index];
}

pub fn dirnamePosix(path: []const u8) ?[]const u8 {
    if (path.len == 0)
        return null;

    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return null;
        end_index -= 1;
    }

    while (path[end_index] != '/') {
        if (end_index == 0)
            return null;
        end_index -= 1;
    }

    if (end_index == 0 and path[0] == '/')
        return path[0..1];

    if (end_index == 0)
        return null;

    return path[0..end_index];
}

test "dirnamePosix" {
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

test "dirnameWindows" {
    try testDirnameWindows("c:\\", null);
    try testDirnameWindows("c:\\foo", "c:\\");
    try testDirnameWindows("c:\\foo\\", "c:\\");
    try testDirnameWindows("c:\\foo\\bar", "c:\\foo");
    try testDirnameWindows("c:\\foo\\bar\\", "c:\\foo");
    try testDirnameWindows("c:\\foo\\bar\\baz", "c:\\foo\\bar");
    try testDirnameWindows("\\", null);
    try testDirnameWindows("\\foo", "\\");
    try testDirnameWindows("\\foo\\", "\\");
    try testDirnameWindows("\\foo\\bar", "\\foo");
    try testDirnameWindows("\\foo\\bar\\", "\\foo");
    try testDirnameWindows("\\foo\\bar\\baz", "\\foo\\bar");
    try testDirnameWindows("c:", null);
    try testDirnameWindows("c:foo", null);
    try testDirnameWindows("c:foo\\", null);
    try testDirnameWindows("c:foo\\bar", "c:foo");
    try testDirnameWindows("c:foo\\bar\\", "c:foo");
    try testDirnameWindows("c:foo\\bar\\baz", "c:foo\\bar");
    try testDirnameWindows("file:stream", null);
    try testDirnameWindows("dir\\file:stream", "dir");
    try testDirnameWindows("\\\\unc\\share", null);
    try testDirnameWindows("\\\\unc\\share\\foo", "\\\\unc\\share\\");
    try testDirnameWindows("\\\\unc\\share\\foo\\", "\\\\unc\\share\\");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar", "\\\\unc\\share\\foo");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar\\", "\\\\unc\\share\\foo");
    try testDirnameWindows("\\\\unc\\share\\foo\\bar\\baz", "\\\\unc\\share\\foo\\bar");
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
        try testing.expect(mem.eql(u8, output, expected_output.?));
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
    if (path.len == 0)
        return &[_]u8{};

    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return &[_]u8{};
        end_index -= 1;
    }
    var start_index: usize = end_index;
    end_index += 1;
    while (path[start_index] != '/') {
        if (start_index == 0)
            return path[0..end_index];
        start_index -= 1;
    }

    return path[start_index + 1 .. end_index];
}

pub fn basenameWindows(path: []const u8) []const u8 {
    if (path.len == 0)
        return &[_]u8{};

    var end_index: usize = path.len - 1;
    while (true) {
        const byte = path[end_index];
        if (byte == '/' or byte == '\\') {
            if (end_index == 0)
                return &[_]u8{};
            end_index -= 1;
            continue;
        }
        if (byte == ':' and end_index == 1) {
            return &[_]u8{};
        }
        break;
    }

    var start_index: usize = end_index;
    end_index += 1;
    while (path[start_index] != '/' and path[start_index] != '\\' and
        !(path[start_index] == ':' and start_index == 1))
    {
        if (start_index == 0)
            return path[0..end_index];
        start_index -= 1;
    }

    return path[start_index + 1 .. end_index];
}

test "basename" {
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
    try testBasename("//a", "a");

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

/// Returns the relative path from `from` to `to`. If `from` and `to` each
/// resolve to the same path (after calling `resolve` on each), a zero-length
/// string is returned.
/// On Windows this canonicalizes the drive to a capital letter and paths to `\\`.
pub fn relative(allocator: Allocator, from: []const u8, to: []const u8) ![]u8 {
    if (native_os == .windows) {
        return relativeWindows(allocator, from, to);
    } else {
        return relativePosix(allocator, from, to);
    }
}

pub fn relativeWindows(allocator: Allocator, from: []const u8, to: []const u8) ![]u8 {
    const cwd = try process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    const resolved_from = try resolveWindows(allocator, &[_][]const u8{ cwd, from });
    defer allocator.free(resolved_from);

    var clean_up_resolved_to = true;
    const resolved_to = try resolveWindows(allocator, &[_][]const u8{ cwd, to });
    defer if (clean_up_resolved_to) allocator.free(resolved_to);

    const parsed_from = windowsParsePath(resolved_from);
    const parsed_to = windowsParsePath(resolved_to);
    const result_is_to = x: {
        if (parsed_from.kind != parsed_to.kind) {
            break :x true;
        } else switch (parsed_from.kind) {
            .NetworkShare => {
                break :x !networkShareServersEql(parsed_to.disk_designator, parsed_from.disk_designator);
            },
            .Drive => {
                break :x ascii.toUpper(parsed_from.disk_designator[0]) != ascii.toUpper(parsed_to.disk_designator[0]);
            },
            .None => {
                break :x false;
            },
        }
    };

    if (result_is_to) {
        clean_up_resolved_to = false;
        return resolved_to;
    }

    var from_it = mem.tokenizeAny(u8, resolved_from, "/\\");
    var to_it = mem.tokenizeAny(u8, resolved_to, "/\\");
    while (true) {
        const from_component = from_it.next() orelse return allocator.dupe(u8, to_it.rest());
        const to_rest = to_it.rest();
        if (to_it.next()) |to_component| {
            if (windows.eqlIgnoreCaseUtf8(from_component, to_component))
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

pub fn relativePosix(allocator: Allocator, from: []const u8, to: []const u8) ![]u8 {
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

test "relative" {
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
    try testRelativeWindows("\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz-quux", "..\\baz-quux");
    try testRelativeWindows("C:\\baz-quux", "C:\\baz", "..\\baz");
    try testRelativeWindows("C:\\baz", "C:\\baz-quux", "..\\baz-quux");
    try testRelativeWindows("\\\\foo\\baz-quux", "\\\\foo\\baz", "..\\baz");
    try testRelativeWindows("\\\\foo\\baz", "\\\\foo\\baz-quux", "..\\baz-quux");
    try testRelativeWindows("C:\\baz", "\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz");
    try testRelativeWindows("\\\\foo\\bar\\baz", "C:\\baz", "C:\\baz");

    try testRelativeWindows("a/b/c", "a\\b", "..");
    try testRelativeWindows("a/b/c", "a", "..\\..");
    try testRelativeWindows("a/b/c", "a\\b\\c\\d", "d");

    try testRelativeWindows("\\\\FOO\\bar\\baz", "\\\\foo\\BAR\\BAZ", "");
    // Unicode-aware case-insensitive path comparison
    try testRelativeWindows("\\\\кириллица\\ελληνικά\\português", "\\\\КИРИЛЛИЦА\\ΕΛΛΗΝΙΚΆ\\PORTUGUÊS", "");

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

test "extension" {
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

test "stem" {
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
        root_end_index: usize = 0,
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

        const InitError = switch (path_type) {
            .windows => error{BadPathName},
            else => error{},
        };

        /// After `init`, `next` will return the first component after the root
        /// (there is no need to call `first` after `init`).
        /// To iterate backwards (from the end of the path to the beginning), call `last`
        /// after `init` and then iterate via `previous` calls.
        /// For Windows paths, `error.BadPathName` is returned if the `path` has an explicit
        /// namespace prefix (`\\.\`, `\\?\`, or `\??\`) or if it is a UNC path with more
        /// than two path separators at the beginning.
        pub fn init(path: []const T) InitError!Self {
            const root_end_index: usize = switch (path_type) {
                .posix, .uefi => posix: {
                    // Root on UEFI and POSIX only differs by the path separator
                    var root_end_index: usize = 0;
                    while (true) : (root_end_index += 1) {
                        if (root_end_index >= path.len or !path_type.isSep(T, path[root_end_index])) {
                            break;
                        }
                    }
                    break :posix root_end_index;
                },
                .windows => windows: {
                    // Namespaces other than the Win32 file namespace are tricky
                    // and basically impossible to determine a 'root' for, since it's
                    // possible to construct an effectively arbitrarily long 'root',
                    // e.g. `\\.\GLOBALROOT\??\UNC\localhost\C$\foo` is a
                    // possible path that would be effectively equivalent to
                    // `C:\foo`, and the `GLOBALROOT\??\` part can also be recursive,
                    // so `GLOBALROOT\??\GLOBALROOT\??\...` would work for any number
                    // of repetitions. Therefore, paths with an explicit namespace prefix
                    // (\\.\, \??\, \\?\) are not allowed here.
                    if (std.os.windows.getNamespacePrefix(T, path) != .none) {
                        return error.BadPathName;
                    }
                    const windows_path_type = std.os.windows.getUnprefixedPathType(T, path);
                    break :windows switch (windows_path_type) {
                        .relative => 0,
                        .root_local_device => path.len,
                        .rooted => 1,
                        .unc_absolute => unc: {
                            var end_index: usize = 2;
                            // Any extra separators between the first two and the server name are not allowed
                            // and will always lead to STATUS_OBJECT_PATH_INVALID if it is attempted
                            // to be used.
                            if (end_index < path.len and path_type.isSep(T, path[end_index])) {
                                return error.BadPathName;
                            }
                            // Server
                            while (end_index < path.len and !path_type.isSep(T, path[end_index])) {
                                end_index += 1;
                            }
                            // Slash(es) after server
                            while (end_index < path.len and path_type.isSep(T, path[end_index])) {
                                end_index += 1;
                            }
                            // Share
                            while (end_index < path.len and !path_type.isSep(T, path[end_index])) {
                                end_index += 1;
                            }
                            // Slash(es) after share
                            while (end_index < path.len and path_type.isSep(T, path[end_index])) {
                                end_index += 1;
                            }
                            break :unc end_index;
                        },
                        .drive_absolute => drive: {
                            var end_index: usize = 3;
                            while (end_index < path.len and path_type.isSep(T, path[end_index])) {
                                end_index += 1;
                            }
                            break :drive end_index;
                        },
                        .drive_relative => 2,
                    };
                },
            };
            return .{
                .path = path,
                .root_end_index = root_end_index,
                .start_index = root_end_index,
                .end_index = root_end_index,
            };
        }

        /// Returns the root of the path if it is an absolute path, or null otherwise.
        /// For POSIX paths, this will be `/`.
        /// For Windows paths, this will be something like `C:\`, `\\server\share\`, etc.
        /// For UEFI paths, this will be `\`.
        pub fn root(self: Self) ?[]const T {
            if (self.root_end_index == 0) return null;
            return self.path[0..self.root_end_index];
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
            var start_index = self.end_index;
            while (start_index < self.path.len and path_type.isSep(T, self.path[start_index])) {
                start_index += 1;
            }
            var end_index = start_index;
            while (end_index < self.path.len and !path_type.isSep(T, self.path[end_index])) {
                end_index += 1;
            }
            if (start_index == end_index) return null;
            self.start_index = start_index;
            self.end_index = end_index;
            return .{
                .name = self.path[self.start_index..self.end_index],
                .path = self.path[0..self.end_index],
            };
        }

        /// Returns the previous component (the component to the left of the most recently
        /// returned component), or null if no such component exists.
        /// For example, if the path is `/a/b/c` and the most recently returned component
        /// is `b`, then this will return the `a` component.
        pub fn previous(self: *Self) ?Component {
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
            self.start_index = start_index;
            self.end_index = end_index;
            return .{
                .name = self.path[self.start_index..self.end_index],
                .path = self.path[0..self.end_index],
            };
        }
    };
}

pub const NativeUtf8ComponentIterator = ComponentIterator(switch (native_os) {
    .windows => .windows,
    .uefi => .uefi,
    else => .posix,
}, u8);

pub fn componentIterator(path: []const u8) !NativeUtf8ComponentIterator {
    return NativeUtf8ComponentIterator.init(path);
}

test "ComponentIterator posix" {
    const PosixComponentIterator = ComponentIterator(.posix, u8);
    {
        const path = "a/b/c/";
        var it = try PosixComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 0), it.root_end_index);
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
        var it = try PosixComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 1), it.root_end_index);
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
        const path = "/";
        var it = try PosixComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 1), it.root_end_index);
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
        var it = try PosixComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 0), it.root_end_index);
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
        var it = try WindowsComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 0), it.root_end_index);
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
        var it = try WindowsComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 3), it.root_end_index);
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
        const path = "/";
        var it = try WindowsComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 1), it.root_end_index);
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
        var it = try WindowsComponentIterator.init(path);
        try std.testing.expectEqual(@as(usize, 0), it.root_end_index);
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

test "ComponentIterator windows UTF-16" {
    // TODO: Fix on big endian architectures
    if (builtin.cpu.arch.endian() != .Little) {
        return error.SkipZigTest;
    }

    const WindowsComponentIterator = ComponentIterator(.windows, u16);
    const L = std.unicode.utf8ToUtf16LeStringLiteral;

    const path = L("C:\\a/b/c/");
    var it = try WindowsComponentIterator.init(path);
    try std.testing.expectEqual(@as(usize, 3), it.root_end_index);
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
        var it = try ComponentIterator(.uefi, u8).init("\\\\a");
        try std.testing.expectEqualStrings("\\\\", it.root().?);

        it = try ComponentIterator(.uefi, u8).init("//a");
        try std.testing.expect(null == it.root());
    }
    // POSIX
    {
        var it = try ComponentIterator(.posix, u8).init("//a");
        try std.testing.expectEqualStrings("//", it.root().?);

        it = try ComponentIterator(.posix, u8).init("\\\\a");
        try std.testing.expect(null == it.root());
    }
    // Windows
    {
        // Drive relative
        var it = try ComponentIterator(.windows, u8).init("C:a");
        try std.testing.expectEqualStrings("C:", it.root().?);

        // Drive absolute
        it = try ComponentIterator(.windows, u8).init("C://a");
        try std.testing.expectEqualStrings("C://", it.root().?);
        it = try ComponentIterator(.windows, u8).init("C:\\a");
        try std.testing.expectEqualStrings("C:\\", it.root().?);

        // Rooted
        it = try ComponentIterator(.windows, u8).init("\\a");
        try std.testing.expectEqualStrings("\\", it.root().?);
        it = try ComponentIterator(.windows, u8).init("/a");
        try std.testing.expectEqualStrings("/", it.root().?);

        // Root local device
        it = try ComponentIterator(.windows, u8).init("\\\\.");
        try std.testing.expectEqualStrings("\\\\.", it.root().?);
        it = try ComponentIterator(.windows, u8).init("//?");
        try std.testing.expectEqualStrings("//?", it.root().?);

        // UNC absolute
        it = try ComponentIterator(.windows, u8).init("//");
        try std.testing.expectEqualStrings("//", it.root().?);
        it = try ComponentIterator(.windows, u8).init("\\\\a");
        try std.testing.expectEqualStrings("\\\\a", it.root().?);
        it = try ComponentIterator(.windows, u8).init("\\\\a\\b\\\\c");
        try std.testing.expectEqualStrings("\\\\a\\b\\\\", it.root().?);
        it = try ComponentIterator(.windows, u8).init("//a");
        try std.testing.expectEqualStrings("//a", it.root().?);
        it = try ComponentIterator(.windows, u8).init("//a/b//c");
        try std.testing.expectEqualStrings("//a/b//", it.root().?);
    }
}
