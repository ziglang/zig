const Coff = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const coff = std.coff;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;

const Allocator = std.mem.Allocator;

const codegen = @import("../codegen.zig");
const link = @import("../link.zig");
const lld = @import("Coff/lld.zig");
const trace = @import("../tracy.zig").trace;

const Air = @import("../Air.zig");
pub const Atom = @import("Coff/Atom.zig");
const Compilation = @import("../Compilation.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Module = @import("../Module.zig");
const StringTable = @import("strtab.zig").StringTable;
const TypedValue = @import("../TypedValue.zig");

pub const base_tag: link.File.Tag = .coff;

const msdos_stub = @embedFile("msdos-stub.bin");

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

base: link.File,
error_flags: link.File.ErrorFlags = .{},

ptr_width: PtrWidth,

sections: std.MultiArrayList(Section) = .{},

text_section_index: ?u16 = null,
got_section_index: ?u16 = null,

locals: std.ArrayListUnmanaged(coff.Symbol) = .{},
globals: std.StringArrayHashMapUnmanaged(SymbolWithLoc) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},

strtab: StringTable(.strtab) = .{},

got_entries: std.AutoArrayHashMapUnmanaged(SymbolWithLoc, u32) = .{},
got_entries_free_list: std.ArrayListUnmanaged(u32) = .{},

/// Virtual address of the entry point procedure relative to image base.
entry_addr: ?u64 = null,

/// Table of Decls that are currently alive.
/// We store them here so that we can properly dispose of any allocated
/// memory within the atom in the incremental linker.
/// TODO consolidate this.
decls: std.AutoHashMapUnmanaged(Module.Decl.Index, ?u16) = .{},

/// List of atoms that are either synthetic or map directly to the Zig source program.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of atoms indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *Atom) = .{},

const page_size: u16 = 0x1000;

const Section = struct {
    header: coff.SectionHeader,

    last_atom: ?*Atom = null,

    /// A list of atoms that have surplus capacity. This list can have false
    /// positives, as functions grow and shrink over time, only sometimes being added
    /// or removed from the freelist.
    ///
    /// An atom has surplus capacity when its overcapacity value is greater than
    /// padToIdeal(minimum_atom_size). That is, when it has so
    /// much extra capacity, that we could fit a small new symbol in it, itself with
    /// ideal_capacity or more.
    ///
    /// Ideal capacity is defined by size + (size / ideal_factor).
    ///
    /// Overcapacity is measured by actual_capacity - ideal_capacity. Note that
    /// overcapacity can be negative. A simple way to have negative overcapacity is to
    /// allocate a fresh atom, which will have ideal capacity, and then grow it
    /// by 1 byte. It will then have -1 overcapacity.
    free_list: std.ArrayListUnmanaged(*Atom) = .{},
};

pub const PtrWidth = enum { p32, p64 };
pub const SrcFn = void;

pub const Export = struct {
    sym_index: ?u32 = null,
};

pub const SymbolWithLoc = struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // null means it's a synthetic global or Zig source.
    file: ?u32 = null,
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
pub const min_text_capacity = padToIdeal(minimum_text_block_size);

/// We commit 0x1000 = 4096 bytes of space to the headers.
/// This should be plenty for any potential future extensions.
const default_headerpad_size: u32 = 0x1000;

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*Coff {
    assert(options.target.ofmt == .coff);

    if (build_options.have_llvm and options.use_llvm) {
        return createEmpty(allocator, options);
    }

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    self.base.file = file;

    // Index 0 is always a null symbol.
    try self.locals.append(allocator, .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = @intToEnum(coff.SectionNumber, 0),
        .@"type" = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    });
    try self.strtab.buffer.append(allocator, 0);

    try self.populateMissingMetadata();

    return self;
}

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Coff {
    const ptr_width: PtrWidth = switch (options.target.cpu.arch.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedCOFFArchitecture,
    };
    const self = try gpa.create(Coff);
    errdefer gpa.destroy(self);
    self.* = .{
        .base = .{
            .tag = .coff,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .ptr_width = ptr_width,
    };

    const use_llvm = build_options.have_llvm and options.use_llvm;
    const use_stage1 = build_options.have_stage1 and options.use_stage1;
    if (use_llvm and !use_stage1) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }
    return self;
}

pub fn deinit(self: *Coff) void {
    const gpa = self.base.allocator;

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(gpa);
    }

    for (self.sections.items(.free_list)) |*free_list| {
        free_list.deinit(gpa);
    }
    self.sections.deinit(gpa);

    for (self.managed_atoms.items) |atom| {
        gpa.destroy(atom);
    }
    self.managed_atoms.deinit(gpa);

    self.locals.deinit(gpa);
    self.globals.deinit(gpa);
    self.locals_free_list.deinit(gpa);
    self.strtab.deinit(gpa);
    self.got_entries.deinit(gpa);
    self.got_entries_free_list.deinit(gpa);
    self.decls.deinit(gpa);
    self.atom_by_index_table.deinit(gpa);
}

fn populateMissingMetadata(self: *Coff) !void {
    _ = self;
    @panic("TODO populateMissingMetadata");
}

pub fn allocateDeclIndexes(self: *Coff, decl_index: Module.Decl.Index) !void {
    if (self.llvm_object) |_| return;
    const decl = self.base.options.module.?.declPtr(decl_index);
    if (decl.link.coff.sym_index != 0) return;
    decl.link.coff.sym_index = try self.allocateSymbol();
    const gpa = self.base.allocator;
    try self.atom_by_index_table.putNoClobber(gpa, decl.link.coff.sym_index, &decl.link.coff);
    try self.decls.putNoClobber(gpa, decl_index, null);
}

fn allocateAtom(self: *Coff, atom: *Atom, new_atom_size: u64, alignment: u64, sect_id: u16) !u64 {
    const tracy = trace(@src());
    defer tracy.end();

    const header = &self.sections.items(.header)[sect_id];
    const free_list = &self.sections.items(.free_list)[sect_id];
    const maybe_last_atom = &self.sections.items(.last_atom)[sect_id];
    const new_atom_ideal_capacity = if (header.isCode()) padToIdeal(new_atom_size) else new_atom_size;

    // We use these to indicate our intention to update metadata, placing the new atom,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var atom_placement: ?*Atom = null;
    var free_list_removal: ?usize = null;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    var vaddr = blk: {
        var i: usize = 0;
        while (i < free_list.items.len) {
            const big_atom = free_list.items[i];
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const sym = big_atom.getSymbol(self);
            const capacity = big_atom.capacity(self);
            const ideal_capacity = if (header.isCode()) padToIdeal(capacity) else capacity;
            const ideal_capacity_end_vaddr = math.add(u64, sym.n_value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = sym.n_value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = mem.alignBackwardGeneric(u64, new_start_vaddr_unaligned, alignment);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the atom that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(self)) {
                    _ = free_list.swapRemove(i);
                } else {
                    i += 1;
                }
                continue;
            }
            // At this point we know that we will place the new atom here. But the
            // remaining question is whether there is still yet enough capacity left
            // over for there to still be a free list node.
            const remaining_capacity = new_start_vaddr - ideal_capacity_end_vaddr;
            const keep_free_list_node = remaining_capacity >= min_text_capacity;

            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = big_atom;
            if (!keep_free_list_node) {
                free_list_removal = i;
            }
            break :blk new_start_vaddr;
        } else if (maybe_last_atom.*) |last| {
            const last_symbol = last.getSymbol(self);
            const ideal_capacity = if (header.isCode()) padToIdeal(last.size) else last.size;
            const ideal_capacity_end_vaddr = last_symbol.n_value + ideal_capacity;
            const new_start_vaddr = mem.alignForwardGeneric(u64, ideal_capacity_end_vaddr, alignment);
            atom_placement = last;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForwardGeneric(u64, header.addr, alignment);
        }
    };

    const expand_section = atom_placement == null or atom_placement.?.next == null;
    if (expand_section) {
        @panic("TODO expand section in allocateAtom");
    }

    if (header.getAlignment() < alignment) {
        header.setAlignment(alignment);
    }
    atom.size = new_atom_size;
    atom.alignment = alignment;

    if (atom.prev) |prev| {
        prev.next = atom.next;
    }
    if (atom.next) |next| {
        next.prev = atom.prev;
    }

    if (atom_placement) |big_atom| {
        atom.prev = big_atom;
        atom.next = big_atom.next;
        big_atom.next = atom;
    } else {
        atom.prev = null;
        atom.next = null;
    }
    if (free_list_removal) |i| {
        _ = free_list.swapRemove(i);
    }

    return vaddr;
}

fn allocateSymbol(self: *Coff) !u32 {
    const gpa = self.base.allocator;
    try self.locals.ensureUnusedCapacity(gpa, 1);

    const index = blk: {
        if (self.locals_free_list.popOrNull()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.locals.items.len});
            const index = @intCast(u32, self.locals.items.len);
            _ = self.locals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.locals.items[index] = .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = @intToEnum(coff.SectionNumber, 0),
        .@"type" = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    };

    return index;
}

pub fn allocateGotEntry(self: *Coff, target: SymbolWithLoc) !u32 {
    const gpa = self.base.allocator;
    try self.got_entries.ensureUnusedCapacity(gpa, 1);
    if (self.got_entries_free_list.popOrNull()) |index| {
        log.debug("  (reusing GOT entry index {d})", .{index});
        if (self.got_entries.getIndex(target)) |existing| {
            assert(existing == index);
        }
        self.got_entries.keys()[index] = target;
        return index;
    } else {
        log.debug("  (allocating GOT entry at index {d})", .{self.got_entries.keys().len});
        const index = @intCast(u32, self.got_entries.keys().len);
        try self.got_entries.putAssumeCapacityNoClobber(target, 0);
        return index;
    }
}

fn growAtom(self: *Coff, atom: *Atom, new_atom_size: u64, alignment: u64, sect_id: u16) !u64 {
    const sym = atom.getSymbol(self);
    const align_ok = mem.alignBackwardGeneric(u64, sym.value, alignment) == sym.value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self);
    if (!need_realloc) return sym.value;
    return self.allocateAtom(atom, new_atom_size, alignment, sect_id);
}

fn shrinkAtom(self: *Coff, atom: *Atom, new_block_size: u64, sect_id: u16) void {
    _ = self;
    _ = atom;
    _ = new_block_size;
    _ = sect_id;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn freeAtom(self: *Coff, atom: *Atom, sect_id: u16) void {
    log.debug("freeAtom {*}", .{atom});

    const free_list = &self.sections.items(.free_list)[sect_id];
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i] == atom) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (free_list.items[i] == atom.prev) {
                already_have_free_list_node = true;
            }
            i += 1;
        }
    }

    const maybe_last_atom = &self.sections.items(.last_atom)[sect_id];
    if (maybe_last_atom.*) |last_atom| {
        if (last_atom == atom) {
            if (atom.prev) |prev| {
                // TODO shrink the section size here
                maybe_last_atom.* = prev;
            } else {
                maybe_last_atom.* = null;
            }
        }
    }

    if (atom.prev) |prev| {
        prev.next = atom.next;

        if (!already_have_free_list_node and prev.freeListEligible(self)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(self.base.allocator, prev) catch {};
        }
    } else {
        atom.prev = null;
    }

    if (atom.next) |next| {
        next.prev = atom.prev;
    } else {
        atom.next = null;
    }
}

pub fn updateFunc(self: *Coff, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| {
            return llvm_object.updateFunc(module, func, air, liveness);
        }
    }
    const tracy = trace(@src());
    defer tracy.end();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const decl_index = func.owner_decl;
    const decl = module.declPtr(decl_index);
    const res = try codegen.generateFunction(
        &self.base,
        decl.srcLoc(),
        func,
        air,
        liveness,
        &code_buffer,
        .none,
    );
    const code = switch (res) {
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };

    const sym = try self.updateDeclCode(decl_index, code);
    log.debug("updated decl code has sym {}", .{sym});

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    return self.updateDeclExports(module, decl_index, decl_exports);
}

pub fn lowerUnnamedConst(self: *Coff, tv: TypedValue, decl_index: Module.Decl.Index) !u32 {
    _ = self;
    _ = tv;
    _ = decl_index;
    @panic("TODO lowerUnnamedConst");
}

pub fn updateDecl(self: *Coff, module: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(module, decl_index);
    }
    const tracy = trace(@src());
    defer tracy.end();

    const decl = module.declPtr(decl_index);

    if (decl.val.tag() == .extern_fn) {
        return; // TODO Should we do more when front-end analyzed extern decl?
    }
    if (decl.val.castTag(.variable)) |payload| {
        const variable = payload.data;
        if (variable.is_extern) {
            return; // TODO Should we do more when front-end analyzed extern decl?
        }
    }

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const decl_val = if (decl.val.castTag(.variable)) |payload| payload.data.init else decl.val;
    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, .none, .{
        .parent_atom_index = 0,
    });
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };

    const sym = try self.updateDeclCode(decl_index, code);
    log.debug("updated decl code for {}", .{sym});

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    return self.updateDeclExports(module, decl_index, decl_exports);
}

fn updateDeclCode(self: *Coff, decl_index: Module.Decl.Index, code: []const u8) !*coff.Symbol {
    _ = self;
    _ = decl_index;
    _ = code;
    @panic("TODO updateDeclCode");
}

pub fn freeDecl(self: *Coff, decl_index: Module.Decl.Index) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    }

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    log.debug("freeDecl {*}", .{decl});

    const kv = self.decls.fetchRemove(decl_index);
    if (kv.?.value) |index| {
        self.freeAtom(&decl.link.coff, index);
    }

    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    const gpa = self.base.allocator;
    const sym_index = decl.link.coff.sym_index;
    if (sym_index != 0) {
        self.locals_free_list.append(gpa, sym_index) catch {};

        // Try freeing GOT atom if this decl had one
        const got_target = SymbolWithLoc{ .sym_index = sym_index, .file = null };
        if (self.got_entries.getIndex(got_target)) |got_index| {
            self.got_entries_free_list.append(gpa, @intCast(u32, got_index)) catch {};
            self.got_entries.values()[got_index] = 0;
            log.debug("  adding GOT index {d} to free list (target local@{d})", .{ got_index, sym_index });
        }

        self.locals.items[sym_index].section_number = @intToEnum(coff.SectionNumber, 0);
        _ = self.atom_by_index_table.remove(sym_index);
        decl.link.coff.sym_index = 0;
    }
}

pub fn updateDeclExports(
    self: *Coff,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    // Even in the case of LLVM, we need to notice certain exported symbols in order to
    // detect the default subsystem.
    for (exports) |exp| {
        const exported_decl = module.declPtr(exp.exported_decl);
        if (exported_decl.getFunction() == null) continue;
        const winapi_cc = switch (self.base.options.target.cpu.arch) {
            .i386 => std.builtin.CallingConvention.Stdcall,
            else => std.builtin.CallingConvention.C,
        };
        const decl_cc = exported_decl.ty.fnCallingConvention();
        if (decl_cc == .C and mem.eql(u8, exp.options.name, "main") and
            self.base.options.link_libc)
        {
            module.stage1_flags.have_c_main = true;
        } else if (decl_cc == winapi_cc and self.base.options.target.os.tag == .windows) {
            if (mem.eql(u8, exp.options.name, "WinMain")) {
                module.stage1_flags.have_winmain = true;
            } else if (mem.eql(u8, exp.options.name, "wWinMain")) {
                module.stage1_flags.have_wwinmain = true;
            } else if (mem.eql(u8, exp.options.name, "WinMainCRTStartup")) {
                module.stage1_flags.have_winmain_crt_startup = true;
            } else if (mem.eql(u8, exp.options.name, "wWinMainCRTStartup")) {
                module.stage1_flags.have_wwinmain_crt_startup = true;
            } else if (mem.eql(u8, exp.options.name, "DllMainCRTStartup")) {
                module.stage1_flags.have_dllmain_crt_startup = true;
            }
        }
    }

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDeclExports(module, decl_index, exports);
    }

    @panic("TODO updateDeclExports");
}

pub fn flush(self: *Coff, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (self.base.options.emit == null) {
        if (build_options.have_llvm) {
            if (self.llvm_object) |llvm_object| {
                return try llvm_object.flushModule(comp, prog_node);
            }
        }
        return;
    }
    const use_lld = build_options.have_llvm and self.base.options.use_lld;
    if (use_lld) {
        return lld.linkWithLLD(self, comp, prog_node);
    }
    switch (self.base.options.output_mode) {
        .Exe, .Obj => return self.flushModule(comp, prog_node),
        .Lib => return error.TODOImplementWritingLibFiles,
    }
}

pub fn flushModule(self: *Coff, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| {
            return try llvm_object.flushModule(comp, prog_node);
        }
    }

    var sub_prog_node = prog_node.start("COFF Flush", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        self.error_flags.no_entry_point_found = false;
    }
}

pub fn getDeclVAddr(
    self: *Coff,
    decl_index: Module.Decl.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    _ = self;
    _ = decl_index;
    _ = reloc_info;
    @panic("TODO getDeclVAddr");
}

pub fn updateDeclLineNumber(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    _ = self;
    _ = module;
    _ = decl;
    log.debug("TODO implement updateDeclLineNumber", .{});
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    // TODO https://github.com/ziglang/zig/issues/1284
    return math.add(@TypeOf(actual_size), actual_size, actual_size / ideal_factor) catch
        math.maxInt(@TypeOf(actual_size));
}

/// Returns pointer-to-symbol described by `sym_with_loc` descriptor.
pub fn getSymbolPtr(self: *Coff, sym_loc: SymbolWithLoc) *coff.Symbol {
    assert(sym_loc.file == null); // TODO linking object files
    return &self.locals.items[sym_loc.sym_index];
}

/// Returns symbol described by `sym_with_loc` descriptor.
pub fn getSymbol(self: *Coff, sym_loc: SymbolWithLoc) coff.Symbol {
    return self.getSymbolPtr(sym_loc).*;
}

/// Returns name of the symbol described by `sym_with_loc` descriptor.
pub fn getSymbolName(self: *Coff, sym_loc: SymbolWithLoc) []const u8 {
    assert(sym_loc.file == null); // TODO linking object files
    const sym = self.locals.items[sym_loc.sym_index];
    const offset = sym.getNameOffset() orelse return sym.getName().?;
    return self.strtab.get(offset).?;
}

/// Returns atom if there is an atom referenced by the symbol described by `sym_with_loc` descriptor.
/// Returns null on failure.
pub fn getAtomForSymbol(self: *Coff, sym_loc: SymbolWithLoc) ?*Atom {
    assert(sym_loc.file == null); // TODO linking with object files
    return self.atom_by_index_table.get(sym_loc.sym_index);
}

/// Returns GOT atom that references `sym_with_loc` if one exists.
/// Returns null otherwise.
pub fn getGotAtomForSymbol(self: *Coff, sym_loc: SymbolWithLoc) ?*Atom {
    const got_index = self.got_entries.get(sym_loc) orelse return null;
    return self.atom_by_index_table.get(got_index);
}
