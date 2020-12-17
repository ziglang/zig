const std = @import("std");
const Type = @import("../type.zig").Type;

pub const Node = struct {
    tag: Tag,
    // type: Type = Type.initTag(.noreturn),

    pub const Tag = enum {
        null_literal,
        undefined_literal,
        opaque_literal,
        bool_literal,
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

        pub fn Type(tag: Tag) ?type {
            return switch (tag) {
                .null_literal => null,
                .undefined_literal => null,
                .opaque_literal => null,
                .bool_literal,
                .int,
                .float,
                .string,
                .char,
                .identifier,
                .field_access,
                .field_access_arrow,
                .warning,
                .failed_decl,
                => Value,
                .@"if" => If,
                .@"while" => While,
                .@"switch" => Switch,
                .@"break" => Break,
                .call => Call,
                .array_access,
                .std_mem_zeroes,
                .@"return",
                .discard,
                => SingleArg,
                .var_decl => VarDecl,
                .func => Func,
                .@"enum" => Enum,
                .@"struct", .@"union" => Record,
                .array_init => ArrayInit,
                .container_init => ContainerInit,
                .std_meta_cast => Infix,
                .block => Block,
            };
        }
    };

    pub const Infix = struct {
        base: Node,
        lhs: *Node,
        rhs: *Node,
    };

    pub const Value = struct {
        base: Node,
        val: []const u8,
    };

    pub const SingleArg = struct {
        base: Node,
        index: *Node,
    };

    pub const If = struct {
        base: Node = .{ .tag = .@"if" },
        cond: *Node,
        then: *Node,
        @"else": ?*Node,
    };

    pub const While = struct {
        base: Node = .{ .tag = .@"while" },
        cond: *Node,
        body: *Node,
    };

    pub const Switch = struct {
        base: Node = .{ .tag = .@"switch" },
        cond: *Node,
        cases: []Prong,
        default: ?[]const u8,

        pub const Prong = struct {
            lhs: *Node,
            rhs: ?*Node,
            label: []const u8,
        };
    };

    pub const Break = struct {
        base: Node = .{ .tag = .@"break" },
        label: ?[]const u8,
        rhs: ?*Node,
    };

    pub const Call = struct {
        base: Node = .{.call},
        lhs: *Node,
        args: []*Node,
    };

    pub const VarDecl = struct {
        base: Node = .{ .tag = .var_decl },
        @"pub": bool,
        @"const": bool,
        @"extern": bool,
        @"export": bool,
        name: []const u8,
        type: Type,
        init: *Node,
    };

    pub const Func = struct {
        base: Node = .{.func},
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
    };

    pub const Enum = struct {
        base: Node = .{ .tag = .@"enum" },
        name: ?[]const u8,
        fields: []Field,

        pub const Field = struct {
            name: []const u8,
            value: ?[]const u8,
        };
    };

    pub const Record = struct {
        base: Node,
        name: ?[]const u8,
        @"packed": bool,
        fields: []Field,

        pub const Field = struct {
            name: []const u8,
            type: Type,
            alignment: c_uint,
        };
    };

    pub const ArrayInit = struct {
        base: Node = .{ .tag = .array_init },
        values: []*Node,
    };

    pub const ContainerInit = struct {
        base: Node = .{ .tag = .container_init },
        values: []Initializer,

        pub const Initializer = struct {
            name: []const u8,
            value: *Node,
        };
    };

    pub const Block = struct {
        base: Node = .{ .tag = .block },
        label: ?[]const u8,
        stmts: []*Node,
    };
};
