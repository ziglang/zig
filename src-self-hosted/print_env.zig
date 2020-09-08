const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;

pub fn cmdEnv(gpa: *Allocator, args: []const []const u8, stdout: anytype) !void {
    const zig_lib_dir = introspect.resolveZigLibDir(gpa) catch |err| {
        std.debug.print("unable to find zig installation directory: {}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer gpa.free(zig_lib_dir);

    const zig_std_dir = try std.fs.path.join(gpa, &[_][]const u8{ zig_lib_dir, "std" });
    defer gpa.free(zig_std_dir);

    const global_cache_dir = try introspect.resolveGlobalCacheDir(gpa);
    defer gpa.free(global_cache_dir);

    var bos = std.io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();

    var jws = std.json.WriteStream(@TypeOf(bos_stream), 6).init(bos_stream);
    try jws.beginObject();

    try jws.objectField("lib_dir");
    try jws.emitString(zig_lib_dir);

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
