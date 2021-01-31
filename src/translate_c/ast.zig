const std = @import("std");
const Type = @import("../type.zig").Type;

pub const Node = struct {
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
        // After this, the tag requires a payload.

        int,
        float,
        string,
        char,
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

        pub const last_no_payload_tag = Tag.false_literal;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(tag: Tag) ?type {
            return switch (tag) {
                .null_literal,
                .undefined_literal,
                .opaque_literal,
                .true_literal,
                .false_litral,
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),

                .int,
                .float,
                .string,
                .char,
                .identifier,
                .field_access,
                .field_access_arrow,
                .warning,
                .failed_decl,
                => Payload.Value,
                .@"if" => Payload.If,
                .@"while" => Payload.While,
                .@"switch" => Payload.Switch,
                .@"break" => Payload.Break,
                .call => Payload.Call,
                .array_access,
                .std_mem_zeroes,
                .@"return",
                .discard,
                => Payload.SingleArg,
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
            lhs: *Node,
            rhs: *Node,
        },
    };

    pub const Value = struct {
        base: Node,
        data: []const u8,
    };

    pub const SingleArg = struct {
        base: Node,
        data: *Node,
    };

    pub const If = struct {
        base: Node = .{ .tag = .@"if" },
        data: struct {
            cond: *Node,
            then: *Node,
            @"else": ?*Node,
        },
    };

    pub const While = struct {
        base: Node = .{ .tag = .@"while" },
        data: struct {
            cond: *Node,
            body: *Node,
        },
    };

    pub const Switch = struct {
        base: Node = .{ .tag = .@"switch" },
        data: struct {
            cond: *Node,
            cases: []Prong,
            default: ?[]const u8,

            pub const Prong = struct {
                lhs: *Node,
                rhs: ?*Node,
                label: []const u8,
            };
        },
    };

    pub const Break = struct {
        base: Node = .{ .tag = .@"break" },
        data: struct {
            label: ?[]const u8,
            rhs: ?*Node,
        },
    };

    pub const Call = struct {
        base: Node = .{.call},
        data: struct {
            lhs: *Node,
            args: []*Node,
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
            init: *Node,
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
            body: ?*Node,

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
        data: []*Node,
    };

    pub const ContainerInit = struct {
        base: Node = .{ .tag = .container_init },
        data: []Initializer,

        pub const Initializer = struct {
            name: []const u8,
            value: *Node,
        };
    };

    pub const Block = struct {
        base: Node = .{ .tag = .block },
        data: struct {
            label: ?[]const u8,
            stmts: []*Node,
        },
    };
};

/// Converts the nodes into a Zig ast and then renders it.
pub fn render(allocator: *Allocator, nodes: []const Node) !void {
    @panic("TODO");
}
