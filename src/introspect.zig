const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const Compilation = @import("Compilation.zig");

/// Returns the sub_path that worked, or `null` if none did.
/// The path of the returned Directory is relative to `base`.
/// The handle of the returned Directory is open.
fn testZigInstallPrefix(base_dir: fs.Dir) ?Compilation.Directory {
    const test_index_file = "std" ++ fs.path.sep_str ++ "std.zig";

    zig_dir: {
        // Try lib/zig/std/std.zig
        const lib_zig = "lib" ++ fs.path.sep_str ++ "zig";
        var test_zig_dir = base_dir.openDir(lib_zig, .{}) catch break :zig_dir;
        const file = test_zig_dir.openFile(test_index_file, .{}) catch {
            test_zig_dir.close();
            break :zig_dir;
        };
        file.close();
        return Compilation.Directory{ .handle = test_zig_dir, .path = lib_zig };
    }

    // Try lib/std/std.zig
    var test_zig_dir = base_dir.openDir("lib", .{}) catch return null;
    const file = test_zig_dir.openFile(test_index_file, .{}) catch {
        test_zig_dir.close();
        return null;
    };
    file.close();
    return Compilation.Directory{ .handle = test_zig_dir, .path = "lib" };
}

/// This is a small wrapper around selfExePathAlloc that adds support for WASI
/// based on a hard-coded Preopen directory ("/zig")
pub fn findZigExePath(allocator: mem.Allocator) ![]u8 {
    if (builtin.os.tag == .wasi) {
        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();
        // On WASI, argv[0] is always just the basename of the current executable
        const argv0 = args.next() orelse return error.FileNotFound;

        // Check these paths:
        //  1. "/zig/{exe_name}"
        //  2. "/zig/bin/{exe_name}"
        const base_paths_to_check = &[_][]const u8{ "/zig", "/zig/bin" };
        const exe_names_to_check = &[_][]const u8{ fs.path.basename(argv0), "zig.wasm" };

        for (base_paths_to_check) |base_path| {
            for (exe_names_to_check) |exe_name| {
                const test_path = fs.path.join(allocator, &.{ base_path, exe_name }) catch continue;
                defer allocator.free(test_path);

                // Make sure it's a file we're pointing to
                const file = os.fstatat(os.wasi.AT.FDCWD, test_path, 0) catch continue;
                if (file.filetype != .REGULAR_FILE) continue;

                // Path seems to be valid, let's try to turn it into an absolute path
                var real_path_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
                if (os.realpath(test_path, &real_path_buf)) |real_path| {
                    return allocator.dupe(u8, real_path); // Success: return absolute path
                } else |_| continue;
            }
        }
        return error.FileNotFound;
    }

    return fs.selfExePathAlloc(allocator);
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDir(gpa: mem.Allocator) !Compilation.Directory {
    const self_exe_path = try findZigExePath(gpa);
    defer gpa.free(self_exe_path);

    return findZigLibDirFromSelfExe(gpa, self_exe_path);
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDirFromSelfExe(
    allocator: mem.Allocator,
    self_exe_path: []const u8,
) error{ OutOfMemory, FileNotFound }!Compilation.Directory {
    const cwd = fs.cwd();
    var cur_path: []const u8 = self_exe_path;
    while (fs.path.dirname(cur_path)) |dirname| : (cur_path = dirname) {
        var base_dir = cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        const sub_directory = testZigInstallPrefix(base_dir) orelse continue;
        return Compilation.Directory{
            .handle = sub_directory.handle,
            .path = try fs.path.join(allocator, &[_][]const u8{ dirname, sub_directory.path.? }),
        };
    }
    return error.FileNotFound;
}

/// Caller owns returned memory.
pub fn resolveGlobalCacheDir(allocator: mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "ZIG_GLOBAL_CACHE_DIR")) |value| {
        if (value.len > 0) {
            return value;
        } else {
            allocator.free(value);
        }
    } else |_| {}

    const appname = "zig";

    if (builtin.os.tag != .windows) {
        if (std.os.getenv("XDG_CACHE_HOME")) |cache_root| {
            return fs.path.join(allocator, &[_][]const u8{ cache_root, appname });
        } else if (std.os.getenv("HOME")) |home| {
            return fs.path.join(allocator, &[_][]const u8{ home, ".cache", appname });
        }
    }

    if (builtin.os.tag == .wasi) {
        // On WASI, we have no way to get an App data dir, so we try to use a fixed
        // Preopen path "/cache" as a last resort
        const path = "/cache";

        const file = os.fstatat(os.wasi.AT.FDCWD, path, 0) catch return error.CacheDirUnavailable;
        if (file.filetype != .DIRECTORY) return error.CacheDirUnavailable;
        return allocator.dupe(u8, path);
    } else {
        return fs.getAppDataDir(allocator, appname);
    }
}
