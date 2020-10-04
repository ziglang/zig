const std = @import("std");

pub const Interpreter = @import("spu-mk2/interpreter.zig").Interpreter;

pub const ExecutionCondition = enum(u3) {
    always = 0,
    when_zero = 1,
    not_zero = 2,
    greater_zero = 3,
    less_than_zero = 4,
    greater_or_equal_zero = 5,
    less_or_equal_zero = 6,
    overflow = 7,
};

pub const InputBehaviour = enum(u2) {
    zero = 0,
    immediate = 1,
    peek = 2,
    pop = 3,
};

pub const OutputBehaviour = enum(u2) {
    discard = 0,
    push = 1,
    jump = 2,
    jump_relative = 3,
};

pub const Command = enum(u5) {
    copy = 0,
    ipget = 1,
    get = 2,
    set = 3,
    store8 = 4,
    store16 = 5,
    load8 = 6,
    load16 = 7,
    undefined0 = 8,
    undefined1 = 9,
    frget = 10,
    frset = 11,
    bpget = 12,
    bpset = 13,
    spget = 14,
    spset = 15,
    add = 16,
    sub = 17,
    mul = 18,
    div = 19,
    mod = 20,
    @"and" = 21,
    @"or" = 22,
    xor = 23,
    not = 24,
    signext = 25,
    rol = 26,
    ror = 27,
    bswap = 28,
    asr = 29,
    lsl = 30,
    lsr = 31,
};

pub const Instruction = packed struct {
    condition: ExecutionCondition,
    input0: InputBehaviour,
    input1: InputBehaviour,
    modify_flags: bool,
    output: OutputBehaviour,
    command: Command,
    reserved: u1 = 0,

    pub fn format(instr: Instruction, comptime fmt: []const u8, options: std.fmt.FormatOptions, out: anytype) !void {
        try std.fmt.format(out, "0x{x:0<4} ", .{@bitCast(u16, instr)});
        try out.writeAll(switch (instr.condition) {
            .always => "    ",
            .when_zero => "== 0",
            .not_zero => "!= 0",
            .greater_zero => " > 0",
            .less_than_zero => " < 0",
            .greater_or_equal_zero => ">= 0",
            .less_or_equal_zero => "<= 0",
            .overflow => "ovfl",
        });
        try out.writeAll(" ");
        try out.writeAll(switch (instr.input0) {
            .zero => "zero",
            .immediate => "imm ",
            .peek => "peek",
            .pop => "pop ",
        });
        try out.writeAll(" ");
        try out.writeAll(switch (instr.input1) {
            .zero => "zero",
            .immediate => "imm ",
            .peek => "peek",
            .pop => "pop ",
        });
        try out.writeAll(" ");
        try out.writeAll(switch (instr.command) {
            .copy => "copy     ",
            .ipget => "ipget    ",
            .get => "get      ",
            .set => "set      ",
            .store8 => "store8   ",
            .store16 => "store16  ",
            .load8 => "load8    ",
            .load16 => "load16   ",
            .undefined0 => "undefined",
            .undefined1 => "undefined",
            .frget => "frget    ",
            .frset => "frset    ",
            .bpget => "bpget    ",
            .bpset => "bpset    ",
            .spget => "spget    ",
            .spset => "spset    ",
            .add => "add      ",
            .sub => "sub      ",
            .mul => "mul      ",
            .div => "div      ",
            .mod => "mod      ",
            .@"and" => "and      ",
            .@"or" => "or       ",
            .xor => "xor      ",
            .not => "not      ",
            .signext => "signext  ",
            .rol => "rol      ",
            .ror => "ror      ",
            .bswap => "bswap    ",
            .asr => "asr      ",
            .lsl => "lsl      ",
            .lsr => "lsr      ",
        });
        try out.writeAll(" ");
        try out.writeAll(switch (instr.output) {
            .discard => "discard",
            .push => "push   ",
            .jump => "jmp    ",
            .jump_relative => "rjmp   ",
        });
        try out.writeAll(" ");
        try out.writeAll(if (instr.modify_flags)
            "+ flags"
        else
            "       ");
    }
};

pub const FlagRegister = packed struct {
    zero: bool,
    negative: bool,
    carry: bool,
    carry_enabled: bool,
    interrupt0_enabled: bool,
    interrupt1_enabled: bool,
    interrupt2_enabled: bool,
    interrupt3_enabled: bool,
    reserved: u8 = 0,
};

pub const Register = enum {
    dummy,

    pub fn allocIndex(self: Register) ?u4 {
        return null;
    }
};

pub const callee_preserved_regs = [_]Register{};
