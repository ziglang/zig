const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const fs = std.fs;
const os = std.os;
const json = std.json;
const StringifyOptions = json.StringifyOptions;
const Allocator = std.mem.Allocator;
const introspect = @import("introspect.zig");

pub const CompilerInfo = struct {
    /// Compiler id hash
    id: []const u8,

    /// Compiler version
    version: []const u8,

    /// Path to lib/
    lib_dir: []const u8,

    /// Path to lib/zig/std
    std_dir: []const u8,

    /// Path to the global cache dir
    global_cache_dir: []const u8,

    pub fn init(allocator: *Allocator) !CompilerInfo {
        const zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        const zig_std_dir = try fs.path.join(allocator, &[_][]const u8{zig_lib_dir, "std"});
        const global_cache_dir = try getAppCacheDir(allocator, "zig");
        defer allocator.free(global_cache_dir);
        const self_hosted_cache_dir = try fs.path.join(allocator, &[_][]const u8{global_cache_dir, "self_hosted"}); // stage1 compiler uses $cache_dir/zig/stage1
        return CompilerInfo{
            .id = "test",
            .version = "0.7.0",
            .lib_dir = zig_lib_dir,
            .std_dir = zig_std_dir,
            .global_cache_dir = self_hosted_cache_dir,
        };
    }

    pub fn deinit(self: *CompilerInfo, allocator: *Allocator) void {
        allocator.free(self.lib_dir);
        allocator.free(self.std_dir);
        allocator.free(self.global_cache_dir);
    }
};

pub fn cmdInfo(allocator: *Allocator, stdout: var) !void {
    var info = try CompilerInfo.init(allocator);
    defer info.deinit(allocator);

    var bos = io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();

    const stringifyOptions = StringifyOptions{
        .whitespace = StringifyOptions.Whitespace{
            // Match indentation of zig targets
            .indent = .{ .Space = 2 }
        },
    };
    try json.stringify(info, stringifyOptions, bos_stream);

    try bos_stream.writeByte('\n');
    try bos.flush();
}

pub const GetAppCacheDirError = error{
    OutOfMemory,
    AppCacheDirUnavailable,
};

// Copied from fs.getAppDataDir, but changed it to return .cache/ dir on linux.
// This is the same behavior as the current zig compiler global cache resolution.
fn getAppCacheDir(allocator: *Allocator, appname: []const u8) GetAppCacheDirError![]u8 {
    switch (builtin.os.tag) {
        .windows => {
            var dir_path_ptr: [*:0]u16 = undefined;
            switch (os.windows.shell32.SHGetKnownFolderPath(
                &os.windows.FOLDERID_LocalAppData,
                os.windows.KF_FLAG_CREATE,
                null,
                &dir_path_ptr,
            )) {
                os.windows.S_OK => {
                    defer os.windows.ole32.CoTaskMemFree(@ptrCast(*c_void, dir_path_ptr));
                    const global_dir = unicode.utf16leToUtf8Alloc(allocator, mem.spanZ(dir_path_ptr)) catch |err| switch (err) {
                        error.UnexpectedSecondSurrogateHalf => return error.AppDataDirUnavailable,
                        error.ExpectedSecondSurrogateHalf => return error.AppDataDirUnavailable,
                        error.DanglingSurrogateHalf => return error.AppDataDirUnavailable,
                        error.OutOfMemory => return error.OutOfMemory,
                    };
                    defer allocator.free(global_dir);
                    return fs.path.join(allocator, &[_][]const u8{ global_dir, appname });
                },
                os.windows.E_OUTOFMEMORY => return error.OutOfMemory,
                else => return error.AppCacheDirUnavailable,
            }
        },
        .macosx => {
            const home_dir = os.getenv("HOME") orelse {
                // TODO look in /etc/passwd
                return error.AppCacheDirUnavailable;
            };
            return fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Application Support", appname });
        },
        .linux, .freebsd, .netbsd, .dragonfly => {
            if (os.getenv("XDG_CACHE_HOME")) |cache_home| {
                return fs.path.join(allocator, &[_][]const u8{ cache_home, appname });
            }

            const home_dir = os.getenv("HOME") orelse {
                return error.AppCacheDirUnavailable;
            };
            return fs.path.join(allocator, &[_][]const u8{ home_dir, ".cache", appname });
        },
        else => @compileError("Unsupported OS"),
    }
}
