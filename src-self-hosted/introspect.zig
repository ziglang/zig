// Introspection and determination of system libraries needed by zig.

const std = @import("std");
const mem = std.mem;
const os = std.os;

const warn = std.debug.warn;

/// Caller must free result
pub fn testZigInstallPrefix(allocator: *mem.Allocator, test_path: []const u8) ![]u8 {
    const test_zig_dir = try os.path.join(allocator, test_path, "lib", "zig");
    errdefer allocator.free(test_zig_dir);

    const test_index_file = try os.path.join(allocator, test_zig_dir, "std", "index.zig");
    defer allocator.free(test_index_file);

    var file = try os.File.openRead(allocator, test_index_file);
    file.close();

    return test_zig_dir;
}

/// Caller must free result
pub fn findZigLibDir(allocator: *mem.Allocator) ![]u8 {
    const self_exe_path = try os.selfExeDirPath(allocator);
    defer allocator.free(self_exe_path);

    var cur_path: []const u8 = self_exe_path;
    while (true) {
        const test_dir = os.path.dirname(cur_path) orelse ".";

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
        , @errorName(err));

        return error.ZigLibDirNotFound;
    };
}
