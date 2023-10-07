const std = @import("std");
const Codegen = @import("../Codegen_legacy.zig");
const Tree = @import("../Tree.zig");
const NodeIndex = Tree.NodeIndex;
const x86_64 = @import("zig").codegen.x86_64;
const Register = x86_64.Register;
const RegisterManager = @import("zig").RegisterManager;

const Fn = @This();

const Value = union(enum) {
    symbol: []const u8,
    immediate: i64,
    register: Register,
    none,
};

register_manager: RegisterManager(Fn, Register, &x86_64.callee_preserved_regs) = .{},
data: *std.ArrayList(u8),
c: *Codegen,

pub fn deinit(func: *Fn) void {
    func.* = undefined;
}

pub fn genFn(c: *Codegen, decl: NodeIndex, data: *std.ArrayList(u8)) Codegen.Error!void {
    var func = Fn{ .data = data, .c = c };
    defer func.deinit();

    // function prologue
    try func.data.appendSlice(&.{
        0x55, // push rbp
        0x48, 0x89, 0xe5, // mov rbp,rsp
    });
    _ = try func.genNode(c.node_data[@intFromEnum(decl)].decl.node);
    // all functions are guaranteed to end in a return statement so no extra work required here
}

pub fn spillInst(f: *Fn, reg: Register, inst: u32) !void {
    _ = inst;
    _ = reg;
    _ = f;
}

fn setReg(func: *Fn, val: Value, reg: Register) !void {
    switch (val) {
        .none => unreachable,
        .symbol => |sym| {
            // lea address with 0 and add relocation
            const encoder = try x86_64.Encoder.init(func.data, 8);
            encoder.rex(.{ .w = true });
            encoder.opcode_1byte(0x8D);
            encoder.modRm_RIPDisp32(reg.low_id());

            const offset = func.data.items.len;
            encoder.imm32(0);

            try func.c.obj.addRelocation(sym, .func, offset, -4);
        },
        .immediate => |x| if (x == 0) {
            // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
            // register is the fastest way to zero a register.
            // The encoding for `xor r32, r32` is `0x31 /r`.
            const encoder = try x86_64.Encoder.init(func.data, 3);

            // If we're accessing e.g. r8d, we need to use a REX prefix before the actual operation. Since
            // this is a 32-bit operation, the W flag is set to zero. X is also zero, as we're not using a SIB.
            // Both R and B are set, as we're extending, in effect, the register bits *and* the operand.
            encoder.rex(.{ .r = reg.isExtended(), .b = reg.isExtended() });
            encoder.opcode_1byte(0x31);
            // Section 3.1.1.1 of the Intel x64 Manual states that "/r indicates that the
            // ModR/M byte of the instruction contains a register operand and an r/m operand."
            encoder.modRm_direct(reg.low_id(), reg.low_id());
        } else if (x <= std.math.maxInt(i32)) {
            // Next best case: if we set the lower four bytes, the upper four will be zeroed.
            //
            // The encoding for `mov IMM32 -> REG` is (0xB8 + R) IMM.

            const encoder = try x86_64.Encoder.init(func.data, 6);
            // Just as with XORing, we need a REX prefix. This time though, we only
            // need the B bit set, as we're extending the opcode's register field,
            // and there is no Mod R/M byte.
            encoder.rex(.{ .b = reg.isExtended() });
            encoder.opcode_withReg(0xB8, reg.low_id());

            // no ModR/M byte

            // IMM
            encoder.imm32(@intCast(x));
        } else {
            // Worst case: we need to load the 64-bit register with the IMM. GNU's assemblers calls
            // this `movabs`, though this is officially just a different variant of the plain `mov`
            // instruction.
            //
            // This encoding is, in fact, the *same* as the one used for 32-bit loads. The only
            // difference is that we set REX.W before the instruction, which extends the load to
            // 64-bit and uses the full bit-width of the register.
            {
                const encoder = try x86_64.Encoder.init(func.data, 10);
                encoder.rex(.{ .w = true, .b = reg.isExtended() });
                encoder.opcode_withReg(0xB8, reg.low_id());
                encoder.imm64(@bitCast(x));
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // This is a variant of 8B /r.
            const encoder = try x86_64.Encoder.init(func.data, 3);
            encoder.rex(.{
                .w = true,
                .r = reg.isExtended(),
                .b = src_reg.isExtended(),
            });
            encoder.opcode_1byte(0x8B);
            encoder.modRm_direct(reg.low_id(), src_reg.low_id());
        },
    }
}

fn genNode(func: *Fn, node: NodeIndex) Codegen.Error!Value {
    if (func.c.tree.value_map.get(node)) |some| {
        if (some.tag == .int)
            return Value{ .immediate = @bitCast(some.data.int) };
    }

    const data = func.c.node_data[@intFromEnum(node)];
    switch (func.c.node_tag[@intFromEnum(node)]) {
        .static_assert => return Value{ .none = {} },
        .compound_stmt_two => {
            if (data.bin.lhs != .none) _ = try func.genNode(data.bin.lhs);
            if (data.bin.rhs != .none) _ = try func.genNode(data.bin.rhs);
            return Value{ .none = {} };
        },
        .compound_stmt => {
            for (func.c.tree.data[data.range.start..data.range.end]) |stmt| {
                _ = try func.genNode(stmt);
            }
            return Value{ .none = {} };
        },
        .call_expr_one => if (data.bin.rhs != .none)
            return func.genCall(data.bin.lhs, &.{data.bin.rhs})
        else
            return func.genCall(data.bin.lhs, &.{}),
        .call_expr => return func.genCall(func.c.tree.data[data.range.start], func.c.tree.data[data.range.start + 1 .. data.range.end]),
        .explicit_cast, .implicit_cast => {
            switch (data.cast.kind) {
                .function_to_pointer,
                .array_to_pointer,
                => return func.genNode(data.cast.operand), // no-op
                else => return func.c.comp.diag.fatalNoSrc("TODO x86_64 genNode for cast {s}\n", .{@tagName(data.cast.kind)}),
            }
        },
        .decl_ref_expr => {
            // TODO locals and arguments
            return Value{ .symbol = func.c.tree.tokSlice(data.decl_ref) };
        },
        .return_stmt => {
            const value = try func.genNode(data.un);
            try func.setReg(value, x86_64.c_abi_int_return_regs[0]);
            try func.data.appendSlice(&.{
                0x5d, // pop rbp
                0xc3, // ret
            });
            return Value{ .none = {} };
        },
        .implicit_return => {
            try func.setReg(.{ .immediate = 0 }, x86_64.c_abi_int_return_regs[0]);
            try func.data.appendSlice(&.{
                0x5d, // pop rbp
                0xc3, // ret
            });
            return Value{ .none = {} };
        },
        .int_literal => return Value{ .immediate = @bitCast(data.int) },
        .string_literal_expr => {
            const range = func.c.tree.value_map.get(node).?.data.bytes;
            const str_bytes = range.slice(func.c.tree.strings);
            const section = try func.c.obj.getSection(.strings);
            const start = section.items.len;
            try section.appendSlice(str_bytes);
            const symbol_name = try func.c.obj.declareSymbol(.strings, null, .Internal, .variable, start, str_bytes.len);
            return Value{ .symbol = symbol_name };
        },
        else => return func.c.comp.diag.fatalNoSrc("TODO x86_64 genNode {}\n", .{func.c.node_tag[@intFromEnum(node)]}),
    }
}

fn genCall(func: *Fn, lhs: NodeIndex, args: []const NodeIndex) Codegen.Error!Value {
    if (args.len > x86_64.c_abi_int_param_regs.len)
        return func.c.comp.diag.fatalNoSrc("TODO more than args {d}\n", .{x86_64.c_abi_int_param_regs.len});

    const func_value = try func.genNode(lhs);
    for (args, 0..) |arg, i| {
        const value = try func.genNode(arg);
        try func.setReg(value, x86_64.c_abi_int_param_regs[i]);
    }

    switch (func_value) {
        .none => unreachable,
        .symbol => |sym| {
            const encoder = try x86_64.Encoder.init(func.data, 5);
            encoder.opcode_1byte(0xe8);

            const offset = func.data.items.len;
            encoder.imm32(0);

            try func.c.obj.addRelocation(sym, .func, offset, -4);
        },
        .immediate => return func.c.comp.diag.fatalNoSrc("TODO call immediate\n", .{}),
        .register => return func.c.comp.diag.fatalNoSrc("TODO call reg\n", .{}),
    }
    return Value{ .register = x86_64.c_abi_int_return_regs[0] };
}

pub fn genVar(c: *Codegen, decl: NodeIndex) Codegen.Error!void {
    _ = c;
    _ = decl;
}
