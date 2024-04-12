const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const Directory = std.Build.Cache.Directory;
const fatal = std.zig.fatal;

/// Returns the sub_path that worked, or `null` if none did.
/// The path of the returned Directory is relative to `base`.
/// The handle of the returned Directory is open.
fn testZigInstallPrefix(base_dir: fs.Dir) ?Directory {
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
        return Directory{ .handle = test_zig_dir, .path = lib_zig };
    }

    // Try lib/std/std.zig
    var test_zig_dir = base_dir.openDir("lib", .{}) catch return null;
    const file = test_zig_dir.openFile(test_index_file, .{}) catch {
        test_zig_dir.close();
        return null;
    };
    file.close();
    return Directory{ .handle = test_zig_dir, .path = "lib" };
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
pub fn findZigLibDir(gpa: mem.Allocator) !Directory {
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
}!Directory {
    const cwd = fs.cwd();
    var cur_path: []const u8 = self_exe_path;
    while (fs.path.dirname(cur_path)) |dirname| : (cur_path = dirname) {
        var base_dir = cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        const sub_directory = testZigInstallPrefix(base_dir) orelse continue;
        const p = try fs.path.join(allocator, &[_][]const u8{ dirname, sub_directory.path.? });
        defer allocator.free(p);
        return Directory{
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
            return fs.path.join(allocator, &[_][]const u8{ cache_root, appname });
        } else if (std.zig.EnvVar.HOME.getPosix()) |home| {
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

pub const BuildRoot = struct {
    directory: std.Build.Cache.Directory,
    build_zig_basename: []const u8,
    cleanup_build_dir: ?std.fs.Dir,

    pub fn deinit(br: *BuildRoot) void {
        if (br.cleanup_build_dir) |*dir| dir.close();
        br.* = undefined;
    }
};

pub const FindBuildRootOptions = struct {
    build_file: ?[]const u8 = null,
    cwd_path: ?[]const u8 = null,
};

pub fn findBuildRoot(arena: std.mem.Allocator, options: FindBuildRootOptions) !BuildRoot {
    const cwd_path = options.cwd_path orelse try std.process.getCwdAlloc(arena);
    const build_zig_basename = if (options.build_file) |bf|
        std.fs.path.basename(bf)
    else
        std.zig.package.build_zig_basename;

    if (options.build_file) |bf| {
        if (std.fs.path.dirname(bf)) |dirname| {
            const dir = std.fs.cwd().openDir(dirname, .{}) catch |err| {
                fatal("unable to open directory to build file from argument 'build-file', '{s}': {s}", .{ dirname, @errorName(err) });
            };
            return .{
                .build_zig_basename = build_zig_basename,
                .directory = .{ .path = dirname, .handle = dir },
                .cleanup_build_dir = dir,
            };
        }

        return .{
            .build_zig_basename = build_zig_basename,
            .directory = .{ .path = null, .handle = std.fs.cwd() },
            .cleanup_build_dir = null,
        };
    }

    // Search up parent directories until we find build.zig.
    var dirname: []const u8 = cwd_path;
    while (true) {
        const joined_path = try std.fs.path.join(arena, &[_][]const u8{ dirname, build_zig_basename });
        if (std.fs.cwd().access(joined_path, .{})) |_| {
            const dir = std.fs.cwd().openDir(dirname, .{}) catch |err| {
                fatal("unable to open directory while searching for build.zig file, '{s}': {s}", .{ dirname, @errorName(err) });
            };
            return .{
                .build_zig_basename = build_zig_basename,
                .directory = .{
                    .path = dirname,
                    .handle = dir,
                },
                .cleanup_build_dir = dir,
            };
        } else |err| switch (err) {
            error.FileNotFound => {
                dirname = std.fs.path.dirname(dirname) orelse {
                    std.log.info("initialize {s} template file with 'zig init'", .{
                        std.zig.package.build_zig_basename,
                    });
                    std.log.info("see 'zig --help' for more options", .{});
                    fatal("no build.zig file found, in the current directory or any parent directories", .{});
                };
                continue;
            },
            else => |e| return e,
        }
    }
}

pub const Templates = struct {
    zig_lib_directory: std.Build.Cache.Directory,
    dir: std.fs.Dir,
    buffer: std.ArrayList(u8),

    pub fn deinit(templates: *Templates) void {
        templates.zig_lib_directory.handle.close();
        templates.dir.close();
        templates.buffer.deinit();
        templates.* = undefined;
    }

    pub fn write(
        templates: *Templates,
        arena: mem.Allocator,
        out_dir: std.fs.Dir,
        root_name: []const u8,
        template_path: []const u8,
    ) !void {
        if (std.fs.path.dirname(template_path)) |dirname| {
            out_dir.makePath(dirname) catch |err| {
                fatal("unable to make path '{s}': {s}", .{ dirname, @errorName(err) });
            };
        }

        const max_bytes = 10 * 1024 * 1024;
        const contents = templates.dir.readFileAlloc(arena, template_path, max_bytes) catch |err| {
            fatal("unable to read template file '{s}': {s}", .{ template_path, @errorName(err) });
        };
        templates.buffer.clearRetainingCapacity();
        try templates.buffer.ensureUnusedCapacity(contents.len);
        for (contents) |c| {
            if (c == '$') {
                try templates.buffer.appendSlice(root_name);
            } else {
                try templates.buffer.append(c);
            }
        }

        return out_dir.writeFile2(.{
            .sub_path = template_path,
            .data = templates.buffer.items,
            .flags = .{ .exclusive = true },
        });
    }
};

pub fn findTemplates(gpa: mem.Allocator, arena: mem.Allocator) Templates {
    const self_exe_path = findZigExePath(arena) catch |err| {
        fatal("unable to find self exe path: {s}", .{@errorName(err)});
    };
    const zig_lib_directory = findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}", .{@errorName(err)});
    };

    const s = std.fs.path.sep_str;
    const template_sub_path = "init";
    const template_dir = zig_lib_directory.handle.openDir(template_sub_path, .{}) catch |err| {
        const path = zig_lib_directory.path orelse ".";
        fatal("unable to open zig project template directory '{s}{s}{s}': {s}", .{
            path, s, template_sub_path, @errorName(err),
        });
    };

    return .{
        .zig_lib_directory = zig_lib_directory,
        .dir = template_dir,
        .buffer = std.ArrayList(u8).init(gpa),
    };
}
