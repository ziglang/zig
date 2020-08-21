const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Module = @import("../Module.zig");
const fs = std.fs;
const codegen = @import("../codegen/c.zig");
const link = @import("../link.zig");
const File = link.File;
const C = @This();

pub const base_tag: File.Tag = .c;

base: File,

header: std.ArrayList(u8),
constants: std.ArrayList(u8),
main: std.ArrayList(u8),

called: std.StringHashMap(void),
need_stddef: bool = false,
need_stdint: bool = false,
error_msg: *Module.ErrorMsg = undefined,

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*File {
    assert(options.object_format == .c);

    const file = try dir.createFile(sub_path, .{ .truncate = true, .read = true, .mode = link.determineMode(options) });
    errdefer file.close();

    var c_file = try allocator.create(C);
    errdefer allocator.destroy(c_file);

    c_file.* = C{
        .base = .{
            .tag = .c,
            .options = options,
            .file = file,
            .allocator = allocator,
        },
        .main = std.ArrayList(u8).init(allocator),
        .header = std.ArrayList(u8).init(allocator),
        .constants = std.ArrayList(u8).init(allocator),
        .called = std.StringHashMap(void).init(allocator),
    };

    return &c_file.base;
}

pub fn fail(self: *C, src: usize, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
    self.error_msg = try Module.ErrorMsg.create(self.base.allocator, src, format, args);
    return error.AnalysisFail;
}

pub fn deinit(self: *C) void {
    self.main.deinit();
    self.header.deinit();
    self.constants.deinit();
    self.called.deinit();
}

pub fn updateDecl(self: *C, module: *Module, decl: *Module.Decl) !void {
    codegen.generate(self, decl) catch |err| {
        if (err == error.AnalysisFail) {
            try module.failed_decls.put(module.gpa, decl, self.error_msg);
        }
        return err;
    };
}

pub fn flush(self: *C, module: *Module) !void {
    const writer = self.base.file.?.writer();
    try writer.writeAll(@embedFile("cbe.h"));
    var includes = false;
    if (self.need_stddef) {
        try writer.writeAll("#include <stddef.h>\n");
        includes = true;
    }
    if (self.need_stdint) {
        try writer.writeAll("#include <stdint.h>\n");
        includes = true;
    }
    if (includes) {
        try writer.writeByte('\n');
    }
    if (self.header.items.len > 0) {
        try writer.print("{}\n", .{self.header.items});
    }
    if (self.constants.items.len > 0) {
        try writer.print("{}\n", .{self.constants.items});
    }
    if (self.main.items.len > 1) {
        const last_two = self.main.items[self.main.items.len - 2 ..];
        if (std.mem.eql(u8, last_two, "\n\n")) {
            self.main.items.len -= 1;
        }
    }
    try writer.writeAll(self.main.items);
    self.base.file.?.close();
    self.base.file = null;
}
