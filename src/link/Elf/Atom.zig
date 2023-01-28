const Atom = @This();

const std = @import("std");
const assert = std.debug.assert;
const elf = std.elf;

const Dwarf = @import("../Dwarf.zig");
const Elf = @import("../Elf.zig");

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
local_sym_index: u32,

/// This field is undefined for symbols with size = 0.
offset_table_index: u32,

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `TextBlock`.
prev: ?*Atom,
next: ?*Atom,

dbg_info_atom: Dwarf.Atom,

pub const empty = Atom{
    .local_sym_index = 0,
    .offset_table_index = undefined,
    .prev = null,
    .next = null,
    .dbg_info_atom = undefined,
};

pub fn ensureInitialized(self: *Atom, elf_file: *Elf) !void {
    if (self.getSymbolIndex() != null) return; // Already initialized
    self.local_sym_index = try elf_file.allocateLocalSymbol();
    self.offset_table_index = try elf_file.allocateGotOffset();
    try elf_file.atom_by_index_table.putNoClobber(elf_file.base.allocator, self.local_sym_index, self);
}

pub fn getSymbolIndex(self: Atom) ?u32 {
    if (self.local_sym_index == 0) return null;
    return self.local_sym_index;
}

pub fn getSymbol(self: Atom, elf_file: *Elf) elf.Elf64_Sym {
    const sym_index = self.getSymbolIndex().?;
    return elf_file.local_symbols.items[sym_index];
}

pub fn getSymbolPtr(self: Atom, elf_file: *Elf) *elf.Elf64_Sym {
    const sym_index = self.getSymbolIndex().?;
    return &elf_file.local_symbols.items[sym_index];
}

pub fn getName(self: Atom, elf_file: *Elf) []const u8 {
    const sym = self.getSymbol();
    return elf_file.getString(sym.st_name);
}

pub fn getOffsetTableAddress(self: Atom, elf_file: *Elf) u64 {
    assert(self.getSymbolIndex() != null);
    const target = elf_file.base.options.target;
    const ptr_bits = target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);
    const got = elf_file.program_headers.items[elf_file.phdr_got_index.?];
    return got.p_vaddr + self.offset_table_index * ptr_bytes;
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, elf_file: *Elf) u64 {
    const self_sym = self.getSymbol(elf_file);
    if (self.next) |next| {
        const next_sym = next.getSymbol(elf_file);
        return next_sym.st_value - self_sym.st_value;
    } else {
        // We are the last block. The capacity is limited only by virtual address space.
        return std.math.maxInt(u32) - self_sym.st_value;
    }
}

pub fn freeListEligible(self: Atom, elf_file: *Elf) bool {
    // No need to keep a free list node for the last block.
    const next = self.next orelse return false;
    const self_sym = self.getSymbol(elf_file);
    const next_sym = next.getSymbol(elf_file);
    const cap = next_sym.st_value - self_sym.st_value;
    const ideal_cap = Elf.padToIdeal(self_sym.st_size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Elf.min_text_capacity;
}
