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

var compiler_id_mutex = std.Mutex{};
var compiler_id: [16]u8 = undefined;
var compiler_id_computed = false;

pub fn resolveCompilerId(gpa: *mem.Allocator) ![16]u8 {
    const held = compiler_id_mutex.acquire();
    defer held.release();

    if (compiler_id_computed)
        return compiler_id;
    compiler_id_computed = true;

    var cache_dir = try openGlobalCacheDir();
    defer cache_dir.close();

    var ch = try CacheHash.init(gpa, cache_dir, "exe");
    defer ch.release();

    const self_exe_path = try fs.selfExePathAlloc(gpa);
    defer gpa.free(self_exe_path);

    _ = try ch.addFile(self_exe_path, null);

    if (try ch.hit()) |digest| {
        compiler_id = digest[0..16].*;
        return compiler_id;
    }

    const libs = try std.process.getSelfExeSharedLibPaths(gpa);
    defer {
        for (libs) |lib| gpa.free(lib);
        gpa.free(libs);
    }

    for (libs) |lib| {
        try ch.addFilePost(lib);
    }

    const digest = ch.final();
    compiler_id = digest[0..16].*;
    return compiler_id;
}
