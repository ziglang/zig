//! This implementation does all the linking work in flush(). A future improvement
//! would be to add incremental linking in a similar way as ELF does.

const Plan9 = @This();
const link = @import("../link.zig");
const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const aout = @import("Plan9/aout.zig");
const codegen = @import("../codegen.zig");
const trace = @import("../tracy.zig").trace;
const File = link.File;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const AnalUnit = InternPool.AnalUnit;

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.link);
const assert = std.debug.assert;
const Path = std.Build.Cache.Path;

base: link.File,
sixtyfour_bit: bool,
bases: Bases,

/// A symbol's value is just casted down when compiling
/// for a 32 bit target.
/// Does not represent the order or amount of symbols in the file
/// it is just useful for storing symbols. Some other symbols are in
/// file_segments.
syms: std.ArrayListUnmanaged(aout.Sym) = .empty,

/// The plan9 a.out format requires segments of
/// filenames to be deduplicated, so we use this map to
/// de duplicate it. The value is the value of the path
/// component
file_segments: std.StringArrayHashMapUnmanaged(u16) = .empty,
/// The value of a 'f' symbol increments by 1 every time, so that no 2 'f'
/// symbols have the same value.
file_segments_i: u16 = 1,

path_arena: std.heap.ArenaAllocator,

/// maps a file scope to a hash map of decl to codegen output
/// this is useful for line debuginfo, since it makes sense to sort by file
/// The debugger looks for the first file (aout.Sym.Type.z) preceeding the text symbol
/// of the function to know what file it came from.
/// If we group the decls by file, it makes it really easy to do this (put the symbol in the correct place)
fn_nav_table: std.AutoArrayHashMapUnmanaged(
    Zcu.File.Index,
    struct { sym_index: u32, functions: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, FnNavOutput) = .empty },
) = .{},
/// the code is modified when relocated, so that is why it is mutable
data_nav_table: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, []u8) = .empty,
/// When `updateExports` is called, we store the export indices here, to be used
/// during flush.
nav_exports: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, []u32) = .empty,

lazy_syms: LazySymbolTable = .{},

uavs: std.AutoHashMapUnmanaged(InternPool.Index, Atom.Index) = .empty,

relocs: std.AutoHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Reloc)) = .empty,
hdr: aout.ExecHdr = undefined,

// relocs: std.
magic: u32,

entry_val: ?u64 = null,

got_len: usize = 0,
// A list of all the free got indexes, so when making a new decl
// don't make a new one, just use one from here.
got_index_free_list: std.ArrayListUnmanaged(usize) = .empty,

syms_index_free_list: std.ArrayListUnmanaged(usize) = .empty,

atoms: std.ArrayListUnmanaged(Atom) = .empty,
navs: std.AutoHashMapUnmanaged(InternPool.Nav.Index, NavMetadata) = .empty,

/// Indices of the three "special" symbols into atoms
etext_edata_end_atom_indices: [3]?Atom.Index = .{ null, null, null },

const Reloc = struct {
    target: Atom.Index,
    offset: u64,
    addend: u32,
    type: enum {
        pcrel,
        nonpcrel,
        // for getting the value of the etext symbol; we ignore target
        special_etext,
        // for getting the value of the edata symbol; we ignore target
        special_edata,
        // for getting the value of the end symbol; we ignore target
        special_end,
    } = .nonpcrel,
};

const Bases = struct {
    text: u64,
    /// the Global Offset Table starts at the beginning of the data section
    data: u64,
};

const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, LazySymbolMetadata);

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_atom: Atom.Index = undefined,
    rodata_atom: Atom.Index = undefined,
    text_state: State = .unused,
    rodata_state: State = .unused,

    fn numberOfAtoms(self: LazySymbolMetadata) u32 {
        var n: u32 = 0;
        if (self.text_state != .unused) n += 1;
        if (self.rodata_state != .unused) n += 1;
        return n;
    }
};

pub const PtrWidth = enum { p32, p64 };

pub const Atom = struct {
    type: aout.Sym.Type,
    /// offset in the text or data sects
    offset: ?u64,
    /// offset into syms
    sym_index: ?usize,
    /// offset into got
    got_index: ?usize,
    /// We include the code here to be use in relocs
    /// In the case of lazy_syms, this atom owns the code.
    /// But, in the case of function and data decls, they own the code and this field
    /// is just a pointer for convience.
    code: CodePtr,

    const CodePtr = struct {
        code_ptr: ?[*]u8,
        other: union {
            code_len: usize,
            nav_index: InternPool.Nav.Index,
        },
        fn fromSlice(slice: []u8) CodePtr {
            return .{ .code_ptr = slice.ptr, .other = .{ .code_len = slice.len } };
        }
        fn getCode(self: CodePtr, plan9: *const Plan9) []u8 {
            const zcu = plan9.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            return if (self.code_ptr) |p| p[0..self.other.code_len] else blk: {
                const nav_index = self.other.nav_index;
                const nav = ip.getNav(nav_index);
                if (ip.isFunctionType(nav.typeOf(ip))) {
                    const table = plan9.fn_nav_table.get(zcu.navFileScopeIndex(nav_index)).?.functions;
                    const output = table.get(nav_index).?;
                    break :blk output.code;
                } else {
                    break :blk plan9.data_nav_table.get(nav_index).?;
                }
            };
        }
        fn getOwnedCode(self: CodePtr) ?[]u8 {
            return if (self.code_ptr) |p| p[0..self.other.code_len] else null;
        }
    };

    pub const Index = u32;

    pub fn getOrCreateOffsetTableEntry(self: *Atom, plan9: *Plan9) usize {
        if (self.got_index == null) self.got_index = plan9.allocateGotIndex();
        return self.got_index.?;
    }

    pub fn getOrCreateSymbolTableEntry(self: *Atom, plan9: *Plan9) !usize {
        if (self.sym_index == null) self.sym_index = try plan9.allocateSymbolIndex();
        return self.sym_index.?;
    }

    // asserts that self.got_index != null
    pub fn getOffsetTableAddress(self: Atom, plan9: *Plan9) u64 {
        const target = plan9.base.comp.root_mod.resolved_target.result;
        const ptr_bytes = @divExact(target.ptrBitWidth(), 8);
        const got_addr = plan9.bases.data;
        const got_index = self.got_index.?;
        return got_addr + got_index * ptr_bytes;
    }
};

/// the plan9 debuginfo output is a bytecode with 4 opcodes
/// assume all numbers/variables are bytes
/// 0 w x y z -> interpret w x y z as a big-endian i32, and add it to the line offset
/// x when x < 65 -> add x to line offset
/// x when x < 129 -> subtract 64 from x and subtract it from the line offset
/// x -> subtract 129 from x, multiply it by the quanta of the instruction size
/// (1 on x86_64), and add it to the pc
/// after every opcode, add the quanta of the instruction size to the pc
pub const DebugInfoOutput = struct {
    /// the actual opcodes
    dbg_line: std.ArrayList(u8),
    /// what line the debuginfo starts on
    /// this helps because the linker might have to insert some opcodes to make sure that the line count starts at the right amount for the next decl
    start_line: ?u32,
    /// what the line count ends on after codegen
    /// this helps because the linker might have to insert some opcodes to make sure that the line count starts at the right amount for the next decl
    end_line: u32,
    /// the last pc change op
    /// This is very useful for adding quanta
    /// to it if its not actually the last one.
    pcop_change_index: ?u32,
    /// cached pc quanta
    pc_quanta: u8,
};

const NavMetadata = struct {
    index: Atom.Index,
    exports: std.ArrayListUnmanaged(usize) = .empty,

    fn getExport(m: NavMetadata, p9: *const Plan9, name: []const u8) ?usize {
        for (m.exports.items) |exp| {
            const sym = p9.syms.items[exp];
            if (mem.eql(u8, name, sym.name)) return exp;
        }
        return null;
    }
};

const FnNavOutput = struct {
    /// this code is modified when relocated so it is mutable
    code: []u8,
    /// this might have to be modified in the linker, so thats why its mutable
    lineinfo: []u8,
    start_line: u32,
    end_line: u32,
};

fn getAddr(self: Plan9, addr: u64, t: aout.Sym.Type) u64 {
    return addr + switch (t) {
        .T, .t, .l, .L => self.bases.text,
        .D, .d, .B, .b => self.bases.data,
        else => unreachable,
    };
}

fn getSymAddr(self: Plan9, s: aout.Sym) u64 {
    return self.getAddr(s.value, s.type);
}

pub fn defaultBaseAddrs(arch: std.Target.Cpu.Arch) Bases {
    return switch (arch) {
        .x86_64 => .{
            // header size => 40 => 0x28
            .text = 0x200028,
            .data = 0x400000,
        },
        .x86 => .{
            // header size => 32 => 0x20
            .text = 0x200020,
            .data = 0x400000,
        },
        .aarch64 => .{
            // header size => 40 => 0x28
            .text = 0x10028,
            .data = 0x20000,
        },
        else => std.debug.panic("find default base address for {}", .{arch}),
    };
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Plan9 {
    const target = comp.root_mod.resolved_target.result;
    const gpa = comp.gpa;
    const optimize_mode = comp.root_mod.optimize_mode;
    const output_mode = comp.config.output_mode;

    const sixtyfour_bit: bool = switch (target.ptrBitWidth()) {
        0...32 => false,
        33...64 => true,
        else => return error.UnsupportedP9Architecture,
    };

    const self = try arena.create(Plan9);
    self.* = .{
        .path_arena = std.heap.ArenaAllocator.init(gpa),
        .base = .{
            .tag = .plan9,
            .comp = comp,
            .emit = emit,
            .gc_sections = options.gc_sections orelse (optimize_mode != .Debug and output_mode != .Obj),
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 16777216,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
        },
        .sixtyfour_bit = sixtyfour_bit,
        .bases = undefined,
        .magic = try aout.magicFromArch(target.cpu.arch),
    };
    // a / will always be in a file path
    try self.file_segments.put(gpa, "/", 1);
    return self;
}

fn putFn(self: *Plan9, nav_index: InternPool.Nav.Index, out: FnNavOutput) !void {
    const gpa = self.base.comp.gpa;
    const zcu = self.base.comp.zcu.?;
    const file_scope = zcu.navFileScopeIndex(nav_index);
    const fn_map_res = try self.fn_nav_table.getOrPut(gpa, file_scope);
    if (fn_map_res.found_existing) {
        if (try fn_map_res.value_ptr.functions.fetchPut(gpa, nav_index, out)) |old_entry| {
            gpa.free(old_entry.value.code);
            gpa.free(old_entry.value.lineinfo);
        }
    } else {
        const file = zcu.fileByIndex(file_scope);
        const arena = self.path_arena.allocator();
        // each file gets a symbol
        fn_map_res.value_ptr.* = .{
            .sym_index = blk: {
                try self.syms.append(gpa, undefined);
                try self.syms.append(gpa, undefined);
                break :blk @as(u32, @intCast(self.syms.items.len - 1));
            },
        };
        try fn_map_res.value_ptr.functions.put(gpa, nav_index, out);

        var a = std.ArrayList(u8).init(arena);
        errdefer a.deinit();
        // every 'z' starts with 0
        try a.append(0);
        // path component value of '/'
        try a.writer().writeInt(u16, 1, .big);

        // getting the full file path
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const full_path = try std.fs.path.join(arena, &.{
            file.mod.root.root_dir.path orelse try std.posix.getcwd(&buf),
            file.mod.root.sub_path,
            file.sub_file_path,
        });
        try self.addPathComponents(full_path, &a);

        // null terminate
        try a.append(0);
        const final = try a.toOwnedSlice();
        self.syms.items[fn_map_res.value_ptr.sym_index - 1] = .{
            .type = .z,
            .value = 1,
            .name = final,
        };
        self.syms.items[fn_map_res.value_ptr.sym_index] = .{
            .type = .z,
            // just put a giant number, no source file will have this many newlines
            .value = std.math.maxInt(u31),
            .name = &.{ 0, 0 },
        };
    }
}

fn addPathComponents(self: *Plan9, path: []const u8, a: *std.ArrayList(u8)) !void {
    const gpa = self.base.comp.gpa;
    const sep = std.fs.path.sep;
    var it = std.mem.tokenizeScalar(u8, path, sep);
    while (it.next()) |component| {
        if (self.file_segments.get(component)) |num| {
            try a.writer().writeInt(u16, num, .big);
        } else {
            self.file_segments_i += 1;
            try self.file_segments.put(gpa, component, self.file_segments_i);
            try a.writer().writeInt(u16, self.file_segments_i, .big);
        }
    }
}

pub fn updateFunc(self: *Plan9, pt: Zcu.PerThread, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const target = self.base.comp.root_mod.resolved_target.result;
    const func = zcu.funcInfo(func_index);

    const atom_idx = try self.seeNav(pt, func.owner_nav);

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();
    var dbg_info_output: DebugInfoOutput = .{
        .dbg_line = std.ArrayList(u8).init(gpa),
        .start_line = null,
        .end_line = undefined,
        .pcop_change_index = null,
        // we have already checked the target in the linker to make sure it is compatable
        .pc_quanta = aout.getPCQuant(target.cpu.arch) catch unreachable,
    };
    defer dbg_info_output.dbg_line.deinit();

    const res = try codegen.generateFunction(
        &self.base,
        pt,
        zcu.navSrcLoc(func.owner_nav),
        func_index,
        air,
        liveness,
        &code_buffer,
        .{ .plan9 = &dbg_info_output },
    );
    const code = switch (res) {
        .ok => try code_buffer.toOwnedSlice(),
        .fail => |em| return zcu.failed_codegen.put(gpa, func.owner_nav, em),
    };
    self.getAtomPtr(atom_idx).code = .{
        .code_ptr = null,
        .other = .{ .nav_index = func.owner_nav },
    };
    const out: FnNavOutput = .{
        .code = code,
        .lineinfo = try dbg_info_output.dbg_line.toOwnedSlice(),
        .start_line = dbg_info_output.start_line.?,
        .end_line = dbg_info_output.end_line,
    };
    try self.putFn(func.owner_nav, out);
    return self.updateFinish(pt, func.owner_nav);
}

pub fn updateNav(self: *Plan9, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    const nav_val = zcu.navValue(nav_index);
    const nav_init = switch (ip.indexToKey(nav_val.toIntern())) {
        .func => return,
        .variable => |variable| Value.fromInterned(variable.init),
        .@"extern" => {
            log.debug("found extern decl: {}", .{nav.name.fmt(ip)});
            return;
        },
        else => nav_val,
    };

    if (nav_init.typeOf(zcu).hasRuntimeBits(zcu)) {
        const atom_idx = try self.seeNav(pt, nav_index);

        var code_buffer = std.ArrayList(u8).init(gpa);
        defer code_buffer.deinit();
        // TODO we need the symbol index for symbol in the table of locals for the containing atom
        const res = try codegen.generateSymbol(
            &self.base,
            pt,
            zcu.navSrcLoc(nav_index),
            nav_init,
            &code_buffer,
            .{ .atom_index = @intCast(atom_idx) },
        );
        const code = switch (res) {
            .ok => code_buffer.items,
            .fail => |em| return zcu.failed_codegen.put(gpa, nav_index, em),
        };
        try self.data_nav_table.ensureUnusedCapacity(gpa, 1);
        const duped_code = try gpa.dupe(u8, code);
        self.getAtomPtr(self.navs.get(nav_index).?.index).code = .{ .code_ptr = null, .other = .{ .nav_index = nav_index } };
        if (self.data_nav_table.fetchPutAssumeCapacity(nav_index, duped_code)) |old_entry| {
            gpa.free(old_entry.value);
        }
        try self.updateFinish(pt, nav_index);
    }
}

/// called at the end of update{Decl,Func}
fn updateFinish(self: *Plan9, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    const is_fn = ip.isFunctionType(nav.typeOf(ip));
    const sym_t: aout.Sym.Type = if (is_fn) .t else .d;

    const atom = self.getAtomPtr(self.navs.get(nav_index).?.index);
    // write the internal linker metadata
    atom.type = sym_t;
    // write the symbol
    // we already have the got index
    const sym: aout.Sym = .{
        .value = undefined, // the value of stuff gets filled in in flushModule
        .type = atom.type,
        .name = try gpa.dupe(u8, nav.name.toSlice(ip)),
    };

    if (atom.sym_index) |s| {
        self.syms.items[s] = sym;
    } else {
        const s = try self.allocateSymbolIndex();
        atom.sym_index = s;
        self.syms.items[s] = sym;
    }
}

fn allocateSymbolIndex(self: *Plan9) !usize {
    const gpa = self.base.comp.gpa;
    if (self.syms_index_free_list.popOrNull()) |i| {
        return i;
    } else {
        _ = try self.syms.addOne(gpa);
        return self.syms.items.len - 1;
    }
}

fn allocateGotIndex(self: *Plan9) usize {
    if (self.got_index_free_list.popOrNull()) |i| {
        return i;
    } else {
        self.got_len += 1;
        return self.got_len - 1;
    }
}

pub fn flush(self: *Plan9, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const comp = self.base.comp;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    assert(!use_lld);

    switch (link.File.effectiveOutputMode(use_lld, comp.config.output_mode)) {
        .Exe => {},
        // plan9 object files are totally different
        .Obj => return error.TODOImplementPlan9Objs,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    return self.flushModule(arena, tid, prog_node);
}

pub fn changeLine(l: *std.ArrayList(u8), delta_line: i32) !void {
    if (delta_line > 0 and delta_line < 65) {
        const toappend = @as(u8, @intCast(delta_line));
        try l.append(toappend);
    } else if (delta_line < 0 and delta_line > -65) {
        const toadd: u8 = @as(u8, @intCast(-delta_line + 64));
        try l.append(toadd);
    } else if (delta_line != 0) {
        try l.append(0);
        try l.writer().writeInt(i32, delta_line, .big);
    }
}

fn externCount(self: *Plan9) usize {
    var extern_atom_count: usize = 0;
    for (self.etext_edata_end_atom_indices) |idx| {
        if (idx != null) extern_atom_count += 1;
    }
    return extern_atom_count;
}
// counts decls, and lazy syms
fn atomCount(self: *Plan9) usize {
    var fn_nav_count: usize = 0;
    var itf_files = self.fn_nav_table.iterator();
    while (itf_files.next()) |ent| {
        // get the submap
        var submap = ent.value_ptr.functions;
        fn_nav_count += submap.count();
    }
    const data_nav_count = self.data_nav_table.count();
    var lazy_atom_count: usize = 0;
    var it_lazy = self.lazy_syms.iterator();
    while (it_lazy.next()) |kv| {
        lazy_atom_count += kv.value_ptr.numberOfAtoms();
    }
    const uav_atom_count = self.uavs.count();
    const extern_atom_count = self.externCount();
    return data_nav_count + fn_nav_count + lazy_atom_count + extern_atom_count + uav_atom_count;
}

pub fn flushModule(self: *Plan9, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const tracy = trace(@src());
    defer tracy.end();

    _ = arena; // Has the same lifetime as the call to Compilation.update.

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const target = comp.root_mod.resolved_target.result;

    const sub_prog_node = prog_node.start("Flush Module", 0);
    defer sub_prog_node.end();

    log.debug("flushModule", .{});

    defer assert(self.hdr.entry != 0x0);

    const pt: Zcu.PerThread = .{
        .zcu = self.base.comp.zcu orelse return error.LinkingWithoutZigSourceUnimplemented,
        .tid = tid,
    };

    // finish up the lazy syms
    if (self.lazy_syms.getPtr(.none)) |metadata| {
        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbolAtom(
            pt,
            .{ .kind = .code, .ty = .anyerror_type },
            metadata.text_atom,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
        if (metadata.rodata_state != .unused) self.updateLazySymbolAtom(
            pt,
            .{ .kind = .const_data, .ty = .anyerror_type },
            metadata.rodata_atom,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
    }
    for (self.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.rodata_state != .unused) metadata.rodata_state = .flushed;
    }
    // make sure the got table is good
    const atom_count = self.atomCount();
    assert(self.got_len == atom_count + self.got_index_free_list.items.len);
    const got_size = self.got_len * if (!self.sixtyfour_bit) @as(u32, 4) else 8;
    var got_table = try gpa.alloc(u8, got_size);
    defer gpa.free(got_table);

    // + 4 for header, got, symbols, linecountinfo
    var iovecs = try gpa.alloc(std.posix.iovec_const, self.atomCount() + 4 - self.externCount());
    defer gpa.free(iovecs);

    const file = self.base.file.?;

    var hdr_buf: [40]u8 = undefined;
    // account for the fat header
    const hdr_size: usize = if (self.sixtyfour_bit) 40 else 32;
    const hdr_slice: []u8 = hdr_buf[0..hdr_size];
    var foff = hdr_size;
    iovecs[0] = .{ .base = hdr_slice.ptr, .len = hdr_slice.len };
    var iovecs_i: usize = 1;
    var text_i: u64 = 0;

    var linecountinfo = std.ArrayList(u8).init(gpa);
    defer linecountinfo.deinit();
    // text
    {
        var linecount: i64 = -1;
        var it_file = self.fn_nav_table.iterator();
        while (it_file.next()) |fentry| {
            var it = fentry.value_ptr.functions.iterator();
            while (it.next()) |entry| {
                const nav_index = entry.key_ptr.*;
                const nav = pt.zcu.intern_pool.getNav(nav_index);
                const atom = self.getAtomPtr(self.navs.get(nav_index).?.index);
                const out = entry.value_ptr.*;
                {
                    // connect the previous decl to the next
                    const delta_line = @as(i32, @intCast(out.start_line)) - @as(i32, @intCast(linecount));

                    try changeLine(&linecountinfo, delta_line);
                    // TODO change the pc too (maybe?)

                    // write out the actual info that was generated in codegen now
                    try linecountinfo.appendSlice(out.lineinfo);
                    linecount = out.end_line;
                }
                foff += out.code.len;
                iovecs[iovecs_i] = .{ .base = out.code.ptr, .len = out.code.len };
                iovecs_i += 1;
                const off = self.getAddr(text_i, .t);
                text_i += out.code.len;
                atom.offset = off;
                log.debug("write text nav 0x{x} ({}), lines {d} to {d}.;__GOT+0x{x} vaddr: 0x{x}", .{ nav_index, nav.name.fmt(&pt.zcu.intern_pool), out.start_line + 1, out.end_line, atom.got_index.? * 8, off });
                if (!self.sixtyfour_bit) {
                    mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @intCast(off), target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, target.cpu.arch.endian());
                }
                self.syms.items[atom.sym_index.?].value = off;
                if (self.nav_exports.get(nav_index)) |export_indices| {
                    try self.addNavExports(pt.zcu, nav_index, export_indices);
                }
            }
        }
        if (linecountinfo.items.len & 1 == 1) {
            // just a nop to make it even, the plan9 linker does this
            try linecountinfo.append(129);
        }
    }
    // the text lazy symbols
    {
        var it = self.lazy_syms.iterator();
        while (it.next()) |kv| {
            const meta = kv.value_ptr;
            const text_atom = if (meta.text_state != .unused) self.getAtomPtr(meta.text_atom) else continue;
            const code = text_atom.code.getOwnedCode().?;
            foff += code.len;
            iovecs[iovecs_i] = .{ .base = code.ptr, .len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(text_i, .t);
            text_i += code.len;
            text_atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[text_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[text_atom.got_index.? * 8 ..][0..8], off, target.cpu.arch.endian());
            }
            self.syms.items[text_atom.sym_index.?].value = off;
        }
    }
    // fix the sym for etext
    if (self.etext_edata_end_atom_indices[0]) |etext_atom_idx| {
        const etext_atom = self.getAtom(etext_atom_idx);
        const val = self.getAddr(text_i, .t);
        self.syms.items[etext_atom.sym_index.?].value = val;
        if (!self.sixtyfour_bit) {
            mem.writeInt(u32, got_table[etext_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), target.cpu.arch.endian());
        } else {
            mem.writeInt(u64, got_table[etext_atom.got_index.? * 8 ..][0..8], val, target.cpu.arch.endian());
        }
    }
    // global offset table is in data
    iovecs[iovecs_i] = .{ .base = got_table.ptr, .len = got_table.len };
    iovecs_i += 1;
    // data
    var data_i: u64 = got_size;
    {
        var it = self.data_nav_table.iterator();
        while (it.next()) |entry| {
            const nav_index = entry.key_ptr.*;
            const atom = self.getAtomPtr(self.navs.get(nav_index).?.index);
            const code = entry.value_ptr.*;

            foff += code.len;
            iovecs[iovecs_i] = .{ .base = code.ptr, .len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(data_i, .d);
            data_i += code.len;
            atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, target.cpu.arch.endian());
            }
            self.syms.items[atom.sym_index.?].value = off;
            if (self.nav_exports.get(nav_index)) |export_indices| {
                try self.addNavExports(pt.zcu, nav_index, export_indices);
            }
        }
        {
            var it_uav = self.uavs.iterator();
            while (it_uav.next()) |kv| {
                const atom = self.getAtomPtr(kv.value_ptr.*);
                const code = atom.code.getOwnedCode().?;
                log.debug("write anon decl: {s}", .{self.syms.items[atom.sym_index.?].name});
                foff += code.len;
                iovecs[iovecs_i] = .{ .base = code.ptr, .len = code.len };
                iovecs_i += 1;
                const off = self.getAddr(data_i, .d);
                data_i += code.len;
                atom.offset = off;
                if (!self.sixtyfour_bit) {
                    mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, target.cpu.arch.endian());
                }
                self.syms.items[atom.sym_index.?].value = off;
            }
        }
        // the lazy data symbols
        var it_lazy = self.lazy_syms.iterator();
        while (it_lazy.next()) |kv| {
            const meta = kv.value_ptr;
            const data_atom = if (meta.rodata_state != .unused) self.getAtomPtr(meta.rodata_atom) else continue;
            const code = data_atom.code.getOwnedCode().?; // lazy symbols must own their code
            foff += code.len;
            iovecs[iovecs_i] = .{ .base = code.ptr, .len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(data_i, .d);
            data_i += code.len;
            data_atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[data_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[data_atom.got_index.? * 8 ..][0..8], off, target.cpu.arch.endian());
            }
            self.syms.items[data_atom.sym_index.?].value = off;
        }
        // edata symbol
        if (self.etext_edata_end_atom_indices[1]) |edata_atom_idx| {
            const edata_atom = self.getAtom(edata_atom_idx);
            const val = self.getAddr(data_i, .b);
            self.syms.items[edata_atom.sym_index.?].value = val;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[edata_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[edata_atom.got_index.? * 8 ..][0..8], val, target.cpu.arch.endian());
            }
        }
        // end symbol (same as edata because native backends don't do .bss yet)
        if (self.etext_edata_end_atom_indices[2]) |end_atom_idx| {
            const end_atom = self.getAtom(end_atom_idx);
            const val = self.getAddr(data_i, .b);
            self.syms.items[end_atom.sym_index.?].value = val;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[end_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), target.cpu.arch.endian());
            } else {
                log.debug("write end (got_table[0x{x}] = 0x{x})", .{ end_atom.got_index.? * 8, val });
                mem.writeInt(u64, got_table[end_atom.got_index.? * 8 ..][0..8], val, target.cpu.arch.endian());
            }
        }
    }
    var sym_buf = std.ArrayList(u8).init(gpa);
    try self.writeSyms(&sym_buf);
    const syms = try sym_buf.toOwnedSlice();
    defer gpa.free(syms);
    assert(2 + self.atomCount() - self.externCount() == iovecs_i); // we didn't write all the decls
    iovecs[iovecs_i] = .{ .base = syms.ptr, .len = syms.len };
    iovecs_i += 1;
    iovecs[iovecs_i] = .{ .base = linecountinfo.items.ptr, .len = linecountinfo.items.len };
    iovecs_i += 1;
    // generate the header
    self.hdr = .{
        .magic = self.magic,
        .text = @as(u32, @intCast(text_i)),
        .data = @as(u32, @intCast(data_i)),
        .syms = @as(u32, @intCast(syms.len)),
        .bss = 0,
        .spsz = 0,
        .pcsz = @as(u32, @intCast(linecountinfo.items.len)),
        .entry = @as(u32, @intCast(self.entry_val.?)),
    };
    @memcpy(hdr_slice, self.hdr.toU8s()[0..hdr_size]);
    // write the fat header for 64 bit entry points
    if (self.sixtyfour_bit) {
        mem.writeInt(u64, hdr_buf[32..40], self.entry_val.?, .big);
    }
    // perform the relocs
    {
        var it = self.relocs.iterator();
        while (it.next()) |kv| {
            const source_atom_index = kv.key_ptr.*;
            const source_atom = self.getAtom(source_atom_index);
            const source_atom_symbol = self.syms.items[source_atom.sym_index.?];
            const code = source_atom.code.getCode(self);
            const endian = target.cpu.arch.endian();
            for (kv.value_ptr.items) |reloc| {
                const offset = reloc.offset;
                const addend = reloc.addend;
                if (reloc.type == .pcrel or reloc.type == .nonpcrel) {
                    const target_atom_index = reloc.target;
                    const target_atom = self.getAtomPtr(target_atom_index);
                    const target_symbol = self.syms.items[target_atom.sym_index.?];
                    const target_offset = target_atom.offset.?;

                    switch (reloc.type) {
                        .pcrel => {
                            const disp = @as(i32, @intCast(target_offset)) - @as(i32, @intCast(source_atom.offset.?)) - 4 - @as(i32, @intCast(offset));
                            mem.writeInt(i32, code[@as(usize, @intCast(offset))..][0..4], @as(i32, @intCast(disp)), endian);
                        },
                        .nonpcrel => {
                            if (!self.sixtyfour_bit) {
                                mem.writeInt(u32, code[@intCast(offset)..][0..4], @as(u32, @intCast(target_offset + addend)), endian);
                            } else {
                                mem.writeInt(u64, code[@intCast(offset)..][0..8], target_offset + addend, endian);
                            }
                        },
                        else => unreachable,
                    }
                    log.debug("relocating the address of '{s}' + {d} into '{s}' + {d} (({s}[{d}] = 0x{x} + 0x{x})", .{ target_symbol.name, addend, source_atom_symbol.name, offset, source_atom_symbol.name, offset, target_offset, addend });
                } else {
                    const addr = switch (reloc.type) {
                        .special_etext => self.syms.items[self.getAtom(self.etext_edata_end_atom_indices[0].?).sym_index.?].value,
                        .special_edata => self.syms.items[self.getAtom(self.etext_edata_end_atom_indices[1].?).sym_index.?].value,
                        .special_end => self.syms.items[self.getAtom(self.etext_edata_end_atom_indices[2].?).sym_index.?].value,
                        else => unreachable,
                    };
                    if (!self.sixtyfour_bit) {
                        mem.writeInt(u32, code[@intCast(offset)..][0..4], @as(u32, @intCast(addr + addend)), endian);
                    } else {
                        mem.writeInt(u64, code[@intCast(offset)..][0..8], addr + addend, endian);
                    }
                    log.debug("relocating the address of '{s}' + {d} into '{s}' + {d} (({s}[{d}] = 0x{x} + 0x{x})", .{ @tagName(reloc.type), addend, source_atom_symbol.name, offset, source_atom_symbol.name, offset, addr, addend });
                }
            }
        }
    }
    // write it all!
    try file.pwritevAll(iovecs, 0);
}
fn addNavExports(
    self: *Plan9,
    mod: *Zcu,
    nav_index: InternPool.Nav.Index,
    export_indices: []const u32,
) !void {
    const gpa = self.base.comp.gpa;
    const metadata = self.navs.getPtr(nav_index).?;
    const atom = self.getAtom(metadata.index);

    for (export_indices) |export_idx| {
        const exp = mod.all_exports.items[export_idx];
        const exp_name = exp.opts.name.toSlice(&mod.intern_pool);
        // plan9 does not support custom sections
        if (exp.opts.section.unwrap()) |section_name| {
            if (!section_name.eqlSlice(".text", &mod.intern_pool) and
                !section_name.eqlSlice(".data", &mod.intern_pool))
            {
                try mod.failed_exports.put(mod.gpa, export_idx, try Zcu.ErrorMsg.create(
                    gpa,
                    mod.navSrcLoc(nav_index),
                    "plan9 does not support extra sections",
                    .{},
                ));
                break;
            }
        }
        const sym = .{
            .value = atom.offset.?,
            .type = atom.type.toGlobal(),
            .name = try gpa.dupe(u8, exp_name),
        };

        if (metadata.getExport(self, exp_name)) |i| {
            self.syms.items[i] = sym;
        } else {
            try self.syms.append(gpa, sym);
            try metadata.exports.append(gpa, self.syms.items.len - 1);
        }
    }
}

pub fn freeDecl(self: *Plan9, decl_index: InternPool.DeclIndex) void {
    const gpa = self.base.comp.gpa;
    // TODO audit the lifetimes of decls table entries. It's possible to get
    // freeDecl without any updateDecl in between.
    const zcu = self.base.comp.zcu.?;
    const decl = zcu.declPtr(decl_index);
    const is_fn = decl.val.isFuncBody(zcu);
    if (is_fn) {
        const symidx_and_submap = self.fn_decl_table.get(decl.getFileScope(zcu)).?;
        var submap = symidx_and_submap.functions;
        if (submap.fetchSwapRemove(decl_index)) |removed_entry| {
            gpa.free(removed_entry.value.code);
            gpa.free(removed_entry.value.lineinfo);
        }
        if (submap.count() == 0) {
            self.syms.items[symidx_and_submap.sym_index] = aout.Sym.undefined_symbol;
            self.syms_index_free_list.append(gpa, symidx_and_submap.sym_index) catch {};
            submap.deinit(gpa);
        }
    } else {
        if (self.data_decl_table.fetchSwapRemove(decl_index)) |removed_entry| {
            gpa.free(removed_entry.value);
        }
    }
    if (self.decls.fetchRemove(decl_index)) |const_kv| {
        var kv = const_kv;
        const atom = self.getAtom(kv.value.index);
        if (atom.got_index) |i| {
            // TODO: if this catch {} is triggered, an assertion in flushModule will be triggered, because got_index_free_list will have the wrong length
            self.got_index_free_list.append(gpa, i) catch {};
        }
        if (atom.sym_index) |i| {
            self.syms_index_free_list.append(gpa, i) catch {};
            self.syms.items[i] = aout.Sym.undefined_symbol;
        }
        kv.value.exports.deinit(gpa);
    }
    {
        const atom_index = self.decls.get(decl_index).?.index;
        const relocs = self.relocs.getPtr(atom_index) orelse return;
        relocs.clearAndFree(gpa);
        assert(self.relocs.remove(atom_index));
    }
}
fn createAtom(self: *Plan9) !Atom.Index {
    const gpa = self.base.comp.gpa;
    const index = @as(Atom.Index, @intCast(self.atoms.items.len));
    const atom = try self.atoms.addOne(gpa);
    atom.* = .{
        .type = .t,
        .offset = null,
        .sym_index = null,
        .got_index = null,
        .code = undefined,
    };
    return index;
}

pub fn seeNav(self: *Plan9, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !Atom.Index {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const gop = try self.navs.getOrPut(gpa, nav_index);
    if (!gop.found_existing) {
        const index = try self.createAtom();
        self.getAtomPtr(index).got_index = self.allocateGotIndex();
        gop.value_ptr.* = .{
            .index = index,
            .exports = .{},
        };
    }
    const atom_idx = gop.value_ptr.index;
    // handle externs here because they might not get updateDecl called on them
    const nav = ip.getNav(nav_index);
    if (ip.indexToKey(nav.status.resolved.val) == .@"extern") {
        // this is a "phantom atom" - it is never actually written to disk, just convenient for us to store stuff about externs
        if (nav.name.eqlSlice("etext", ip)) {
            self.etext_edata_end_atom_indices[0] = atom_idx;
        } else if (nav.name.eqlSlice("edata", ip)) {
            self.etext_edata_end_atom_indices[1] = atom_idx;
        } else if (nav.name.eqlSlice("end", ip)) {
            self.etext_edata_end_atom_indices[2] = atom_idx;
        }
        try self.updateFinish(pt, nav_index);
        log.debug("seeNav(extern) for {} (got_addr=0x{x})", .{
            nav.name.fmt(ip),
            self.getAtom(atom_idx).getOffsetTableAddress(self),
        });
    } else log.debug("seeNav for {}", .{nav.name.fmt(ip)});
    return atom_idx;
}

pub fn updateExports(
    self: *Plan9,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const u32,
) !void {
    const gpa = self.base.comp.gpa;
    switch (exported) {
        .uav => @panic("TODO: plan9 updateExports handling values"),
        .nav => |nav| {
            _ = try self.seeNav(pt, nav);
            if (self.nav_exports.fetchSwapRemove(nav)) |kv| {
                gpa.free(kv.value);
            }
            try self.nav_exports.ensureUnusedCapacity(gpa, 1);
            const duped_indices = try gpa.dupe(u32, export_indices);
            self.nav_exports.putAssumeCapacityNoClobber(nav, duped_indices);
        },
    }
    // all proper work is done in flush
}

pub fn getOrCreateAtomForLazySymbol(self: *Plan9, pt: Zcu.PerThread, lazy_sym: File.LazySymbol) !Atom.Index {
    const gop = try self.lazy_syms.getOrPut(pt.zcu.gpa, lazy_sym.ty);
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();

    if (!gop.found_existing) gop.value_ptr.* = .{};

    const atom_ptr, const state_ptr = switch (lazy_sym.kind) {
        .code => .{ &gop.value_ptr.text_atom, &gop.value_ptr.text_state },
        .const_data => .{ &gop.value_ptr.rodata_atom, &gop.value_ptr.rodata_state },
    };
    switch (state_ptr.*) {
        .unused => atom_ptr.* = try self.createAtom(),
        .pending_flush => return atom_ptr.*,
        .flushed => {},
    }
    state_ptr.* = .pending_flush;
    const atom = atom_ptr.*;
    _ = try self.getAtomPtr(atom).getOrCreateSymbolTableEntry(self);
    _ = self.getAtomPtr(atom).getOrCreateOffsetTableEntry(self);
    // anyerror needs to be deferred until flushModule
    if (lazy_sym.ty != .anyerror_type) try self.updateLazySymbolAtom(pt, lazy_sym, atom);
    return atom;
}

fn updateLazySymbolAtom(self: *Plan9, pt: Zcu.PerThread, sym: File.LazySymbol, atom_index: Atom.Index) !void {
    const gpa = pt.zcu.gpa;

    var required_alignment: InternPool.Alignment = .none;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    // create the symbol for the name
    const name = try std.fmt.allocPrint(gpa, "__lazy_{s}_{}", .{
        @tagName(sym.kind),
        Type.fromInterned(sym.ty).fmt(pt),
    });

    const symbol: aout.Sym = .{
        .value = undefined,
        .type = if (sym.kind == .code) .t else .d,
        .name = name,
    };
    self.syms.items[self.getAtomPtr(atom_index).sym_index.?] = symbol;

    // generate the code
    const src = Type.fromInterned(sym.ty).srcLocOrNull(pt.zcu) orelse Zcu.LazySrcLoc.unneeded;
    const res = try codegen.generateLazySymbol(
        &self.base,
        pt,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .atom_index = @intCast(atom_index) },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };
    // duped_code is freed when the atom is freed
    const duped_code = try gpa.dupe(u8, code);
    errdefer gpa.free(duped_code);
    self.getAtomPtr(atom_index).code = .{
        .code_ptr = duped_code.ptr,
        .other = .{ .code_len = duped_code.len },
    };
}

pub fn deinit(self: *Plan9) void {
    const gpa = self.base.comp.gpa;
    {
        var it = self.relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(gpa);
        }
        self.relocs.deinit(gpa);
    }
    var it_lzc = self.lazy_syms.iterator();
    while (it_lzc.next()) |kv| {
        if (kv.value_ptr.text_state != .unused)
            gpa.free(self.syms.items[self.getAtom(kv.value_ptr.text_atom).sym_index.?].name);
        if (kv.value_ptr.rodata_state != .unused)
            gpa.free(self.syms.items[self.getAtom(kv.value_ptr.rodata_atom).sym_index.?].name);
    }
    self.lazy_syms.deinit(gpa);
    var itf_files = self.fn_nav_table.iterator();
    while (itf_files.next()) |ent| {
        // get the submap
        var submap = ent.value_ptr.functions;
        defer submap.deinit(gpa);
        var itf = submap.iterator();
        while (itf.next()) |entry| {
            gpa.free(entry.value_ptr.code);
            gpa.free(entry.value_ptr.lineinfo);
        }
    }
    self.fn_nav_table.deinit(gpa);
    var itd = self.data_nav_table.iterator();
    while (itd.next()) |entry| {
        gpa.free(entry.value_ptr.*);
    }
    var it_uav = self.uavs.iterator();
    while (it_uav.next()) |entry| {
        const sym_index = self.getAtom(entry.value_ptr.*).sym_index.?;
        gpa.free(self.syms.items[sym_index].name);
    }
    self.data_nav_table.deinit(gpa);
    for (self.nav_exports.values()) |export_indices| {
        gpa.free(export_indices);
    }
    self.nav_exports.deinit(gpa);
    self.syms.deinit(gpa);
    self.got_index_free_list.deinit(gpa);
    self.syms_index_free_list.deinit(gpa);
    self.file_segments.deinit(gpa);
    self.path_arena.deinit();
    for (self.atoms.items) |a| {
        if (a.code.getOwnedCode()) |c| {
            gpa.free(c);
        }
    }
    self.atoms.deinit(gpa);

    {
        var it = self.navs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(gpa);
        }
        self.navs.deinit(gpa);
    }
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Plan9 {
    const target = comp.root_mod.resolved_target.result;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;

    assert(!use_llvm); // Caught by Compilation.Config.resolve.
    assert(!use_lld); // Caught by Compilation.Config.resolve.
    assert(target.ofmt == .plan9);

    const self = try createEmpty(arena, comp, emit, options);
    errdefer self.base.destroy();

    const file = try emit.root_dir.handle.createFile(emit.sub_path, .{
        .read = true,
        .mode = link.File.determineMode(
            use_lld,
            comp.config.output_mode,
            comp.config.link_mode,
        ),
    });
    errdefer file.close();
    self.base.file = file;

    self.bases = defaultBaseAddrs(target.cpu.arch);

    const gpa = comp.gpa;

    try self.syms.appendSlice(gpa, &.{
        // we include the global offset table to make it easier for debugging
        .{
            .value = self.getAddr(0, .d), // the global offset table starts at 0
            .type = .d,
            .name = "__GOT",
        },
    });

    return self;
}

pub fn writeSym(self: *Plan9, w: anytype, sym: aout.Sym) !void {
    // log.debug("write sym{{name: {s}, value: {x}}}", .{ sym.name, sym.value });
    if (sym.type == .bad) return; // we don't want to write free'd symbols
    if (!self.sixtyfour_bit) {
        try w.writeInt(u32, @as(u32, @intCast(sym.value)), .big);
    } else {
        try w.writeInt(u64, sym.value, .big);
    }
    try w.writeByte(@intFromEnum(sym.type));
    try w.writeAll(sym.name);
    try w.writeByte(0);
}

pub fn writeSyms(self: *Plan9, buf: *std.ArrayList(u8)) !void {
    const zcu = self.base.comp.zcu.?;
    const ip = &zcu.intern_pool;
    const writer = buf.writer();
    // write __GOT
    try self.writeSym(writer, self.syms.items[0]);
    // write the f symbols
    {
        var it = self.file_segments.iterator();
        while (it.next()) |entry| {
            try self.writeSym(writer, .{
                .type = .f,
                .value = entry.value_ptr.*,
                .name = entry.key_ptr.*,
            });
        }
    }

    // write the data symbols
    {
        var it = self.data_nav_table.iterator();
        while (it.next()) |entry| {
            const nav_index = entry.key_ptr.*;
            const nav_metadata = self.navs.get(nav_index).?;
            const atom = self.getAtom(nav_metadata.index);
            const sym = self.syms.items[atom.sym_index.?];
            try self.writeSym(writer, sym);
            if (self.nav_exports.get(nav_index)) |export_indices| {
                for (export_indices) |export_idx| {
                    const exp = zcu.all_exports.items[export_idx];
                    if (nav_metadata.getExport(self, exp.opts.name.toSlice(ip))) |exp_i| {
                        try self.writeSym(writer, self.syms.items[exp_i]);
                    }
                }
            }
        }
    }
    // the data lazy symbols
    {
        var it = self.lazy_syms.iterator();
        while (it.next()) |kv| {
            const meta = kv.value_ptr;
            const data_atom = if (meta.rodata_state != .unused) self.getAtomPtr(meta.rodata_atom) else continue;
            const sym = self.syms.items[data_atom.sym_index.?];
            try self.writeSym(writer, sym);
        }
    }
    // text symbols are the hardest:
    // the file of a text symbol is the .z symbol before it
    // so we have to write everything in the right order
    {
        var it_file = self.fn_nav_table.iterator();
        while (it_file.next()) |fentry| {
            var symidx_and_submap = fentry.value_ptr;
            // write the z symbols
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index - 1]);
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index]);

            // write all the decls come from the file of the z symbol
            var submap_it = symidx_and_submap.functions.iterator();
            while (submap_it.next()) |entry| {
                const nav_index = entry.key_ptr.*;
                const nav_metadata = self.navs.get(nav_index).?;
                const atom = self.getAtom(nav_metadata.index);
                const sym = self.syms.items[atom.sym_index.?];
                try self.writeSym(writer, sym);
                if (self.nav_exports.get(nav_index)) |export_indices| {
                    for (export_indices) |export_idx| {
                        const exp = zcu.all_exports.items[export_idx];
                        if (nav_metadata.getExport(self, exp.opts.name.toSlice(ip))) |exp_i| {
                            const s = self.syms.items[exp_i];
                            if (mem.eql(u8, s.name, "_start"))
                                self.entry_val = s.value;
                            try self.writeSym(writer, s);
                        }
                    }
                }
            }
        }
        // the text lazy symbols
        {
            var it = self.lazy_syms.iterator();
            while (it.next()) |kv| {
                const meta = kv.value_ptr;
                const text_atom = if (meta.text_state != .unused) self.getAtomPtr(meta.text_atom) else continue;
                const sym = self.syms.items[text_atom.sym_index.?];
                try self.writeSym(writer, sym);
            }
        }
    }
    // special symbols
    for (self.etext_edata_end_atom_indices) |idx| {
        if (idx) |atom_idx| {
            const atom = self.getAtom(atom_idx);
            const sym = self.syms.items[atom.sym_index.?];
            try self.writeSym(writer, sym);
        }
    }
}

/// Must be called only after a successful call to `updateDecl`.
pub fn updateDeclLineNumber(self: *Plan9, pt: Zcu.PerThread, decl_index: InternPool.DeclIndex) !void {
    _ = self;
    _ = pt;
    _ = decl_index;
}

pub fn getNavVAddr(
    self: *Plan9,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const ip = &pt.zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("getDeclVAddr for {}", .{nav.name.fmt(ip)});
    if (ip.indexToKey(nav.status.resolved.val) == .@"extern") {
        if (nav.name.eqlSlice("etext", ip)) {
            try self.addReloc(reloc_info.parent.atom_index, .{
                .target = undefined,
                .offset = reloc_info.offset,
                .addend = reloc_info.addend,
                .type = .special_etext,
            });
        } else if (nav.name.eqlSlice("edata", ip)) {
            try self.addReloc(reloc_info.parent.atom_index, .{
                .target = undefined,
                .offset = reloc_info.offset,
                .addend = reloc_info.addend,
                .type = .special_edata,
            });
        } else if (nav.name.eqlSlice("end", ip)) {
            try self.addReloc(reloc_info.parent.atom_index, .{
                .target = undefined,
                .offset = reloc_info.offset,
                .addend = reloc_info.addend,
                .type = .special_end,
            });
        }
        // TODO handle other extern variables and functions
        return undefined;
    }
    // otherwise, we just add a relocation
    const atom_index = try self.seeNav(pt, nav_index);
    // the parent_atom_index in this case is just the decl_index of the parent
    try self.addReloc(reloc_info.parent.atom_index, .{
        .target = atom_index,
        .offset = reloc_info.offset,
        .addend = reloc_info.addend,
    });
    return undefined;
}

pub fn lowerUav(
    self: *Plan9,
    pt: Zcu.PerThread,
    uav: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.GenResult {
    _ = explicit_alignment;
    // example:
    // const ty = mod.intern_pool.typeOf(decl_val).toType();
    // const val = decl_val.toValue();
    // The symbol name can be something like `__anon_{d}` with `@intFromEnum(decl_val)`.
    // It doesn't have an owner decl because it's just an unnamed constant that might
    // be used by more than one function, however, its address is being used so we need
    // to put it in some location.
    // ...
    const gpa = self.base.comp.gpa;
    const gop = try self.uavs.getOrPut(gpa, uav);
    if (gop.found_existing) return .{ .mcv = .{ .load_direct = gop.value_ptr.* } };
    const val = Value.fromInterned(uav);
    const name = try std.fmt.allocPrint(gpa, "__anon_{d}", .{@intFromEnum(uav)});

    const index = try self.createAtom();
    const got_index = self.allocateGotIndex();
    gop.value_ptr.* = index;
    // we need to free name latex
    var code_buffer = std.ArrayList(u8).init(gpa);
    const res = try codegen.generateSymbol(&self.base, pt, src_loc, val, &code_buffer, .{ .atom_index = index });
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| return .{ .fail = em },
    };
    const atom_ptr = self.getAtomPtr(index);
    atom_ptr.* = .{
        .type = .d,
        .offset = undefined,
        .sym_index = null,
        .got_index = got_index,
        .code = Atom.CodePtr.fromSlice(code),
    };
    _ = try atom_ptr.getOrCreateSymbolTableEntry(self);
    self.syms.items[atom_ptr.sym_index.?] = .{
        .type = .d,
        .value = undefined,
        .name = name,
    };
    return .{ .mcv = .{ .load_direct = index } };
}

pub fn getUavVAddr(self: *Plan9, uav: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    const atom_index = self.uavs.get(uav).?;
    try self.addReloc(reloc_info.parent.atom_index, .{
        .target = atom_index,
        .offset = reloc_info.offset,
        .addend = reloc_info.addend,
    });
    return undefined;
}

pub fn addReloc(self: *Plan9, parent_index: Atom.Index, reloc: Reloc) !void {
    const gpa = self.base.comp.gpa;
    const gop = try self.relocs.getOrPut(gpa, parent_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn getAtom(self: *const Plan9, index: Atom.Index) Atom {
    return self.atoms.items[index];
}

fn getAtomPtr(self: *Plan9, index: Atom.Index) *Atom {
    return &self.atoms.items[index];
}
