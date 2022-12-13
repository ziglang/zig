//! TODO: Rename this to ObjCopyStep now that it invokes the `zig objcopy`
//! subcommand rather than containing an implementation directly.

const std = @import("std");
const InstallRawStep = @This();

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Builder = std.build.Builder;
const File = std.fs.File;
const InstallDir = std.build.InstallDir;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const elf = std.elf;
const fs = std.fs;
const io = std.io;
const sort = std.sort;

pub const base_id = .install_raw;

pub const RawFormat = enum {
    bin,
    hex,
};

step: Step,
builder: *Builder,
artifact: *LibExeObjStep,
dest_dir: InstallDir,
dest_filename: []const u8,
options: CreateOptions,
output_file: std.build.GeneratedFile,

pub const CreateOptions = struct {
    format: ?RawFormat = null,
    dest_dir: ?InstallDir = null,
    only_section: ?[]const u8 = null,
    pad_to: ?u64 = null,
};

pub fn create(builder: *Builder, artifact: *LibExeObjStep, dest_filename: []const u8, options: CreateOptions) *InstallRawStep {
    const self = builder.allocator.create(InstallRawStep) catch unreachable;
    self.* = InstallRawStep{
        .step = Step.init(.install_raw, builder.fmt("install raw binary {s}", .{artifact.step.name}), builder.allocator, make),
        .builder = builder,
        .artifact = artifact,
        .dest_dir = if (options.dest_dir) |d| d else switch (artifact.kind) {
            .obj => unreachable,
            .@"test" => unreachable,
            .exe, .test_exe => .bin,
            .lib => unreachable,
        },
        .dest_filename = dest_filename,
        .options = options,
        .output_file = std.build.GeneratedFile{ .step = &self.step },
    };
    self.step.dependOn(&artifact.step);

    builder.pushInstalledFile(self.dest_dir, dest_filename);
    return self;
}

pub fn getOutputSource(self: *const InstallRawStep) std.build.FileSource {
    return std.build.FileSource{ .generated = &self.output_file };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(InstallRawStep, "step", step);
    const b = self.builder;

    if (self.artifact.target.getObjectFormat() != .elf) {
        std.debug.print("InstallRawStep only works with ELF format.\n", .{});
        return error.InvalidObjectFormat;
    }

    const full_src_path = self.artifact.getOutputSource().getPath(b);
    const full_dest_path = b.getInstallPath(self.dest_dir, self.dest_filename);
    self.output_file.path = full_dest_path;

    fs.cwd().makePath(b.getInstallPath(self.dest_dir, "")) catch unreachable;

    var argv_list = std.ArrayList([]const u8).init(b.allocator);
    try argv_list.appendSlice(&.{ b.zig_exe, "objcopy" });

    if (self.options.only_section) |only_section| {
        try argv_list.appendSlice(&.{ "-j", only_section });
    }
    if (self.options.pad_to) |pad_to| {
        try argv_list.appendSlice(&.{
            "--pad-to",
            b.fmt("{d}", .{pad_to}),
        });
    }
    if (self.options.format) |format| switch (format) {
        .bin => try argv_list.appendSlice(&.{ "-O", "binary" }),
        .hex => try argv_list.appendSlice(&.{ "-O", "hex" }),
    };

    try argv_list.appendSlice(&.{ full_src_path, full_dest_path });
    _ = try self.builder.execFromStep(argv_list.items, &self.step);
}

test {
    std.testing.refAllDecls(InstallRawStep);
}
