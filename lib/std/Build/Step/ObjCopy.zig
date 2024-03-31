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
    elf,
};

pub const Strip = enum {
    none,
    debug,
    debug_and_symbols,
};

step: Step,
input_file: std.Build.LazyPath,
basename: []const u8,
output_file: std.Build.GeneratedFile,
output_file_debug: ?std.Build.GeneratedFile,

format: ?RawFormat,
only_sections: ?[]const []const u8,
pad_to: ?u64,
strip: Strip,
compress_debug: bool,

pub const Options = struct {
    basename: ?[]const u8 = null,
    format: ?RawFormat = null,
    only_sections: ?[]const []const u8 = null,
    pad_to: ?u64 = null,

    compress_debug: bool = false,
    strip: Strip = .none,

    /// Put the stripped out debug sections in a separate file.
    /// note: the `basename` is baked into the elf file to specify the link to the separate debug file.
    /// see https://sourceware.org/gdb/onlinedocs/gdb/Separate-Debug-Files.html
    extract_to_separate_file: bool = false,
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
        .output_file_debug = if (options.strip != .none and options.extract_to_separate_file) std.Build.GeneratedFile{ .step = &self.step } else null,
        .format = options.format,
        .only_sections = options.only_sections,
        .pad_to = options.pad_to,
        .strip = options.strip,
        .compress_debug = options.compress_debug,
    };
    input_file.addStepDependencies(&self.step);
    return self;
}

/// deprecated: use getOutput
pub const getOutputSource = getOutput;

pub fn getOutput(self: *const ObjCopy) std.Build.LazyPath {
    return .{ .generated = &self.output_file };
}
pub fn getOutputSeparatedDebug(self: *const ObjCopy) ?std.Build.LazyPath {
    return if (self.output_file_debug) |*file| .{ .generated = file } else null;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    const b = step.owner;
    const self: *ObjCopy = @fieldParentPtr("step", step);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    // Random bytes to make ObjCopy unique. Refresh this with new random
    // bytes when ObjCopy implementation is modified incompatibly.
    man.hash.add(@as(u32, 0xe18b7baf));

    const full_src_path = self.input_file.getPath(b);
    _ = try man.addFile(full_src_path, null);
    man.hash.addOptionalListOfBytes(self.only_sections);
    man.hash.addOptional(self.pad_to);
    man.hash.addOptional(self.format);
    man.hash.add(self.compress_debug);
    man.hash.add(self.strip);
    man.hash.add(self.output_file_debug != null);

    if (try step.cacheHit(&man)) {
        // Cache hit, skip subprocess execution.
        const digest = man.final();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{
            "o", &digest, self.basename,
        });
        if (self.output_file_debug) |*file| {
            file.path = try b.cache_root.join(b.allocator, &.{
                "o", &digest, b.fmt("{s}.debug", .{self.basename}),
            });
        }
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ fs.path.sep_str ++ digest;
    const full_dest_path = try b.cache_root.join(b.allocator, &.{ cache_path, self.basename });
    const full_dest_path_debug = try b.cache_root.join(b.allocator, &.{ cache_path, b.fmt("{s}.debug", .{self.basename}) });
    b.cache_root.handle.makePath(cache_path) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_path, @errorName(err) });
    };

    var argv = std.ArrayList([]const u8).init(b.allocator);
    try argv.appendSlice(&.{ b.graph.zig_exe, "objcopy" });

    if (self.only_sections) |only_sections| {
        for (only_sections) |only_section| {
            try argv.appendSlice(&.{ "-j", only_section });
        }
    }
    switch (self.strip) {
        .none => {},
        .debug => try argv.appendSlice(&.{"--strip-debug"}),
        .debug_and_symbols => try argv.appendSlice(&.{"--strip-all"}),
    }
    if (self.pad_to) |pad_to| {
        try argv.appendSlice(&.{ "--pad-to", b.fmt("{d}", .{pad_to}) });
    }
    if (self.format) |format| switch (format) {
        .bin => try argv.appendSlice(&.{ "-O", "binary" }),
        .hex => try argv.appendSlice(&.{ "-O", "hex" }),
        .elf => try argv.appendSlice(&.{ "-O", "elf" }),
    };
    if (self.compress_debug) {
        try argv.appendSlice(&.{"--compress-debug-sections"});
    }
    if (self.output_file_debug != null) {
        try argv.appendSlice(&.{b.fmt("--extract-to={s}", .{full_dest_path_debug})});
    }

    try argv.appendSlice(&.{ full_src_path, full_dest_path });

    try argv.append("--listen=-");
    _ = try step.evalZigProcess(argv.items, prog_node);

    self.output_file.path = full_dest_path;
    if (self.output_file_debug) |*file| file.path = full_dest_path_debug;
    try man.writeManifest();
}
