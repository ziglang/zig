const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;
const assert = std.debug.assert;

const introspect = @import("introspect.zig");

// TODO this is hard-coded until self-hosted gains this information canonically
const available_libcs = [_][]const u8{
    "aarch64_be-linux-gnu",
    "aarch64_be-linux-musl",
    "aarch64_be-windows-gnu",
    "aarch64-linux-gnu",
    "aarch64-linux-musl",
    "aarch64-windows-gnu",
    "armeb-linux-gnueabi",
    "armeb-linux-gnueabihf",
    "armeb-linux-musleabi",
    "armeb-linux-musleabihf",
    "armeb-windows-gnu",
    "arm-linux-gnueabi",
    "arm-linux-gnueabihf",
    "arm-linux-musleabi",
    "arm-linux-musleabihf",
    "arm-windows-gnu",
    "i386-linux-gnu",
    "i386-linux-musl",
    "i386-windows-gnu",
    "mips64el-linux-gnuabi64",
    "mips64el-linux-gnuabin32",
    "mips64el-linux-musl",
    "mips64-linux-gnuabi64",
    "mips64-linux-gnuabin32",
    "mips64-linux-musl",
    "mipsel-linux-gnu",
    "mipsel-linux-musl",
    "mips-linux-gnu",
    "mips-linux-musl",
    "powerpc64le-linux-gnu",
    "powerpc64le-linux-musl",
    "powerpc64-linux-gnu",
    "powerpc64-linux-musl",
    "powerpc-linux-gnu",
    "powerpc-linux-musl",
    "riscv64-linux-gnu",
    "riscv64-linux-musl",
    "s390x-linux-gnu",
    "s390x-linux-musl",
    "sparc-linux-gnu",
    "sparcv9-linux-gnu",
    "wasm32-freestanding-musl",
    "x86_64-linux-gnu",
    "x86_64-linux-gnux32",
    "x86_64-linux-musl",
    "x86_64-windows-gnu",
};

pub fn cmdTargets(
    allocator: *Allocator,
    args: []const []const u8,
    /// Output stream
    stdout: anytype,
    native_target: Target,
) !void {
    const available_glibcs = blk: {
        const zig_lib_dir = introspect.resolveZigLibDir(allocator) catch |err| {
            std.debug.print("unable to find zig installation directory: {}\n", .{@errorName(err)});
            std.process.exit(1);
        };
        defer allocator.free(zig_lib_dir);

        var dir = try std.fs.cwd().openDir(zig_lib_dir, .{});
        defer dir.close();

        const vers_txt = try dir.readFileAlloc(allocator, "libc" ++ std.fs.path.sep_str ++ "glibc" ++ std.fs.path.sep_str ++ "vers.txt", 10 * 1024);
        defer allocator.free(vers_txt);

        var list = std.ArrayList(std.builtin.Version).init(allocator);
        defer list.deinit();

        var it = mem.tokenize(vers_txt, "\r\n");
        while (it.next()) |line| {
            const prefix = "GLIBC_";
            assert(mem.startsWith(u8, line, prefix));
            const adjusted_line = line[prefix.len..];
            const ver = try std.builtin.Version.parse(adjusted_line);
            try list.append(ver);
        }
        break :blk list.toOwnedSlice();
    };
    defer allocator.free(available_glibcs);

    var bos = io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();
    var jws = std.json.WriteStream(@TypeOf(bos_stream), 6).init(bos_stream);

    try jws.beginObject();

    try jws.objectField("arch");
    try jws.beginArray();
    {
        inline for (@typeInfo(Target.Cpu.Arch).Enum.fields) |field| {
            try jws.arrayElem();
            try jws.emitString(field.name);
        }
    }
    try jws.endArray();

    try jws.objectField("os");
    try jws.beginArray();
    inline for (@typeInfo(Target.Os.Tag).Enum.fields) |field| {
        try jws.arrayElem();
        try jws.emitString(field.name);
    }
    try jws.endArray();

    try jws.objectField("abi");
    try jws.beginArray();
    inline for (@typeInfo(Target.Abi).Enum.fields) |field| {
        try jws.arrayElem();
        try jws.emitString(field.name);
    }
    try jws.endArray();

    try jws.objectField("libc");
    try jws.beginArray();
    for (available_libcs) |libc| {
        try jws.arrayElem();
        try jws.emitString(libc);
    }
    try jws.endArray();

    try jws.objectField("glibc");
    try jws.beginArray();
    for (available_glibcs) |glibc| {
        try jws.arrayElem();

        const tmp = try std.fmt.allocPrint(allocator, "{}", .{glibc});
        defer allocator.free(tmp);
        try jws.emitString(tmp);
    }
    try jws.endArray();

    try jws.objectField("cpus");
    try jws.beginObject();
    inline for (@typeInfo(Target.Cpu.Arch).Enum.fields) |field| {
        try jws.objectField(field.name);
        try jws.beginObject();
        const arch = @field(Target.Cpu.Arch, field.name);
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
    inline for (@typeInfo(Target.Cpu.Arch).Enum.fields) |field| {
        try jws.objectField(field.name);
        try jws.beginArray();
        const arch = @field(Target.Cpu.Arch, field.name);
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
    // TODO implement native glibc version detection in self-hosted
    try jws.endObject();

    try jws.endObject();

    try bos_stream.writeByte('\n');
    return bos.flush();
}
