const Plan9 = @This();

const std = @import("std");
const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const File = link.File;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.link);

base: link.File,
error_flags: File.ErrorFlags = File.ErrorFlags{},

pub const SrcFn = struct {
    /// Offset from the beginning of the Debug Line Program header that contains this function.
    off: u32,
    /// Size of the line number program component belonging to this function, not
    /// including padding.
    len: u32,

    /// Points to the previous and next neighbors, based on the offset from .debug_line.
    /// This can be used to find, for example, the capacity of this `SrcFn`.
    prev: ?*SrcFn,
    next: ?*SrcFn,

    pub const empty: SrcFn = .{
        .off = 0,
        .len = 0,
        .prev = null,
        .next = null,
    };
};

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*Plan9 {
    const self = try gpa.create(Plan9);
    self.* = .{
        .base = .{
            .tag = .plan9,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
    };
    return self;
}

pub fn updateDecl(self: *Plan9, module: *Module, decl: *Module.Decl) !void {}

pub fn allocateDeclIndexes(self: *Plan9, decl: *Module.Decl) !void {}

pub fn flush(self: *Plan9, comp: *Compilation) !void {}
pub fn flushModule(self: *Plan9, comp: *Compilation) !void {}
pub fn freeDecl(self: *Plan9, decl: *Module.Decl) void {}
pub fn updateDeclExports(
    self: *Plan9,
    module: *Module,
    decl: *Module.Decl,
    exports: []const *Module.Export,
) !void {}
pub fn deinit(self: *Plan9) void {}

pub const Export = struct {
    sym_index: ?u32 = null,
};
