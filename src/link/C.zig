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
                .decl_index = decl_index.toOptional(),
                .decl = module.declPtr(decl_index),
                .fwd_decl = fwd_decl.toManaged(gpa),
                .ctypes = ctypes.*,
            },
            .code = code.toManaged(gpa),
            .indent_writer = undefined, // set later so we can get a pointer to object.code
        },
        .lazy_fns = lazy_fns.*,
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
    ctypes.shrinkAndFree(gpa, ctypes.count());
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
            .decl_index = decl_index.toOptional(),
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
    ctypes.shrinkAndFree(gpa, ctypes.count());
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

fn abiDefines(self: *C, target: std.Target) !std.ArrayList(u8) {
    var defines = std.ArrayList(u8).init(self.base.allocator);
    errdefer defines.deinit();
    const writer = defines.writer();
    switch (target.abi) {
        .msvc => try writer.writeAll("#define ZIG_TARGET_ABI_MSVC\n"),
        else => {},
    }
    try writer.print("#define ZIG_TARGET_MAX_INT_ALIGNMENT {d}\n", .{target.maxIntAlignment()});
    return defines;
}

pub fn flushModule(self: *C, _: *Compilation, prog_node: *std.Progress.Node) !void {
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

    const abi_defines = try self.abiDefines(module.getTarget());
    defer abi_defines.deinit();

    // Covers defines, zig.h, ctypes, asm, lazy fwd.
    try f.all_buffers.ensureUnusedCapacity(gpa, 5);

    f.appendBufAssumeCapacity(abi_defines.items);
    f.appendBufAssumeCapacity(zig_h);

    const ctypes_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    {
        var asm_buf = f.asm_buf.toManaged(gpa);
        defer f.asm_buf = asm_buf.moveToUnmanaged();
        try codegen.genGlobalAsm(module, asm_buf.writer());
        f.appendBufAssumeCapacity(asm_buf.items);
    }

    const lazy_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    try self.flushErrDecls(&f.lazy_db);

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

    {
        // We need to flush lazy ctypes after flushing all decls but before flushing any decl ctypes.
        // This ensures that every lazy CType.Index exactly matches the global CType.Index.
        assert(f.ctypes.count() == 0);
        try self.flushCTypes(&f, .none, f.lazy_db.ctypes);

        var it = self.decl_table.iterator();
        while (it.next()) |entry|
            try self.flushCTypes(&f, entry.key_ptr.toOptional(), entry.value_ptr.ctypes);
    }

    f.all_buffers.items[ctypes_index] = .{
        .iov_base = if (f.ctypes_buf.items.len > 0) f.ctypes_buf.items.ptr else "",
        .iov_len = f.ctypes_buf.items.len,
    };
    f.file_size += f.ctypes_buf.items.len;

    f.all_buffers.items[lazy_index] = .{
        .iov_base = if (f.lazy_db.fwd_decl.items.len > 0) f.lazy_db.fwd_decl.items.ptr else "",
        .iov_len = f.lazy_db.fwd_decl.items.len,
    };
    f.file_size += f.lazy_db.fwd_decl.items.len;

    // Now the code.
    try f.all_buffers.ensureUnusedCapacity(gpa, 1 + decl_values.len);
    f.appendBufAssumeCapacity(f.lazy_db.code.items);
    for (decl_values) |decl| f.appendBufAssumeCapacity(decl.code.items);

    const file = self.base.file.?;
    try file.setEndPos(f.file_size);
    try file.pwritevAll(f.all_buffers.items, 0);
}

const Flush = struct {
    remaining_decls: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, void) = .{},

    ctypes: codegen.CType.Store = .{},
    ctypes_map: std.ArrayListUnmanaged(codegen.CType.Index) = .{},
    ctypes_buf: std.ArrayListUnmanaged(u8) = .{},

    lazy_db: DeclBlock = .{},
    lazy_fns: LazyFns = .{},

    asm_buf: std.ArrayListUnmanaged(u8) = .{},

    /// We collect a list of buffers to write, and write them all at once with pwritev 😎
    all_buffers: std.ArrayListUnmanaged(std.os.iovec_const) = .{},
    /// Keeps track of the total bytes of `all_buffers`.
    file_size: u64 = 0,

    const LazyFns = std.AutoHashMapUnmanaged(codegen.LazyFnKey, void);

    fn appendBufAssumeCapacity(f: *Flush, buf: []const u8) void {
        if (buf.len == 0) return;
        f.all_buffers.appendAssumeCapacity(.{ .iov_base = buf.ptr, .iov_len = buf.len });
        f.file_size += buf.len;
    }

    fn deinit(f: *Flush, gpa: Allocator) void {
        f.all_buffers.deinit(gpa);
        f.asm_buf.deinit(gpa);
        f.lazy_fns.deinit(gpa);
        f.lazy_db.deinit(gpa);
        f.ctypes_buf.deinit(gpa);
        f.ctypes_map.deinit(gpa);
        f.ctypes.deinit(gpa);
        f.remaining_decls.deinit(gpa);
    }
};

const FlushDeclError = error{
    OutOfMemory,
};

fn flushCTypes(
    self: *C,
    f: *Flush,
    decl_index: Module.Decl.OptionalIndex,
    decl_ctypes: codegen.CType.Store,
) FlushDeclError!void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;

    const decl_ctypes_len = decl_ctypes.count();
    f.ctypes_map.clearRetainingCapacity();
    try f.ctypes_map.ensureTotalCapacity(gpa, decl_ctypes_len);

    var global_ctypes = f.ctypes.promote(gpa);
    defer f.ctypes.demote(global_ctypes);

    var ctypes_buf = f.ctypes_buf.toManaged(gpa);
    defer f.ctypes_buf = ctypes_buf.moveToUnmanaged();
    const writer = ctypes_buf.writer();

    const slice = decl_ctypes.set.map.entries.slice();
    for (slice.items(.key), 0..) |decl_cty, decl_i| {
        const Context = struct {
            arena: Allocator,
            ctypes_map: []codegen.CType.Index,
            cached_hash: codegen.CType.Store.Set.Map.Hash,
            idx: codegen.CType.Index,

            pub fn hash(ctx: @This(), _: codegen.CType) codegen.CType.Store.Set.Map.Hash {
                return ctx.cached_hash;
            }
            pub fn eql(ctx: @This(), lhs: codegen.CType, rhs: codegen.CType, _: usize) bool {
                return lhs.eqlContext(rhs, ctx);
            }
            pub fn eqlIndex(
                ctx: @This(),
                lhs_idx: codegen.CType.Index,
                rhs_idx: codegen.CType.Index,
            ) bool {
                if (lhs_idx < codegen.CType.Tag.no_payload_count or
                    rhs_idx < codegen.CType.Tag.no_payload_count) return lhs_idx == rhs_idx;
                const lhs_i = lhs_idx - codegen.CType.Tag.no_payload_count;
                if (lhs_i >= ctx.ctypes_map.len) return false;
                return ctx.ctypes_map[lhs_i] == rhs_idx;
            }
            pub fn copyIndex(ctx: @This(), idx: codegen.CType.Index) codegen.CType.Index {
                if (idx < codegen.CType.Tag.no_payload_count) return idx;
                return ctx.ctypes_map[idx - codegen.CType.Tag.no_payload_count];
            }
        };
        const decl_idx = @intCast(codegen.CType.Index, codegen.CType.Tag.no_payload_count + decl_i);
        const ctx = Context{
            .arena = global_ctypes.arena.allocator(),
            .ctypes_map = f.ctypes_map.items,
            .cached_hash = decl_ctypes.indexToHash(decl_idx),
            .idx = decl_idx,
        };
        const gop = try global_ctypes.set.map.getOrPutContextAdapted(gpa, decl_cty, ctx, .{
            .store = &global_ctypes.set,
        });
        const global_idx =
            @intCast(codegen.CType.Index, codegen.CType.Tag.no_payload_count + gop.index);
        f.ctypes_map.appendAssumeCapacity(global_idx);
        if (!gop.found_existing) {
            errdefer _ = global_ctypes.set.map.pop();
            gop.key_ptr.* = try decl_cty.copyContext(ctx);
        }
        if (std.debug.runtime_safety) {
            const global_cty = &global_ctypes.set.map.entries.items(.key)[gop.index];
            assert(global_cty == gop.key_ptr);
            assert(decl_cty.eqlContext(global_cty.*, ctx));
            assert(decl_cty.hash(decl_ctypes.set) == global_cty.hash(global_ctypes.set));
        }
        try codegen.genTypeDecl(
            mod,
            writer,
            global_ctypes.set,
            global_idx,
            decl_index,
            decl_ctypes.set,
            decl_idx,
            gop.found_existing,
        );
    }
}

fn flushErrDecls(self: *C, db: *DeclBlock) FlushDeclError!void {
    const gpa = self.base.allocator;

    const fwd_decl = &db.fwd_decl;
    const ctypes = &db.ctypes;
    const code = &db.code;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .module = self.base.options.module.?,
            .error_msg = null,
            .decl_index = .none,
            .decl = null,
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
}

fn flushLazyFn(self: *C, db: *DeclBlock, lazy_fn: codegen.LazyFnMap.Entry) FlushDeclError!void {
    const gpa = self.base.allocator;

    const fwd_decl = &db.fwd_decl;
    const ctypes = &db.ctypes;
    const code = &db.code;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .module = self.base.options.module.?,
            .error_msg = null,
            .decl_index = .none,
            .decl = null,
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
}

fn flushLazyFns(self: *C, f: *Flush, lazy_fns: codegen.LazyFnMap) FlushDeclError!void {
    const gpa = self.base.allocator;
    try f.lazy_fns.ensureUnusedCapacity(gpa, @intCast(Flush.LazyFns.Size, lazy_fns.count()));

    var it = lazy_fns.iterator();
    while (it.next()) |entry| {
        const gop = f.lazy_fns.getOrPutAssumeCapacity(entry.key_ptr.*);
        if (gop.found_existing) continue;
        gop.value_ptr.* = {};
        try self.flushLazyFn(&f.lazy_db, entry);
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
