tag: enum { @"extern", local },
offset: u32,
target: u32,
addend: i64,
type: Type,
meta: packed struct {
    pcrel: bool,
    has_subtractor: bool,
    length: u2,
    symbolnum: u24,
},

pub fn getTargetSymbol(rel: Relocation, macho_file: *MachO) *Symbol {
    assert(rel.tag == .@"extern");
    return macho_file.getSymbol(rel.target);
}

pub fn getTargetAtom(rel: Relocation, macho_file: *MachO) *Atom {
    assert(rel.tag == .local);
    return macho_file.getAtom(rel.target).?;
}

pub fn getTargetAddress(rel: Relocation, macho_file: *MachO) u64 {
    return switch (rel.tag) {
        .local => rel.getTargetAtom(macho_file).getAddress(macho_file),
        .@"extern" => rel.getTargetSymbol(macho_file).getAddress(.{}, macho_file),
    };
}

pub fn getGotTargetAddress(rel: Relocation, macho_file: *MachO) u64 {
    return switch (rel.tag) {
        .local => 0,
        .@"extern" => rel.getTargetSymbol(macho_file).getGotAddress(macho_file),
    };
}

pub fn getZigGotTargetAddress(rel: Relocation, macho_file: *MachO) u64 {
    return switch (rel.tag) {
        .local => 0,
        .@"extern" => rel.getTargetSymbol(macho_file).getZigGotAddress(macho_file),
    };
}

pub fn getRelocAddend(rel: Relocation, cpu_arch: std.Target.Cpu.Arch) i64 {
    const addend: i64 = switch (rel.type) {
        .signed => 0,
        .signed1 => -1,
        .signed2 => -2,
        .signed4 => -4,
        else => 0,
    };
    return switch (cpu_arch) {
        .x86_64 => if (rel.meta.pcrel) addend - 4 else addend,
        else => addend,
    };
}

pub fn lessThan(ctx: void, lhs: Relocation, rhs: Relocation) bool {
    _ = ctx;
    return lhs.offset < rhs.offset;
}

pub const Type = enum {
    // x86_64
    /// RIP-relative displacement (X86_64_RELOC_SIGNED)
    signed,
    /// RIP-relative displacement (X86_64_RELOC_SIGNED_1)
    signed1,
    /// RIP-relative displacement (X86_64_RELOC_SIGNED_2)
    signed2,
    /// RIP-relative displacement (X86_64_RELOC_SIGNED_4)
    signed4,
    /// RIP-relative GOT load (X86_64_RELOC_GOT_LOAD)
    got_load,
    /// RIP-relative TLV load (X86_64_RELOC_TLV)
    tlv,
    /// Zig-specific __got_zig indirection
    zig_got_load,

    // arm64
    /// PC-relative load (distance to page, ARM64_RELOC_PAGE21)
    page,
    /// Non-PC-relative offset to symbol (ARM64_RELOC_PAGEOFF12)
    pageoff,
    /// PC-relative GOT load (distance to page, ARM64_RELOC_GOT_LOAD_PAGE21)
    got_load_page,
    /// Non-PC-relative offset to GOT slot (ARM64_RELOC_GOT_LOAD_PAGEOFF12)
    got_load_pageoff,
    /// PC-relative TLV load (distance to page, ARM64_RELOC_TLVP_LOAD_PAGE21)
    tlvp_page,
    /// Non-PC-relative offset to TLV slot (ARM64_RELOC_TLVP_LOAD_PAGEOFF12)
    tlvp_pageoff,

    // common
    /// PC-relative call/bl/b (X86_64_RELOC_BRANCH or ARM64_RELOC_BRANCH26)
    branch,
    /// PC-relative displacement to GOT pointer (X86_64_RELOC_GOT or ARM64_RELOC_POINTER_TO_GOT)
    got,
    /// Absolute subtractor value (X86_64_RELOC_SUBTRACTOR or ARM64_RELOC_SUBTRACTOR)
    subtractor,
    /// Absolute relocation (X86_64_RELOC_UNSIGNED or ARM64_RELOC_UNSIGNED)
    unsigned,
};

const assert = std.debug.assert;
const macho = std.macho;
const math = std.math;
const std = @import("std");

const Atom = @import("Atom.zig");
const MachO = @import("../MachO.zig");
const Relocation = @This();
const Symbol = @import("Symbol.zig");
