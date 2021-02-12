const std = @import("std");
const Type = @import("../type.zig").Type;
const Allocator = std.mem.Allocator;

pub const Node = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub const Tag = enum {
        null_literal,
        undefined_literal,
        /// opaque {}
        opaque_literal,
        true_literal,
        false_literal,
        empty_block,
        return_void,
        zero_literal,
        one_literal,
        void_type,
        noreturn_type,
        @"anytype",
        @"continue",
        /// pub usingnamespace @import("std").c.builtins;
        usingnamespace_builtins,
        // After this, the tag requires a payload.

        // int or float, doesn't really matter
        number_literal,
        string_literal,
        char_literal,
        identifier,
        @"if",
        /// if (!operand) break;
        if_not_break,
        @"while",
        /// while (true) operand
        while_true,
        @"switch",
        /// else => operand,
        switch_else,
        /// lhs => rhs,
        switch_prong,
        @"break",
        break_val,
        @"return",
        field_access,
        array_access,
        call,
        var_decl,
        func,
        warning,
        failed_decl,
        /// All enums are non-exhaustive
        @"enum",
        @"struct",
        @"union",
        array_init,
        tuple,
        container_init,
        std_meta_cast,
        discard,

        // a + b
        add,
        // a = b
        add_assign,
        // c = (a = b)
        add_assign_value,
        add_wrap,
        add_wrap_assign,
        add_wrap_assign_value,
        sub,
        sub_assign,
        sub_assign_value,
        sub_wrap,
        sub_wrap_assign,
        sub_wrap_assign_value,
        mul,
        mul_assign,
        mul_assign_value,
        mul_wrap,
        mul_wrap_assign,
        mul_wrap_assign_value,
        div,
        div_assign,
        div_assign_value,
        shl,
        shl_assign,
        shl_assign_value,
        shr,
        shr_assign,
        shr_assign_value,
        mod,
        mod_assign,
        mod_assign_value,
        @"and",
        and_assign,
        and_assign_value,
        @"or",
        or_assign,
        or_assign_value,
        xor,
        xor_assign,
        xor_assign_value,
        less_than,
        less_than_equal,
        greater_than,
        greater_than_equal,
        equal,
        not_equal,
        bit_and,
        bit_and_assign,
        bit_or,
        bit_or_assign,
        bit_xor,
        bit_xor_assign,
        array_cat,
        ellipsis3,
        assign,

        log2_int_type,
        /// @import("std").math.Log2Int(operand)
        std_math_Log2Int,
        /// @intCast(lhs, rhs)
        int_cast,
        /// @rem(lhs, rhs)
        rem,
        /// @divTrunc(lhs, rhs)
        div_trunc,
        /// @boolToInt(operand)
        bool_to_int,
        /// @as(lhs, rhs)
        as,
        /// @truncate(lhs, rhs)
        truncate,
        /// @bitCast(lhs, rhs)
        bit_cast,
        /// @floatCast(lhs, rhs)
        float_cast,
        /// @floatToInt(lhs, rhs)
        float_to_int,
        /// @intToFloat(lhs, rhs)
        int_to_float,
        /// @intToEnum(lhs, rhs)
        int_to_enum,
        /// @enumToInt(operand)
        enum_to_int,
        /// @intToPtr(lhs, rhs)
        int_to_ptr,
        /// @ptrToInt(operand)
        ptr_to_int,
        /// @alignCast(lhs, rhs)
        align_cast,
        /// @ptrCast(lhs, rhs)
        ptr_cast,

        negate,
        negate_wrap,
        bit_not,
        not,
        address_of,
        /// .?
        unwrap,
        /// .*
        deref,

        block,
        /// { operand }
        block_single,

        sizeof,
        alignof,
        typeof,
        type,

        optional_type,
        c_pointer,
        single_pointer,
        array_type,

        /// @import("std").meta.sizeof(operand)
        std_meta_sizeof,
        /// @import("std").mem.zeroes(operand)
        std_mem_zeroes,
        /// @import("std").mem.zeroInit(lhs, rhs)
        std_mem_zeroinit,
        // pub const name = @compileError(msg);
        fail_decl,
        // var actual = mangled;
        arg_redecl,
        /// pub const alias = actual;
        alias,
        /// const name = init;
        typedef,
        var_simple,
        /// pub const name = init;
        pub_typedef,
        pub_var_simple,
        /// pub const enum_field_name = @enumToInt(enum_name.field_name);
        enum_redecl,

        /// pub inline fn name(params) return_type body
        pub_inline_fn,

        /// [0]type{}
        empty_array,
        /// [1]type{val} ** count
        array_filler,

        /// _ = operand;
        ignore,

        pub const last_no_payload_tag = Tag.usingnamespace_builtins;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .null_literal,
                .undefined_literal,
                .opaque_literal,
                .true_literal,
                .false_literal,
                .empty_block,
                .usingnamespace_builtins,
                .return_void,
                .zero_literal,
                .one_literal,
                .void_type,
                .noreturn_type,
                .@"anytype",
                .@"continue",
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),

                .std_mem_zeroes,
                .@"return",
                .discard,
                .std_math_Log2Int,
                .negate,
                .negate_wrap,
                .bit_not,
                .not,
                .optional_type,
                .address_of,
                .unwrap,
                .deref,
                .ptr_to_int,
                .enum_to_int,
                .empty_array,
                .while_true,
                .if_not_break,
                .switch_else,
                .ignore,
                .block_single,
                .std_meta_sizeof,
                .bool_to_int,
                .sizeof,
                .alignof,
                .typeof,
                => Payload.UnOp,

                .add,
                .add_assign,
                .add_assign_value,
                .add_wrap,
                .add_wrap_assign,
                .add_wrap_assign_value,
                .sub,
                .sub_assign,
                .sub_assign_value,
                .sub_wrap,
                .sub_wrap_assign,
                .sub_wrap_assign_value,
                .mul,
                .mul_assign,
                .mul_assign_value,
                .mul_wrap,
                .mul_wrap_assign,
                .mul_wrap_assign_value,
                .div,
                .div_assign,
                .div_assign_value,
                .shl,
                .shl_assign,
                .shl_assign_value,
                .shr,
                .shr_assign,
                .shr_assign_value,
                .mod,
                .mod_assign,
                .mod_assign_value,
                .@"and",
                .and_assign,
                .and_assign_value,
                .@"or",
                .or_assign,
                .or_assign_value,
                .xor,
                .xor_assign,
                .xor_assign_value,
                .less_than,
                .less_than_equal,
                .greater_than,
                .greater_than_equal,
                .equal,
                .not_equal,
                .bit_and,
                .bit_and_assign,
                .bit_or,
                .bit_or_assign,
                .bit_xor,
                .bit_xor_assign,
                .div_trunc,
                .rem,
                .int_cast,
                .as,
                .truncate,
                .bit_cast,
                .float_cast,
                .float_to_int,
                .int_to_float,
                .int_to_enum,
                .int_to_ptr,
                .array_cat,
                .ellipsis3,
                .switch_prong,
                .field_access,
                .assign,
                .align_cast,
                .array_access,
                .std_mem_zeroinit,
                .ptr_cast,
                => Payload.BinOp,

                .number_literal,
                .string_literal,
                .char_literal,
                .identifier,
                .warning,
                .failed_decl,
                .type,
                .fail_decl,
                => Payload.Value,
                .@"if" => Payload.If,
                .@"while" => Payload.While,
                .@"switch" => Payload.Switch,
                .@"break" => Payload.Break,
                .break_val => Payload.BreakVal,
                .call => Payload.Call,
                .var_decl => Payload.VarDecl,
                .func => Payload.Func,
                .@"enum" => Payload.Enum,
                .@"struct", .@"union" => Payload.Record,
                .array_init, .tuple => Payload.ArrayInit,
                .container_init => Payload.ContainerInit,
                .std_meta_cast => Payload.Infix,
                .block => Payload.Block,
                .c_pointer, .single_pointer => Payload.Pointer,
                .array_type => Payload.Array,
                .arg_redecl, .alias => Payload.ArgRedecl,
                .log2_int_type => Payload.Log2IntType,
                .typedef, .pub_typedef, .var_simple, .pub_var_simple => Payload.SimpleVarDecl,
                .enum_redecl => Payload.EnumRedecl,
                .array_filler => Payload.ArrayFiller,
                .pub_inline_fn => Payload.PubInlineFn,
            };
        }

        pub fn init(comptime t: Tag) Node {
            comptime std.debug.assert(@enumToInt(t) < Tag.no_payload_count);
            return .{ .tag_if_small_enough = @enumToInt(t) };
        }

        pub fn create(comptime t: Tag, ally: *Allocator, data: Data(t)) error{OutOfMemory}!Node {
            const ptr = try ally.create(t.Type());
            ptr.* = .{
                .base = .{ .tag = t },
                .data = data,
            };
            return Node{ .ptr_otherwise = &ptr.base };
        }

        pub fn Data(comptime t: Tag) type {
            return std.meta.fieldInfo(t.Type(), .data).field_type;
        }
    };

    pub fn tag(self: Node) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(Tag, @intCast(std.meta.Tag(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn castTag(self: Node, comptime t: Tag) ?*t.Type() {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        if (self.ptr_otherwise.tag == t)
            return @fieldParentPtr(t.Type(), "base", self.ptr_otherwise);

        return null;
    }

    pub fn initPayload(payload: *Payload) Node {
        std.debug.assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }
};

pub const Payload = struct {
    tag: Node.Tag,

    pub const Infix = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            rhs: Node,
        },
    };

    pub const Value = struct {
        base: Payload,
        data: []const u8,
    };

    pub const UnOp = struct {
        base: Payload,
        data: Node,
    };

    pub const BinOp = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            rhs: Node,
        },
    };

    pub const If = struct {
        base: Payload,
        data: struct {
            cond: Node,
            then: Node,
            @"else": ?Node,
        },
    };

    pub const While = struct {
        base: Payload,
        data: struct {
            cond: Node,
            body: Node,
            cont_expr: ?Node
        },
    };

    pub const Switch = struct {
        base: Payload,
        data: struct {
            cond: Node,
            cases: []Node,
        },
    };

    pub const Break = struct {
        base: Payload,
        data: ?[]const u8,
    };

    pub const BreakVal = struct {
        base: Payload,
        data: struct {
            label: ?[]const u8,
            val: Node,
        },
    };

    pub const Call = struct {
        base: Payload,
        data: struct {
            lhs: Node,
            args: []Node,
        },
    };

    pub const VarDecl = struct {
        base: Payload,
        data: struct {
            is_pub: bool,
            is_const: bool,
            is_extern: bool,
            is_export: bool,
            alignment: ?c_uint,
            linksection_string: ?[]const u8,
            name: []const u8,
            type: Node,
            init: ?Node,
        },
    };

    pub const Func = struct {
        base: Payload,
        data: struct {
            is_pub: bool,
            is_extern: bool,
            is_export: bool,
            is_var_args: bool,
            name: ?[]const u8,
            linksection_string: ?[]const u8,
            explicit_callconv: ?std.builtin.CallingConvention,
            params: []Param,
            return_type: Node,
            body: ?Node,
            alignment: ?c_uint,
        },
    };

    pub const Param = struct {
        is_noalias: bool,
        name: ?[]const u8,
        type: Node,
    };

    pub const Enum = struct {
        base: Payload,
        data: []Field,

        pub const Field = struct {
            name: []const u8,
            value: ?Node,
        };
    };

    pub const Record = struct {
        base: Payload,
        data: struct {
            is_packed: bool,
            fields: []Field,
        },

        pub const Field = struct {
            name: []const u8,
            type: Node,
            alignment: ?c_uint,
        };
    };

    pub const ArrayInit = struct {
        base: Payload,
        data: []Node,
    };

    pub const ContainerInit = struct {
        base: Payload,
        data: []Initializer,

        pub const Initializer = struct {
            name: []const u8,
            value: Node,
        };
    };

    pub const Block = struct {
        base: Payload,
        data: struct {
            label: ?[]const u8,
            stmts: []Node
        },
    };

    pub const Array = struct {
        base: Payload,
        data: struct {
            elem_type: Node,
            len: usize,
        },
    };

    pub const Pointer = struct {
        base: Payload,
        data: struct {
            elem_type: Node,
            is_const: bool,
            is_volatile: bool,
        },
    };

    pub const ArgRedecl = struct {
        base: Payload,
        data: struct {
            actual: []const u8,
            mangled: []const u8,
        },
    };

    pub const Log2IntType = struct {
        base: Payload,
        data: std.math.Log2Int(u64),
    };

    pub const SimpleVarDecl = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            init: Node,
        },
    };

    pub const EnumRedecl = struct {
        base: Payload,
        data: struct {
            enum_val_name: []const u8,
            field_name: []const u8,
            enum_name: []const u8,
        },
    };

    pub const ArrayFiller = struct {
        base: Payload,
        data: struct {
            type: Node,
            filler: Node,
            count: usize,
        },
    };

    pub const PubInlineFn = struct {
        base: Payload,
        data: struct {
            name: []const u8,
            params: []Param,
            return_type: Node,
            body: Node,
        },
    };
};

/// Converts the nodes into a Zig ast.
pub fn render(allocator: *Allocator, nodes: []const Node) !std.zig.ast.Tree {
    @panic("TODO");
}
