//! Ingests an `Ast` and produces a `Zoir`.

gpa: Allocator,
tree: Ast,

options: Options,

nodes: std.MultiArrayList(Zoir.Node.Repr),
extra: std.ArrayListUnmanaged(u32),
limbs: std.ArrayListUnmanaged(std.math.big.Limb),
string_bytes: std.ArrayListUnmanaged(u8),
string_table: std.HashMapUnmanaged(u32, void, StringIndexContext, std.hash_map.default_max_load_percentage),

compile_errors: std.ArrayListUnmanaged(Zoir.CompileError),
error_notes: std.ArrayListUnmanaged(Zoir.CompileError.Note),

pub const Options = struct {
    /// When false, string literals are not parsed. `string_literal` nodes will contain empty
    /// strings, and errors that normally occur during string parsing will not be raised.
    ///
    /// `parseStrLit` and `strLitSizeHint` may be used to parse string literals after the fact.
    parse_str_lits: bool = true,
};

pub fn generate(gpa: Allocator, tree: Ast, options: Options) Allocator.Error!Zoir {
    assert(tree.mode == .zon);

    var zg: ZonGen = .{
        .gpa = gpa,
        .tree = tree,
        .options = options,
        .nodes = .empty,
        .extra = .empty,
        .limbs = .empty,
        .string_bytes = .empty,
        .string_table = .empty,
        .compile_errors = .empty,
        .error_notes = .empty,
    };
    defer {
        zg.nodes.deinit(gpa);
        zg.extra.deinit(gpa);
        zg.limbs.deinit(gpa);
        zg.string_bytes.deinit(gpa);
        zg.string_table.deinit(gpa);
        zg.compile_errors.deinit(gpa);
        zg.error_notes.deinit(gpa);
    }

    if (tree.errors.len == 0) {
        const root_ast_node = tree.nodes.items(.data)[0].lhs;
        try zg.nodes.append(gpa, undefined); // index 0; root node
        try zg.expr(root_ast_node, .root);
    } else {
        try zg.lowerAstErrors();
    }

    if (zg.compile_errors.items.len > 0) {
        const string_bytes = try zg.string_bytes.toOwnedSlice(gpa);
        errdefer gpa.free(string_bytes);
        const compile_errors = try zg.compile_errors.toOwnedSlice(gpa);
        errdefer gpa.free(compile_errors);
        const error_notes = try zg.error_notes.toOwnedSlice(gpa);
        errdefer gpa.free(error_notes);

        return .{
            .nodes = .empty,
            .extra = &.{},
            .limbs = &.{},
            .string_bytes = string_bytes,
            .compile_errors = compile_errors,
            .error_notes = error_notes,
        };
    } else {
        assert(zg.error_notes.items.len == 0);

        var nodes = zg.nodes.toOwnedSlice();
        errdefer nodes.deinit(gpa);
        const extra = try zg.extra.toOwnedSlice(gpa);
        errdefer gpa.free(extra);
        const limbs = try zg.limbs.toOwnedSlice(gpa);
        errdefer gpa.free(limbs);
        const string_bytes = try zg.string_bytes.toOwnedSlice(gpa);
        errdefer gpa.free(string_bytes);

        return .{
            .nodes = nodes,
            .extra = extra,
            .limbs = limbs,
            .string_bytes = string_bytes,
            .compile_errors = &.{},
            .error_notes = &.{},
        };
    }
}

fn expr(zg: *ZonGen, node: Ast.Node.Index, dest_node: Zoir.Node.Index) Allocator.Error!void {
    const gpa = zg.gpa;
    const tree = zg.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);

    switch (node_tags[node]) {
        .root => unreachable,
        .@"usingnamespace" => unreachable,
        .test_decl => unreachable,
        .container_field_init => unreachable,
        .container_field_align => unreachable,
        .container_field => unreachable,
        .fn_decl => unreachable,
        .global_var_decl => unreachable,
        .local_var_decl => unreachable,
        .simple_var_decl => unreachable,
        .aligned_var_decl => unreachable,
        .@"defer" => unreachable,
        .@"errdefer" => unreachable,
        .switch_case => unreachable,
        .switch_case_inline => unreachable,
        .switch_case_one => unreachable,
        .switch_case_inline_one => unreachable,
        .switch_range => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,
        .for_range => unreachable,
        .assign => unreachable,
        .assign_destructure => unreachable,
        .assign_shl => unreachable,
        .assign_shl_sat => unreachable,
        .assign_shr => unreachable,
        .assign_bit_and => unreachable,
        .assign_bit_or => unreachable,
        .assign_bit_xor => unreachable,
        .assign_div => unreachable,
        .assign_sub => unreachable,
        .assign_sub_wrap => unreachable,
        .assign_sub_sat => unreachable,
        .assign_mod => unreachable,
        .assign_add => unreachable,
        .assign_add_wrap => unreachable,
        .assign_add_sat => unreachable,
        .assign_mul => unreachable,
        .assign_mul_wrap => unreachable,
        .assign_mul_sat => unreachable,

        .shl,
        .shr,
        .add,
        .add_wrap,
        .add_sat,
        .sub,
        .sub_wrap,
        .sub_sat,
        .mul,
        .mul_wrap,
        .mul_sat,
        .div,
        .mod,
        .shl_sat,
        .bit_and,
        .bit_or,
        .bit_xor,
        .bang_equal,
        .equal_equal,
        .greater_than,
        .greater_or_equal,
        .less_than,
        .less_or_equal,
        .array_cat,
        .array_mult,
        .bool_and,
        .bool_or,
        .bool_not,
        .bit_not,
        .negation_wrap,
        => try zg.addErrorTok(main_tokens[node], "operator '{s}' is not allowed in ZON", .{tree.tokenSlice(main_tokens[node])}),

        .error_union,
        .merge_error_sets,
        .optional_type,
        .anyframe_literal,
        .anyframe_type,
        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        .container_decl,
        .container_decl_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        .array_type,
        .array_type_sentinel,
        .error_set_decl,
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => try zg.addErrorNode(node, "types are not available in ZON", .{}),

        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        .@"return",
        .if_simple,
        .@"if",
        .while_simple,
        .while_cont,
        .@"while",
        .for_simple,
        .@"for",
        .@"catch",
        .@"orelse",
        .@"break",
        .@"continue",
        .@"switch",
        .switch_comma,
        .@"nosuspend",
        .@"suspend",
        .@"await",
        .@"resume",
        .@"try",
        .unreachable_literal,
        => try zg.addErrorNode(node, "control flow is not allowed in ZON", .{}),

        .@"comptime" => try zg.addErrorNode(node, "keyword 'comptime' is not allowed in ZON", .{}),
        .asm_simple, .@"asm" => try zg.addErrorNode(node, "inline asm is not allowed in ZON", .{}),

        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => try zg.addErrorNode(node, "builtin function calls are not allowed in ZON", .{}),

        .field_access => try zg.addErrorNode(node, "field accesses are not allowed in ZON", .{}),

        .slice_open,
        .slice,
        .slice_sentinel,
        => try zg.addErrorNode(node, "slice operator is not allowed in ZON", .{}),

        .deref, .address_of => try zg.addErrorTok(main_tokens[node], "pointers are not available in ZON", .{}),
        .unwrap_optional => try zg.addErrorTok(main_tokens[node], "optionals are not available in ZON", .{}),
        .error_value => try zg.addErrorNode(node, "errors are not available in ZON", .{}),

        .array_access => try zg.addErrorTok(node, "array indexing is not allowed in ZON", .{}),

        .block_two,
        .block_two_semicolon,
        .block,
        .block_semicolon,
        => {
            const size = switch (node_tags[node]) {
                .block_two, .block_two_semicolon => @intFromBool(node_datas[node].lhs != 0) + @intFromBool(node_datas[node].rhs != 0),
                .block, .block_semicolon => node_datas[node].rhs - node_datas[node].lhs,
                else => unreachable,
            };
            if (size == 0) {
                try zg.addErrorNodeNotes(node, "void literals are not available in ZON", .{}, &.{
                    try zg.errNoteNode(node, "void union payloads can be represented by enum literals", .{}),
                });
            } else {
                try zg.addErrorNode(node, "blocks are not allowed in ZON", .{});
            }
        },

        .array_init_one,
        .array_init_one_comma,
        .array_init,
        .array_init_comma,
        .struct_init_one,
        .struct_init_one_comma,
        .struct_init,
        .struct_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;

            const type_node = if (tree.fullArrayInit(&buf, node)) |full|
                full.ast.type_expr
            else if (tree.fullStructInit(&buf, node)) |full|
                full.ast.type_expr
            else
                unreachable;

            try zg.addErrorNodeNotes(type_node, "types are not available in ZON", .{}, &.{
                try zg.errNoteNode(type_node, "replace the type with '.'", .{}),
            });
        },

        .grouped_expression => {
            try zg.addErrorTokNotes(main_tokens[node], "expression grouping is not allowed in ZON", .{}, &.{
                try zg.errNoteTok(main_tokens[node], "these parentheses are always redundant", .{}),
            });
            return zg.expr(node_datas[node].lhs, dest_node);
        },

        .negation => {
            const child_node = node_datas[node].lhs;
            switch (node_tags[child_node]) {
                .number_literal => return zg.numberLiteral(child_node, node, dest_node, .negative),
                .identifier => {
                    const child_ident = tree.tokenSlice(main_tokens[child_node]);
                    if (mem.eql(u8, child_ident, "inf")) {
                        zg.setNode(dest_node, .{
                            .tag = .neg_inf,
                            .data = 0, // ignored
                            .ast_node = node,
                        });
                        return;
                    }
                },
                else => {},
            }
            try zg.addErrorTok(main_tokens[node], "expected number or 'inf' after '-'", .{});
        },
        .number_literal => try zg.numberLiteral(node, node, dest_node, .positive),
        .char_literal => try zg.charLiteral(node, dest_node),

        .identifier => try zg.identifier(node, dest_node),

        .enum_literal => {
            const str_index = zg.identAsString(main_tokens[node]) catch |err| switch (err) {
                error.BadString => undefined, // doesn't matter, there's an error
                error.OutOfMemory => |e| return e,
            };
            zg.setNode(dest_node, .{
                .tag = .enum_literal,
                .data = @intFromEnum(str_index),
                .ast_node = node,
            });
        },
        .string_literal, .multiline_string_literal => if (zg.strLitAsString(node)) |result| switch (result) {
            .nts => |nts| zg.setNode(dest_node, .{
                .tag = .string_literal_null,
                .data = @intFromEnum(nts),
                .ast_node = node,
            }),
            .slice => |slice| {
                const extra_index: u32 = @intCast(zg.extra.items.len);
                try zg.extra.appendSlice(zg.gpa, &.{ slice.start, slice.len });
                zg.setNode(dest_node, .{
                    .tag = .string_literal,
                    .data = extra_index,
                    .ast_node = node,
                });
            },
        } else |err| switch (err) {
            error.BadString => {},
            error.OutOfMemory => |e| return e,
        },

        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = tree.fullArrayInit(&buf, node).?;
            assert(full.ast.elements.len != 0); // Otherwise it would be a struct init
            assert(full.ast.type_expr == 0); // The tag was `array_init_dot_*`

            const first_elem: u32 = @intCast(zg.nodes.len);
            try zg.nodes.resize(gpa, zg.nodes.len + full.ast.elements.len);

            const extra_index: u32 = @intCast(zg.extra.items.len);
            try zg.extra.appendSlice(gpa, &.{
                @intCast(full.ast.elements.len),
                first_elem,
            });

            zg.setNode(dest_node, .{
                .tag = .array_literal,
                .data = extra_index,
                .ast_node = node,
            });

            for (full.ast.elements, first_elem..) |elem_node, elem_dest_node| {
                try zg.expr(elem_node, @enumFromInt(elem_dest_node));
            }
        },

        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = tree.fullStructInit(&buf, node).?;
            assert(full.ast.type_expr == 0); // The tag was `struct_init_dot_*`

            if (full.ast.fields.len == 0) {
                zg.setNode(dest_node, .{
                    .tag = .empty_literal,
                    .data = 0, // ignored
                    .ast_node = node,
                });
                return;
            }

            const first_elem: u32 = @intCast(zg.nodes.len);
            try zg.nodes.resize(gpa, zg.nodes.len + full.ast.fields.len);

            const extra_index: u32 = @intCast(zg.extra.items.len);
            try zg.extra.ensureUnusedCapacity(gpa, 2 + full.ast.fields.len);
            zg.extra.appendSliceAssumeCapacity(&.{
                @intCast(full.ast.fields.len),
                first_elem,
            });
            const names_start = extra_index + 2;
            zg.extra.appendNTimesAssumeCapacity(undefined, full.ast.fields.len);

            zg.setNode(dest_node, .{
                .tag = .struct_literal,
                .data = extra_index,
                .ast_node = node,
            });

            // For short initializers, track the names on the stack rather than going through gpa.
            var sfba_state = std.heap.stackFallback(256, gpa);
            const sfba = sfba_state.get();
            var field_names: std.AutoHashMapUnmanaged(Zoir.NullTerminatedString, Ast.TokenIndex) = .empty;
            defer field_names.deinit(sfba);

            var reported_any_duplicate = false;

            for (full.ast.fields, names_start.., first_elem..) |elem_node, extra_name_idx, elem_dest_node| {
                const name_token = tree.firstToken(elem_node) - 2;
                if (zg.identAsString(name_token)) |name_str| {
                    zg.extra.items[extra_name_idx] = @intFromEnum(name_str);
                    const gop = try field_names.getOrPut(sfba, name_str);
                    if (gop.found_existing and !reported_any_duplicate) {
                        reported_any_duplicate = true;
                        const earlier_token = gop.value_ptr.*;
                        try zg.addErrorTokNotes(earlier_token, "duplicate struct field name", .{}, &.{
                            try zg.errNoteTok(name_token, "duplicate name here", .{}),
                        });
                    }
                    gop.value_ptr.* = name_token;
                } else |err| switch (err) {
                    error.BadString => {}, // there's an error, so it's fine to not populate `zg.extra`
                    error.OutOfMemory => |e| return e,
                }
                try zg.expr(elem_node, @enumFromInt(elem_dest_node));
            }
        },
    }
}

fn appendIdentStr(zg: *ZonGen, ident_token: Ast.TokenIndex) error{ OutOfMemory, BadString }!u32 {
    const gpa = zg.gpa;
    const tree = zg.tree;
    assert(tree.tokens.items(.tag)[ident_token] == .identifier);
    const ident_name = tree.tokenSlice(ident_token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        const start = zg.string_bytes.items.len;
        try zg.string_bytes.appendSlice(gpa, ident_name);
        return @intCast(start);
    }
    const offset = 1;
    const start: u32 = @intCast(zg.string_bytes.items.len);
    const raw_string = zg.tree.tokenSlice(ident_token)[offset..];
    try zg.string_bytes.ensureUnusedCapacity(gpa, raw_string.len);
    const result = r: {
        var aw: std.io.AllocatingWriter = undefined;
        const bw = aw.fromArrayList(gpa, &zg.string_bytes);
        defer zg.string_bytes = aw.toArrayList();
        break :r std.zig.string_literal.parseWrite(bw, raw_string) catch |err| return @errorCast(err);
    };
    switch (result) {
        .success => {},
        .failure => |err| {
            try zg.lowerStrLitError(err, ident_token, raw_string, offset);
            return error.BadString;
        },
    }

    const slice = zg.string_bytes.items[start..];
    if (mem.indexOfScalar(u8, slice, 0) != null) {
        try zg.addErrorTok(ident_token, "identifier cannot contain null bytes", .{});
        return error.BadString;
    } else if (slice.len == 0) {
        try zg.addErrorTok(ident_token, "identifier cannot be empty", .{});
        return error.BadString;
    }
    return start;
}

/// Estimates the size of a string node without parsing it.
pub fn strLitSizeHint(tree: Ast, node: Ast.Node.Index) usize {
    switch (tree.nodes.items(.tag)[node]) {
        // Parsed string literals are typically around the size of the raw strings.
        .string_literal => {
            const token = tree.nodes.items(.main_token)[node];
            const raw_string = tree.tokenSlice(token);
            return raw_string.len;
        },
        // Multiline string literal lengths can be computed exactly.
        .multiline_string_literal => {
            const first_tok, const last_tok = bounds: {
                const node_data = tree.nodes.items(.data)[node];
                break :bounds .{ node_data.lhs, node_data.rhs };
            };

            var size = tree.tokenSlice(first_tok)[2..].len;
            for (first_tok + 1..last_tok + 1) |tok_idx| {
                size += 1; // Newline
                size += tree.tokenSlice(@intCast(tok_idx))[2..].len;
            }
            return size;
        },
        else => unreachable,
    }
}

/// Parses the given node as a string literal.
pub fn parseStrLit(
    tree: Ast,
    node: Ast.Node.Index,
    writer: *std.io.BufferedWriter,
) anyerror!std.zig.string_literal.Result {
    switch (tree.nodes.items(.tag)[node]) {
        .string_literal => {
            const token = tree.nodes.items(.main_token)[node];
            const raw_string = tree.tokenSlice(token);
            return std.zig.string_literal.parseWrite(writer, raw_string);
        },
        .multiline_string_literal => {
            const first_tok, const last_tok = bounds: {
                const node_data = tree.nodes.items(.data)[node];
                break :bounds .{ node_data.lhs, node_data.rhs };
            };

            // First line: do not append a newline.
            {
                const line_bytes = tree.tokenSlice(first_tok)[2..];
                try writer.writeAll(line_bytes);
            }

            // Following lines: each line prepends a newline.
            for (first_tok + 1..last_tok + 1) |tok_idx| {
                const line_bytes = tree.tokenSlice(@intCast(tok_idx))[2..];
                try writer.writeByte('\n');
                try writer.writeAll(line_bytes);
            }

            return .success;
        },
        // Node must represent a string
        else => unreachable,
    }
}

const StringLiteralResult = union(enum) {
    nts: Zoir.NullTerminatedString,
    slice: struct { start: u32, len: u32 },
};

fn strLitAsString(zg: *ZonGen, str_node: Ast.Node.Index) error{ OutOfMemory, BadString }!StringLiteralResult {
    if (!zg.options.parse_str_lits) return .{ .slice = .{ .start = 0, .len = 0 } };

    const gpa = zg.gpa;
    const string_bytes = &zg.string_bytes;
    const str_index: u32 = @intCast(zg.string_bytes.items.len);
    const size_hint = strLitSizeHint(zg.tree, str_node);
    try string_bytes.ensureUnusedCapacity(gpa, size_hint);
    const result = r: {
        var aw: std.io.AllocatingWriter = undefined;
        const bw = aw.fromArrayList(gpa, &zg.string_bytes);
        defer zg.string_bytes = aw.toArrayList();
        break :r parseStrLit(zg.tree, str_node, bw) catch |err| return @errorCast(err);
    };
    switch (result) {
        .success => {},
        .failure => |err| {
            const token = zg.tree.nodes.items(.main_token)[str_node];
            const raw_string = zg.tree.tokenSlice(token);
            try zg.lowerStrLitError(err, token, raw_string, 0);
            return error.BadString;
        },
    }
    const key: []const u8 = string_bytes.items[str_index..];
    if (std.mem.indexOfScalar(u8, key, 0) != null) return .{ .slice = .{
        .start = str_index,
        .len = @intCast(key.len),
    } };
    const gop = try zg.string_table.getOrPutContextAdapted(
        gpa,
        key,
        StringIndexAdapter{ .bytes = string_bytes },
        StringIndexContext{ .bytes = string_bytes },
    );
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return .{ .nts = @enumFromInt(gop.key_ptr.*) };
    }
    gop.key_ptr.* = str_index;
    try string_bytes.append(gpa, 0);
    return .{ .nts = @enumFromInt(str_index) };
}

fn identAsString(zg: *ZonGen, ident_token: Ast.TokenIndex) !Zoir.NullTerminatedString {
    const gpa = zg.gpa;
    const string_bytes = &zg.string_bytes;
    const str_index = try zg.appendIdentStr(ident_token);
    const key: []const u8 = string_bytes.items[str_index..];
    const gop = try zg.string_table.getOrPutContextAdapted(
        gpa,
        key,
        StringIndexAdapter{ .bytes = string_bytes },
        StringIndexContext{ .bytes = string_bytes },
    );
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return @enumFromInt(gop.key_ptr.*);
    }
    gop.key_ptr.* = str_index;
    try string_bytes.append(gpa, 0);
    return @enumFromInt(str_index);
}

fn numberLiteral(zg: *ZonGen, num_node: Ast.Node.Index, src_node: Ast.Node.Index, dest_node: Zoir.Node.Index, sign: enum { negative, positive }) !void {
    const tree = zg.tree;
    const num_token = tree.nodes.items(.main_token)[num_node];
    const num_bytes = tree.tokenSlice(num_token);

    switch (std.zig.parseNumberLiteral(num_bytes)) {
        .int => |unsigned_num| {
            if (unsigned_num == 0 and sign == .negative) {
                try zg.addErrorTokNotes(num_token, "integer literal '-0' is ambiguous", .{}, &.{
                    try zg.errNoteTok(num_token, "use '0' for an integer zero", .{}),
                    try zg.errNoteTok(num_token, "use '-0.0' for a floating-point signed zero", .{}),
                });
                return;
            }
            const num: i65 = switch (sign) {
                .positive => unsigned_num,
                .negative => -@as(i65, unsigned_num),
            };
            if (std.math.cast(i32, num)) |x| {
                zg.setNode(dest_node, .{
                    .tag = .int_literal_small,
                    .data = @bitCast(x),
                    .ast_node = src_node,
                });
                return;
            }
            const max_limbs = comptime std.math.big.int.calcTwosCompLimbCount(@bitSizeOf(@TypeOf(num)));
            var limbs: [max_limbs]std.math.big.Limb = undefined;
            var big_int: std.math.big.int.Mutable = .init(&limbs, num);
            try zg.setBigIntLiteralNode(dest_node, src_node, big_int.toConst());
        },
        .big_int => |base| {
            const gpa = zg.gpa;
            const num_without_prefix = switch (base) {
                .decimal => num_bytes,
                .hex, .binary, .octal => num_bytes[2..],
            };
            var big_int: std.math.big.int.Managed = try .init(gpa);
            defer big_int.deinit();
            big_int.setString(@intFromEnum(base), num_without_prefix) catch |err| switch (err) {
                error.InvalidCharacter => unreachable, // caught in `parseNumberLiteral`
                error.InvalidBase => unreachable, // we only pass 16, 8, 2, see above
                error.OutOfMemory => return error.OutOfMemory,
            };
            switch (sign) {
                .positive => {},
                .negative => big_int.negate(),
            }
            try zg.setBigIntLiteralNode(dest_node, src_node, big_int.toConst());
        },
        .float => {
            const unsigned_num = std.fmt.parseFloat(f128, num_bytes) catch |err| switch (err) {
                error.InvalidCharacter => unreachable, // validated by tokenizer
            };
            const num: f128 = switch (sign) {
                .positive => unsigned_num,
                .negative => -unsigned_num,
            };

            {
                // If the value fits into an f32 without losing any precision, store it that way.
                @setFloatMode(.strict);
                const smaller_float: f32 = @floatCast(num);
                const bigger_again: f128 = smaller_float;
                if (bigger_again == num) {
                    zg.setNode(dest_node, .{
                        .tag = .float_literal_small,
                        .data = @bitCast(smaller_float),
                        .ast_node = src_node,
                    });
                    return;
                }
            }

            const elems: [4]u32 = @bitCast(num);
            const extra_index: u32 = @intCast(zg.extra.items.len);
            try zg.extra.appendSlice(zg.gpa, &elems);
            zg.setNode(dest_node, .{
                .tag = .float_literal,
                .data = extra_index,
                .ast_node = src_node,
            });
        },
        .failure => |err| try zg.lowerNumberError(err, num_token, num_bytes),
    }
}

fn setBigIntLiteralNode(zg: *ZonGen, dest_node: Zoir.Node.Index, src_node: Ast.Node.Index, val: std.math.big.int.Const) !void {
    try zg.extra.ensureUnusedCapacity(zg.gpa, 2);
    try zg.limbs.ensureUnusedCapacity(zg.gpa, val.limbs.len);

    const limbs_idx: u32 = @intCast(zg.limbs.items.len);
    zg.limbs.appendSliceAssumeCapacity(val.limbs);

    const extra_idx: u32 = @intCast(zg.extra.items.len);
    zg.extra.appendSliceAssumeCapacity(&.{ @intCast(val.limbs.len), limbs_idx });

    zg.setNode(dest_node, .{
        .tag = if (val.positive) .int_literal_pos else .int_literal_neg,
        .data = extra_idx,
        .ast_node = src_node,
    });
}

fn charLiteral(zg: *ZonGen, node: Ast.Node.Index, dest_node: Zoir.Node.Index) !void {
    const tree = zg.tree;
    assert(tree.nodes.items(.tag)[node] == .char_literal);
    const main_token = tree.nodes.items(.main_token)[node];
    const slice = tree.tokenSlice(main_token);
    switch (std.zig.parseCharLiteral(slice)) {
        .success => |codepoint| zg.setNode(dest_node, .{
            .tag = .char_literal,
            .data = codepoint,
            .ast_node = node,
        }),
        .failure => |err| try zg.lowerStrLitError(err, main_token, slice, 0),
    }
}

fn identifier(zg: *ZonGen, node: Ast.Node.Index, dest_node: Zoir.Node.Index) !void {
    const tree = zg.tree;
    assert(tree.nodes.items(.tag)[node] == .identifier);
    const main_token = tree.nodes.items(.main_token)[node];
    const ident = tree.tokenSlice(main_token);

    const tag: Zoir.Node.Repr.Tag = t: {
        if (mem.eql(u8, ident, "true")) break :t .true;
        if (mem.eql(u8, ident, "false")) break :t .false;
        if (mem.eql(u8, ident, "null")) break :t .null;
        if (mem.eql(u8, ident, "inf")) break :t .pos_inf;
        if (mem.eql(u8, ident, "nan")) break :t .nan;
        try zg.addErrorNodeNotes(node, "invalid expression", .{}, &.{
            try zg.errNoteNode(node, "ZON allows identifiers 'true', 'false', 'null', 'inf', and 'nan'", .{}),
            try zg.errNoteNode(node, "precede identifier with '.' for an enum literal", .{}),
        });
        return;
    };

    zg.setNode(dest_node, .{
        .tag = tag,
        .data = 0, // ignored
        .ast_node = node,
    });
}

fn setNode(zg: *ZonGen, dest: Zoir.Node.Index, repr: Zoir.Node.Repr) void {
    zg.nodes.set(@intFromEnum(dest), repr);
}

fn lowerStrLitError(
    zg: *ZonGen,
    err: std.zig.string_literal.Error,
    token: Ast.TokenIndex,
    raw_string: []const u8,
    offset: u32,
) Allocator.Error!void {
    return ZonGen.addErrorTokOff(
        zg,
        token,
        @intCast(offset + err.offset()),
        "{}",
        .{err.fmt(raw_string)},
    );
}

fn lowerNumberError(zg: *ZonGen, err: std.zig.number_literal.Error, token: Ast.TokenIndex, bytes: []const u8) Allocator.Error!void {
    const is_float = std.mem.indexOfScalar(u8, bytes, '.') != null;
    switch (err) {
        .leading_zero => if (is_float) {
            try zg.addErrorTok(token, "number '{s}' has leading zero", .{bytes});
        } else {
            try zg.addErrorTokNotes(token, "number '{s}' has leading zero", .{bytes}, &.{
                try zg.errNoteTok(token, "use '0o' prefix for octal literals", .{}),
            });
        },
        .digit_after_base => try zg.addErrorTok(token, "expected a digit after base prefix", .{}),
        .upper_case_base => |i| try zg.addErrorTokOff(token, @intCast(i), "base prefix must be lowercase", .{}),
        .invalid_float_base => |i| try zg.addErrorTokOff(token, @intCast(i), "invalid base for float literal", .{}),
        .repeated_underscore => |i| try zg.addErrorTokOff(token, @intCast(i), "repeated digit separator", .{}),
        .invalid_underscore_after_special => |i| try zg.addErrorTokOff(token, @intCast(i), "expected digit before digit separator", .{}),
        .invalid_digit => |info| try zg.addErrorTokOff(token, @intCast(info.i), "invalid digit '{c}' for {s} base", .{ bytes[info.i], @tagName(info.base) }),
        .invalid_digit_exponent => |i| try zg.addErrorTokOff(token, @intCast(i), "invalid digit '{c}' in exponent", .{bytes[i]}),
        .duplicate_exponent => |i| try zg.addErrorTokOff(token, @intCast(i), "duplicate exponent", .{}),
        .exponent_after_underscore => |i| try zg.addErrorTokOff(token, @intCast(i), "expected digit before exponent", .{}),
        .special_after_underscore => |i| try zg.addErrorTokOff(token, @intCast(i), "expected digit before '{c}'", .{bytes[i]}),
        .trailing_special => |i| try zg.addErrorTokOff(token, @intCast(i), "expected digit after '{c}'", .{bytes[i - 1]}),
        .trailing_underscore => |i| try zg.addErrorTokOff(token, @intCast(i), "trailing digit separator", .{}),
        .duplicate_period => unreachable, // Validated by tokenizer
        .invalid_character => unreachable, // Validated by tokenizer
        .invalid_exponent_sign => |i| {
            assert(bytes.len >= 2 and bytes[0] == '0' and bytes[1] == 'x'); // Validated by tokenizer
            try zg.addErrorTokOff(token, @intCast(i), "sign '{c}' cannot follow digit '{c}' in hex base", .{ bytes[i], bytes[i - 1] });
        },
        .period_after_exponent => |i| try zg.addErrorTokOff(token, @intCast(i), "unexpected period after exponent", .{}),
    }
}

fn errNoteNode(zg: *ZonGen, node: Ast.Node.Index, comptime format: []const u8, args: anytype) Allocator.Error!Zoir.CompileError.Note {
    const message_idx: u32 = @intCast(zg.string_bytes.items.len);
    try zg.string_bytes.print(zg.gpa, format ++ "\x00", args);
    return .{
        .msg = @enumFromInt(message_idx),
        .token = Zoir.CompileError.invalid_token,
        .node_or_offset = node,
    };
}

fn errNoteTok(zg: *ZonGen, tok: Ast.TokenIndex, comptime format: []const u8, args: anytype) Allocator.Error!Zoir.CompileError.Note {
    const message_idx: u32 = @intCast(zg.string_bytes.items.len);
    try zg.string_bytes.print(zg.gpa, format ++ "\x00", args);
    return .{
        .msg = @enumFromInt(message_idx),
        .token = tok,
        .node_or_offset = 0,
    };
}

fn addErrorNode(zg: *ZonGen, node: Ast.Node.Index, comptime format: []const u8, args: anytype) Allocator.Error!void {
    return zg.addErrorInner(Zoir.CompileError.invalid_token, node, format, args, &.{});
}
fn addErrorTok(zg: *ZonGen, tok: Ast.TokenIndex, comptime format: []const u8, args: anytype) Allocator.Error!void {
    return zg.addErrorInner(tok, 0, format, args, &.{});
}
fn addErrorNodeNotes(zg: *ZonGen, node: Ast.Node.Index, comptime format: []const u8, args: anytype, notes: []const Zoir.CompileError.Note) Allocator.Error!void {
    return zg.addErrorInner(Zoir.CompileError.invalid_token, node, format, args, notes);
}
fn addErrorTokNotes(zg: *ZonGen, tok: Ast.TokenIndex, comptime format: []const u8, args: anytype, notes: []const Zoir.CompileError.Note) Allocator.Error!void {
    return zg.addErrorInner(tok, 0, format, args, notes);
}
fn addErrorTokOff(zg: *ZonGen, tok: Ast.TokenIndex, offset: u32, comptime format: []const u8, args: anytype) Allocator.Error!void {
    return zg.addErrorInner(tok, offset, format, args, &.{});
}
fn addErrorTokNotesOff(zg: *ZonGen, tok: Ast.TokenIndex, offset: u32, comptime format: []const u8, args: anytype, notes: []const Zoir.CompileError.Note) Allocator.Error!void {
    return zg.addErrorInner(tok, offset, format, args, notes);
}

fn addErrorInner(
    zg: *ZonGen,
    token: Ast.TokenIndex,
    node_or_offset: u32,
    comptime format: []const u8,
    args: anytype,
    notes: []const Zoir.CompileError.Note,
) Allocator.Error!void {
    const gpa = zg.gpa;

    const first_note: u32 = @intCast(zg.error_notes.items.len);
    try zg.error_notes.appendSlice(gpa, notes);

    const message_idx: u32 = @intCast(zg.string_bytes.items.len);
    try zg.string_bytes.print(gpa, format ++ "\x00", args);

    try zg.compile_errors.append(gpa, .{
        .msg = @enumFromInt(message_idx),
        .token = token,
        .node_or_offset = node_or_offset,
        .first_note = first_note,
        .note_count = @intCast(notes.len),
    });
}

fn lowerAstErrors(zg: *ZonGen) Allocator.Error!void {
    const gpa = zg.gpa;
    const tree = zg.tree;
    assert(tree.errors.len > 0);

    var msg: std.io.AllocatingWriter = undefined;
    const msg_bw = msg.init(gpa);
    defer msg.deinit();

    var notes: std.ArrayListUnmanaged(Zoir.CompileError.Note) = .empty;
    defer notes.deinit(gpa);

    var cur_err = tree.errors[0];
    for (tree.errors[1..]) |err| {
        if (err.is_note) {
            tree.renderError(err, msg_bw) catch |e| return @errorCast(e); // TODO: try @errorCast(...)
            try notes.append(gpa, try zg.errNoteTok(err.token, "{s}", .{msg.getWritten()}));
        } else {
            // Flush error
            tree.renderError(cur_err, msg_bw) catch |e| return @errorCast(e); // TODO try @errorCast(...)
            const extra_offset = tree.errorOffset(cur_err);
            try zg.addErrorTokNotesOff(cur_err.token, extra_offset, "{s}", .{msg.getWritten()}, notes.items);
            notes.clearRetainingCapacity();
            cur_err = err;

            // TODO: `Parse` currently does not have good error recovery
            // mechanisms, so the remaining errors could be bogus. As such,
            // we'll ignore all remaining errors for now. We should improve
            // `Parse` so that we can report all the errors.
            return;
        }
        msg.clearRetainingCapacity();
    }

    // Flush error
    const extra_offset = tree.errorOffset(cur_err);
    tree.renderError(cur_err, msg_bw) catch |e| return @errorCast(e); // TODO try @errorCast(...)
    try zg.addErrorTokNotesOff(cur_err.token, extra_offset, "{s}", .{msg.getWritten()}, notes.items);
}

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;
const StringIndexAdapter = std.hash_map.StringIndexAdapter;
const StringIndexContext = std.hash_map.StringIndexContext;
const ZonGen = @This();
const Zoir = @import("Zoir.zig");
const Ast = @import("Ast.zig");
