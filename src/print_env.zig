const std = @import("std");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const Allocator = std.mem.Allocator;
const fatal = std.process.fatal;

const usage =
    \\Usage: zig env [options]
    \\
    \\Options:
    \\  -h, --help                Print this help and exit
    \\  --global-cache-dir [path] Override the global cache directory
    \\  --zig-lib-dir [path]      Override path to Zig installation lib directory
    \\
;

pub fn cmdEnv(arena: Allocator, args: []const []const u8, out: *std.Io.Writer) !void {
    var override_lib_dir: ?[]const u8 = null;
    var override_global_cache_dir: ?[]const u8 = null;

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.startsWith(u8, arg, "-")) {
                if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                    try std.fs.File.stdout().writeAll(usage);
                    return;
                } else if (std.mem.eql(u8, arg, "--zig-lib-dir")) {
                    if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                    i += 1;
                    override_lib_dir = args[i];
                    continue;
                } else if (std.mem.eql(u8, arg, "--global-cache-dir")) {
                    if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                    i += 1;
                    override_global_cache_dir = args[i];
                    continue;
                }
            }
            fatal("invalid argument '{s}'", .{arg});
        }
    }

    const cwd_path = try introspect.getResolvedCwd(arena);
    const self_exe_path = try std.fs.selfExePathAlloc(arena);

    const zig_lib_directory = override_lib_dir orelse blk: {
        var cache_dir = introspect.findZigLibDirFromSelfExe(arena, cwd_path, self_exe_path) catch |err| {
            fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
        };
        cache_dir.handle.close();
        break :blk cache_dir.path.?;
    };

    const zig_std_dir = try std.fs.path.join(arena, &[_][]const u8{ zig_lib_directory, "std" });

    const global_cache_dir = override_global_cache_dir orelse
        try introspect.resolveGlobalCacheDir(arena);

    const host = try std.zig.system.resolveTargetQuery(.{});
    const triple = try host.zigTriple(arena);

    var serializer: std.zon.Serializer = .{ .writer = out };
    var root = try serializer.beginStruct(.{});

    try root.field("zig_exe", self_exe_path, .{});
    try root.field("lib_dir", zig_lib_directory, .{});
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
