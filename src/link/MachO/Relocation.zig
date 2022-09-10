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

pub const Table = std.AutoHashMapUnmanaged(*Atom, std.ArrayListUnmanaged(Relocation));

/// Offset within the atom's code buffer.
/// Note relocation size can be inferred by relocation's kind.
offset: u32,
target: SymbolWithLoc,
addend: i64,
pcrel: bool,
length: u2,
@"type": u4,
dirty: bool = true,

pub fn getTargetAtom(self: Relocation, macho_file: *MachO) ?*Atom {
    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, self.@"type")) {
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => return macho_file.getGotAtomForSymbol(self.target).?,
            else => {},
        },
        .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, self.@"type")) {
            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => return macho_file.getGotAtomForSymbol(self.target).?,
            else => {},
        },
        else => unreachable,
    }
    if (macho_file.getStubsAtomForSymbol(self.target)) |stubs_atom| return stubs_atom;
    if (macho_file.getTlvPtrAtomForSymbol(self.target)) |tlv_ptr_atom| return tlv_ptr_atom;
    return macho_file.getAtomForSymbol(self.target);
}

pub fn resolve(self: Relocation, atom: *Atom, macho_file: *MachO, code: []u8) !void {
    const arch = macho_file.base.options.target.cpu.arch;
    const source_sym = atom.getSymbol(macho_file);
    const source_addr = source_sym.n_value + self.offset;

    const target_atom = self.getTargetAtom(macho_file) orelse return;
    const target_addr = target_atom.getSymbol(macho_file).n_value + self.addend;

    log.debug("  ({x}: [() => 0x{x} ({s})) ({s})", .{
        source_addr,
        target_addr,
        macho_file.getSymbolName(self.target),
        switch (arch) {
            .aarch64 => @tagName(@intToEnum(macho.reloc_type_arm64, self.@"type")),
            .x86_64 => @tagName(@intToEnum(macho.reloc_type_x86_64, self.@"type")),
            else => unreachable,
        },
    });

    switch (arch) {
        .aarch64 => return self.resolveAarch64(source_addr, target_addr, macho_file, code),
        .x86_64 => return self.resolveX8664(source_addr, target_addr, code),
        else => unreachable,
    }
}

fn resolveAarch64(self: Relocation, source_addr: u64, target_addr: u64, macho_file: *MachO, code: []u8) !void {
    const rel_type = @intToEnum(macho.reloc_type_arm64, self.@"type");
    switch (rel_type) {
        .ARM64_RELOC_BRANCH26 => {
            const displacement = math.cast(i28, @intCast(i64, target_addr) - @intCast(i64, source_addr)) orelse {
                log.err("jump too big to encode as i28 displacement value", .{});
                log.err("  (target - source) = displacement => 0x{x} - 0x{x} = 0x{x}", .{
                    target_addr,
                    source_addr,
                    @intCast(i64, target_addr) - @intCast(i64, source_addr),
                });
                log.err("  TODO implement branch islands to extend jump distance for arm64", .{});
                return error.TODOImplementBranchIslands;
            };
            var inst = aarch64.Instruction{
                .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.unconditional_branch_immediate,
                ), code),
            };
            inst.unconditional_branch_immediate.imm26 = @truncate(u26, @bitCast(u28, displacement >> 2));
            mem.writeIntLittle(u32, code, inst.toU32());
        },
        .ARM64_RELOC_PAGE21,
        .ARM64_RELOC_GOT_LOAD_PAGE21,
        .ARM64_RELOC_TLVP_LOAD_PAGE21,
        => {
            const source_page = @intCast(i32, source_addr >> 12);
            const target_page = @intCast(i32, target_addr >> 12);
            const pages = @bitCast(u21, @intCast(i21, target_page - source_page));
            var inst = aarch64.Instruction{
                .pc_relative_address = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.pc_relative_address,
                ), code),
            };
            inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
            inst.pc_relative_address.immlo = @truncate(u2, pages);
            mem.writeIntLittle(u32, code, inst.toU32());
        },
        .ARM64_RELOC_PAGEOFF12 => {
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
            if (isArithmeticOp(code)) {
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), code),
                };
                inst.add_subtract_immediate.imm12 = narrowed;
                mem.writeIntLittle(u32, code, inst.toU32());
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), code),
                };
                const offset: u12 = blk: {
                    if (inst.load_store_register.size == 0) {
                        if (inst.load_store_register.v == 1) {
                            // 128-bit SIMD is scaled by 16.
                            break :blk try math.divExact(u12, narrowed, 16);
                        }
                        // Otherwise, 8-bit SIMD or ldrb.
                        break :blk narrowed;
                    } else {
                        const denom: u4 = try math.powi(u4, 2, inst.load_store_register.size);
                        break :blk try math.divExact(u12, narrowed, denom);
                    }
                };
                inst.load_store_register.offset = offset;
                mem.writeIntLittle(u32, code, inst.toU32());
            }
        },
        .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => {
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
            var inst: aarch64.Instruction = .{
                .load_store_register = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.load_store_register,
                ), code),
            };
            const offset = try math.divExact(u12, narrowed, 8);
            inst.load_store_register.offset = offset;
            mem.writeIntLittle(u32, code, inst.toU32());
        },
        .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
            const RegInfo = struct {
                rd: u5,
                rn: u5,
                size: u2,
            };
            const reg_info: RegInfo = blk: {
                if (isArithmeticOp(code)) {
                    const inst = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), code);
                    break :blk .{
                        .rd = inst.rd,
                        .rn = inst.rn,
                        .size = inst.sf,
                    };
                } else {
                    const inst = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), code);
                    break :blk .{
                        .rd = inst.rt,
                        .rn = inst.rn,
                        .size = inst.size,
                    };
                }
            };
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
            var inst = if (macho_file.tlv_ptr_entries_table.contains(self.target)) blk: {
                const offset = try math.divExact(u12, narrowed, 8);
                break :blk aarch64.Instruction{
                    .load_store_register = .{
                        .rt = reg_info.rd,
                        .rn = reg_info.rn,
                        .offset = offset,
                        .opc = 0b01,
                        .op1 = 0b01,
                        .v = 0,
                        .size = reg_info.size,
                    },
                };
            } else aarch64.Instruction{
                .add_subtract_immediate = .{
                    .rd = reg_info.rd,
                    .rn = reg_info.rn,
                    .imm12 = narrowed,
                    .sh = 0,
                    .s = 0,
                    .op = 0,
                    .sf = @truncate(u1, reg_info.size),
                },
            };
            mem.writeIntLittle(u32, code, inst.toU32());
        },
        .ARM64_RELOC_POINTER_TO_GOT => {
            const result = math.cast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr)) orelse
                return error.Overflow;
            mem.writeIntLittle(u32, code, @bitCast(u32, result));
        },
        .ARM64_RELOC_UNSIGNED => {
            switch (self.length) {
                2 => mem.writeIntLittle(u32, code, @truncate(u32, @bitCast(u64, target_addr))),
                3 => mem.writeIntLittle(u64, code, target_addr),
                else => unreachable,
            }
        },
        .ARM64_RELOC_SUBTRACTOR => unreachable,
        .ARM64_RELOC_ADDEND => unreachable,
    }
}

fn resolveX8664(self: Relocation, source_addr: u64, target_addr: u64, code: []u8) !void {
    const rel_type = @intToEnum(macho.reloc_type_x86_64, self.@"type");
    switch (rel_type) {
        .X86_64_RELOC_BRANCH,
        .X86_64_RELOC_GOT,
        .X86_64_RELOC_GOT_LOAD,
        .X86_64_RELOC_TLV,
        => {
            const displacement = math.cast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4) orelse
                return error.Overflow;
            mem.writeIntLittle(u32, code, @bitCast(u32, displacement));
        },
        .X86_64_RELOC_SIGNED,
        .X86_64_RELOC_SIGNED_1,
        .X86_64_RELOC_SIGNED_2,
        .X86_64_RELOC_SIGNED_4,
        => {
            const correction: u3 = switch (rel_type) {
                .X86_64_RELOC_SIGNED => 0,
                .X86_64_RELOC_SIGNED_1 => 1,
                .X86_64_RELOC_SIGNED_2 => 2,
                .X86_64_RELOC_SIGNED_4 => 4,
                else => unreachable,
            };
            const displacement = math.cast(i32, target_addr - @intCast(i64, source_addr + correction + 4)) orelse
                return error.Overflow;
            mem.writeIntLittle(u32, code, @bitCast(u32, displacement));
        },
        .X86_64_RELOC_UNSIGNED => {
            switch (self.length) {
                2 => mem.writeIntLittle(u32, code, @truncate(u32, @bitCast(u64, target_addr))),
                3 => mem.writeIntLittle(u64, code, target_addr),
            }
        },
        .X86_64_RELOC_SUBTRACTOR => unreachable,
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}
