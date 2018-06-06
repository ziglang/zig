const std = @import("../index.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const os = std.os;
const math = std.math;
const posix = os.posix;
const windows = os.windows;
const cstr = std.cstr;

pub const sep_windows = '\\';
pub const sep_posix = '/';
pub const sep = if (is_windows) sep_windows else sep_posix;

pub const delimiter_windows = ';';
pub const delimiter_posix = ':';
pub const delimiter = if (is_windows) delimiter_windows else delimiter_posix;

const is_windows = builtin.os == builtin.Os.windows;

pub fn isSep(byte: u8) bool {
    if (is_windows) {
        return byte == '/' or byte == '\\';
    } else {
        return byte == '/';
    }
}

/// Naively combines a series of paths with the native path seperator.
/// Allocates memory for the result, which must be freed by the caller.
pub fn join(allocator: *Allocator, paths: ...) ![]u8 {
    if (is_windows) {
        return joinWindows(allocator, paths);
    } else {
        return joinPosix(allocator, paths);
    }
}

pub fn joinWindows(allocator: *Allocator, paths: ...) ![]u8 {
    return mem.join(allocator, sep_windows, paths);
}

pub fn joinPosix(allocator: *Allocator, paths: ...) ![]u8 {
    return mem.join(allocator, sep_posix, paths);
}

test "os.path.join" {
    assert(mem.eql(u8, try joinWindows(debug.global_allocator, "c:\\a\\b", "c"), "c:\\a\\b\\c"));
    assert(mem.eql(u8, try joinWindows(debug.global_allocator, "c:\\a\\b\\", "c"), "c:\\a\\b\\c"));

    assert(mem.eql(u8, try joinWindows(debug.global_allocator, "c:\\", "a", "b\\", "c"), "c:\\a\\b\\c"));
    assert(mem.eql(u8, try joinWindows(debug.global_allocator, "c:\\a\\", "b\\", "c"), "c:\\a\\b\\c"));

    assert(mem.eql(u8, try joinWindows(debug.global_allocator, "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std", "io.zig"), "c:\\home\\andy\\dev\\zig\\build\\lib\\zig\\std\\io.zig"));

    assert(mem.eql(u8, try joinPosix(debug.global_allocator, "/a/b", "c"), "/a/b/c"));
    assert(mem.eql(u8, try joinPosix(debug.global_allocator, "/a/b/", "c"), "/a/b/c"));

    assert(mem.eql(u8, try joinPosix(debug.global_allocator, "/", "a", "b/", "c"), "/a/b/c"));
    assert(mem.eql(u8, try joinPosix(debug.global_allocator, "/a/", "b/", "c"), "/a/b/c"));

    assert(mem.eql(u8, try joinPosix(debug.global_allocator, "/home/andy/dev/zig/build/lib/zig/std", "io.zig"), "/home/andy/dev/zig/build/lib/zig/std/io.zig"));
}

pub fn isAbsolute(path: []const u8) bool {
    if (is_windows) {
        return isAbsoluteWindows(path);
    } else {
        return isAbsolutePosix(path);
    }
}

pub fn isAbsoluteWindows(path: []const u8) bool {
    if (path[0] == '/')
        return true;

    if (path[0] == '\\') {
        return true;
    }
    if (path.len < 3) {
        return false;
    }
    if (path[1] == ':') {
        if (path[2] == '/')
            return true;
        if (path[2] == '\\')
            return true;
    }
    return false;
}

pub fn isAbsolutePosix(path: []const u8) bool {
    return path[0] == sep_posix;
}

test "os.path.isAbsoluteWindows" {
    testIsAbsoluteWindows("/", true);
    testIsAbsoluteWindows("//", true);
    testIsAbsoluteWindows("//server", true);
    testIsAbsoluteWindows("//server/file", true);
    testIsAbsoluteWindows("\\\\server\\file", true);
    testIsAbsoluteWindows("\\\\server", true);
    testIsAbsoluteWindows("\\\\", true);
    testIsAbsoluteWindows("c", false);
    testIsAbsoluteWindows("c:", false);
    testIsAbsoluteWindows("c:\\", true);
    testIsAbsoluteWindows("c:/", true);
    testIsAbsoluteWindows("c://", true);
    testIsAbsoluteWindows("C:/Users/", true);
    testIsAbsoluteWindows("C:\\Users\\", true);
    testIsAbsoluteWindows("C:cwd/another", false);
    testIsAbsoluteWindows("C:cwd\\another", false);
    testIsAbsoluteWindows("directory/directory", false);
    testIsAbsoluteWindows("directory\\directory", false);
    testIsAbsoluteWindows("/usr/local", true);
}

test "os.path.isAbsolutePosix" {
    testIsAbsolutePosix("/home/foo", true);
    testIsAbsolutePosix("/home/foo/..", true);
    testIsAbsolutePosix("bar/", false);
    testIsAbsolutePosix("./baz", false);
}

fn testIsAbsoluteWindows(path: []const u8, expected_result: bool) void {
    assert(isAbsoluteWindows(path) == expected_result);
}

fn testIsAbsolutePosix(path: []const u8, expected_result: bool) void {
    assert(isAbsolutePosix(path) == expected_result);
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
        .disk_designator = []u8{},
        .is_abs = false,
    };
    if (path.len < "//a/b".len) {
        return relative_path;
    }

    // TODO when I combined these together with `inline for` the compiler crashed
    {
        const this_sep = '/';
        const two_sep = []u8{ this_sep, this_sep };
        if (mem.startsWith(u8, path, two_sep)) {
            if (path[2] == this_sep) {
                return relative_path;
            }

            var it = mem.split(path, []u8{this_sep});
            _ = (it.next() ?? return relative_path);
            _ = (it.next() ?? return relative_path);
            return WindowsPath{
                .is_abs = isAbsoluteWindows(path),
                .kind = WindowsPath.Kind.NetworkShare,
                .disk_designator = path[0..it.index],
            };
        }
    }
    {
        const this_sep = '\\';
        const two_sep = []u8{ this_sep, this_sep };
        if (mem.startsWith(u8, path, two_sep)) {
            if (path[2] == this_sep) {
                return relative_path;
            }

            var it = mem.split(path, []u8{this_sep});
            _ = (it.next() ?? return relative_path);
            _ = (it.next() ?? return relative_path);
            return WindowsPath{
                .is_abs = isAbsoluteWindows(path),
                .kind = WindowsPath.Kind.NetworkShare,
                .disk_designator = path[0..it.index],
            };
        }
    }
    return relative_path;
}

test "os.path.windowsParsePath" {
    {
        const parsed = windowsParsePath("//a/b");
        assert(parsed.is_abs);
        assert(parsed.kind == WindowsPath.Kind.NetworkShare);
        assert(mem.eql(u8, parsed.disk_designator, "//a/b"));
    }
    {
        const parsed = windowsParsePath("\\\\a\\b");
        assert(parsed.is_abs);
        assert(parsed.kind == WindowsPath.Kind.NetworkShare);
        assert(mem.eql(u8, parsed.disk_designator, "\\\\a\\b"));
    }
    {
        const parsed = windowsParsePath("\\\\a\\");
        assert(!parsed.is_abs);
        assert(parsed.kind == WindowsPath.Kind.None);
        assert(mem.eql(u8, parsed.disk_designator, ""));
    }
    {
        const parsed = windowsParsePath("/usr/local");
        assert(parsed.is_abs);
        assert(parsed.kind == WindowsPath.Kind.None);
        assert(mem.eql(u8, parsed.disk_designator, ""));
    }
    {
        const parsed = windowsParsePath("c:../");
        assert(!parsed.is_abs);
        assert(parsed.kind == WindowsPath.Kind.Drive);
        assert(mem.eql(u8, parsed.disk_designator, "c:"));
    }
}

pub fn diskDesignator(path: []const u8) []const u8 {
    if (is_windows) {
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

    var it1 = mem.split(ns1, []u8{sep1});
    var it2 = mem.split(ns2, []u8{sep2});

    // TODO ASCII is wrong, we actually need full unicode support to compare paths.
    return asciiEqlIgnoreCase(??it1.next(), ??it2.next());
}

fn compareDiskDesignators(kind: WindowsPath.Kind, p1: []const u8, p2: []const u8) bool {
    switch (kind) {
        WindowsPath.Kind.None => {
            assert(p1.len == 0);
            assert(p2.len == 0);
            return true;
        },
        WindowsPath.Kind.Drive => {
            return asciiUpper(p1[0]) == asciiUpper(p2[0]);
        },
        WindowsPath.Kind.NetworkShare => {
            const sep1 = p1[0];
            const sep2 = p2[0];

            var it1 = mem.split(p1, []u8{sep1});
            var it2 = mem.split(p2, []u8{sep2});

            // TODO ASCII is wrong, we actually need full unicode support to compare paths.
            return asciiEqlIgnoreCase(??it1.next(), ??it2.next()) and asciiEqlIgnoreCase(??it1.next(), ??it2.next());
        },
    }
}

fn asciiUpper(byte: u8) u8 {
    return switch (byte) {
        'a'...'z' => 'A' + (byte - 'a'),
        else => byte,
    };
}

fn asciiEqlIgnoreCase(s1: []const u8, s2: []const u8) bool {
    if (s1.len != s2.len)
        return false;
    var i: usize = 0;
    while (i < s1.len) : (i += 1) {
        if (asciiUpper(s1[i]) != asciiUpper(s2[i]))
            return false;
    }
    return true;
}

/// Converts the command line arguments into a slice and calls `resolveSlice`.
pub fn resolve(allocator: *Allocator, args: ...) ![]u8 {
    var paths: [args.len][]const u8 = undefined;
    comptime var arg_i = 0;
    inline while (arg_i < args.len) : (arg_i += 1) {
        paths[arg_i] = args[arg_i];
    }
    return resolveSlice(allocator, paths);
}

/// On Windows, this calls `resolveWindows` and on POSIX it calls `resolvePosix`.
pub fn resolveSlice(allocator: *Allocator, paths: []const []const u8) ![]u8 {
    if (is_windows) {
        return resolveWindows(allocator, paths);
    } else {
        return resolvePosix(allocator, paths);
    }
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and "..".
/// The result does not have a trailing path separator.
/// If all paths are relative it uses the current working directory as a starting point.
/// Each drive has its own current working directory.
/// Path separators are canonicalized to '\\' and drives are canonicalized to capital letters.
pub fn resolveWindows(allocator: *Allocator, paths: []const []const u8) ![]u8 {
    if (paths.len == 0) {
        assert(is_windows); // resolveWindows called on non windows can't use getCwd
        return os.getCwd(allocator);
    }

    // determine which disk designator we will result with, if any
    var result_drive_buf = "_:";
    var result_disk_designator: []const u8 = "";
    var have_drive_kind = WindowsPath.Kind.None;
    var have_abs_path = false;
    var first_index: usize = 0;
    var max_size: usize = 0;
    for (paths) |p, i| {
        const parsed = windowsParsePath(p);
        if (parsed.is_abs) {
            have_abs_path = true;
            first_index = i;
            max_size = result_disk_designator.len;
        }
        switch (parsed.kind) {
            WindowsPath.Kind.Drive => {
                result_drive_buf[0] = asciiUpper(parsed.disk_designator[0]);
                result_disk_designator = result_drive_buf[0..];
                have_drive_kind = WindowsPath.Kind.Drive;
            },
            WindowsPath.Kind.NetworkShare => {
                result_disk_designator = parsed.disk_designator;
                have_drive_kind = WindowsPath.Kind.NetworkShare;
            },
            WindowsPath.Kind.None => {},
        }
        max_size += p.len + 1;
    }

    // if we will result with a disk designator, loop again to determine
    // which is the last time the disk designator is absolutely specified, if any
    // and count up the max bytes for paths related to this disk designator
    if (have_drive_kind != WindowsPath.Kind.None) {
        have_abs_path = false;
        first_index = 0;
        max_size = result_disk_designator.len;
        var correct_disk_designator = false;

        for (paths) |p, i| {
            const parsed = windowsParsePath(p);
            if (parsed.kind != WindowsPath.Kind.None) {
                if (parsed.kind == have_drive_kind) {
                    correct_disk_designator = compareDiskDesignators(have_drive_kind, result_disk_designator, parsed.disk_designator);
                } else {
                    continue;
                }
            }
            if (!correct_disk_designator) {
                continue;
            }
            if (parsed.is_abs) {
                first_index = i;
                max_size = result_disk_designator.len;
                have_abs_path = true;
            }
            max_size += p.len + 1;
        }
    }

    // Allocate result and fill in the disk designator, calling getCwd if we have to.
    var result: []u8 = undefined;
    var result_index: usize = 0;

    if (have_abs_path) {
        switch (have_drive_kind) {
            WindowsPath.Kind.Drive => {
                result = try allocator.alloc(u8, max_size);

                mem.copy(u8, result, result_disk_designator);
                result_index += result_disk_designator.len;
            },
            WindowsPath.Kind.NetworkShare => {
                result = try allocator.alloc(u8, max_size);
                var it = mem.split(paths[first_index], "/\\");
                const server_name = ??it.next();
                const other_name = ??it.next();

                result[result_index] = '\\';
                result_index += 1;
                result[result_index] = '\\';
                result_index += 1;
                mem.copy(u8, result[result_index..], server_name);
                result_index += server_name.len;
                result[result_index] = '\\';
                result_index += 1;
                mem.copy(u8, result[result_index..], other_name);
                result_index += other_name.len;

                result_disk_designator = result[0..result_index];
            },
            WindowsPath.Kind.None => {
                assert(is_windows); // resolveWindows called on non windows can't use getCwd
                const cwd = try os.getCwd(allocator);
                defer allocator.free(cwd);
                const parsed_cwd = windowsParsePath(cwd);
                result = try allocator.alloc(u8, max_size + parsed_cwd.disk_designator.len + 1);
                mem.copy(u8, result, parsed_cwd.disk_designator);
                result_index += parsed_cwd.disk_designator.len;
                result_disk_designator = result[0..parsed_cwd.disk_designator.len];
                if (parsed_cwd.kind == WindowsPath.Kind.Drive) {
                    result[0] = asciiUpper(result[0]);
                }
                have_drive_kind = parsed_cwd.kind;
            },
        }
    } else {
        assert(is_windows); // resolveWindows called on non windows can't use getCwd
        // TODO call get cwd for the result_disk_designator instead of the global one
        const cwd = try os.getCwd(allocator);
        defer allocator.free(cwd);

        result = try allocator.alloc(u8, max_size + cwd.len + 1);

        mem.copy(u8, result, cwd);
        result_index += cwd.len;
        const parsed_cwd = windowsParsePath(result[0..result_index]);
        result_disk_designator = parsed_cwd.disk_designator;
        if (parsed_cwd.kind == WindowsPath.Kind.Drive) {
            result[0] = asciiUpper(result[0]);
        }
        have_drive_kind = parsed_cwd.kind;
    }
    errdefer allocator.free(result);

    // Now we know the disk designator to use, if any, and what kind it is. And our result
    // is big enough to append all the paths to.
    var correct_disk_designator = true;
    for (paths[first_index..]) |p, i| {
        const parsed = windowsParsePath(p);

        if (parsed.kind != WindowsPath.Kind.None) {
            if (parsed.kind == have_drive_kind) {
                correct_disk_designator = compareDiskDesignators(have_drive_kind, result_disk_designator, parsed.disk_designator);
            } else {
                continue;
            }
        }
        if (!correct_disk_designator) {
            continue;
        }
        var it = mem.split(p[parsed.disk_designator.len..], "/\\");
        while (it.next()) |component| {
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                while (true) {
                    if (result_index == 0 or result_index == result_disk_designator.len)
                        break;
                    result_index -= 1;
                    if (result[result_index] == '\\' or result[result_index] == '/')
                        break;
                }
            } else {
                result[result_index] = sep_windows;
                result_index += 1;
                mem.copy(u8, result[result_index..], component);
                result_index += component.len;
            }
        }
    }

    if (result_index == result_disk_designator.len) {
        result[result_index] = '\\';
        result_index += 1;
    }

    return result[0..result_index];
}

/// This function is like a series of `cd` statements executed one after another.
/// It resolves "." and "..".
/// The result does not have a trailing path separator.
/// If all paths are relative it uses the current working directory as a starting point.
pub fn resolvePosix(allocator: *Allocator, paths: []const []const u8) ![]u8 {
    if (paths.len == 0) {
        assert(!is_windows); // resolvePosix called on windows can't use getCwd
        return os.getCwd(allocator);
    }

    var first_index: usize = 0;
    var have_abs = false;
    var max_size: usize = 0;
    for (paths) |p, i| {
        if (isAbsolutePosix(p)) {
            first_index = i;
            have_abs = true;
            max_size = 0;
        }
        max_size += p.len + 1;
    }

    var result: []u8 = undefined;
    var result_index: usize = 0;

    if (have_abs) {
        result = try allocator.alloc(u8, max_size);
    } else {
        assert(!is_windows); // resolvePosix called on windows can't use getCwd
        const cwd = try os.getCwd(allocator);
        defer allocator.free(cwd);
        result = try allocator.alloc(u8, max_size + cwd.len + 1);
        mem.copy(u8, result, cwd);
        result_index += cwd.len;
    }
    errdefer allocator.free(result);

    for (paths[first_index..]) |p, i| {
        var it = mem.split(p, "/");
        while (it.next()) |component| {
            if (mem.eql(u8, component, ".")) {
                continue;
            } else if (mem.eql(u8, component, "..")) {
                while (true) {
                    if (result_index == 0)
                        break;
                    result_index -= 1;
                    if (result[result_index] == '/')
                        break;
                }
            } else {
                result[result_index] = '/';
                result_index += 1;
                mem.copy(u8, result[result_index..], component);
                result_index += component.len;
            }
        }
    }

    if (result_index == 0) {
        result[0] = '/';
        result_index += 1;
    }

    return result[0..result_index];
}

test "os.path.resolve" {
    const cwd = try os.getCwd(debug.global_allocator);
    if (is_windows) {
        if (windowsParsePath(cwd).kind == WindowsPath.Kind.Drive) {
            cwd[0] = asciiUpper(cwd[0]);
        }
        assert(mem.eql(u8, testResolveWindows([][]const u8{"."}), cwd));
    } else {
        assert(mem.eql(u8, testResolvePosix([][]const u8{ "a/b/c/", "../../.." }), cwd));
        assert(mem.eql(u8, testResolvePosix([][]const u8{"."}), cwd));
    }
}

test "os.path.resolveWindows" {
    if (is_windows) {
        const cwd = try os.getCwd(debug.global_allocator);
        const parsed_cwd = windowsParsePath(cwd);
        {
            const result = testResolveWindows([][]const u8{ "/usr/local", "lib\\zig\\std\\array_list.zig" });
            const expected = try join(debug.global_allocator, parsed_cwd.disk_designator, "usr\\local\\lib\\zig\\std\\array_list.zig");
            if (parsed_cwd.kind == WindowsPath.Kind.Drive) {
                expected[0] = asciiUpper(parsed_cwd.disk_designator[0]);
            }
            assert(mem.eql(u8, result, expected));
        }
        {
            const result = testResolveWindows([][]const u8{ "usr/local", "lib\\zig" });
            const expected = try join(debug.global_allocator, cwd, "usr\\local\\lib\\zig");
            if (parsed_cwd.kind == WindowsPath.Kind.Drive) {
                expected[0] = asciiUpper(parsed_cwd.disk_designator[0]);
            }
            assert(mem.eql(u8, result, expected));
        }
    }

    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:\\a\\b\\c", "/hi", "ok" }), "C:\\hi\\ok"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/blah\\blah", "d:/games", "c:../a" }), "C:\\blah\\a"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/blah\\blah", "d:/games", "C:../a" }), "C:\\blah\\a"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/ignore", "d:\\a/b\\c/d", "\\e.exe" }), "D:\\e.exe"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/ignore", "c:/some/file" }), "C:\\some\\file"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "d:/ignore", "d:some/dir//" }), "D:\\ignore\\some\\dir"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "//server/share", "..", "relative\\" }), "\\\\server\\share\\relative"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/", "//" }), "C:\\"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/", "//dir" }), "C:\\dir"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/", "//server/share" }), "\\\\server\\share\\"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/", "//server//share" }), "\\\\server\\share\\"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "c:/", "///some//dir" }), "C:\\some\\dir"));
    assert(mem.eql(u8, testResolveWindows([][]const u8{ "C:\\foo\\tmp.3\\", "..\\tmp.3\\cycles\\root.js" }), "C:\\foo\\tmp.3\\cycles\\root.js"));
}

test "os.path.resolvePosix" {
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/a/b", "c" }), "/a/b/c"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/a/b", "c", "//d", "e///" }), "/d/e"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/a/b/c", "..", "../" }), "/a"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/", "..", ".." }), "/"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{"/a/b/c/"}), "/a/b/c"));

    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/var/lib", "../", "file/" }), "/var/file"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/var/lib", "/../", "file/" }), "/file"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/some/dir", ".", "/absolute/" }), "/absolute"));
    assert(mem.eql(u8, testResolvePosix([][]const u8{ "/foo/tmp.3/", "../tmp.3/cycles/root.js" }), "/foo/tmp.3/cycles/root.js"));
}

fn testResolveWindows(paths: []const []const u8) []u8 {
    return resolveWindows(debug.global_allocator, paths) catch unreachable;
}

fn testResolvePosix(paths: []const []const u8) []u8 {
    return resolvePosix(debug.global_allocator, paths) catch unreachable;
}

/// If the path is a file in the current directory (no directory component)
/// then the returned slice has .len = 0.
pub fn dirname(path: []const u8) []const u8 {
    if (is_windows) {
        return dirnameWindows(path);
    } else {
        return dirnamePosix(path);
    }
}

pub fn dirnameWindows(path: []const u8) []const u8 {
    if (path.len == 0)
        return path[0..0];

    const root_slice = diskDesignatorWindows(path);
    if (path.len == root_slice.len)
        return path;

    const have_root_slash = path.len > root_slice.len and (path[root_slice.len] == '/' or path[root_slice.len] == '\\');

    var end_index: usize = path.len - 1;

    while ((path[end_index] == '/' or path[end_index] == '\\') and end_index > root_slice.len) {
        if (end_index == 0)
            return path[0..0];
        end_index -= 1;
    }

    while (path[end_index] != '/' and path[end_index] != '\\' and end_index > root_slice.len) {
        if (end_index == 0)
            return path[0..0];
        end_index -= 1;
    }

    if (have_root_slash and end_index == root_slice.len) {
        end_index += 1;
    }

    return path[0..end_index];
}

pub fn dirnamePosix(path: []const u8) []const u8 {
    if (path.len == 0)
        return path[0..0];

    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return path[0..1];
        end_index -= 1;
    }

    while (path[end_index] != '/') {
        if (end_index == 0)
            return path[0..0];
        end_index -= 1;
    }

    if (end_index == 0 and path[end_index] == '/')
        return path[0..1];

    return path[0..end_index];
}

test "os.path.dirnamePosix" {
    testDirnamePosix("/a/b/c", "/a/b");
    testDirnamePosix("/a/b/c///", "/a/b");
    testDirnamePosix("/a", "/");
    testDirnamePosix("/", "/");
    testDirnamePosix("////", "/");
    testDirnamePosix("", "");
    testDirnamePosix("a", "");
    testDirnamePosix("a/", "");
    testDirnamePosix("a//", "");
}

test "os.path.dirnameWindows" {
    testDirnameWindows("c:\\", "c:\\");
    testDirnameWindows("c:\\foo", "c:\\");
    testDirnameWindows("c:\\foo\\", "c:\\");
    testDirnameWindows("c:\\foo\\bar", "c:\\foo");
    testDirnameWindows("c:\\foo\\bar\\", "c:\\foo");
    testDirnameWindows("c:\\foo\\bar\\baz", "c:\\foo\\bar");
    testDirnameWindows("\\", "\\");
    testDirnameWindows("\\foo", "\\");
    testDirnameWindows("\\foo\\", "\\");
    testDirnameWindows("\\foo\\bar", "\\foo");
    testDirnameWindows("\\foo\\bar\\", "\\foo");
    testDirnameWindows("\\foo\\bar\\baz", "\\foo\\bar");
    testDirnameWindows("c:", "c:");
    testDirnameWindows("c:foo", "c:");
    testDirnameWindows("c:foo\\", "c:");
    testDirnameWindows("c:foo\\bar", "c:foo");
    testDirnameWindows("c:foo\\bar\\", "c:foo");
    testDirnameWindows("c:foo\\bar\\baz", "c:foo\\bar");
    testDirnameWindows("file:stream", "");
    testDirnameWindows("dir\\file:stream", "dir");
    testDirnameWindows("\\\\unc\\share", "\\\\unc\\share");
    testDirnameWindows("\\\\unc\\share\\foo", "\\\\unc\\share\\");
    testDirnameWindows("\\\\unc\\share\\foo\\", "\\\\unc\\share\\");
    testDirnameWindows("\\\\unc\\share\\foo\\bar", "\\\\unc\\share\\foo");
    testDirnameWindows("\\\\unc\\share\\foo\\bar\\", "\\\\unc\\share\\foo");
    testDirnameWindows("\\\\unc\\share\\foo\\bar\\baz", "\\\\unc\\share\\foo\\bar");
    testDirnameWindows("/a/b/", "/a");
    testDirnameWindows("/a/b", "/a");
    testDirnameWindows("/a", "/");
    testDirnameWindows("", "");
    testDirnameWindows("/", "/");
    testDirnameWindows("////", "/");
    testDirnameWindows("foo", "");
}

fn testDirnamePosix(input: []const u8, expected_output: []const u8) void {
    assert(mem.eql(u8, dirnamePosix(input), expected_output));
}

fn testDirnameWindows(input: []const u8, expected_output: []const u8) void {
    assert(mem.eql(u8, dirnameWindows(input), expected_output));
}

pub fn basename(path: []const u8) []const u8 {
    if (is_windows) {
        return basenameWindows(path);
    } else {
        return basenamePosix(path);
    }
}

pub fn basenamePosix(path: []const u8) []const u8 {
    if (path.len == 0)
        return []u8{};

    var end_index: usize = path.len - 1;
    while (path[end_index] == '/') {
        if (end_index == 0)
            return []u8{};
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
        return []u8{};

    var end_index: usize = path.len - 1;
    while (true) {
        const byte = path[end_index];
        if (byte == '/' or byte == '\\') {
            if (end_index == 0)
                return []u8{};
            end_index -= 1;
            continue;
        }
        if (byte == ':' and end_index == 1) {
            return []u8{};
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

test "os.path.basename" {
    testBasename("", "");
    testBasename("/", "");
    testBasename("/dir/basename.ext", "basename.ext");
    testBasename("/basename.ext", "basename.ext");
    testBasename("basename.ext", "basename.ext");
    testBasename("basename.ext/", "basename.ext");
    testBasename("basename.ext//", "basename.ext");
    testBasename("/aaa/bbb", "bbb");
    testBasename("/aaa/", "aaa");
    testBasename("/aaa/b", "b");
    testBasename("/a/b", "b");
    testBasename("//a", "a");

    testBasenamePosix("\\dir\\basename.ext", "\\dir\\basename.ext");
    testBasenamePosix("\\basename.ext", "\\basename.ext");
    testBasenamePosix("basename.ext", "basename.ext");
    testBasenamePosix("basename.ext\\", "basename.ext\\");
    testBasenamePosix("basename.ext\\\\", "basename.ext\\\\");
    testBasenamePosix("foo", "foo");

    testBasenameWindows("\\dir\\basename.ext", "basename.ext");
    testBasenameWindows("\\basename.ext", "basename.ext");
    testBasenameWindows("basename.ext", "basename.ext");
    testBasenameWindows("basename.ext\\", "basename.ext");
    testBasenameWindows("basename.ext\\\\", "basename.ext");
    testBasenameWindows("foo", "foo");
    testBasenameWindows("C:", "");
    testBasenameWindows("C:.", ".");
    testBasenameWindows("C:\\", "");
    testBasenameWindows("C:\\dir\\base.ext", "base.ext");
    testBasenameWindows("C:\\basename.ext", "basename.ext");
    testBasenameWindows("C:basename.ext", "basename.ext");
    testBasenameWindows("C:basename.ext\\", "basename.ext");
    testBasenameWindows("C:basename.ext\\\\", "basename.ext");
    testBasenameWindows("C:foo", "foo");
    testBasenameWindows("file:stream", "file:stream");
}

fn testBasename(input: []const u8, expected_output: []const u8) void {
    assert(mem.eql(u8, basename(input), expected_output));
}

fn testBasenamePosix(input: []const u8, expected_output: []const u8) void {
    assert(mem.eql(u8, basenamePosix(input), expected_output));
}

fn testBasenameWindows(input: []const u8, expected_output: []const u8) void {
    assert(mem.eql(u8, basenameWindows(input), expected_output));
}

/// Returns the relative path from `from` to `to`. If `from` and `to` each
/// resolve to the same path (after calling `resolve` on each), a zero-length
/// string is returned.
/// On Windows this canonicalizes the drive to a capital letter and paths to `\\`.
pub fn relative(allocator: *Allocator, from: []const u8, to: []const u8) ![]u8 {
    if (is_windows) {
        return relativeWindows(allocator, from, to);
    } else {
        return relativePosix(allocator, from, to);
    }
}

pub fn relativeWindows(allocator: *Allocator, from: []const u8, to: []const u8) ![]u8 {
    const resolved_from = try resolveWindows(allocator, [][]const u8{from});
    defer allocator.free(resolved_from);

    var clean_up_resolved_to = true;
    const resolved_to = try resolveWindows(allocator, [][]const u8{to});
    defer if (clean_up_resolved_to) allocator.free(resolved_to);

    const parsed_from = windowsParsePath(resolved_from);
    const parsed_to = windowsParsePath(resolved_to);
    const result_is_to = x: {
        if (parsed_from.kind != parsed_to.kind) {
            break :x true;
        } else switch (parsed_from.kind) {
            WindowsPath.Kind.NetworkShare => {
                break :x !networkShareServersEql(parsed_to.disk_designator, parsed_from.disk_designator);
            },
            WindowsPath.Kind.Drive => {
                break :x asciiUpper(parsed_from.disk_designator[0]) != asciiUpper(parsed_to.disk_designator[0]);
            },
            else => unreachable,
        }
    };

    if (result_is_to) {
        clean_up_resolved_to = false;
        return resolved_to;
    }

    var from_it = mem.split(resolved_from, "/\\");
    var to_it = mem.split(resolved_to, "/\\");
    while (true) {
        const from_component = from_it.next() ?? return mem.dupe(allocator, u8, to_it.rest());
        const to_rest = to_it.rest();
        if (to_it.next()) |to_component| {
            // TODO ASCII is wrong, we actually need full unicode support to compare paths.
            if (asciiEqlIgnoreCase(from_component, to_component))
                continue;
        }
        var up_count: usize = 1;
        while (from_it.next()) |_| {
            up_count += 1;
        }
        const up_index_end = up_count * "..\\".len;
        const result = try allocator.alloc(u8, up_index_end + to_rest.len);
        errdefer allocator.free(result);

        var result_index: usize = 0;
        while (result_index < up_index_end) {
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '\\';
            result_index += 1;
        }
        // shave off the trailing slash
        result_index -= 1;

        var rest_it = mem.split(to_rest, "/\\");
        while (rest_it.next()) |to_component| {
            result[result_index] = '\\';
            result_index += 1;
            mem.copy(u8, result[result_index..], to_component);
            result_index += to_component.len;
        }

        return result[0..result_index];
    }

    return []u8{};
}

pub fn relativePosix(allocator: *Allocator, from: []const u8, to: []const u8) ![]u8 {
    const resolved_from = try resolvePosix(allocator, [][]const u8{from});
    defer allocator.free(resolved_from);

    const resolved_to = try resolvePosix(allocator, [][]const u8{to});
    defer allocator.free(resolved_to);

    var from_it = mem.split(resolved_from, "/");
    var to_it = mem.split(resolved_to, "/");
    while (true) {
        const from_component = from_it.next() ?? return mem.dupe(allocator, u8, to_it.rest());
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
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '.';
            result_index += 1;
            result[result_index] = '/';
            result_index += 1;
        }
        if (to_rest.len == 0) {
            // shave off the trailing slash
            return result[0 .. result_index - 1];
        }

        mem.copy(u8, result[result_index..], to_rest);
        return result;
    }

    return []u8{};
}

test "os.path.relative" {
    testRelativeWindows("c:/blah\\blah", "d:/games", "D:\\games");
    testRelativeWindows("c:/aaaa/bbbb", "c:/aaaa", "..");
    testRelativeWindows("c:/aaaa/bbbb", "c:/cccc", "..\\..\\cccc");
    testRelativeWindows("c:/aaaa/bbbb", "c:/aaaa/bbbb", "");
    testRelativeWindows("c:/aaaa/bbbb", "c:/aaaa/cccc", "..\\cccc");
    testRelativeWindows("c:/aaaa/", "c:/aaaa/cccc", "cccc");
    testRelativeWindows("c:/", "c:\\aaaa\\bbbb", "aaaa\\bbbb");
    testRelativeWindows("c:/aaaa/bbbb", "d:\\", "D:\\");
    testRelativeWindows("c:/AaAa/bbbb", "c:/aaaa/bbbb", "");
    testRelativeWindows("c:/aaaaa/", "c:/aaaa/cccc", "..\\aaaa\\cccc");
    testRelativeWindows("C:\\foo\\bar\\baz\\quux", "C:\\", "..\\..\\..\\..");
    testRelativeWindows("C:\\foo\\test", "C:\\foo\\test\\bar\\package.json", "bar\\package.json");
    testRelativeWindows("C:\\foo\\bar\\baz-quux", "C:\\foo\\bar\\baz", "..\\baz");
    testRelativeWindows("C:\\foo\\bar\\baz", "C:\\foo\\bar\\baz-quux", "..\\baz-quux");
    testRelativeWindows("\\\\foo\\bar", "\\\\foo\\bar\\baz", "baz");
    testRelativeWindows("\\\\foo\\bar\\baz", "\\\\foo\\bar", "..");
    testRelativeWindows("\\\\foo\\bar\\baz-quux", "\\\\foo\\bar\\baz", "..\\baz");
    testRelativeWindows("\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz-quux", "..\\baz-quux");
    testRelativeWindows("C:\\baz-quux", "C:\\baz", "..\\baz");
    testRelativeWindows("C:\\baz", "C:\\baz-quux", "..\\baz-quux");
    testRelativeWindows("\\\\foo\\baz-quux", "\\\\foo\\baz", "..\\baz");
    testRelativeWindows("\\\\foo\\baz", "\\\\foo\\baz-quux", "..\\baz-quux");
    testRelativeWindows("C:\\baz", "\\\\foo\\bar\\baz", "\\\\foo\\bar\\baz");
    testRelativeWindows("\\\\foo\\bar\\baz", "C:\\baz", "C:\\baz");

    testRelativePosix("/var/lib", "/var", "..");
    testRelativePosix("/var/lib", "/bin", "../../bin");
    testRelativePosix("/var/lib", "/var/lib", "");
    testRelativePosix("/var/lib", "/var/apache", "../apache");
    testRelativePosix("/var/", "/var/lib", "lib");
    testRelativePosix("/", "/var/lib", "var/lib");
    testRelativePosix("/foo/test", "/foo/test/bar/package.json", "bar/package.json");
    testRelativePosix("/Users/a/web/b/test/mails", "/Users/a/web/b", "../..");
    testRelativePosix("/foo/bar/baz-quux", "/foo/bar/baz", "../baz");
    testRelativePosix("/foo/bar/baz", "/foo/bar/baz-quux", "../baz-quux");
    testRelativePosix("/baz-quux", "/baz", "../baz");
    testRelativePosix("/baz", "/baz-quux", "../baz-quux");
}

fn testRelativePosix(from: []const u8, to: []const u8, expected_output: []const u8) void {
    const result = relativePosix(debug.global_allocator, from, to) catch unreachable;
    assert(mem.eql(u8, result, expected_output));
}

fn testRelativeWindows(from: []const u8, to: []const u8, expected_output: []const u8) void {
    const result = relativeWindows(debug.global_allocator, from, to) catch unreachable;
    assert(mem.eql(u8, result, expected_output));
}

/// Return the canonicalized absolute pathname.
/// Expands all symbolic links and resolves references to `.`, `..`, and
/// extra `/` characters in ::pathname.
/// Caller must deallocate result.
pub fn real(allocator: *Allocator, pathname: []const u8) ![]u8 {
    switch (builtin.os) {
        Os.windows => {
            const pathname_buf = try allocator.alloc(u8, pathname.len + 1);
            defer allocator.free(pathname_buf);

            mem.copy(u8, pathname_buf, pathname);
            pathname_buf[pathname.len] = 0;

            const h_file = windows.CreateFileA(pathname_buf.ptr, windows.GENERIC_READ, windows.FILE_SHARE_READ, null, windows.OPEN_EXISTING, windows.FILE_ATTRIBUTE_NORMAL, null);
            if (h_file == windows.INVALID_HANDLE_VALUE) {
                const err = windows.GetLastError();
                return switch (err) {
                    windows.ERROR.FILE_NOT_FOUND => error.FileNotFound,
                    windows.ERROR.ACCESS_DENIED => error.AccessDenied,
                    windows.ERROR.FILENAME_EXCED_RANGE => error.NameTooLong,
                    else => os.unexpectedErrorWindows(err),
                };
            }
            defer os.close(h_file);
            var buf = try allocator.alloc(u8, 256);
            errdefer allocator.free(buf);
            while (true) {
                const buf_len = math.cast(windows.DWORD, buf.len) catch return error.NameTooLong;
                const result = windows.GetFinalPathNameByHandleA(h_file, buf.ptr, buf_len, windows.VOLUME_NAME_DOS);

                if (result == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        windows.ERROR.PATH_NOT_FOUND => error.FileNotFound,
                        windows.ERROR.NOT_ENOUGH_MEMORY => error.OutOfMemory,
                        windows.ERROR.INVALID_PARAMETER => unreachable,
                        else => os.unexpectedErrorWindows(err),
                    };
                }

                if (result > buf.len) {
                    buf = try allocator.realloc(u8, buf, result);
                    continue;
                }

                // windows returns \\?\ prepended to the path
                // we strip it because nobody wants \\?\ prepended to their path
                const final_len = x: {
                    if (result > 4 and mem.startsWith(u8, buf, "\\\\?\\")) {
                        var i: usize = 4;
                        while (i < result) : (i += 1) {
                            buf[i - 4] = buf[i];
                        }
                        break :x result - 4;
                    } else {
                        break :x result;
                    }
                };

                return allocator.shrink(u8, buf, final_len);
            }
        },
        Os.macosx, Os.ios => {
            // TODO instead of calling the libc function here, port the implementation
            // to Zig, and then remove the NameTooLong error possibility.
            const pathname_buf = try allocator.alloc(u8, pathname.len + 1);
            defer allocator.free(pathname_buf);

            const result_buf = try allocator.alloc(u8, posix.PATH_MAX);
            errdefer allocator.free(result_buf);

            mem.copy(u8, pathname_buf, pathname);
            pathname_buf[pathname.len] = 0;

            const err = posix.getErrno(posix.realpath(pathname_buf.ptr, result_buf.ptr));
            if (err > 0) {
                return switch (err) {
                    posix.EINVAL => unreachable,
                    posix.EBADF => unreachable,
                    posix.EFAULT => unreachable,
                    posix.EACCES => error.AccessDenied,
                    posix.ENOENT => error.FileNotFound,
                    posix.ENOTSUP => error.NotSupported,
                    posix.ENOTDIR => error.NotDir,
                    posix.ENAMETOOLONG => error.NameTooLong,
                    posix.ELOOP => error.SymLinkLoop,
                    posix.EIO => error.InputOutput,
                    else => os.unexpectedErrorPosix(err),
                };
            }
            return allocator.shrink(u8, result_buf, cstr.len(result_buf.ptr));
        },
        Os.linux => {
            const fd = try os.posixOpen(allocator, pathname, posix.O_PATH | posix.O_NONBLOCK | posix.O_CLOEXEC, 0);
            defer os.close(fd);

            var buf: ["/proc/self/fd/-2147483648".len]u8 = undefined;
            const proc_path = fmt.bufPrint(buf[0..], "/proc/self/fd/{}", fd) catch unreachable;

            return os.readLink(allocator, proc_path);
        },
        else => @compileError("TODO implement os.path.real for " ++ @tagName(builtin.os)),
    }
}

test "os.path.real" {
    // at least call it so it gets compiled
    _ = real(debug.global_allocator, "some_path");
}
