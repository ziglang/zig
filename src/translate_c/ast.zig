const std = @import("std");
const Type = @import("../type.zig").Type;

pub const Node = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub const Tag = enum {
        null_literal,
        undefined_literal,
        opaque_literal,
        true_literal,
        false_literal,
        empty_block,
        /// pub usingnamespace @import("std").c.builtins;
        usingnamespace_builtins,
        // After this, the tag requires a payload.

        int_literal,
        float_literal,
        string_literal,
        char_literal,
        identifier,
        @"if",
        @"while",
        @"switch",
        @"continue",
        @"break",
        @"return",
        field_access,
        field_access_arrow,
        array_access,
        call,
        std_mem_zeroes,
        var_decl,
        func,
        warning,
        failed_decl,
        @"enum",
        @"struct",
        @"union",
        array_init,
        container_init,
        std_meta_cast,
        discard,
        block,

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
        bit_or,
        bit_xor,

        /// @import("std").math.Log2Int(operand)
        std_math_Log2Int,
        /// @intCast(lhs, rhs)
        int_cast,
        /// @rem(lhs, rhs)
        rem,
        /// @divTrunc(lhs, rhs)
        div_trunc,
        /// @boolToInt(lhs, rhs)
        bool_to_int,

        negate,
        negate_wrap,
        bit_not,
        not,

        block,
        @"break",

        sizeof,
        alignof,
        type,

        optional_type,
        c_pointer,
        single_pointer,
        array_type,

        pub const last_no_payload_tag = Tag.false_literal;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(tag: Tag) ?type {
            return switch (tag) {
                .null_literal,
                .undefined_literal,
                .opaque_literal,
                .true_literal,
                .false_litral,
                .empty_block,
                .usingnamespace_builtins,
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),

                .array_access,
                .std_mem_zeroes,
                .@"return",
                .discard,
                .std_math_Log2Int,
                .negate,
                .negate_wrap,
                .bit_not,
                .not,
                .optional_type,
                .c_pointer,
                .single_pointer,
                .array_type,
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
                .bit_or,
                .bit_xor,
                .div_trunc,
                .rem,
                .int_cast,
                .bool_to_int,
                => Payload.BinOp,

                .int,
                .float,
                .string,
                .char,
                .identifier,
                .field_access,
                .field_access_arrow,
                .warning,
                .failed_decl,
                .sizeof,
                .alignof,
                .type,
                => Payload.Value,
                .@"if" => Payload.If,
                .@"while" => Payload.While,
                .@"switch" => Payload.Switch,
                .@"break" => Payload.Break,
                .call => Payload.Call,
                .var_decl => Payload.VarDecl,
                .func => Payload.Func,
                .@"enum" => Payload.Enum,
                .@"struct", .@"union" => Payload.Record,
                .array_init => Payload.ArrayInit,
                .container_init => Payload.ContainerInit,
                .std_meta_cast => Payload.Infix,
                .block => Payload.Block,
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
};

pub const Payload = struct {
    tag: Tag,

    pub const Infix = struct {
        base: Node,
        data: struct {
            lhs: Node,
            rhs: Node,
        },
    };

    pub const Value = struct {
        base: Node,
        data: []const u8,
    };

    pub const UnOp = struct {
        base: Node,
        data: Node,
    };

    pub const BinOp = struct {
        base: Node,
        data: struct {
            lhs: Node,
            rhs: Node,
        },
    };

    pub const If = struct {
        base: Node = .{ .tag = .@"if" },
        data: struct {
            cond: Node,
            then: Node,
            @"else": ?Node,
        },
    };

    pub const While = struct {
        base: Node = .{ .tag = .@"while" },
        data: struct {
            cond: Node,
            body: Node,
        },
    };

    pub const Switch = struct {
        base: Node = .{ .tag = .@"switch" },
        data: struct {
            cond: Node,
            cases: []Prong,
            default: ?[]const u8,

            pub const Prong = struct {
                lhs: Node,
                rhs: ?Node,
                label: []const u8,
            };
        },
    };

    pub const Break = struct {
        base: Node = .{ .tag = .@"break" },
        data: struct {
            label: ?[]const u8,
            rhs: ?Node,
        },
    };

    pub const Call = struct {
        base: Node = .{.call},
        data: struct {
            lhs: Node,
            args: []Node,
        },
    };

    pub const VarDecl = struct {
        base: Node = .{ .tag = .var_decl },
        data: struct {
            @"pub": bool,
            @"const": bool,
            @"extern": bool,
            @"export": bool,
            name: []const u8,
            type: Type,
            init: Node,
        },
    };

    pub const Func = struct {
        base: Node = .{.func},
        data: struct {
            @"pub": bool,
            @"extern": bool,
            @"export": bool,
            name: []const u8,
            cc: std.builtin.CallingConvention,
            params: []Param,
            return_type: Type,
            body: ?Node,

            pub const Param = struct {
                @"noalias": bool,
                name: ?[]const u8,
                type: Type,
            };
        },
    };

    pub const Enum = struct {
        base: Node = .{ .tag = .@"enum" },
        data: struct {
            name: ?[]const u8,
            fields: []Field,

            pub const Field = struct {
                name: []const u8,
                value: ?[]const u8,
            };
        },
    };

    pub const Record = struct {
        base: Node,
        data: struct {
            name: ?[]const u8,
            @"packed": bool,
            fields: []Field,

            pub const Field = struct {
                name: []const u8,
                type: Type,
                alignment: c_uint,
            };
        },
    };

    pub const ArrayInit = struct {
        base: Node = .{ .tag = .array_init },
        data: []Node,
    };

    pub const ContainerInit = struct {
        base: Node = .{ .tag = .container_init },
        data: []Initializer,

        pub const Initializer = struct {
            name: []const u8,
            value: Node,
        };
    };

    pub const Block = struct {
        base: Node,
        data: struct {
            label: ?[]const u8,
            stmts: []Node
        },
    };

    pub const Break = struct {
        base: Node = .{ .tag = .@"break" },
        data: *Block
    };
};

/// Converts the nodes into a Zig ast and then renders it.
pub fn render(allocator: *Allocator, nodes: []const Node) !void {
    @panic("TODO");
}
