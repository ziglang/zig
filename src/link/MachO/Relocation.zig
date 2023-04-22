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
    /// RIP-relative displacement to GOT pointer to TLV thunk
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

/// Returns true if and only if the reloc is dirty AND the target address is available.
pub fn isResolvable(self: Relocation, macho_file: *MachO) bool {
    _ = self.getTargetAtomIndex(macho_file) orelse return false;
    return self.dirty;
}

pub fn getTargetAtomIndex(self: Relocation, macho_file: *MachO) ?Atom.Index {
    return switch (self.type) {
        .got, .got_page, .got_pageoff => macho_file.got_table.getAtomIndex(macho_file, self.target),
        .tlv => {
            const thunk_atom_index = macho_file.tlv_table.getAtomIndex(macho_file, self.target) orelse
                return null;
            const thunk_atom = macho_file.getAtom(thunk_atom_index);
            return macho_file.got_table.getAtomIndex(macho_file, thunk_atom.getSymbolWithLoc());
        },
        .branch => if (macho_file.stubs_table.getAtomIndex(macho_file, self.target)) |index|
            index
        else
            macho_file.getAtomIndexForSymbol(self.target),
        else => macho_file.getAtomIndexForSymbol(self.target),
    };
}

pub fn resolve(self: Relocation, macho_file: *MachO, atom_index: Atom.Index, code: []u8) void {
    const arch = macho_file.base.options.target.cpu.arch;
    const atom = macho_file.getAtom(atom_index);
    const source_sym = atom.getSymbol(macho_file);
    const source_addr = source_sym.n_value + self.offset;

    const target_atom_index = self.getTargetAtomIndex(macho_file).?; // Oops, you didn't check if the relocation can be resolved with isResolvable().
    const target_atom = macho_file.getAtom(target_atom_index);

    const target_addr: i64 = switch (self.type) {
        .tlv_initializer => blk: {
            assert(self.addend == 0); // Addend here makes no sense.
            const header = macho_file.sections.items(.header)[macho_file.thread_data_section_index.?];
            const target_sym = target_atom.getSymbol(macho_file);
            break :blk @intCast(i64, target_sym.n_value - header.addr);
        },
        else => @intCast(i64, target_atom.getSymbol(macho_file).n_value) + self.addend,
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
                @intCast(i64, target_addr) - @intCast(i64, source_addr),
            ) orelse unreachable; // TODO codegen should never allow for jump larger than i28 displacement
            var inst = aarch64.Instruction{
                .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.unconditional_branch_immediate,
                ), buffer[0..4]),
            };
            inst.unconditional_branch_immediate.imm26 = @truncate(u26, @bitCast(u28, displacement >> 2));
            mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
        },
        .page, .got_page => {
            const source_page = @intCast(i32, source_addr >> 12);
            const target_page = @intCast(i32, target_addr >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), buffer[0..4]),
            };
            inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
            inst.pc_relative_address.immlo = @truncate(u2, pages);
            mem.writeIntLittle(u32, buffer[0..4], inst.toU32());
        },
        .pageoff, .got_pageoff => {
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
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
            2 => mem.writeIntLittle(u32, buffer[0..4], @truncate(u32, @bitCast(u64, target_addr))),
            3 => mem.writeIntLittle(u64, buffer[0..8], @bitCast(u64, target_addr)),
            else => unreachable,
        },
        .got, .signed, .tlv => unreachable, // Invalid target architecture.
    }
}

fn resolveX8664(self: Relocation, source_addr: u64, target_addr: i64, code: []u8) void {
    switch (self.type) {
        .branch, .got, .tlv, .signed => {
            const displacement = @intCast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4);
            mem.writeIntLittle(u32, code[self.offset..][0..4], @bitCast(u32, displacement));
        },
        .tlv_initializer, .unsigned => {
            switch (self.length) {
                2 => {
                    mem.writeIntLittle(u32, code[self.offset..][0..4], @truncate(u32, @bitCast(u64, target_addr)));
                },
                3 => {
                    mem.writeIntLittle(u64, code[self.offset..][0..8], @bitCast(u64, target_addr));
                },
                else => unreachable,
            }
        },
        .got_page, .got_pageoff, .page, .pageoff => unreachable, // Invalid target architecture.
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
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
