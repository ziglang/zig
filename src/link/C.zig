const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const fs = std.fs;

const C = @This();
const build_options = @import("build_options");
const Zcu = @import("../Module.zig");
const Module = @import("../Package/Module.zig");
const InternPool = @import("../InternPool.zig");
const Alignment = InternPool.Alignment;
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen/c.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const Type = @import("../type.zig").Type;
const Value = @import("../Value.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");

pub const base_tag: link.File.Tag = .c;
pub const zig_h = "#include \"zig.h\"\n";

base: link.File,
/// This linker backend does not try to incrementally link output C source code.
/// Instead, it tracks all declarations in this table, and iterates over it
/// in the flush function, stitching pre-rendered pieces of C code together.
decl_table: std.AutoArrayHashMapUnmanaged(InternPool.DeclIndex, DeclBlock) = .{},
/// All the string bytes of rendered C code, all squished into one array.
/// While in progress, a separate buffer is used, and then when finished, the
/// buffer is copied into this one.
string_bytes: std.ArrayListUnmanaged(u8) = .{},
/// Tracks all the anonymous decls that are used by all the decls so they can
/// be rendered during flush().
anon_decls: std.AutoArrayHashMapUnmanaged(InternPool.Index, DeclBlock) = .{},
/// Sparse set of anon decls that are overaligned. Underaligned anon decls are
/// lowered the same as ABI-aligned anon decls. The keys here are a subset of
/// the keys of `anon_decls`.
aligned_anon_decls: std.AutoArrayHashMapUnmanaged(InternPool.Index, Alignment) = .{},

/// Optimization, `updateDecl` reuses this buffer rather than creating a new
/// one with every call.
fwd_decl_buf: std.ArrayListUnmanaged(u8) = .{},
/// Optimization, `updateDecl` reuses this buffer rather than creating a new
/// one with every call.
code_buf: std.ArrayListUnmanaged(u8) = .{},
/// Optimization, `flush` reuses this buffer rather than creating a new
/// one with every call.
lazy_fwd_decl_buf: std.ArrayListUnmanaged(u8) = .{},
/// Optimization, `flush` reuses this buffer rather than creating a new
/// one with every call.
lazy_code_buf: std.ArrayListUnmanaged(u8) = .{},

/// A reference into `string_bytes`.
const String = extern struct {
    start: u32,
    len: u32,

    const empty: String = .{
        .start = 0,
        .len = 0,
    };
};

/// Per-declaration data.
pub const DeclBlock = struct {
    code: String = String.empty,
    fwd_decl: String = String.empty,
    /// Each `Decl` stores a set of used `CType`s.  In `flush()`, we iterate
    /// over each `Decl` and generate the definition for each used `CType` once.
    ctype_pool: codegen.CType.Pool = codegen.CType.Pool.empty,
    /// May contain string references to ctype_pool
    lazy_fns: codegen.LazyFnMap = .{},

    fn deinit(db: *DeclBlock, gpa: Allocator) void {
        db.lazy_fns.deinit(gpa);
        db.ctype_pool.deinit(gpa);
        db.* = undefined;
    }
};

pub fn getString(this: C, s: String) []const u8 {
    return this.string_bytes.items[s.start..][0..s.len];
}

pub fn addString(this: *C, s: []const u8) Allocator.Error!String {
    const comp = this.base.comp;
    const gpa = comp.gpa;
    try this.string_bytes.appendSlice(gpa, s);
    return .{
        .start = @intCast(this.string_bytes.items.len - s.len),
        .len = @intCast(s.len),
    };
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*C {
    return createEmpty(arena, comp, emit, options);
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*C {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .c);
    const optimize_mode = comp.root_mod.optimize_mode;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;
    const output_mode = comp.config.output_mode;

    // These are caught by `Compilation.Config.resolve`.
    assert(!use_lld);
    assert(!use_llvm);

    const file = try emit.directory.handle.createFile(emit.sub_path, .{
        // Truncation is done on `flush`.
        .truncate = false,
    });
    errdefer file.close();

    const c_file = try arena.create(C);

    c_file.* = .{
        .base = .{
            .tag = .c,
            .comp = comp,
            .emit = emit,
            .gc_sections = options.gc_sections orelse (optimize_mode != .Debug and output_mode != .Obj),
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 16777216,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = file,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
            .rpath_list = options.rpath_list,
        },
    };

    return c_file;
}

pub fn deinit(self: *C) void {
    const gpa = self.base.comp.gpa;

    for (self.decl_table.values()) |*db| {
        db.deinit(gpa);
    }
    self.decl_table.deinit(gpa);

    for (self.anon_decls.values()) |*db| {
        db.deinit(gpa);
    }
    self.anon_decls.deinit(gpa);
    self.aligned_anon_decls.deinit(gpa);

    self.string_bytes.deinit(gpa);
    self.fwd_decl_buf.deinit(gpa);
    self.code_buf.deinit(gpa);
    self.lazy_fwd_decl_buf.deinit(gpa);
    self.lazy_code_buf.deinit(gpa);
}

pub fn freeDecl(self: *C, decl_index: InternPool.DeclIndex) void {
    const gpa = self.base.comp.gpa;
    if (self.decl_table.fetchSwapRemove(decl_index)) |kv| {
        var decl_block = kv.value;
        decl_block.deinit(gpa);
    }
}

pub fn updateFunc(
    self: *C,
    zcu: *Zcu,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) !void {
    const gpa = self.base.comp.gpa;

    const func = zcu.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = zcu.declPtr(decl_index);
    const gop = try self.decl_table.getOrPut(gpa, decl_index);
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const ctype_pool = &gop.value_ptr.ctype_pool;
    const lazy_fns = &gop.value_ptr.lazy_fns;
    const fwd_decl = &self.fwd_decl_buf;
    const code = &self.code_buf;
    try ctype_pool.init(gpa);
    ctype_pool.clearRetainingCapacity();
    lazy_fns.clearRetainingCapacity();
    fwd_decl.clearRetainingCapacity();
    code.clearRetainingCapacity();

    var function: codegen.Function = .{
        .value_map = codegen.CValueMap.init(gpa),
        .air = air,
        .liveness = liveness,
        .func_index = func_index,
        .object = .{
            .dg = .{
                .gpa = gpa,
                .zcu = zcu,
                .mod = zcu.namespacePtr(decl.src_namespace).file_scope.mod,
                .error_msg = null,
                .pass = .{ .decl = decl_index },
                .is_naked_fn = decl.typeOf(zcu).fnCallingConvention(zcu) == .Naked,
                .fwd_decl = fwd_decl.toManaged(gpa),
                .ctype_pool = ctype_pool.*,
                .scratch = .{},
                .anon_decl_deps = self.anon_decls,
                .aligned_anon_decls = self.aligned_anon_decls,
            },
            .code = code.toManaged(gpa),
            .indent_writer = undefined, // set later so we can get a pointer to object.code
        },
        .lazy_fns = lazy_fns.*,
    };
    function.object.indent_writer = .{ .underlying_writer = function.object.code.writer() };
    defer {
        self.anon_decls = function.object.dg.anon_decl_deps;
        self.aligned_anon_decls = function.object.dg.aligned_anon_decls;
        fwd_decl.* = function.object.dg.fwd_decl.moveToUnmanaged();
        ctype_pool.* = function.object.dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);
        function.object.dg.scratch.deinit(gpa);
        lazy_fns.* = function.lazy_fns.move();
        lazy_fns.shrinkAndFree(gpa, lazy_fns.count());
        code.* = function.object.code.moveToUnmanaged();
        function.deinit();
    }

    codegen.genFunc(&function) catch |err| switch (err) {
        error.AnalysisFail => {
            try zcu.failed_decls.put(gpa, decl_index, function.object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };
    gop.value_ptr.fwd_decl = try self.addString(function.object.dg.fwd_decl.items);
    gop.value_ptr.code = try self.addString(function.object.code.items);
}

fn updateAnonDecl(self: *C, zcu: *Zcu, i: usize) !void {
    const gpa = self.base.comp.gpa;
    const anon_decl = self.anon_decls.keys()[i];

    const fwd_decl = &self.fwd_decl_buf;
    const code = &self.code_buf;
    fwd_decl.clearRetainingCapacity();
    code.clearRetainingCapacity();

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .zcu = zcu,
            .mod = zcu.root_mod,
            .error_msg = null,
            .pass = .{ .anon = anon_decl },
            .is_naked_fn = false,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctype_pool = codegen.CType.Pool.empty,
            .scratch = .{},
            .anon_decl_deps = self.anon_decls,
            .aligned_anon_decls = self.aligned_anon_decls,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        self.anon_decls = object.dg.anon_decl_deps;
        self.aligned_anon_decls = object.dg.aligned_anon_decls;
        fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
        object.dg.ctype_pool.deinit(object.dg.gpa);
        object.dg.scratch.deinit(gpa);
        code.* = object.code.moveToUnmanaged();
    }
    try object.dg.ctype_pool.init(gpa);

    const c_value: codegen.CValue = .{ .constant = Value.fromInterned(anon_decl) };
    const alignment: Alignment = self.aligned_anon_decls.get(anon_decl) orelse .none;
    codegen.genDeclValue(&object, c_value.constant, false, c_value, alignment, .none) catch |err| switch (err) {
        error.AnalysisFail => {
            @panic("TODO: C backend AnalysisFail on anonymous decl");
            //try zcu.failed_decls.put(gpa, decl_index, object.dg.error_msg.?);
            //return;
        },
        else => |e| return e,
    };

    object.dg.ctype_pool.freeUnusedCapacity(gpa);
    object.dg.anon_decl_deps.values()[i] = .{
        .code = try self.addString(object.code.items),
        .fwd_decl = try self.addString(object.dg.fwd_decl.items),
        .ctype_pool = object.dg.ctype_pool.move(),
    };
}

pub fn updateDecl(self: *C, zcu: *Zcu, decl_index: InternPool.DeclIndex) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    const decl = zcu.declPtr(decl_index);
    const gop = try self.decl_table.getOrPut(gpa, decl_index);
    errdefer _ = self.decl_table.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const ctype_pool = &gop.value_ptr.ctype_pool;
    const fwd_decl = &self.fwd_decl_buf;
    const code = &self.code_buf;
    try ctype_pool.init(gpa);
    ctype_pool.clearRetainingCapacity();
    fwd_decl.clearRetainingCapacity();
    code.clearRetainingCapacity();

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .zcu = zcu,
            .mod = zcu.namespacePtr(decl.src_namespace).file_scope.mod,
            .error_msg = null,
            .pass = .{ .decl = decl_index },
            .is_naked_fn = false,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctype_pool = ctype_pool.*,
            .scratch = .{},
            .anon_decl_deps = self.anon_decls,
            .aligned_anon_decls = self.aligned_anon_decls,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        self.anon_decls = object.dg.anon_decl_deps;
        self.aligned_anon_decls = object.dg.aligned_anon_decls;
        fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
        ctype_pool.* = object.dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);
        object.dg.scratch.deinit(gpa);
        code.* = object.code.moveToUnmanaged();
    }

    codegen.genDecl(&object) catch |err| switch (err) {
        error.AnalysisFail => {
            try zcu.failed_decls.put(gpa, decl_index, object.dg.error_msg.?);
            return;
        },
        else => |e| return e,
    };
    gop.value_ptr.code = try self.addString(object.code.items);
    gop.value_ptr.fwd_decl = try self.addString(object.dg.fwd_decl.items);
}

pub fn updateDeclLineNumber(self: *C, zcu: *Zcu, decl_index: InternPool.DeclIndex) !void {
    // The C backend does not have the ability to fix line numbers without re-generating
    // the entire Decl.
    _ = self;
    _ = zcu;
    _ = decl_index;
}

pub fn flush(self: *C, arena: Allocator, prog_node: std.Progress.Node) !void {
    return self.flushModule(arena, prog_node);
}

fn abiDefines(self: *C, target: std.Target) !std.ArrayList(u8) {
    const gpa = self.base.comp.gpa;
    var defines = std.ArrayList(u8).init(gpa);
    errdefer defines.deinit();
    const writer = defines.writer();
    switch (target.abi) {
        .msvc => try writer.writeAll("#define ZIG_TARGET_ABI_MSVC\n"),
        else => {},
    }
    try writer.print("#define ZIG_TARGET_MAX_INT_ALIGNMENT {d}\n", .{
        Type.maxIntAlignment(target, false),
    });
    return defines;
}

pub fn flushModule(self: *C, arena: Allocator, prog_node: std.Progress.Node) !void {
    _ = arena; // Has the same lifetime as the call to Compilation.update.

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Flush Module", 0);
    defer sub_prog_node.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const zcu = self.base.comp.module.?;

    {
        var i: usize = 0;
        while (i < self.anon_decls.count()) : (i += 1) {
            try updateAnonDecl(self, zcu, i);
        }
    }

    // This code path happens exclusively with -ofmt=c. The flush logic for
    // emit-h is in `flushEmitH` below.

    var f: Flush = .{
        .ctype_pool = codegen.CType.Pool.empty,
        .lazy_ctype_pool = codegen.CType.Pool.empty,
    };
    defer f.deinit(gpa);

    const abi_defines = try self.abiDefines(zcu.getTarget());
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
        try codegen.genGlobalAsm(zcu, asm_buf.writer());
        f.appendBufAssumeCapacity(asm_buf.items);
    }

    const lazy_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    self.lazy_fwd_decl_buf.clearRetainingCapacity();
    self.lazy_code_buf.clearRetainingCapacity();
    try f.lazy_ctype_pool.init(gpa);
    try self.flushErrDecls(zcu, &f.lazy_ctype_pool);

    // Unlike other backends, the .c code we are emitting has order-dependent decls.
    // `CType`s, forward decls, and non-functions first.

    {
        var export_names: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void) = .{};
        defer export_names.deinit(gpa);
        try export_names.ensureTotalCapacity(gpa, @intCast(zcu.decl_exports.entries.len));
        for (zcu.decl_exports.values()) |exports| for (exports.items) |@"export"|
            try export_names.put(gpa, @"export".opts.name, {});

        for (self.anon_decls.values()) |*decl_block| {
            try self.flushDeclBlock(zcu, zcu.root_mod, &f, decl_block, export_names, .none);
        }

        for (self.decl_table.keys(), self.decl_table.values()) |decl_index, *decl_block| {
            const decl = zcu.declPtr(decl_index);
            assert(decl.has_tv);
            const extern_symbol_name = if (decl.isExtern(zcu)) decl.name.toOptional() else .none;
            const mod = zcu.namespacePtr(decl.src_namespace).file_scope.mod;
            try self.flushDeclBlock(zcu, mod, &f, decl_block, export_names, extern_symbol_name);
        }
    }

    {
        // We need to flush lazy ctypes after flushing all decls but before flushing any decl ctypes.
        // This ensures that every lazy CType.Index exactly matches the global CType.Index.
        try f.ctype_pool.init(gpa);
        try self.flushCTypes(zcu, &f, .flush, &f.lazy_ctype_pool);

        for (self.anon_decls.keys(), self.anon_decls.values()) |anon_decl, decl_block| {
            try self.flushCTypes(zcu, &f, .{ .anon = anon_decl }, &decl_block.ctype_pool);
        }

        for (self.decl_table.keys(), self.decl_table.values()) |decl_index, decl_block| {
            try self.flushCTypes(zcu, &f, .{ .decl = decl_index }, &decl_block.ctype_pool);
        }
    }

    f.all_buffers.items[ctypes_index] = .{
        .base = if (f.ctypes_buf.items.len > 0) f.ctypes_buf.items.ptr else "",
        .len = f.ctypes_buf.items.len,
    };
    f.file_size += f.ctypes_buf.items.len;

    const lazy_fwd_decl_len = self.lazy_fwd_decl_buf.items.len;
    f.all_buffers.items[lazy_index] = .{
        .base = if (lazy_fwd_decl_len > 0) self.lazy_fwd_decl_buf.items.ptr else "",
        .len = lazy_fwd_decl_len,
    };
    f.file_size += lazy_fwd_decl_len;

    // Now the code.
    const anon_decl_values = self.anon_decls.values();
    const decl_values = self.decl_table.values();
    try f.all_buffers.ensureUnusedCapacity(gpa, 1 + anon_decl_values.len + decl_values.len);
    f.appendBufAssumeCapacity(self.lazy_code_buf.items);
    for (anon_decl_values) |db| f.appendBufAssumeCapacity(self.getString(db.code));
    for (decl_values) |db| f.appendBufAssumeCapacity(self.getString(db.code));

    const file = self.base.file.?;
    try file.setEndPos(f.file_size);
    try file.pwritevAll(f.all_buffers.items, 0);
}

const Flush = struct {
    ctype_pool: codegen.CType.Pool,
    ctype_global_from_decl_map: std.ArrayListUnmanaged(codegen.CType) = .{},
    ctypes_buf: std.ArrayListUnmanaged(u8) = .{},

    lazy_ctype_pool: codegen.CType.Pool,
    lazy_fns: LazyFns = .{},

    asm_buf: std.ArrayListUnmanaged(u8) = .{},

    /// We collect a list of buffers to write, and write them all at once with pwritev 😎
    all_buffers: std.ArrayListUnmanaged(std.posix.iovec_const) = .{},
    /// Keeps track of the total bytes of `all_buffers`.
    file_size: u64 = 0,

    const LazyFns = std.AutoHashMapUnmanaged(codegen.LazyFnKey, void);

    fn appendBufAssumeCapacity(f: *Flush, buf: []const u8) void {
        if (buf.len == 0) return;
        f.all_buffers.appendAssumeCapacity(.{ .base = buf.ptr, .len = buf.len });
        f.file_size += buf.len;
    }

    fn deinit(f: *Flush, gpa: Allocator) void {
        f.all_buffers.deinit(gpa);
        f.asm_buf.deinit(gpa);
        f.lazy_fns.deinit(gpa);
        f.lazy_ctype_pool.deinit(gpa);
        f.ctypes_buf.deinit(gpa);
        assert(f.ctype_global_from_decl_map.items.len == 0);
        f.ctype_global_from_decl_map.deinit(gpa);
        f.ctype_pool.deinit(gpa);
    }
};

const FlushDeclError = error{
    OutOfMemory,
};

fn flushCTypes(
    self: *C,
    zcu: *Zcu,
    f: *Flush,
    pass: codegen.DeclGen.Pass,
    decl_ctype_pool: *const codegen.CType.Pool,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;
    const global_ctype_pool = &f.ctype_pool;

    const global_from_decl_map = &f.ctype_global_from_decl_map;
    assert(global_from_decl_map.items.len == 0);
    try global_from_decl_map.ensureTotalCapacity(gpa, decl_ctype_pool.items.len);
    defer global_from_decl_map.clearRetainingCapacity();

    var ctypes_buf = f.ctypes_buf.toManaged(gpa);
    defer f.ctypes_buf = ctypes_buf.moveToUnmanaged();
    const writer = ctypes_buf.writer();

    for (0..decl_ctype_pool.items.len) |decl_ctype_pool_index| {
        const PoolAdapter = struct {
            global_from_decl_map: []const codegen.CType,
            pub fn eql(pool_adapter: @This(), decl_ctype: codegen.CType, global_ctype: codegen.CType) bool {
                return if (decl_ctype.toPoolIndex()) |decl_pool_index|
                    decl_pool_index < pool_adapter.global_from_decl_map.len and
                        pool_adapter.global_from_decl_map[decl_pool_index].eql(global_ctype)
                else
                    decl_ctype.index == global_ctype.index;
            }
            pub fn copy(pool_adapter: @This(), decl_ctype: codegen.CType) codegen.CType {
                return if (decl_ctype.toPoolIndex()) |decl_pool_index|
                    pool_adapter.global_from_decl_map[decl_pool_index]
                else
                    decl_ctype;
            }
        };
        const decl_ctype = codegen.CType.fromPoolIndex(decl_ctype_pool_index);
        const global_ctype, const found_existing = try global_ctype_pool.getOrPutAdapted(
            gpa,
            decl_ctype_pool,
            decl_ctype,
            PoolAdapter{ .global_from_decl_map = global_from_decl_map.items },
        );
        global_from_decl_map.appendAssumeCapacity(global_ctype);
        try codegen.genTypeDecl(
            zcu,
            writer,
            global_ctype_pool,
            global_ctype,
            pass,
            decl_ctype_pool,
            decl_ctype,
            found_existing,
        );
    }
}

fn flushErrDecls(self: *C, zcu: *Zcu, ctype_pool: *codegen.CType.Pool) FlushDeclError!void {
    const gpa = self.base.comp.gpa;

    const fwd_decl = &self.lazy_fwd_decl_buf;
    const code = &self.lazy_code_buf;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .zcu = zcu,
            .mod = zcu.root_mod,
            .error_msg = null,
            .pass = .flush,
            .is_naked_fn = false,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctype_pool = ctype_pool.*,
            .scratch = .{},
            .anon_decl_deps = self.anon_decls,
            .aligned_anon_decls = self.aligned_anon_decls,
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        self.anon_decls = object.dg.anon_decl_deps;
        self.aligned_anon_decls = object.dg.aligned_anon_decls;
        fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
        ctype_pool.* = object.dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);
        object.dg.scratch.deinit(gpa);
        code.* = object.code.moveToUnmanaged();
    }

    codegen.genErrDecls(&object) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        else => |e| return e,
    };
}

fn flushLazyFn(
    self: *C,
    zcu: *Zcu,
    mod: *Module,
    ctype_pool: *codegen.CType.Pool,
    lazy_ctype_pool: *const codegen.CType.Pool,
    lazy_fn: codegen.LazyFnMap.Entry,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;

    const fwd_decl = &self.lazy_fwd_decl_buf;
    const code = &self.lazy_code_buf;

    var object = codegen.Object{
        .dg = .{
            .gpa = gpa,
            .zcu = zcu,
            .mod = mod,
            .error_msg = null,
            .pass = .flush,
            .is_naked_fn = false,
            .fwd_decl = fwd_decl.toManaged(gpa),
            .ctype_pool = ctype_pool.*,
            .scratch = .{},
            .anon_decl_deps = .{},
            .aligned_anon_decls = .{},
        },
        .code = code.toManaged(gpa),
        .indent_writer = undefined, // set later so we can get a pointer to object.code
    };
    object.indent_writer = .{ .underlying_writer = object.code.writer() };
    defer {
        // If this assert trips just handle the anon_decl_deps the same as
        // `updateFunc()` does.
        assert(object.dg.anon_decl_deps.count() == 0);
        assert(object.dg.aligned_anon_decls.count() == 0);
        fwd_decl.* = object.dg.fwd_decl.moveToUnmanaged();
        ctype_pool.* = object.dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);
        object.dg.scratch.deinit(gpa);
        code.* = object.code.moveToUnmanaged();
    }

    codegen.genLazyFn(&object, lazy_ctype_pool, lazy_fn) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        else => |e| return e,
    };
}

fn flushLazyFns(
    self: *C,
    zcu: *Zcu,
    mod: *Module,
    f: *Flush,
    lazy_ctype_pool: *const codegen.CType.Pool,
    lazy_fns: codegen.LazyFnMap,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;
    try f.lazy_fns.ensureUnusedCapacity(gpa, @intCast(lazy_fns.count()));

    var it = lazy_fns.iterator();
    while (it.next()) |entry| {
        const gop = f.lazy_fns.getOrPutAssumeCapacity(entry.key_ptr.*);
        if (gop.found_existing) continue;
        gop.value_ptr.* = {};
        try self.flushLazyFn(zcu, mod, &f.lazy_ctype_pool, lazy_ctype_pool, entry);
    }
}

fn flushDeclBlock(
    self: *C,
    zcu: *Zcu,
    mod: *Module,
    f: *Flush,
    decl_block: *DeclBlock,
    export_names: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void),
    extern_symbol_name: InternPool.OptionalNullTerminatedString,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;
    try self.flushLazyFns(zcu, mod, f, &decl_block.ctype_pool, decl_block.lazy_fns);
    try f.all_buffers.ensureUnusedCapacity(gpa, 1);
    fwd_decl: {
        if (extern_symbol_name.unwrap()) |name| {
            if (export_names.contains(name)) break :fwd_decl;
        }
        f.appendBufAssumeCapacity(self.getString(decl_block.fwd_decl));
    }
}

pub fn flushEmitH(zcu: *Zcu) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const emit_h = zcu.emit_h orelse return;

    // We collect a list of buffers to write, and write them all at once with pwritev 😎
    const num_buffers = emit_h.decl_table.count() + 1;
    var all_buffers = try std.ArrayList(std.posix.iovec_const).initCapacity(zcu.gpa, num_buffers);
    defer all_buffers.deinit();

    var file_size: u64 = zig_h.len;
    if (zig_h.len != 0) {
        all_buffers.appendAssumeCapacity(.{
            .base = zig_h,
            .len = zig_h.len,
        });
    }

    for (emit_h.decl_table.keys()) |decl_index| {
        const decl_emit_h = emit_h.declPtr(decl_index);
        const buf = decl_emit_h.fwd_decl.items;
        if (buf.len != 0) {
            all_buffers.appendAssumeCapacity(.{
                .base = buf.ptr,
                .len = buf.len,
            });
            file_size += buf.len;
        }
    }

    const directory = emit_h.loc.directory orelse zcu.comp.local_cache_directory;
    const file = try directory.handle.createFile(emit_h.loc.basename, .{
        // We set the end position explicitly below; by not truncating the file, we possibly
        // make it easier on the file system by doing 1 reallocation instead of two.
        .truncate = false,
    });
    defer file.close();

    try file.setEndPos(file_size);
    try file.pwritevAll(all_buffers.items, 0);
}

pub fn updateExports(
    self: *C,
    zcu: *Zcu,
    exported: Zcu.Exported,
    exports: []const *Zcu.Export,
) !void {
    _ = exports;
    _ = exported;
    _ = zcu;
    _ = self;
}
