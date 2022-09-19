const Atom = @This();

const std = @import("std");
const coff = std.coff;
const log = std.log.scoped(.link);

const Coff = @import("../Coff.zig");
const Reloc = Coff.Reloc;
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
size: u32,

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

/// Returns symbol referencing this atom.
pub fn getSymbol(self: Atom, coff_file: *const Coff) *const coff.Symbol {
    return coff_file.getSymbol(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

/// Returns pointer-to-symbol referencing this atom.
pub fn getSymbolPtr(self: Atom, coff_file: *Coff) *coff.Symbol {
    return coff_file.getSymbolPtr(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    return .{ .sym_index = self.sym_index, .file = self.file };
}

/// Returns the name of this atom.
pub fn getName(self: Atom, coff_file: *const Coff) []const u8 {
    return coff_file.getSymbolName(.{
        .sym_index = self.sym_index,
        .file = self.file,
    });
}

/// Returns how much room there is to grow in virtual address space.
pub fn capacity(self: Atom, coff_file: *const Coff) u32 {
    const self_sym = self.getSymbol(coff_file);
    if (self.next) |next| {
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
    const next = self.next orelse return false;
    const self_sym = self.getSymbol(coff_file);
    const next_sym = next.getSymbol(coff_file);
    const cap = next_sym.value - self_sym.value;
    const ideal_cap = Coff.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= Coff.min_text_capacity;
}

pub fn addRelocation(self: *Atom, coff_file: *Coff, reloc: Reloc) !void {
    const gpa = coff_file.base.allocator;
    log.debug("  (adding reloc of type {s} to target %{d})", .{ @tagName(reloc.@"type"), reloc.target.sym_index });
    const gop = try coff_file.relocs.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

pub fn addBaseRelocation(self: *Atom, coff_file: *Coff, offset: u32) !void {
    const gpa = coff_file.base.allocator;
    log.debug("  (adding base relocation at offset 0x{x} in %{d})", .{ offset, self.sym_index });
    const gop = try coff_file.base_relocs.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}
