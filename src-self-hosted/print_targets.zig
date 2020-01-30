const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const Target = std.Target;

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
    "x86_64-linux-gnu (native)",
    "x86_64-linux-gnux32",
    "x86_64-linux-musl",
    "x86_64-windows-gnu",
};

// TODO this is hard-coded until self-hosted gains this information canonically
const available_glibcs = [_][]const u8{
    "2.0",
    "2.1",
    "2.1.1",
    "2.1.2",
    "2.1.3",
    "2.2",
    "2.2.1",
    "2.2.2",
    "2.2.3",
    "2.2.4",
    "2.2.5",
    "2.2.6",
    "2.3",
    "2.3.2",
    "2.3.3",
    "2.3.4",
    "2.4",
    "2.5",
    "2.6",
    "2.7",
    "2.8",
    "2.9",
    "2.10",
    "2.11",
    "2.12",
    "2.13",
    "2.14",
    "2.15",
    "2.16",
    "2.17",
    "2.18",
    "2.19",
    "2.22",
    "2.23",
    "2.24",
    "2.25",
    "2.26",
    "2.27",
    "2.28",
    "2.29",
    "2.30",
};

pub fn cmdTargets(
    allocator: *Allocator,
    args: []const []const u8,
    stdout: *io.OutStream(fs.File.WriteError),
    native_target: Target,
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
    inline for (@typeInfo(Target.Os).Enum.fields) |field| {
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
        try jws.emitString(glibc);
    }
    try jws.endArray();

    try jws.objectField("cpus");
    try jws.beginObject();
    inline for (@typeInfo(Target.Arch).Union.fields) |field| {
        try jws.objectField(field.name);
        try jws.beginObject();
        const arch = @unionInit(Target.Arch, field.name, undefined);
        for (arch.allCpus()) |cpu| {
            try jws.objectField(cpu.name);
            try jws.beginArray();
            for (arch.allFeaturesList()) |feature, i| {
                if (cpu.features.isEnabled(@intCast(u8, i))) {
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
    inline for (@typeInfo(Target.Arch).Union.fields) |field| {
        try jws.objectField(field.name);
        try jws.beginArray();
        const arch = @unionInit(Target.Arch, field.name, undefined);
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
    try jws.objectField("arch");
    try jws.emitString(@tagName(native_target.getArch()));
    try jws.objectField("os");
    try jws.emitString(@tagName(native_target.getOs()));
    try jws.objectField("abi");
    try jws.emitString(@tagName(native_target.getAbi()));
    try jws.objectField("cpuName");
    const cpu_features = native_target.getCpuFeatures();
    try jws.emitString(cpu_features.cpu.name);
    {
        try jws.objectField("cpuFeatures");
        try jws.beginArray();
        for (native_target.getArch().allFeaturesList()) |feature, i_usize| {
            const index = @intCast(Target.Cpu.Feature.Set.Index, i_usize);
            if (cpu_features.features.isEnabled(index)) {
                try jws.arrayElem();
                try jws.emitString(feature.name);
            }
        }
        try jws.endArray();
    }
    // TODO implement native glibc version detection in self-hosted
    try jws.endObject();

    try jws.endObject();

    try bos.stream.writeByte('\n');
    return bos.flush();
}
