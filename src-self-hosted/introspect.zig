//! Introspection and determination of system libraries needed by zig.

const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const warn = std.debug.warn;

/// Caller must free result
pub fn testZigInstallPrefix(allocator: *mem.Allocator, test_path: []const u8) ![]u8 {
    const test_zig_dir = try fs.path.join(allocator, &[_][]const u8{ test_path, "lib", "zig" });
    errdefer allocator.free(test_zig_dir);

    const test_index_file = try fs.path.join(allocator, &[_][]const u8{ test_zig_dir, "std", "std.zig" });
    defer allocator.free(test_index_file);

    var file = try fs.cwd().openRead(test_index_file);
    file.close();

    return test_zig_dir;
}

/// Caller must free result
pub fn findZigLibDir(allocator: *mem.Allocator) ![]u8 {
    const self_exe_path = try fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(self_exe_path);

    var cur_path: []const u8 = self_exe_path;
    while (true) {
        const test_dir = fs.path.dirname(cur_path) orelse ".";

        if (mem.eql(u8, test_dir, cur_path)) {
            break;
        }

        return testZigInstallPrefix(allocator, test_dir) catch |err| {
            cur_path = test_dir;
            continue;
        };
    }

    return error.FileNotFound;
}

pub fn resolveZigLibDir(allocator: *mem.Allocator) ![]u8 {
    return findZigLibDir(allocator) catch |err| {
        warn(
            \\Unable to find zig lib directory: {}.
            \\Reinstall Zig or use --zig-install-prefix.
            \\
        , .{@errorName(err)});

        return error.ZigLibDirNotFound;
    };
}

/// Caller must free result
pub fn resolveZigCacheDir(allocator: *mem.Allocator) ![]u8 {
    return std.mem.dupe(allocator, u8, "zig-cache");
}
