const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const Compilation = @import("Compilation.zig");
const Allocator = std.mem.Allocator;
const EnvVar = std.zig.EnvVar;
const fatal = std.process.fatal;

pub fn cmdEnv(
    arena: Allocator,
    args: []const []const u8,
    wasi_preopens: switch (builtin.target.os.tag) {
        .wasi => std.fs.wasi.Preopens,
        else => void,
    },
    stdout: std.fs.File.Writer,
) !void {
    const override_lib_dir: ?[]const u8 = try EnvVar.ZIG_LIB_DIR.get(arena);
    const override_global_cache_dir: ?[]const u8 = try EnvVar.ZIG_GLOBAL_CACHE_DIR.get(arena);

    const self_exe_path = switch (builtin.target.os.tag) {
        .wasi => args[0],
        else => std.fs.selfExePathAlloc(arena) catch |err| {
            fatal("unable to find zig self exe path: {s}", .{@errorName(err)});
        },
    };

    var dirs: Compilation.Directories = .init(
        arena,
        override_lib_dir,
        override_global_cache_dir,
        .global,
        if (builtin.target.os.tag == .wasi) wasi_preopens,
        if (builtin.target.os.tag != .wasi) self_exe_path,
    );
    defer dirs.deinit();

    const zig_lib_dir = dirs.zig_lib.path orelse "";
    const zig_std_dir = try dirs.zig_lib.join(arena, &.{"std"});
    const global_cache_dir = dirs.global_cache.path orelse "";

    const host = try std.zig.system.resolveTargetQuery(.{});
    const triple = try host.zigTriple(arena);

    var bw = std.io.bufferedWriter(stdout);
    const w = bw.writer();

    var jws = std.json.writeStream(w, .{ .whitespace = .indent_1 });

    try jws.beginObject();

    try jws.objectField("zig_exe");
    try jws.write(self_exe_path);

    try jws.objectField("lib_dir");
    try jws.write(zig_lib_dir);

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
