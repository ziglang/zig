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
    var jws_stack = std.json.WriteStreamFixedStack(6){};
    var jws = jws_stack.init(w);

    try jws.beginObject();

    try jws.write("arch");
    try jws.beginArray();
    for (meta.fieldNames(Target.Cpu.Arch)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.write("os");
    try jws.beginArray();
    for (meta.fieldNames(Target.Os.Tag)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.write("abi");
    try jws.beginArray();
    for (meta.fieldNames(Target.Abi)) |field| {
        try jws.write(field);
    }
    try jws.endArray();

    try jws.write("libc");
    try jws.beginArray();
    for (target.available_libcs) |libc| {
        const tmp = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
        });
        defer allocator.free(tmp);
        try jws.write(tmp);
    }
    try jws.endArray();

    try jws.write("glibc");
    try jws.beginArray();
    for (glibc_abi.all_versions) |ver| {
        const tmp = try std.fmt.allocPrint(allocator, "{}", .{ver});
        defer allocator.free(tmp);
        try jws.write(tmp);
    }
    try jws.endArray();

    try jws.write("cpus");
    try jws.beginObject();
    for (meta.tags(Target.Cpu.Arch)) |arch| {
        try jws.write(@tagName(arch));
        try jws.beginObject();
        for (arch.allCpuModels()) |model| {
            try jws.write(model.name);
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

    try jws.write("cpuFeatures");
    try jws.beginObject();
    for (meta.tags(Target.Cpu.Arch)) |arch| {
        try jws.write(@tagName(arch));
        try jws.beginArray();
        for (arch.allFeaturesList()) |feature| {
            try jws.write(feature.name);
        }
        try jws.endArray();
    }
    try jws.endObject();

    try jws.write("native");
    try jws.beginObject();
    {
        const triple = try native_target.zigTriple(allocator);
        defer allocator.free(triple);
        try jws.write("triple");
        try jws.write(triple);
    }
    {
        try jws.write("cpu");
        try jws.beginObject();
        try jws.write("arch");
        try jws.write(@tagName(native_target.cpu.arch));

        try jws.write("name");
        const cpu = native_target.cpu;
        try jws.write(cpu.model.name);

        {
            try jws.write("features");
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
    try jws.write("os");
    try jws.write(@tagName(native_target.os.tag));
    try jws.write("abi");
    try jws.write(@tagName(native_target.abi));
    try jws.endObject();

    try jws.endObject();

    try w.writeByte('\n');
    return bw.flush();
}
