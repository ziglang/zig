const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
fn walkParentsForFileDir(
    allocator: mem.Allocator,
    self_exe_path: []const u8,
    test_dir_paths: []const []const u8,
    test_file_path: []const u8,
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

        for (test_dir_paths) |test_dir_path| {
            var test_dir = base_dir.openDir(test_dir_path, .{}) catch continue;
            const file = test_dir.openFile(test_file_path, .{}) catch {
                test_dir.close();
                continue;
            };
            file.close();

            const sub_directory = Compilation.Directory{ .handle = test_dir, .path = test_dir_path };
            const p = try fs.path.join(allocator, &[_][]const u8{ dirname, sub_directory.path.? });
            defer allocator.free(p);
            return Compilation.Directory{
                .handle = sub_directory.handle,
                .path = try resolvePath(allocator, p),
            };
        }
    }
    return error.FileNotFound;
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
    const lib_zig = "lib" ++ fs.path.sep_str ++ "zig";
    const test_index_file = "std" ++ fs.path.sep_str ++ "std.zig";
    return walkParentsForFileDir(allocator, self_exe_path, &.{ lib_zig, "lib" }, test_index_file);
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigSrcDirFromSelfExe(
    allocator: mem.Allocator,
    self_exe_path: []const u8,
    test_file_path: []const u8,
) error{
    OutOfMemory,
    FileNotFound,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}!Compilation.Directory {
    return walkParentsForFileDir(allocator, self_exe_path, &.{"src"}, test_file_path);
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
