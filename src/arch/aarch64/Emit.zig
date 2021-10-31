//! This file contains the functionality for lowering AArch64 MIR into
//! machine code

const Emit = @This();
const std = @import("std");
const math = std.math;
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const link = @import("../../link.zig");
const assert = std.debug.assert;
const DW = std.dwarf;
const leb128 = std.leb;
const Instruction = bits.Instruction;
const Register = bits.Register;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

mir: Mir,
bin_file: *link.File,
debug_output: DebugInfoOutput,
target: *const std.Target,
code: *std.ArrayList(u8),

prev_di_line: u32,
prev_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

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

            .dbg_line => try emit.mirDbgLine(inst),

            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

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

fn dbgAdvancePCAndLine(self: *Emit, line: u32, column: u32) !void {
    const delta_line = @intCast(i32, line) - @intCast(i32, self.prev_di_line);
    const delta_pc: usize = self.code.items.len - self.prev_di_pc;
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            // TODO Look into using the DWARF special opcodes to compress this data.
            // It lets you emit single-byte opcodes that add different numbers to
            // both the PC and the line number at the same time.
            try dbg_out.dbg_line.ensureUnusedCapacity(11);
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_pc);
            leb128.writeULEB128(dbg_out.dbg_line.writer(), delta_pc) catch unreachable;
            if (delta_line != 0) {
                dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_line);
                leb128.writeILEB128(dbg_out.dbg_line.writer(), delta_line) catch unreachable;
            }
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.copy);
            self.prev_di_pc = self.code.items.len;
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes
            // we have already checked the target in the linker to make sure it is compatable
            const quant = @import("../../link/Plan9/aout.zig").getPCQuant(self.target.cpu.arch) catch unreachable;

            // increasing the line number
            try @import("../../link/Plan9.zig").changeLine(dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @intCast(i64, delta_pc) - quant;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one quanta
                try dbg_out.dbg_line.append(@intCast(u8, @divExact(d_pc_p9, quant) + 128) - quant);
                if (dbg_out.pcop_change_index.*) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index.* = @intCast(u32, dbg_out.dbg_line.items.len - 1);
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the quant does it for us
            } else unreachable;
            if (dbg_out.start_line.* == null)
                dbg_out.start_line.* = self.prev_di_line;
            dbg_out.end_line.* = line;
            // only do this if the pc changed
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .none => {},
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

fn mirDbgLine(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const dbg_line_column = emit.mir.instructions.items(.data)[inst].dbg_line_column;

    switch (tag) {
        .dbg_line => try emit.dbgAdvancePCAndLine(dbg_line_column.line, dbg_line_column.column),
        else => unreachable,
    }
}

fn mirDebugPrologueEnd(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_prologue_end);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_epilogue_begin);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
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
