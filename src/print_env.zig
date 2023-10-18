const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = @import("main.zig").fatal;

pub fn cmdEnv(arena: Allocator, args: []const []const u8, stdout: std.fs.File.Writer) !void {
    _ = args;
    const self_exe_path = try introspect.findZigExePath(arena);

    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const zig_std_dir = try std.fs.path.join(arena, &[_][]const u8{ zig_lib_directory.path.?, "std" });

    const global_cache_dir = try introspect.resolveGlobalCacheDir(arena);

    const info = try std.zig.system.NativeTargetInfo.detect(.{});
    const triple = try info.target.zigTriple(arena);

    var bw = std.io.bufferedWriter(stdout);
    const w = bw.writer();

    try w.print(
        \\zig_exe={s}
        \\lib_dir={s}
        \\std_dir={s}
        \\global_cache_dir={s}
        \\version={s}
        \\target={s}
        \\
    , .{
        self_exe_path,
        zig_lib_directory.path.?,
        zig_std_dir,
        global_cache_dir,
        build_options.version,
        triple,
    });

    inline for (@typeInfo(introspect.EnvVar).Enum.fields) |field| {
        if (try @field(introspect.EnvVar, field.name).get(arena)) |value| {
            try w.print("{s}={s}\n", .{ field.name, value });
        } else {
            try w.print("{s}\n", .{field.name});
        }
    }

    try bw.flush();
}
