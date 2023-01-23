const std = @import("std");
const mem = std.mem;
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = @import("main.zig").fatal;

const Env = struct {
    name: []const u8,
    value: []const u8,
};

pub fn cmdEnv(gpa: Allocator, args: []const []const u8, stdout: std.fs.File.Writer) !void {
    const self_exe_path = try introspect.findZigExePath(gpa);
    defer gpa.free(self_exe_path);

    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(gpa, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer gpa.free(zig_lib_directory.path.?);
    defer zig_lib_directory.handle.close();

    const zig_std_dir = try std.fs.path.join(gpa, &[_][]const u8{ zig_lib_directory.path.?, "std" });
    defer gpa.free(zig_std_dir);

    const global_cache_dir = try introspect.resolveGlobalCacheDir(gpa);
    defer gpa.free(global_cache_dir);

    const info = try std.zig.system.NativeTargetInfo.detect(.{});
    const triple = try info.target.zigTriple(gpa);
    defer gpa.free(triple);

    const envars: []Env = &[_]Env{
        .{ .name = "zig_exe", .value = self_exe_path },
        .{ .name = "lib_dir", .value = zig_lib_directory.path.? },
        .{ .name = "std_dir", .value = zig_std_dir },
        .{ .name = "global_cache_dir", .value = global_cache_dir },
        .{ .name = "version", .value = build_options.version },
        .{ .name = "target", .value = triple },
    };

    var bw = std.io.bufferedWriter(stdout);
    const w = bw.writer();

    if (args.len > 0) {
        for (args) |name| {
            for (envars) |env| {
                if (mem.eql(u8, name, env.name)) {
                    try w.print("{s}\n", .{env.value});
                }
            }
        }
        try bw.flush();

        return;
    }

    for (envars) |env| {
        try w.print("{[name]s}=\"{[value]s}\"\n", env);
    }
    try bw.flush();
}
