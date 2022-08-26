const Atom = @This();

const std = @import("std");
const coff = std.coff;

const Allocator = std.mem.Allocator;

const Coff = @import("../Coff.zig");
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

/// Used size of the atom
size: u64,

/// Alignment of the atom
alignment: u32,

/// Points to the previous and next neighbors, based on the `text_offset`.
/// This can be used to find, for example, the capacity of this `Atom`.
prev: ?*Atom,
next: ?*Atom,

pub const empty = Atom{
    .sym_index = 0,
    .file = null,
    .size = 0,
    .alignment = 0,
    .prev = null,
    .next = null,
};

pub fn deinit(self: *Atom, gpa: Allocator) void {
    _ = self;
    _ = gpa;
}

pub fn getSymbol(self: Atom, coff_file: *Coff) coff.Symbol {
    return self.getSymbolPtr(coff_file).*;
}

pub fn getSymbolPtr(self: Atom, coff_file: *Coff) *coff.Symbol {
    return coff_file.getSymbolPtr(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    return .{ .sym_index = self.sym_index, .file = self.file };
}

/// Returns how much room there is to grow in virtual address space.
pub fn capacity(self: Atom, coff_file: *Coff) u64 {
    const self_sym = self.getSymbol(coff_file);
    if (self.next) |next| {
        const next_sym = next.getSymbol(coff_file);
        return next_sym.value - self_sym.value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return std.math.maxInt(u64) - self_sym.value;
    }
}

pub fn freeListEligible(self: Atom, coff_file: *Coff) bool {
    // No need to keep a free list node for the last atom.
    const next = self.next orelse return false;
    const self_sym = self.getSymbol(coff_file);
    const next_sym = next.getSymbol(coff_file);
    const cap = next_sym.value - self_sym.value;
    const ideal_cap = Coff.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Coff.min_text_capacity;
}
