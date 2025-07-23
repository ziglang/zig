const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = mem.Allocator;
const os = std.os;
const fs = std.fs;
const Cache = std.Build.Cache;
const Compilation = @import("Compilation.zig");
const Package = @import("Package.zig");
const build_options = @import("build_options");

/// Returns the sub_path that worked, or `null` if none did.
/// The path of the returned Directory is relative to `base`.
/// The handle of the returned Directory is open.
fn testZigInstallPrefix(base_dir: fs.Dir) ?Cache.Directory {
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
        return .{ .handle = test_zig_dir, .path = lib_zig };
    }

    // Try lib/std/std.zig
    var test_zig_dir = base_dir.openDir("lib", .{}) catch return null;
    const file = test_zig_dir.openFile(test_index_file, .{}) catch {
        test_zig_dir.close();
        return null;
    };
    file.close();
    return .{ .handle = test_zig_dir, .path = "lib" };
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDir(gpa: Allocator) !Cache.Directory {
    const cwd_path = try getResolvedCwd(gpa);
    defer gpa.free(cwd_path);
    const self_exe_path = try fs.selfExePathAlloc(gpa);
    defer gpa.free(self_exe_path);

    return findZigLibDirFromSelfExe(gpa, cwd_path, self_exe_path);
}

/// Like `std.process.getCwdAlloc`, but also resolves the path with `std.fs.path.resolve`. This
/// means the path has no repeated separators, no "." or ".." components, and no trailing separator.
/// On WASI, "" is returned instead of ".".
pub fn getResolvedCwd(gpa: Allocator) error{
    OutOfMemory,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
}![]u8 {
    if (builtin.target.os.tag == .wasi) {
        if (std.debug.runtime_safety) {
            const cwd = try std.process.getCwdAlloc(gpa);
            defer gpa.free(cwd);
            std.debug.assert(mem.eql(u8, cwd, "."));
        }
        return "";
    }
    const cwd = try std.process.getCwdAlloc(gpa);
    defer gpa.free(cwd);
    const resolved = try fs.path.resolve(gpa, &.{cwd});
    std.debug.assert(fs.path.isAbsolute(resolved));
    return resolved;
}

/// Both the directory handle and the path are newly allocated resources which the caller now owns.
pub fn findZigLibDirFromSelfExe(
    allocator: Allocator,
    /// The return value of `getResolvedCwd`.
    /// Passed as an argument to avoid pointlessly repeating the call.
    cwd_path: []const u8,
    self_exe_path: []const u8,
) !Cache.Directory {
    if (try std.zig.EnvVar.ZIG_LIB_DIR.get(allocator)) |value| {
        return .{
            .handle = try fs.cwd().openDir(value, .{}),
            .path = value,
        };
    }

    const cwd = fs.cwd();
    var cur_path: []const u8 = self_exe_path;
    while (fs.path.dirname(cur_path)) |dirname| : (cur_path = dirname) {
        var base_dir = cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        const sub_directory = testZigInstallPrefix(base_dir) orelse continue;
        const p = try fs.path.join(allocator, &.{ dirname, sub_directory.path.? });
        defer allocator.free(p);

        const resolved = try resolvePath(allocator, cwd_path, &.{p});
        return .{
            .handle = sub_directory.handle,
            .path = if (resolved.len == 0) null else resolved,
        };
    }
    return error.FileNotFound;
}

/// Caller owns returned memory.
pub fn resolveGlobalCacheDir(allocator: Allocator) ![]u8 {
    if (builtin.os.tag == .wasi)
        @compileError("on WASI the global cache dir must be resolved with preopens");

    if (try std.zig.EnvVar.ZIG_GLOBAL_CACHE_DIR.get(allocator)) |value| return value;

    const appname = "zig";

    if (builtin.os.tag != .windows) {
        if (std.zig.EnvVar.XDG_CACHE_HOME.getPosix()) |cache_root| {
            if (cache_root.len > 0) {
                return fs.path.join(allocator, &.{ cache_root, appname });
            }
        }
        if (std.zig.EnvVar.HOME.getPosix()) |home| {
            return fs.path.join(allocator, &.{ home, ".cache", appname });
        }
    }

    return fs.getAppDataDir(allocator, appname);
}

/// Similar to `fs.path.resolve`, but converts to a cwd-relative path, or, if that would
/// start with a relative up-dir (".."), an absolute path based on the cwd. Also, the cwd
/// returns the empty string ("") instead of ".".
pub fn resolvePath(
    gpa: Allocator,
    /// The return value of `getResolvedCwd`.
    /// Passed as an argument to avoid pointlessly repeating the call.
    cwd_resolved: []const u8,
    paths: []const []const u8,
) Allocator.Error![]u8 {
    if (builtin.target.os.tag == .wasi) {
        std.debug.assert(mem.eql(u8, cwd_resolved, ""));
        const res = try fs.path.resolve(gpa, paths);
        if (mem.eql(u8, res, ".")) {
            gpa.free(res);
            return "";
        }
        return res;
    }

    // Heuristic for a fast path: if no component is absolute and ".." never appears, we just need to resolve `paths`.
    for (paths) |p| {
        if (fs.path.isAbsolute(p)) break; // absolute path
        if (mem.indexOf(u8, p, "..") != null) break; // may contain up-dir
    } else {
        // no absolute path, no "..".
        const res = try fs.path.resolve(gpa, paths);
        if (mem.eql(u8, res, ".")) {
            gpa.free(res);
            return "";
        }
        std.debug.assert(!fs.path.isAbsolute(res));
        std.debug.assert(!isUpDir(res));
        return res;
    }

    // The fast path failed; resolve the whole thing.
    // Optimization: `paths` often has just one element.
    const path_resolved = switch (paths.len) {
        0 => unreachable,
        1 => try fs.path.resolve(gpa, &.{ cwd_resolved, paths[0] }),
        else => r: {
            const all_paths = try gpa.alloc([]const u8, paths.len + 1);
            defer gpa.free(all_paths);
            all_paths[0] = cwd_resolved;
            @memcpy(all_paths[1..], paths);
            break :r try fs.path.resolve(gpa, all_paths);
        },
    };
    errdefer gpa.free(path_resolved);

    std.debug.assert(fs.path.isAbsolute(path_resolved));
    std.debug.assert(fs.path.isAbsolute(cwd_resolved));

    if (!std.mem.startsWith(u8, path_resolved, cwd_resolved)) return path_resolved; // not in cwd
    if (path_resolved.len == cwd_resolved.len) {
        // equal to cwd
        gpa.free(path_resolved);
        return "";
    }
    if (path_resolved[cwd_resolved.len] != std.fs.path.sep) return path_resolved; // not in cwd (last component differs)

    // in cwd; extract sub path
    const sub_path = try gpa.dupe(u8, path_resolved[cwd_resolved.len + 1 ..]);
    gpa.free(path_resolved);
    return sub_path;
}

/// TODO move this to std.fs.path
pub fn isUpDir(p: []const u8) bool {
    return mem.startsWith(u8, p, "..") and (p.len == 2 or p[2] == fs.path.sep);
}

pub const default_local_zig_cache_basename = ".zig-cache";

/// Searches upwards from `cwd` for a directory containing a `build.zig` file.
/// If such a directory is found, returns the path to it joined to the `.zig_cache` name.
/// Otherwise, returns `null`, indicating no suitable local cache location.
pub fn resolveSuitableLocalCacheDir(arena: Allocator, cwd: []const u8) Allocator.Error!?[]u8 {
    var cur_dir = cwd;
    while (true) {
        const joined = try fs.path.join(arena, &.{ cur_dir, Package.build_zig_basename });
        if (fs.cwd().access(joined, .{})) |_| {
            return try fs.path.join(arena, &.{ cur_dir, default_local_zig_cache_basename });
        } else |err| switch (err) {
            error.FileNotFound => {
                cur_dir = fs.path.dirname(cur_dir) orelse return null;
                continue;
            },
            else => return null,
        }
    }
}
