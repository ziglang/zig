const std = @import("std");
const ObjCopyStep = @This();

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const File = std.fs.File;
const InstallDir = std.Build.InstallDir;
const CompileStep = std.Build.CompileStep;
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
builder: *std.Build,
file_source: std.Build.FileSource,
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
    builder: *std.Build,
    file_source: std.Build.FileSource,
    options: Options,
) *ObjCopyStep {
    const self = builder.allocator.create(ObjCopyStep) catch @panic("OOM");
    self.* = ObjCopyStep{
        .step = Step.init(
            base_id,
            builder.fmt("objcopy {s}", .{file_source.getDisplayName()}),
            builder.allocator,
            make,
        ),
        .builder = builder,
        .file_source = file_source,
        .basename = options.basename orelse file_source.getDisplayName(),
        .output_file = std.Build.GeneratedFile{ .step = &self.step },

        .format = options.format,
        .only_section = options.only_section,
        .pad_to = options.pad_to,
    };
    file_source.addStepDependencies(&self.step);
    return self;
}

pub fn getOutputSource(self: *const ObjCopyStep) std.Build.FileSource {
    return .{ .generated = &self.output_file };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(ObjCopyStep, "step", step);
    const b = self.builder;

    var man = b.cache.obtain();
    defer man.deinit();

    // Random bytes to make ObjCopyStep unique. Refresh this with new random
    // bytes when ObjCopyStep implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xe18b7baf));

    const full_src_path = self.file_source.getPath(b);
    _ = try man.addFile(full_src_path, null);
    man.hash.addOptionalBytes(self.only_section);
    man.hash.addOptional(self.pad_to);
    man.hash.addOptional(self.format);

    if (man.hit() catch |err| failWithCacheError(man, err)) {
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
        std.debug.print("unable to make path {s}: {s}\n", .{ cache_path, @errorName(err) });
        return err;
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
    _ = try self.builder.execFromStep(argv.items, &self.step);

    self.output_file.path = full_dest_path;
    try man.writeManifest();
}

/// TODO consolidate this with the same function in RunStep?
/// Also properly deal with concurrency (see open PR)
fn failWithCacheError(man: std.Build.Cache.Manifest, err: anyerror) noreturn {
    const i = man.failed_file_index orelse failWithSimpleError(err);
    const pp = man.files.items[i].prefixed_path orelse failWithSimpleError(err);
    const prefix = man.cache.prefixes()[pp.prefix].path orelse "";
    std.debug.print("{s}: {s}/{s}\n", .{ @errorName(err), prefix, pp.sub_path });
    std.process.exit(1);
}

fn failWithSimpleError(err: anyerror) noreturn {
    std.debug.print("{s}\n", .{@errorName(err)});
    std.process.exit(1);
}
