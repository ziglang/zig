const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const target = @import("target.zig");
const assert = std.debug.assert;
const glibc = @import("glibc.zig");
const introspect = @import("introspect.zig");
const fatal = @import("main.zig").fatal;

pub fn cmdTargets(
    allocator: Allocator,
    args: []const []const u8,
    /// Output stream
    stdout: anytype,
    native_target: Target,
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

    var bw = io.bufferedWriter(stdout);
    const w = bw.writer();
    var sz = std.zon.stringify.serializer(w, .{});

    {
        var root_obj = try sz.startStruct(.{});

        try root_obj.field("arch", meta.fieldNames(Target.Cpu.Arch), .{});
        try root_obj.field("os", meta.fieldNames(Target.Os.Tag), .{});
        try root_obj.field("abi", meta.fieldNames(Target.Abi), .{});

        {
            try root_obj.fieldPrefix("libc");
            var libc_obj = try sz.startTuple(.{});
            for (std.zig.target.available_libcs) |libc| {
                const tmp = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
                    @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
                });
                defer allocator.free(tmp);
                try libc_obj.field(tmp, .{});
            }
            try libc_obj.finish();
        }

        {
            try root_obj.fieldPrefix("glibc");
            var glibc_obj = try sz.startTuple(.{});
            for (glibc_abi.all_versions) |ver| {
                const tmp = try std.fmt.allocPrint(allocator, "{}", .{ver});
                defer allocator.free(tmp);
                try glibc_obj.field(tmp, .{});
            }
            try glibc_obj.finish();
        }

        {
            try root_obj.fieldPrefix("cpus");
            var cpus_obj = try sz.startStruct(.{});
            for (meta.tags(Target.Cpu.Arch)) |arch| {
                try cpus_obj.fieldPrefix(@tagName(arch));
                var arch_obj = try sz.startStruct(.{});
                for (arch.allCpuModels()) |model| {
                    try arch_obj.fieldPrefix(model.name);
                    var features = try sz.startTuple(.{});
                    for (arch.allFeaturesList(), 0..) |feature, i_usize| {
                        const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                        if (model.features.isEnabled(index)) {
                            try features.field(feature.name, .{});
                        }
                    }
                    try features.finish();
                }
                try arch_obj.finish();
            }
            try cpus_obj.finish();
        }

        {
            try root_obj.fieldPrefix("cpuFeatures");
            var cpu_features_obj = try sz.startStruct(.{});
            for (meta.tags(Target.Cpu.Arch)) |arch| {
                try cpu_features_obj.fieldPrefix(@tagName(arch));
                var arch_features = try sz.startTuple(.{});
                for (arch.allFeaturesList()) |feature| {
                    try arch_features.field(feature.name, .{});
                }
                try arch_features.finish();
            }
            try cpu_features_obj.finish();
        }

        {
            try root_obj.fieldPrefix("native");
            var native_obj = try sz.startStruct(.{});
            {
                const triple = try native_target.zigTriple(allocator);
                defer allocator.free(triple);
                try native_obj.field("triple", triple, .{});
            }
            {
                try native_obj.fieldPrefix("cpu");
                var cpu_obj = try sz.startStruct(.{});
                try cpu_obj.field("arch", native_target.cpu.arch, .{});

                try cpu_obj.field("name", native_target.cpu.model.name, .{});

                {
                    try native_obj.fieldPrefix("features");
                    var features = try sz.startTuple(.{});
                    for (native_target.cpu.arch.allFeaturesList(), 0..) |feature, i_usize| {
                        const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                        if (native_target.cpu.features.isEnabled(index)) {
                            try features.field(feature.name, .{});
                        }
                    }
                    try features.finish();
                }
                try cpu_obj.finish();
            }

            try native_obj.field("os", native_target.os.tag, .{});
            try native_obj.field("abi", native_target.abi, .{});
            try native_obj.finish();
        }

        try root_obj.finish();
    }

    try w.writeByte('\n');
    return bw.flush();
}
