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

pub fn cmdTargets(
    allocator: Allocator,
    args: []const []const u8,
    out: *std.Io.Writer,
    native_target: *const Target,
) !void {
    _ = args;
    var zig_lib_directory = introspect.findZigLibDir(allocator) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();
    defer allocator.free(zig_lib_directory.path.?);

    const abilists_contents = zig_lib_directory.handle.readFileAlloc(
        allocator,
        glibc.abilists_path,
        glibc.abilists_max_size,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => fatal("unable to read " ++ glibc.abilists_path ++ ": {s}", .{@errorName(err)}),
    };
    defer allocator.free(abilists_contents);

    const glibc_abi = try glibc.loadMetaData(allocator, abilists_contents);
    defer glibc_abi.destroy(allocator);

    var serializer: std.zon.Serializer = .{ .writer = out };

    {
        var root_obj = try serializer.beginStruct(.{});

        try root_obj.field("arch", meta.fieldNames(Target.Cpu.Arch), .{});
        try root_obj.field("os", meta.fieldNames(Target.Os.Tag), .{});
        try root_obj.field("abi", meta.fieldNames(Target.Abi), .{});

        {
            var libc_obj = try root_obj.beginTupleField("libc", .{});
            for (std.zig.target.available_libcs) |libc| {
                const tmp = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
                    @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
                });
                defer allocator.free(tmp);
                try libc_obj.field(tmp, .{});
            }
            try libc_obj.end();
        }

        {
            var glibc_obj = try root_obj.beginTupleField("glibc", .{});
            for (glibc_abi.all_versions) |ver| {
                const tmp = try std.fmt.allocPrint(allocator, "{f}", .{ver});
                defer allocator.free(tmp);
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
                const triple = try native_target.zigTriple(allocator);
                defer allocator.free(triple);
                try native_obj.field("triple", triple, .{});
            }
            {
                var cpu_obj = try native_obj.beginStructField("cpu", .{});
                try cpu_obj.field("arch", @tagName(native_target.cpu.arch), .{});

                try cpu_obj.field("name", native_target.cpu.model.name, .{});

                {
                    var features = try native_obj.beginTupleField("features", .{});
                    for (native_target.cpu.arch.allFeaturesList(), 0..) |feature, i_usize| {
                        const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                        if (native_target.cpu.features.isEnabled(index)) {
                            try features.field(feature.name, .{});
                        }
                    }
                    try features.end();
                }
                try cpu_obj.end();
            }

            try native_obj.field("os", @tagName(native_target.os.tag), .{});
            try native_obj.field("abi", @tagName(native_target.abi), .{});
            try native_obj.end();
        }

        try root_obj.end();
    }

    try out.writeByte('\n');
}
