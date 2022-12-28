const Coff = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const coff = std.coff;
const fmt = std.fmt;
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
const Object = @import("Coff/Object.zig");
const Relocation = @import("Coff/Relocation.zig");
const StringTable = @import("strtab.zig").StringTable;
const TypedValue = @import("../TypedValue.zig");

pub const base_tag: link.File.Tag = .coff;

const msdos_stub = @embedFile("msdos-stub.bin");

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

base: link.File,
error_flags: link.File.ErrorFlags = .{},

ptr_width: PtrWidth,
page_size: u32,

objects: std.ArrayListUnmanaged(Object) = .{},

sections: std.MultiArrayList(Section) = .{},
data_directories: [coff.IMAGE_NUMBEROF_DIRECTORY_ENTRIES]coff.ImageDataDirectory,

text_section_index: ?u16 = null,
got_section_index: ?u16 = null,
rdata_section_index: ?u16 = null,
data_section_index: ?u16 = null,
reloc_section_index: ?u16 = null,
idata_section_index: ?u16 = null,

locals: std.ArrayListUnmanaged(coff.Symbol) = .{},
globals: std.ArrayListUnmanaged(SymbolWithLoc) = .{},
resolver: std.StringHashMapUnmanaged(u32) = .{},
unresolved: std.AutoArrayHashMapUnmanaged(u32, bool) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},
globals_free_list: std.ArrayListUnmanaged(u32) = .{},

strtab: StringTable(.strtab) = .{},
strtab_offset: ?u32 = null,

got_entries: std.ArrayListUnmanaged(Entry) = .{},
got_entries_free_list: std.ArrayListUnmanaged(u32) = .{},
got_entries_table: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

imports: std.ArrayListUnmanaged(Entry) = .{},
imports_free_list: std.ArrayListUnmanaged(u32) = .{},
imports_table: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

/// Virtual address of the entry point procedure relative to image base.
entry_addr: ?u32 = null,

/// Table of Decls that are currently alive.
/// We store them here so that we can properly dispose of any allocated
/// memory within the atom in the incremental linker.
/// TODO consolidate this.
decls: std.AutoHashMapUnmanaged(Module.Decl.Index, ?u16) = .{},

/// List of atoms that are either synthetic or map directly to the Zig source program.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of atoms indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *Atom) = .{},

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

/// A table of relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
relocs: RelocTable = .{},

/// A table of base relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
base_relocs: BaseRelocationTable = .{},

const Entry = struct {
    target: SymbolWithLoc,
    // Index into the synthetic symbol table (i.e., file == null).
    sym_index: u32,
};

const RelocTable = std.AutoHashMapUnmanaged(*Atom, std.ArrayListUnmanaged(Relocation));
const BaseRelocationTable = std.AutoHashMapUnmanaged(*Atom, std.ArrayListUnmanaged(u32));
const UnnamedConstTable = std.AutoHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(*Atom));

const default_file_alignment: u16 = 0x200;
const default_size_of_stack_reserve: u32 = 0x1000000;
const default_size_of_stack_commit: u32 = 0x1000;
const default_size_of_heap_reserve: u32 = 0x100000;
const default_size_of_heap_commit: u32 = 0x1000;

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

pub const PtrWidth = enum {
    p32,
    p64,

    fn abiSize(pw: PtrWidth) u4 {
        return switch (pw) {
            .p32 => 4,
            .p64 => 8,
        };
    }
};
pub const SrcFn = void;

pub const Export = struct {
    sym_index: ?u32 = null,
};

pub const SymbolWithLoc = struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // null means it's a synthetic global or Zig source.
    file: ?u32 = null,

    pub fn eql(this: SymbolWithLoc, other: SymbolWithLoc) bool {
        if (this.file == null and other.file == null) {
            return this.sym_index == other.sym_index;
        }
        if (this.file != null and other.file != null) {
            return this.sym_index == other.sym_index and this.file.? == other.file.?;
        }
        return false;
    }
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
pub const min_text_capacity = padToIdeal(minimum_text_block_size);

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

    try self.populateMissingMetadata();

    return self;
}

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Coff {
    const ptr_width: PtrWidth = switch (options.target.cpu.arch.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedCOFFArchitecture,
    };
    const page_size: u32 = switch (options.target.cpu.arch) {
        else => 0x1000,
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
        .page_size = page_size,
        .data_directories = comptime mem.zeroes([coff.IMAGE_NUMBEROF_DIRECTORY_ENTRIES]coff.ImageDataDirectory),
    };

    const use_llvm = build_options.have_llvm and options.use_llvm;
    if (use_llvm) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }
    return self;
}

pub fn deinit(self: *Coff) void {
    const gpa = self.base.allocator;

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(gpa);
    }

    for (self.objects.items) |*object| {
        object.deinit(gpa);
    }
    self.objects.deinit(gpa);

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

    {
        var it = self.resolver.keyIterator();
        while (it.next()) |key_ptr| {
            gpa.free(key_ptr.*);
        }
        self.resolver.deinit(gpa);
    }

    self.unresolved.deinit(gpa);
    self.locals_free_list.deinit(gpa);
    self.globals_free_list.deinit(gpa);
    self.strtab.deinit(gpa);
    self.got_entries.deinit(gpa);
    self.got_entries_free_list.deinit(gpa);
    self.got_entries_table.deinit(gpa);
    self.imports.deinit(gpa);
    self.imports_free_list.deinit(gpa);
    self.imports_table.deinit(gpa);
    self.decls.deinit(gpa);
    self.atom_by_index_table.deinit(gpa);

    {
        var it = self.unnamed_const_atoms.valueIterator();
        while (it.next()) |atoms| {
            atoms.deinit(gpa);
        }
        self.unnamed_const_atoms.deinit(gpa);
    }

    {
        var it = self.relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(gpa);
        }
        self.relocs.deinit(gpa);
    }

    {
        var it = self.base_relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(gpa);
        }
        self.base_relocs.deinit(gpa);
    }
}

fn populateMissingMetadata(self: *Coff) !void {
    assert(self.llvm_object == null);
    const gpa = self.base.allocator;

    try self.strtab.buffer.ensureUnusedCapacity(gpa, @sizeOf(u32));
    self.strtab.buffer.appendNTimesAssumeCapacity(0, @sizeOf(u32));

    // Index 0 is always a null symbol.
    try self.locals.append(gpa, .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    });

    if (self.text_section_index == null) {
        const file_size = @intCast(u32, self.base.options.program_code_size_hint);
        self.text_section_index = try self.allocateSection(".text", file_size, .{
            .CNT_CODE = 1,
            .MEM_EXECUTE = 1,
            .MEM_READ = 1,
        });
    }

    if (self.got_section_index == null) {
        const file_size = @intCast(u32, self.base.options.symbol_count_hint) * self.ptr_width.abiSize();
        self.got_section_index = try self.allocateSection(".got", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (self.rdata_section_index == null) {
        const file_size: u32 = self.page_size;
        self.rdata_section_index = try self.allocateSection(".rdata", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (self.data_section_index == null) {
        const file_size: u32 = self.page_size;
        self.data_section_index = try self.allocateSection(".data", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
            .MEM_WRITE = 1,
        });
    }

    if (self.idata_section_index == null) {
        const file_size = @intCast(u32, self.base.options.symbol_count_hint) * self.ptr_width.abiSize();
        self.idata_section_index = try self.allocateSection(".idata", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (self.reloc_section_index == null) {
        const file_size = @intCast(u32, self.base.options.symbol_count_hint) * @sizeOf(coff.BaseRelocation);
        self.reloc_section_index = try self.allocateSection(".reloc", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_DISCARDABLE = 1,
            .MEM_READ = 1,
        });
    }

    if (self.strtab_offset == null) {
        const file_size = @intCast(u32, self.strtab.len());
        self.strtab_offset = self.findFreeSpace(file_size, @alignOf(u32)); // 4bytes aligned seems like a good idea here
        log.debug("found strtab free space 0x{x} to 0x{x}", .{ self.strtab_offset.?, self.strtab_offset.? + file_size });
    }

    {
        // We need to find out what the max file offset is according to section headers.
        // Otherwise, we may end up with an COFF binary with file size not matching the final section's
        // offset + it's filesize.
        // TODO I don't like this here one bit
        var max_file_offset: u64 = 0;
        for (self.sections.items(.header)) |header| {
            if (header.pointer_to_raw_data + header.size_of_raw_data > max_file_offset) {
                max_file_offset = header.pointer_to_raw_data + header.size_of_raw_data;
            }
        }
        try self.base.file.?.pwriteAll(&[_]u8{0}, max_file_offset);
    }
}

fn allocateSection(self: *Coff, name: []const u8, size: u32, flags: coff.SectionHeaderFlags) !u16 {
    const index = @intCast(u16, self.sections.slice().len);
    const off = self.findFreeSpace(size, default_file_alignment);
    // Memory is always allocated in sequence
    // TODO: investigate if we can allocate .text last; this way it would never need to grow in memory!
    const vaddr = blk: {
        if (index == 0) break :blk self.page_size;
        const prev_header = self.sections.items(.header)[index - 1];
        break :blk mem.alignForwardGeneric(u32, prev_header.virtual_address + prev_header.virtual_size, self.page_size);
    };
    // We commit more memory than needed upfront so that we don't have to reallocate too soon.
    const memsz = mem.alignForwardGeneric(u32, size, self.page_size) * 100;
    log.debug("found {s} free space 0x{x} to 0x{x} (0x{x} - 0x{x})", .{
        name,
        off,
        off + size,
        vaddr,
        vaddr + size,
    });
    var header = coff.SectionHeader{
        .name = undefined,
        .virtual_size = memsz,
        .virtual_address = vaddr,
        .size_of_raw_data = size,
        .pointer_to_raw_data = off,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = flags,
    };
    try self.setSectionName(&header, name);
    try self.sections.append(self.base.allocator, .{ .header = header });
    return index;
}

fn growSectionVM(self: *Coff, sect_id: u32, needed_size: u32) !void {
    const header = &self.sections.items(.header)[sect_id];
    const increased_size = padToIdeal(needed_size);
    const old_aligned_end = header.virtual_address + mem.alignForwardGeneric(u32, header.virtual_size, self.page_size);
    const new_aligned_end = header.virtual_address + mem.alignForwardGeneric(u32, increased_size, self.page_size);
    const diff = new_aligned_end - old_aligned_end;
    log.debug("growing {s} in virtual memory by {x}", .{ self.getSectionName(header), diff });

    // TODO: enforce order by increasing VM addresses in self.sections container.
    // This is required by the loader anyhow as far as I can tell.
    for (self.sections.items(.header)[sect_id + 1 ..]) |*next_header, next_sect_id| {
        const maybe_last_atom = &self.sections.items(.last_atom)[sect_id + 1 + next_sect_id];
        next_header.virtual_address += diff;

        if (maybe_last_atom.*) |last_atom| {
            var atom = last_atom;
            while (true) {
                const sym = atom.getSymbolPtr(self);
                sym.value += diff;

                if (atom.prev) |prev| {
                    atom = prev;
                } else break;
            }
        }
    }

    header.virtual_size = increased_size;
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

fn allocateAtom(self: *Coff, atom: *Atom, new_atom_size: u32, alignment: u32) !u32 {
    const tracy = trace(@src());
    defer tracy.end();

    const sect_id = @enumToInt(atom.getSymbol(self).section_number) - 1;
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
            const ideal_capacity_end_vaddr = math.add(u32, sym.value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = sym.value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = mem.alignBackwardGeneric(u32, new_start_vaddr_unaligned, alignment);
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
            const ideal_capacity_end_vaddr = last_symbol.value + ideal_capacity;
            const new_start_vaddr = mem.alignForwardGeneric(u32, ideal_capacity_end_vaddr, alignment);
            atom_placement = last;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForwardGeneric(u32, header.virtual_address, alignment);
        }
    };

    const expand_section = atom_placement == null or atom_placement.?.next == null;
    if (expand_section) {
        const sect_capacity = self.allocatedSize(header.pointer_to_raw_data);
        const needed_size: u32 = (vaddr + new_atom_size) - header.virtual_address;
        if (needed_size > sect_capacity) {
            const new_offset = self.findFreeSpace(needed_size, default_file_alignment);
            const current_size = if (maybe_last_atom.*) |last_atom| blk: {
                const sym = last_atom.getSymbol(self);
                break :blk (sym.value + last_atom.size) - header.virtual_address;
            } else 0;
            log.debug("moving {s} from 0x{x} to 0x{x}", .{ self.getSectionName(header), header.pointer_to_raw_data, new_offset });
            const amt = try self.base.file.?.copyRangeAll(
                header.pointer_to_raw_data,
                self.base.file.?,
                new_offset,
                current_size,
            );
            if (amt != current_size) return error.InputOutput;
            header.pointer_to_raw_data = new_offset;
        }

        const sect_vm_capacity = self.allocatedVirtualSize(header.virtual_address);
        if (needed_size > sect_vm_capacity) {
            try self.growSectionVM(sect_id, needed_size);
            self.markRelocsDirtyByAddress(header.virtual_address + needed_size);
        }

        header.virtual_size = @max(header.virtual_size, needed_size);
        header.size_of_raw_data = needed_size;
        maybe_last_atom.* = atom;
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
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    };

    return index;
}

fn allocateGlobal(self: *Coff) !u32 {
    const gpa = self.base.allocator;
    try self.globals.ensureUnusedCapacity(gpa, 1);

    const index = blk: {
        if (self.globals_free_list.popOrNull()) |index| {
            log.debug("  (reusing global index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating global index {d})", .{self.globals.items.len});
            const index = @intCast(u32, self.globals.items.len);
            _ = self.globals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.globals.items[index] = .{
        .sym_index = 0,
        .file = null,
    };

    return index;
}

pub fn allocateGotEntry(self: *Coff, target: SymbolWithLoc) !u32 {
    const gpa = self.base.allocator;
    try self.got_entries.ensureUnusedCapacity(gpa, 1);

    const index: u32 = blk: {
        if (self.got_entries_free_list.popOrNull()) |index| {
            log.debug("  (reusing GOT entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating GOT entry at index {d})", .{self.got_entries.items.len});
            const index = @intCast(u32, self.got_entries.items.len);
            _ = self.got_entries.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.got_entries.items[index] = .{ .target = target, .sym_index = 0 };
    try self.got_entries_table.putNoClobber(gpa, target, index);

    return index;
}

pub fn allocateImportEntry(self: *Coff, target: SymbolWithLoc) !u32 {
    const gpa = self.base.allocator;
    try self.imports.ensureUnusedCapacity(gpa, 1);

    const index: u32 = blk: {
        if (self.imports_free_list.popOrNull()) |index| {
            log.debug("  (reusing import entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating import entry at index {d})", .{self.imports.items.len});
            const index = @intCast(u32, self.imports.items.len);
            _ = self.imports.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.imports.items[index] = .{ .target = target, .sym_index = 0 };
    try self.imports_table.putNoClobber(gpa, target, index);

    return index;
}

fn createGotAtom(self: *Coff, target: SymbolWithLoc) !*Atom {
    const gpa = self.base.allocator;
    const atom = try gpa.create(Atom);
    errdefer gpa.destroy(atom);
    atom.* = Atom.empty;
    atom.sym_index = try self.allocateSymbol();
    atom.size = @sizeOf(u64);
    atom.alignment = @alignOf(u64);

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, atom.sym_index, atom);

    const sym = atom.getSymbolPtr(self);
    sym.section_number = @intToEnum(coff.SectionNumber, self.got_section_index.? + 1);
    sym.value = try self.allocateAtom(atom, atom.size, atom.alignment);

    log.debug("allocated GOT atom at 0x{x}", .{sym.value});

    try atom.addRelocation(self, .{
        .type = .direct,
        .target = target,
        .offset = 0,
        .addend = 0,
        .pcrel = false,
        .length = 3,
    });

    const target_sym = self.getSymbol(target);
    switch (target_sym.section_number) {
        .UNDEFINED => @panic("TODO generate a binding for undefined GOT target"),
        .ABSOLUTE => {},
        .DEBUG => unreachable, // not possible
        else => try atom.addBaseRelocation(self, 0),
    }

    return atom;
}

fn createImportAtom(self: *Coff) !*Atom {
    const gpa = self.base.allocator;
    const atom = try gpa.create(Atom);
    errdefer gpa.destroy(atom);
    atom.* = Atom.empty;
    atom.sym_index = try self.allocateSymbol();
    atom.size = @sizeOf(u64);
    atom.alignment = @alignOf(u64);

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, atom.sym_index, atom);

    const sym = atom.getSymbolPtr(self);
    sym.section_number = @intToEnum(coff.SectionNumber, self.idata_section_index.? + 1);
    sym.value = try self.allocateAtom(atom, atom.size, atom.alignment);

    log.debug("allocated import atom at 0x{x}", .{sym.value});

    return atom;
}

fn growAtom(self: *Coff, atom: *Atom, new_atom_size: u32, alignment: u32) !u32 {
    const sym = atom.getSymbol(self);
    const align_ok = mem.alignBackwardGeneric(u32, sym.value, alignment) == sym.value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self);
    if (!need_realloc) return sym.value;
    return self.allocateAtom(atom, new_atom_size, alignment);
}

fn shrinkAtom(self: *Coff, atom: *Atom, new_block_size: u32) void {
    _ = self;
    _ = atom;
    _ = new_block_size;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn writeAtom(self: *Coff, atom: *Atom, code: []const u8) !void {
    const sym = atom.getSymbol(self);
    const section = self.sections.get(@enumToInt(sym.section_number) - 1);
    const file_offset = section.header.pointer_to_raw_data + sym.value - section.header.virtual_address;
    log.debug("writing atom for symbol {s} at file offset 0x{x} to 0x{x}", .{ atom.getName(self), file_offset, file_offset + code.len });
    try self.base.file.?.pwriteAll(code, file_offset);
    try self.resolveRelocs(atom);
}

fn writePtrWidthAtom(self: *Coff, atom: *Atom) !void {
    switch (self.ptr_width) {
        .p32 => {
            var buffer: [@sizeOf(u32)]u8 = [_]u8{0} ** @sizeOf(u32);
            try self.writeAtom(atom, &buffer);
        },
        .p64 => {
            var buffer: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64);
            try self.writeAtom(atom, &buffer);
        },
    }
}

fn markRelocsDirtyByTarget(self: *Coff, target: SymbolWithLoc) void {
    // TODO: reverse-lookup might come in handy here
    var it = self.relocs.valueIterator();
    while (it.next()) |relocs| {
        for (relocs.items) |*reloc| {
            if (!reloc.target.eql(target)) continue;
            reloc.dirty = true;
        }
    }
}

fn markRelocsDirtyByAddress(self: *Coff, addr: u32) void {
    var it = self.relocs.valueIterator();
    while (it.next()) |relocs| {
        for (relocs.items) |*reloc| {
            const target_atom = reloc.getTargetAtom(self) orelse continue;
            const target_sym = target_atom.getSymbol(self);
            if (target_sym.value < addr) continue;
            reloc.dirty = true;
        }
    }
}

fn resolveRelocs(self: *Coff, atom: *Atom) !void {
    const relocs = self.relocs.get(atom) orelse return;

    log.debug("relocating '{s}'", .{atom.getName(self)});

    for (relocs.items) |*reloc| {
        if (!reloc.dirty) continue;
        try reloc.resolve(atom, self);
    }
}

fn freeAtom(self: *Coff, atom: *Atom) void {
    log.debug("freeAtom {*}", .{atom});

    // Remove any relocs and base relocs associated with this Atom
    self.freeRelocationsForAtom(atom);

    const sym = atom.getSymbol(self);
    const sect_id = @enumToInt(sym.section_number) - 1;
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

    const decl_index = func.owner_decl;
    const decl = module.declPtr(decl_index);
    self.freeUnnamedConsts(decl_index);
    self.freeRelocationsForAtom(&decl.link.coff);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

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

    try self.updateDeclCode(decl_index, code, .FUNCTION);

    // Since we updated the vaddr and the size, each corresponding export
    // symbol also needs to be updated.
    return self.updateDeclExports(module, decl_index, module.getDeclExports(decl_index));
}

pub fn lowerUnnamedConst(self: *Coff, tv: TypedValue, decl_index: Module.Decl.Index) !u32 {
    const gpa = self.base.allocator;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const gop = try self.unnamed_const_atoms.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;

    const atom = try gpa.create(Atom);
    errdefer gpa.destroy(atom);
    atom.* = Atom.empty;

    atom.sym_index = try self.allocateSymbol();
    const sym = atom.getSymbolPtr(self);
    const sym_name = blk: {
        const decl_name = try decl.getFullyQualifiedName(mod);
        defer gpa.free(decl_name);

        const index = unnamed_consts.items.len;
        break :blk try std.fmt.allocPrint(gpa, "__unnamed_{s}_{d}", .{ decl_name, index });
    };
    defer gpa.free(sym_name);
    try self.setSymbolName(sym, sym_name);
    sym.section_number = @intToEnum(coff.SectionNumber, self.rdata_section_index.? + 1);

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, atom.sym_index, atom);

    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), tv, &code_buffer, .none, .{
        .parent_atom_index = atom.sym_index,
    });
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            log.err("{s}", .{em.msg});
            return error.AnalysisFail;
        },
    };

    const required_alignment = tv.ty.abiAlignment(self.base.options.target);
    atom.alignment = required_alignment;
    atom.size = @intCast(u32, code.len);
    sym.value = try self.allocateAtom(atom, atom.size, atom.alignment);
    errdefer self.freeAtom(atom);

    try unnamed_consts.append(gpa, atom);

    log.debug("allocated atom for {s} at 0x{x}", .{ sym_name, sym.value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    try self.writeAtom(atom, code);

    return atom.sym_index;
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

    self.freeRelocationsForAtom(&decl.link.coff);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const decl_val = if (decl.val.castTag(.variable)) |payload| payload.data.init else decl.val;
    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
        .ty = decl.ty,
        .val = decl_val,
    }, &code_buffer, .none, .{
        .parent_atom_index = decl.link.coff.sym_index,
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

    try self.updateDeclCode(decl_index, code, .NULL);

    // Since we updated the vaddr and the size, each corresponding export
    // symbol also needs to be updated.
    return self.updateDeclExports(module, decl_index, module.getDeclExports(decl_index));
}

fn getDeclOutputSection(self: *Coff, decl: *Module.Decl) u16 {
    const ty = decl.ty;
    const zig_ty = ty.zigTypeTag();
    const val = decl.val;
    const index: u16 = blk: {
        if (val.isUndefDeep()) {
            // TODO in release-fast and release-small, we should put undef in .bss
            break :blk self.data_section_index.?;
        }

        switch (zig_ty) {
            // TODO: what if this is a function pointer?
            .Fn => break :blk self.text_section_index.?,
            else => {
                if (val.castTag(.variable)) |_| {
                    break :blk self.data_section_index.?;
                }
                break :blk self.rdata_section_index.?;
            },
        }
    };
    return index;
}

fn updateDeclCode(self: *Coff, decl_index: Module.Decl.Index, code: []const u8, complex_type: coff.ComplexType) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer gpa.free(decl_name);

    log.debug("updateDeclCode {s}{*}", .{ decl_name, decl });
    const required_alignment = decl.getAlignment(self.base.options.target);

    const decl_ptr = self.decls.getPtr(decl_index).?;
    if (decl_ptr.* == null) {
        decl_ptr.* = self.getDeclOutputSection(decl);
    }
    const sect_index = decl_ptr.*.?;

    const code_len = @intCast(u32, code.len);
    const atom = &decl.link.coff;
    assert(atom.sym_index != 0); // Caller forgot to allocateDeclIndexes()
    if (atom.size != 0) {
        const sym = atom.getSymbolPtr(self);
        try self.setSymbolName(sym, decl_name);
        sym.section_number = @intToEnum(coff.SectionNumber, sect_index + 1);
        sym.type = .{ .complex_type = complex_type, .base_type = .NULL };

        const capacity = atom.capacity(self);
        const need_realloc = code.len > capacity or !mem.isAlignedGeneric(u64, sym.value, required_alignment);
        if (need_realloc) {
            const vaddr = try self.growAtom(atom, code_len, required_alignment);
            log.debug("growing {s} from 0x{x} to 0x{x}", .{ decl_name, sym.value, vaddr });
            log.debug("  (required alignment 0x{x}", .{required_alignment});

            if (vaddr != sym.value) {
                sym.value = vaddr;
                log.debug("  (updating GOT entry)", .{});
                const got_target = SymbolWithLoc{ .sym_index = atom.sym_index, .file = null };
                const got_atom = self.getGotAtomForSymbol(got_target).?;
                self.markRelocsDirtyByTarget(got_target);
                try self.writePtrWidthAtom(got_atom);
            }
        } else if (code_len < atom.size) {
            self.shrinkAtom(atom, code_len);
        }
        atom.size = code_len;
    } else {
        const sym = atom.getSymbolPtr(self);
        try self.setSymbolName(sym, decl_name);
        sym.section_number = @intToEnum(coff.SectionNumber, sect_index + 1);
        sym.type = .{ .complex_type = complex_type, .base_type = .NULL };

        const vaddr = try self.allocateAtom(atom, code_len, required_alignment);
        errdefer self.freeAtom(atom);
        log.debug("allocated atom for {s} at 0x{x}", .{ decl_name, vaddr });
        atom.size = code_len;
        sym.value = vaddr;

        const got_target = SymbolWithLoc{ .sym_index = atom.sym_index, .file = null };
        const got_index = try self.allocateGotEntry(got_target);
        const got_atom = try self.createGotAtom(got_target);
        self.got_entries.items[got_index].sym_index = got_atom.sym_index;
        try self.writePtrWidthAtom(got_atom);
    }

    self.markRelocsDirtyByTarget(atom.getSymbolWithLoc());
    try self.writeAtom(atom, code);
}

fn freeRelocationsForAtom(self: *Coff, atom: *Atom) void {
    var removed_relocs = self.relocs.fetchRemove(atom);
    if (removed_relocs) |*relocs| relocs.value.deinit(self.base.allocator);
    var removed_base_relocs = self.base_relocs.fetchRemove(atom);
    if (removed_base_relocs) |*base_relocs| base_relocs.value.deinit(self.base.allocator);
}

fn freeUnnamedConsts(self: *Coff, decl_index: Module.Decl.Index) void {
    const gpa = self.base.allocator;
    const unnamed_consts = self.unnamed_const_atoms.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |atom| {
        self.freeAtom(atom);
        self.locals_free_list.append(gpa, atom.sym_index) catch {};
        self.locals.items[atom.sym_index].section_number = .UNDEFINED;
        _ = self.atom_by_index_table.remove(atom.sym_index);
        log.debug("  adding local symbol index {d} to free list", .{atom.sym_index});
        atom.sym_index = 0;
    }
    unnamed_consts.clearAndFree(gpa);
}

pub fn freeDecl(self: *Coff, decl_index: Module.Decl.Index) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    }

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    log.debug("freeDecl {*}", .{decl});

    const kv = self.decls.fetchRemove(decl_index);
    if (kv.?.value) |_| {
        self.freeAtom(&decl.link.coff);
        self.freeUnnamedConsts(decl_index);
    }

    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    const gpa = self.base.allocator;
    const sym_index = decl.link.coff.sym_index;
    if (sym_index != 0) {
        self.locals_free_list.append(gpa, sym_index) catch {};

        // Try freeing GOT atom if this decl had one
        const got_target = SymbolWithLoc{ .sym_index = sym_index, .file = null };
        if (self.got_entries_table.get(got_target)) |got_index| {
            self.got_entries_free_list.append(gpa, @intCast(u32, got_index)) catch {};
            self.got_entries.items[got_index] = .{
                .target = .{ .sym_index = 0, .file = null },
                .sym_index = 0,
            };
            _ = self.got_entries_table.remove(got_target);

            log.debug("  adding GOT index {d} to free list (target local@{d})", .{ got_index, sym_index });
        }

        self.locals.items[sym_index].section_number = .UNDEFINED;
        _ = self.atom_by_index_table.remove(sym_index);
        log.debug("  adding local symbol index {d} to free list", .{sym_index});
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

    if (build_options.have_llvm) {
        // Even in the case of LLVM, we need to notice certain exported symbols in order to
        // detect the default subsystem.
        for (exports) |exp| {
            const exported_decl = module.declPtr(exp.exported_decl);
            if (exported_decl.getFunction() == null) continue;
            const winapi_cc = switch (self.base.options.target.cpu.arch) {
                .x86 => std.builtin.CallingConvention.Stdcall,
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

        if (self.llvm_object) |llvm_object| return llvm_object.updateDeclExports(module, decl_index, exports);
    }

    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    const decl = module.declPtr(decl_index);
    const atom = &decl.link.coff;
    if (atom.sym_index == 0) return;
    const decl_sym = atom.getSymbol(self);

    for (exports) |exp| {
        log.debug("adding new export '{s}'", .{exp.options.name});

        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, ".text")) {
                try module.failed_exports.putNoClobber(
                    module.gpa,
                    exp,
                    try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(),
                        "Unimplemented: ExportOptions.section",
                        .{},
                    ),
                );
                continue;
            }
        }

        if (exp.options.linkage == .LinkOnce) {
            try module.failed_exports.putNoClobber(
                module.gpa,
                exp,
                try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(),
                    "Unimplemented: GlobalLinkage.LinkOnce",
                    .{},
                ),
            );
            continue;
        }

        const sym_index = exp.link.coff.sym_index orelse blk: {
            const sym_index = try self.allocateSymbol();
            exp.link.coff.sym_index = sym_index;
            break :blk sym_index;
        };
        const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
        const sym = self.getSymbolPtr(sym_loc);
        try self.setSymbolName(sym, exp.options.name);
        sym.value = decl_sym.value;
        sym.section_number = @intToEnum(coff.SectionNumber, self.text_section_index.? + 1);
        sym.type = .{ .complex_type = .FUNCTION, .base_type = .NULL };

        switch (exp.options.linkage) {
            .Strong => {
                sym.storage_class = .EXTERNAL;
            },
            .Internal => @panic("TODO Internal"),
            .Weak => @panic("TODO WeakExternal"),
            else => unreachable,
        }

        try self.resolveGlobalSymbol(sym_loc);
    }
}

pub fn deleteExport(self: *Coff, exp: Export) void {
    if (self.llvm_object) |_| return;
    const sym_index = exp.sym_index orelse return;

    const gpa = self.base.allocator;

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    const sym = self.getSymbolPtr(sym_loc);
    const sym_name = self.getSymbolName(sym_loc);
    log.debug("deleting export '{s}'", .{sym_name});
    assert(sym.storage_class == .EXTERNAL and sym.section_number != .UNDEFINED);
    sym.* = .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    };
    self.locals_free_list.append(gpa, sym_index) catch {};

    if (self.resolver.fetchRemove(sym_name)) |entry| {
        defer gpa.free(entry.key);
        self.globals_free_list.append(gpa, entry.value) catch {};
        self.globals.items[entry.value] = .{
            .sym_index = 0,
            .file = null,
        };
    }
}

fn resolveGlobalSymbol(self: *Coff, current: SymbolWithLoc) !void {
    const gpa = self.base.allocator;
    const sym = self.getSymbol(current);
    const sym_name = self.getSymbolName(current);

    const gop = try self.getOrPutGlobalPtr(sym_name);
    if (!gop.found_existing) {
        gop.value_ptr.* = current;
        if (sym.section_number == .UNDEFINED) {
            try self.unresolved.putNoClobber(gpa, self.getGlobalIndex(sym_name).?, false);
        }
        return;
    }

    log.debug("TODO finish resolveGlobalSymbols implementation", .{});

    if (sym.section_number == .UNDEFINED) return;

    _ = self.unresolved.swapRemove(self.getGlobalIndex(sym_name).?);

    gop.value_ptr.* = current;
}

pub fn flush(self: *Coff, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
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

pub fn flushModule(self: *Coff, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
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

    while (self.unresolved.popOrNull()) |entry| {
        assert(entry.value); // We only expect imports generated by the incremental linker for now.
        const global = self.globals.items[entry.key];
        if (self.imports_table.contains(global)) continue;

        const import_index = try self.allocateImportEntry(global);
        const import_atom = try self.createImportAtom();
        self.imports.items[import_index].sym_index = import_atom.sym_index;
        try self.writePtrWidthAtom(import_atom);
    }

    if (build_options.enable_logging) {
        self.logSymtab();
    }

    {
        var it = self.relocs.keyIterator();
        while (it.next()) |atom| {
            try self.resolveRelocs(atom.*);
        }
    }
    try self.writeImportTable();
    try self.writeBaseRelocations();

    if (self.getEntryPoint()) |entry_sym_loc| {
        self.entry_addr = self.getSymbol(entry_sym_loc).value;
    }

    try self.writeStrtab();
    try self.writeDataDirectoriesHeaders();
    try self.writeSectionHeaders();

    if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        self.error_flags.no_entry_point_found = false;
        try self.writeHeader();
    }
}

pub fn getDeclVAddr(
    self: *Coff,
    decl_index: Module.Decl.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    assert(self.llvm_object == null);
    assert(decl.link.coff.sym_index != 0);

    const atom = self.getAtomForSymbol(.{ .sym_index = reloc_info.parent_atom_index, .file = null }).?;
    const target = SymbolWithLoc{ .sym_index = decl.link.coff.sym_index, .file = null };
    try atom.addRelocation(self, .{
        .type = .direct,
        .target = target,
        .offset = @intCast(u32, reloc_info.offset),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try atom.addBaseRelocation(self, @intCast(u32, reloc_info.offset));

    return 0;
}

pub fn getGlobalSymbol(self: *Coff, name: []const u8) !u32 {
    const gop = try self.getOrPutGlobalPtr(name);
    const global_index = self.getGlobalIndex(name).?;

    if (gop.found_existing) {
        return global_index;
    }

    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    gop.value_ptr.* = sym_loc;

    const gpa = self.base.allocator;
    const sym = self.getSymbolPtr(sym_loc);
    try self.setSymbolName(sym, name);
    sym.storage_class = .EXTERNAL;

    try self.unresolved.putNoClobber(gpa, global_index, true);

    return global_index;
}

pub fn updateDeclLineNumber(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    _ = self;
    _ = module;
    _ = decl;
    log.debug("TODO implement updateDeclLineNumber", .{});
}

/// TODO: note if we need to rewrite base relocations by dirtying any of the entries in the global table
/// TODO: note that .ABSOLUTE is used as padding within each block; we could use this fact to do
///       incremental updates and writes into the table instead of doing it all at once
fn writeBaseRelocations(self: *Coff) !void {
    const gpa = self.base.allocator;

    var pages = std.AutoHashMap(u32, std.ArrayList(coff.BaseRelocation)).init(gpa);
    defer {
        var it = pages.valueIterator();
        while (it.next()) |inner| {
            inner.deinit();
        }
        pages.deinit();
    }

    var it = self.base_relocs.iterator();
    while (it.next()) |entry| {
        const atom = entry.key_ptr.*;
        const offsets = entry.value_ptr.*;

        for (offsets.items) |offset| {
            const sym = atom.getSymbol(self);
            const rva = sym.value + offset;
            const page = mem.alignBackwardGeneric(u32, rva, self.page_size);
            const gop = try pages.getOrPut(page);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(coff.BaseRelocation).init(gpa);
            }
            try gop.value_ptr.append(.{
                .offset = @intCast(u12, rva - page),
                .type = .DIR64,
            });
        }
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    var pages_it = pages.iterator();
    while (pages_it.next()) |entry| {
        // Pad to required 4byte alignment
        if (!mem.isAlignedGeneric(
            usize,
            entry.value_ptr.items.len * @sizeOf(coff.BaseRelocation),
            @sizeOf(u32),
        )) {
            try entry.value_ptr.append(.{
                .offset = 0,
                .type = .ABSOLUTE,
            });
        }

        const block_size = @intCast(
            u32,
            entry.value_ptr.items.len * @sizeOf(coff.BaseRelocation) + @sizeOf(coff.BaseRelocationDirectoryEntry),
        );
        try buffer.ensureUnusedCapacity(block_size);
        buffer.appendSliceAssumeCapacity(mem.asBytes(&coff.BaseRelocationDirectoryEntry{
            .page_rva = entry.key_ptr.*,
            .block_size = block_size,
        }));
        buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(entry.value_ptr.items));
    }

    const header = &self.sections.items(.header)[self.reloc_section_index.?];
    const sect_capacity = self.allocatedSize(header.pointer_to_raw_data);
    const needed_size = @intCast(u32, buffer.items.len);
    if (needed_size > sect_capacity) {
        const new_offset = self.findFreeSpace(needed_size, default_file_alignment);
        log.debug("writing {s} at 0x{x} to 0x{x} (0x{x} - 0x{x})", .{
            self.getSectionName(header),
            header.pointer_to_raw_data,
            header.pointer_to_raw_data + needed_size,
            new_offset,
            new_offset + needed_size,
        });
        header.pointer_to_raw_data = new_offset;

        const sect_vm_capacity = self.allocatedVirtualSize(header.virtual_address);
        if (needed_size > sect_vm_capacity) {
            // TODO: we want to enforce .reloc after every alloc section.
            try self.growSectionVM(self.reloc_section_index.?, needed_size);
        }
    }
    header.virtual_size = @max(header.virtual_size, needed_size);
    header.size_of_raw_data = needed_size;

    try self.base.file.?.pwriteAll(buffer.items, header.pointer_to_raw_data);

    self.data_directories[@enumToInt(coff.DirectoryEntry.BASERELOC)] = .{
        .virtual_address = header.virtual_address,
        .size = needed_size,
    };
}

fn writeImportTable(self: *Coff) !void {
    if (self.idata_section_index == null) return;

    const gpa = self.base.allocator;

    const section = self.sections.get(self.idata_section_index.?);
    const last_atom = section.last_atom orelse return;

    const iat_rva = section.header.virtual_address;
    const iat_size = last_atom.getSymbol(self).value + last_atom.size * 2 - iat_rva; // account for sentinel zero pointer

    const dll_name = "KERNEL32.dll";

    var import_dir_entry = coff.ImportDirectoryEntry{
        .import_lookup_table_rva = @sizeOf(coff.ImportDirectoryEntry) * 2,
        .time_date_stamp = 0,
        .forwarder_chain = 0,
        .name_rva = 0,
        .import_address_table_rva = iat_rva,
    };

    // TODO: we currently assume there's only one (implicit) DLL - ntdll
    var lookup_table = std.ArrayList(coff.ImportLookupEntry64.ByName).init(gpa);
    defer lookup_table.deinit();

    var names_table = std.ArrayList(u8).init(gpa);
    defer names_table.deinit();

    // TODO: check if import is still valid
    for (self.imports.items) |entry| {
        const target_name = self.getSymbolName(entry.target);
        const start = names_table.items.len;
        mem.writeIntLittle(u16, try names_table.addManyAsArray(2), 0); // TODO: currently, hint is set to 0 as we haven't yet parsed any DLL
        try names_table.appendSlice(target_name);
        try names_table.append(0);
        const end = names_table.items.len;
        if (!mem.isAlignedGeneric(usize, end - start, @sizeOf(u16))) {
            try names_table.append(0);
        }
        try lookup_table.append(.{ .name_table_rva = @intCast(u31, start) });
    }
    try lookup_table.append(.{ .name_table_rva = 0 }); // the sentinel

    const dir_entry_size = @sizeOf(coff.ImportDirectoryEntry) + lookup_table.items.len * @sizeOf(coff.ImportLookupEntry64.ByName) + names_table.items.len + dll_name.len + 1;
    const needed_size = iat_size + dir_entry_size + @sizeOf(coff.ImportDirectoryEntry);
    const sect_capacity = self.allocatedSize(section.header.pointer_to_raw_data);
    assert(needed_size < sect_capacity); // TODO: implement expanding .idata section

    // Fixup offsets
    const base_rva = iat_rva + iat_size;
    import_dir_entry.import_lookup_table_rva += base_rva;
    import_dir_entry.name_rva = @intCast(u32, base_rva + dir_entry_size + @sizeOf(coff.ImportDirectoryEntry) - dll_name.len - 1);

    for (lookup_table.items[0 .. lookup_table.items.len - 1]) |*lk| {
        lk.name_table_rva += @intCast(u31, base_rva + @sizeOf(coff.ImportDirectoryEntry) * 2 + lookup_table.items.len * @sizeOf(coff.ImportLookupEntry64.ByName));
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacity(dir_entry_size + @sizeOf(coff.ImportDirectoryEntry));
    buffer.appendSliceAssumeCapacity(mem.asBytes(&import_dir_entry));
    buffer.appendNTimesAssumeCapacity(0, @sizeOf(coff.ImportDirectoryEntry)); // the sentinel; TODO: I think doing all of the above on bytes directly might be cleaner
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(lookup_table.items));
    buffer.appendSliceAssumeCapacity(names_table.items);
    buffer.appendSliceAssumeCapacity(dll_name);
    buffer.appendAssumeCapacity(0);

    try self.base.file.?.pwriteAll(buffer.items, section.header.pointer_to_raw_data + iat_size);
    // Override the IAT atoms
    // TODO: we should rewrite only dirtied atoms, but that's for way later
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(lookup_table.items), section.header.pointer_to_raw_data);

    self.data_directories[@enumToInt(coff.DirectoryEntry.IMPORT)] = .{
        .virtual_address = iat_rva + iat_size,
        .size = @intCast(u32, @sizeOf(coff.ImportDirectoryEntry) * 2),
    };

    self.data_directories[@enumToInt(coff.DirectoryEntry.IAT)] = .{
        .virtual_address = iat_rva,
        .size = iat_size,
    };
}

fn writeStrtab(self: *Coff) !void {
    if (self.strtab_offset == null) return;

    const allocated_size = self.allocatedSize(self.strtab_offset.?);
    const needed_size = @intCast(u32, self.strtab.len());

    if (needed_size > allocated_size) {
        self.strtab_offset = null;
        self.strtab_offset = @intCast(u32, self.findFreeSpace(needed_size, @alignOf(u32)));
    }

    log.debug("writing strtab from 0x{x} to 0x{x}", .{ self.strtab_offset.?, self.strtab_offset.? + needed_size });

    var buffer = std.ArrayList(u8).init(self.base.allocator);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.appendSliceAssumeCapacity(self.strtab.items());
    // Here, we do a trick in that we do not commit the size of the strtab to strtab buffer, instead
    // we write the length of the strtab to a temporary buffer that goes to file.
    mem.writeIntLittle(u32, buffer.items[0..4], @intCast(u32, self.strtab.len()));

    try self.base.file.?.pwriteAll(buffer.items, self.strtab_offset.?);
}

fn writeSectionHeaders(self: *Coff) !void {
    const offset = self.getSectionHeadersOffset();
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.sections.items(.header)), offset);
}

fn writeDataDirectoriesHeaders(self: *Coff) !void {
    const offset = self.getDataDirectoryHeadersOffset();
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(&self.data_directories), offset);
}

fn writeHeader(self: *Coff) !void {
    const gpa = self.base.allocator;
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    const writer = buffer.writer();

    try buffer.ensureTotalCapacity(self.getSizeOfHeaders());
    writer.writeAll(msdos_stub) catch unreachable;
    mem.writeIntLittle(u32, buffer.items[0x3c..][0..4], msdos_stub.len);

    writer.writeAll("PE\x00\x00") catch unreachable;
    var flags = coff.CoffHeaderFlags{
        .EXECUTABLE_IMAGE = 1,
        .DEBUG_STRIPPED = 1, // TODO
    };
    switch (self.ptr_width) {
        .p32 => flags.@"32BIT_MACHINE" = 1,
        .p64 => flags.LARGE_ADDRESS_AWARE = 1,
    }
    if (self.base.options.output_mode == .Lib and self.base.options.link_mode == .Dynamic) {
        flags.DLL = 1;
    }

    const timestamp = std.time.timestamp();
    const size_of_optional_header = @intCast(u16, self.getOptionalHeaderSize() + self.getDataDirectoryHeadersSize());
    var coff_header = coff.CoffHeader{
        .machine = coff.MachineType.fromTargetCpuArch(self.base.options.target.cpu.arch),
        .number_of_sections = @intCast(u16, self.sections.slice().len), // TODO what if we prune a section
        .time_date_stamp = @truncate(u32, @bitCast(u64, timestamp)),
        .pointer_to_symbol_table = self.strtab_offset orelse 0,
        .number_of_symbols = 0,
        .size_of_optional_header = size_of_optional_header,
        .flags = flags,
    };

    writer.writeAll(mem.asBytes(&coff_header)) catch unreachable;

    const dll_flags: coff.DllFlags = .{
        .HIGH_ENTROPY_VA = 1, // TODO do we want to permit non-PIE builds at all?
        .DYNAMIC_BASE = 1,
        .TERMINAL_SERVER_AWARE = 1, // We are not a legacy app
        .NX_COMPAT = 1, // We are compatible with Data Execution Prevention
    };
    const subsystem: coff.Subsystem = .WINDOWS_CUI;
    const size_of_image: u32 = self.getSizeOfImage();
    const size_of_headers: u32 = mem.alignForwardGeneric(u32, self.getSizeOfHeaders(), default_file_alignment);
    const image_base = self.getImageBase();

    const base_of_code = self.sections.get(self.text_section_index.?).header.virtual_address;
    const base_of_data = self.sections.get(self.data_section_index.?).header.virtual_address;

    var size_of_code: u32 = 0;
    var size_of_initialized_data: u32 = 0;
    var size_of_uninitialized_data: u32 = 0;
    for (self.sections.items(.header)) |header| {
        if (header.flags.CNT_CODE == 1) {
            size_of_code += header.size_of_raw_data;
        }
        if (header.flags.CNT_INITIALIZED_DATA == 1) {
            size_of_initialized_data += header.size_of_raw_data;
        }
        if (header.flags.CNT_UNINITIALIZED_DATA == 1) {
            size_of_uninitialized_data += header.size_of_raw_data;
        }
    }

    switch (self.ptr_width) {
        .p32 => {
            var opt_header = coff.OptionalHeaderPE32{
                .magic = coff.IMAGE_NT_OPTIONAL_HDR32_MAGIC,
                .major_linker_version = 0,
                .minor_linker_version = 0,
                .size_of_code = size_of_code,
                .size_of_initialized_data = size_of_initialized_data,
                .size_of_uninitialized_data = size_of_uninitialized_data,
                .address_of_entry_point = self.entry_addr orelse 0,
                .base_of_code = base_of_code,
                .base_of_data = base_of_data,
                .image_base = @intCast(u32, image_base),
                .section_alignment = self.page_size,
                .file_alignment = default_file_alignment,
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = 6,
                .minor_subsystem_version = 0,
                .win32_version_value = 0,
                .size_of_image = size_of_image,
                .size_of_headers = size_of_headers,
                .checksum = 0,
                .subsystem = subsystem,
                .dll_flags = dll_flags,
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = @intCast(u32, self.data_directories.len),
            };
            writer.writeAll(mem.asBytes(&opt_header)) catch unreachable;
        },
        .p64 => {
            var opt_header = coff.OptionalHeaderPE64{
                .magic = coff.IMAGE_NT_OPTIONAL_HDR64_MAGIC,
                .major_linker_version = 0,
                .minor_linker_version = 0,
                .size_of_code = size_of_code,
                .size_of_initialized_data = size_of_initialized_data,
                .size_of_uninitialized_data = size_of_uninitialized_data,
                .address_of_entry_point = self.entry_addr orelse 0,
                .base_of_code = base_of_code,
                .image_base = image_base,
                .section_alignment = self.page_size,
                .file_alignment = default_file_alignment,
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = 6,
                .minor_subsystem_version = 0,
                .win32_version_value = 0,
                .size_of_image = size_of_image,
                .size_of_headers = size_of_headers,
                .checksum = 0,
                .subsystem = subsystem,
                .dll_flags = dll_flags,
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = @intCast(u32, self.data_directories.len),
            };
            writer.writeAll(mem.asBytes(&opt_header)) catch unreachable;
        },
    }

    try self.base.file.?.pwriteAll(buffer.items, 0);
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

fn detectAllocCollision(self: *Coff, start: u32, size: u32) ?u32 {
    const headers_size = @max(self.getSizeOfHeaders(), self.page_size);
    if (start < headers_size)
        return headers_size;

    const end = start + padToIdeal(size);

    if (self.strtab_offset) |off| {
        const tight_size = @intCast(u32, self.strtab.len());
        const increased_size = padToIdeal(tight_size);
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (self.sections.items(.header)) |header| {
        const tight_size = header.size_of_raw_data;
        const increased_size = padToIdeal(tight_size);
        const test_end = header.pointer_to_raw_data + increased_size;
        if (end > header.pointer_to_raw_data and start < test_end) {
            return test_end;
        }
    }

    return null;
}

fn allocatedSize(self: *Coff, start: u32) u32 {
    if (start == 0)
        return 0;
    var min_pos: u32 = std.math.maxInt(u32);
    if (self.strtab_offset) |off| {
        if (off > start and off < min_pos) min_pos = off;
    }
    for (self.sections.items(.header)) |header| {
        if (header.pointer_to_raw_data <= start) continue;
        if (header.pointer_to_raw_data < min_pos) min_pos = header.pointer_to_raw_data;
    }
    return min_pos - start;
}

fn findFreeSpace(self: *Coff, object_size: u32, min_alignment: u32) u32 {
    var start: u32 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u32, item_end, min_alignment);
    }
    return start;
}

fn allocatedVirtualSize(self: *Coff, start: u32) u32 {
    if (start == 0)
        return 0;
    var min_pos: u32 = std.math.maxInt(u32);
    for (self.sections.items(.header)) |header| {
        if (header.virtual_address <= start) continue;
        if (header.virtual_address < min_pos) min_pos = header.virtual_address;
    }
    return min_pos - start;
}

inline fn getSizeOfHeaders(self: Coff) u32 {
    const msdos_hdr_size = msdos_stub.len + 4;
    return @intCast(u32, msdos_hdr_size + @sizeOf(coff.CoffHeader) + self.getOptionalHeaderSize() +
        self.getDataDirectoryHeadersSize() + self.getSectionHeadersSize());
}

inline fn getOptionalHeaderSize(self: Coff) u32 {
    return switch (self.ptr_width) {
        .p32 => @intCast(u32, @sizeOf(coff.OptionalHeaderPE32)),
        .p64 => @intCast(u32, @sizeOf(coff.OptionalHeaderPE64)),
    };
}

inline fn getDataDirectoryHeadersSize(self: Coff) u32 {
    return @intCast(u32, self.data_directories.len * @sizeOf(coff.ImageDataDirectory));
}

inline fn getSectionHeadersSize(self: Coff) u32 {
    return @intCast(u32, self.sections.slice().len * @sizeOf(coff.SectionHeader));
}

inline fn getDataDirectoryHeadersOffset(self: Coff) u32 {
    const msdos_hdr_size = msdos_stub.len + 4;
    return @intCast(u32, msdos_hdr_size + @sizeOf(coff.CoffHeader) + self.getOptionalHeaderSize());
}

inline fn getSectionHeadersOffset(self: Coff) u32 {
    return self.getDataDirectoryHeadersOffset() + self.getDataDirectoryHeadersSize();
}

inline fn getSizeOfImage(self: Coff) u32 {
    var image_size: u32 = mem.alignForwardGeneric(u32, self.getSizeOfHeaders(), self.page_size);
    for (self.sections.items(.header)) |header| {
        image_size += mem.alignForwardGeneric(u32, header.virtual_size, self.page_size);
    }
    return image_size;
}

/// Returns symbol location corresponding to the set entrypoint (if any).
pub fn getEntryPoint(self: Coff) ?SymbolWithLoc {
    const entry_name = self.base.options.entry orelse "wWinMainCRTStartup"; // TODO this is incomplete
    const global_index = self.resolver.get(entry_name) orelse return null;
    return self.globals.items[global_index];
}

pub fn getImageBase(self: Coff) u64 {
    const image_base: u64 = self.base.options.image_base_override orelse switch (self.base.options.output_mode) {
        .Exe => switch (self.base.options.target.cpu.arch) {
            .aarch64 => @as(u64, 0x140000000),
            .x86_64, .x86 => 0x400000,
            else => unreachable, // unsupported target architecture
        },
        .Lib => 0x10000000,
        .Obj => 0,
    };
    return image_base;
}

/// Returns pointer-to-symbol described by `sym_loc` descriptor.
pub fn getSymbolPtr(self: *Coff, sym_loc: SymbolWithLoc) *coff.Symbol {
    assert(sym_loc.file == null); // TODO linking object files
    return &self.locals.items[sym_loc.sym_index];
}

/// Returns symbol described by `sym_loc` descriptor.
pub fn getSymbol(self: *const Coff, sym_loc: SymbolWithLoc) *const coff.Symbol {
    assert(sym_loc.file == null); // TODO linking object files
    return &self.locals.items[sym_loc.sym_index];
}

/// Returns name of the symbol described by `sym_loc` descriptor.
pub fn getSymbolName(self: *const Coff, sym_loc: SymbolWithLoc) []const u8 {
    assert(sym_loc.file == null); // TODO linking object files
    const sym = self.getSymbol(sym_loc);
    const offset = sym.getNameOffset() orelse return sym.getName().?;
    return self.strtab.get(offset).?;
}

/// Returns pointer to the global entry for `name` if one exists.
pub fn getGlobalPtr(self: *Coff, name: []const u8) ?*SymbolWithLoc {
    const global_index = self.resolver.get(name) orelse return null;
    return &self.globals.items[global_index];
}

/// Returns the global entry for `name` if one exists.
pub fn getGlobal(self: *const Coff, name: []const u8) ?SymbolWithLoc {
    const global_index = self.resolver.get(name) orelse return null;
    return self.globals.items[global_index];
}

/// Returns the index of the global entry for `name` if one exists.
pub fn getGlobalIndex(self: *const Coff, name: []const u8) ?u32 {
    return self.resolver.get(name);
}

/// Returns global entry at `index`.
pub fn getGlobalByIndex(self: *const Coff, index: u32) SymbolWithLoc {
    assert(index < self.globals.items.len);
    return self.globals.items[index];
}

const GetOrPutGlobalPtrResult = struct {
    found_existing: bool,
    value_ptr: *SymbolWithLoc,
};

/// Return pointer to the global entry for `name` if one exists.
/// Puts a new global entry for `name` if one doesn't exist, and
/// returns a pointer to it.
pub fn getOrPutGlobalPtr(self: *Coff, name: []const u8) !GetOrPutGlobalPtrResult {
    if (self.getGlobalPtr(name)) |ptr| {
        return GetOrPutGlobalPtrResult{ .found_existing = true, .value_ptr = ptr };
    }
    const gpa = self.base.allocator;
    const global_index = try self.allocateGlobal();
    const global_name = try gpa.dupe(u8, name);
    _ = try self.resolver.put(gpa, global_name, global_index);
    const ptr = &self.globals.items[global_index];
    return GetOrPutGlobalPtrResult{ .found_existing = false, .value_ptr = ptr };
}

/// Returns atom if there is an atom referenced by the symbol described by `sym_loc` descriptor.
/// Returns null on failure.
pub fn getAtomForSymbol(self: *Coff, sym_loc: SymbolWithLoc) ?*Atom {
    assert(sym_loc.file == null); // TODO linking with object files
    return self.atom_by_index_table.get(sym_loc.sym_index);
}

/// Returns GOT atom that references `sym_loc` if one exists.
/// Returns null otherwise.
pub fn getGotAtomForSymbol(self: *Coff, sym_loc: SymbolWithLoc) ?*Atom {
    const got_index = self.got_entries_table.get(sym_loc) orelse return null;
    const got_entry = self.got_entries.items[got_index];
    return self.getAtomForSymbol(.{ .sym_index = got_entry.sym_index, .file = null });
}

/// Returns import atom that references `sym_loc` if one exists.
/// Returns null otherwise.
pub fn getImportAtomForSymbol(self: *Coff, sym_loc: SymbolWithLoc) ?*Atom {
    const imports_index = self.imports_table.get(sym_loc) orelse return null;
    const imports_entry = self.imports.items[imports_index];
    return self.getAtomForSymbol(.{ .sym_index = imports_entry.sym_index, .file = null });
}

fn setSectionName(self: *Coff, header: *coff.SectionHeader, name: []const u8) !void {
    if (name.len <= 8) {
        mem.copy(u8, &header.name, name);
        mem.set(u8, header.name[name.len..], 0);
        return;
    }
    const offset = try self.strtab.insert(self.base.allocator, name);
    const name_offset = fmt.bufPrint(&header.name, "/{d}", .{offset}) catch unreachable;
    mem.set(u8, header.name[name_offset.len..], 0);
}

fn getSectionName(self: *const Coff, header: *const coff.SectionHeader) []const u8 {
    if (header.getName()) |name| {
        return name;
    }
    const offset = header.getNameOffset().?;
    return self.strtab.get(offset).?;
}

fn setSymbolName(self: *Coff, symbol: *coff.Symbol, name: []const u8) !void {
    if (name.len <= 8) {
        mem.copy(u8, &symbol.name, name);
        mem.set(u8, symbol.name[name.len..], 0);
        return;
    }
    const offset = try self.strtab.insert(self.base.allocator, name);
    mem.set(u8, symbol.name[0..4], 0);
    mem.writeIntLittle(u32, symbol.name[4..8], offset);
}

fn logSymAttributes(sym: *const coff.Symbol, buf: *[4]u8) []const u8 {
    mem.set(u8, buf[0..4], '_');
    switch (sym.section_number) {
        .UNDEFINED => {
            buf[3] = 'u';
            switch (sym.storage_class) {
                .EXTERNAL => buf[1] = 'e',
                .WEAK_EXTERNAL => buf[1] = 'w',
                .NULL => {},
                else => unreachable,
            }
        },
        .ABSOLUTE => unreachable, // handle ABSOLUTE
        .DEBUG => unreachable,
        else => {
            buf[0] = 's';
            switch (sym.storage_class) {
                .EXTERNAL => buf[1] = 'e',
                .WEAK_EXTERNAL => buf[1] = 'w',
                .NULL => {},
                else => unreachable,
            }
        },
    }
    return buf[0..];
}

fn logSymtab(self: *Coff) void {
    var buf: [4]u8 = undefined;

    log.debug("symtab:", .{});
    log.debug("  object(null)", .{});
    for (self.locals.items) |*sym, sym_id| {
        const where = if (sym.section_number == .UNDEFINED) "ord" else "sect";
        const def_index: u16 = switch (sym.section_number) {
            .UNDEFINED => 0, // TODO
            .ABSOLUTE => unreachable, // TODO
            .DEBUG => unreachable, // TODO
            else => @enumToInt(sym.section_number),
        };
        log.debug("    %{d}: {?s} @{x} in {s}({d}), {s}", .{
            sym_id,
            self.getSymbolName(.{ .sym_index = @intCast(u32, sym_id), .file = null }),
            sym.value,
            where,
            def_index,
            logSymAttributes(sym, &buf),
        });
    }

    log.debug("globals table:", .{});
    for (self.globals.items) |sym_loc| {
        const sym_name = self.getSymbolName(sym_loc);
        log.debug("  {s} => %{d} in object({?d})", .{ sym_name, sym_loc.sym_index, sym_loc.file });
    }

    log.debug("GOT entries:", .{});
    for (self.got_entries.items) |entry, i| {
        const got_sym = self.getSymbol(.{ .sym_index = entry.sym_index, .file = null });
        const target_sym = self.getSymbol(entry.target);
        if (target_sym.section_number == .UNDEFINED) {
            log.debug("  {d}@{x} => import('{s}')", .{
                i,
                got_sym.value,
                self.getSymbolName(entry.target),
            });
        } else {
            log.debug("  {d}@{x} => local(%{d}) in object({?d}) {s}", .{
                i,
                got_sym.value,
                entry.target.sym_index,
                entry.target.file,
                logSymAttributes(target_sym, &buf),
            });
        }
    }
}

fn logSections(self: *Coff) void {
    log.debug("sections:", .{});
    for (self.sections.items(.header)) |*header| {
        log.debug("  {s}: VM({x}, {x}) FILE({x}, {x})", .{
            self.getSectionName(header),
            header.virtual_address,
            header.virtual_address + header.virtual_size,
            header.pointer_to_raw_data,
            header.pointer_to_raw_data + header.size_of_raw_data,
        });
    }
}
