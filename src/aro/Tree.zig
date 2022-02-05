const std = @import("std");
const Type = @import("Type.zig");
const Tokenizer = @import("Tokenizer.zig");
const Compilation = @import("Compilation.zig");
const Source = @import("Source.zig");
const Attribute = @import("Attribute.zig");
const Value = @import("Value.zig");

const Tree = @This();

pub const Token = struct {
    id: Id,
    /// This location contains the actual token slice which might be generated.
    /// If it is generated then there is guaranteed to be at least one
    /// expansion location.
    loc: Source.Location,
    expansion_locs: ?[*]Source.Location = null,

    pub fn expansionSlice(tok: Token) []const Source.Location {
        const locs = tok.expansion_locs orelse return &[0]Source.Location{};
        var i: usize = 0;
        while (locs[i].id != .unused) : (i += 1) {}
        return locs[0..i];
    }

    pub fn addExpansionLocation(tok: *Token, gpa: std.mem.Allocator, new: []const Source.Location) !void {
        if (new.len == 0 or tok.id == .whitespace) return;
        var list = std.ArrayList(Source.Location).init(gpa);
        defer {
            std.mem.set(Source.Location, list.items.ptr[list.items.len..list.capacity], .{});
            // add a sentinel since the allocator is not guaranteed
            // to return the exact desired size
            list.items.ptr[list.capacity - 1].byte_offset = 1;
            tok.expansion_locs = list.items.ptr;
        }

        if (tok.expansion_locs) |locs| {
            var i: usize = 0;
            while (locs[i].id != .unused) : (i += 1) {}
            list.items = locs[0..i];
            while (locs[i].byte_offset != 1) : (i += 1) {}
            list.capacity = i + 1;
        }

        const min_len = std.math.max(list.items.len + new.len + 1, 4);
        const wanted_len = std.math.ceilPowerOfTwo(usize, min_len) catch
            return error.OutOfMemory;
        try list.ensureTotalCapacity(wanted_len);

        for (new) |new_loc| {
            if (new_loc.id == .generated) continue;
            list.appendAssumeCapacity(new_loc);
        }
    }

    pub fn free(expansion_locs: ?[*]Source.Location, gpa: std.mem.Allocator) void {
        const locs = expansion_locs orelse return;
        var i: usize = 0;
        while (locs[i].id != .unused) : (i += 1) {}
        while (locs[i].byte_offset != 1) : (i += 1) {}
        gpa.free(locs[0 .. i + 1]);
    }

    pub fn dupe(tok: Token, gpa: std.mem.Allocator) !Token {
        var copy = tok;
        copy.expansion_locs = null;
        try copy.addExpansionLocation(gpa, tok.expansionSlice());
        return copy;
    }

    pub const List = std.MultiArrayList(Token);
    pub const Id = Tokenizer.Token.Id;
};

pub const TokenIndex = u32;
pub const NodeIndex = enum(u32) { none, _ };
pub const ValueMap = std.AutoHashMap(NodeIndex, Value);

comp: *Compilation,
arena: std.heap.ArenaAllocator,
generated: []const u8,
tokens: Token.List.Slice,
nodes: Node.List.Slice,
data: []const NodeIndex,
root_decls: []const NodeIndex,
strings: []const u8,
value_map: ValueMap,

pub fn deinit(tree: *Tree) void {
    tree.comp.gpa.free(tree.root_decls);
    tree.comp.gpa.free(tree.data);
    tree.comp.gpa.free(tree.strings);
    tree.nodes.deinit(tree.comp.gpa);
    tree.arena.deinit();
    tree.value_map.deinit();
}

pub const Node = struct {
    tag: Tag,
    ty: Type = .{ .specifier = .void },
    data: Data,

    pub const Range = struct { start: u32, end: u32 };

    pub const Data = union {
        decl: struct {
            name: TokenIndex,
            node: NodeIndex = .none,
        },
        decl_ref: TokenIndex,
        range: Range,
        if3: struct {
            cond: NodeIndex,
            body: u32,
        },
        un: NodeIndex,
        bin: struct {
            lhs: NodeIndex,
            rhs: NodeIndex,
        },
        member: struct {
            lhs: NodeIndex,
            index: u32,
        },
        union_init: struct {
            field_index: u32,
            node: NodeIndex,
        },
        int: u64,

        pub fn forDecl(data: Data, tree: Tree) struct {
            decls: []const NodeIndex,
            cond: NodeIndex,
            incr: NodeIndex,
            body: NodeIndex,
        } {
            const items = tree.data[data.range.start..data.range.end];
            const decls = items[0 .. items.len - 3];

            return .{
                .decls = decls,
                .cond = items[items.len - 3],
                .incr = items[items.len - 2],
                .body = items[items.len - 1],
            };
        }

        pub fn forStmt(data: Data, tree: Tree) struct {
            init: NodeIndex,
            cond: NodeIndex,
            incr: NodeIndex,
            body: NodeIndex,
        } {
            const items = tree.data[data.if3.body..];

            return .{
                .init = items[0],
                .cond = items[1],
                .incr = items[2],
                .body = data.if3.cond,
            };
        }
    };

    pub const List = std.MultiArrayList(Node);
};

pub const Tag = enum(u8) {
    /// Only appears at index 0 and reaching it is always a result of a bug.
    invalid,

    // ====== Decl ======

    // _Static_assert
    static_assert,

    // function prototype
    fn_proto,
    static_fn_proto,
    inline_fn_proto,
    inline_static_fn_proto,

    // function definition
    fn_def,
    static_fn_def,
    inline_fn_def,
    inline_static_fn_def,

    // variable declaration
    @"var",
    extern_var,
    static_var,
    // same as static_var, used for __func__, __FUNCTION__ and __PRETTY_FUNCTION__
    implicit_static_var,
    threadlocal_var,
    threadlocal_extern_var,
    threadlocal_static_var,

    // typedef declaration
    typedef,

    // container declarations
    /// { lhs; rhs; }
    struct_decl_two,
    /// { lhs; rhs; }
    union_decl_two,
    /// { lhs, rhs, }
    enum_decl_two,
    /// { range }
    struct_decl,
    /// { range }
    union_decl,
    /// { range }
    enum_decl,

    /// name = node
    enum_field_decl,
    /// ty name : node
    /// name == 0 means unnamed
    record_field_decl,
    /// Used when a record has an unnamed record as a field
    indirect_record_field_decl,

    // ====== Stmt ======

    labeled_stmt,
    /// { first; second; } first and second may be null
    compound_stmt_two,
    /// { data }
    compound_stmt,
    /// if (first) data[second] else data[second+1];
    if_then_else_stmt,
    /// if (first); else second;
    if_else_stmt,
    /// if (first) second; second may be null
    if_then_stmt,
    /// switch (first) second
    switch_stmt,
    /// case first: second
    case_stmt,
    /// default: first
    default_stmt,
    /// while (first) second
    while_stmt,
    /// do second while(first);
    do_while_stmt,
    /// for (data[..]; data[len-3]; data[len-2]) data[len-1]
    for_decl_stmt,
    /// for (;;;) first
    forever_stmt,
    /// for (data[first]; data[first+1]; data[first+2]) second
    for_stmt,
    /// goto first;
    goto_stmt,
    /// goto *un;
    computed_goto_stmt,
    // continue; first and second unused
    continue_stmt,
    // break; first and second unused
    break_stmt,
    // null statement (just a semicolon); first and second unused
    null_stmt,
    /// return first; first may be null
    return_stmt,

    // ====== Expr ======

    /// lhs , rhs
    comma_expr,
    /// lhs ?: rhs
    binary_cond_expr,
    /// lhs ? data[0] : data[1]
    cond_expr,
    /// lhs = rhs
    assign_expr,
    /// lhs *= rhs
    mul_assign_expr,
    /// lhs /= rhs
    div_assign_expr,
    /// lhs %= rhs
    mod_assign_expr,
    /// lhs += rhs
    add_assign_expr,
    /// lhs -= rhs
    sub_assign_expr,
    /// lhs <<= rhs
    shl_assign_expr,
    /// lhs >>= rhs
    shr_assign_expr,
    /// lhs &= rhs
    bit_and_assign_expr,
    /// lhs ^= rhs
    bit_xor_assign_expr,
    /// lhs |= rhs
    bit_or_assign_expr,
    /// lhs || rhs
    bool_or_expr,
    /// lhs && rhs
    bool_and_expr,
    /// lhs | rhs
    bit_or_expr,
    /// lhs ^ rhs
    bit_xor_expr,
    /// lhs & rhs
    bit_and_expr,
    /// lhs == rhs
    equal_expr,
    /// lhs != rhs
    not_equal_expr,
    /// lhs < rhs
    less_than_expr,
    /// lhs <= rhs
    less_than_equal_expr,
    /// lhs > rhs
    greater_than_expr,
    /// lhs >= rhs
    greater_than_equal_expr,
    /// lhs << rhs
    shl_expr,
    /// lhs >> rhs
    shr_expr,
    /// lhs + rhs
    add_expr,
    /// lhs - rhs
    sub_expr,
    /// lhs * rhs
    mul_expr,
    /// lhs / rhs
    div_expr,
    /// lhs % rhs
    mod_expr,
    /// Explicit (type)un
    cast_expr,
    /// &un
    addr_of_expr,
    /// &&decl_ref
    addr_of_label,
    /// *un
    deref_expr,
    /// +un
    plus_expr,
    /// -un
    negate_expr,
    /// ~un
    bit_not_expr,
    /// !un
    bool_not_expr,
    /// ++un
    pre_inc_expr,
    /// --un
    pre_dec_expr,
    /// lhs[rhs]  lhs is pointer/array type, rhs is integer type
    array_access_expr,
    /// first(second) second may be 0
    call_expr_one,
    /// data[0](data[1..])
    call_expr,
    /// decl
    builtin_call_expr_one,
    builtin_call_expr,
    /// lhs.member
    member_access_expr,
    /// lhs->member
    member_access_ptr_expr,
    /// un++
    post_inc_expr,
    /// un--
    post_dec_expr,
    /// (un)
    paren_expr,
    /// decl_ref
    decl_ref_expr,
    /// decl_ref
    enumeration_ref,
    /// integer literal, always unsigned
    int_literal,
    /// Same as int_literal, but originates from a char literal
    char_literal,
    /// f32 literal
    float_literal,
    /// f64 literal
    double_literal,
    /// wraps a float or double literal: un
    imaginary_literal,
    /// tree.str[index..][0..len]
    string_literal_expr,
    /// sizeof(un?)
    sizeof_expr,
    /// _Alignof(un?)
    alignof_expr,
    /// _Generic(controlling lhs, chosen rhs)
    generic_expr_one,
    /// _Generic(controlling range[0], chosen range[1], rest range[2..])
    generic_expr,
    /// ty: un
    generic_association_expr,
    // default: un
    generic_default_expr,
    /// __builtin_choose_expr(lhs, data[0], data[1])
    builtin_choose_expr,
    /// ({ un })
    stmt_expr,

    // ====== Initializer expressions ======

    /// { lhs, rhs }
    array_init_expr_two,
    /// { range }
    array_init_expr,
    /// { lhs, rhs }
    struct_init_expr_two,
    /// { range }
    struct_init_expr,
    /// { union_init }
    union_init_expr,
    /// (ty){ un }
    compound_literal_expr,

    // ====== Implicit casts ======

    /// Convert T[] to T *
    array_to_pointer,
    /// Converts an lvalue to an rvalue
    lval_to_rval,
    /// Convert a function type to a pointer to a function
    function_to_pointer,
    /// Convert a pointer type to a _Bool
    pointer_to_bool,
    /// Convert a pointer type to an integer type
    pointer_to_int,
    /// Convert _Bool to an integer type
    bool_to_int,
    /// Convert _Bool to a floating type
    bool_to_float,
    /// Convert a _Bool to a pointer; will cause a  warning
    bool_to_pointer,
    /// Convert an integer type to _Bool
    int_to_bool,
    /// Convert an integer to a floating
    int_to_float,
    /// Convert an integer type to a pointer type
    int_to_pointer,
    /// Convert a floating type to a _Bool
    float_to_bool,
    /// Convert a floating type to an integer
    float_to_int,
    /// Convert one integer type to another
    int_cast,
    /// Convert one floating type to another
    float_cast,
    /// Convert pointer to one with same child type but more CV-quals,
    /// OR to appropriately-qualified void *
    /// only appears on the branches of a conditional expr
    qual_cast,
    /// Convert type to void; only appears on the branches of a conditional expr
    to_void,

    /// Convert a literal 0 to a null pointer
    null_to_pointer,

    /// Inserted at the end of a function body if no return stmt is found.
    /// ty is the functions return type
    implicit_return,

    /// Inserted in array_init_expr to represent unspecified elements.
    /// data.int contains the amount of elements.
    array_filler_expr,
    /// Inserted in record and scalar initializers for unspecified elements.
    default_init_expr,

    /// attribute argument identifier (see `mode` attribute)
    attr_arg_ident,
    /// rhs can be none
    attr_params_two,
    /// range
    attr_params,

    pub fn isImplicit(tag: Tag) bool {
        return switch (tag) {
            .array_to_pointer,
            .lval_to_rval,
            .function_to_pointer,
            .pointer_to_bool,
            .pointer_to_int,
            .bool_to_int,
            .bool_to_float,
            .bool_to_pointer,
            .int_to_bool,
            .int_to_float,
            .int_to_pointer,
            .float_to_bool,
            .float_to_int,
            .int_cast,
            .float_cast,
            .to_void,
            .implicit_return,
            .qual_cast,
            .null_to_pointer,
            .array_filler_expr,
            .default_init_expr,
            .implicit_static_var,
            => true,
            else => false,
        };
    }
};

pub fn isLval(nodes: Node.List.Slice, extra: []const NodeIndex, value_map: ValueMap, node: NodeIndex) bool {
    var is_const: bool = undefined;
    return isLvalExtra(nodes, extra, value_map, node, &is_const);
}

pub fn isLvalExtra(nodes: Node.List.Slice, extra: []const NodeIndex, value_map: ValueMap, node: NodeIndex, is_const: *bool) bool {
    is_const.* = false;
    switch (nodes.items(.tag)[@enumToInt(node)]) {
        .compound_literal_expr => {
            is_const.* = nodes.items(.ty)[@enumToInt(node)].isConst();
            return true;
        },
        .string_literal_expr => return true,
        .member_access_ptr_expr => {
            const lhs_expr = nodes.items(.data)[@enumToInt(node)].member.lhs;
            const ptr_ty = nodes.items(.ty)[@enumToInt(lhs_expr)];
            if (ptr_ty.isPtr()) is_const.* = ptr_ty.elemType().isConst();
            return true;
        },
        .array_access_expr => {
            const lhs_expr = nodes.items(.data)[@enumToInt(node)].bin.lhs;
            if (lhs_expr != .none) {
                const array_ty = nodes.items(.ty)[@enumToInt(lhs_expr)];
                if (array_ty.isPtr() or array_ty.isArray()) is_const.* = array_ty.elemType().isConst();
            }
            return true;
        },
        .decl_ref_expr => {
            const decl_ty = nodes.items(.ty)[@enumToInt(node)];
            is_const.* = decl_ty.isConst();
            return true;
        },
        .deref_expr => {
            const data = nodes.items(.data)[@enumToInt(node)];
            const operand_ty = nodes.items(.ty)[@enumToInt(data.un)];
            if (operand_ty.isFunc()) return false;
            if (operand_ty.isPtr() or operand_ty.isArray()) is_const.* = operand_ty.elemType().isConst();
            return true;
        },
        .member_access_expr => {
            const data = nodes.items(.data)[@enumToInt(node)];
            return isLvalExtra(nodes, extra, value_map, data.member.lhs, is_const);
        },
        .paren_expr => {
            const data = nodes.items(.data)[@enumToInt(node)];
            return isLvalExtra(nodes, extra, value_map, data.un, is_const);
        },
        .builtin_choose_expr => {
            const data = nodes.items(.data)[@enumToInt(node)];

            if (value_map.get(data.if3.cond)) |val| {
                const offset = @boolToInt(val.isZero());
                return isLvalExtra(nodes, extra, value_map, extra[data.if3.body + offset], is_const);
            }
            return false;
        },
        else => return false,
    }
}

pub fn dumpStr(bytes: []const u8, tag: Tag, writer: anytype) !void {
    switch (tag) {
        .string_literal_expr => try writer.print("\"{}\"", .{std.zig.fmtEscapes(bytes[0 .. bytes.len - 1])}),
        else => unreachable,
    }
}

pub fn tokSlice(tree: Tree, tok_i: TokenIndex) []const u8 {
    if (tree.tokens.items(.id)[tok_i].lexeme()) |some| return some;
    const loc = tree.tokens.items(.loc)[tok_i];
    var tmp_tokenizer = Tokenizer{
        .buf = tree.comp.getSource(loc.id).buf,
        .comp = tree.comp,
        .index = loc.byte_offset,
        .source = .generated,
    };
    const tok = tmp_tokenizer.next();
    return tmp_tokenizer.buf[tok.start..tok.end];
}

pub fn dump(tree: Tree, writer: anytype) @TypeOf(writer).Error!void {
    for (tree.root_decls) |i| {
        try tree.dumpNode(i, 0, writer);
        try writer.writeByte('\n');
    }
}

fn dumpAttribute(attr: Attribute, writer: anytype) !void {
    inline for (std.meta.fields(Attribute.Tag)) |e| {
        if (e.value == @enumToInt(attr.tag)) {
            const args = @field(attr.args, e.name);
            if (@TypeOf(args) == void) {
                try writer.writeByte('\n');
                return;
            }
            inline for (@typeInfo(@TypeOf(args)).Struct.fields) |f, i| {
                if (comptime std.mem.eql(u8, f.name, "__name_tok")) continue;
                if (i != 0) {
                    try writer.writeAll(", ");
                }
                try writer.writeAll(f.name);
                try writer.writeAll(": ");
                switch (f.field_type) {
                    []const u8, ?[]const u8 => try writer.print("\"{s}\"", .{@field(args, f.name)}),
                    else => switch (@typeInfo(f.field_type)) {
                        .Enum => try writer.writeAll(@tagName(@field(args, f.name))),
                        else => try writer.print("{}", .{@field(args, f.name)}),
                    },
                }
            }
            try writer.writeByte('\n');
            return;
        }
    }
}

fn dumpNode(tree: Tree, node: NodeIndex, level: u32, w: anytype) @TypeOf(w).Error!void {
    const delta = 2;
    const half = delta / 2;
    const util = @import("util.zig");
    const TYPE = util.Color.purple;
    const TAG = util.Color.cyan;
    const IMPLICIT = util.Color.blue;
    const NAME = util.Color.red;
    const LITERAL = util.Color.green;
    const ATTRIBUTE = util.Color.yellow;
    std.debug.assert(node != .none);

    const tag = tree.nodes.items(.tag)[@enumToInt(node)];
    const data = tree.nodes.items(.data)[@enumToInt(node)];
    const ty = tree.nodes.items(.ty)[@enumToInt(node)];
    try w.writeByteNTimes(' ', level);

    util.setColor(if (tag.isImplicit()) IMPLICIT else TAG, w);
    try w.print("{s}: ", .{@tagName(tag)});
    util.setColor(TYPE, w);
    try w.writeByte('\'');
    try ty.dump(w);
    try w.writeByte('\'');

    if (isLval(tree.nodes, tree.data, tree.value_map, node)) {
        util.setColor(ATTRIBUTE, w);
        try w.writeAll(" lvalue");
    }
    if (tree.value_map.get(node)) |val| {
        util.setColor(LITERAL, w);
        try w.writeAll(" (value: ");
        try val.dump(ty, tree.comp, w);
        try w.writeByte(')');
    }
    try w.writeAll("\n");
    util.setColor(.reset, w);

    if (ty.specifier == .attributed) {
        util.setColor(ATTRIBUTE, w);
        for (ty.data.attributed.attributes) |attr| {
            try w.writeByteNTimes(' ', level + half);
            try w.print("attr: {s} ", .{@tagName(attr.tag)});
            try dumpAttribute(attr, w);
        }
        util.setColor(.reset, w);
    }

    switch (tag) {
        .invalid => unreachable,
        .static_assert => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("condition:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);
            if (data.bin.rhs != .none) {
                try w.writeByteNTimes(' ', level + 1);
                try w.writeAll("diagnostic:\n");
                try tree.dumpNode(data.bin.rhs, level + delta, w);
            }
        },
        .fn_proto,
        .static_fn_proto,
        .inline_fn_proto,
        .inline_static_fn_proto,
        => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
        },
        .fn_def,
        .static_fn_def,
        .inline_fn_def,
        .inline_static_fn_def,
        => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("body:\n");
            try tree.dumpNode(data.decl.node, level + delta, w);
        },
        .typedef,
        .@"var",
        .extern_var,
        .static_var,
        .implicit_static_var,
        .threadlocal_var,
        .threadlocal_extern_var,
        .threadlocal_static_var,
        => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
            if (data.decl.node != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("init:\n");
                try tree.dumpNode(data.decl.node, level + delta, w);
            }
        },
        .enum_field_decl => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
            if (data.decl.node != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("value:\n");
                try tree.dumpNode(data.decl.node, level + delta, w);
            }
        },
        .record_field_decl => {
            if (data.decl.name != 0) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("name: ");
                util.setColor(NAME, w);
                try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
                util.setColor(.reset, w);
            }
            if (data.decl.node != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("bits:\n");
                try tree.dumpNode(data.decl.node, level + delta, w);
            }
        },
        .indirect_record_field_decl => {},
        .compound_stmt,
        .array_init_expr,
        .struct_init_expr,
        .enum_decl,
        .struct_decl,
        .union_decl,
        .attr_params,
        => {
            for (tree.data[data.range.start..data.range.end]) |stmt, i| {
                if (i != 0) try w.writeByte('\n');
                try tree.dumpNode(stmt, level + delta, w);
            }
        },
        .compound_stmt_two,
        .array_init_expr_two,
        .struct_init_expr_two,
        .enum_decl_two,
        .struct_decl_two,
        .union_decl_two,
        .attr_params_two,
        => {
            if (data.bin.lhs != .none) try tree.dumpNode(data.bin.lhs, level + delta, w);
            if (data.bin.rhs != .none) try tree.dumpNode(data.bin.rhs, level + delta, w);
        },
        .union_init_expr => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("field index: ");
            util.setColor(LITERAL, w);
            try w.print("{d}\n", .{data.union_init.field_index});
            util.setColor(.reset, w);
            if (data.union_init.node != .none) {
                try tree.dumpNode(data.union_init.node, level + delta, w);
            }
        },
        .compound_literal_expr => {
            try tree.dumpNode(data.un, level + half, w);
        },
        .labeled_stmt => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("label: ");
            util.setColor(LITERAL, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
            if (data.decl.node != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("stmt:\n");
                try tree.dumpNode(data.decl.node, level + delta, w);
            }
        },
        .case_stmt => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("value:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);
            if (data.bin.rhs != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("stmt:\n");
                try tree.dumpNode(data.bin.rhs, level + delta, w);
            }
        },
        .default_stmt => {
            if (data.un != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("stmt:\n");
                try tree.dumpNode(data.un, level + delta, w);
            }
        },
        .cond_expr, .if_then_else_stmt, .builtin_choose_expr => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(data.if3.cond, level + delta, w);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("then:\n");
            try tree.dumpNode(tree.data[data.if3.body], level + delta, w);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("else:\n");
            try tree.dumpNode(tree.data[data.if3.body + 1], level + delta, w);
        },
        .if_else_stmt => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("else:\n");
            try tree.dumpNode(data.bin.rhs, level + delta, w);
        },
        .if_then_stmt => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);

            if (data.bin.rhs != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("then:\n");
                try tree.dumpNode(data.bin.rhs, level + delta, w);
            }
        },
        .switch_stmt, .while_stmt, .do_while_stmt => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("cond:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);

            if (data.bin.rhs != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("body:\n");
                try tree.dumpNode(data.bin.rhs, level + delta, w);
            }
        },
        .for_decl_stmt => {
            const for_decl = data.forDecl(tree);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("decl:\n");
            for (for_decl.decls) |decl| {
                try tree.dumpNode(decl, level + delta, w);
                try w.writeByte('\n');
            }
            if (for_decl.cond != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("cond:\n");
                try tree.dumpNode(for_decl.cond, level + delta, w);
            }
            if (for_decl.incr != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("incr:\n");
                try tree.dumpNode(for_decl.incr, level + delta, w);
            }
            if (for_decl.body != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("body:\n");
                try tree.dumpNode(for_decl.body, level + delta, w);
            }
        },
        .forever_stmt => {
            if (data.un != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("body:\n");
                try tree.dumpNode(data.un, level + delta, w);
            }
        },
        .for_stmt => {
            const for_stmt = data.forStmt(tree);

            if (for_stmt.init != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("init:\n");
                try tree.dumpNode(for_stmt.init, level + delta, w);
            }
            if (for_stmt.cond != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("cond:\n");
                try tree.dumpNode(for_stmt.cond, level + delta, w);
            }
            if (for_stmt.incr != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("incr:\n");
                try tree.dumpNode(for_stmt.incr, level + delta, w);
            }
            if (for_stmt.body != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("body:\n");
                try tree.dumpNode(for_stmt.body, level + delta, w);
            }
        },
        .goto_stmt, .addr_of_label => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("label: ");
            util.setColor(LITERAL, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
            util.setColor(.reset, w);
        },
        .continue_stmt, .break_stmt, .implicit_return, .null_stmt => {},
        .return_stmt => {
            if (data.un != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("expr:\n");
                try tree.dumpNode(data.un, level + delta, w);
            }
        },
        .attr_arg_ident => {
            try w.writeByteNTimes(' ', level + half);
            util.setColor(ATTRIBUTE, w);
            try w.print("name: {s}\n", .{tree.tokSlice(data.decl_ref)});
            util.setColor(.reset, w);
        },
        .call_expr => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(tree.data[data.range.start], level + delta, w);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("args:\n");
            for (tree.data[data.range.start + 1 .. data.range.end]) |arg| try tree.dumpNode(arg, level + delta, w);
        },
        .call_expr_one => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);
            if (data.bin.rhs != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("arg:\n");
                try tree.dumpNode(data.bin.rhs, level + delta, w);
            }
        },
        .builtin_call_expr => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(@enumToInt(tree.data[data.range.start]))});
            util.setColor(.reset, w);

            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("args:\n");
            for (tree.data[data.range.start + 1 .. data.range.end]) |arg| try tree.dumpNode(arg, level + delta, w);
        },
        .builtin_call_expr_one => {
            try w.writeByteNTimes(' ', level + half);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl.name)});
            util.setColor(.reset, w);
            if (data.decl.node != .none) {
                try w.writeByteNTimes(' ', level + half);
                try w.writeAll("arg:\n");
                try tree.dumpNode(data.decl.node, level + delta, w);
            }
        },
        .comma_expr,
        .binary_cond_expr,
        .assign_expr,
        .mul_assign_expr,
        .div_assign_expr,
        .mod_assign_expr,
        .add_assign_expr,
        .sub_assign_expr,
        .shl_assign_expr,
        .shr_assign_expr,
        .bit_and_assign_expr,
        .bit_xor_assign_expr,
        .bit_or_assign_expr,
        .bool_or_expr,
        .bool_and_expr,
        .bit_or_expr,
        .bit_xor_expr,
        .bit_and_expr,
        .equal_expr,
        .not_equal_expr,
        .less_than_expr,
        .less_than_equal_expr,
        .greater_than_expr,
        .greater_than_equal_expr,
        .shl_expr,
        .shr_expr,
        .add_expr,
        .sub_expr,
        .mul_expr,
        .div_expr,
        .mod_expr,
        => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("rhs:\n");
            try tree.dumpNode(data.bin.rhs, level + delta, w);
        },
        .cast_expr,
        .addr_of_expr,
        .computed_goto_stmt,
        .deref_expr,
        .plus_expr,
        .negate_expr,
        .bit_not_expr,
        .bool_not_expr,
        .pre_inc_expr,
        .pre_dec_expr,
        .post_inc_expr,
        .post_dec_expr,
        .paren_expr,
        => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("operand:\n");
            try tree.dumpNode(data.un, level + delta, w);
        },
        .decl_ref_expr => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
            util.setColor(.reset, w);
        },
        .enumeration_ref => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{tree.tokSlice(data.decl_ref)});
            util.setColor(.reset, w);
        },
        .int_literal,
        .char_literal,
        .float_literal,
        .double_literal,
        .string_literal_expr,
        => {},
        .member_access_expr, .member_access_ptr_expr => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("lhs:\n");
            try tree.dumpNode(data.member.lhs, level + delta, w);

            var lhs_ty = tree.nodes.items(.ty)[@enumToInt(data.member.lhs)];
            if (lhs_ty.isPtr()) lhs_ty = lhs_ty.elemType();
            lhs_ty = lhs_ty.canonicalize(.standard);

            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("name: ");
            util.setColor(NAME, w);
            try w.print("{s}\n", .{lhs_ty.data.record.fields[data.member.index].name});
            util.setColor(.reset, w);
        },
        .array_access_expr => {
            if (data.bin.lhs != .none) {
                try w.writeByteNTimes(' ', level + 1);
                try w.writeAll("lhs:\n");
                try tree.dumpNode(data.bin.lhs, level + delta, w);
            }
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("index:\n");
            try tree.dumpNode(data.bin.rhs, level + delta, w);
        },
        .sizeof_expr, .alignof_expr => {
            if (data.un != .none) {
                try w.writeByteNTimes(' ', level + 1);
                try w.writeAll("expr:\n");
                try tree.dumpNode(data.un, level + delta, w);
            }
        },
        .generic_expr_one => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("controlling:\n");
            try tree.dumpNode(data.bin.lhs, level + delta, w);
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("chosen:\n");
            try tree.dumpNode(data.bin.rhs, level + delta, w);
        },
        .generic_expr => {
            const nodes = tree.data[data.range.start..data.range.end];
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("controlling:\n");
            try tree.dumpNode(nodes[0], level + delta, w);
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("chosen:\n");
            try tree.dumpNode(nodes[1], level + delta, w);
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("rest:\n");
            for (nodes[2..]) |expr| {
                try tree.dumpNode(expr, level + delta, w);
            }
        },
        .generic_association_expr, .generic_default_expr, .stmt_expr, .imaginary_literal => {
            try tree.dumpNode(data.un, level + delta, w);
        },
        .array_to_pointer,
        .lval_to_rval,
        .function_to_pointer,
        .pointer_to_bool,
        .pointer_to_int,
        .bool_to_int,
        .bool_to_float,
        .bool_to_pointer,
        .int_to_bool,
        .int_to_float,
        .int_to_pointer,
        .float_to_bool,
        .float_to_int,
        .int_cast,
        .float_cast,
        .to_void,
        .qual_cast,
        .null_to_pointer,
        => {
            try tree.dumpNode(data.un, level + delta, w);
        },
        .array_filler_expr => {
            try w.writeByteNTimes(' ', level + 1);
            try w.writeAll("count: ");
            util.setColor(LITERAL, w);
            try w.print("{d}\n", .{data.int});
            util.setColor(.reset, w);
        },
        .default_init_expr => {},
    }
}
