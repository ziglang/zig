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

pub fn cmdTargets(arena: Allocator, args: []const []const u8) anyerror!void {
    _ = args;
    const host = std.zig.resolveTargetQueryOrFatal(.{});
    var buffer: [1024]u8 = undefined;
    var bw: std.io.BufferedWriter = .{
        .unbuffered_writer = io.getStdOut().writer(),
        .buffer = &buffer,
    };
    try print(arena, &bw, host);
    try bw.flush();
}

fn print(arena: Allocator, output: *std.io.BufferedWriter, host: Target) anyerror!void {
    var zig_lib_directory = introspect.findZigLibDir(arena) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const abilists_contents = zig_lib_directory.handle.readFileAlloc(
        arena,
        glibc.abilists_path,
        glibc.abilists_max_size,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => fatal("unable to read " ++ glibc.abilists_path ++ ": {s}", .{@errorName(err)}),
    };

    const glibc_abi = try glibc.loadMetaData(arena, abilists_contents);

    var jws = std.json.writeStream(output, .{ .whitespace = .indent_1 });

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
        const tmp = try std.fmt.allocPrint(arena, "{s}-{s}-{s}", .{
            @tagName(libc.arch), @tagName(libc.os), @tagName(libc.abi),
        });
        try jws.write(tmp);
    }
    try jws.endArray();

    try jws.objectField("glibc");
    try jws.beginArray();
    for (glibc_abi.all_versions) |ver| {
        const tmp = try std.fmt.allocPrint(arena, "{}", .{ver});
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
        const triple = try host.zigTriple(arena);
        try jws.objectField("triple");
        try jws.write(triple);
    }
    {
        try jws.objectField("cpu");
        try jws.beginObject();
        try jws.objectField("arch");
        try jws.write(@tagName(host.cpu.arch));

        try jws.objectField("name");
        const cpu = host.cpu;
        try jws.write(cpu.model.name);

        {
            try jws.objectField("features");
            try jws.beginArray();
            for (host.cpu.arch.allFeaturesList(), 0..) |feature, i_usize| {
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
    try jws.write(@tagName(host.os.tag));
    try jws.objectField("abi");
    try jws.write(@tagName(host.abi));
    try jws.endObject();

    try jws.endObject();

    try output.writeByte('\n');
}
