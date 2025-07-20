const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = std.process.fatal;

pub fn cmdEnv(arena: Allocator, out: *std.Io.Writer) !void {
    const cwd_path = try introspect.getResolvedCwd(arena);
    const self_exe_path = try std.fs.selfExePathAlloc(arena);

    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(arena, cwd_path, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const zig_std_dir = try std.fs.path.join(arena, &[_][]const u8{ zig_lib_directory.path.?, "std" });

    const global_cache_dir = try introspect.resolveGlobalCacheDir(arena);

    const host = try std.zig.system.resolveTargetQuery(.{});
    const triple = try host.zigTriple(arena);

    var serializer: std.zon.Serializer = .{ .writer = out };
    var root = try serializer.beginStruct(.{});

    try root.field("zig_exe", self_exe_path, .{});
    try root.field("lib_dir", zig_lib_directory.path.?, .{});
    try root.field("std_dir", zig_std_dir, .{});
    try root.field("global_cache_dir", global_cache_dir, .{});
    try root.field("version", build_options.version, .{});
    try root.field("target", triple, .{});
    var env = try root.beginStructField("env", .{});
    inline for (@typeInfo(std.zig.EnvVar).@"enum".fields) |field| {
        try env.field(field.name, try @field(std.zig.EnvVar, field.name).get(arena), .{});
    }
    try env.end();
    try root.end();

    try out.writeByte('\n');
}
