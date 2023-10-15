//! This implementation does all the linking work in flush(). A future improvement
//! would be to add incremental linking in a similar way as ELF does.

const Plan9 = @This();
const link = @import("../link.zig");
const Module = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const Compilation = @import("../Compilation.zig");
const aout = @import("Plan9/aout.zig");
const codegen = @import("../codegen.zig");
const trace = @import("../tracy.zig").trace;
const File = link.File;
const build_options = @import("build_options");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const TypedValue = @import("../TypedValue.zig");

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.link);
const assert = std.debug.assert;

pub const base_tag = .plan9;

base: link.File,
sixtyfour_bit: bool,
error_flags: File.ErrorFlags = File.ErrorFlags{},
bases: Bases,

/// A symbol's value is just casted down when compiling
/// for a 32 bit target.
/// Does not represent the order or amount of symbols in the file
/// it is just useful for storing symbols. Some other symbols are in
/// file_segments.
syms: std.ArrayListUnmanaged(aout.Sym) = .{},

/// The plan9 a.out format requires segments of
/// filenames to be deduplicated, so we use this map to
/// de duplicate it. The value is the value of the path
/// component
file_segments: std.StringArrayHashMapUnmanaged(u16) = .{},
/// The value of a 'f' symbol increments by 1 every time, so that no 2 'f'
/// symbols have the same value.
file_segments_i: u16 = 1,

path_arena: std.heap.ArenaAllocator,

/// maps a file scope to a hash map of decl to codegen output
/// this is useful for line debuginfo, since it makes sense to sort by file
/// The debugger looks for the first file (aout.Sym.Type.z) preceeding the text symbol
/// of the function to know what file it came from.
/// If we group the decls by file, it makes it really easy to do this (put the symbol in the correct place)
fn_decl_table: std.AutoArrayHashMapUnmanaged(
    *Module.File,
    struct { sym_index: u32, functions: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, FnDeclOutput) = .{} },
) = .{},
/// the code is modified when relocated, so that is why it is mutable
data_decl_table: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, []u8) = .{},

/// Table of unnamed constants associated with a parent `Decl`.
/// We store them here so that we can free the constants whenever the `Decl`
/// needs updating or is freed.
///
/// For example,
///
/// ```zig
/// const Foo = struct{
///     a: u8,
/// };
///
/// pub fn main() void {
///     var foo = Foo{ .a = 1 };
///     _ = foo;
/// }
/// ```
///
/// value assigned to label `foo` is an unnamed constant belonging/associated
/// with `Decl` `main`, and lives as long as that `Decl`.
unnamed_const_atoms: UnnamedConstTable = .{},

lazy_syms: LazySymbolTable = .{},

anon_decls: std.AutoHashMapUnmanaged(InternPool.Index, Atom.Index) = .{},

relocs: std.AutoHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Reloc)) = .{},
hdr: aout.ExecHdr = undefined,

// relocs: std.
magic: u32,

entry_val: ?u64 = null,

got_len: usize = 0,
// A list of all the free got indexes, so when making a new decl
// don't make a new one, just use one from here.
got_index_free_list: std.ArrayListUnmanaged(usize) = .{},

syms_index_free_list: std.ArrayListUnmanaged(usize) = .{},

atoms: std.ArrayListUnmanaged(Atom) = .{},
decls: std.AutoHashMapUnmanaged(Module.Decl.Index, DeclMetadata) = .{},

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

const UnnamedConstTable = std.AutoHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(Atom.Index));

const LazySymbolTable = std.AutoArrayHashMapUnmanaged(Module.Decl.OptionalIndex, LazySymbolMetadata);

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
    /// In the case of unnamed_const_atoms and lazy_syms, this atom owns the code.
    /// But, in the case of function and data decls, they own the code and this field
    /// is just a pointer for convience.
    code: CodePtr,

    const CodePtr = struct {
        code_ptr: ?[*]u8,
        other: union {
            code_len: usize,
            decl_index: Module.Decl.Index,
        },
        fn fromSlice(slice: []u8) CodePtr {
            return .{ .code_ptr = slice.ptr, .other = .{ .code_len = slice.len } };
        }
        fn getCode(self: CodePtr, plan9: *const Plan9) []u8 {
            const mod = plan9.base.options.module.?;
            return if (self.code_ptr) |p| p[0..self.other.code_len] else blk: {
                const decl_index = self.other.decl_index;
                const decl = mod.declPtr(decl_index);
                if (decl.ty.zigTypeTag(mod) == .Fn) {
                    const table = plan9.fn_decl_table.get(decl.getFileScope(mod)).?.functions;
                    const output = table.get(decl_index).?;
                    break :blk output.code;
                } else {
                    break :blk plan9.data_decl_table.get(decl_index).?;
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
        const ptr_bytes = @divExact(plan9.base.options.target.ptrBitWidth(), 8);
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

const DeclMetadata = struct {
    index: Atom.Index,
    exports: std.ArrayListUnmanaged(usize) = .{},

    fn getExport(m: DeclMetadata, p9: *const Plan9, name: []const u8) ?usize {
        for (m.exports.items) |exp| {
            const sym = p9.syms.items[exp];
            if (mem.eql(u8, name, sym.name)) return exp;
        }
        return null;
    }
};

const FnDeclOutput = struct {
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

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    const sixtyfour_bit: bool = switch (options.target.ptrBitWidth()) {
        0...32 => false,
        33...64 => true,
        else => return error.UnsupportedP9Architecture,
    };

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);

    const self = try gpa.create(Plan9);
    self.* = .{
        .path_arena = arena_allocator,
        .base = .{
            .tag = .plan9,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .sixtyfour_bit = sixtyfour_bit,
        .bases = undefined,
        .magic = try aout.magicFromArch(self.base.options.target.cpu.arch),
    };
    // a / will always be in a file path
    try self.file_segments.put(self.base.allocator, "/", 1);
    return self;
}

fn putFn(self: *Plan9, decl_index: Module.Decl.Index, out: FnDeclOutput) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const fn_map_res = try self.fn_decl_table.getOrPut(gpa, decl.getFileScope(mod));
    if (fn_map_res.found_existing) {
        if (try fn_map_res.value_ptr.functions.fetchPut(gpa, decl_index, out)) |old_entry| {
            gpa.free(old_entry.value.code);
            gpa.free(old_entry.value.lineinfo);
        }
    } else {
        const file = decl.getFileScope(mod);
        const arena = self.path_arena.allocator();
        // each file gets a symbol
        fn_map_res.value_ptr.* = .{
            .sym_index = blk: {
                try self.syms.append(gpa, undefined);
                try self.syms.append(gpa, undefined);
                break :blk @as(u32, @intCast(self.syms.items.len - 1));
            },
        };
        try fn_map_res.value_ptr.functions.put(gpa, decl_index, out);

        var a = std.ArrayList(u8).init(arena);
        errdefer a.deinit();
        // every 'z' starts with 0
        try a.append(0);
        // path component value of '/'
        try a.writer().writeIntBig(u16, 1);

        // getting the full file path
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const full_path = try std.fs.path.join(arena, &.{
            file.mod.root.root_dir.path orelse try std.os.getcwd(&buf),
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
    const sep = std.fs.path.sep;
    var it = std.mem.tokenizeScalar(u8, path, sep);
    while (it.next()) |component| {
        if (self.file_segments.get(component)) |num| {
            try a.writer().writeIntBig(u16, num);
        } else {
            self.file_segments_i += 1;
            try self.file_segments.put(self.base.allocator, component, self.file_segments_i);
            try a.writer().writeIntBig(u16, self.file_segments_i);
        }
    }
}

pub fn updateFunc(self: *Plan9, mod: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);
    self.freeUnnamedConsts(decl_index);

    const atom_idx = try self.seeDecl(decl_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();
    var dbg_info_output: DebugInfoOutput = .{
        .dbg_line = std.ArrayList(u8).init(self.base.allocator),
        .start_line = null,
        .end_line = undefined,
        .pcop_change_index = null,
        // we have already checked the target in the linker to make sure it is compatable
        .pc_quanta = aout.getPCQuant(self.base.options.target.cpu.arch) catch unreachable,
    };
    defer dbg_info_output.dbg_line.deinit();

    const res = try codegen.generateFunction(
        &self.base,
        decl.srcLoc(mod),
        func_index,
        air,
        liveness,
        &code_buffer,
        .{ .plan9 = &dbg_info_output },
    );
    const code = switch (res) {
        .ok => try code_buffer.toOwnedSlice(),
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };
    self.getAtomPtr(atom_idx).code = .{
        .code_ptr = null,
        .other = .{ .decl_index = decl_index },
    };
    const out: FnDeclOutput = .{
        .code = code,
        .lineinfo = try dbg_info_output.dbg_line.toOwnedSlice(),
        .start_line = dbg_info_output.start_line.?,
        .end_line = dbg_info_output.end_line,
    };
    try self.putFn(decl_index, out);
    return self.updateFinish(decl_index);
}

pub fn lowerUnnamedConst(self: *Plan9, tv: TypedValue, decl_index: Module.Decl.Index) !u32 {
    _ = try self.seeDecl(decl_index);
    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const gop = try self.unnamed_const_atoms.getOrPut(self.base.allocator, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;

    const decl_name = mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(mod));

    const index = unnamed_consts.items.len;
    // name is freed when the unnamed const is freed
    const name = try std.fmt.allocPrint(self.base.allocator, "__unnamed_{s}_{d}", .{ decl_name, index });

    const sym_index = try self.allocateSymbolIndex();
    const new_atom_idx = try self.createAtom();
    var info: Atom = .{
        .type = .d,
        .offset = null,
        .sym_index = sym_index,
        .got_index = self.allocateGotIndex(),
        .code = undefined, // filled in later
    };
    const sym: aout.Sym = .{
        .value = undefined,
        .type = info.type,
        .name = name,
    };
    self.syms.items[info.sym_index.?] = sym;

    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(mod), tv, &code_buffer, .{
        .none = {},
    }, .{
        .parent_atom_index = new_atom_idx,
    });
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };
    // duped_code is freed when the unnamed const is freed
    var duped_code = try self.base.allocator.dupe(u8, code);
    errdefer self.base.allocator.free(duped_code);
    const new_atom = self.getAtomPtr(new_atom_idx);
    new_atom.* = info;
    new_atom.code = .{ .code_ptr = duped_code.ptr, .other = .{ .code_len = duped_code.len } };
    try unnamed_consts.append(self.base.allocator, new_atom_idx);
    // we return the new_atom_idx to codegen
    return new_atom_idx;
}

pub fn updateDecl(self: *Plan9, mod: *Module, decl_index: Module.Decl.Index) !void {
    const decl = mod.declPtr(decl_index);

    if (decl.isExtern(mod)) {
        log.debug("found extern decl: {s}", .{mod.intern_pool.stringToSlice(decl.name)});
        return;
    }
    const atom_idx = try self.seeDecl(decl_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();
    const decl_val = if (decl.val.getVariable(mod)) |variable| variable.init.toValue() else decl.val;
    // TODO we need the symbol index for symbol in the table of locals for the containing atom
    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(mod), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, .{ .none = {} }, .{
        .parent_atom_index = @as(Atom.Index, @intCast(atom_idx)),
    });
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };
    try self.data_decl_table.ensureUnusedCapacity(self.base.allocator, 1);
    const duped_code = try self.base.allocator.dupe(u8, code);
    self.getAtomPtr(self.decls.get(decl_index).?.index).code = .{ .code_ptr = null, .other = .{ .decl_index = decl_index } };
    if (self.data_decl_table.fetchPutAssumeCapacity(decl_index, duped_code)) |old_entry| {
        self.base.allocator.free(old_entry.value);
    }
    return self.updateFinish(decl_index);
}
/// called at the end of update{Decl,Func}
fn updateFinish(self: *Plan9, decl_index: Module.Decl.Index) !void {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const is_fn = (decl.ty.zigTypeTag(mod) == .Fn);
    const sym_t: aout.Sym.Type = if (is_fn) .t else .d;

    const atom = self.getAtomPtr(self.decls.get(decl_index).?.index);
    // write the internal linker metadata
    atom.type = sym_t;
    // write the symbol
    // we already have the got index
    const sym: aout.Sym = .{
        .value = undefined, // the value of stuff gets filled in in flushModule
        .type = atom.type,
        .name = try self.base.allocator.dupe(u8, mod.intern_pool.stringToSlice(decl.name)),
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
    if (self.syms_index_free_list.popOrNull()) |i| {
        return i;
    } else {
        _ = try self.syms.addOne(self.base.allocator);
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

pub fn flush(self: *Plan9, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    assert(!self.base.options.use_lld);

    switch (self.base.options.effectiveOutputMode()) {
        .Exe => {},
        // plan9 object files are totally different
        .Obj => return error.TODOImplementPlan9Objs,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    return self.flushModule(comp, prog_node);
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
        try l.writer().writeIntBig(i32, delta_line);
    }
}

fn externCount(self: *Plan9) usize {
    var extern_atom_count: usize = 0;
    for (self.etext_edata_end_atom_indices) |idx| {
        if (idx != null) extern_atom_count += 1;
    }
    return extern_atom_count;
}
// counts decls, unnamed consts, and lazy syms
fn atomCount(self: *Plan9) usize {
    var fn_decl_count: usize = 0;
    var itf_files = self.fn_decl_table.iterator();
    while (itf_files.next()) |ent| {
        // get the submap
        var submap = ent.value_ptr.functions;
        fn_decl_count += submap.count();
    }
    const data_decl_count = self.data_decl_table.count();
    var unnamed_const_count: usize = 0;
    var it_unc = self.unnamed_const_atoms.iterator();
    while (it_unc.next()) |unnamed_consts| {
        unnamed_const_count += unnamed_consts.value_ptr.items.len;
    }
    var lazy_atom_count: usize = 0;
    var it_lazy = self.lazy_syms.iterator();
    while (it_lazy.next()) |kv| {
        lazy_atom_count += kv.value_ptr.numberOfAtoms();
    }
    const anon_atom_count = self.anon_decls.count();
    const extern_atom_count = self.externCount();
    return data_decl_count + fn_decl_count + unnamed_const_count + lazy_atom_count + extern_atom_count + anon_atom_count;
}

pub fn flushModule(self: *Plan9, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (build_options.skip_non_native and builtin.object_format != .plan9) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    _ = comp;
    const tracy = trace(@src());
    defer tracy.end();

    var sub_prog_node = prog_node.start("Flush Module", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    log.debug("flushModule", .{});

    defer assert(self.hdr.entry != 0x0);

    const mod = self.base.options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    // finish up the lazy syms
    if (self.lazy_syms.getPtr(.none)) |metadata| {
        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbolAtom(
            File.LazySymbol.initDecl(.code, null, mod),
            metadata.text_atom,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
        if (metadata.rodata_state != .unused) self.updateLazySymbolAtom(
            File.LazySymbol.initDecl(.const_data, null, mod),
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
    var got_table = try self.base.allocator.alloc(u8, got_size);
    defer self.base.allocator.free(got_table);

    // + 4 for header, got, symbols, linecountinfo
    var iovecs = try self.base.allocator.alloc(std.os.iovec_const, self.atomCount() + 4 - self.externCount());
    defer self.base.allocator.free(iovecs);

    const file = self.base.file.?;

    var hdr_buf: [40]u8 = undefined;
    // account for the fat header
    const hdr_size = if (self.sixtyfour_bit) @as(usize, 40) else 32;
    const hdr_slice: []u8 = hdr_buf[0..hdr_size];
    var foff = hdr_size;
    iovecs[0] = .{ .iov_base = hdr_slice.ptr, .iov_len = hdr_slice.len };
    var iovecs_i: usize = 1;
    var text_i: u64 = 0;

    var linecountinfo = std.ArrayList(u8).init(self.base.allocator);
    defer linecountinfo.deinit();
    // text
    {
        var linecount: i64 = -1;
        var it_file = self.fn_decl_table.iterator();
        while (it_file.next()) |fentry| {
            var it = fentry.value_ptr.functions.iterator();
            while (it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                const decl = mod.declPtr(decl_index);
                const atom = self.getAtomPtr(self.decls.get(decl_index).?.index);
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
                iovecs[iovecs_i] = .{ .iov_base = out.code.ptr, .iov_len = out.code.len };
                iovecs_i += 1;
                const off = self.getAddr(text_i, .t);
                text_i += out.code.len;
                atom.offset = off;
                log.debug("write text decl {*} ({}), lines {d} to {d}.;__GOT+0x{x} vaddr: 0x{x}", .{ decl, decl.name.fmt(&mod.intern_pool), out.start_line + 1, out.end_line, atom.got_index.? * 8, off });
                if (!self.sixtyfour_bit) {
                    mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
                }
                self.syms.items[atom.sym_index.?].value = off;
                if (mod.decl_exports.get(decl_index)) |exports| {
                    try self.addDeclExports(mod, decl_index, exports.items);
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
            iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(text_i, .t);
            text_i += code.len;
            text_atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[text_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[text_atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
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
            mem.writeInt(u32, got_table[etext_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), self.base.options.target.cpu.arch.endian());
        } else {
            mem.writeInt(u64, got_table[etext_atom.got_index.? * 8 ..][0..8], val, self.base.options.target.cpu.arch.endian());
        }
    }
    // global offset table is in data
    iovecs[iovecs_i] = .{ .iov_base = got_table.ptr, .iov_len = got_table.len };
    iovecs_i += 1;
    // data
    var data_i: u64 = got_size;
    {
        var it = self.data_decl_table.iterator();
        while (it.next()) |entry| {
            const decl_index = entry.key_ptr.*;
            const atom = self.getAtomPtr(self.decls.get(decl_index).?.index);
            const code = entry.value_ptr.*;

            foff += code.len;
            iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(data_i, .d);
            data_i += code.len;
            atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
            }
            self.syms.items[atom.sym_index.?].value = off;
            if (mod.decl_exports.get(decl_index)) |exports| {
                try self.addDeclExports(mod, decl_index, exports.items);
            }
        }
        // write the unnamed constants after the other data decls
        var it_unc = self.unnamed_const_atoms.iterator();
        while (it_unc.next()) |unnamed_consts| {
            for (unnamed_consts.value_ptr.items) |atom_idx| {
                const atom = self.getAtomPtr(atom_idx);
                const code = atom.code.getOwnedCode().?; // unnamed consts must own their code
                log.debug("write unnamed const: ({s})", .{self.syms.items[atom.sym_index.?].name});
                foff += code.len;
                iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
                iovecs_i += 1;
                const off = self.getAddr(data_i, .d);
                data_i += code.len;
                atom.offset = off;
                if (!self.sixtyfour_bit) {
                    mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
                }
                self.syms.items[atom.sym_index.?].value = off;
            }
        }
        // the anon decls
        {
            var it_anon = self.anon_decls.iterator();
            while (it_anon.next()) |kv| {
                const atom = self.getAtomPtr(kv.value_ptr.*);
                const code = atom.code.getOwnedCode().?;
                log.debug("write anon decl: {s}", .{self.syms.items[atom.sym_index.?].name});
                foff += code.len;
                iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
                iovecs_i += 1;
                const off = self.getAddr(data_i, .d);
                data_i += code.len;
                atom.offset = off;
                if (!self.sixtyfour_bit) {
                    mem.writeInt(u32, got_table[atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
                } else {
                    mem.writeInt(u64, got_table[atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
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
            iovecs[iovecs_i] = .{ .iov_base = code.ptr, .iov_len = code.len };
            iovecs_i += 1;
            const off = self.getAddr(data_i, .d);
            data_i += code.len;
            data_atom.offset = off;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[data_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(off)), self.base.options.target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[data_atom.got_index.? * 8 ..][0..8], off, self.base.options.target.cpu.arch.endian());
            }
            self.syms.items[data_atom.sym_index.?].value = off;
        }
        // edata symbol
        if (self.etext_edata_end_atom_indices[1]) |edata_atom_idx| {
            const edata_atom = self.getAtom(edata_atom_idx);
            const val = self.getAddr(data_i, .b);
            self.syms.items[edata_atom.sym_index.?].value = val;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[edata_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), self.base.options.target.cpu.arch.endian());
            } else {
                mem.writeInt(u64, got_table[edata_atom.got_index.? * 8 ..][0..8], val, self.base.options.target.cpu.arch.endian());
            }
        }
        // end symbol (same as edata because native backends don't do .bss yet)
        if (self.etext_edata_end_atom_indices[2]) |end_atom_idx| {
            const end_atom = self.getAtom(end_atom_idx);
            const val = self.getAddr(data_i, .b);
            self.syms.items[end_atom.sym_index.?].value = val;
            if (!self.sixtyfour_bit) {
                mem.writeInt(u32, got_table[end_atom.got_index.? * 4 ..][0..4], @as(u32, @intCast(val)), self.base.options.target.cpu.arch.endian());
            } else {
                log.debug("write end (got_table[0x{x}] = 0x{x})", .{ end_atom.got_index.? * 8, val });
                mem.writeInt(u64, got_table[end_atom.got_index.? * 8 ..][0..8], val, self.base.options.target.cpu.arch.endian());
            }
        }
    }
    var sym_buf = std.ArrayList(u8).init(self.base.allocator);
    try self.writeSyms(&sym_buf);
    const syms = try sym_buf.toOwnedSlice();
    defer self.base.allocator.free(syms);
    assert(2 + self.atomCount() - self.externCount() == iovecs_i); // we didn't write all the decls
    iovecs[iovecs_i] = .{ .iov_base = syms.ptr, .iov_len = syms.len };
    iovecs_i += 1;
    iovecs[iovecs_i] = .{ .iov_base = linecountinfo.items.ptr, .iov_len = linecountinfo.items.len };
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
        mem.writeIntSliceBig(u64, hdr_buf[32..40], self.entry_val.?);
    }
    // perform the relocs
    {
        var it = self.relocs.iterator();
        while (it.next()) |kv| {
            const source_atom_index = kv.key_ptr.*;
            const source_atom = self.getAtom(source_atom_index);
            const source_atom_symbol = self.syms.items[source_atom.sym_index.?];
            const code = source_atom.code.getCode(self);
            const endian = self.base.options.target.cpu.arch.endian();
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
fn addDeclExports(
    self: *Plan9,
    mod: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    const metadata = self.decls.getPtr(decl_index).?;
    const atom = self.getAtom(metadata.index);

    for (exports) |exp| {
        const exp_name = mod.intern_pool.stringToSlice(exp.opts.name);
        // plan9 does not support custom sections
        if (exp.opts.section.unwrap()) |section_name| {
            if (!mod.intern_pool.stringEqlSlice(section_name, ".text") and !mod.intern_pool.stringEqlSlice(section_name, ".data")) {
                try mod.failed_exports.put(mod.gpa, exp, try Module.ErrorMsg.create(
                    self.base.allocator,
                    mod.declPtr(decl_index).srcLoc(mod),
                    "plan9 does not support extra sections",
                    .{},
                ));
                break;
            }
        }
        const sym = .{
            .value = atom.offset.?,
            .type = atom.type.toGlobal(),
            .name = try self.base.allocator.dupe(u8, exp_name),
        };

        if (metadata.getExport(self, exp_name)) |i| {
            self.syms.items[i] = sym;
        } else {
            try self.syms.append(self.base.allocator, sym);
            try metadata.exports.append(self.base.allocator, self.syms.items.len - 1);
        }
    }
}

pub fn freeDecl(self: *Plan9, decl_index: Module.Decl.Index) void {
    // TODO audit the lifetimes of decls table entries. It's possible to get
    // freeDecl without any updateDecl in between.
    // However that is planned to change, see the TODO comment in Module.zig
    // in the deleteUnusedDecl function.
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const is_fn = decl.val.isFuncBody(mod);
    if (is_fn) {
        var symidx_and_submap = self.fn_decl_table.get(decl.getFileScope(mod)).?;
        var submap = symidx_and_submap.functions;
        if (submap.fetchSwapRemove(decl_index)) |removed_entry| {
            self.base.allocator.free(removed_entry.value.code);
            self.base.allocator.free(removed_entry.value.lineinfo);
        }
        if (submap.count() == 0) {
            self.syms.items[symidx_and_submap.sym_index] = aout.Sym.undefined_symbol;
            self.syms_index_free_list.append(self.base.allocator, symidx_and_submap.sym_index) catch {};
            submap.deinit(self.base.allocator);
        }
    } else {
        if (self.data_decl_table.fetchSwapRemove(decl_index)) |removed_entry| {
            self.base.allocator.free(removed_entry.value);
        }
    }
    if (self.decls.fetchRemove(decl_index)) |const_kv| {
        var kv = const_kv;
        const atom = self.getAtom(kv.value.index);
        if (atom.got_index) |i| {
            // TODO: if this catch {} is triggered, an assertion in flushModule will be triggered, because got_index_free_list will have the wrong length
            self.got_index_free_list.append(self.base.allocator, i) catch {};
        }
        if (atom.sym_index) |i| {
            self.syms_index_free_list.append(self.base.allocator, i) catch {};
            self.syms.items[i] = aout.Sym.undefined_symbol;
        }
        kv.value.exports.deinit(self.base.allocator);
    }
    self.freeUnnamedConsts(decl_index);
    {
        const atom_index = self.decls.get(decl_index).?.index;
        const relocs = self.relocs.getPtr(atom_index) orelse return;
        relocs.clearAndFree(self.base.allocator);
        assert(self.relocs.remove(atom_index));
    }
}
fn freeUnnamedConsts(self: *Plan9, decl_index: Module.Decl.Index) void {
    const unnamed_consts = self.unnamed_const_atoms.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |atom_idx| {
        const atom = self.getAtom(atom_idx);
        self.base.allocator.free(self.syms.items[atom.sym_index.?].name);
        self.syms.items[atom.sym_index.?] = aout.Sym.undefined_symbol;
        self.syms_index_free_list.append(self.base.allocator, atom.sym_index.?) catch {};
    }
    unnamed_consts.clearAndFree(self.base.allocator);
}

fn createAtom(self: *Plan9) !Atom.Index {
    const gpa = self.base.allocator;
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

pub fn seeDecl(self: *Plan9, decl_index: Module.Decl.Index) !Atom.Index {
    const gop = try self.decls.getOrPut(self.base.allocator, decl_index);
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
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    const name = mod.intern_pool.stringToSlice(decl.name);
    if (decl.isExtern(mod)) {
        // this is a "phantom atom" - it is never actually written to disk, just convenient for us to store stuff about externs
        if (std.mem.eql(u8, name, "etext")) {
            self.etext_edata_end_atom_indices[0] = atom_idx;
        } else if (std.mem.eql(u8, name, "edata")) {
            self.etext_edata_end_atom_indices[1] = atom_idx;
        } else if (std.mem.eql(u8, name, "end")) {
            self.etext_edata_end_atom_indices[2] = atom_idx;
        }
        try self.updateFinish(decl_index);
        log.debug("seeDecl(extern) for {s} (got_addr=0x{x})", .{ name, self.getAtom(atom_idx).getOffsetTableAddress(self) });
    } else log.debug("seeDecl for {s}", .{name});
    return atom_idx;
}

pub fn updateDeclExports(
    self: *Plan9,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    _ = try self.seeDecl(decl_index);
    // we do all the things in flush
    _ = module;
    _ = exports;
}

pub fn getOrCreateAtomForLazySymbol(self: *Plan9, sym: File.LazySymbol) !Atom.Index {
    const gop = try self.lazy_syms.getOrPut(self.base.allocator, sym.getDecl(self.base.options.module.?));
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();

    if (!gop.found_existing) gop.value_ptr.* = .{};

    const metadata: struct { atom: *Atom.Index, state: *LazySymbolMetadata.State } = switch (sym.kind) {
        .code => .{ .atom = &gop.value_ptr.text_atom, .state = &gop.value_ptr.text_state },
        .const_data => .{ .atom = &gop.value_ptr.rodata_atom, .state = &gop.value_ptr.rodata_state },
    };
    switch (metadata.state.*) {
        .unused => metadata.atom.* = try self.createAtom(),
        .pending_flush => return metadata.atom.*,
        .flushed => {},
    }
    metadata.state.* = .pending_flush;
    const atom = metadata.atom.*;
    _ = try self.getAtomPtr(atom).getOrCreateSymbolTableEntry(self);
    _ = self.getAtomPtr(atom).getOrCreateOffsetTableEntry(self);
    // anyerror needs to be deferred until flushModule
    if (sym.getDecl(self.base.options.module.?) != .none) {
        try self.updateLazySymbolAtom(sym, atom);
    }
    return atom;
}

fn updateLazySymbolAtom(self: *Plan9, sym: File.LazySymbol, atom_index: Atom.Index) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;

    var required_alignment: InternPool.Alignment = .none;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    // create the symbol for the name
    const name = try std.fmt.allocPrint(gpa, "__lazy_{s}_{}", .{
        @tagName(sym.kind),
        sym.ty.fmt(mod),
    });

    const symbol: aout.Sym = .{
        .value = undefined,
        .type = if (sym.kind == .code) .t else .d,
        .name = name,
    };
    self.syms.items[self.getAtomPtr(atom_index).sym_index.?] = symbol;

    // generate the code
    const src = if (sym.ty.getOwnerDeclOrNull(mod)) |owner_decl|
        mod.declPtr(owner_decl).srcLoc(mod)
    else
        Module.SrcLoc{
            .file_scope = undefined,
            .parent_decl_node = undefined,
            .lazy = .unneeded,
        };
    const res = try codegen.generateLazySymbol(
        &self.base,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .parent_atom_index = @as(Atom.Index, @intCast(atom_index)) },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };
    // duped_code is freed when the atom is freed
    var duped_code = try self.base.allocator.dupe(u8, code);
    errdefer self.base.allocator.free(duped_code);
    self.getAtomPtr(atom_index).code = .{
        .code_ptr = duped_code.ptr,
        .other = .{ .code_len = duped_code.len },
    };
}

pub fn deinit(self: *Plan9) void {
    const gpa = self.base.allocator;
    {
        var it = self.relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(self.base.allocator);
        }
        self.relocs.deinit(self.base.allocator);
    }
    // free the unnamed consts
    var it_unc = self.unnamed_const_atoms.iterator();
    while (it_unc.next()) |kv| {
        self.freeUnnamedConsts(kv.key_ptr.*);
    }
    self.unnamed_const_atoms.deinit(gpa);
    var it_lzc = self.lazy_syms.iterator();
    while (it_lzc.next()) |kv| {
        if (kv.value_ptr.text_state != .unused)
            gpa.free(self.syms.items[self.getAtom(kv.value_ptr.text_atom).sym_index.?].name);
        if (kv.value_ptr.rodata_state != .unused)
            gpa.free(self.syms.items[self.getAtom(kv.value_ptr.rodata_atom).sym_index.?].name);
    }
    self.lazy_syms.deinit(gpa);
    var itf_files = self.fn_decl_table.iterator();
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
    self.fn_decl_table.deinit(gpa);
    var itd = self.data_decl_table.iterator();
    while (itd.next()) |entry| {
        gpa.free(entry.value_ptr.*);
    }
    var it_anon = self.anon_decls.iterator();
    while (it_anon.next()) |entry| {
        const sym_index = self.getAtom(entry.value_ptr.*).sym_index.?;
        gpa.free(self.syms.items[sym_index].name);
    }
    self.data_decl_table.deinit(gpa);
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
        var it = self.decls.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(gpa);
        }
        self.decls.deinit(gpa);
    }
}

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*Plan9 {
    if (options.use_llvm)
        return error.LLVMBackendDoesNotSupportPlan9;
    assert(options.target.ofmt == .plan9);

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();
    self.base.file = file;

    self.bases = defaultBaseAddrs(options.target.cpu.arch);

    try self.syms.appendSlice(self.base.allocator, &.{
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
        try w.writeIntBig(u32, @as(u32, @intCast(sym.value)));
    } else {
        try w.writeIntBig(u64, sym.value);
    }
    try w.writeByte(@intFromEnum(sym.type));
    try w.writeAll(sym.name);
    try w.writeByte(0);
}

pub fn writeSyms(self: *Plan9, buf: *std.ArrayList(u8)) !void {
    const mod = self.base.options.module.?;
    const ip = &mod.intern_pool;
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
        var it = self.data_decl_table.iterator();
        while (it.next()) |entry| {
            const decl_index = entry.key_ptr.*;
            const decl_metadata = self.decls.get(decl_index).?;
            const atom = self.getAtom(decl_metadata.index);
            const sym = self.syms.items[atom.sym_index.?];
            try self.writeSym(writer, sym);
            if (self.base.options.module.?.decl_exports.get(decl_index)) |exports| {
                for (exports.items) |e| if (decl_metadata.getExport(self, ip.stringToSlice(e.opts.name))) |exp_i| {
                    try self.writeSym(writer, self.syms.items[exp_i]);
                };
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
    // unnamed consts
    {
        var it = self.unnamed_const_atoms.iterator();
        while (it.next()) |kv| {
            const consts = kv.value_ptr;
            for (consts.items) |atom_index| {
                const sym = self.syms.items[self.getAtom(atom_index).sym_index.?];
                try self.writeSym(writer, sym);
            }
        }
    }
    // text symbols are the hardest:
    // the file of a text symbol is the .z symbol before it
    // so we have to write everything in the right order
    {
        var it_file = self.fn_decl_table.iterator();
        while (it_file.next()) |fentry| {
            var symidx_and_submap = fentry.value_ptr;
            // write the z symbols
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index - 1]);
            try self.writeSym(writer, self.syms.items[symidx_and_submap.sym_index]);

            // write all the decls come from the file of the z symbol
            var submap_it = symidx_and_submap.functions.iterator();
            while (submap_it.next()) |entry| {
                const decl_index = entry.key_ptr.*;
                const decl_metadata = self.decls.get(decl_index).?;
                const atom = self.getAtom(decl_metadata.index);
                const sym = self.syms.items[atom.sym_index.?];
                try self.writeSym(writer, sym);
                if (self.base.options.module.?.decl_exports.get(decl_index)) |exports| {
                    for (exports.items) |e| if (decl_metadata.getExport(self, ip.stringToSlice(e.opts.name))) |exp_i| {
                        const s = self.syms.items[exp_i];
                        if (mem.eql(u8, s.name, "_start"))
                            self.entry_val = s.value;
                        try self.writeSym(writer, s);
                    };
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
pub fn updateDeclLineNumber(self: *Plan9, mod: *Module, decl_index: Module.Decl.Index) !void {
    _ = self;
    _ = mod;
    _ = decl_index;
}

pub fn getDeclVAddr(
    self: *Plan9,
    decl_index: Module.Decl.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    log.debug("getDeclVAddr for {s}", .{mod.intern_pool.stringToSlice(decl.name)});
    if (decl.isExtern(mod)) {
        const extern_name = mod.intern_pool.stringToSlice(decl.name);
        if (std.mem.eql(u8, extern_name, "etext")) {
            try self.addReloc(reloc_info.parent_atom_index, .{
                .target = undefined,
                .offset = reloc_info.offset,
                .addend = reloc_info.addend,
                .type = .special_etext,
            });
        } else if (std.mem.eql(u8, extern_name, "edata")) {
            try self.addReloc(reloc_info.parent_atom_index, .{
                .target = undefined,
                .offset = reloc_info.offset,
                .addend = reloc_info.addend,
                .type = .special_edata,
            });
        } else if (std.mem.eql(u8, extern_name, "end")) {
            try self.addReloc(reloc_info.parent_atom_index, .{
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
    const atom_index = try self.seeDecl(decl_index);
    // the parent_atom_index in this case is just the decl_index of the parent
    try self.addReloc(reloc_info.parent_atom_index, .{
        .target = atom_index,
        .offset = reloc_info.offset,
        .addend = reloc_info.addend,
    });
    return undefined;
}

pub fn lowerAnonDecl(self: *Plan9, decl_val: InternPool.Index, src_loc: Module.SrcLoc) !codegen.Result {
    // This is basically the same as lowerUnnamedConst.
    // example:
    // const ty = mod.intern_pool.typeOf(decl_val).toType();
    // const val = decl_val.toValue();
    // The symbol name can be something like `__anon_{d}` with `@intFromEnum(decl_val)`.
    // It doesn't have an owner decl because it's just an unnamed constant that might
    // be used by more than one function, however, its address is being used so we need
    // to put it in some location.
    // ...
    const gpa = self.base.allocator;
    var gop = try self.anon_decls.getOrPut(gpa, decl_val);
    const mod = self.base.options.module.?;
    if (!gop.found_existing) {
        const ty = mod.intern_pool.typeOf(decl_val).toType();
        const val = decl_val.toValue();
        const tv = TypedValue{ .ty = ty, .val = val };
        const name = try std.fmt.allocPrint(gpa, "__anon_{d}", .{@intFromEnum(decl_val)});

        const index = try self.createAtom();
        const got_index = self.allocateGotIndex();
        gop.value_ptr.* = index;
        // we need to free name latex
        var code_buffer = std.ArrayList(u8).init(gpa);
        const res = try codegen.generateSymbol(&self.base, src_loc, tv, &code_buffer, .{ .none = {} }, .{ .parent_atom_index = index });
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
    }
    return .ok;
}

pub fn getAnonDeclVAddr(self: *Plan9, decl_val: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    const atom_index = self.anon_decls.get(decl_val).?;
    try self.addReloc(reloc_info.parent_atom_index, .{
        .target = atom_index,
        .offset = reloc_info.offset,
        .addend = reloc_info.addend,
    });
    return undefined;
}

pub fn addReloc(self: *Plan9, parent_index: Atom.Index, reloc: Reloc) !void {
    const gop = try self.relocs.getOrPut(self.base.allocator, parent_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(self.base.allocator, reloc);
}

pub fn getAtom(self: *const Plan9, index: Atom.Index) Atom {
    return self.atoms.items[index];
}

fn getAtomPtr(self: *Plan9, index: Atom.Index) *Atom {
    return &self.atoms.items[index];
}
