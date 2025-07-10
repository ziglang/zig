const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const Path = std.Build.Cache.Path;

const C = @This();
const build_options = @import("build_options");
const Zcu = @import("../Zcu.zig");
const Module = @import("../Package/Module.zig");
const InternPool = @import("../InternPool.zig");
const Alignment = InternPool.Alignment;
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen/c.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const AnyMir = @import("../codegen.zig").AnyMir;

pub const zig_h = "#include \"zig.h\"\n";

base: link.File,
/// This linker backend does not try to incrementally link output C source code.
/// Instead, it tracks all declarations in this table, and iterates over it
/// in the flush function, stitching pre-rendered pieces of C code together.
navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, AvBlock),
/// All the string bytes of rendered C code, all squished into one array.
/// While in progress, a separate buffer is used, and then when finished, the
/// buffer is copied into this one.
string_bytes: std.ArrayListUnmanaged(u8),
/// Tracks all the anonymous decls that are used by all the decls so they can
/// be rendered during flush().
uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, AvBlock),
/// Sparse set of uavs that are overaligned. Underaligned anon decls are
/// lowered the same as ABI-aligned anon decls. The keys here are a subset of
/// the keys of `uavs`.
aligned_uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, Alignment),

exported_navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, ExportedBlock),
exported_uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, ExportedBlock),

/// Optimization, `updateDecl` reuses this buffer rather than creating a new
/// one with every call.
fwd_decl_buf: []u8,
/// Optimization, `updateDecl` reuses this buffer rather than creating a new
/// one with every call.
code_header_buf: []u8,
/// Optimization, `updateDecl` reuses this buffer rather than creating a new
/// one with every call.
code_buf: []u8,
/// Optimization, `flush` reuses this buffer rather than creating a new
/// one with every call.
scratch_buf: []u32,

/// A reference into `string_bytes`.
const String = extern struct {
    start: u32,
    len: u32,

    const empty: String = .{
        .start = 0,
        .len = 0,
    };

    fn concat(lhs: String, rhs: String) String {
        assert(lhs.start + lhs.len == rhs.start);
        return .{
            .start = lhs.start,
            .len = lhs.len + rhs.len,
        };
    }
};

/// Per-declaration data.
pub const AvBlock = struct {
    fwd_decl: String = .empty,
    code: String = .empty,
    /// Each `Decl` stores a set of used `CType`s.  In `flush()`, we iterate
    /// over each `Decl` and generate the definition for each used `CType` once.
    ctype_pool: codegen.CType.Pool = .empty,
    /// May contain string references to ctype_pool
    lazy_fns: codegen.LazyFnMap = .{},

    fn deinit(ab: *AvBlock, gpa: Allocator) void {
        ab.lazy_fns.deinit(gpa);
        ab.ctype_pool.deinit(gpa);
        ab.* = undefined;
    }
};

/// Per-exported-symbol data.
pub const ExportedBlock = struct {
    fwd_decl: String = .empty,
};

pub fn getString(this: C, s: String) []const u8 {
    return this.string_bytes.items[s.start..][0..s.len];
}

pub fn addString(this: *C, writers: []const *std.io.AllocatingWriter) Allocator.Error!String {
    const comp = this.base.comp;
    const gpa = comp.gpa;
    const start = this.string_bytes.items.len;
    for (writers) |writer| try this.string_bytes.appendSlice(gpa, writer.getWritten());
    return .{
        .start = @intCast(start),
        .len = @intCast(this.string_bytes.items.len - start),
    };
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*C {
    return createEmpty(arena, comp, emit, options);
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*C {
    const target = &comp.root_mod.resolved_target.result;
    assert(target.ofmt == .c);
    const optimize_mode = comp.root_mod.optimize_mode;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;
    const output_mode = comp.config.output_mode;

    // These are caught by `Compilation.Config.resolve`.
    assert(!use_lld);
    assert(!use_llvm);

    const file = try emit.root_dir.handle.createFile(emit.sub_path, .{
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
            .build_id = options.build_id,
        },
        .navs = .empty,
        .string_bytes = .empty,
        .uavs = .empty,
        .aligned_uavs = .empty,
        .exported_navs = .empty,
        .exported_uavs = .empty,
        .fwd_decl_buf = &.{},
        .code_header_buf = &.{},
        .code_buf = &.{},
        .scratch_buf = &.{},
    };

    return c_file;
}

pub fn deinit(self: *C) void {
    const gpa = self.base.comp.gpa;

    for (self.navs.values()) |*db| {
        db.deinit(gpa);
    }
    self.navs.deinit(gpa);

    for (self.uavs.values()) |*db| {
        db.deinit(gpa);
    }
    self.uavs.deinit(gpa);
    self.aligned_uavs.deinit(gpa);

    self.exported_navs.deinit(gpa);
    self.exported_uavs.deinit(gpa);

    self.string_bytes.deinit(gpa);
    gpa.free(self.fwd_decl_buf);
    gpa.free(self.code_header_buf);
    gpa.free(self.code_buf);
    gpa.free(self.scratch_buf);
}

pub fn updateFunc(
    self: *C,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *AnyMir,
) link.File.UpdateNavError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);

    const gop = try self.navs.getOrPut(gpa, func.owner_nav);
    if (gop.found_existing) gop.value_ptr.deinit(gpa);
    gop.value_ptr.* = .{
        .code = .empty,
        .fwd_decl = .empty,
        .ctype_pool = mir.c.ctype_pool.move(),
        .lazy_fns = mir.c.lazy_fns.move(),
    };
    gop.value_ptr.fwd_decl = try self.addString(mir.c.fwd_decl);
    const code_header = try self.addString(mir.c.code_header);
    const code = try self.addString(mir.c.code);
    gop.value_ptr.code = code_header.concat(code);
    try self.addUavsFromCodegen(&mir.c.uavs);
}

fn updateUav(self: *C, pt: Zcu.PerThread, i: usize) link.File.FlushError!void {
    const gpa = self.base.comp.gpa;
    const uav = self.uavs.keys()[i];

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .pt = pt,
            .mod = pt.zcu.root_mod,
            .error_msg = null,
            .pass = .{ .uav = uav },
            .is_naked_fn = false,
            .expected_block = null,
            .fwd_decl = undefined,
            .ctype_pool = .empty,
            .scratch = .initBuffer(self.scratch_buf),
            .uavs = .empty,
        },
        .code_header = undefined,
        .code = undefined,
        .indent_counter = 0,
    };
    object.dg.fwd_decl = .initOwnedSlice(gpa, self.fwd_decl_buf);
    object.code = .initOwnedSlice(gpa, self.code_buf);
    defer {
        object.dg.uavs.deinit(gpa);
        object.dg.ctype_pool.deinit(object.dg.gpa);

        self.fwd_decl_buf = object.dg.fwd_decl.toArrayList().allocatedSlice();
        self.code_buf = object.code.toArrayList().allocatedSlice();
        self.scratch_buf = object.dg.scratch.allocatedSlice();
    }
    try object.dg.ctype_pool.init(gpa);

    const c_value: codegen.CValue = .{ .constant = Value.fromInterned(uav) };
    const alignment: Alignment = self.aligned_uavs.get(uav) orelse .none;
    codegen.genDeclValue(&object, c_value.constant, c_value, alignment, .none) catch |err| switch (err) {
        error.AnalysisFail => {
            @panic("TODO: C backend AnalysisFail on anonymous decl");
            //try zcu.failed_decls.put(gpa, decl_index, object.dg.error_msg.?);
            //return;
        },
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };

    try self.addUavsFromCodegen(&object.dg.uavs);

    object.dg.ctype_pool.freeUnusedCapacity(gpa);
    self.uavs.values()[i] = .{
        .fwd_decl = try self.addString(object.dg.fwd_decl.getWritten()),
        .code = try self.addString(object.code.getWritten()),
        .ctype_pool = object.dg.ctype_pool.move(),
    };
}

pub fn updateNav(self: *C, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) link.File.UpdateNavError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const nav = ip.getNav(nav_index);
    const nav_init = switch (ip.indexToKey(nav.status.fully_resolved.val)) {
        .func => return,
        .@"extern" => .none,
        .variable => |variable| variable.init,
        else => nav.status.fully_resolved.val,
    };
    if (nav_init != .none and !Value.fromInterned(nav_init).typeOf(zcu).hasRuntimeBits(zcu)) return;

    const gop = try self.navs.getOrPut(gpa, nav_index);
    errdefer _ = self.navs.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const ctype_pool = &gop.value_ptr.ctype_pool;
    try ctype_pool.init(gpa);
    ctype_pool.clearRetainingCapacity();

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .pt = pt,
            .mod = zcu.navFileScope(nav_index).mod.?,
            .error_msg = null,
            .pass = .{ .nav = nav_index },
            .is_naked_fn = false,
            .expected_block = null,
            .fwd_decl = undefined,
            .ctype_pool = ctype_pool.*,
            .scratch = .initBuffer(self.scratch_buf),
            .uavs = .empty,
        },
        .code_header = undefined,
        .code = undefined,
        .indent_counter = 0,
    };
    object.dg.fwd_decl = .initOwnedSlice(gpa, self.fwd_decl_buf);
    object.code = .initOwnedSlice(gpa, self.code_buf);
    defer {
        object.dg.uavs.deinit(gpa);
        ctype_pool.* = object.dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);

        self.fwd_decl_buf = object.dg.fwd_decl.toArrayList().allocatedSlice();
        self.code_buf = object.code.toArrayList().allocatedSlice();
        self.scratch_buf = object.dg.scratch.allocatedSlice();
    }

    codegen.genDecl(&object) catch |err| switch (err) {
        error.AnalysisFail => switch (zcu.codegenFailMsg(nav_index, object.dg.error_msg.?)) {
            error.CodegenFail => return,
            error.OutOfMemory => |e| return e,
        },
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };
    gop.value_ptr.fwd_decl = try self.addString(object.dg.fwd_decl.getWritten());
    gop.value_ptr.code = try self.addString(object.code.getWritten());
    try self.addUavsFromCodegen(&object.dg.uavs);
}

pub fn updateLineNumber(self: *C, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) !void {
    // The C backend does not have the ability to fix line numbers without re-generating
    // the entire Decl.
    _ = self;
    _ = pt;
    _ = ti_id;
}

fn abiDefines(w: *std.io.Writer, target: *const std.Target) !void {
    switch (target.abi) {
        .msvc, .itanium => try w.writeAll("#define ZIG_TARGET_ABI_MSVC\n"),
        else => {},
    }
    try w.print("#define ZIG_TARGET_MAX_INT_ALIGNMENT {d}\n", .{
        target.cMaxIntAlignment(),
    });
}

pub fn flush(self: *C, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    _ = arena; // Has the same lifetime as the call to Compilation.update.

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("Flush Module", 0);
    defer sub_prog_node.end();

    const comp = self.base.comp;
    const diags = &comp.link_diags;
    const gpa = comp.gpa;
    const zcu = self.base.comp.zcu.?;
    const ip = &zcu.intern_pool;
    const pt: Zcu.PerThread = .activate(zcu, tid);
    defer pt.deactivate();

    {
        var i: usize = 0;
        while (i < self.uavs.count()) : (i += 1) {
            try self.updateUav(pt, i);
        }
    }

    // This code path happens exclusively with -ofmt=c. The flush logic for
    // emit-h is in `flushEmitH` below.

    var f: Flush = .{
        .ctype_pool = .empty,
        .ctype_global_from_decl_map = .empty,
        .ctypes = .empty,

        .lazy_ctype_pool = .empty,
        .lazy_fns = .empty,
        .lazy_fwd_decl = .empty,
        .lazy_code = .empty,

        .all_buffers = .empty,
        .file_size = 0,
    };
    defer f.deinit(gpa);

    var abi_defines_aw: std.io.Writer.Allocating = .init(gpa);
    defer abi_defines_aw.deinit();
    abiDefines(&abi_defines_aw.writer, zcu.getTarget()) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
    };

    // Covers defines, zig.h, ctypes, asm, lazy fwd.
    try f.all_buffers.ensureUnusedCapacity(gpa, 5);

    f.appendBufAssumeCapacity(abi_defines_aw.getWritten());
    f.appendBufAssumeCapacity(zig_h);

    const ctypes_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    var asm_aw: std.io.Writer.Allocating = .init(gpa);
    defer asm_aw.deinit();
    codegen.genGlobalAsm(zcu, &asm_aw.writer) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
    };
    f.appendBufAssumeCapacity(asm_aw.getWritten());

    const lazy_index = f.all_buffers.items.len;
    f.all_buffers.items.len += 1;

    try f.lazy_ctype_pool.init(gpa);
    try self.flushErrDecls(pt, &f);

    // Unlike other backends, the .c code we are emitting has order-dependent decls.
    // `CType`s, forward decls, and non-functions first.

    {
        var export_names: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void) = .empty;
        defer export_names.deinit(gpa);
        try export_names.ensureTotalCapacity(gpa, @intCast(zcu.single_exports.count()));
        for (zcu.single_exports.values()) |export_index| {
            export_names.putAssumeCapacity(export_index.ptr(zcu).opts.name, {});
        }
        for (zcu.multi_exports.values()) |info| {
            try export_names.ensureUnusedCapacity(gpa, info.len);
            for (zcu.all_exports.items[info.index..][0..info.len]) |@"export"| {
                export_names.putAssumeCapacity(@"export".opts.name, {});
            }
        }

        for (self.uavs.keys(), self.uavs.values()) |uav, *av_block| try self.flushAvBlock(
            pt,
            zcu.root_mod,
            &f,
            av_block,
            self.exported_uavs.getPtr(uav),
            export_names,
            .none,
        );

        for (self.navs.keys(), self.navs.values()) |nav, *av_block| try self.flushAvBlock(
            pt,
            zcu.navFileScope(nav).mod.?,
            &f,
            av_block,
            self.exported_navs.getPtr(nav),
            export_names,
            if (ip.getNav(nav).getExtern(ip) != null)
                ip.getNav(nav).name.toOptional()
            else
                .none,
        );
    }

    {
        // We need to flush lazy ctypes after flushing all decls but before flushing any decl ctypes.
        // This ensures that every lazy CType.Index exactly matches the global CType.Index.
        try f.ctype_pool.init(gpa);
        try self.flushCTypes(zcu, &f, .flush, &f.lazy_ctype_pool);

        for (self.uavs.keys(), self.uavs.values()) |uav, av_block| {
            try self.flushCTypes(zcu, &f, .{ .uav = uav }, &av_block.ctype_pool);
        }

        for (self.navs.keys(), self.navs.values()) |nav, av_block| {
            try self.flushCTypes(zcu, &f, .{ .nav = nav }, &av_block.ctype_pool);
        }
    }

    f.all_buffers.items[ctypes_index] = f.ctypes.items;
    f.file_size += f.ctypes.items.len;

    f.all_buffers.items[lazy_index] = f.lazy_fwd_decl.items;
    f.file_size += f.lazy_fwd_decl.items.len;

    // Now the code.
    try f.all_buffers.ensureUnusedCapacity(gpa, 1 + (self.uavs.count() + self.navs.count()) * 2);
    f.appendBufAssumeCapacity(f.lazy_code.items);
    for (self.uavs.keys(), self.uavs.values()) |uav, av_block| f.appendCodeAssumeCapacity(
        if (self.exported_uavs.contains(uav)) .default else switch (ip.indexToKey(uav)) {
            .@"extern" => .zig_extern,
            else => .static,
        },
        self.getString(av_block.code),
    );
    for (self.navs.keys(), self.navs.values()) |nav, av_block| f.appendCodeAssumeCapacity(storage: {
        if (self.exported_navs.contains(nav)) break :storage .default;
        if (ip.getNav(nav).getExtern(ip) != null) break :storage .zig_extern;
        break :storage .static;
    }, self.getString(av_block.code));

    const file = self.base.file.?;
    file.setEndPos(f.file_size) catch |err| return diags.fail("failed to allocate file: {s}", .{@errorName(err)});
    var fw = file.writer(&.{});
    var w = &fw.interface;
    w.writeVecAll(f.all_buffers.items) catch |err| switch (err) {
        error.WriteFailed => return diags.fail("failed to write to '{f}': {s}", .{
            std.fmt.alt(self.base.emit, .formatEscapeChar), @errorName(fw.err.?),
        }),
    };
}

const Flush = struct {
    ctype_pool: codegen.CType.Pool,
    ctype_global_from_decl_map: std.ArrayListUnmanaged(codegen.CType),
    ctypes: std.ArrayListUnmanaged(u8),

    lazy_ctype_pool: codegen.CType.Pool,
    lazy_fns: LazyFns,
    lazy_fwd_decl: std.ArrayListUnmanaged(u8),
    lazy_code: std.ArrayListUnmanaged(u8),

    /// We collect a list of buffers to write, and write them all at once with pwritev 😎
    all_buffers: std.ArrayListUnmanaged([]const u8),
    /// Keeps track of the total bytes of `all_buffers`.
    file_size: u64,

    const LazyFns = std.AutoHashMapUnmanaged(codegen.LazyFnKey, void);

    fn appendBufAssumeCapacity(f: *Flush, buf: []const u8) void {
        if (buf.len == 0) return;
        f.all_buffers.appendAssumeCapacity(buf);
        f.file_size += buf.len;
    }

    fn appendCodeAssumeCapacity(f: *Flush, storage: enum { default, zig_extern, static }, code: []const u8) void {
        if (code.len == 0) return;
        f.appendBufAssumeCapacity(switch (storage) {
            .default => "\n",
            .zig_extern => "\nzig_extern ",
            .static => "\nstatic ",
        });
        f.appendBufAssumeCapacity(code);
    }

    fn deinit(f: *Flush, gpa: Allocator) void {
        f.ctype_pool.deinit(gpa);
        assert(f.ctype_global_from_decl_map.items.len == 0);
        f.ctype_global_from_decl_map.deinit(gpa);
        f.ctypes.deinit(gpa);
        f.lazy_ctype_pool.deinit(gpa);
        f.lazy_fns.deinit(gpa);
        f.lazy_fwd_decl.deinit(gpa);
        f.lazy_code.deinit(gpa);
        f.all_buffers.deinit(gpa);
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

    var ctypes_aw: std.io.Writer.Allocating = .fromArrayList(gpa, &f.ctypes);
    const ctypes_bw = &ctypes_aw.writer;
    defer f.ctypes = ctypes_aw.toArrayList();

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
        codegen.genTypeDecl(
            zcu,
            ctypes_bw,
            global_ctype_pool,
            global_ctype,
            pass,
            decl_ctype_pool,
            decl_ctype,
            found_existing,
        ) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
        };
    }
}

fn flushErrDecls(self: *C, pt: Zcu.PerThread, f: *Flush) FlushDeclError!void {
    const gpa = self.base.comp.gpa;

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .pt = pt,
            .mod = pt.zcu.root_mod,
            .error_msg = null,
            .pass = .flush,
            .is_naked_fn = false,
            .expected_block = null,
            .fwd_decl = undefined,
            .ctype_pool = f.lazy_ctype_pool,
            .scratch = .initBuffer(self.scratch_buf),
            .uavs = .empty,
        },
        .code_header = undefined,
        .code = undefined,
        .indent_counter = 0,
    };
    object.dg.fwd_decl = .fromArrayList(gpa, &f.lazy_fwd_decl);
    object.code = .fromArrayList(gpa, &f.lazy_code);
    defer {
        object.dg.uavs.deinit(gpa);
        f.lazy_ctype_pool = object.dg.ctype_pool.move();
        f.lazy_ctype_pool.freeUnusedCapacity(gpa);

        f.lazy_fwd_decl = object.dg.fwd_decl.toArrayList();
        f.lazy_code = object.code.toArrayList();
        self.scratch_buf = object.dg.scratch.allocatedSlice();
    }

    codegen.genErrDecls(&object) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };

    try self.addUavsFromCodegen(&object.dg.uavs);
}

fn flushLazyFn(
    self: *C,
    pt: Zcu.PerThread,
    mod: *Module,
    f: *Flush,
    lazy_ctype_pool: *const codegen.CType.Pool,
    lazy_fn: codegen.LazyFnMap.Entry,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;

    var object: codegen.Object = .{
        .dg = .{
            .gpa = gpa,
            .pt = pt,
            .mod = mod,
            .error_msg = null,
            .pass = .flush,
            .is_naked_fn = false,
            .expected_block = null,
            .fwd_decl = undefined,
            .ctype_pool = f.lazy_ctype_pool,
            .scratch = .initBuffer(self.scratch_buf),
            .uavs = .empty,
        },
        .code_header = undefined,
        .code = undefined,
        .indent_counter = 0,
    };
    object.dg.fwd_decl = .fromArrayList(gpa, &f.lazy_fwd_decl);
    object.code = .fromArrayList(gpa, &f.lazy_code);
    defer {
        // If this assert trips just handle the anon_decl_deps the same as
        // `updateFunc()` does.
        assert(object.dg.uavs.count() == 0);
        f.lazy_ctype_pool = object.dg.ctype_pool.move();
        f.lazy_ctype_pool.freeUnusedCapacity(gpa);

        f.lazy_fwd_decl = object.dg.fwd_decl.toArrayList();
        f.lazy_code = object.code.toArrayList();
        self.scratch_buf = object.dg.scratch.allocatedSlice();
    }

    codegen.genLazyFn(&object, lazy_ctype_pool, lazy_fn) catch |err| switch (err) {
        error.AnalysisFail => unreachable,
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };
}

fn flushLazyFns(
    self: *C,
    pt: Zcu.PerThread,
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
        try self.flushLazyFn(pt, mod, f, lazy_ctype_pool, entry);
    }
}

fn flushAvBlock(
    self: *C,
    pt: Zcu.PerThread,
    mod: *Module,
    f: *Flush,
    av_block: *const AvBlock,
    exported_block: ?*const ExportedBlock,
    export_names: std.AutoHashMapUnmanaged(InternPool.NullTerminatedString, void),
    extern_name: InternPool.OptionalNullTerminatedString,
) FlushDeclError!void {
    const gpa = self.base.comp.gpa;
    try self.flushLazyFns(pt, mod, f, &av_block.ctype_pool, av_block.lazy_fns);
    try f.all_buffers.ensureUnusedCapacity(gpa, 1);
    // avoid emitting extern decls that are already exported
    if (extern_name.unwrap()) |name| if (export_names.contains(name)) return;
    f.appendBufAssumeCapacity(self.getString(if (exported_block) |exported|
        exported.fwd_decl
    else
        av_block.fwd_decl));
}

pub fn flushEmitH(zcu: *Zcu) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (true) return; // emit-h is regressed

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
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const mod, const pass: codegen.DeclGen.Pass, const decl_block, const exported_block = switch (exported) {
        .nav => |nav| .{
            zcu.navFileScope(nav).mod.?,
            .{ .nav = nav },
            self.navs.getPtr(nav).?,
            (try self.exported_navs.getOrPut(gpa, nav)).value_ptr,
        },
        .uav => |uav| .{
            zcu.root_mod,
            .{ .uav = uav },
            self.uavs.getPtr(uav).?,
            (try self.exported_uavs.getOrPut(gpa, uav)).value_ptr,
        },
    };
    const ctype_pool = &decl_block.ctype_pool;
    var dg: codegen.DeclGen = .{
        .gpa = gpa,
        .pt = pt,
        .mod = mod,
        .error_msg = null,
        .pass = pass,
        .is_naked_fn = false,
        .expected_block = null,
        .fwd_decl = undefined,
        .ctype_pool = decl_block.ctype_pool,
        .scratch = .initBuffer(self.scratch_buf),
        .uavs = .empty,
    };
    dg.fwd_decl = .initOwnedSlice(gpa, self.fwd_decl_buf);
    defer {
        assert(dg.uavs.count() == 0);
        ctype_pool.* = dg.ctype_pool.move();
        ctype_pool.freeUnusedCapacity(gpa);

        self.fwd_decl_buf = dg.fwd_decl.toArrayList().allocatedSlice();
        self.scratch_buf = dg.scratch.allocatedSlice();
    }
    codegen.genExports(&dg, exported, export_indices) catch |err| switch (err) {
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };
    exported_block.* = .{ .fwd_decl = try self.addString(dg.fwd_decl.getWritten()) };
}

pub fn deleteExport(
    self: *C,
    exported: Zcu.Exported,
    _: InternPool.NullTerminatedString,
) void {
    switch (exported) {
        .nav => |nav| _ = self.exported_navs.swapRemove(nav),
        .uav => |uav| _ = self.exported_uavs.swapRemove(uav),
    }
}

fn addUavsFromCodegen(c: *C, uavs: *const std.AutoArrayHashMapUnmanaged(InternPool.Index, Alignment)) Allocator.Error!void {
    const gpa = c.base.comp.gpa;
    try c.uavs.ensureUnusedCapacity(gpa, uavs.count());
    try c.aligned_uavs.ensureUnusedCapacity(gpa, uavs.count());
    for (uavs.keys(), uavs.values()) |uav_val, uav_align| {
        {
            const gop = c.uavs.getOrPutAssumeCapacity(uav_val);
            if (!gop.found_existing) gop.value_ptr.* = .{};
        }
        if (uav_align != .none) {
            const gop = c.aligned_uavs.getOrPutAssumeCapacity(uav_val);
            gop.value_ptr.* = if (gop.found_existing) max: {
                break :max gop.value_ptr.*.maxStrict(uav_align);
            } else uav_align;
        }
    }
}
