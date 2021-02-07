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
        return_void,
        zero_literal,
        void_type,
        noreturn_type,
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

        log2_int_type,
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
        /// @as(lhs, rhs)
        as,

        negate,
        negate_wrap,
        bit_not,
        not,
        address_of,
        // operand.?.*
        unwrap_deref,

        block,
        @"break",

        sizeof,
        alignof,
        type,

        optional_type,
        c_pointer,
        single_pointer,
        array_type,


        // pub const name = @compileError(msg);
        fail_decl,
        // var actual = mangled;
        arg_redecl,

        pub const last_no_payload_tag = Tag.usingnamespace_builtins;
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
                .return_void,
                .zero_literal,
                .void_type,
                .noreturn_type,
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
                .address_of,
                .unwrap_deref,
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
                .as,
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
                .fail_decl,
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
                .c_pointer => Payload.Pointer,
                .single_pointer => Payload.Pointer,
                .array_type => Payload.Array,
                .arg_redecl => Payload.ArgRedecl,
                .log2_int_type => Payload.Log2IntType,
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
            return @intToEnum(Tag, @intCast(@TagType(Tag), self.tag_if_small_enough));
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
            is_pub: bool,
            is_extern: bool,
            is_export: bool,
            is_var_args: bool,
            name: []const u8,
            link_section_string: ?[]const u8,
            explicit_callconv: ?std.builtin.CallingConvention,
            params: []Param,
            return_type: Node,
            body: ?Node,
            alignment: c_uint,

            pub const Param = struct {
                is_noalias: bool,
                name: ?[]const u8,
                type: Node,
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

    pub const Array = struct {
        base: Node,
        data: struct {
            elem_type: Node,
            len: Node,
        },
    };

    pub const Pointer = struct {
        base: Node,
        data: struct {
            elem_type: Node,
            is_const: bool,
            is_volatile: bool,
        },
    };

    pub const ArgRedecl = struct {
        base: Node,
        data: struct {
            actual: []const u8,
            mangled: []const u8,
        },
    };

    pub const Log2IntType = struct {
        base: Node,
        data: std.math.Log2Int(u64),
    };
};

/// Converts the nodes into a Zig ast.
pub fn render(allocator: *Allocator, nodes: []const Node) !*ast.Tree {
    @panic("TODO");
}
