const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const fs = std.fs;
const codegen = @import("../codegen/c.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const C = @This();

pub const base_tag: link.File.Tag = .c;

pub const Header = struct {
    buf: std.ArrayList(u8),
    emit_loc: ?Compilation.EmitLoc,

    pub fn init(allocator: *Allocator, emit_loc: ?Compilation.EmitLoc) Header {
        return .{
            .buf = std.ArrayList(u8).init(allocator),
            .emit_loc = emit_loc,
        };
    }

    pub fn flush(self: *const Header, writer: anytype) !void {
        const tracy = trace(@src());
        defer tracy.end();

        try writer.writeAll(@embedFile("cbe.h"));
        if (self.buf.items.len > 0) {
            try writer.print("{s}", .{self.buf.items});
        }
    }

    pub fn deinit(self: *Header) void {
        self.buf.deinit();
        self.* = undefined;
    }
};

base: link.File,

path: []const u8,

// These are only valid during a flush()!
header: Header,
constants: std.ArrayList(u8),
main: std.ArrayList(u8),
called: std.StringHashMap(void),

error_msg: *Compilation.ErrorMsg = undefined,

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*C {
    assert(options.object_format == .c);

    if (options.use_llvm) return error.LLVMHasNoCBackend;
    if (options.use_lld) return error.LLDHasNoCBackend;

    var c_file = try allocator.create(C);
    errdefer allocator.destroy(c_file);

    c_file.* = C{
        .base = .{
            .tag = .c,
            .options = options,
            .file = null,
            .allocator = allocator,
        },
        .main = undefined,
        .header = undefined,
        .constants = undefined,
        .called = undefined,
        .path = sub_path,
    };

    return c_file;
}

pub fn fail(self: *C, src: usize, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
    self.error_msg = try Compilation.ErrorMsg.create(self.base.allocator, src, format, args);
    return error.AnalysisFail;
}

pub fn deinit(self: *C) void {}

pub fn flush(self: *C, comp: *Compilation) !void {
    return self.flushModule(comp);
}

pub fn flushModule(self: *C, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    self.main = std.ArrayList(u8).init(self.base.allocator);
    self.header = Header.init(self.base.allocator, null);
    self.constants = std.ArrayList(u8).init(self.base.allocator);
    self.called = std.StringHashMap(void).init(self.base.allocator);
    defer self.main.deinit();
    defer self.header.deinit();
    defer self.constants.deinit();
    defer self.called.deinit();

    const module = self.base.options.module.?;
    for (self.base.options.module.?.decl_table.entries.items) |kv| {
        codegen.generate(self, module, kv.value) catch |err| {
            if (err == error.AnalysisFail) {
                try module.failed_decls.put(module.gpa, kv.value, self.error_msg);
            }
            return err;
        };
    }

    const file = try self.base.options.emit.?.directory.handle.createFile(self.path, .{ .truncate = true, .read = true, .mode = link.determineMode(self.base.options) });
    defer file.close();

    const writer = file.writer();
    try self.header.flush(writer);
    if (self.header.buf.items.len > 0) {
        try writer.writeByte('\n');
    }
    if (self.constants.items.len > 0) {
        try writer.print("{s}\n", .{self.constants.items});
    }
    if (self.main.items.len > 1) {
        const last_two = self.main.items[self.main.items.len - 2 ..];
        if (std.mem.eql(u8, last_two, "\n\n")) {
            self.main.items.len -= 1;
        }
    }
    try writer.writeAll(self.main.items);
}
