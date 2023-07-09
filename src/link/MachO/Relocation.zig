//! Relocation used by the self-hosted backends to instruct the linker where and how to
//! fixup the values when flushing the contents to file and/or memory.

type: Type,
target: SymbolWithLoc,
offset: u32,
addend: i64,
pcrel: bool,
length: u2,
dirty: bool = true,

pub const Type = enum {
    // x86, x86_64
    /// RIP-relative displacement to a GOT pointer
    got,
    /// RIP-relative displacement
    signed,
    /// RIP-relative displacement to a TLV thunk
    tlv,

    // aarch64
    /// PC-relative distance to target page in GOT section
    got_page,
    /// Offset to a GOT pointer relative to the start of a page in GOT section
    got_pageoff,
    /// PC-relative distance to target page in a section
    page,
    /// Offset to a pointer relative to the start of a page in a section
    pageoff,

    // common
    /// PC/RIP-relative displacement B/BL/CALL
    branch,
    /// Absolute pointer value
    unsigned,
    /// Relative offset to TLV initializer
    tlv_initializer,
};

/// Returns true if and only if the reloc can be resolved.
pub fn isResolvable(self: Relocation, macho_file: *MachO) bool {
    _ = self.getTargetBaseAddress(macho_file) orelse return false;
    return true;
}

pub fn isGotIndirection(self: Relocation) bool {
    return switch (self.type) {
        .got, .got_page, .got_pageoff => true,
        else => false,
    };
}

pub fn isStubTrampoline(self: Relocation, macho_file: *MachO) bool {
    return switch (self.type) {
        .branch => macho_file.getSymbol(self.target).undf(),
        else => false,
    };
}

pub fn getTargetBaseAddress(self: Relocation, macho_file: *MachO) ?u64 {
    if (self.isStubTrampoline(macho_file)) {
        const index = macho_file.stub_table.lookup.get(self.target) orelse return null;
        const header = macho_file.sections.items(.header)[macho_file.stubs_section_index.?];
        return header.addr +
            index * @import("stubs.zig").calcStubEntrySize(macho_file.base.options.target.cpu.arch);
    }
    switch (self.type) {
        .got, .got_page, .got_pageoff => {
            const got_index = macho_file.got_table.lookup.get(self.target) orelse return null;
            const header = macho_file.sections.items(.header)[macho_file.got_section_index.?];
            return header.addr + got_index * @sizeOf(u64);
        },
        .tlv => {
            const atom_index = macho_file.tlv_table.get(self.target) orelse return null;
            const atom = macho_file.getAtom(atom_index);
            return atom.getSymbol(macho_file).n_value;
        },
        else => {
            const target_atom_index = macho_file.getAtomIndexForSymbol(self.target) orelse return null;
            const target_atom = macho_file.getAtom(target_atom_index);
            return target_atom.getSymbol(macho_file).n_value;
        },
    }
}

pub fn resolve(self: Relocation, macho_file: *MachO, atom_index: Atom.Index, code: []u8) void {
    const arch = macho_file.base.options.target.cpu.arch;
    const atom = macho_file.getAtom(atom_index);
    const source_sym = atom.getSymbol(macho_file);
    const source_addr = source_sym.n_value + self.offset;

    const target_base_addr = self.getTargetBaseAddress(macho_file).?; // Oops, you didn't check if the relocation can be resolved with isResolvable().
    const target_addr: i64 = switch (self.type) {
        .tlv_initializer => blk: {
            assert(self.addend == 0); // Addend here makes no sense.
            const header = macho_file.sections.items(.header)[macho_file.thread_data_section_index.?];
            break :blk @as(i64, @intCast(target_base_addr - header.addr));
        },
        else => @as(i64, @intCast(target_base_addr)) + self.addend,
    };

    log.debug("  ({x}: [() => 0x{x} ({s})) ({s})", .{
        source_addr,
        target_addr,
        macho_file.getSymbolName(self.target),
        @tagName(self.type),
    });

    switch (arch) {
        .aarch64 => self.resolveAarch64(source_addr, target_addr, code),
        .x86_64 => self.resolveX8664(source_addr, target_addr, code),
        else => unreachable,
    }
}

fn resolveAarch64(self: Relocation, source_addr: u64, target_addr: i64, code: []u8) void {
    var buffer = code[self.offset..];
    switch (self.type) {
        .branch => {
            const displacement = math.cast(
                i28,
                @as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr)),
            ) orelse unreachable; // TODO codegen should never allow for jump larger than i28 displacement
            var inst = aarch64.Instruction{
                .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.unconditional_branch_immediate,
                ), buffer[0..4]),
            };
            inst.unconditional_branch_immediate.imm26 = @as(u26, @truncate(@as(u28, @bitCast(displacement >> 2))));
            mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
        },
        .page, .got_page => {
            const source_page = @as(i32, @intCast(source_addr >> 12));
            const target_page = @as(i32, @intCast(target_addr >> 12));
            const pages = @as(u21, @bitCast(@as(i21, @intCast(target_page - source_page))));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), buffer[0..4]),
            };
            inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
            inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
            mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
        },
        .pageoff, .got_pageoff => {
            const narrowed = @as(u12, @truncate(@as(u64, @intCast(target_addr))));
            if (isArithmeticOp(buffer[0..4])) {
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), buffer[0..4]),
                };
                inst.add_subtract_immediate.imm12 = narrowed;
                mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), buffer[0..4]),
                };
                const offset: u12 = blk: {
                    if (inst.load_store_register.size == 0) {
                        if (inst.load_store_register.v == 1) {
                            // 128-bit SIMD is scaled by 16.
                            break :blk @divExact(narrowed, 16);
                        }
                        // Otherwise, 8-bit SIMD or ldrb.
                        break :blk narrowed;
                    } else {
                        const denom: u4 = math.powi(u4, 2, inst.load_store_register.size) catch unreachable;
                        break :blk @divExact(narrowed, denom);
                    }
                };
                inst.load_store_register.offset = offset;
                mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
            }
        },
        .tlv_initializer, .unsigned => switch (self.length) {
            2 => mem.writeIntLittle(u32, buffer[0..4], @as(u32, @truncate(@as(u64, @bitCast(target_addr))))),
            3 => mem.writeIntLittle(u64, buffer[0..8], @as(u64, @bitCast(target_addr))),
            else => unreachable,
        },
        .got, .signed, .tlv => unreachable, // Invalid target architecture.
    }
}

fn resolveX8664(self: Relocation, source_addr: u64, target_addr: i64, code: []u8) void {
    switch (self.type) {
        .branch, .got, .tlv, .signed => {
            const displacement = @as(i32, @intCast(@as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr)) - 4));
            mem.writeIntLittle(u32, code[self.offset..][0..4], @as(u32, @bitCast(displacement)));
        },
        .tlv_initializer, .unsigned => {
            switch (self.length) {
                2 => {
                    mem.writeIntLittle(u32, code[self.offset..][0..4], @as(u32, @truncate(@as(u64, @bitCast(target_addr)))));
                },
                3 => {
                    mem.writeIntLittle(u64, code[self.offset..][0..8], @as(u64, @bitCast(target_addr)));
                },
                else => unreachable,
            }
        },
        .got_page, .got_pageoff, .page, .pageoff => unreachable, // Invalid target architecture.
    }
}

pub inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @as(u5, @truncate(inst[3]));
    return ((group_decode >> 2) == 4);
}

pub fn calcPcRelativeDisplacementX86(source_addr: u64, target_addr: u64, correction: u3) error{Overflow}!i32 {
    const disp = @as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr + 4 + correction));
    return math.cast(i32, disp) orelse error.Overflow;
}

pub fn calcPcRelativeDisplacementArm64(source_addr: u64, target_addr: u64) error{Overflow}!i28 {
    const disp = @as(i64, @intCast(target_addr)) - @as(i64, @intCast(source_addr));
    return math.cast(i28, disp) orelse error.Overflow;
}

pub fn calcNumberOfPages(source_addr: u64, target_addr: u64) i21 {
    const source_page = @as(i32, @intCast(source_addr >> 12));
    const target_page = @as(i32, @intCast(target_addr >> 12));
    const pages = @as(i21, @intCast(target_page - source_page));
    return pages;
}

pub const PageOffsetInstKind = enum {
    arithmetic,
    load_store_8,
    load_store_16,
    load_store_32,
    load_store_64,
    load_store_128,
};

pub fn calcPageOffset(target_addr: u64, kind: PageOffsetInstKind) !u12 {
    const narrowed = @as(u12, @truncate(target_addr));
    return switch (kind) {
        .arithmetic, .load_store_8 => narrowed,
        .load_store_16 => try math.divExact(u12, narrowed, 2),
        .load_store_32 => try math.divExact(u12, narrowed, 4),
        .load_store_64 => try math.divExact(u12, narrowed, 8),
        .load_store_128 => try math.divExact(u12, narrowed, 16),
    };
}

const Relocation = @This();

const std = @import("std");
const aarch64 = @import("../../arch/aarch64/bits.zig");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const Atom = @import("Atom.zig");
const MachO = @import("../MachO.zig");
const SymbolWithLoc = MachO.SymbolWithLoc;
