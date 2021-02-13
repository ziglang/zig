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

        integer_literal,
        float_literal,
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
        /// All enums are non-exhaustive
        @"enum",
        @"struct",
        @"union",
        array_init,
        tuple,
        container_init,
        std_meta_cast,
        /// _ = operand;
        discard,

        // a + b
        add,
        // a = b
        add_assign,
        // c = (a = b)
        add_wrap,
        add_wrap_assign,
        sub,
        sub_assign,
        sub_wrap,
        sub_wrap_assign,
        mul,
        mul_assign,
        mul_wrap,
        mul_wrap_assign,
        div,
        div_assign,
        shl,
        shl_assign,
        shr,
        shr_assign,
        mod,
        mod_assign,
        @"and",
        @"or",
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
        var_simple,
        /// pub const name = init;
        pub_var_simple,
        /// pub const enum_field_name = @enumToInt(enum_name.field_name);
        enum_redecl,

        /// pub inline fn name(params) return_type body
        pub_inline_fn,

        /// [0]type{}
        empty_array,
        /// [1]type{val} ** count
        array_filler,

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
                .block_single,
                .std_meta_sizeof,
                .bool_to_int,
                .sizeof,
                .alignof,
                .typeof,
                => Payload.UnOp,

                .add,
                .add_assign,
                .add_wrap,
                .add_wrap_assign,
                .sub,
                .sub_assign,
                .sub_wrap,
                .sub_wrap_assign,
                .mul,
                .mul_assign,
                .mul_wrap,
                .mul_wrap_assign,
                .div,
                .div_assign,
                .shl,
                .shl_assign,
                .shr,
                .shr_assign,
                .mod,
                .mod_assign,
                .@"and",
                .@"or",
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

                .integer_literal,
                .float_literal,
                .string_literal,
                .char_literal,
                .identifier,
                .warning,
                .type,
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
                .arg_redecl, .alias, .fail_decl => Payload.ArgRedecl,
                .log2_int_type => Payload.Log2IntType,
                .var_simple, .pub_var_simple => Payload.SimpleVarDecl,
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
            cont_expr: ?Node,
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
            stmts: []Node,
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
/// Caller must free the source slice.
pub fn render(gpa: *Allocator, nodes: []const Node) !std.zig.ast.Tree {
    var ctx = Context{
        .gpa = gpa,
        .buf = std.ArrayList(u8).init(gpa),
    };
    defer ctx.buf.deinit();
    defer ctx.nodes.deinit(gpa);
    defer ctx.extra_data.deinit(gpa);
    defer ctx.tokens.deinit(gpa);

    // Estimate that each top level node has 25 child nodes.
    const estimated_node_count = nodes.len * 25;
    try ctx.nodes.ensureCapacity(gpa, estimated_node_count);

    ctx.nodes.appendAssumeCapacity(.{
        .tag = .root,
        .main_token = 0,
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    const root_members = try renderNodes(&ctx, nodes);
    ctx.nodes.items(.data)[0] = .{
        .lhs = root_members.start,
        .rhs = root_members.end,
    };

    try ctx.tokens.append(gpa, .{
        .tag = .eof,
        .start = @intCast(u32, ctx.buf.items.len),
    });

    return std.zig.ast.Tree{
        .source = ctx.buf.toOwnedSlice(),
        .tokens = ctx.tokens.toOwnedSlice(),
        .nodes = ctx.nodes.toOwnedSlice(),
        .extra_data = ctx.extra_data.toOwnedSlice(gpa),
        .errors = &.{},
    };
}

const NodeIndex = std.zig.ast.Node.Index;
const NodeSubRange = std.zig.ast.Node.SubRange;
const TokenIndex = std.zig.ast.TokenIndex;
const TokenTag = std.zig.Token.Tag;

const Context = struct {
    gpa: *Allocator,
    buf: std.ArrayList(u8) = .{},
    nodes: std.zig.ast.NodeList = .{},
    extra_data: std.ArrayListUnmanaged(std.zig.ast.Node.Index) = .{},
    tokens: std.zig.ast.TokenList = .{},

    fn addTokenFmt(c: *Context, tag: TokenTag, comptime format: []const u8, args: anytype) Allocator.Error!TokenIndex {
        const start_index = c.buf.items.len;
        try c.buf.writer().print(format ++ " ", args);

        try c.tokens.append(c.gpa, .{
            .tag = tag,
            .start = @intCast(u32, start_index),
        });

        return @intCast(u32, c.tokens.len - 1);
    }

    fn addToken(c: *Context, tag: TokenTag, bytes: []const u8) Allocator.Error!TokenIndex {
        return addTokenFmt(c, tag, "{s}", .{bytes});
    }

    fn addIdentifier(c: *Context, bytes: []const u8) Allocator.Error!TokenIndex {
        return addTokenFmt(c, .identifier, "{s}", .{std.zig.fmtId(bytes)});
    }

    fn listToSpan(c: *Context, list: []const NodeIndex) Allocator.Error!NodeSubRange {
        try c.extra_data.appendSlice(c.gpa, list);
        return NodeSubRange{
            .start = @intCast(NodeIndex, c.extra_data.items.len - list.len),
            .end = @intCast(NodeIndex, c.extra_data.items.len),
        };
    }

    fn addNode(c: *Context, elem: std.zig.ast.NodeList.Elem) Allocator.Error!NodeIndex {
        const result = @intCast(NodeIndex, c.nodes.len);
        try c.nodes.append(c.gpa, elem);
        return result;
    }

    fn addExtra(c: *Context, extra: anytype) Allocator.Error!NodeIndex {
        const fields = std.meta.fields(@TypeOf(extra));
        try c.extra_data.ensureCapacity(c.gpa, c.extra_data.items.len + fields.len);
        const result = @intCast(u32, c.extra_data.items.len);
        inline for (fields) |field| {
            comptime std.debug.assert(field.field_type == NodeIndex);
            c.extra_data.appendAssumeCapacity(@field(extra, field.name));
        }
        return result;
    }
};

fn renderNodes(c: *Context, nodes: []const Node) Allocator.Error!NodeSubRange {
    var result = std.ArrayList(NodeIndex).init(c.gpa);
    defer result.deinit();

    for (nodes) |node| {
        const res = try renderNode(c, node);
        if (node.tag() == .warning) continue;
        if (c.nodes.items(.tag)[res] == .identifier) continue; // TODO remove
        try result.append(res);
    }

    return try c.listToSpan(result.items);
}

fn renderNode(c: *Context, node: Node) Allocator.Error!NodeIndex {
    switch (node.tag()) {
        .warning => {
            const payload = node.castTag(.warning).?.data;
            try c.buf.appendSlice(payload);
            try c.buf.append('\n');
            return @as(NodeIndex, 0); // error: integer value 0 cannot be coerced to type 'std.mem.Allocator.Error!u32'
        },
        .usingnamespace_builtins => {
            // pub usingnamespace @import("std").c.builtins;
            _ = try c.addToken(.keyword_pub, "pub");
            const usingnamespace_token = try c.addToken(.keyword_usingnamespace, "usingnamespace");
            const import_node = try renderStdImport(c, "c", "builtins");
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .@"usingnamespace",
                .main_token = usingnamespace_token,
                .data = .{
                    .lhs = import_node,
                    .rhs = undefined,
                },
            });
        },
        .std_math_Log2Int => {
            const payload = node.castTag(.std_math_Log2Int).?.data;
            const import_node = try renderStdImport(c, "math", "Log2Int");
            return renderCall(c, import_node, &.{payload});
        },
        .std_meta_cast => {
            const payload = node.castTag(.std_meta_cast).?.data;
            const import_node = try renderStdImport(c, "meta", "cast");
            return renderCall(c, import_node, &.{ payload.lhs, payload.rhs });
        },
        .std_meta_sizeof => {
            const payload = node.castTag(.std_meta_sizeof).?.data;
            const import_node = try renderStdImport(c, "meta", "sizeof");
            return renderCall(c, import_node, &.{payload});
        },
        .std_mem_zeroes => {
            const payload = node.castTag(.std_mem_zeroes).?.data;
            const import_node = try renderStdImport(c, "mem", "zeroes");
            return renderCall(c, import_node, &.{payload});
        },
        .std_mem_zeroinit => {
            const payload = node.castTag(.std_mem_zeroinit).?.data;
            const import_node = try renderStdImport(c, "mem", "zeroInit");
            return renderCall(c, import_node, &.{ payload.lhs, payload.rhs });
        },
        .call => {
            const payload = node.castTag(.call).?.data;
            const lhs = try renderNode(c, payload.lhs);
            return renderCall(c, lhs, payload.args);
        },
        .null_literal => return c.addNode(.{
            .tag = .null_literal,
            .main_token = try c.addToken(.keyword_null, "null"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .undefined_literal => return c.addNode(.{
            .tag = .undefined_literal,
            .main_token = try c.addToken(.keyword_undefined, "undefined"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .true_literal => return c.addNode(.{
            .tag = .true_literal,
            .main_token = try c.addToken(.keyword_true, "true"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .false_literal => return c.addNode(.{
            .tag = .false_literal,
            .main_token = try c.addToken(.keyword_false, "false"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .zero_literal => return c.addNode(.{
            .tag = .integer_literal,
            .main_token = try c.addToken(.integer_literal, "0"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .one_literal => return c.addNode(.{
            .tag = .integer_literal,
            .main_token = try c.addToken(.integer_literal, "1"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .void_type => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "void"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .@"anytype" => return c.addNode(.{
            .tag = .@"anytype",
            .main_token = try c.addToken(.keyword_anytype, "anytype"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .noreturn_type => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addToken(.identifier, "noreturn"),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
        .@"continue" => {
            const tok = try c.addToken(.keyword_continue, "continue");
            _ = try c.addToken(.semicolon, ";");
            return c.addNode(.{
                .tag = .@"continue",
                .main_token = tok,
                .data = .{
                    .lhs = 0,
                    .rhs = undefined,
                },
            });
        },
        .@"break" => {
            const payload = node.castTag(.@"break").?.data;
            const tok = try c.addToken(.keyword_break, "break");
            const break_label = if (payload) |some| blk: {
                _ = try c.addToken(.colon, ":");
                break :blk try c.addIdentifier(some);
            } else 0;
            _ = try c.addToken(.semicolon, ";");
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.keyword_break, "break"),
                .data = .{
                    .lhs = break_label,
                    .rhs = 0,
                },
            });
        },
        .break_val => {
            const payload = node.castTag(.break_val).?.data;
            const tok = try c.addToken(.keyword_break, "break");
            const break_label = if (payload.label) |some| blk: {
                _ = try c.addToken(.colon, ":");
                break :blk try c.addIdentifier(some);
            } else 0;
            const val = try renderNode(c, payload.val);
            _ = try c.addToken(.semicolon, ";");
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.keyword_break, "break"),
                .data = .{
                    .lhs = break_label,
                    .rhs = val,
                },
            });
        },
        .type => {
            const payload = node.castTag(.type).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.identifier, payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .log2_int_type => {
            const payload = node.castTag(.log2_int_type).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addTokenFmt(.identifier, "u{d}", .{payload}),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .identifier => {
            const payload = node.castTag(.identifier).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addIdentifier(payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .float_literal => {
            const payload = node.castTag(.float_literal).?.data;
            return c.addNode(.{
                .tag = .float_literal,
                .main_token = try c.addToken(.float_literal, payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .integer_literal => {
            const payload = node.castTag(.integer_literal).?.data;
            return c.addNode(.{
                .tag = .integer_literal,
                .main_token = try c.addToken(.integer_literal, payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .string_literal => {
            const payload = node.castTag(.string_literal).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.string_literal, payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .char_literal => {
            const payload = node.castTag(.char_literal).?.data;
            return c.addNode(.{
                .tag = .identifier,
                .main_token = try c.addToken(.string_literal, payload),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        },
        .fail_decl => {
            const payload = node.castTag(.fail_decl).?.data;
            // pub const name = @compileError(msg);
            _ = try c.addToken(.keyword_pub, "pub");
            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.actual);
            _ = try c.addToken(.equal, "=");

            const compile_error_tok = try c.addToken(.builtin, "@compileError");
            _ = try c.addToken(.l_paren, "(");
            const err_msg_tok = try c.addTokenFmt(.string_literal, "\"{s}\"", .{std.zig.fmtEscapes(payload.mangled)});
            const err_msg = try c.addNode(.{
                .tag = .string_literal,
                .main_token = err_msg_tok,
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
            _ = try c.addToken(.r_paren, ")");
            const compile_error = try c.addNode(.{
                .tag = .builtin_call_two,
                .main_token = compile_error_tok,
                .data = .{
                    .lhs = err_msg,
                    .rhs = 0,
                },
            });
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{
                    .lhs = 0,
                    .rhs = compile_error,
                },
            });
        },
        .pub_var_simple, .var_simple => {
            const payload = @fieldParentPtr(Payload.SimpleVarDecl, "base", node.ptr_otherwise).data;
            if (node.tag() == .pub_var_simple) _ = try c.addToken(.keyword_pub, "pub");
            const const_tok = try c.addToken(.keyword_const, "const");
            _ = try c.addIdentifier(payload.name);
            _ = try c.addToken(.equal, "=");

            const init = try renderNode(c, payload.init);
            _ = try c.addToken(.semicolon, ";");

            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = const_tok,
                .data = .{
                    .lhs = 0,
                    .rhs = init,
                },
            });
        },
        .var_decl => return renderVar(c, node),
        .int_cast => {
            const payload = node.castTag(.int_cast).?.data;
            return renderBuiltinCall(c, "@intCast", &.{ payload.lhs, payload.rhs });
        },
        .rem => {
            const payload = node.castTag(.rem).?.data;
            return renderBuiltinCall(c, "@rem", &.{ payload.lhs, payload.rhs });
        },
        .div_trunc => {
            const payload = node.castTag(.div_trunc).?.data;
            return renderBuiltinCall(c, "@divTrunc", &.{ payload.lhs, payload.rhs });
        },
        .bool_to_int => {
            const payload = node.castTag(.bool_to_int).?.data;
            return renderBuiltinCall(c, "@boolToInt", &.{payload});
        },
        .as => {
            const payload = node.castTag(.as).?.data;
            return renderBuiltinCall(c, "@as", &.{ payload.lhs, payload.rhs });
        },
        .truncate => {
            const payload = node.castTag(.truncate).?.data;
            return renderBuiltinCall(c, "@truncate", &.{ payload.lhs, payload.rhs });
        },
        .bit_cast => {
            const payload = node.castTag(.bit_cast).?.data;
            return renderBuiltinCall(c, "@bitCast", &.{ payload.lhs, payload.rhs });
        },
        .float_cast => {
            const payload = node.castTag(.float_cast).?.data;
            return renderBuiltinCall(c, "@floatCast", &.{ payload.lhs, payload.rhs });
        },
        .float_to_int => {
            const payload = node.castTag(.float_to_int).?.data;
            return renderBuiltinCall(c, "@floatToInt", &.{ payload.lhs, payload.rhs });
        },
        .int_to_float => {
            const payload = node.castTag(.int_to_float).?.data;
            return renderBuiltinCall(c, "@intToFloat", &.{ payload.lhs, payload.rhs });
        },
        .int_to_enum => {
            const payload = node.castTag(.int_to_enum).?.data;
            return renderBuiltinCall(c, "@intToEnum", &.{ payload.lhs, payload.rhs });
        },
        .enum_to_int => {
            const payload = node.castTag(.enum_to_int).?.data;
            return renderBuiltinCall(c, "@enumToInt", &.{payload});
        },
        .int_to_ptr => {
            const payload = node.castTag(.int_to_ptr).?.data;
            return renderBuiltinCall(c, "@intToPtr", &.{ payload.lhs, payload.rhs });
        },
        .ptr_to_int => {
            const payload = node.castTag(.ptr_to_int).?.data;
            return renderBuiltinCall(c, "@ptrToInt", &.{payload});
        },
        .align_cast => {
            const payload = node.castTag(.align_cast).?.data;
            return renderBuiltinCall(c, "@alignCast", &.{ payload.lhs, payload.rhs });
        },
        .ptr_cast => {
            const payload = node.castTag(.ptr_cast).?.data;
            return renderBuiltinCall(c, "@ptrCast", &.{ payload.lhs, payload.rhs });
        },
        .sizeof => {
            const payload = node.castTag(.sizeof).?.data;
            return renderBuiltinCall(c, "@sizeOf", &.{payload});
        },
        .alignof => {
            const payload = node.castTag(.alignof).?.data;
            return renderBuiltinCall(c, "@alignOf", &.{payload});
        },
        .typeof => {
            const payload = node.castTag(.typeof).?.data;
            return renderBuiltinCall(c, "@TypeOf", &.{payload});
        },
        .negate => return renderPrefixOp(c, node, .negation, .minus, "-"),
        .negate_wrap => return renderPrefixOp(c, node, .negation_wrap, .minus_percent, "-%"),
        .bit_not => return renderPrefixOp(c, node, .bit_not, .tilde, "~"),
        .not => return renderPrefixOp(c, node, .bool_not, .bang, "!"),
        .optional_type => return renderPrefixOp(c, node, .optional_type, .question_mark, "?"),
        .address_of => return renderPrefixOp(c, node, .address_of, .ampersand, "&"),
        .deref => {
            const payload = node.castTag(.deref).?.data;
            const operand = try renderNodeGrouped(c, payload);
            const deref_tok = try c.addToken(.period_asterisk, ".*");
            return c.addNode(.{
                .tag = .deref,
                .main_token = deref_tok,
                .data = .{
                    .lhs = operand,
                    .rhs = undefined,
                },
            });
        },
        .unwrap => {
            const payload = node.castTag(.unwrap).?.data;
            const operand = try renderNodeGrouped(c, payload);
            const period = try c.addToken(.period, ".");
            const question_mark = try c.addToken(.question_mark, "?");
            return c.addNode(.{
                .tag = .unwrap_optional,
                .main_token = period,
                .data = .{
                    .lhs = operand,
                    .rhs = question_mark,
                },
            });
        },
        .add => return renderBinOp(c, node, .add, .plus, "+"),
        .add_assign => return renderBinOp(c, node, .assign_add, .plus_equal, "+="),
        .add_wrap => return renderBinOp(c, node, .add_wrap, .plus_percent, "+%"),
        .add_wrap_assign => return renderBinOp(c, node, .assign_add_wrap, .plus_percent_equal, "+%="),
        .sub => return renderBinOp(c, node, .sub, .minus, "-"),
        .sub_assign => return renderBinOp(c, node, .assign_sub, .minus_equal, "-="),
        .sub_wrap => return renderBinOp(c, node, .sub_wrap, .minus_percent, "-%"),
        .sub_wrap_assign => return renderBinOp(c, node, .assign_sub_wrap, .minus_percent_equal, "-%="),
        .mul => return renderBinOp(c, node, .mul, .asterisk, "*"),
        .mul_assign => return renderBinOp(c, node, .assign_mul, .asterisk_equal, "*="),
        .mul_wrap => return renderBinOp(c, node, .mul_wrap, .asterisk_percent, "*="),
        .mul_wrap_assign => return renderBinOp(c, node, .assign_mul_wrap, .asterisk_percent_equal, "*%="),
        .div => return renderBinOp(c, node, .div, .slash, "/"),
        .div_assign => return renderBinOp(c, node, .assign_div, .slash_equal, "/="),
        .shl => return renderBinOp(c, node, .bit_shift_left, .angle_bracket_angle_bracket_left, "<<"),
        .shl_assign => return renderBinOp(c, node, .assign_bit_shift_left, .angle_bracket_angle_bracket_left_equal, "<<="),
        .shr => return renderBinOp(c, node, .bit_shift_right, .angle_bracket_angle_bracket_right, ">>"),
        .shr_assign => return renderBinOp(c, node, .assign_bit_shift_right, .angle_bracket_angle_bracket_right_equal, ">>="),
        .mod => return renderBinOp(c, node, .mod, .percent, "%"),
        .mod_assign => return renderBinOp(c, node, .assign_mod, .percent_equal, "%="),
        .@"and" => return renderBinOp(c, node, .bool_and, .keyword_and, "and"),
        .@"or" => return renderBinOp(c, node, .bool_or, .keyword_or, "or"),
        .less_than => return renderBinOp(c, node, .less_than, .angle_bracket_left, "<"),
        .less_than_equal => return renderBinOp(c, node, .less_or_equal, .angle_bracket_left_equal, "<="),
        .greater_than => return renderBinOp(c, node, .greater_than, .angle_bracket_right, ">="),
        .greater_than_equal => return renderBinOp(c, node, .greater_or_equal, .angle_bracket_right_equal, ">="),
        .equal => return renderBinOp(c, node, .equal_equal, .equal_equal, "=="),
        .not_equal => return renderBinOp(c, node, .bang_equal, .bang_equal, "!="),
        .bit_and => return renderBinOp(c, node, .bit_and, .ampersand, "&"),
        .bit_and_assign => return renderBinOp(c, node, .assign_bit_and, .ampersand_equal, "&="),
        .bit_or => return renderBinOp(c, node, .bit_or, .pipe, "|"),
        .bit_or_assign => return renderBinOp(c, node, .assign_bit_or, .pipe_equal, "|="),
        .bit_xor => return renderBinOp(c, node, .bit_xor, .caret, "^"),
        .bit_xor_assign => return renderBinOp(c, node, .assign_bit_xor, .caret_equal, "^="),
        .array_cat => return renderBinOp(c, node, .array_cat, .plus_plus, "++"),
        .ellipsis3 => return renderBinOp(c, node, .switch_range, .ellipsis3, "..."),
        .assign => return renderBinOp(c, node, .assign, .equal, "="),
        else => return c.addNode(.{
            .tag = .identifier,
            .main_token = try c.addTokenFmt(.identifier, "@\"TODO {}\"", .{node.tag()}),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        }),
    }
}

fn renderNodeGrouped(c: *Context, node: Node) !NodeIndex {
    switch (node.tag()) {
        .null_literal,
        .undefined_literal,
        .true_literal,
        .false_literal,
        .return_void,
        .zero_literal,
        .one_literal,
        .void_type,
        .noreturn_type,
        .@"anytype",
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
        .std_mem_zeroes,
        .std_math_Log2Int,
        .log2_int_type,
        .ptr_to_int,
        .enum_to_int,
        .sizeof,
        .alignof,
        .typeof,
        .std_meta_sizeof,
        .std_meta_cast,
        .std_mem_zeroinit,
        .integer_literal,
        .float_literal,
        .string_literal,
        .char_literal,
        .identifier,
        .field_access,
        .ptr_cast,
        .type,
        .array_access,
        .align_cast,
        => {
            // no grouping needed
            return renderNode(c, node);
        },

        .negate,
        .negate_wrap,
        .bit_not,
        .opaque_literal,
        .not,
        .optional_type,
        .address_of,
        .unwrap,
        .deref,
        .empty_array,
        .block_single,
        .bool_to_int,
        .add,
        .add_wrap,
        .sub,
        .sub_wrap,
        .mul,
        .mul_wrap,
        .div,
        .shl,
        .shr,
        .mod,
        .@"and",
        .@"or",
        .less_than,
        .less_than_equal,
        .greater_than,
        .greater_than_equal,
        .equal,
        .not_equal,
        .bit_and,
        .bit_or,
        .bit_xor,
        .empty_block,
        .array_cat,
        .array_filler,
        .@"if",
        .call,
        .@"enum",
        .@"struct",
        .@"union",
        .array_init,
        .tuple,
        .container_init,
        .block,
        .c_pointer,
        .single_pointer,
        .array_type,
        => return c.addNode(.{
            .tag = .grouped_expression,
            .main_token = try c.addToken(.l_paren, "("),
            .data = .{
                .lhs = try renderNode(c, node),
                .rhs = try c.addToken(.r_paren, ")"),
            },
        }),
        .ellipsis3,
        .switch_prong,
        .warning,
        .var_decl,
        .func,
        .fail_decl,
        .arg_redecl,
        .alias,
        .var_simple,
        .pub_var_simple,
        .enum_redecl,
        .@"while",
        .@"switch",
        .@"break",
        .break_val,
        .pub_inline_fn,
        .discard,
        .@"continue",
        .@"return",
        .usingnamespace_builtins,
        .while_true,
        .if_not_break,
        .switch_else,
        .add_assign,
        .add_wrap_assign,
        .sub_assign,
        .sub_wrap_assign,
        .mul_assign,
        .mul_wrap_assign,
        .div_assign,
        .shl_assign,
        .shr_assign,
        .mod_assign,
        .bit_and_assign,
        .bit_or_assign,
        .bit_xor_assign,
        .assign,
        => {
            // these should never appear in places where grouping might be needed.
            unreachable;
        },
    }
}

fn renderPrefixOp(c: *Context, node: Node, tag: std.zig.ast.Node.Tag, tok_tag: TokenTag, bytes: []const u8) !NodeIndex {
    const payload = @fieldParentPtr(Payload.UnOp, "base", node.ptr_otherwise).data;
    const tok = try c.addToken(tok_tag, bytes);
    const operand = try renderNodeGrouped(c, payload);
    return c.addNode(.{
        .tag = tag,
        .main_token = tok,
        .data = .{
            .lhs = operand,
            .rhs = undefined,
        },
    });
}

fn renderBinOp(c: *Context, node: Node, tag: std.zig.ast.Node.Tag, tok_tag: TokenTag, bytes: []const u8) !NodeIndex {
    const payload = @fieldParentPtr(Payload.BinOp, "base", node.ptr_otherwise).data;
    const lhs = try renderNodeGrouped(c, payload.lhs);
    return c.addNode(.{
        .tag = tag,
        .main_token = try c.addToken(tok_tag, bytes),
        .data = .{
            .lhs = lhs,
            .rhs = try renderNodeGrouped(c, payload.rhs),
        },
    });
}

fn renderStdImport(c: *Context, first: []const u8, second: []const u8) !NodeIndex {
    const import_tok = try c.addToken(.builtin, "@import");
    _ = try c.addToken(.l_paren, "(");
    const std_tok = try c.addToken(.string_literal, "\"std\"");
    const std_node = try c.addNode(.{
        .tag = .string_literal,
        .main_token = std_tok,
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    _ = try c.addToken(.r_paren, ")");

    const import_node = try c.addNode(.{
        .tag = .builtin_call_two,
        .main_token = import_tok,
        .data = .{
            .lhs = std_node,
            .rhs = 0,
        },
    });

    var access_chain = import_node;
    access_chain = try c.addNode(.{
        .tag = .field_access,
        .main_token = try c.addToken(.period, "."),
        .data = .{
            .lhs = access_chain,
            .rhs = try c.addIdentifier(first),
        },
    });
    access_chain = try c.addNode(.{
        .tag = .field_access,
        .main_token = try c.addToken(.period, "."),
        .data = .{
            .lhs = access_chain,
            .rhs = try c.addIdentifier(second),
        },
    });
    return access_chain;
}

fn renderCall(c: *Context, lhs: NodeIndex, args: []const Node) !NodeIndex {
    const lparen = try c.addToken(.l_paren, "(");
    const res = switch (args.len) {
        0 => try c.addNode(.{
            .tag = .call_one,
            .main_token = lparen,
            .data = .{
                .lhs = lhs,
                .rhs = 0,
            },
        }),
        1 => blk: {
            const arg = try renderNode(c, args[0]);
            break :blk try c.addNode(.{
                .tag = .call_one,
                .main_token = lparen,
                .data = .{
                    .lhs = lhs,
                    .rhs = arg,
                },
            });
        },
        else => blk: {
            const start = @intCast(u32, c.extra_data.items.len);
            const end = @intCast(u32, start + args.len);
            try c.extra_data.ensureCapacity(c.gpa, end + 2); // + 2 for span start + end
            for (args) |arg, i| {
                if (i != 0) _ = try c.addToken(.comma, ",");
                c.extra_data.appendAssumeCapacity(try renderNode(c, arg));
            }
            c.extra_data.appendAssumeCapacity(start);
            c.extra_data.appendAssumeCapacity(end);
            break :blk try c.addNode(.{
                .tag = .call_comma,
                .main_token = lparen,
                .data = .{
                    .lhs = lhs,
                    .rhs = end + 2,
                },
            });
        },
    };
    _ = try c.addToken(.r_paren, ")");
    return res;
}

fn renderBuiltinCall(c: *Context, builtin: []const u8, args: []const Node) !NodeIndex {
    const builtin_tok = try c.addToken(.builtin, builtin);
    _ = try c.addToken(.l_paren, "(");
    var arg_1: NodeIndex = 0;
    var arg_2: NodeIndex = 0;
    switch (args.len) {
        0 => {},
        1 => {
            arg_1 = try renderNode(c, args[0]);
        },
        2 => {
            arg_1 = try renderNode(c, args[0]);
            _ = try c.addToken(.comma, ",");
            arg_2 = try renderNode(c, args[1]);
        },
        else => unreachable, // expand this function as needed.
    }

    _ = try c.addToken(.r_paren, ")");
    return c.addNode(.{
        .tag = .builtin_call_two,
        .main_token = builtin_tok,
        .data = .{
            .lhs = arg_1,
            .rhs = arg_2,
        },
    });
}

fn renderVar(c: *Context, node: Node) !NodeIndex {
    const payload = node.castTag(.var_decl).?.data;
    if (payload.is_pub) _ = try c.addToken(.keyword_pub, "pub");
    if (payload.is_extern) _ = try c.addToken(.keyword_extern, "extern");
    if (payload.is_export) _ = try c.addToken(.keyword_export, "export");
    const mut_tok = if (payload.is_const)
        try c.addToken(.keyword_const, "const")
    else
        try c.addToken(.keyword_var, "var");
    _ = try c.addIdentifier(payload.name);
    _ = try c.addToken(.colon, ":");
    const type_node = try renderNode(c, payload.type);

    const align_node = if (payload.alignment) |some| blk: {
        _ = try c.addToken(.keyword_align, "align");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .integer_literal,
            .main_token = try c.addTokenFmt(.integer_literal, "{d}", .{some}),
            .data = .{ .lhs = undefined, .rhs = undefined },
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else 0;

    const section_node = if (payload.linksection_string) |some| blk: {
        _ = try c.addToken(.keyword_linksection, "linksection");
        _ = try c.addToken(.l_paren, "(");
        const res = try c.addNode(.{
            .tag = .string_literal,
            .main_token = try c.addTokenFmt(.string_literal, "\"{s}\"", .{std.zig.fmtEscapes(some)}),
            .data = .{ .lhs = undefined, .rhs = undefined },
        });
        _ = try c.addToken(.r_paren, ")");
        break :blk res;
    } else 0;

    const init_node = if (payload.init) |some| blk: {
        _ = try c.addToken(.equal, "=");
        break :blk try renderNode(c, some);
    } else 0;
    _ = try c.addToken(.semicolon, ";");

    if (section_node == 0) {
        if (align_node == 0) {
            return c.addNode(.{
                .tag = .simple_var_decl,
                .main_token = mut_tok,
                .data = .{
                    .lhs = type_node,
                    .rhs = init_node,
                },
            });
        } else {
            return c.addNode(.{
                .tag = .local_var_decl,
                .main_token = mut_tok,
                .data = .{
                    .lhs = try c.addExtra(std.zig.ast.Node.LocalVarDecl{
                        .type_node = type_node,
                        .align_node = align_node,
                    }),
                    .rhs = init_node,
                },
            });
        }
    } else {
        return c.addNode(.{
            .tag = .global_var_decl,
            .main_token = mut_tok,
            .data = .{
                .lhs = try c.addExtra(std.zig.ast.Node.GlobalVarDecl{
                    .type_node = type_node,
                    .align_node = align_node,
                    .section_node = section_node,
                }),
                .rhs = init_node,
            },
        });
    }
}
