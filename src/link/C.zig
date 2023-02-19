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
pub const zig_h = "#include \"zig.h\"\n";

base: link.File,
/// This linker backend does not try to incrementally link output C source code.
/// Instead, it tracks all declarations in this table, and iterates over it
/// in the flush function, stitching pre-rendered pieces of C code together.
decl_table: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, DeclBlock) = .{},

/// Per-declaration data.
const DeclBlock = struct {
    code: std.ArrayListUnmanaged(u8) = .{},
    fwd_decl: std.ArrayListUnmanaged(u8) = .{},
    /// Each `Decl` stores a set of used `CType`s.  In `flush()`, we iterate
    /// over each `Decl` and generate the definition for each used `CType` once.
    ctypes: codegen.CType.Store = .{},
    /// Key and Value storage use the ctype arena.
    lazy_fns: codegen.LazyFnMap = .{},

    fn deinit(db: *DeclBlock, gpa: Allocator) void {
        db.lazy_fns.deinit(gpa);
        db.ctypes.deinit(gpa);
        db.fwd_decl.deinit(gpa);
        db.code.deinit(gpa);
        db.* = undefined;
    }
};

pub fn openPath(gpa: Allocator, sub_path: []const u8, options: link.Options) !*C {
    assert(options.target.ofmt == .c);

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

    const gpa = self.base.allocator;

    const decl_index = func.owner_decl;
    const gop = try self.decl_table.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const ctypes = &gop.value_ptr.ctypes;
    const lazy_fns = &gop.value_ptr.lazy_fns;
    const fwd_decl = &gop.value_ptr.fwd_decl;
    const code = &gop.value_ptr.code;
    ctypes.clearRetainingCapacity(gpa);
    lazy_fns.clearRetainingCapacity();
    fwd_decl.shrinkRetainingCapacity(0);
    code.shrinkRetainingCapacity(0);

    var function: codegen.Function = .{
        .value_map = codegen.CValueMap.init(gpa),
        .air = air,
        .liveness = liveness,
        .func = func,
        .object = .{
            .dg = .{
                .gpa = gpa,
                .module = module,
                .error_msg = null,
                .decl_index = decl_index,
                .decl = module.declPtr(decl_index),
                .fwd_decl = fwd_decl.toManaged(gpa),
                .ctypes = ctypes.*,
            },
            .code = code.toManaged(gpa),
            .indent_writer = undefined, // set later so we can get a pointer to object.code
        },
        .lazy_fns = lazy_fns.*,
        .arena = std.heap.ArenaAllocator.init(gpa),
    };

    function.object.indent_writer = .{ .underlying_writer = function.object.code.writer() };
    defer function.deinit();

    codegen.genFunc(&function) catch |err| switch (err) {
        error.AnalysisFail => {
            try module.failed_decls.put(gpa, decl_index, function.object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };

    ctypes.* = function.object.dg.ctypes.move();
    lazy_fns.* = function.lazy_fns.move();
    fwd_decl.* = function.object.dg.fwd_decl.moveToUnmanaged();
    code.* = function.object.code.moveToUnmanaged();

    // Free excess allocated memory for this Decl.
    ctypes.shrinkToFit(gpa);
    lazy_fns.shrinkAndFree(gpa, lazy_fns.count());
    fwd_decl.shrinkAndFree(gpa, fwd_decl.items.len);
    code.shrinkAndFree(gpa, code.items.len);
}

pub fn updateDecl(self: *C, module: *Module, decl_index: Module.Decl.Index) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    const gop = try self.decl_table.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const ctypes = &gop.value_ptr.ctypes;
    const fwd_decl = &gop.value_ptr.fwd_decl;
    const code = &gop.value_ptr.code;
    ctypes.clearRetainingCapacity(gpa);
    fwd_decl.shrinkRetainingCapacity(0);
    code.shrinkRetainingCapacity(0);

    const decl = module.declPtr(decl_index);

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .module = module,
            .error_msg = null,
            .decl_index = decl_index,
            .decl = decl,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctypes = ctypes.*,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        object.code.deinit();
        object.dg.ctypes.deinit(object.dg.gpa);
        object.dg.fwd_decl.deinit();
    }

    codegen.genDecl(&object) catch |err| switch (err) {
        error.AnalysisFail => {
            try module.failed_decls.put(gpa, decl_index, object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };

    ctypes.* = object.dg.ctypes.move();
    fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
    code.* = object.code.moveToUnmanaged();

    // Free excess allocated memory for this Decl.
    ctypes.shrinkToFit(gpa);
    fwd_decl.shrinkAndFree(gpa, fwd_decl.items.len);
    code.shrinkAndFree(gpa, code.items.len);
}

pub fn updateDeclLineNumber(self: *C, module: *Module, decl_index: Module.Decl.Index) !void {
    // The C backend does not have the ability to fix line numbers without re-generating
    // the entire Decl.
    _ = self;
    _ = module;
    _ = decl_index;
}

pub fn flush(self: *C, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    return self.flushModule(comp, prog_node);
}

fn abiDefine(comp: *Compilation) ?[]const u8 {
    return switch (comp.getTarget().abi) {
        .msvc => "#define ZIG_TARGET_ABI_MSVC\n",
        else => null,
    };
}

pub fn flushModule(self: *C, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const gpa = self.base.allocator;
    const module = self.base.options.module.?;

    // This code path happens exclusively with -ofmt=c. The flush logic for
    // emit-h is in `flushEmitH` below.

    var f: Flush = .{};
    defer f.deinit(gpa);

    const abi_define = abiDefine(comp);

    // Covers defines, zig.h, ctypes, asm.
    try f.all_buffers.ensureUnusedCapacity(gpa, 4);

    if (abi_define) |buf| f.appendBufAssumeCapacity(buf);
    f.appendBufAssumeCapacity(zig_h);

    const ctypes_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    {
        var asm_buf = f.asm_buf.toManaged(gpa);
        defer asm_buf.deinit();

        try codegen.genGlobalAsm(module, &asm_buf);

        f.asm_buf = asm_buf.moveToUnmanaged();
        f.appendBufAssumeCapacity(f.asm_buf.items);
    }

    try self.flushErrDecls(&f);

    // `CType`s, forward decls, and non-functions first.
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

    {
        var export_names = std.StringHashMapUnmanaged(void){};
        defer export_names.deinit(gpa);
        try export_names.ensureTotalCapacity(gpa, @intCast(u32, module.decl_exports.entries.len));
        for (module.decl_exports.values()) |exports| for (exports.items) |@"export"|
            try export_names.put(gpa, @"export".options.name, {});

        while (f.remaining_decls.popOrNull()) |kv| {
            const decl_index = kv.key;
            try self.flushDecl(&f, decl_index, export_names);
        }
    }

    f.all_buffers.items[ctypes_index] = .{
        .iov_base = if (f.ctypes_buf.items.len > 0) f.ctypes_buf.items.ptr else "",
        .iov_len = f.ctypes_buf.items.len,
    };
    f.file_size += f.ctypes_buf.items.len;

    // Now the code.
    try f.all_buffers.ensureUnusedCapacity(gpa, decl_values.len);
    for (decl_values) |decl|
        f.appendBufAssumeCapacity(decl.code.items);

    const file = self.base.file.?;
    try file.setEndPos(f.file_size);
    try file.pwritevAll(f.all_buffers.items, 0);
}

const Flush = struct {
    remaining_decls: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, void) = .{},

    ctypes: codegen.CType.Store = .{},
    ctypes_map: std.ArrayListUnmanaged(codegen.CType.Index) = .{},
    ctypes_buf: std.ArrayListUnmanaged(u8) = .{},

    err_decls: DeclBlock = .{},

    lazy_fns: LazyFns = .{},

    asm_buf: std.ArrayListUnmanaged(u8) = .{},
    /// We collect a list of buffers to write, and write them all at once with pwritev 😎
    all_buffers: std.ArrayListUnmanaged(std.os.iovec_const) = .{},
    /// Keeps track of the total bytes of `all_buffers`.
    file_size: u64 = 0,

    const LazyFns = std.AutoHashMapUnmanaged(codegen.LazyFnKey, DeclBlock);

    fn appendBufAssumeCapacity(f: *Flush, buf: []const u8) void {
        if (buf.len == 0) return;
        f.all_buffers.appendAssumeCapacity(.{ .iov_base = buf.ptr, .iov_len = buf.len });
        f.file_size += buf.len;
    }

    fn deinit(f: *Flush, gpa: Allocator) void {
        f.all_buffers.deinit(gpa);
        var lazy_fns_it = f.lazy_fns.valueIterator();
        while (lazy_fns_it.next()) |db| db.deinit(gpa);
        f.lazy_fns.deinit(gpa);
        f.err_decls.deinit(gpa);
        f.ctypes_buf.deinit(gpa);
        f.ctypes_map.deinit(gpa);
        f.ctypes.deinit(gpa);
        f.remaining_decls.deinit(gpa);
    }
};

const FlushDeclError = error{
    OutOfMemory,
};

fn flushCTypes(self: *C, f: *Flush, ctypes: codegen.CType.Store) FlushDeclError!void {
    _ = self;
    _ = f;
    _ = ctypes;
}

fn flushErrDecls(self: *C, f: *Flush) FlushDeclError!void {
    const gpa = self.base.allocator;

    const fwd_decl = &f.err_decls.fwd_decl;
    const ctypes = &f.err_decls.ctypes;
    const code = &f.err_decls.code;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .module = self.base.options.module.?,
            .error_msg = null,
            .decl_index = undefined,
            .decl = undefined,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctypes = ctypes.*,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        object.code.deinit();
        object.dg.ctypes.deinit(gpa);
        object.dg.fwd_decl.deinit();
    }

    codegen.genErrDecls(&object) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        else => |e| return e,
    };

    fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
    ctypes.* = object.dg.ctypes.move();
    code.* = object.code.moveToUnmanaged();

    try self.flushCTypes(f, ctypes.*);
    try f.all_buffers.ensureUnusedCapacity(gpa, 2);
    f.appendBufAssumeCapacity(fwd_decl.items);
    f.appendBufAssumeCapacity(code.items);
}

fn flushLazyFn(
    self: *C,
    f: *Flush,
    db: *DeclBlock,
    lazy_fn: codegen.LazyFnMap.Entry,
) FlushDeclError!void {
    const gpa = self.base.allocator;

    const fwd_decl = &db.fwd_decl;
    const ctypes = &db.ctypes;
    const code = &db.code;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .module = self.base.options.module.?,
            .error_msg = null,
            .decl_index = undefined,
            .decl = undefined,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctypes = ctypes.*,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        object.code.deinit();
        object.dg.ctypes.deinit(gpa);
        object.dg.fwd_decl.deinit();
    }

    codegen.genLazyFn(&object, lazy_fn) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        else => |e| return e,
    };

    fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
    ctypes.* = object.dg.ctypes.move();
    code.* = object.code.moveToUnmanaged();

    try self.flushCTypes(f, ctypes.*);
    try f.all_buffers.ensureUnusedCapacity(gpa, 2);
    f.appendBufAssumeCapacity(fwd_decl.items);
    f.appendBufAssumeCapacity(code.items);
}

fn flushLazyFns(self: *C, f: *Flush, lazy_fns: codegen.LazyFnMap) FlushDeclError!void {
    const gpa = self.base.allocator;
    try f.lazy_fns.ensureUnusedCapacity(gpa, @intCast(Flush.LazyFns.Size, lazy_fns.count()));

    var it = lazy_fns.iterator();
    while (it.next()) |entry| {
        const gop = f.lazy_fns.getOrPutAssumeCapacity(entry.key_ptr.*);
        if (gop.found_existing) continue;
        gop.value_ptr.* = .{};
        try self.flushLazyFn(f, gop.value_ptr, entry);
    }
}

/// Assumes `decl` was in the `remaining_decls` set, and has already been removed.
fn flushDecl(
    self: *C,
    f: *Flush,
    decl_index: Module.Decl.Index,
    export_names: std.StringHashMapUnmanaged(void),
) FlushDeclError!void {
    const gpa = self.base.allocator;
    const decl = self.base.options.module.?.declPtr(decl_index);
    // Before flushing any particular Decl we must ensure its
    // dependencies are already flushed, so that the order in the .c
    // file comes out correctly.
    for (decl.dependencies.keys()) |dep| {
        if (f.remaining_decls.swapRemove(dep)) {
            try flushDecl(self, f, dep, export_names);
        }
    }

    const decl_block = self.decl_table.getPtr(decl_index).?;

    try self.flushCTypes(f, decl_block.ctypes);
    try self.flushLazyFns(f, decl_block.lazy_fns);
    try f.all_buffers.ensureUnusedCapacity(gpa, 1);
    if (!(decl.isExtern() and export_names.contains(mem.span(decl.name))))
        f.appendBufAssumeCapacity(decl_block.fwd_decl.items);
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
    if (zig_h.len != 0) {
        all_buffers.appendAssumeCapacity(.{
            .iov_base = zig_h,
            .iov_len = zig_h.len,
        });
    }

    for (emit_h.decl_table.keys()) |decl_index| {
        const decl_emit_h = emit_h.declPtr(decl_index);
        const buf = decl_emit_h.fwd_decl.items;
        if (buf.len != 0) {
            all_buffers.appendAssumeCapacity(.{
                .iov_base = buf.ptr,
                .iov_len = buf.len,
            });
            file_size += buf.len;
        }
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
