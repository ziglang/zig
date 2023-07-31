const std = @import("std");
const ObjCopy = @This();

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const File = std.fs.File;
const InstallDir = std.Build.InstallDir;
const Step = std.Build.Step;
const elf = std.elf;
const fs = std.fs;
const io = std.io;
const sort = std.sort;

pub const base_id: Step.Id = .objcopy;

pub const RawFormat = enum {
    bin,
    hex,
};

step: Step,
input_file: std.Build.LazyPath,
basename: []const u8,
output_file: std.Build.GeneratedFile,

format: ?RawFormat,
only_section: ?[]const u8,
pad_to: ?u64,

pub const Options = struct {
    basename: ?[]const u8 = null,
    format: ?RawFormat = null,
    only_section: ?[]const u8 = null,
    pad_to: ?u64 = null,
};

pub fn create(
    owner: *std.Build,
    input_file: std.Build.LazyPath,
    options: Options,
) *ObjCopy {
    const self = owner.allocator.create(ObjCopy) catch @panic("OOM");
    self.* = ObjCopy{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("objcopy {s}", .{input_file.getDisplayName()}),
            .owner = owner,
            .makeFn = make,
        }),
        .input_file = input_file,
        .basename = options.basename orelse input_file.getDisplayName(),
        .output_file = std.Build.GeneratedFile{ .step = &self.step },

        .format = options.format,
        .only_section = options.only_section,
        .pad_to = options.pad_to,
    };
    input_file.addStepDependencies(&self.step);
    return self;
}

/// deprecated: use getOutput
pub const getOutputSource = getOutput;

pub fn getOutput(self: *const ObjCopy) std.Build.LazyPath {
    return .{ .generated = &self.output_file };
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    const b = step.owner;
    const self = @fieldParentPtr(ObjCopy, "step", step);

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make ObjCopy unique. Refresh this with new random
    // bytes when ObjCopy implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xe18b7baf));

    const full_src_path = self.input_file.getPath(b);
    _ = try man.addFile(full_src_path, null);
    man.hash.addOptionalBytes(self.only_section);
    man.hash.addOptional(self.pad_to);
    man.hash.addOptional(self.format);

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "o", &digest, self.basename,
        });
        return;
    }

    const digest = man.final();
    const full_dest_path = try b.cache_root.join(b.allocator, &.{ "o", &digest, self.basename });
    const cache_path = "o" ++ fs.path.sep_str ++ digest;
    b.cache_root.handle.makePath(cache_path) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_path, @errorName(err) });
    };

    var argv = std.ArrayList([]const u8).init(b.allocator);
    try argv.appendSlice(&.{ b.zig_exe, "objcopy" });

    if (self.only_section) |only_section| {
        try argv.appendSlice(&.{ "-j", only_section });
    }
    if (self.pad_to) |pad_to| {
        try argv.appendSlice(&.{ "--pad-to", b.fmt("{d}", .{pad_to}) });
    }
    if (self.format) |format| switch (format) {
        .bin => try argv.appendSlice(&.{ "-O", "binary" }),
        .hex => try argv.appendSlice(&.{ "-O", "hex" }),
    };

    try argv.appendSlice(&.{ full_src_path, full_dest_path });

    try argv.append("--listen=-");
    _ = try step.evalZigProcess(argv.items, prog_node);

    self.output_file.path = full_dest_path;
    try man.writeManifest();
}
