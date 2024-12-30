const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");

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
        @compileError("this function is unsupported on WASI");
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
) error{
    OutOfMemory,
    FileNotFound,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}!Compilation.Directory {
    const cwd = fs.cwd();
    var cur_path: []const u8 = self_exe_path;
    while (fs.path.dirname(cur_path)) |dirname| : (cur_path = dirname) {
        var base_dir = cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        const sub_directory = testZigInstallPrefix(base_dir) orelse continue;
        const p = try fs.path.join(allocator, &[_][]const u8{ dirname, sub_directory.path.? });
        defer allocator.free(p);
        return Compilation.Directory{
            .handle = sub_directory.handle,
            .path = try resolvePath(allocator, p),
        };
    }
    return error.FileNotFound;
}

/// Caller owns returned memory.
pub fn resolveGlobalCacheDir(allocator: mem.Allocator) ![]u8 {
    if (builtin.os.tag == .wasi)
        @compileError("on WASI the global cache dir must be resolved with preopens");

    if (try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(allocator)) |value| return value;

    const appname = "zig";

    if (builtin.os.tag != .windows) {
        if (std.zig.EnvVar.XDG_CACHE_HOME.getPosix()) |cache_root| {
            if (cache_root.len > 0) {
                return fs.path.join(allocator, &[_][]const u8{ cache_root, appname });
            }
        }
        if (std.zig.EnvVar.HOME.getPosix()) |home| {
            return fs.path.join(allocator, &[_][]const u8{ home, ".cache", appname });
        }
    }

    return fs.getAppDataDir(allocator, appname);
}

/// Similar to std.fs.path.resolve, with a few important differences:
/// * If the input is an absolute path, check it against the cwd and try to
///   convert it to a relative path.
/// * If the resulting path would start with a relative up-dir ("../"), instead
///   return an absolute path based on the cwd.
/// * When targeting WASI, fail with an error message if an absolute path is
///   used.
pub fn resolvePath(
    ally: mem.Allocator,
    p: []const u8,
) error{
    OutOfMemory,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}![]u8 {
    if (fs.path.isAbsolute(p)) {
        const cwd_path = try std.process.getCwdAlloc(ally);
        defer ally.free(cwd_path);
        const relative = try fs.path.relative(ally, cwd_path, p);
        if (isUpDir(relative)) {
            ally.free(relative);
            return ally.dupe(u8, p);
        } else {
            return relative;
        }
    } else {
        const resolved = try fs.path.resolve(ally, &.{p});
        if (isUpDir(resolved)) {
            ally.free(resolved);
            const cwd_path = try std.process.getCwdAlloc(ally);
            defer ally.free(cwd_path);
            return fs.path.resolve(ally, &.{ cwd_path, p });
        } else {
            return resolved;
        }
    }
}

/// TODO move this to std.fs.path
pub fn isUpDir(p: []const u8) bool {
    return mem.startsWith(u8, p, "..") and (p.len == 2 or p[2] == fs.path.sep);
}
