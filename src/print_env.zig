const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = @import("main.zig").fatal;

pub fn cmdEnv(gpa: *Allocator, args: []const []const u8, stdout: anytype) !void {
    const self_exe_path = try std.fs.selfExePathAlloc(gpa);
    defer gpa.free(self_exe_path);

    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(gpa, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {}\n", .{@errorName(err)});
    };
    defer gpa.free(zig_lib_directory.path.?);
    defer zig_lib_directory.handle.close();

    const zig_std_dir = try std.fs.path.join(gpa, &[_][]const u8{ zig_lib_directory.path.?, "std" });
    defer gpa.free(zig_std_dir);

    const global_cache_dir = try introspect.resolveGlobalCacheDir(gpa);
    defer gpa.free(global_cache_dir);

    var bos = std.io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();

    var jws = std.json.WriteStream(@TypeOf(bos_stream), 6).init(bos_stream);
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

    try jws.endObject();
    try bos_stream.writeByte('\n');
    try bos.flush();
}
