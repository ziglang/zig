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

    const host = try std.zig.system.resolveTargetQuery(.{});
    const triple = try host.zigTriple(arena);

    var bw = std.io.bufferedWriter(stdout);
    const w = bw.writer();

    var jws = std.json.writeStream(w, .{ .whitespace = .indent_1 });

    try jws.beginObject();

    try jws.objectField("zig_exe");
    try jws.write(self_exe_path);

    try jws.objectField("lib_dir");
    try jws.write(zig_lib_directory.path.?);

    try jws.objectField("std_dir");
    try jws.write(zig_std_dir);

    try jws.objectField("global_cache_dir");
    try jws.write(global_cache_dir);

    try jws.objectField("version");
    try jws.write(build_options.version);

    try jws.objectField("target");
    try jws.write(triple);

    try jws.objectField("env");
    try jws.beginObject();
    inline for (@typeInfo(std.zig.EnvVar).@"enum".fields) |field| {
        try jws.objectField(field.name);
        try jws.write(try @field(std.zig.EnvVar, field.name).get(arena));
    }
    try jws.endObject();

    try jws.endObject();
    try w.writeByte('\n');

    try bw.flush();
}
