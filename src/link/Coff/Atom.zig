const Atom = @This();

const std = @import("std");
const coff = std.coff;
const log = std.log.scoped(.link);

const Coff = @import("../Coff.zig");
const Relocation = @import("Relocation.zig");
const SymbolWithLoc = Coff.SymbolWithLoc;

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
sym_index: u32,

/// null means symbol defined by Zig source.
file: ?u32,

/// Size of the atom
size: u32,

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `Atom`.
prev_index: ?Index,
next_index: ?Index,

pub const Index = u32;

pub fn getSymbolIndex(self: Atom) ?u32 {
    if (self.sym_index == 0) return null;
    return self.sym_index;
}

/// Returns symbol referencing this atom.
pub fn getSymbol(self: Atom, coff_file: *const Coff) *const coff.Symbol {
    const sym_index = self.getSymbolIndex().?;
    return coff_file.getSymbol(.{
        .sym_index = sym_index,
        .file = self.file,
    });
}

/// Returns pointer-to-symbol referencing this atom.
pub fn getSymbolPtr(self: Atom, coff_file: *Coff) *coff.Symbol {
    const sym_index = self.getSymbolIndex().?;
    return coff_file.getSymbolPtr(.{
        .sym_index = sym_index,
        .file = self.file,
    });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    const sym_index = self.getSymbolIndex().?;
    return .{ .sym_index = sym_index, .file = self.file };
}

/// Returns the name of this atom.
pub fn getName(self: Atom, coff_file: *const Coff) []const u8 {
    const sym_index = self.getSymbolIndex().?;
    return coff_file.getSymbolName(.{
        .sym_index = sym_index,
        .file = self.file,
    });
}

/// Returns how much room there is to grow in virtual address space.
pub fn capacity(self: Atom, coff_file: *const Coff) u32 {
    const self_sym = self.getSymbol(coff_file);
    if (self.next_index) |next_index| {
        const next = coff_file.getAtom(next_index);
        const next_sym = next.getSymbol(coff_file);
        return next_sym.value - self_sym.value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return std.math.maxInt(u32) - self_sym.value;
    }
}

pub fn freeListEligible(self: Atom, coff_file: *const Coff) bool {
    // No need to keep a free list node for the last atom.
    const next_index = self.next_index orelse return false;
    const next = coff_file.getAtom(next_index);
    const self_sym = self.getSymbol(coff_file);
    const next_sym = next.getSymbol(coff_file);
    const cap = next_sym.value - self_sym.value;
    const ideal_cap = Coff.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Coff.min_text_capacity;
}

pub fn addRelocation(coff_file: *Coff, atom_index: Index, reloc: Relocation) !void {
    const comp = coff_file.base.comp;
    const gpa = comp.gpa;
    log.debug("  (adding reloc of type {s} to target %{d})", .{ @tagName(reloc.type), reloc.target.sym_index });
    const gop = try coff_file.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn addBaseRelocation(coff_file: *Coff, atom_index: Index, offset: u32) !void {
    const comp = coff_file.base.comp;
    const gpa = comp.gpa;
    log.debug("  (adding base relocation at offset 0x{x} in %{d})", .{
        offset,
        coff_file.getAtom(atom_index).getSymbolIndex().?,
    });
    const gop = try coff_file.base_relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}

pub fn freeRelocations(coff_file: *Coff, atom_index: Index) void {
    const comp = coff_file.base.comp;
    const gpa = comp.gpa;
    var removed_relocs = coff_file.relocs.fetchOrderedRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(gpa);
    var removed_base_relocs = coff_file.base_relocs.fetchOrderedRemove(atom_index);
    if (removed_base_relocs) |*base_relocs| base_relocs.value.deinit(gpa);
}
