const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const target = @import("target.zig");
const assert = std.debug.assert;
const glibc = @import("libs/glibc.zig");
const introspect = @import("introspect.zig");
const Writer = std.io.Writer;

pub fn cmdTargets(arena: Allocator, args: []const []const u8) !void {
    _ = args;
    const host = std.zig.resolveTargetQueryOrFatal(.{});
    var buffer: [1024]u8 = undefined;
    var bw = fs.File.stdout().writer().buffered(&buffer);
    try print(arena, &bw, host);
    try bw.flush();
}

fn print(arena: Allocator, output: *Writer, host: *const Target) Writer.Error!void {
    var zig_lib_directory = introspect.findZigLibDir(arena) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const abilists_contents = zig_lib_directory.handle.readFileAlloc(
        glibc.abilists_path,
        arena,
        .limited(glibc.abilists_max_size),
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => fatal("unable to read " ++ glibc.abilists_path ++ ": {s}", .{@errorName(err)}),
    };

    const glibc_abi = try glibc.loadMetaData(arena, abilists_contents);

    var sz: std.zon.stringify.Serializer = .{ .writer = output };

    {
        var root_obj = try sz.beginStruct(.{});

        try root_obj.field("arch", meta.fieldNames(Target.Cpu.Arch), .{});
        try root_obj.field("os", meta.fieldNames(Target.Os.Tag), .{});
        try root_obj.field("abi", meta.fieldNames(Target.Abi), .{});

        {
            var libc_obj = try root_obj.beginTupleField("libc", .{});
            for (std.zig.target.available_libcs) |libc| {
                const tmp = try std.fmt.allocPrint(arena, "{s}-{s}-{s}", .{
                    @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
                });
                try libc_obj.field(tmp, .{});
            }
            try libc_obj.end();
        }

        {
            var glibc_obj = try root_obj.beginTupleField("glibc", .{});
            for (glibc_abi.all_versions) |ver| {
                const tmp = try std.fmt.allocPrint(arena, "{f}", .{ver});
                try glibc_obj.field(tmp, .{});
            }
            try glibc_obj.end();
        }

        {
            var cpus_obj = try root_obj.beginStructField("cpus", .{});
            for (meta.tags(Target.Cpu.Arch)) |arch| {
                var arch_obj = try cpus_obj.beginStructField(@tagName(arch), .{});
                for (arch.allCpuModels()) |model| {
                    var features = try arch_obj.beginTupleField(model.name, .{});
                    for (arch.allFeaturesList(), 0..) |feature, i_usize| {
                        const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                        if (model.features.isEnabled(index)) {
                            try features.field(feature.name, .{});
                        }
                    }
                    try features.end();
                }
                try arch_obj.end();
            }
            try cpus_obj.end();
        }

        {
            var cpu_features_obj = try root_obj.beginStructField("cpu_features", .{});
            for (meta.tags(Target.Cpu.Arch)) |arch| {
                var arch_features = try cpu_features_obj.beginTupleField(@tagName(arch), .{});
                for (arch.allFeaturesList()) |feature| {
                    try arch_features.field(feature.name, .{});
                }
                try arch_features.end();
            }
            try cpu_features_obj.end();
        }

        {
            var native_obj = try root_obj.beginStructField("native", .{});
            {
                const triple = try host.zigTriple(arena);
                try native_obj.field("triple", triple, .{});
            }
            {
                var cpu_obj = try native_obj.beginStructField("cpu", .{});
                try cpu_obj.field("arch", @tagName(host.cpu.arch), .{});

                try cpu_obj.field("name", host.cpu.model.name, .{});

                {
                    var features = try native_obj.beginTupleField("features", .{});
                    for (host.cpu.arch.allFeaturesList(), 0..) |feature, i_usize| {
                        const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                        if (host.cpu.features.isEnabled(index)) {
                            try features.field(feature.name, .{});
                        }
                    }
                    try features.end();
                }
                try cpu_obj.end();
            }

            try native_obj.field("os", @tagName(host.os.tag), .{});
            try native_obj.field("abi", @tagName(host.abi), .{});
            try native_obj.end();
        }

        try root_obj.end();
    }

    try output.writeByte('\n');
}
