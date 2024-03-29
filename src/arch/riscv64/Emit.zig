//! This file contains the functionality for lowering RISCV64 MIR into
//! machine code

mir: Mir,
bin_file: *link.File,
debug_output: DebugInfoOutput,
target: *const std.Target,
err_msg: ?*ErrorMsg = null,
src_loc: Module.SrcLoc,
code: *std.ArrayList(u8),

/// List of registers to save in the prologue.
save_reg_list: Mir.RegisterList,

prev_di_line: u32,
prev_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

/// Function's stack size. Used for backpatching.
stack_size: u32,

/// For backward branches: stores the code offset of the target
/// instruction
///
/// For forward branches: stores the code offset of the branch
/// instruction
code_offset_mapping: std.AutoHashMapUnmanaged(Mir.Inst.Index, usize) = .{},

const log = std.log.scoped(.emit);

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(
    emit: *Emit,
) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    try emit.lowerMir();

    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        log.debug("emitMir: {s}", .{@tagName(tag)});
        switch (tag) {
            .add => try emit.mirRType(inst),
            .sub => try emit.mirRType(inst),
            .@"or" => try emit.mirRType(inst),

            .cmp_eq => try emit.mirRType(inst),
            .cmp_neq => try emit.mirRType(inst),
            .cmp_gt => try emit.mirRType(inst),
            .cmp_gte => try emit.mirRType(inst),
            .cmp_lt => try emit.mirRType(inst),
            .cmp_imm_gte => try emit.mirRType(inst),
            .cmp_imm_eq => try emit.mirIType(inst),
            .cmp_imm_lte => try emit.mirIType(inst),

            .beq => try emit.mirBType(inst),
            .bne => try emit.mirBType(inst),

            .addi => try emit.mirIType(inst),
            .addiw => try emit.mirIType(inst),
            .andi => try emit.mirIType(inst),
            .jalr => try emit.mirIType(inst),
            .abs => try emit.mirIType(inst),

            .jal => try emit.mirJType(inst),

            .ebreak => try emit.mirSystem(inst),
            .ecall => try emit.mirSystem(inst),
            .unimp => try emit.mirSystem(inst),

            .dbg_line => try emit.mirDbgLine(inst),
            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .psuedo_prologue => try emit.mirPsuedo(inst),
            .psuedo_epilogue => try emit.mirPsuedo(inst),

            .j => try emit.mirPsuedo(inst),

            .mv => try emit.mirRR(inst),

            .nop => try emit.mirNop(inst),
            .ret => try emit.mirNop(inst),

            .lui => try emit.mirUType(inst),

            .ld => try emit.mirIType(inst),
            .lw => try emit.mirIType(inst),
            .lh => try emit.mirIType(inst),
            .lb => try emit.mirIType(inst),

            .sd => try emit.mirIType(inst),
            .sw => try emit.mirIType(inst),
            .sh => try emit.mirIType(inst),
            .sb => try emit.mirIType(inst),

            .srlw => try emit.mirRType(inst),
            .sllw => try emit.mirRType(inst),

            .srli => try emit.mirIType(inst),
            .slli => try emit.mirIType(inst),

            .ldr_ptr_stack => try emit.mirIType(inst),

            .load_symbol => try emit.mirLoadSymbol(inst),
        }
    }
}

pub fn deinit(emit: *Emit) void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;

    emit.code_offset_mapping.deinit(gpa);
    emit.* = undefined;
}

fn writeInstruction(emit: *Emit, instruction: Instruction) !void {
    const endian = emit.target.cpu.arch.endian();
    std.mem.writeInt(u32, try emit.code.addManyAsArray(4), instruction.toU32(), endian);
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(emit.err_msg == null);
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    emit.err_msg = try ErrorMsg.create(gpa, emit.src_loc, format, args);
    return error.EmitFail;
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) !void {
    const delta_line = @as(i32, @intCast(line)) - @as(i32, @intCast(emit.prev_di_line));
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    switch (emit.debug_output) {
        .dwarf => |dw| {
            if (column != emit.prev_di_column) try dw.setColumn(column);
            if (delta_line == 0) return; // TODO: remove this
            try dw.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes

            // increasing the line number
            try link.File.Plan9.changeLine(&dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @as(i64, @intCast(delta_pc)) - dbg_out.pc_quanta;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one pc quanta
                try dbg_out.dbg_line.append(@as(u8, @intCast(@divExact(d_pc_p9, dbg_out.pc_quanta) + 128)) - dbg_out.pc_quanta);
                if (dbg_out.pcop_change_index) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index = @as(u32, @intCast(dbg_out.dbg_line.items.len - 1));
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the pc quanta does it for us
            } else unreachable;
            if (dbg_out.start_line == null)
                dbg_out.start_line = emit.prev_di_line;
            dbg_out.end_line = line;
            // only do this if the pc changed
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

fn mirRType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_type = emit.mir.instructions.items(.data)[inst].r_type;

    const rd = r_type.rd;
    const rs1 = r_type.rs1;
    const rs2 = r_type.rs2;

    switch (tag) {
        .add => try emit.writeInstruction(Instruction.add(rd, rs1, rs2)),
        .sub => try emit.writeInstruction(Instruction.sub(rd, rs1, rs2)),
        .cmp_gt => {
            // rs1 > rs2
            try emit.writeInstruction(Instruction.sltu(rd, rs2, rs1));
        },
        .cmp_gte => {
            // rs1 >= rs2
            try emit.writeInstruction(Instruction.sltu(rd, rs1, rs2));
            try emit.writeInstruction(Instruction.xori(rd, rd, 1));
        },
        .cmp_eq => {
            // rs1 == rs2

            try emit.writeInstruction(Instruction.xor(rd, rs1, rs2));
            try emit.writeInstruction(Instruction.sltiu(rd, rd, 1)); // seqz
        },
        .cmp_neq => {
            // rs1 != rs2

            try emit.writeInstruction(Instruction.xor(rd, rs1, rs2));
            try emit.writeInstruction(Instruction.sltu(rd, .zero, rd)); // snez
        },
        .cmp_lt => {
            // rd = 1 if rs1 < rs2
            try emit.writeInstruction(Instruction.slt(rd, rs1, rs2));
        },
        .sllw => try emit.writeInstruction(Instruction.sllw(rd, rs1, rs2)),
        .srlw => try emit.writeInstruction(Instruction.srlw(rd, rs1, rs2)),
        .@"or" => try emit.writeInstruction(Instruction.@"or"(rd, rs1, rs2)),
        .cmp_imm_gte => {
            // rd = 1 if rs1 >= imm12
            // see the docstring of cmp_imm_gte to see why we use r_type here

            // (rs1 >= imm12) == !(imm12 > rs1)
            try emit.writeInstruction(Instruction.sltu(rd, rs1, rs2));
        },
        else => unreachable,
    }
}

fn mirBType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const b_type = emit.mir.instructions.items(.data)[inst].b_type;

    const offset = @as(i64, @intCast(emit.code_offset_mapping.get(b_type.inst).?)) - @as(i64, @intCast(emit.code.items.len));

    switch (tag) {
        .beq => {
            log.debug("beq: {} offset={}", .{ inst, offset });
            try emit.writeInstruction(Instruction.beq(b_type.rs1, b_type.rs2, @intCast(offset)));
        },
        .bne => {
            log.debug("bne: {} offset={}", .{ inst, offset });
            try emit.writeInstruction(Instruction.bne(b_type.rs1, b_type.rs2, @intCast(offset)));
        },
        else => unreachable,
    }
}

fn mirIType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const i_type = emit.mir.instructions.items(.data)[inst].i_type;

    const rd = i_type.rd;
    const rs1 = i_type.rs1;
    const imm12 = i_type.imm12;

    switch (tag) {
        .addi => try emit.writeInstruction(Instruction.addi(rd, rs1, imm12)),
        .addiw => try emit.writeInstruction(Instruction.addiw(rd, rs1, imm12)),
        .jalr => try emit.writeInstruction(Instruction.jalr(rd, imm12, rs1)),

        .andi => try emit.writeInstruction(Instruction.andi(rd, rs1, imm12)),

        .ld => try emit.writeInstruction(Instruction.ld(rd, imm12, rs1)),
        .lw => try emit.writeInstruction(Instruction.lw(rd, imm12, rs1)),
        .lh => try emit.writeInstruction(Instruction.lh(rd, imm12, rs1)),
        .lb => try emit.writeInstruction(Instruction.lb(rd, imm12, rs1)),

        .sd => try emit.writeInstruction(Instruction.sd(rd, imm12, rs1)),
        .sw => try emit.writeInstruction(Instruction.sw(rd, imm12, rs1)),
        .sh => try emit.writeInstruction(Instruction.sh(rd, imm12, rs1)),
        .sb => try emit.writeInstruction(Instruction.sb(rd, imm12, rs1)),

        .ldr_ptr_stack => try emit.writeInstruction(Instruction.add(rd, rs1, .sp)),

        .abs => {
            try emit.writeInstruction(Instruction.sraiw(rd, rs1, @intCast(imm12)));
            try emit.writeInstruction(Instruction.xor(rs1, rs1, rd));
            try emit.writeInstruction(Instruction.subw(rs1, rs1, rd));
        },

        .srli => try emit.writeInstruction(Instruction.srli(rd, rs1, @intCast(imm12))),
        .slli => try emit.writeInstruction(Instruction.slli(rd, rs1, @intCast(imm12))),

        .cmp_imm_eq => {
            try emit.writeInstruction(Instruction.xori(rd, rs1, imm12));
            try emit.writeInstruction(Instruction.sltiu(rd, rd, 1));
        },

        .cmp_imm_lte => {
            try emit.writeInstruction(Instruction.sltiu(rd, rs1, @bitCast(imm12)));
        },

        else => unreachable,
    }
}

fn mirJType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const j_type = emit.mir.instructions.items(.data)[inst].j_type;

    const offset = @as(i64, @intCast(emit.code_offset_mapping.get(j_type.inst).?)) - @as(i64, @intCast(emit.code.items.len));

    switch (tag) {
        .jal => {
            log.debug("jal: {} offset={}", .{ inst, offset });
            try emit.writeInstruction(Instruction.jal(j_type.rd, @intCast(offset)));
        },
        else => unreachable,
    }
}

fn mirSystem(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .ebreak => try emit.writeInstruction(Instruction.ebreak),
        .ecall => try emit.writeInstruction(Instruction.ecall),
        .unimp => try emit.writeInstruction(Instruction.unimp),
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

fn mirDebugPrologueEnd(emit: *Emit) !void {
    switch (emit.debug_output) {
        .dwarf => |dw| {
            try dw.setPrologueEnd();
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(emit: *Emit) !void {
    switch (emit.debug_output) {
        .dwarf => |dw| {
            try dw.setEpilogueBegin();
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirPsuedo(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst];

    switch (tag) {
        .psuedo_prologue => {
            const stack_size: i12 = math.cast(i12, emit.stack_size) orelse {
                return emit.fail("TODO: mirPsuedo support larger stack sizes", .{});
            };

            // Decrement sp by (num s registers * 8) + local var space
            try emit.writeInstruction(Instruction.addi(.sp, .sp, -stack_size));

            // Spill ra
            try emit.writeInstruction(Instruction.sd(.ra, 0, .sp));

            // Spill callee saved registers.
            var s_reg_iter = emit.save_reg_list.iterator(.{});
            var i: i12 = 8;
            while (s_reg_iter.next()) |reg_i| {
                const reg = abi.callee_preserved_regs[reg_i];
                try emit.writeInstruction(Instruction.sd(reg, i, .sp));
                i += 8;
            }
        },
        .psuedo_epilogue => {
            const stack_size: i12 = math.cast(i12, emit.stack_size) orelse {
                return emit.fail("TODO: mirPsuedo support larger stack sizes", .{});
            };

            // Restore ra
            try emit.writeInstruction(Instruction.ld(.ra, 0, .sp));

            // Restore spilled callee saved registers
            var s_reg_iter = emit.save_reg_list.iterator(.{});
            var i: i12 = 8;
            while (s_reg_iter.next()) |reg_i| {
                const reg = abi.callee_preserved_regs[reg_i];
                try emit.writeInstruction(Instruction.ld(reg, i, .sp));
                i += 8;
            }

            // Increment sp back to previous value
            try emit.writeInstruction(Instruction.addi(.sp, .sp, stack_size));
        },

        .j => {
            const offset = @as(i64, @intCast(emit.code_offset_mapping.get(data.inst).?)) - @as(i64, @intCast(emit.code.items.len));
            try emit.writeInstruction(Instruction.jal(.zero, @intCast(offset)));
        },

        else => unreachable,
    }
}

fn mirRR(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr = emit.mir.instructions.items(.data)[inst].rr;

    const rd = rr.rd;
    const rs = rr.rs;

    switch (tag) {
        .mv => try emit.writeInstruction(Instruction.addi(rd, rs, 0)),
        else => unreachable,
    }
}

fn mirUType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const u_type = emit.mir.instructions.items(.data)[inst].u_type;

    switch (tag) {
        .lui => try emit.writeInstruction(Instruction.lui(u_type.rd, u_type.imm20)),
        else => unreachable,
    }
}

fn mirNop(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .nop => try emit.writeInstruction(Instruction.addi(.zero, .zero, 0)),
        .ret => try emit.writeInstruction(Instruction.jalr(.zero, 0, .ra)),
        else => unreachable,
    }
}

fn mirLoadSymbol(emit: *Emit, inst: Mir.Inst.Index) !void {
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const data = emit.mir.extraData(Mir.LoadSymbolPayload, payload).data;
    const reg = @as(Register, @enumFromInt(data.register));

    const start_offset = @as(u32, @intCast(emit.code.items.len));
    try emit.writeInstruction(Instruction.lui(reg, 0));

    switch (emit.bin_file.tag) {
        .elf => {
            const elf_file = emit.bin_file.cast(link.File.Elf).?;
            const atom_ptr = elf_file.symbol(data.atom_index).atom(elf_file).?;
            const sym_index = elf_file.zigObjectPtr().?.symbol(data.sym_index);
            const sym = elf_file.symbol(sym_index);

            var hi_r_type: u32 = @intFromEnum(std.elf.R_RISCV.HI20);
            var lo_r_type: u32 = @intFromEnum(std.elf.R_RISCV.LO12_I);

            if (sym.flags.needs_zig_got) {
                _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);

                hi_r_type = Elf.R_ZIG_GOT_HI20;
                lo_r_type = Elf.R_ZIG_GOT_LO12;

                // we need to deref once if we are getting from zig_got, as itll
                // reloc an address of the address in the got.
                try emit.writeInstruction(Instruction.ld(reg, 0, reg));
            } else {
                try emit.writeInstruction(Instruction.addi(reg, reg, 0));
            }

            try atom_ptr.addReloc(elf_file, .{
                .r_offset = start_offset,
                .r_info = (@as(u64, @intCast(data.sym_index)) << 32) | hi_r_type,
                .r_addend = 0,
            });

            try atom_ptr.addReloc(elf_file, .{
                .r_offset = start_offset + 4,
                .r_info = (@as(u64, @intCast(data.sym_index)) << 32) | lo_r_type,
                .r_addend = 0,
            });
        },
        else => unreachable,
    }
}

fn isStore(tag: Mir.Inst.Tag) bool {
    return switch (tag) {
        .sb => true,
        .sh => true,
        .sw => true,
        .sd => true,
        .addi => true, // needed for ptr_stack_offset stores
        else => false,
    };
}

fn isLoad(tag: Mir.Inst.Tag) bool {
    return switch (tag) {
        .lb => true,
        .lh => true,
        .lw => true,
        .ld => true,
        else => false,
    };
}

pub fn isBranch(tag: Mir.Inst.Tag) bool {
    return switch (tag) {
        .beq => true,
        .bne => true,
        .jal => true,
        .j => true,
        else => false,
    };
}

pub fn branchTarget(emit: *Emit, inst: Mir.Inst.Index) Mir.Inst.Index {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst];

    switch (tag) {
        .bne,
        .beq,
        => return data.b_type.inst,
        .jal => return data.j_type.inst,
        .j => return data.inst,
        else => std.debug.panic("branchTarget {s}", .{@tagName(tag)}),
    }
}

fn instructionSize(emit: *Emit, inst: Mir.Inst.Index) usize {
    const tag = emit.mir.instructions.items(.tag)[inst];

    return switch (tag) {
        .dbg_line,
        .dbg_epilogue_begin,
        .dbg_prologue_end,
        => 0,

        .cmp_eq,
        .cmp_neq,
        .cmp_imm_eq,
        .cmp_gte,
        .load_symbol,
        .abs,
        => 8,

        .psuedo_epilogue, .psuedo_prologue => size: {
            const count = emit.save_reg_list.count() * 4;
            break :size count + 8;
        },

        else => 4,
    };
}

fn lowerMir(emit: *Emit) !void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    const mir_tags = emit.mir.instructions.items(.tag);
    const mir_datas = emit.mir.instructions.items(.data);

    const proglogue_size: u32 = @intCast(emit.save_reg_list.size());
    emit.stack_size += proglogue_size;

    for (mir_tags, 0..) |tag, index| {
        const inst: u32 = @intCast(index);

        if (isStore(tag) or isLoad(tag)) {
            const data = mir_datas[inst].i_type;
            if (data.rs1 == .sp) {
                const offset = mir_datas[inst].i_type.imm12;
                mir_datas[inst].i_type.imm12 = offset + @as(i12, @intCast(proglogue_size)) + 8;
            }
        }

        if (isBranch(tag)) {
            const target_inst = emit.branchTarget(inst);
            try emit.code_offset_mapping.put(gpa, target_inst, 0);
        }
    }
    var current_code_offset: usize = 0;

    for (0..mir_tags.len) |index| {
        const inst = @as(u32, @intCast(index));
        if (emit.code_offset_mapping.getPtr(inst)) |offset| {
            offset.* = current_code_offset;
        }
        current_code_offset += emit.instructionSize(inst);
    }
}

const Emit = @This();
const std = @import("std");
const math = std.math;
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const abi = @import("abi.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const Elf = @import("../../link/Elf.zig");
const ErrorMsg = Module.ErrorMsg;
const assert = std.debug.assert;
const Instruction = bits.Instruction;
const Register = bits.Register;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
