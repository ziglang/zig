//! This file contains the functionality for print x86_64 MIR in a debug way, interleaved with AIR

const Print = @This();

const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;

const Air = @import("../../Air.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;
const Encoder = bits.Encoder;
const ErrorMsg = Module.ErrorMsg;
const MCValue = @import("CodeGen.zig").MCValue;
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Instruction = bits.Instruction;
const Register = bits.Register;
const Type = @import("../../type.zig").Type;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

mir: Mir,
bin_file: *link.File,

pub fn printMir(print: *const Print, w: anytype, mir_to_air_map: std.AutoHashMap(Mir.Inst.Index, Air.Inst.Index), air: Air) !void {
    const instruction_bytes = print.mir.instructions.len *
        // Here we don't use @sizeOf(Mir.Inst.Data) because it would include
        // the debug safety tag but we want to measure release size.
        (@sizeOf(Mir.Inst.Tag) + 2 + 8);
    const extra_bytes = print.mir.extra.len * @sizeOf(u32);
    const total_bytes = @sizeOf(Mir) + instruction_bytes + extra_bytes;

    // zig fmt: off
    std.debug.print(
        \\# Total MIR bytes: {}
        \\# MIR Instructions:         {d} ({})
        \\# MIR Extra Data:           {d} ({})
        \\
    , .{
        fmtIntSizeBin(total_bytes),
        print.mir.instructions.len, fmtIntSizeBin(instruction_bytes),
        print.mir.extra.len, fmtIntSizeBin(extra_bytes),
    });
    // zig fmt: on
    const mir_tags = print.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        if (mir_to_air_map.get(inst)) |air_index| {
            try w.print("air index %{} ({}) for following mir inst(s)\n", .{ air_index, air.instructions.items(.tag)[air_index] });
        }
        try w.writeAll("  ");
        switch (tag) {
            .adc => try print.mirArith(.adc, inst, w),
            .add => try print.mirArith(.add, inst, w),
            .sub => try print.mirArith(.sub, inst, w),
            .xor => try print.mirArith(.xor, inst, w),
            .@"and" => try print.mirArith(.@"and", inst, w),
            .@"or" => try print.mirArith(.@"or", inst, w),
            .sbb => try print.mirArith(.sbb, inst, w),
            .cmp => try print.mirArith(.cmp, inst, w),
            .mov => try print.mirArith(.mov, inst, w),

            .adc_mem_imm => try print.mirArithMemImm(.adc, inst, w),
            .add_mem_imm => try print.mirArithMemImm(.add, inst, w),
            .sub_mem_imm => try print.mirArithMemImm(.sub, inst, w),
            .xor_mem_imm => try print.mirArithMemImm(.xor, inst, w),
            .and_mem_imm => try print.mirArithMemImm(.@"and", inst, w),
            .or_mem_imm => try print.mirArithMemImm(.@"or", inst, w),
            .sbb_mem_imm => try print.mirArithMemImm(.sbb, inst, w),
            .cmp_mem_imm => try print.mirArithMemImm(.cmp, inst, w),
            .mov_mem_imm => try print.mirArithMemImm(.mov, inst, w),

            .adc_scale_src => try print.mirArithScaleSrc(.adc, inst, w),
            .add_scale_src => try print.mirArithScaleSrc(.add, inst, w),
            .sub_scale_src => try print.mirArithScaleSrc(.sub, inst, w),
            .xor_scale_src => try print.mirArithScaleSrc(.xor, inst, w),
            .and_scale_src => try print.mirArithScaleSrc(.@"and", inst, w),
            .or_scale_src => try print.mirArithScaleSrc(.@"or", inst, w),
            .sbb_scale_src => try print.mirArithScaleSrc(.sbb, inst, w),
            .cmp_scale_src => try print.mirArithScaleSrc(.cmp, inst, w),
            .mov_scale_src => try print.mirArithScaleSrc(.mov, inst, w),

            .adc_scale_dst => try print.mirArithScaleDst(.adc, inst, w),
            .add_scale_dst => try print.mirArithScaleDst(.add, inst, w),
            .sub_scale_dst => try print.mirArithScaleDst(.sub, inst, w),
            .xor_scale_dst => try print.mirArithScaleDst(.xor, inst, w),
            .and_scale_dst => try print.mirArithScaleDst(.@"and", inst, w),
            .or_scale_dst => try print.mirArithScaleDst(.@"or", inst, w),
            .sbb_scale_dst => try print.mirArithScaleDst(.sbb, inst, w),
            .cmp_scale_dst => try print.mirArithScaleDst(.cmp, inst, w),
            .mov_scale_dst => try print.mirArithScaleDst(.mov, inst, w),

            .adc_scale_imm => try print.mirArithScaleImm(.adc, inst, w),
            .add_scale_imm => try print.mirArithScaleImm(.add, inst, w),
            .sub_scale_imm => try print.mirArithScaleImm(.sub, inst, w),
            .xor_scale_imm => try print.mirArithScaleImm(.xor, inst, w),
            .and_scale_imm => try print.mirArithScaleImm(.@"and", inst, w),
            .or_scale_imm => try print.mirArithScaleImm(.@"or", inst, w),
            .sbb_scale_imm => try print.mirArithScaleImm(.sbb, inst, w),
            .cmp_scale_imm => try print.mirArithScaleImm(.cmp, inst, w),
            .mov_scale_imm => try print.mirArithScaleImm(.mov, inst, w),

            .adc_mem_index_imm => try print.mirArithMemIndexImm(.adc, inst, w),
            .add_mem_index_imm => try print.mirArithMemIndexImm(.add, inst, w),
            .sub_mem_index_imm => try print.mirArithMemIndexImm(.sub, inst, w),
            .xor_mem_index_imm => try print.mirArithMemIndexImm(.xor, inst, w),
            .and_mem_index_imm => try print.mirArithMemIndexImm(.@"and", inst, w),
            .or_mem_index_imm => try print.mirArithMemIndexImm(.@"or", inst, w),
            .sbb_mem_index_imm => try print.mirArithMemIndexImm(.sbb, inst, w),
            .cmp_mem_index_imm => try print.mirArithMemIndexImm(.cmp, inst, w),
            .mov_mem_index_imm => try print.mirArithMemIndexImm(.mov, inst, w),

            .movabs => try print.mirMovabs(inst, w),

            .lea => try print.mirLea(inst, w),

            .imul_complex => try print.mirIMulComplex(inst, w),

            .push => try print.mirPushPop(.push, inst, w),
            .pop => try print.mirPushPop(.pop, inst, w),

            .jmp => try print.mirJmpCall(.jmp, inst, w),
            .call => try print.mirJmpCall(.call, inst, w),

            .cond_jmp_greater_less => try print.mirCondJmp(.cond_jmp_greater_less, inst, w),
            .cond_jmp_above_below => try print.mirCondJmp(.cond_jmp_above_below, inst, w),
            .cond_jmp_eq_ne => try print.mirCondJmp(.cond_jmp_eq_ne, inst, w),

            .cond_set_byte_greater_less => try print.mirCondSetByte(.cond_set_byte_greater_less, inst, w),
            .cond_set_byte_above_below => try print.mirCondSetByte(.cond_set_byte_above_below, inst, w),
            .cond_set_byte_eq_ne => try print.mirCondSetByte(.cond_set_byte_eq_ne, inst, w),

            .@"test" => try print.mirTest(inst, w),

            .brk => try w.writeAll("brk\n"),
            .ret => try w.writeAll("ret\n"),
            .nop => try w.writeAll("nop\n"),
            .syscall => try w.writeAll("syscall\n"),

            .call_extern => try print.mirCallExtern(inst, w),

            .dbg_line, .dbg_prologue_end, .dbg_epilogue_begin, .arg_dbg_info => try w.print("{s}\n", .{@tagName(tag)}),

            .push_regs_from_callee_preserved_regs => try print.mirPushPopRegsFromCalleePreservedRegs(.push, inst, w),
            .pop_regs_from_callee_preserved_regs => try print.mirPushPopRegsFromCalleePreservedRegs(.pop, inst, w),

            else => {
                try w.print("TODO emit asm for {s}\n", .{@tagName(tag)});
            },
        }
    }
}

fn mirPushPop(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // PUSH/POP reg
            try w.print("{s} {s}", .{ @tagName(tag), @tagName(ops.reg1) });
        },
        0b01 => {
            // PUSH/POP r/m64
            const imm = print.mir.instructions.items(.data)[inst].imm;
            try w.print("{s} [{s} + {d}]", .{ @tagName(tag), @tagName(ops.reg1), imm });
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            // PUSH imm32
            assert(tag == .push);
            try w.print("{s} {d}", .{ @tagName(tag), imm });
        },
        0b11 => unreachable,
    }
    try w.writeByte('\n');
}
fn mirPushPopRegsFromCalleePreservedRegs(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const payload = print.mir.instructions.items(.data)[inst].payload;
    const data = print.mir.extraData(Mir.RegsToPushOrPop, payload).data;
    const regs = data.regs;
    var disp: u32 = data.disp + 8;
    if (regs == 0) return w.writeAll("no regs from callee_preserved_regs\n");
    for (bits.callee_preserved_regs) |reg, i| {
        if ((regs >> @intCast(u5, i)) & 1 == 0) continue;
        if (tag == .push) {
            try w.print("mov qword ptr [{s} + {d}], {s}", .{
                @tagName(ops.reg1),
                @bitCast(u32, -@intCast(i32, disp)),
                @tagName(reg.to64()),
            });
        } else {
            try w.print("mov {s}, qword ptr [{s} + {d}]", .{
                @tagName(reg.to64()),
                @tagName(ops.reg1),
                @bitCast(u32, -@intCast(i32, disp)),
            });
        }
        disp += 8;
    }
    try w.writeByte('\n');
}

fn mirJmpCall(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    try w.print("{s} ", .{@tagName(tag)});
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const flag = @truncate(u1, ops.flags);
    if (flag == 0) {
        return w.writeAll("TODO target\n");
    }
    if (ops.reg1 == .none) {
        // JMP/CALL [imm]
        const imm = print.mir.instructions.items(.data)[inst].imm;
        try w.print("[{x}]\n", .{imm});
        return;
    }
    // JMP/CALL reg
    try w.print("{s}\n", .{@tagName(ops.reg1)});
}

fn mirCondJmp(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    _ = print;
    _ = tag;
    _ = inst;
    try w.writeAll("TODO print mirCondJmp\n");
}

fn mirCondSetByte(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    _ = tag;
    _ = inst;
    _ = print;
    try w.writeAll("TODO print mirCondSetByte\n");
}

fn mirTest(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    _ = print;
    _ = inst;
    try w.writeAll("TODO print mirTest\n");
}

fn mirArith(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    try w.writeAll(@tagName(tag));
    try w.writeByte(' ');
    switch (ops.flags) {
        0b00 => {
            if (ops.reg2 == .none) {
                const imm = print.mir.instructions.items(.data)[inst].imm;
                try w.print("{s}, {d}", .{ @tagName(ops.reg1), imm });
            } else try w.print("{s}, {s}", .{ @tagName(ops.reg1), @tagName(ops.reg2) });
        },
        0b01 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            if (ops.reg2 == .none) {
                try w.print("{s}, ", .{@tagName(ops.reg1)});
                switch (ops.reg1.size()) {
                    8 => try w.print("byte ptr ", .{}),
                    16 => try w.print("word ptr ", .{}),
                    32 => try w.print("dword ptr ", .{}),
                    64 => try w.print("qword ptr ", .{}),
                    else => unreachable,
                }
                try w.print("[ds:{d}]", .{imm});
            } else {
                try w.print("{s}, ", .{@tagName(ops.reg1)});
                switch (ops.reg1.size()) {
                    8 => try w.print("byte ptr ", .{}),
                    16 => try w.print("word ptr ", .{}),
                    32 => try w.print("dword ptr ", .{}),
                    64 => try w.print("qword ptr ", .{}),
                    else => unreachable,
                }
                try w.print("[{s} + {d}]", .{ @tagName(ops.reg2), imm });
            }
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            if (ops.reg2 == .none) {
                try w.writeAll("unused variant");
            } else {
                switch (ops.reg2.size()) {
                    8 => try w.print("byte ptr ", .{}),
                    16 => try w.print("word ptr ", .{}),
                    32 => try w.print("dword ptr ", .{}),
                    64 => try w.print("qword ptr ", .{}),
                    else => unreachable,
                }
                try w.print("[{s} + {d}], {s}", .{ @tagName(ops.reg1), imm, @tagName(ops.reg2) });
            }
        },
        0b11 => {
            try w.writeAll("unused variant");
        },
    }
    try w.writeByte('\n');
}

fn mirArithMemImm(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const payload = print.mir.instructions.items(.data)[inst].payload;
    const imm_pair = print.mir.extraData(Mir.ImmPair, payload).data;
    try w.print("{s} ", .{@tagName(tag)});
    switch (ops.flags) {
        0b00 => try w.print("byte ptr ", .{}),
        0b01 => try w.print("word ptr ", .{}),
        0b10 => try w.print("dword ptr ", .{}),
        0b11 => try w.print("qword ptr ", .{}),
    }
    try w.print("[{s} + {d}], {d}\n", .{ @tagName(ops.reg1), imm_pair.dest_off, imm_pair.operand });
}

fn mirArithScaleSrc(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    // OP reg1, [reg2 + scale*rcx + imm32]
    const imm = print.mir.instructions.items(.data)[inst].imm;
    try w.print("{s} {s}, [{s} + {d}*rcx + {d}]\n", .{ @tagName(tag), @tagName(ops.reg1), @tagName(ops.reg2), scale, imm });
}

fn mirArithScaleDst(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const imm = print.mir.instructions.items(.data)[inst].imm;

    if (ops.reg2 == .none) {
        // OP [reg1 + scale*rax + 0], imm32
        try w.print("{s} [{s} + {d}*rax + 0], {d}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm });
    }

    // OP [reg1 + scale*rax + imm32], reg2
    try w.print("{s} [{s} + {d}*rax + {d}], {s}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm, @tagName(ops.reg2) });
}

fn mirArithScaleImm(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const payload = print.mir.instructions.items(.data)[inst].payload;
    const imm_pair = print.mir.extraData(Mir.ImmPair, payload).data;
    try w.print("{s} [{s} + {d}*rax + {d}], {d}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm_pair.dest_off, imm_pair.operand });
}

fn mirArithMemIndexImm(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const payload = print.mir.instructions.items(.data)[inst].payload;
    const imm_pair = print.mir.extraData(Mir.ImmPair, payload).data;
    try w.print("{s} ", .{@tagName(tag)});
    switch (ops.flags) {
        0b00 => try w.print("byte ptr ", .{}),
        0b01 => try w.print("word ptr ", .{}),
        0b10 => try w.print("dword ptr ", .{}),
        0b11 => try w.print("qword ptr ", .{}),
    }
    try w.print("[{s} + 1*rax + {d}], {d}\n", .{ @tagName(ops.reg1), imm_pair.dest_off, imm_pair.operand });
}

fn mirMovabs(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .movabs);
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);

    const is_64 = ops.reg1.size() == 64;
    const imm: i128 = if (is_64) blk: {
        const payload = print.mir.instructions.items(.data)[inst].payload;
        const imm64 = print.mir.extraData(Mir.Imm64, payload).data;
        break :blk imm64.decode();
    } else print.mir.instructions.items(.data)[inst].imm;
    if (ops.flags == 0b00) {
        // movabs reg, imm64
        try w.print("movabs {s}, {d}\n", .{ @tagName(ops.reg1), imm });
    }
    if (ops.reg1 == .none) {
        try w.writeAll("movabs moffs64, rax\n");
    } else {
        // movabs rax, moffs64
        try w.writeAll("movabs rax, moffs64\n");
    }
}

fn mirIMulComplex(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .imul_complex);
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            try w.print("imul {s}, {s}\n", .{ @tagName(ops.reg1), @tagName(ops.reg2) });
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            try w.print("imul {s}, {s}, {d}\n", .{ @tagName(ops.reg1), @tagName(ops.reg2), imm });
        },
        else => return w.writeAll("TODO implement imul\n"),
    }
}

fn mirLea(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    try w.writeAll("lea ");
    switch (ops.flags) {
        0b00 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            try w.print("{s} [", .{@tagName(ops.reg1)});
            if (ops.reg2 != .none) {
                try w.print("{s} + ", .{@tagName(ops.reg2)});
            } else {
                try w.print("ds:", .{});
            }
            try w.print("{d}]\n", .{imm});
        },
        0b01 => {
            try w.print("{s}, ", .{@tagName(ops.reg1)});
            switch (ops.reg1.size()) {
                8 => try w.print("byte ptr ", .{}),
                16 => try w.print("word ptr ", .{}),
                32 => try w.print("dword ptr ", .{}),
                64 => try w.print("qword ptr ", .{}),
                else => unreachable,
            }
            try w.print("[rip + 0x0] ", .{});
            const payload = print.mir.instructions.items(.data)[inst].payload;
            const imm = print.mir.extraData(Mir.Imm64, payload).data.decode();
            try w.print("target@{x}", .{imm});
        },
        0b10 => {
            try w.print("{s}, ", .{@tagName(ops.reg1)});
            switch (ops.reg1.size()) {
                8 => try w.print("byte ptr ", .{}),
                16 => try w.print("word ptr ", .{}),
                32 => try w.print("dword ptr ", .{}),
                64 => try w.print("qword ptr ", .{}),
                else => unreachable,
            }
            try w.print("[rip + 0x0] ", .{});
            const got_entry = print.mir.instructions.items(.data)[inst].got_entry;
            if (print.bin_file.cast(link.File.MachO)) |macho_file| {
                const target = macho_file.locals.items[got_entry];
                const target_name = macho_file.getString(target.n_strx);
                try w.print("target@{s}", .{target_name});
            } else {
                try w.writeAll("TODO lea reg, [rip + reloc] for linking backends different than MachO");
            }
        },
        0b11 => {
            try w.writeAll("unused variant\n");
        },
    }
    try w.writeAll("\n");
}

fn mirCallExtern(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    _ = print;
    _ = inst;
    return w.writeAll("TODO call_extern");
}
