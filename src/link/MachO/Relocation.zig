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

type: u4,
target: SymbolWithLoc,
offset: u32,
addend: i64,
pcrel: bool,
length: u2,
dirty: bool = true,

pub fn fmtType(self: Relocation, target: std.Target) []const u8 {
    switch (target.cpu.arch) {
        .aarch64 => return @tagName(@intToEnum(macho.reloc_type_arm64, self.type)),
        .x86_64 => return @tagName(@intToEnum(macho.reloc_type_x86_64, self.type)),
        else => unreachable,
    }
}

pub fn getTargetAtomIndex(self: Relocation, macho_file: *MachO) ?Atom.Index {
    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => switch (@intToEnum(macho.reloc_type_arm64, self.type)) {
            .ARM64_RELOC_GOT_LOAD_PAGE21,
            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
            .ARM64_RELOC_POINTER_TO_GOT,
            => return macho_file.getGotAtomIndexForSymbol(self.target),
            else => {},
        },
        .x86_64 => switch (@intToEnum(macho.reloc_type_x86_64, self.type)) {
            .X86_64_RELOC_GOT,
            .X86_64_RELOC_GOT_LOAD,
            => return macho_file.getGotAtomIndexForSymbol(self.target),
            else => {},
        },
        else => unreachable,
    }
    if (macho_file.getStubsAtomIndexForSymbol(self.target)) |stubs_atom| return stubs_atom;
    return macho_file.getAtomIndexForSymbol(self.target);
}

pub fn resolve(self: Relocation, macho_file: *MachO, atom_index: Atom.Index, code: []u8) !void {
    const arch = macho_file.base.options.target.cpu.arch;
    const atom = macho_file.getAtom(atom_index);
    const source_sym = atom.getSymbol(macho_file);
    const source_addr = source_sym.n_value + self.offset;

    const target_atom_index = self.getTargetAtomIndex(macho_file) orelse return;
    const target_atom = macho_file.getAtom(target_atom_index);
    const target_addr = @intCast(i64, target_atom.getSymbol(macho_file).n_value) + self.addend;

    log.debug("  ({x}: [() => 0x{x} ({s})) ({s})", .{
        source_addr,
        target_addr,
        macho_file.getSymbolName(self.target),
        self.fmtType(macho_file.base.options.target),
    });

    switch (arch) {
        .aarch64 => return self.resolveAarch64(source_addr, target_addr, code),
        .x86_64 => return self.resolveX8664(source_addr, target_addr, code),
        else => unreachable,
    }
}

fn resolveAarch64(
    self: Relocation,
    source_addr: u64,
    target_addr: i64,
    code: []u8,
) !void {
    const rel_type = @intToEnum(macho.reloc_type_arm64, self.type);
    if (rel_type == .ARM64_RELOC_UNSIGNED) {
        return switch (self.length) {
            2 => mem.writeIntLittle(u32, code[self.offset..][0..4], @truncate(u32, @bitCast(u64, target_addr))),
            3 => mem.writeIntLittle(u64, code[self.offset..][0..8], @bitCast(u64, target_addr)),
            else => unreachable,
        };
    }

    var buffer = code[self.offset..][0..4];
    switch (rel_type) {
        .ARM64_RELOC_BRANCH26 => {
            const displacement = math.cast(
                i28,
                @intCast(i64, target_addr) - @intCast(i64, source_addr),
            ) orelse unreachable; // TODO codegen should never allow for jump larger than i28 displacement
            var inst = aarch64.Instruction{
                .unconditional_branch_immediate = mem.bytesToValue(meta.TagPayload(
                    aarch64.Instruction,
                    aarch64.Instruction.unconditional_branch_immediate,
                ), buffer),
            };
            inst.unconditional_branch_immediate.imm26 = @truncate(u26, @bitCast(u28, displacement >> 2));
            mem.writeIntLittle(u32, buffer, inst.toU32());
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
                ), buffer),
            };
            inst.pc_relative_address.immhi = @truncate(u19, pages >> 2);
            inst.pc_relative_address.immlo = @truncate(u2, pages);
            mem.writeIntLittle(u32, buffer, inst.toU32());
        },
        .ARM64_RELOC_PAGEOFF12,
        .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
        => {
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
            if (isArithmeticOp(buffer)) {
                var inst = aarch64.Instruction{
                    .add_subtract_immediate = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), buffer),
                };
                inst.add_subtract_immediate.imm12 = narrowed;
                mem.writeIntLittle(u32, buffer, inst.toU32());
            } else {
                var inst = aarch64.Instruction{
                    .load_store_register = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), buffer),
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
                mem.writeIntLittle(u32, buffer, inst.toU32());
            }
        },
        .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
            const RegInfo = struct {
                rd: u5,
                rn: u5,
                size: u2,
            };
            const reg_info: RegInfo = blk: {
                if (isArithmeticOp(buffer)) {
                    const inst = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.add_subtract_immediate,
                    ), buffer);
                    break :blk .{
                        .rd = inst.rd,
                        .rn = inst.rn,
                        .size = inst.sf,
                    };
                } else {
                    const inst = mem.bytesToValue(meta.TagPayload(
                        aarch64.Instruction,
                        aarch64.Instruction.load_store_register,
                    ), buffer);
                    break :blk .{
                        .rd = inst.rt,
                        .rn = inst.rn,
                        .size = inst.size,
                    };
                }
            };
            const narrowed = @truncate(u12, @intCast(u64, target_addr));
            var inst = aarch64.Instruction{
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
            mem.writeIntLittle(u32, buffer, inst.toU32());
        },
        .ARM64_RELOC_POINTER_TO_GOT => {
            const result = @intCast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr));
            mem.writeIntLittle(i32, buffer, result);
        },
        .ARM64_RELOC_SUBTRACTOR => unreachable,
        .ARM64_RELOC_ADDEND => unreachable,
        .ARM64_RELOC_UNSIGNED => unreachable,
    }
}

fn resolveX8664(
    self: Relocation,
    source_addr: u64,
    target_addr: i64,
    code: []u8,
) !void {
    const rel_type = @intToEnum(macho.reloc_type_x86_64, self.type);
    switch (rel_type) {
        .X86_64_RELOC_BRANCH,
        .X86_64_RELOC_GOT,
        .X86_64_RELOC_GOT_LOAD,
        .X86_64_RELOC_TLV,
        => {
            const displacement = @intCast(i32, @intCast(i64, target_addr) - @intCast(i64, source_addr) - 4);
            mem.writeIntLittle(u32, code[self.offset..][0..4], @bitCast(u32, displacement));
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
            const displacement = @intCast(i32, target_addr - @intCast(i64, source_addr + correction + 4));
            mem.writeIntLittle(u32, code[self.offset..][0..4], @bitCast(u32, displacement));
        },
        .X86_64_RELOC_UNSIGNED => {
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
        .X86_64_RELOC_SUBTRACTOR => unreachable,
    }
}

inline fn isArithmeticOp(inst: *const [4]u8) bool {
    const group_decode = @truncate(u5, inst[3]);
    return ((group_decode >> 2) == 4);
}
