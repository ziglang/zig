const Atom = @This();

const std = @import("std");

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

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, elf_file: Elf) u64 {
    const self_sym = elf_file.local_symbols.items[self.local_sym_index];
    if (self.next) |next| {
        const next_sym = elf_file.local_symbols.items[next.local_sym_index];
        return next_sym.st_value - self_sym.st_value;
    } else {
        // We are the last block. The capacity is limited only by virtual address space.
        return std.math.maxInt(u32) - self_sym.st_value;
    }
}

pub fn freeListEligible(self: Atom, elf_file: Elf) bool {
    // No need to keep a free list node for the last block.
    const next = self.next orelse return false;
    const self_sym = elf_file.local_symbols.items[self.local_sym_index];
    const next_sym = elf_file.local_symbols.items[next.local_sym_index];
    const cap = next_sym.st_value - self_sym.st_value;
    const ideal_cap = Elf.padToIdeal(self_sym.st_size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Elf.min_text_capacity;
}
