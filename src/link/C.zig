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
pub const zig_h = @embedFile("C/zig.h");

base: link.File,

/// Per-declaration data. For functions this is the body, and
/// the forward declaration is stored in the FnBlock.
pub const DeclBlock = struct {
    code: std.ArrayListUnmanaged(u8),

    pub const empty: DeclBlock = .{
        .code = .{},
    };
};

/// Per-function data.
pub const FnBlock = struct {
    fwd_decl: std.ArrayListUnmanaged(u8),

    pub const empty: FnBlock = .{
        .fwd_decl = .{},
    };
};

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*C {
    assert(options.object_format == .c);

    if (options.use_llvm) return error.LLVMHasNoCBackend;
    if (options.use_lld) return error.LLDHasNoCBackend;

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        // Truncation is done on `flush`.
        .truncate = false,
        .mode = link.determineMode(options),
    });
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
    };

    return c_file;
}

pub fn deinit(self: *C) void {
    const module = self.base.options.module orelse return;
    for (module.decl_table.items()) |entry| {
        self.freeDecl(entry.value);
    }
}

pub fn allocateDeclIndexes(self: *C, decl: *Module.Decl) !void {}

pub fn freeDecl(self: *C, decl: *Module.Decl) void {
    decl.link.c.code.deinit(self.base.allocator);
    decl.fn_link.c.fwd_decl.deinit(self.base.allocator);
}

pub fn updateDecl(self: *C, module: *Module, decl: *Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const fwd_decl = &decl.fn_link.c.fwd_decl;
    const code = &decl.link.c.code;
    fwd_decl.shrinkRetainingCapacity(0);
    code.shrinkRetainingCapacity(0);

    var object: codegen.Object = .{
        .dg = .{
            .module = module,
            .error_msg = null,
            .decl = decl,
            .fwd_decl = fwd_decl.toManaged(module.gpa),
        },
        .gpa = module.gpa,
        .code = code.toManaged(module.gpa),
        .value_map = codegen.CValueMap.init(module.gpa),
    };
    defer object.value_map.deinit();
    defer object.code.deinit();
    defer object.dg.fwd_decl.deinit();

    codegen.genDecl(&object) catch |err| switch (err) {
        error.AnalysisFail => {},
        else => |e| return e,
    };
    // The code may populate this error without returning error.AnalysisFail.
    if (object.dg.error_msg) |msg| {
        try module.failed_decls.put(module.gpa, decl, msg);
        return;
    }

    fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
    code.* = object.code.moveToUnmanaged();

    // Free excess allocated memory for this Decl.
    fwd_decl.shrink(module.gpa, fwd_decl.items.len);
    code.shrink(module.gpa, code.items.len);
}

pub fn updateDeclLineNumber(self: *C, module: *Module, decl: *Module.Decl) !void {
    // The C backend does not have the ability to fix line numbers without re-generating
    // the entire Decl.
    return self.updateDecl(module, decl);
}

pub fn flush(self: *C, comp: *Compilation) !void {
    return self.flushModule(comp);
}

pub fn flushModule(self: *C, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const module = self.base.options.module orelse
        return error.LinkingWithoutZigSourceUnimplemented;

    // We collect a list of buffers to write, and write them all at once with pwritev 😎
    var all_buffers = std.ArrayList(std.os.iovec_const).init(comp.gpa);
    defer all_buffers.deinit();

    // This is at least enough until we get to the function bodies without error handling.
    try all_buffers.ensureCapacity(module.decl_table.count() + 1);

    var file_size: u64 = zig_h.len;
    all_buffers.appendAssumeCapacity(.{
        .iov_base = zig_h,
        .iov_len = zig_h.len,
    });

    var fn_count: usize = 0;

    // Forward decls and non-functions first.
    for (module.decl_table.items()) |kv| {
        const decl = kv.value;
        const decl_tv = decl.typed_value.most_recent.typed_value;
        const buf = buf: {
            if (decl_tv.val.castTag(.function)) |_| {
                fn_count += 1;
                break :buf decl.fn_link.c.fwd_decl.items;
            } else {
                break :buf decl.link.c.code.items;
            }
        };
        all_buffers.appendAssumeCapacity(.{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        });
        file_size += buf.len;
    }

    // Now the function bodies.
    try all_buffers.ensureCapacity(all_buffers.items.len + fn_count);
    for (module.decl_table.items()) |kv| {
        const decl = kv.value;
        const decl_tv = decl.typed_value.most_recent.typed_value;
        if (decl_tv.val.castTag(.function)) |_| {
            const buf = decl.link.c.code.items;
            all_buffers.appendAssumeCapacity(.{
                .iov_base = buf.ptr,
                .iov_len = buf.len,
            });
            file_size += buf.len;
        }
    }

    const file = self.base.file.?;
    try file.setEndPos(file_size);
    try file.pwritevAll(all_buffers.items, 0);
}

pub fn updateDeclExports(
    self: *C,
    module: *Module,
    decl: *Module.Decl,
    exports: []const *Module.Export,
) !void {}
