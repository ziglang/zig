const builtin = @import("builtin");
const std = @import("std");
const process = std.process;
const mem = std.mem;
const unicode = std.unicode;
const io = std.io;
const fs = std.fs;
const os = std.os;
const json = std.json;
const StringifyOptions = json.StringifyOptions;
const Allocator = std.mem.Allocator;
const introspect = @import("introspect.zig");

const usage_info =
    \\Usage: zig info [options]
    \\
    \\   Outputs path to zig lib dir, std dir and the global cache dir.
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\   --format [text|json]   Choose output format (defaults to text)
    \\
;

pub const CompilerInfo = struct {
    // TODO: port compiler id hash from cpp
    // /// Compiler id hash
    // id: []const u8,

    // /// Compiler version
    // version: []const u8,
    /// Path to lib/
    lib_dir: []const u8,

    /// Path to lib/zig/std
    std_dir: []const u8,

    /// Path to the global cache dir
    global_cache_dir: []const u8,

    const CompilerType = enum {
        Stage1,
        SelfHosted,
    };

    pub fn getVersionString() []const u8 {
        // TODO: get this from build.zig somehow
        return "0.6.0";
    }

    pub fn getCacheDir(allocator: *Allocator, compiler_type: CompilerType) ![]u8 {
        const global_cache_dir = try getAppCacheDir(allocator, "zig");
        defer allocator.free(global_cache_dir);

        const postfix = switch (compiler_type) {
            .SelfHosted => "self_hosted",
            .Stage1 => "stage1",
        };
        return try fs.path.join(allocator, &[_][]const u8{ global_cache_dir, postfix }); // stage1 compiler uses $cache_dir/zig/stage1
    }

    // TODO: add CacheType argument here to make it return correct cache dir for stage1
    pub fn init(allocator: *Allocator, compiler_type: CompilerType) !CompilerInfo {
        const zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        errdefer allocator.free(zig_lib_dir);

        const zig_std_dir = try fs.path.join(allocator, &[_][]const u8{ zig_lib_dir, "std" });
        errdefer allocator.free(zig_std_dir);

        const cache_dir = try CompilerInfo.getCacheDir(allocator, compiler_type);
        errdefer allocator.free(cache_dir);

        return CompilerInfo{
            .lib_dir = zig_lib_dir,
            .std_dir = zig_std_dir,
            .global_cache_dir = cache_dir,
        };
    }

    pub fn toString(self: *CompilerInfo, out_stream: var) !void {
        inline for (@typeInfo(CompilerInfo).Struct.fields) |field| {
            try std.fmt.format(out_stream, "{: <16}\t{: <}\n", .{ field.name, @field(self, field.name) });
        }
    }

    pub fn deinit(self: *CompilerInfo, allocator: *Allocator) void {
        allocator.free(self.lib_dir);
        allocator.free(self.std_dir);
        allocator.free(self.global_cache_dir);
    }
};

pub fn cmdInfo(allocator: *Allocator, cmd_args: []const []const u8, compiler_type: CompilerInfo.CompilerType, stdout: var) !void {
    var info = try CompilerInfo.init(allocator, compiler_type);
    defer info.deinit(allocator);

    var bos = io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();

    var json_format = false;

    var i: usize = 0;
    while (i < cmd_args.len) : (i += 1) {
        const arg = cmd_args[i];
        if (mem.eql(u8, arg, "--format")) {
            if (cmd_args.len <= i + 1) {
                std.debug.warn("expected [text|json] after --format\n", .{});
                process.exit(1);
            }
            const format = cmd_args[i + 1];
            i += 1;
            if (mem.eql(u8, format, "text")) {
                json_format = false;
            } else if (mem.eql(u8, format, "json")) {
                json_format = true;
            } else {
                std.debug.warn("expected [text|json] after --format, found '{}'\n", .{format});
                process.exit(1);
            }
        } else if (mem.eql(u8, arg, "--help")) {
            try stdout.writeAll(usage_info);
            return;
        } else {
            std.debug.warn("unrecognized parameter: '{}'\n", .{arg});
            process.exit(1);
        }
    }

    if (json_format) {
        try json.stringify(info, StringifyOptions{
            .whitespace = StringifyOptions.Whitespace{ .indent = .{ .Space = 2 } },
        }, bos_stream);
        try bos_stream.writeByte('\n');
    } else {
        try info.toString(bos_stream);
    }

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
                        error.UnexpectedSecondSurrogateHalf => return error.AppCacheDirUnavailable,
                        error.ExpectedSecondSurrogateHalf => return error.AppCacheDirUnavailable,
                        error.DanglingSurrogateHalf => return error.AppCacheDirUnavailable,
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
