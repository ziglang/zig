const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = @import("main.zig").fatal;

pub fn cmdEnv(gpa: Allocator, args: []const []const u8, stdout: std.fs.File.Writer) !void {
    _ = args;
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

    var bw = std.io.bufferedWriter(stdout);
    const w = bw.writer();

    var jws = std.json.WriteStream(@TypeOf(w), 6).init(w);
    try jws.beginObject();

    try jws.objectField("zig_exe");
    try jws.emitString(self_exe_path);

    try jws.objectField("lib_dir");
    try jws.emitString(zig_lib_directory.path.?);

    try jws.objectField("std_dir");
    try jws.emitString(zig_std_dir);

    try jws.objectField("global_cache_dir");
    try jws.emitString(global_cache_dir);

    try jws.objectField("version");
    try jws.emitString(build_options.version);

    try jws.objectField("target");
    try jws.emitString(triple);

    try jws.endObject();
    try w.writeByte('\n');
    try bw.flush();
}
