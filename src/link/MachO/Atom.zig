const Atom = @This();

const std = @import("std");
const build_options = @import("build_options");
const aarch64 = @import("../../arch/aarch64/bits.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const MachO = @import("../MachO.zig");
pub const Relocation = @import("Relocation.zig");
const SymbolWithLoc = MachO.SymbolWithLoc;

/// Each decl always gets a local symbol with the fully qualified name.
/// The vaddr and size are found here directly.
/// The file offset is found by computing the vaddr offset from the section vaddr
/// the symbol references, and adding that to the file offset of the section.
/// If this field is 0, it means the codegen size = 0 and there is no symbol or
/// offset table entry.
sym_index: u32,

/// null means symbol defined by Zig source.
file: ?u32,

/// Size and alignment of this atom
/// Unlike in Elf, we need to store the size of this symbol as part of
/// the atom since macho.nlist_64 lacks this information.
size: u64,

/// Points to the previous and next neighbours
/// TODO use the same trick as with symbols: reserve index 0 as null atom
next_index: ?Index,
prev_index: ?Index,

pub const Index = u32;

pub const Binding = struct {
    target: SymbolWithLoc,
    offset: u64,
};

pub const SymbolAtOffset = struct {
    sym_index: u32,
    offset: u64,
};

pub fn getSymbolIndex(self: Atom) ?u32 {
    if (self.sym_index == 0) return null;
    return self.sym_index;
}

/// Returns symbol referencing this atom.
pub fn getSymbol(self: Atom, macho_file: *MachO) macho.nlist_64 {
    return self.getSymbolPtr(macho_file).*;
}

/// Returns pointer-to-symbol referencing this atom.
pub fn getSymbolPtr(self: Atom, macho_file: *MachO) *macho.nlist_64 {
    const sym_index = self.getSymbolIndex().?;
    return macho_file.getSymbolPtr(.{
        .sym_index = sym_index,
        .file = self.file,
    });
}

pub fn getSymbolWithLoc(self: Atom) SymbolWithLoc {
    const sym_index = self.getSymbolIndex().?;
    return .{ .sym_index = sym_index, .file = self.file };
}

/// Returns the name of this atom.
pub fn getName(self: Atom, macho_file: *MachO) []const u8 {
    const sym_index = self.getSymbolIndex().?;
    return macho_file.getSymbolName(.{
        .sym_index = sym_index,
        .file = self.file,
    });
}

/// Returns how much room there is to grow in virtual address space.
/// File offset relocation happens transparently, so it is not included in
/// this calculation.
pub fn capacity(self: Atom, macho_file: *MachO) u64 {
    const self_sym = self.getSymbol(macho_file);
    if (self.next_index) |next_index| {
        const next = macho_file.getAtom(next_index);
        const next_sym = next.getSymbol(macho_file);
        return next_sym.n_value - self_sym.n_value;
    } else {
        // We are the last atom.
        // The capacity is limited only by virtual address space.
        return macho_file.allocatedVirtualSize(self_sym.n_value);
    }
}

pub fn freeListEligible(self: Atom, macho_file: *MachO) bool {
    // No need to keep a free list node for the last atom.
    const next_index = self.next_index orelse return false;
    const next = macho_file.getAtom(next_index);
    const self_sym = self.getSymbol(macho_file);
    const next_sym = next.getSymbol(macho_file);
    const cap = next_sym.n_value - self_sym.n_value;
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

pub fn addRelocation(macho_file: *MachO, atom_index: Index, reloc: Relocation) !void {
    return addRelocations(macho_file, atom_index, &[_]Relocation{reloc});
}

pub fn addRelocations(macho_file: *MachO, atom_index: Index, relocs: []Relocation) !void {
    const gpa = macho_file.base.allocator;
    const gop = try macho_file.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.ensureUnusedCapacity(gpa, relocs.len);
    for (relocs) |reloc| {
        log.debug("  (adding reloc of type {s} to target %{d})", .{
            @tagName(reloc.type),
            reloc.target.sym_index,
        });
        gop.value_ptr.appendAssumeCapacity(reloc);
    }
}

pub fn addRebase(macho_file: *MachO, atom_index: Index, offset: u32) !void {
    const gpa = macho_file.base.allocator;
    const atom = macho_file.getAtom(atom_index);
    log.debug("  (adding rebase at offset 0x{x} in %{?d})", .{ offset, atom.getSymbolIndex() });
    const gop = try macho_file.rebases.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}

pub fn addBinding(macho_file: *MachO, atom_index: Index, binding: Binding) !void {
    const gpa = macho_file.base.allocator;
    const atom = macho_file.getAtom(atom_index);
    log.debug("  (adding binding to symbol {s} at offset 0x{x} in %{?d})", .{
        macho_file.getSymbolName(binding.target),
        binding.offset,
        atom.getSymbolIndex(),
    });
    const gop = try macho_file.bindings.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, binding);
}

pub fn resolveRelocations(
    macho_file: *MachO,
    atom_index: Index,
    relocs: []*const Relocation,
    code: []u8,
) void {
    log.debug("relocating '{s}'", .{macho_file.getAtom(atom_index).getName(macho_file)});
    for (relocs) |reloc| {
        reloc.resolve(macho_file, atom_index, code);
    }
}

pub fn freeRelocations(macho_file: *MachO, atom_index: Index) void {
    const gpa = macho_file.base.allocator;
    var removed_relocs = macho_file.relocs.fetchOrderedRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(gpa);
    var removed_rebases = macho_file.rebases.fetchOrderedRemove(atom_index);
    if (removed_rebases) |*rebases| rebases.value.deinit(gpa);
    var removed_bindings = macho_file.bindings.fetchOrderedRemove(atom_index);
    if (removed_bindings) |*bindings| bindings.value.deinit(gpa);
}
