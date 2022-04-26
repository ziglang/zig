const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const Allocator = mem.Allocator;
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

    const glibc_abi = try glibc.loadMetaData(allocator, zig_lib_directory.handle);
    defer glibc_abi.destroy(allocator);

    var bw = io.bufferedWriter(stdout);
    const w = bw.writer();
    var jws = std.json.WriteStream(@TypeOf(w), 6).init(w);

    try jws.beginObject();

    try jws.objectField("arch");
    try jws.beginArray();
    for (meta.fieldNames(Target.Cpu.Arch)) |field| {
        try jws.arrayElem();
        try jws.emitString(field);
    }
    try jws.endArray();

    try jws.objectField("os");
    try jws.beginArray();
    for (meta.fieldNames(Target.Os.Tag)) |field| {
        try jws.arrayElem();
        try jws.emitString(field);
    }
    try jws.endArray();

    try jws.objectField("abi");
    try jws.beginArray();
    for (meta.fieldNames(Target.Abi)) |field| {
        try jws.arrayElem();
        try jws.emitString(field);
    }
    try jws.endArray();

    try jws.objectField("libc");
    try jws.beginArray();
    for (target.available_libcs) |libc| {
        const tmp = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
        });
        defer allocator.free(tmp);
        try jws.arrayElem();
        try jws.emitString(tmp);
    }
    try jws.endArray();

    try jws.objectField("glibc");
    try jws.beginArray();
    for (glibc_abi.all_versions) |ver| {
        try jws.arrayElem();

        const tmp = try std.fmt.allocPrint(allocator, "{}", .{ver});
        defer allocator.free(tmp);
        try jws.emitString(tmp);
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
            for (arch.allFeaturesList()) |feature, i| {
                if (model.features.isEnabled(@intCast(u8, i))) {
                    try jws.arrayElem();
                    try jws.emitString(feature.name);
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
            try jws.arrayElem();
            try jws.emitString(feature.name);
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
        try jws.emitString(triple);
    }
    {
        try jws.objectField("cpu");
        try jws.beginObject();
        try jws.objectField("arch");
        try jws.emitString(@tagName(native_target.cpu.arch));

        try jws.objectField("name");
        const cpu = native_target.cpu;
        try jws.emitString(cpu.model.name);

        {
            try jws.objectField("features");
            try jws.beginArray();
            for (native_target.cpu.arch.allFeaturesList()) |feature, i_usize| {
                const index = @intCast(Target.Cpu.Feature.Set.Index, i_usize);
                if (cpu.features.isEnabled(index)) {
                    try jws.arrayElem();
                    try jws.emitString(feature.name);
                }
            }
            try jws.endArray();
        }
        try jws.endObject();
    }
    try jws.objectField("os");
    try jws.emitString(@tagName(native_target.os.tag));
    try jws.objectField("abi");
    try jws.emitString(@tagName(native_target.abi));
    try jws.endObject();

    try jws.endObject();

    try w.writeByte('\n');
    return bw.flush();
}
