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
const Dwarf = @import("../Dwarf.zig");
const MachO = @import("../MachO.zig");
const Relocation = @import("Relocation.zig");
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

/// Alignment of this atom as a power of 2.
/// For instance, alignment of 0 should be read as 2^0 = 1 byte aligned.
alignment: u32,

/// Points to the previous and next neighbours
next: ?*Atom,
prev: ?*Atom,

dbg_info_atom: Dwarf.Atom,

pub const Binding = struct {
    target: SymbolWithLoc,
    offset: u64,
};

pub const SymbolAtOffset = struct {
    sym_index: u32,
    offset: u64,
};

pub const empty = Atom{
    .sym_index = 0,
    .file = null,
    .size = 0,
    .alignment = 0,
    .prev = null,
    .next = null,
    .dbg_info_atom = undefined,
};

pub fn ensureInitialized(self: *Atom, macho_file: *MachO) !void {
    if (self.getSymbolIndex() != null) return; // Already initialized
    self.sym_index = try macho_file.allocateSymbol();
    try macho_file.atom_by_index_table.putNoClobber(macho_file.base.allocator, self.sym_index, self);
}

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
    if (self.next) |next| {
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
    const next = self.next orelse return false;
    const self_sym = self.getSymbol(macho_file);
    const next_sym = next.getSymbol(macho_file);
    const cap = next_sym.n_value - self_sym.n_value;
    const ideal_cap = MachO.padToIdeal(self.size);
    if (cap <= ideal_cap) return false;
    const surplus = cap - ideal_cap;
    return surplus >= MachO.min_text_capacity;
}

pub fn addRelocation(self: *Atom, macho_file: *MachO, reloc: Relocation) !void {
    return self.addRelocations(macho_file, 1, .{reloc});
}

pub fn addRelocations(
    self: *Atom,
    macho_file: *MachO,
    comptime count: comptime_int,
    relocs: [count]Relocation,
) !void {
    const gpa = macho_file.base.allocator;
    const target = macho_file.base.options.target;
    const gop = try macho_file.relocs.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.ensureUnusedCapacity(gpa, count);
    for (relocs) |reloc| {
        log.debug("  (adding reloc of type {s} to target %{d})", .{
            reloc.fmtType(target),
            reloc.target.sym_index,
        });
        gop.value_ptr.appendAssumeCapacity(reloc);
    }
}

pub fn addRebase(self: *Atom, macho_file: *MachO, offset: u32) !void {
    const gpa = macho_file.base.allocator;
    log.debug("  (adding rebase at offset 0x{x} in %{?d})", .{ offset, self.getSymbolIndex() });
    const gop = try macho_file.rebases.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}

pub fn addBinding(self: *Atom, macho_file: *MachO, binding: Binding) !void {
    const gpa = macho_file.base.allocator;
    log.debug("  (adding binding to symbol {s} at offset 0x{x} in %{?d})", .{
        macho_file.getSymbolName(binding.target),
        binding.offset,
        self.getSymbolIndex(),
    });
    const gop = try macho_file.bindings.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, binding);
}

pub fn addLazyBinding(self: *Atom, macho_file: *MachO, binding: Binding) !void {
    const gpa = macho_file.base.allocator;
    log.debug("  (adding lazy binding to symbol {s} at offset 0x{x} in %{?d})", .{
        macho_file.getSymbolName(binding.target),
        binding.offset,
        self.getSymbolIndex(),
    });
    const gop = try macho_file.lazy_bindings.getOrPut(gpa, self);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, binding);
}

pub fn resolveRelocations(self: *Atom, macho_file: *MachO) !void {
    const relocs = macho_file.relocs.get(self) orelse return;
    const source_sym = self.getSymbol(macho_file);
    const source_section = macho_file.sections.get(source_sym.n_sect - 1).header;
    const file_offset = source_section.offset + source_sym.n_value - source_section.addr;

    log.debug("relocating '{s}'", .{self.getName(macho_file)});

    for (relocs.items) |*reloc| {
        if (!reloc.dirty) continue;

        try reloc.resolve(self, macho_file, file_offset);
        reloc.dirty = false;
    }
}
