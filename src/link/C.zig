const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const fs = std.fs;

const C = @This();
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen/c.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const Type = @import("../type.zig").Type;
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");

pub const base_tag: link.File.Tag = .c;
pub const zig_h = @embedFile("C/zig.h");

base: link.File,
/// This linker backend does not try to incrementally link output C source code.
/// Instead, it tracks all declarations in this table, and iterates over it
/// in the flush function, stitching pre-rendered pieces of C code together.
decl_table: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, DeclBlock) = .{},
/// Stores Type/Value data for `typedefs` to reference.
/// Accumulates allocations and then there is a periodic garbage collection after flush().
arena: std.heap.ArenaAllocator,

/// Per-declaration data.
const DeclBlock = struct {
    code: std.ArrayListUnmanaged(u8) = .{},
    fwd_decl: std.ArrayListUnmanaged(u8) = .{},
    /// Each Decl stores a mapping of Zig Types to corresponding C types, for every
    /// Zig Type used by the Decl. In flush(), we iterate over each Decl
    /// and emit the typedef code for all types, making sure to not emit the same thing twice.
    /// Any arena memory the Type points to lives in the `arena` field of `C`.
    typedefs: codegen.TypedefMap.Unmanaged = .{},

    fn deinit(db: *DeclBlock, gpa: Allocator) void {
        db.code.deinit(gpa);
        db.fwd_decl.deinit(gpa);
        for (db.typedefs.values()) |typedef| {
            gpa.free(typedef.rendered);
        }
        db.typedefs.deinit(gpa);
        db.* = undefined;
    }
};

pub fn openPath(gpa: Allocator, sub_path: []const u8, options: link.Options) !*C {
    assert(options.object_format == .c);

    if (options.use_llvm) return error.LLVMHasNoCBackend;
    if (options.use_lld) return error.LLDHasNoCBackend;

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        // Truncation is done on `flush`.
        .truncate = false,
        .mode = link.determineMode(options),
    });
    errdefer file.close();

    var c_file = try gpa.create(C);
    errdefer gpa.destroy(c_file);

    c_file.* = C{
        .arena = std.heap.ArenaAllocator.init(gpa),
        .base = .{
            .tag = .c,
            .options = options,
            .file = file,
            .allocator = gpa,
        },
    };

    return c_file;
}

pub fn deinit(self: *C) void {
    const gpa = self.base.allocator;

    for (self.decl_table.values()) |*db| {
        db.deinit(gpa);
    }
    self.decl_table.deinit(gpa);

    self.arena.deinit();
}

pub fn freeDecl(self: *C, decl_index: Module.Decl.Index) void {
    const gpa = self.base.allocator;
    if (self.decl_table.fetchSwapRemove(decl_index)) |kv| {
        var decl_block = kv.value;
        decl_block.deinit(gpa);
    }
}

pub fn updateFunc(self: *C, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl_index = func.owner_decl;
    const gop = try self.decl_table.getOrPut(self.base.allocator, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const fwd_decl = &gop.value_ptr.fwd_decl;
    const typedefs = &gop.value_ptr.typedefs;
    const code = &gop.value_ptr.code;
    fwd_decl.shrinkRetainingCapacity(0);
    {
        for (typedefs.values()) |value| {
            module.gpa.free(value.rendered);
        }
    }
    typedefs.clearRetainingCapacity();
    code.shrinkRetainingCapacity(0);

    var function: codegen.Function = .{
        .value_map = codegen.CValueMap.init(module.gpa),
        .air = air,
        .liveness = liveness,
        .func = func,
        .object = .{
            .dg = .{
                .gpa = module.gpa,
                .module = module,
                .error_msg = null,
                .decl_index = decl_index,
                .decl = module.declPtr(decl_index),
                .fwd_decl = fwd_decl.toManaged(module.gpa),
                .typedefs = typedefs.promoteContext(module.gpa, .{ .mod = module }),
                .typedefs_arena = self.arena.allocator(),
            },
            .code = code.toManaged(module.gpa),
            .indent_writer = undefined, // set later so we can get a pointer to object.code
        },
    };

    function.object.indent_writer = .{ .underlying_writer = function.object.code.writer() };
    defer {
        function.value_map.deinit();
        function.blocks.deinit(module.gpa);
        function.object.code.deinit();
        function.object.dg.fwd_decl.deinit();
        for (function.object.dg.typedefs.values()) |value| {
            module.gpa.free(value.rendered);
        }
        function.object.dg.typedefs.deinit();
    }

    codegen.genFunc(&function) catch |err| switch (err) {
        error.AnalysisFail => {
            try module.failed_decls.put(module.gpa, decl_index, function.object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };

    fwd_decl.* = function.object.dg.fwd_decl.moveToUnmanaged();
    typedefs.* = function.object.dg.typedefs.unmanaged;
    function.object.dg.typedefs.unmanaged = .{};
    code.* = function.object.code.moveToUnmanaged();

    // Free excess allocated memory for this Decl.
    fwd_decl.shrinkAndFree(module.gpa, fwd_decl.items.len);
    code.shrinkAndFree(module.gpa, code.items.len);
}

pub fn updateDecl(self: *C, module: *Module, decl_index: Module.Decl.Index) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gop = try self.decl_table.getOrPut(self.base.allocator, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const fwd_decl = &gop.value_ptr.fwd_decl;
    const typedefs = &gop.value_ptr.typedefs;
    const code = &gop.value_ptr.code;
    fwd_decl.shrinkRetainingCapacity(0);
    {
        for (typedefs.values()) |value| {
            module.gpa.free(value.rendered);
        }
    }
    typedefs.clearRetainingCapacity();
    code.shrinkRetainingCapacity(0);

    const decl = module.declPtr(decl_index);

    var object: codegen.Object = .{
        .dg = .{
            .gpa = module.gpa,
            .module = module,
            .error_msg = null,
            .decl_index = decl_index,
            .decl = decl,
            .fwd_decl = fwd_decl.toManaged(module.gpa),
            .typedefs = typedefs.promoteContext(module.gpa, .{ .mod = module }),
            .typedefs_arena = self.arena.allocator(),
        },
        .code = code.toManaged(module.gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        object.code.deinit();
        object.dg.fwd_decl.deinit();
        for (object.dg.typedefs.values()) |value| {
            module.gpa.free(value.rendered);
        }
        object.dg.typedefs.deinit();
    }

    codegen.genDecl(&object) catch |err| switch (err) {
        error.AnalysisFail => {
            try module.failed_decls.put(module.gpa, decl_index, object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };

    fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
    typedefs.* = object.dg.typedefs.unmanaged;
    object.dg.typedefs.unmanaged = .{};
    code.* = object.code.moveToUnmanaged();

    // Free excess allocated memory for this Decl.
    fwd_decl.shrinkAndFree(module.gpa, fwd_decl.items.len);
    code.shrinkAndFree(module.gpa, code.items.len);
}

pub fn updateDeclLineNumber(self: *C, module: *Module, decl: *Module.Decl) !void {
    // The C backend does not have the ability to fix line numbers without re-generating
    // the entire Decl.
    _ = self;
    _ = module;
    _ = decl;
}

pub fn flush(self: *C, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    return self.flushModule(comp, prog_node);
}

pub fn flushModule(self: *C, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const gpa = comp.gpa;
    const module = self.base.options.module.?;

    // This code path happens exclusively with -ofmt=c. The flush logic for
    // emit-h is in `flushEmitH` below.

    var f: Flush = .{};
    defer f.deinit(gpa);

    // Covers zig.h and err_typedef_item.
    try f.all_buffers.ensureUnusedCapacity(gpa, 2);

    f.all_buffers.appendAssumeCapacity(.{
        .iov_base = zig_h,
        .iov_len = zig_h.len,
    });
    f.file_size += zig_h.len;

    const err_typedef_writer = f.err_typedef_buf.writer(gpa);
    const err_typedef_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    render_errors: {
        if (module.global_error_set.size == 0) break :render_errors;
        var it = module.global_error_set.iterator();
        while (it.next()) |entry| {
            try err_typedef_writer.print("#define zig_error_{s} {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        try err_typedef_writer.writeByte('\n');
    }

    // Typedefs, forward decls, and non-functions first.
    // Unlike other backends, the .c code we are emitting is order-dependent. Therefore
    // we must traverse the set of Decls that we are emitting according to their dependencies.
    // Our strategy is to populate a set of remaining decls, pop Decls one by one,
    // recursively chasing their dependencies.
    try f.remaining_decls.ensureUnusedCapacity(gpa, self.decl_table.count());

    const decl_keys = self.decl_table.keys();
    const decl_values = self.decl_table.values();
    for (decl_keys) |decl_index| {
        assert(module.declPtr(decl_index).has_tv);
        f.remaining_decls.putAssumeCapacityNoClobber(decl_index, {});
    }

    while (f.remaining_decls.popOrNull()) |kv| {
        const decl_index = kv.key;
        try flushDecl(self, &f, decl_index);
    }

    f.all_buffers.items[err_typedef_index] = .{
        .iov_base = f.err_typedef_buf.items.ptr,
        .iov_len = f.err_typedef_buf.items.len,
    };
    f.file_size += f.err_typedef_buf.items.len;

    // Now the function bodies.
    try f.all_buffers.ensureUnusedCapacity(gpa, f.fn_count);
    for (decl_keys) |decl_index, i| {
        const decl = module.declPtr(decl_index);
        if (decl.getFunction() != null) {
            const decl_block = &decl_values[i];
            const buf = decl_block.code.items;
            if (buf.len != 0) {
                f.all_buffers.appendAssumeCapacity(.{
                    .iov_base = buf.ptr,
                    .iov_len = buf.len,
                });
                f.file_size += buf.len;
            }
        }
    }

    const file = self.base.file.?;
    try file.setEndPos(f.file_size);
    try file.pwritevAll(f.all_buffers.items, 0);
}

const Flush = struct {
    remaining_decls: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, void) = .{},
    typedefs: Typedefs = .{},
    err_typedef_buf: std.ArrayListUnmanaged(u8) = .{},
    /// We collect a list of buffers to write, and write them all at once with pwritev 😎
    all_buffers: std.ArrayListUnmanaged(std.os.iovec_const) = .{},
    /// Keeps track of the total bytes of `all_buffers`.
    file_size: u64 = 0,
    fn_count: usize = 0,

    const Typedefs = std.HashMapUnmanaged(
        Type,
        void,
        Type.HashContext64,
        std.hash_map.default_max_load_percentage,
    );

    fn deinit(f: *Flush, gpa: Allocator) void {
        f.all_buffers.deinit(gpa);
        f.err_typedef_buf.deinit(gpa);
        f.typedefs.deinit(gpa);
        f.remaining_decls.deinit(gpa);
    }
};

const FlushDeclError = error{
    OutOfMemory,
};

/// Assumes `decl` was in the `remaining_decls` set, and has already been removed.
fn flushDecl(self: *C, f: *Flush, decl_index: Module.Decl.Index) FlushDeclError!void {
    const module = self.base.options.module.?;
    const decl = module.declPtr(decl_index);
    // Before flushing any particular Decl we must ensure its
    // dependencies are already flushed, so that the order in the .c
    // file comes out correctly.
    for (decl.dependencies.keys()) |dep| {
        if (f.remaining_decls.swapRemove(dep)) {
            try flushDecl(self, f, dep);
        }
    }

    const decl_block = self.decl_table.getPtr(decl_index).?;
    const gpa = self.base.allocator;

    if (decl_block.typedefs.count() != 0) {
        try f.typedefs.ensureUnusedCapacityContext(gpa, @intCast(u32, decl_block.typedefs.count()), .{
            .mod = module,
        });
        var it = decl_block.typedefs.iterator();
        while (it.next()) |new| {
            const gop = f.typedefs.getOrPutAssumeCapacityContext(new.key_ptr.*, .{
                .mod = module,
            });
            if (!gop.found_existing) {
                try f.err_typedef_buf.appendSlice(gpa, new.value_ptr.rendered);
            }
        }
    }

    if (decl_block.fwd_decl.items.len != 0) {
        const buf = decl_block.fwd_decl.items;
        try f.all_buffers.append(gpa, .{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        });
        f.file_size += buf.len;
    }
    if (decl.getFunction() != null) {
        f.fn_count += 1;
    } else if (decl_block.code.items.len != 0) {
        const buf = decl_block.code.items;
        try f.all_buffers.append(gpa, .{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        });
        f.file_size += buf.len;
    }
}

pub fn flushEmitH(module: *Module) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const emit_h = module.emit_h orelse return;

    // We collect a list of buffers to write, and write them all at once with pwritev 😎
    const num_buffers = emit_h.decl_table.count() + 1;
    var all_buffers = try std.ArrayList(std.os.iovec_const).initCapacity(module.gpa, num_buffers);
    defer all_buffers.deinit();

    var file_size: u64 = zig_h.len;
    all_buffers.appendAssumeCapacity(.{
        .iov_base = zig_h,
        .iov_len = zig_h.len,
    });

    for (emit_h.decl_table.keys()) |decl_index| {
        const decl_emit_h = emit_h.declPtr(decl_index);
        const buf = decl_emit_h.fwd_decl.items;
        all_buffers.appendAssumeCapacity(.{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        });
        file_size += buf.len;
    }

    const directory = emit_h.loc.directory orelse module.comp.local_cache_directory;
    const file = try directory.handle.createFile(emit_h.loc.basename, .{
        // We set the end position explicitly below; by not truncating the file, we possibly
        // make it easier on the file system by doing 1 reallocation instead of two.
        .truncate = false,
    });
    defer file.close();

    try file.setEndPos(file_size);
    try file.pwritevAll(all_buffers.items, 0);
}

pub fn updateDeclExports(
    self: *C,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    _ = exports;
    _ = decl_index;
    _ = module;
    _ = self;
}
