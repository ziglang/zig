const std = @import("std");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const Module = @import("Module.zig");
const assert = std.debug.assert;
const codegen = @import("codegen.zig");
const ast = std.zig.ast;

/// These are in-memory, analyzed instructions. See `zir.Inst` for the representation
/// of instructions that correspond to the ZIR text format.
/// This struct owns the `Value` and `Type` memory. When the struct is deallocated,
/// so are the `Value` and `Type`. The value of a constant must be copied into
/// a memory location for the value to survive after a const instruction.
pub const Inst = struct {
    tag: Tag,
    /// Each bit represents the index of an `Inst` parameter in the `args` field.
    /// If a bit is set, it marks the end of the lifetime of the corresponding
    /// instruction parameter. For example, 0b101 means that the first and
    /// third `Inst` parameters' lifetimes end after this instruction, and will
    /// not have any more following references.
    /// The most significant bit being set means that the instruction itself is
    /// never referenced, in other words its lifetime ends as soon as it finishes.
    /// If bit 15 (0b1xxx_xxxx_xxxx_xxxx) is set, it means this instruction itself is unreferenced.
    /// If bit 14 (0bx1xx_xxxx_xxxx_xxxx) is set, it means this is a special case and the
    /// lifetimes of operands are encoded elsewhere.
    deaths: DeathsInt = undefined,
    ty: Type,
    src: Module.LazySrcLoc,

    pub const DeathsInt = u16;
    pub const DeathsBitIndex = std.math.Log2Int(DeathsInt);
    pub const unreferenced_bit_index = @typeInfo(DeathsInt).Int.bits - 1;
    pub const deaths_bits = unreferenced_bit_index - 1;

    pub fn isUnused(self: Inst) bool {
        return (self.deaths & (1 << unreferenced_bit_index)) != 0;
    }

    pub fn operandDies(self: Inst, index: DeathsBitIndex) bool {
        assert(index < deaths_bits);
        return @truncate(u1, self.deaths >> index) != 0;
    }

    pub fn clearOperandDeath(self: *Inst, index: DeathsBitIndex) void {
        assert(index < deaths_bits);
        self.deaths &= ~(@as(DeathsInt, 1) << index);
    }

    pub fn specialOperandDeaths(self: Inst) bool {
        return (self.deaths & (1 << deaths_bits)) != 0;
    }

    pub const Tag = enum {
        add,
        addwrap,
        alloc,
        arg,
        assembly,
        bit_and,
        bitcast,
        bit_or,
        block,
        br,
        /// Same as `br` except the operand is a list of instructions to be treated as
        /// a flat block; that is there is only 1 break instruction from the block, and
        /// it is implied to be after the last instruction, and the last instruction is
        /// the break operand.
        /// This instruction exists for late-stage semantic analysis patch ups, to
        /// replace one br operand with multiple instructions, without moving anything else around.
        br_block_flat,
        breakpoint,
        br_void,
        call,
        cmp_lt,
        cmp_lte,
        cmp_eq,
        cmp_gte,
        cmp_gt,
        cmp_neq,
        condbr,
        constant,
        dbg_stmt,
        /// ?T => bool
        is_null,
        /// ?T => bool (inverted logic)
        is_non_null,
        /// *?T => bool
        is_null_ptr,
        /// *?T => bool (inverted logic)
        is_non_null_ptr,
        /// E!T => bool
        is_err,
        /// *E!T => bool
        is_err_ptr,
        /// E => u16
        error_to_int,
        /// u16 => E
        int_to_error,
        bool_and,
        bool_or,
        /// Read a value from a pointer.
        load,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        loop,
        ptrtoint,
        ref,
        ret,
        retvoid,
        varptr,
        /// Write a value to a pointer. LHS is pointer, RHS is value.
        store,
        sub,
        subwrap,
        unreach,
        mul,
        mulwrap,
        div,
        not,
        floatcast,
        intcast,
        /// ?T => T
        optional_payload,
        /// *?T => *T
        optional_payload_ptr,
        wrap_optional,
        /// E!T -> T
        unwrap_errunion_payload,
        /// E!T -> E
        unwrap_errunion_err,
        /// *(E!T) -> *T
        unwrap_errunion_payload_ptr,
        /// *(E!T) -> E
        unwrap_errunion_err_ptr,
        /// wrap from T to E!T
        wrap_errunion_payload,
        /// wrap from E to E!T
        wrap_errunion_err,
        xor,
        switchbr,
        /// Given a pointer to a struct and a field index, returns a pointer to the field.
        struct_field_ptr,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                => NoOp,

                .ref,
                .ret,
                .bitcast,
                .not,
                .is_non_null,
                .is_non_null_ptr,
                .is_null,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .int_to_error,
                .error_to_int,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .optional_payload,
                .optional_payload_ptr,
                .wrap_optional,
                .unwrap_errunion_payload,
                .unwrap_errunion_err,
                .unwrap_errunion_payload_ptr,
                .unwrap_errunion_err_ptr,
                .wrap_errunion_payload,
                .wrap_errunion_err,
                => UnOp,

                .add,
                .addwrap,
                .sub,
                .subwrap,
                .mul,
                .mulwrap,
                .div,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                .bool_and,
                .bool_or,
                .bit_and,
                .bit_or,
                .xor,
                => BinOp,

                .arg => Arg,
                .assembly => Assembly,
                .block => Block,
                .br => Br,
                .br_block_flat => BrBlockFlat,
                .br_void => BrVoid,
                .call => Call,
                .condbr => CondBr,
                .constant => Constant,
                .loop => Loop,
                .varptr => VarPtr,
                .struct_field_ptr => StructFieldPtr,
                .switchbr => SwitchBr,
                .dbg_stmt => DbgStmt,
            };
        }

        pub fn fromCmpOp(op: std.math.CompareOperator) Tag {
            return switch (op) {
                .lt => .cmp_lt,
                .lte => .cmp_lte,
                .eq => .cmp_eq,
                .gte => .cmp_gte,
                .gt => .cmp_gt,
                .neq => .cmp_neq,
            };
        }
    };

    /// Prefer `castTag` to this.
    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (@hasField(T, "base_tag")) {
            return base.castTag(T.base_tag);
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                if (T == tag.Type()) {
                    return @fieldParentPtr(T, "base", base);
                }
                return null;
            }
        }
        unreachable;
    }

    pub fn castTag(base: *Inst, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
    }

    pub fn Args(comptime T: type) type {
        return std.meta.fieldInfo(T, .args).field_type;
    }

    /// Returns `null` if runtime-known.
    /// Should be called by codegen, not by Sema. Sema functions should call
    /// `resolvePossiblyUndefinedValue` or `resolveDefinedValue` instead.
    /// TODO audit Sema code for violations to the above guidance.
    pub fn value(base: *Inst) ?Value {
        if (base.ty.onePossibleValue()) |opv| return opv;

        const inst = base.castTag(.constant) orelse return null;
        return inst.val;
    }

    pub fn cmpOperator(base: *Inst) ?std.math.CompareOperator {
        return switch (base.tag) {
            .cmp_lt => .lt,
            .cmp_lte => .lte,
            .cmp_eq => .eq,
            .cmp_gte => .gte,
            .cmp_gt => .gt,
            .cmp_neq => .neq,
            else => null,
        };
    }

    pub fn operandCount(base: *Inst) usize {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (tag == base.tag) {
                return @fieldParentPtr(tag.Type(), "base", base).operandCount();
            }
        }
        unreachable;
    }

    pub fn getOperand(base: *Inst, index: usize) ?*Inst {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (tag == base.tag) {
                return @fieldParentPtr(tag.Type(), "base", base).getOperand(index);
            }
        }
        unreachable;
    }

    pub fn breakBlock(base: *Inst) ?*Block {
        return switch (base.tag) {
            .br => base.castTag(.br).?.block,
            .br_void => base.castTag(.br_void).?.block,
            .br_block_flat => base.castTag(.br_block_flat).?.block,
            else => null,
        };
    }

    pub const NoOp = struct {
        base: Inst,

        pub fn operandCount(self: *const NoOp) usize {
            return 0;
        }
        pub fn getOperand(self: *const NoOp, index: usize) ?*Inst {
            return null;
        }
    };

    pub const UnOp = struct {
        base: Inst,
        operand: *Inst,

        pub fn operandCount(self: *const UnOp) usize {
            return 1;
        }
        pub fn getOperand(self: *const UnOp, index: usize) ?*Inst {
            if (index == 0)
                return self.operand;
            return null;
        }
    };

    pub const BinOp = struct {
        base: Inst,
        lhs: *Inst,
        rhs: *Inst,

        pub fn operandCount(self: *const BinOp) usize {
            return 2;
        }
        pub fn getOperand(self: *const BinOp, index: usize) ?*Inst {
            var i = index;

            if (i < 1)
                return self.lhs;
            i -= 1;

            if (i < 1)
                return self.rhs;
            i -= 1;

            return null;
        }
    };

    pub const Arg = struct {
        pub const base_tag = Tag.arg;

        base: Inst,
        /// This exists to be emitted into debug info.
        name: [*:0]const u8,

        pub fn operandCount(self: *const Arg) usize {
            return 0;
        }
        pub fn getOperand(self: *const Arg, index: usize) ?*Inst {
            return null;
        }
    };

    pub const Assembly = struct {
        pub const base_tag = Tag.assembly;

        base: Inst,
        asm_source: []const u8,
        is_volatile: bool,
        output_constraint: ?[]const u8,
        inputs: []const []const u8,
        clobbers: []const []const u8,
        args: []const *Inst,

        pub fn operandCount(self: *const Assembly) usize {
            return self.args.len;
        }
        pub fn getOperand(self: *const Assembly, index: usize) ?*Inst {
            if (index < self.args.len)
                return self.args[index];
            return null;
        }
    };

    pub const Block = struct {
        pub const base_tag = Tag.block;

        base: Inst,
        body: Body,
        /// This memory is reserved for codegen code to do whatever it needs to here.
        codegen: codegen.BlockData = .{},

        pub fn operandCount(self: *const Block) usize {
            return 0;
        }
        pub fn getOperand(self: *const Block, index: usize) ?*Inst {
            return null;
        }
    };

    pub const convertable_br_size = std.math.max(@sizeOf(BrBlockFlat), @sizeOf(Br));
    pub const convertable_br_align = std.math.max(@alignOf(BrBlockFlat), @alignOf(Br));
    comptime {
        assert(@byteOffsetOf(BrBlockFlat, "base") == @byteOffsetOf(Br, "base"));
    }

    pub const BrBlockFlat = struct {
        pub const base_tag = Tag.br_block_flat;

        base: Inst,
        block: *Block,
        body: Body,

        pub fn operandCount(self: *const BrBlockFlat) usize {
            return 0;
        }
        pub fn getOperand(self: *const BrBlockFlat, index: usize) ?*Inst {
            return null;
        }
    };

    pub const Br = struct {
        pub const base_tag = Tag.br;

        base: Inst,
        block: *Block,
        operand: *Inst,

        pub fn operandCount(self: *const Br) usize {
            return 1;
        }
        pub fn getOperand(self: *const Br, index: usize) ?*Inst {
            if (index == 0)
                return self.operand;
            return null;
        }
    };

    pub const BrVoid = struct {
        pub const base_tag = Tag.br_void;

        base: Inst,
        block: *Block,

        pub fn operandCount(self: *const BrVoid) usize {
            return 0;
        }
        pub fn getOperand(self: *const BrVoid, index: usize) ?*Inst {
            return null;
        }
    };

    pub const Call = struct {
        pub const base_tag = Tag.call;

        base: Inst,
        func: *Inst,
        args: []const *Inst,

        pub fn operandCount(self: *const Call) usize {
            return self.args.len + 1;
        }
        pub fn getOperand(self: *const Call, index: usize) ?*Inst {
            var i = index;

            if (i < 1)
                return self.func;
            i -= 1;

            if (i < self.args.len)
                return self.args[i];
            i -= self.args.len;

            return null;
        }
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;

        base: Inst,
        condition: *Inst,
        then_body: Body,
        else_body: Body,
        /// Set of instructions whose lifetimes end at the start of one of the branches.
        /// The `then` branch is first: `deaths[0..then_death_count]`.
        /// The `else` branch is next: `(deaths + then_death_count)[0..else_death_count]`.
        deaths: [*]*Inst = undefined,
        then_death_count: u32 = 0,
        else_death_count: u32 = 0,

        pub fn operandCount(self: *const CondBr) usize {
            return 1;
        }
        pub fn getOperand(self: *const CondBr, index: usize) ?*Inst {
            var i = index;

            if (i < 1)
                return self.condition;
            i -= 1;

            return null;
        }
        pub fn thenDeaths(self: *const CondBr) []*Inst {
            return self.deaths[0..self.then_death_count];
        }
        pub fn elseDeaths(self: *const CondBr) []*Inst {
            return (self.deaths + self.then_death_count)[0..self.else_death_count];
        }
    };

    pub const Constant = struct {
        pub const base_tag = Tag.constant;

        base: Inst,
        val: Value,

        pub fn operandCount(self: *const Constant) usize {
            return 0;
        }
        pub fn getOperand(self: *const Constant, index: usize) ?*Inst {
            return null;
        }
    };

    pub const Loop = struct {
        pub const base_tag = Tag.loop;

        base: Inst,
        body: Body,

        pub fn operandCount(self: *const Loop) usize {
            return 0;
        }
        pub fn getOperand(self: *const Loop, index: usize) ?*Inst {
            return null;
        }
    };

    pub const VarPtr = struct {
        pub const base_tag = Tag.varptr;

        base: Inst,
        variable: *Module.Var,

        pub fn operandCount(self: *const VarPtr) usize {
            return 0;
        }
        pub fn getOperand(self: *const VarPtr, index: usize) ?*Inst {
            return null;
        }
    };

    pub const StructFieldPtr = struct {
        pub const base_tag = Tag.struct_field_ptr;

        base: Inst,
        struct_ptr: *Inst,
        field_index: usize,

        pub fn operandCount(self: *const StructFieldPtr) usize {
            return 1;
        }
        pub fn getOperand(self: *const StructFieldPtr, index: usize) ?*Inst {
            var i = index;

            if (i < 1)
                return self.struct_ptr;
            i -= 1;

            return null;
        }
    };

    pub const SwitchBr = struct {
        pub const base_tag = Tag.switchbr;

        base: Inst,
        target: *Inst,
        cases: []Case,
        /// Set of instructions whose lifetimes end at the start of one of the cases.
        /// In same order as cases, deaths[0..case_0_count, case_0_count .. case_1_count, ... ].
        deaths: [*]*Inst = undefined,
        else_index: u32 = 0,
        else_deaths: u32 = 0,
        else_body: Body,

        pub const Case = struct {
            item: Value,
            body: Body,
            index: u32 = 0,
            deaths: u32 = 0,
        };

        pub fn operandCount(self: *const SwitchBr) usize {
            return 1;
        }
        pub fn getOperand(self: *const SwitchBr, index: usize) ?*Inst {
            var i = index;

            if (i < 1)
                return self.target;
            i -= 1;

            return null;
        }
        pub fn caseDeaths(self: *const SwitchBr, case_index: usize) []*Inst {
            const case = self.cases[case_index];
            return (self.deaths + case.index)[0..case.deaths];
        }
        pub fn elseDeaths(self: *const SwitchBr) []*Inst {
            return (self.deaths + self.else_index)[0..self.else_deaths];
        }
    };

    pub const DbgStmt = struct {
        pub const base_tag = Tag.dbg_stmt;

        base: Inst,
        line: u32,
        column: u32,

        pub fn operandCount(self: *const DbgStmt) usize {
            return 0;
        }
        pub fn getOperand(self: *const DbgStmt, index: usize) ?*Inst {
            return null;
        }
    };
};

pub const Body = struct {
    instructions: []*Inst,
};

/// For debugging purposes, prints a function representation to stderr.
pub fn dumpFn(old_module: Module, module_fn: *Module.Fn) void {
    const allocator = old_module.gpa;
    var ctx: DumpTzir = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .module_fn = module_fn,
        .indent = 2,
        .inst_table = DumpTzir.InstTable.init(allocator),
        .partial_inst_table = DumpTzir.InstTable.init(allocator),
        .const_table = DumpTzir.InstTable.init(allocator),
    };
    defer ctx.inst_table.deinit();
    defer ctx.partial_inst_table.deinit();
    defer ctx.const_table.deinit();
    defer ctx.arena.deinit();

    switch (module_fn.state) {
        .queued => std.debug.print("(queued)", .{}),
        .inline_only => std.debug.print("(inline_only)", .{}),
        .in_progress => std.debug.print("(in_progress)", .{}),
        .sema_failure => std.debug.print("(sema_failure)", .{}),
        .dependency_failure => std.debug.print("(dependency_failure)", .{}),
        .success => {
            const writer = std.io.getStdErr().writer();
            ctx.dump(module_fn.body, writer) catch @panic("failed to dump TZIR");
        },
    }
}

const DumpTzir = struct {
    allocator: *std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const Module,
    module_fn: *Module.Fn,
    indent: usize,
    inst_table: InstTable,
    partial_inst_table: InstTable,
    const_table: InstTable,
    next_index: usize = 0,
    next_partial_index: usize = 0,
    next_const_index: usize = 0,

    const InstTable = std.AutoArrayHashMap(*Inst, usize);

    /// TODO: Improve this code to include a stack of Body and store the instructions
    /// in there. Now we are putting all the instructions in a function local table,
    /// however instructions that are in a Body can be thown away when the Body ends.
    fn dump(dtz: *DumpTzir, body: Body, writer: std.fs.File.Writer) !void {
        // First pass to pre-populate the table so that we can show even invalid references.
        // Must iterate the same order we iterate the second time.
        // We also look for constants and put them in the const_table.
        try dtz.fetchInstsAndResolveConsts(body);

        std.debug.print("Module.Function(name={s}):\n", .{dtz.module_fn.owner_decl.name});

        for (dtz.const_table.items()) |entry| {
            const constant = entry.key.castTag(.constant).?;
            try writer.print("  @{d}: {} = {};\n", .{
                entry.value, constant.base.ty, constant.val,
            });
        }

        return dtz.dumpBody(body, writer);
    }

    fn fetchInstsAndResolveConsts(dtz: *DumpTzir, body: Body) error{OutOfMemory}!void {
        for (body.instructions) |inst| {
            try dtz.inst_table.put(inst, dtz.next_index);
            dtz.next_index += 1;
            switch (inst.tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                .dbg_stmt,
                .arg,
                => {},

                .ref,
                .ret,
                .bitcast,
                .not,
                .is_non_null,
                .is_non_null_ptr,
                .is_null,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .error_to_int,
                .int_to_error,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .optional_payload,
                .optional_payload_ptr,
                .wrap_optional,
                .wrap_errunion_payload,
                .wrap_errunion_err,
                .unwrap_errunion_payload,
                .unwrap_errunion_err,
                .unwrap_errunion_payload_ptr,
                .unwrap_errunion_err_ptr,
                => {
                    const un_op = inst.cast(Inst.UnOp).?;
                    try dtz.findConst(un_op.operand);
                },

                .add,
                .addwrap,
                .sub,
                .subwrap,
                .mul,
                .mulwrap,
                .div,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                .bool_and,
                .bool_or,
                .bit_and,
                .bit_or,
                .xor,
                => {
                    const bin_op = inst.cast(Inst.BinOp).?;
                    try dtz.findConst(bin_op.lhs);
                    try dtz.findConst(bin_op.rhs);
                },

                .br => {
                    const br = inst.castTag(.br).?;
                    try dtz.findConst(&br.block.base);
                    try dtz.findConst(br.operand);
                },

                .br_block_flat => {
                    const br_block_flat = inst.castTag(.br_block_flat).?;
                    try dtz.findConst(&br_block_flat.block.base);
                    try dtz.fetchInstsAndResolveConsts(br_block_flat.body);
                },

                .br_void => {
                    const br_void = inst.castTag(.br_void).?;
                    try dtz.findConst(&br_void.block.base);
                },

                .block => {
                    const block = inst.castTag(.block).?;
                    try dtz.fetchInstsAndResolveConsts(block.body);
                },

                .condbr => {
                    const condbr = inst.castTag(.condbr).?;
                    try dtz.findConst(condbr.condition);
                    try dtz.fetchInstsAndResolveConsts(condbr.then_body);
                    try dtz.fetchInstsAndResolveConsts(condbr.else_body);
                },
                .switchbr => {
                    const switchbr = inst.castTag(.switchbr).?;
                    try dtz.findConst(switchbr.target);
                    try dtz.fetchInstsAndResolveConsts(switchbr.else_body);
                    for (switchbr.cases) |case| {
                        try dtz.fetchInstsAndResolveConsts(case.body);
                    }
                },

                .loop => {
                    const loop = inst.castTag(.loop).?;
                    try dtz.fetchInstsAndResolveConsts(loop.body);
                },
                .call => {
                    const call = inst.castTag(.call).?;
                    try dtz.findConst(call.func);
                    for (call.args) |arg| {
                        try dtz.findConst(arg);
                    }
                },
                .struct_field_ptr => {
                    const struct_field_ptr = inst.castTag(.struct_field_ptr).?;
                    try dtz.findConst(struct_field_ptr.struct_ptr);
                },

                // TODO fill out this debug printing
                .assembly,
                .constant,
                .varptr,
                => {},
            }
        }
    }

    fn dumpBody(dtz: *DumpTzir, body: Body, writer: std.fs.File.Writer) (std.fs.File.WriteError || error{OutOfMemory})!void {
        for (body.instructions) |inst| {
            const my_index = dtz.next_partial_index;
            try dtz.partial_inst_table.put(inst, my_index);
            dtz.next_partial_index += 1;

            try writer.writeByteNTimes(' ', dtz.indent);
            try writer.print("%{d}: {} = {s}(", .{
                my_index, inst.ty, @tagName(inst.tag),
            });
            switch (inst.tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                .dbg_stmt,
                => try writer.writeAll(")\n"),

                .ref,
                .ret,
                .bitcast,
                .not,
                .is_non_null,
                .is_null,
                .is_non_null_ptr,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .error_to_int,
                .int_to_error,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .optional_payload,
                .optional_payload_ptr,
                .wrap_optional,
                .wrap_errunion_err,
                .wrap_errunion_payload,
                .unwrap_errunion_err,
                .unwrap_errunion_payload,
                .unwrap_errunion_payload_ptr,
                .unwrap_errunion_err_ptr,
                => {
                    const un_op = inst.cast(Inst.UnOp).?;
                    const kinky = try dtz.writeInst(writer, un_op.operand);
                    if (kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .add,
                .addwrap,
                .sub,
                .subwrap,
                .mul,
                .mulwrap,
                .div,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                .bool_and,
                .bool_or,
                .bit_and,
                .bit_or,
                .xor,
                => {
                    const bin_op = inst.cast(Inst.BinOp).?;

                    const lhs_kinky = try dtz.writeInst(writer, bin_op.lhs);
                    try writer.writeAll(", ");
                    const rhs_kinky = try dtz.writeInst(writer, bin_op.rhs);

                    if (lhs_kinky != null or rhs_kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (lhs_kinky) |lhs| {
                            try writer.print(" %{d}", .{lhs});
                        }
                        if (rhs_kinky) |rhs| {
                            try writer.print(" %{d}", .{rhs});
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .arg => {
                    const arg = inst.castTag(.arg).?;
                    try writer.print("{s})\n", .{arg.name});
                },

                .br => {
                    const br = inst.castTag(.br).?;

                    const lhs_kinky = try dtz.writeInst(writer, &br.block.base);
                    try writer.writeAll(", ");
                    const rhs_kinky = try dtz.writeInst(writer, br.operand);

                    if (lhs_kinky != null or rhs_kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (lhs_kinky) |lhs| {
                            try writer.print(" %{d}", .{lhs});
                        }
                        if (rhs_kinky) |rhs| {
                            try writer.print(" %{d}", .{rhs});
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .br_block_flat => {
                    const br_block_flat = inst.castTag(.br_block_flat).?;
                    const block_kinky = try dtz.writeInst(writer, &br_block_flat.block.base);
                    if (block_kinky != null) {
                        try writer.writeAll(", { // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(", {\n");
                    }

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(br_block_flat.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .br_void => {
                    const br_void = inst.castTag(.br_void).?;
                    const kinky = try dtz.writeInst(writer, &br_void.block.base);
                    if (kinky) |_| {
                        try writer.writeAll(") // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .block => {
                    const block = inst.castTag(.block).?;

                    try writer.writeAll("{\n");

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(block.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .condbr => {
                    const condbr = inst.castTag(.condbr).?;

                    const condition_kinky = try dtz.writeInst(writer, condbr.condition);
                    if (condition_kinky != null) {
                        try writer.writeAll(", { // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(", {\n");
                    }

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(condbr.then_body, writer);

                    try writer.writeByteNTimes(' ', old_indent);
                    try writer.writeAll("}, {\n");

                    try dtz.dumpBody(condbr.else_body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', old_indent);
                    try writer.writeAll("})\n");
                },

                .switchbr => {
                    const switchbr = inst.castTag(.switchbr).?;

                    const condition_kinky = try dtz.writeInst(writer, switchbr.target);
                    if (condition_kinky != null) {
                        try writer.writeAll(", { // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(", {\n");
                    }
                    const old_indent = dtz.indent;

                    if (switchbr.else_body.instructions.len != 0) {
                        dtz.indent += 2;
                        try dtz.dumpBody(switchbr.else_body, writer);

                        try writer.writeByteNTimes(' ', old_indent);
                        try writer.writeAll("}, {\n");
                        dtz.indent = old_indent;
                    }
                    for (switchbr.cases) |case| {
                        dtz.indent += 2;
                        try dtz.dumpBody(case.body, writer);

                        try writer.writeByteNTimes(' ', old_indent);
                        try writer.writeAll("}, {\n");
                        dtz.indent = old_indent;
                    }

                    try writer.writeByteNTimes(' ', old_indent);
                    try writer.writeAll("})\n");
                },

                .loop => {
                    const loop = inst.castTag(.loop).?;

                    try writer.writeAll("{\n");

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(loop.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .call => {
                    const call = inst.castTag(.call).?;

                    const args_kinky = try dtz.allocator.alloc(?usize, call.args.len);
                    defer dtz.allocator.free(args_kinky);
                    std.mem.set(?usize, args_kinky, null);
                    var any_kinky_args = false;

                    const func_kinky = try dtz.writeInst(writer, call.func);

                    for (call.args) |arg, i| {
                        try writer.writeAll(", ");

                        args_kinky[i] = try dtz.writeInst(writer, arg);
                        any_kinky_args = any_kinky_args or args_kinky[i] != null;
                    }

                    if (func_kinky != null or any_kinky_args) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (func_kinky) |func_index| {
                            try writer.print(" %{d}", .{func_index});
                        }
                        for (args_kinky) |arg_kinky| {
                            if (arg_kinky) |arg_index| {
                                try writer.print(" %{d}", .{arg_index});
                            }
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .struct_field_ptr => {
                    const struct_field_ptr = inst.castTag(.struct_field_ptr).?;
                    const kinky = try dtz.writeInst(writer, struct_field_ptr.struct_ptr);
                    if (kinky != null) {
                        try writer.print("{d}) // Instruction does not dominate all uses!\n", .{
                            struct_field_ptr.field_index,
                        });
                    } else {
                        try writer.print("{d})\n", .{struct_field_ptr.field_index});
                    }
                },

                // TODO fill out this debug printing
                .assembly,
                .constant,
                .varptr,
                => {
                    try writer.writeAll("!TODO!)\n");
                },
            }
        }
    }

    fn writeInst(dtz: *DumpTzir, writer: std.fs.File.Writer, inst: *Inst) !?usize {
        if (dtz.partial_inst_table.get(inst)) |operand_index| {
            try writer.print("%{d}", .{operand_index});
            return null;
        } else if (dtz.const_table.get(inst)) |operand_index| {
            try writer.print("@{d}", .{operand_index});
            return null;
        } else if (dtz.inst_table.get(inst)) |operand_index| {
            try writer.print("%{d}", .{operand_index});
            return operand_index;
        } else {
            try writer.writeAll("!BADREF!");
            return null;
        }
    }

    fn findConst(dtz: *DumpTzir, operand: *Inst) !void {
        if (operand.tag == .constant) {
            try dtz.const_table.put(operand, dtz.next_const_index);
            dtz.next_const_index += 1;
        }
    }
};
