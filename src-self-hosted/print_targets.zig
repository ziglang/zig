const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;

pub fn cmdTargets(
    allocator: *Allocator,
    args: []const []const u8,
    stdout: *io.OutStream(fs.File.WriteError),
) !void {
    const BOS = io.BufferedOutStream(fs.File.WriteError);
    var bos = BOS.init(stdout);
    var jws = std.json.WriteStream(BOS.Stream, 6).init(&bos.stream);

    try jws.beginObject();

    try jws.objectField("arch");
    try jws.beginObject();
    {
        inline for (@typeInfo(Target.Arch).Union.fields) |field| {
            try jws.objectField(field.name);
            if (field.field_type == void) {
                try jws.emitNull();
            } else {
                try jws.emitString(@typeName(field.field_type));
            }
        }
    }
    try jws.endObject();

    try jws.objectField("subArch");
    try jws.beginObject();
    const sub_arch_list = [_]type{
        Target.Arch.Arm32,
        Target.Arch.Arm64,
        Target.Arch.Kalimba,
        Target.Arch.Mips,
    };
    inline for (sub_arch_list) |SubArch| {
        try jws.objectField(@typeName(SubArch));
        try jws.beginArray();
        inline for (@typeInfo(SubArch).Enum.fields) |field| {
            try jws.arrayElem();
            try jws.emitString(field.name);
        }
        try jws.endArray();
    }
    try jws.endObject();

    try jws.objectField("os");
    try jws.beginArray();
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(Target.Os)) : (i += 1) {
            const os_tag = @memberName(Target.Os, i);
            try jws.arrayElem();
            try jws.emitString(os_tag);
        }
    }
    try jws.endArray();

    try jws.objectField("abi");
    try jws.beginArray();
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(Target.Abi)) : (i += 1) {
            const abi_tag = @memberName(Target.Abi, i);
            try jws.arrayElem();
            try jws.emitString(abi_tag);
        }
    }
    try jws.endArray();

    try jws.objectField("native");
    try jws.beginObject();
    {
        const triple = try Target.current.zigTriple(allocator);
        defer allocator.free(triple);
        try jws.objectField("triple");
        try jws.emitString(triple);
    }
    try jws.objectField("arch");
    try jws.emitString(@tagName(Target.current.getArch()));
    try jws.objectField("os");
    try jws.emitString(@tagName(Target.current.getOs()));
    try jws.objectField("abi");
    try jws.emitString(@tagName(Target.current.getAbi()));
    try jws.objectField("cpuName");
    switch (Target.current.getCpuFeatures()) {
        .baseline, .features => try jws.emitNull(),
        .cpu => |cpu| try jws.emitString(cpu.name),
    }
    try jws.endObject();

    try jws.endObject();

    try bos.stream.writeByte('\n');
    return bos.flush();
}
