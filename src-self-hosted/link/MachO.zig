const MachO = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;

const Module = @import("../Module.zig");
const link = @import("../link.zig");
const File = link.File;

pub const base_tag: Tag = File.Tag.macho;

base: File,

error_flags: File.ErrorFlags = File.ErrorFlags{},

pub const TextBlock = struct {
    pub const empty = TextBlock{};
};

pub const SrcFn = struct {
    pub const empty = SrcFn{};
};

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*File {
    assert(options.object_format == .macho);

    const file = try dir.createFile(sub_path, .{ .truncate = false, .read = true, .mode = link.determineMode(options) });
    errdefer file.close();

    var macho_file = try allocator.create(MachO);
    errdefer allocator.destroy(macho_file);

    macho_file.* = openFile(allocator, file, options) catch |err| switch (err) {
        error.IncrFailed => try createFile(allocator, file, options),
        else => |e| return e,
    };

    return &macho_file.base;
}

/// Returns error.IncrFailed if incremental update could not be performed.
fn openFile(allocator: *Allocator, file: fs.File, options: link.Options) !MachO {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.IncrFailed,
    }
    var self: MachO = .{
        .base = .{
            .file = file,
            .tag = .macho,
            .options = options,
            .allocator = allocator,
        },
    };
    errdefer self.deinit();

    // TODO implement reading the macho file
    return error.IncrFailed;
    //try self.populateMissingMetadata();
    //return self;
}

/// Truncates the existing file contents and overwrites the contents.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
fn createFile(allocator: *Allocator, file: fs.File, options: link.Options) !MachO {
    switch (options.output_mode) {
        .Exe => return error.TODOImplementWritingMachOExeFiles,
        .Obj => return error.TODOImplementWritingMachOObjFiles,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
}

pub fn flush(self: *MachO, module: *Module) !void {}

pub fn deinit(self: *MachO) void {}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {}
