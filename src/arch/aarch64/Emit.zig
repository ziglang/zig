//! This file contains the functionality for lowering AArch64 MIR into
//! machine code

const Emit = @This();
const std = @import("std");
const math = std.math;
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const link = @import("../../link.zig");
const assert = std.debug.assert;
const Instruction = bits.Instruction;
const Register = bits.Register;

mir: Mir,
bin_file: *link.File,
target: *const std.Target,
code: *std.ArrayList(u8),

pub fn emitMir(
    emit: *Emit,
) !void {
    const mir_tags = emit.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            .add_immediate => try emit.mirAddSubtractImmediate(inst),
            .sub_immediate => try emit.mirAddSubtractImmediate(inst),

            .b => try emit.mirBranch(inst),
            .bl => try emit.mirBranch(inst),

            .blr => try emit.mirUnconditionalBranchRegister(inst),
            .ret => try emit.mirUnconditionalBranchRegister(inst),

            .brk => try emit.mirExceptionGeneration(inst),
            .svc => try emit.mirExceptionGeneration(inst),

            .call_extern => try emit.mirCallExtern(inst),

            .load_memory => try emit.mirLoadMemory(inst),

            .ldp => try emit.mirLoadStoreRegisterPair(inst),
            .stp => try emit.mirLoadStoreRegisterPair(inst),

            .ldr => try emit.mirLoadStoreRegister(inst),
            .ldrb => try emit.mirLoadStoreRegister(inst),
            .ldrh => try emit.mirLoadStoreRegister(inst),
            .str => try emit.mirLoadStoreRegister(inst),
            .strb => try emit.mirLoadStoreRegister(inst),
            .strh => try emit.mirLoadStoreRegister(inst),

            .mov_register => try emit.mirMoveRegister(inst),
            .mov_to_from_sp => try emit.mirMoveRegister(inst),

            .movk => try emit.mirMoveWideImmediate(inst),
            .movz => try emit.mirMoveWideImmediate(inst),

            .nop => try emit.mirNop(),
        }
    }
}

fn writeInstruction(emit: *Emit, instruction: Instruction) !void {
    const endian = emit.target.cpu.arch.endian();
    std.mem.writeInt(u32, try emit.code.addManyAsArray(4), instruction.toU32(), endian);
}

fn moveImmediate(emit: *Emit, reg: Register, imm64: u64) !void {
    try emit.writeInstruction(Instruction.movz(reg, @truncate(u16, imm64), 0));

    if (imm64 > math.maxInt(u16)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 16), 16));
    }
    if (imm64 > math.maxInt(u32)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 32), 32));
    }
    if (imm64 > math.maxInt(u48)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 48), 48));
    }
}

fn mirAddSubtractImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr_imm12_sh = emit.mir.instructions.items(.data)[inst].rr_imm12_sh;

    switch (tag) {
        .add_immediate => try emit.writeInstruction(Instruction.add(
            rr_imm12_sh.rd,
            rr_imm12_sh.rn,
            rr_imm12_sh.imm12,
            rr_imm12_sh.sh == 1,
        )),
        .sub_immediate => try emit.writeInstruction(Instruction.sub(
            rr_imm12_sh.rd,
            rr_imm12_sh.rn,
            rr_imm12_sh.imm12,
            rr_imm12_sh.sh == 1,
        )),
        else => unreachable,
    }
}

fn mirBranch(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const target_inst = emit.mir.instructions.items(.data)[inst].inst;
    _ = tag;
    _ = target_inst;

    switch (tag) {
        .b => @panic("Implement mirBranch"),
        .bl => @panic("Implement mirBranch"),
        else => unreachable,
    }
}

fn mirUnconditionalBranchRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const reg = emit.mir.instructions.items(.data)[inst].reg;

    switch (tag) {
        .blr => try emit.writeInstruction(Instruction.blr(reg)),
        .ret => try emit.writeInstruction(Instruction.ret(reg)),
        else => unreachable,
    }
}

fn mirExceptionGeneration(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const imm16 = emit.mir.instructions.items(.data)[inst].imm16;

    switch (tag) {
        .brk => try emit.writeInstruction(Instruction.brk(imm16)),
        .svc => try emit.writeInstruction(Instruction.svc(imm16)),
        else => unreachable,
    }
}

fn mirCallExtern(emit: *Emit, inst: Mir.Inst.Index) !void {
    assert(emit.mir.instructions.items(.tag)[inst] == .call_extern);
    const n_strx = emit.mir.instructions.items(.data)[inst].extern_fn;

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        const offset = blk: {
            const offset = @intCast(u32, emit.code.items.len);
            // bl
            try emit.writeInstruction(Instruction.bl(0));
            break :blk offset;
        };
        // Add relocation to the decl.
        try macho_file.active_decl.?.link.macho.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .global = n_strx },
            .addend = 0,
            .subtractor = null,
            .pcrel = true,
            .length = 2,
            .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_BRANCH26),
        });
    } else {
        @panic("Implement call_extern for linking backends != MachO");
    }
}

fn mirLoadMemory(emit: *Emit, inst: Mir.Inst.Index) !void {
    assert(emit.mir.instructions.items(.tag)[inst] == .load_memory);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const load_memory = emit.mir.extraData(Mir.LoadMemory, payload).data;
    const reg = @intToEnum(Register, load_memory.register);
    const addr = load_memory.addr;

    if (emit.bin_file.options.pie) {
        // PC-relative displacement to the entry in the GOT table.
        // adrp
        const offset = @intCast(u32, emit.code.items.len);
        try emit.writeInstruction(Instruction.adrp(reg, 0));

        // ldr reg, reg, offset
        try emit.writeInstruction(Instruction.ldr(reg, .{
            .register = .{
                .rn = reg,
                .offset = Instruction.LoadStoreOffset.imm(0),
            },
        }));

        if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
            // TODO I think the reloc might be in the wrong place.
            const decl = macho_file.active_decl.?;
            // Page reloc for adrp instruction.
            try decl.link.macho.relocs.append(emit.bin_file.allocator, .{
                .offset = offset,
                .target = .{ .local = addr },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGE21),
            });
            // Pageoff reloc for adrp instruction.
            try decl.link.macho.relocs.append(emit.bin_file.allocator, .{
                .offset = offset + 4,
                .target = .{ .local = addr },
                .addend = 0,
                .subtractor = null,
                .pcrel = false,
                .length = 2,
                .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGEOFF12),
            });
        } else {
            return @panic("TODO implement load_memory for PIE GOT indirection on this platform");
        }
    } else {
        // The value is in memory at a hard-coded address.
        // If the type is a pointer, it means the pointer address is at this memory location.
        try emit.moveImmediate(reg, addr);
        try emit.writeInstruction(Instruction.ldr(
            reg,
            .{ .register = .{ .rn = reg, .offset = Instruction.LoadStoreOffset.none } },
        ));
    }
}

fn mirLoadStoreRegisterPair(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register_pair = emit.mir.instructions.items(.data)[inst].load_store_register_pair;

    switch (tag) {
        .stp => try emit.writeInstruction(Instruction.stp(
            load_store_register_pair.rt,
            load_store_register_pair.rt2,
            load_store_register_pair.rn,
            load_store_register_pair.offset,
        )),
        .ldp => try emit.writeInstruction(Instruction.ldp(
            load_store_register_pair.rt,
            load_store_register_pair.rt2,
            load_store_register_pair.rn,
            load_store_register_pair.offset,
        )),
        else => unreachable,
    }
}

fn mirLoadStoreRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register = emit.mir.instructions.items(.data)[inst].load_store_register;

    switch (tag) {
        .ldr => try emit.writeInstruction(Instruction.ldr(
            load_store_register.rt,
            .{ .register = .{ .rn = load_store_register.rn, .offset = load_store_register.offset } },
        )),
        .ldrb => try emit.writeInstruction(Instruction.ldrb(
            load_store_register.rt,
            load_store_register.rn,
            .{ .offset = load_store_register.offset },
        )),
        .ldrh => try emit.writeInstruction(Instruction.ldrh(
            load_store_register.rt,
            load_store_register.rn,
            .{ .offset = load_store_register.offset },
        )),
        .str => try emit.writeInstruction(Instruction.str(
            load_store_register.rt,
            load_store_register.rn,
            .{ .offset = load_store_register.offset },
        )),
        .strb => try emit.writeInstruction(Instruction.strb(
            load_store_register.rt,
            load_store_register.rn,
            .{ .offset = load_store_register.offset },
        )),
        .strh => try emit.writeInstruction(Instruction.strh(
            load_store_register.rt,
            load_store_register.rn,
            .{ .offset = load_store_register.offset },
        )),
        else => unreachable,
    }
}

fn mirMoveRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr = emit.mir.instructions.items(.data)[inst].rr;

    switch (tag) {
        .mov_register => try emit.writeInstruction(Instruction.orr(rr.rd, .xzr, rr.rn, Instruction.Shift.none)),
        .mov_to_from_sp => try emit.writeInstruction(Instruction.add(rr.rd, rr.rn, 0, false)),
        else => unreachable,
    }
}

fn mirMoveWideImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_imm16_sh = emit.mir.instructions.items(.data)[inst].r_imm16_sh;

    switch (tag) {
        .movz => try emit.writeInstruction(Instruction.movz(r_imm16_sh.rd, r_imm16_sh.imm16, @as(u6, r_imm16_sh.hw) << 4)),
        .movk => try emit.writeInstruction(Instruction.movk(r_imm16_sh.rd, r_imm16_sh.imm16, @as(u6, r_imm16_sh.hw) << 4)),
        else => unreachable,
    }
}

fn mirNop(emit: *Emit) !void {
    try emit.writeInstruction(Instruction.nop());
}
