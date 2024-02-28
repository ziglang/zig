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
    var jws = std.json.writeStream(w, .{ .whitespace = .indent_1 });

    try jws.beginObject();

    try jws.objectField("arch");
    try jws.beginArray();
    for (meta.fieldNames(Target.Cpu.Arch)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.objectField("os");
    try jws.beginArray();
    for (meta.fieldNames(Target.Os.Tag)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.objectField("abi");
    try jws.beginArray();
    for (meta.fieldNames(Target.Abi)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.objectField("libc");
    try jws.beginArray();
    for (std.zig.target.available_libcs) |libc| {
        const tmp = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
        });
        defer allocator.free(tmp);
        try jws.write(tmp);
    }
    try jws.endArray();

    try jws.objectField("glibc");
    try jws.beginArray();
    for (glibc_abi.all_versions) |ver| {
        const tmp = try std.fmt.allocPrint(allocator, "{}", .{ver});
        defer allocator.free(tmp);
        try jws.write(tmp);
    }
    try jws.endArray();

    try jws.objectField("cpus");
    try jws.beginObject();
    for (meta.tags(Target.Cpu.Arch)) |arch| {
        try jws.objectField(@tagName(arch));
        try jws.beginObject();
        for (arch.allCpuModels()) |model| {
            try jws.objectField(model.name);
            try jws.beginArray();
            for (arch.allFeaturesList(), 0..) |feature, i_usize| {
                const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                if (model.features.isEnabled(index)) {
                    try jws.write(feature.name);
                }
            }
            try jws.endArray();
        }
        try jws.endObject();
    }
    try jws.endObject();

    try jws.objectField("cpuFeatures");
    try jws.beginObject();
    for (meta.tags(Target.Cpu.Arch)) |arch| {
        try jws.objectField(@tagName(arch));
        try jws.beginArray();
        for (arch.allFeaturesList()) |feature| {
            try jws.write(feature.name);
        }
        try jws.endArray();
    }
    try jws.endObject();

    try jws.objectField("native");
    try jws.beginObject();
    {
        const triple = try native_target.zigTriple(allocator);
        defer allocator.free(triple);
        try jws.objectField("triple");
        try jws.write(triple);
    }
    {
        try jws.objectField("cpu");
        try jws.beginObject();
        try jws.objectField("arch");
        try jws.write(@tagName(native_target.cpu.arch));

        try jws.objectField("name");
        const cpu = native_target.cpu;
        try jws.write(cpu.model.name);

        {
            try jws.objectField("features");
            try jws.beginArray();
            for (native_target.cpu.arch.allFeaturesList(), 0..) |feature, i_usize| {
                const index = @as(Target.Cpu.Feature.Set.Index, @intCast(i_usize));
                if (cpu.features.isEnabled(index)) {
                    try jws.write(feature.name);
                }
            }
            try jws.endArray();
        }
        try jws.endObject();
    }
    try jws.objectField("os");
    try jws.write(@tagName(native_target.os.tag));
    try jws.objectField("abi");
    try jws.write(@tagName(native_target.abi));
    try jws.endObject();

    try jws.endObject();

    try w.writeByte('\n');
    return bw.flush();
}
