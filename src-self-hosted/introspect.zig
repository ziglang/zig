//! Introspection and determination of system libraries needed by zig.

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const CacheHash = std.cache_hash.CacheHash;

/// Caller must free result
pub fn testZigInstallPrefix(allocator: *mem.Allocator, test_path: []const u8) ![]u8 {
    {
        const test_zig_dir = try fs.path.join(allocator, &[_][]const u8{ test_path, "lib", "zig" });
        errdefer allocator.free(test_zig_dir);

        const test_index_file = try fs.path.join(allocator, &[_][]const u8{ test_zig_dir, "std", "std.zig" });
        defer allocator.free(test_index_file);

        if (fs.cwd().openFile(test_index_file, .{})) |file| {
            file.close();
            return test_zig_dir;
        } else |err| switch (err) {
            error.FileNotFound => {
                allocator.free(test_zig_dir);
            },
            else => |e| return e,
        }
    }

    // Also try without "zig"
    const test_zig_dir = try fs.path.join(allocator, &[_][]const u8{ test_path, "lib" });
    errdefer allocator.free(test_zig_dir);

    const test_index_file = try fs.path.join(allocator, &[_][]const u8{ test_zig_dir, "std", "std.zig" });
    defer allocator.free(test_index_file);

    const file = try fs.cwd().openFile(test_index_file, .{});
    file.close();

    return test_zig_dir;
}

/// Caller must free result
pub fn findZigLibDir(allocator: *mem.Allocator) ![]u8 {
    const self_exe_path = try fs.selfExePathAlloc(allocator);
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
        std.debug.print(
            \\Unable to find zig lib directory: {}.
            \\Reinstall Zig or use --zig-install-prefix.
            \\
        , .{@errorName(err)});

        return error.ZigLibDirNotFound;
    };
}

/// Caller owns returned memory.
pub fn resolveGlobalCacheDir(allocator: *mem.Allocator) ![]u8 {
    const appname = "zig";

    if (std.Target.current.os.tag != .windows) {
        if (std.os.getenv("XDG_CACHE_HOME")) |cache_root| {
            return fs.path.join(allocator, &[_][]const u8{ cache_root, appname });
        } else if (std.os.getenv("HOME")) |home| {
            return fs.path.join(allocator, &[_][]const u8{ home, ".cache", appname });
        }
    }

    return fs.getAppDataDir(allocator, appname);
}

pub fn openGlobalCacheDir() !fs.Dir {
    var buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const path_name = try resolveGlobalCacheDir(&fba.allocator);
    return fs.cwd().makeOpenPath(path_name, .{});
}
