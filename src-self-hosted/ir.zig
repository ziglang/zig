const std = @import("std");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const Module = @import("Module.zig");

/// These are in-memory, analyzed instructions. See `zir.Inst` for the representation
/// of instructions that correspond to the ZIR text format.
/// This struct owns the `Value` and `Type` memory. When the struct is deallocated,
/// so are the `Value` and `Type`. The value of a constant must be copied into
/// a memory location for the value to survive after a const instruction.
pub const Inst = struct {
    tag: Tag,
    /// Each bit represents the index of an `Inst` parameter in the `args` field.
    /// If a bit is set, it marks the end of the lifetime of the corresponding 
    /// instruction parameter. For example, 0b00000101 means that the first and
    /// third `Inst` parameters' lifetimes end after this instruction, and will
    /// not have any more following references.
    /// The most significant bit being set means that the instruction itself is
    /// never referenced, in other words its lifetime ends as soon as it finishes.
    /// If the byte is `0xff`, it means this is a special case and this data is
    /// encoded elsewhere.
    deaths: u8 = 0xff,
    ty: Type,
    /// Byte offset into the source.
    src: usize,

    pub const Tag = enum {
        add,
        arg,
        assembly,
        bitcast,
        block,
        breakpoint,
        call,
        cmp,
        condbr,
        constant,
        isnonnull,
        isnull,
        ptrtoint,
        ret,
        retvoid,
        unreach,

        /// Returns whether the instruction is one of the control flow "noreturn" types.
        /// Function calls do not count. When ZIR is generated, the compiler automatically
        /// emits an `Unreach` after a function call with the `noreturn` return type.
        pub fn isNoReturn(tag: Tag) bool {
            return switch (tag) {
                .add,
                .arg,
                .assembly,
                .bitcast,
                .block,
                .breakpoint,
                .cmp,
                .constant,
                .isnonnull,
                .isnull,
                .ptrtoint,
                .call,
                => false,

                .condbr,
                .ret,
                .retvoid,
                .unreach,
                => true,
            };
        }
    };

    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn Args(comptime T: type) type {
        return std.meta.fieldInfo(T, "args").field_type;
    }

    /// Returns `null` if runtime-known.
    pub fn value(base: *Inst) ?Value {
        if (base.ty.onePossibleValue())
            return Value.initTag(.the_one_possible_value);

        const inst = base.cast(Constant) orelse return null;
        return inst.val;
    }

    pub const Add = struct {
        pub const base_tag = Tag.add;
        base: Inst,

        args: struct {
            lhs: *Inst,
            rhs: *Inst,
        },
    };

    pub const Arg = struct {
        pub const base_tag = Tag.arg;
        base: Inst,

        args: struct {
            index: usize,
        },
    };

    pub const Assembly = struct {
        pub const base_tag = Tag.assembly;
        base: Inst,

        args: struct {
            asm_source: []const u8,
            is_volatile: bool,
            output: ?[]const u8,
            inputs: []const []const u8,
            clobbers: []const []const u8,
            args: []const *Inst,
        },
    };

    pub const BitCast = struct {
        pub const base_tag = Tag.bitcast;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const Block = struct {
        pub const base_tag = Tag.block;
        base: Inst,
        args: struct {
            body: Body,
        },
    };

    pub const Breakpoint = struct {
        pub const base_tag = Tag.breakpoint;
        base: Inst,
        args: void,
    };

    pub const Call = struct {
        pub const base_tag = Tag.call;
        base: Inst,
        args: struct {
            func: *Inst,
            args: []const *Inst,
        },
    };

    pub const Cmp = struct {
        pub const base_tag = Tag.cmp;

        base: Inst,
        args: struct {
            lhs: *Inst,
            op: std.math.CompareOperator,
            rhs: *Inst,
        },
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;

        base: Inst,
        args: struct {
            condition: *Inst,
            true_body: Body,
            false_body: Body,
        },
        /// Set of instructions whose lifetimes end at the start of one of the branches.
        /// The `true` branch is first: `deaths[0..true_death_count]`.
        /// The `false` branch is next: `(deaths + true_death_count)[..false_death_count]`.
        deaths: [*]*Inst = undefined,
        true_death_count: u32 = 0,
        false_death_count: u32 = 0,
    };

    pub const Constant = struct {
        pub const base_tag = Tag.constant;
        base: Inst,

        val: Value,
    };

    pub const IsNonNull = struct {
        pub const base_tag = Tag.isnonnull;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const IsNull = struct {
        pub const base_tag = Tag.isnull;

        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const PtrToInt = struct {
        pub const base_tag = Tag.ptrtoint;

        base: Inst,
        args: struct {
            ptr: *Inst,
        },
    };

    pub const Ret = struct {
        pub const base_tag = Tag.ret;
        base: Inst,
        args: struct {
            operand: *Inst,
        },
    };

    pub const RetVoid = struct {
        pub const base_tag = Tag.retvoid;
        base: Inst,
        args: void,
    };

    pub const Unreach = struct {
        pub const base_tag = Tag.unreach;
        base: Inst,
        args: void,
    };
};

pub const Body = struct {
    instructions: []*Inst,
};