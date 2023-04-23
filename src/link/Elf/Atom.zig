const Atom = @This();

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;

const Elf = @import("../Elf.zig");

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
local_sym_index: u32,

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `TextBlock`.
prev_index: ?Index,
next_index: ?Index,

pub const Index = u32;

pub const Reloc = struct {
    target: u32,
    offset: u64,
    addend: u32,
    prev_vaddr: u64,
};

pub fn getSymbolIndex(self: Atom) ?u32 {
    if (self.local_sym_index == 0) return null;
    return self.local_sym_index;
}

pub fn getSymbol(self: Atom, elf_file: *const Elf) elf.Elf64_Sym {
    return elf_file.getSymbol(self.getSymbolIndex().?);
}

pub fn getSymbolPtr(self: Atom, elf_file: *Elf) *elf.Elf64_Sym {
    return elf_file.getSymbolPtr(self.getSymbolIndex().?);
}

pub fn getName(self: Atom, elf_file: *const Elf) []const u8 {
    return elf_file.getSymbolName(self.getSymbolIndex().?);
}

/// If entry already exists, returns index to it.
/// Otherwise, creates a new entry in the Global Offset Table for this Atom.
pub fn getOrCreateOffsetTableEntry(self: Atom, elf_file: *Elf) !u32 {
    const sym_index = self.getSymbolIndex().?;
    if (elf_file.got_table.lookup.get(sym_index)) |index| return index;
    const index = try elf_file.got_table.allocateEntry(elf_file.base.allocator, sym_index);
    elf_file.got_table_count_dirty = true;
    return index;
}

pub fn getOffsetTableAddress(self: Atom, elf_file: *Elf) u64 {
    const sym_index = self.getSymbolIndex().?;
    const got_entry_index = elf_file.got_table.lookup.get(sym_index).?;
    const target = elf_file.base.options.target;
    const ptr_bits = target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);
    const got = elf_file.program_headers.items[elf_file.phdr_got_index.?];
    return got.p_vaddr + got_entry_index * ptr_bytes;
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, elf_file: *const Elf) u64 {
    const self_sym = self.getSymbol(elf_file);
    if (self.next_index) |next_index| {
        const next = elf_file.getAtom(next_index);
        const next_sym = next.getSymbol(elf_file);
        return next_sym.st_value - self_sym.st_value;
    } else {
        // We are the last block. The capacity is limited only by virtual address space.
        return std.math.maxInt(u32) - self_sym.st_value;
    }
}

pub fn freeListEligible(self: Atom, elf_file: *const Elf) bool {
    // No need to keep a free list node for the last block.
    const next_index = self.next_index orelse return false;
    const next = elf_file.getAtom(next_index);
    const self_sym = self.getSymbol(elf_file);
    const next_sym = next.getSymbol(elf_file);
    const cap = next_sym.st_value - self_sym.st_value;
    const ideal_cap = Elf.padToIdeal(self_sym.st_size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Elf.min_text_capacity;
}

pub fn addRelocation(elf_file: *Elf, atom_index: Index, reloc: Reloc) !void {
    const gpa = elf_file.base.allocator;
    const gop = try elf_file.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn freeRelocations(elf_file: *Elf, atom_index: Index) void {
    var removed_relocs = elf_file.relocs.fetchRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(elf_file.base.allocator);
}
