const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const Compilation = @import("Compilation.zig");
const Allocator = std.mem.Allocator;
const EnvVar = std.zig.EnvVar;
const fatal = std.process.fatal;

pub fn cmdEnv(
    arena: Allocator,
    out: *std.Io.Writer,
    args: []const []const u8,
    wasi_preopens: switch (builtin.target.os.tag) {
        .wasi => std.fs.wasi.Preopens,
        else => void,
    },
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

    var serializer: std.zon.Serializer = .{ .writer = out };
    var root = try serializer.beginStruct(.{});

    try root.field("zig_exe", self_exe_path, .{});
    try root.field("lib_dir", zig_lib_dir, .{});
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
