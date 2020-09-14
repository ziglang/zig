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
    /// Byte offset into the source.
    src: usize,

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
        alloc,
        arg,
        assembly,
        bitcast,
        block,
        br,
        breakpoint,
        brvoid,
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
        isnonnull,
        isnull,
        iserr,
        /// Read a value from a pointer.
        load,
        loop,
        ptrtoint,
        ref,
        ret,
        retvoid,
        varptr,
        /// Write a value to a pointer. LHS is pointer, RHS is value.
        store,
        sub,
        unreach,
        not,
        floatcast,
        intcast,
        unwrap_optional,
        wrap_optional,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                .dbg_stmt,
                => NoOp,

                .ref,
                .ret,
                .bitcast,
                .not,
                .isnonnull,
                .isnull,
                .iserr,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .unwrap_optional,
                .wrap_optional,
                => UnOp,

                .add,
                .sub,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                => BinOp,

                .arg => Arg,
                .assembly => Assembly,
                .block => Block,
                .br => Br,
                .brvoid => BrVoid,
                .call => Call,
                .condbr => CondBr,
                .constant => Constant,
                .loop => Loop,
                .varptr => VarPtr,
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
        return std.meta.fieldInfo(T, "args").field_type;
    }

    /// Returns `null` if runtime-known.
    pub fn value(base: *Inst) ?Value {
        if (base.ty.onePossibleValue()) |opv| return opv;

        const inst = base.cast(Constant) orelse return null;
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
            .brvoid => base.castTag(.brvoid).?.block,
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
        output: ?[]const u8,
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

    pub const Br = struct {
        pub const base_tag = Tag.br;

        base: Inst,
        block: *Block,
        operand: *Inst,

        pub fn operandCount(self: *const Br) usize {
            return 0;
        }
        pub fn getOperand(self: *const Br, index: usize) ?*Inst {
            if (index == 0)
                return self.operand;
            return null;
        }
    };

    pub const BrVoid = struct {
        pub const base_tag = Tag.brvoid;

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
};

pub const Body = struct {
    instructions: []*Inst,
};
