// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = u32;
pub const ByteOffset = u32;

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});
pub const NodeList = std.MultiArrayList(Node);

pub const Tree = struct {
    /// Reference to externally-owned data.
    source: []const u8,

    tokens: TokenList.Slice,
    /// The root AST node is assumed to be index 0. Since there can be no
    /// references to the root node, this means 0 is available to indicate null.
    nodes: NodeList.Slice,
    extra_data: []Node.Index,

    errors: []const Error,

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    pub fn deinit(tree: *Tree, gpa: *mem.Allocator) void {
        tree.tokens.deinit(gpa);
        tree.nodes.deinit(gpa);
        gpa.free(tree.extra_data);
        gpa.free(tree.errors);
        tree.* = undefined;
    }

    pub const RenderError = error{
        /// Ran out of memory allocating call stack frames to complete rendering, or
        /// ran out of memory allocating space in the output buffer.
        OutOfMemory,
    };

    /// `gpa` is used for allocating the resulting formatted source code, as well as
    /// for allocating extra stack memory if needed, because this function utilizes recursion.
    /// Note: that's not actually true yet, see https://github.com/ziglang/zig/issues/1006.
    /// Caller owns the returned slice of bytes, allocated with `gpa`.
    pub fn render(tree: Tree, gpa: *mem.Allocator) RenderError![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();

        try tree.renderToArrayList(&buffer);
        return buffer.toOwnedSlice();
    }

    pub fn renderToArrayList(tree: Tree, buffer: *std.ArrayList(u8)) RenderError!void {
        return @import("./render.zig").renderTree(buffer, tree);
    }

    pub fn tokenLocation(self: Tree, start_offset: ByteOffset, token_index: TokenIndex) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_offset,
            .line_end = self.source.len,
        };
        const token_start = self.tokens.items(.start)[token_index];
        for (self.source[start_offset..]) |c, i| {
            if (i + start_offset == token_start) {
                loc.line_end = i + start_offset;
                while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') {
                    loc.line_end += 1;
                }
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

    pub fn tokenSlice(tree: Tree, token_index: TokenIndex) []const u8 {
        const token_starts = tree.tokens.items(.start);
        const token_tags = tree.tokens.items(.tag);
        const token_tag = token_tags[token_index];

        // Many tokens can be determined entirely by their tag.
        if (token_tag.lexeme()) |lexeme| {
            return lexeme;
        }

        // For some tokens, re-tokenization is needed to find the end.
        var tokenizer: std.zig.Tokenizer = .{
            .buffer = tree.source,
            .index = token_starts[token_index],
            .pending_invalid_token = null,
        };
        const token = tokenizer.next();
        assert(token.tag == token_tag);
        return tree.source[token.loc.start..token.loc.end];
    }

    pub fn extraData(tree: Tree, index: usize, comptime T: type) T {
        const fields = std.meta.fields(T);
        var result: T = undefined;
        inline for (fields) |field, i| {
            comptime assert(field.field_type == Node.Index);
            @field(result, field.name) = tree.extra_data[index + i];
        }
        return result;
    }

    pub fn rootDecls(tree: Tree) []const Node.Index {
        // Root is always index 0.
        const nodes_data = tree.nodes.items(.data);
        return tree.extra_data[nodes_data[0].lhs..nodes_data[0].rhs];
    }

    pub fn renderError(tree: Tree, parse_error: Error, stream: anytype) !void {
        const token_tags = tree.tokens.items(.tag);
        switch (parse_error.tag) {
            .asterisk_after_ptr_deref => {
                return stream.writeAll("'.*' cannot be followed by '*'. Are you missing a space?");
            },
            .decl_between_fields => {
                return stream.writeAll("declarations are not allowed between container fields");
            },
            .expected_block => {
                return stream.print("expected block or field, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_block_or_assignment => {
                return stream.print("expected block or assignment, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_block_or_expr => {
                return stream.print("expected block or expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_block_or_field => {
                return stream.print("expected block or field, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_container_members => {
                return stream.print("expected test, comptime, var decl, or container field, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_expr => {
                return stream.print("expected expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_expr_or_assignment => {
                return stream.print("expected expression or assignment, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_fn => {
                return stream.print("expected function, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_inlinable => {
                return stream.print("expected 'while' or 'for', found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_labelable => {
                return stream.print("expected 'while', 'for', 'inline', 'suspend', or '{{', found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_param_list => {
                return stream.print("expected parameter list, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_prefix_expr => {
                return stream.print("expected prefix expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_primary_type_expr => {
                return stream.print("expected primary type expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_pub_item => {
                return stream.writeAll("expected function or variable declaration after pub");
            },
            .expected_return_type => {
                return stream.print("expected return type expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_semi_or_else => {
                return stream.print("expected ';' or 'else', found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_semi_or_lbrace => {
                return stream.print("expected ';' or '{{', found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_statement => {
                return stream.print("expected statement, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_string_literal => {
                return stream.print("expected string literal, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_suffix_op => {
                return stream.print("expected pointer dereference, optional unwrap, or field access, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_type_expr => {
                return stream.print("expected type expression, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_var_decl => {
                return stream.print("expected variable declaration, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_var_decl_or_fn => {
                return stream.print("expected variable declaration or function, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_loop_payload => {
                return stream.print("expected loop payload, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .expected_container => {
                return stream.print("expected a struct, enum or union, found '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .extra_align_qualifier => {
                return stream.writeAll("extra align qualifier");
            },
            .extra_allowzero_qualifier => {
                return stream.writeAll("extra allowzero qualifier");
            },
            .extra_const_qualifier => {
                return stream.writeAll("extra const qualifier");
            },
            .extra_volatile_qualifier => {
                return stream.writeAll("extra volatile qualifier");
            },
            .ptr_mod_on_array_child_type => {
                return stream.print("pointer modifier '{s}' not allowed on array child type", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .invalid_and => {
                return stream.writeAll("`&&` is invalid; note that `and` is boolean AND");
            },
            .invalid_bit_range => {
                return stream.writeAll("bit range not allowed on slices and arrays");
            },
            .invalid_token => {
                return stream.print("invalid token '{s}'", .{
                    token_tags[parse_error.token].symbol(),
                });
            },
            .same_line_doc_comment => {
                return stream.writeAll("same line documentation comment");
            },
            .unattached_doc_comment => {
                return stream.writeAll("unattached documentation comment");
            },

            .expected_token => {
                const found_tag = token_tags[parse_error.token];
                const expected_symbol = parse_error.extra.expected_tag.symbol();
                switch (found_tag) {
                    .invalid => return stream.print("expected '{s}', found invalid bytes", .{
                        expected_symbol,
                    }),
                    else => return stream.print("expected '{s}', found '{s}'", .{
                        expected_symbol, found_tag.symbol(),
                    }),
                }
            },
        }
    }

    pub fn firstToken(tree: Tree, node: Node.Index) TokenIndex {
        const tags = tree.nodes.items(.tag);
        const datas = tree.nodes.items(.data);
        const main_tokens = tree.nodes.items(.main_token);
        const token_tags = tree.tokens.items(.tag);
        var end_offset: TokenIndex = 0;
        var n = node;
        while (true) switch (tags[n]) {
            .root => return 0,

            .test_decl,
            .@"errdefer",
            .@"defer",
            .bool_not,
            .negation,
            .bit_not,
            .negation_wrap,
            .address_of,
            .@"try",
            .@"await",
            .optional_type,
            .@"switch",
            .switch_comma,
            .if_simple,
            .@"if",
            .@"suspend",
            .@"resume",
            .@"continue",
            .@"break",
            .@"return",
            .anyframe_type,
            .identifier,
            .anyframe_literal,
            .char_literal,
            .integer_literal,
            .float_literal,
            .false_literal,
            .true_literal,
            .null_literal,
            .undefined_literal,
            .unreachable_literal,
            .string_literal,
            .multiline_string_literal,
            .grouped_expression,
            .builtin_call_two,
            .builtin_call_two_comma,
            .builtin_call,
            .builtin_call_comma,
            .error_set_decl,
            .@"anytype",
            .@"comptime",
            .@"nosuspend",
            .asm_simple,
            .@"asm",
            .array_type,
            .array_type_sentinel,
            .error_value,
            => return main_tokens[n] - end_offset,

            .array_init_dot,
            .array_init_dot_comma,
            .array_init_dot_two,
            .array_init_dot_two_comma,
            .struct_init_dot,
            .struct_init_dot_comma,
            .struct_init_dot_two,
            .struct_init_dot_two_comma,
            .enum_literal,
            => return main_tokens[n] - 1 - end_offset,

            .@"catch",
            .field_access,
            .unwrap_optional,
            .equal_equal,
            .bang_equal,
            .less_than,
            .greater_than,
            .less_or_equal,
            .greater_or_equal,
            .assign_mul,
            .assign_div,
            .assign_mod,
            .assign_add,
            .assign_sub,
            .assign_bit_shift_left,
            .assign_bit_shift_right,
            .assign_bit_and,
            .assign_bit_xor,
            .assign_bit_or,
            .assign_mul_wrap,
            .assign_add_wrap,
            .assign_sub_wrap,
            .assign,
            .merge_error_sets,
            .mul,
            .div,
            .mod,
            .array_mult,
            .mul_wrap,
            .add,
            .sub,
            .array_cat,
            .add_wrap,
            .sub_wrap,
            .bit_shift_left,
            .bit_shift_right,
            .bit_and,
            .bit_xor,
            .bit_or,
            .@"orelse",
            .bool_and,
            .bool_or,
            .slice_open,
            .slice,
            .slice_sentinel,
            .deref,
            .array_access,
            .array_init_one,
            .array_init_one_comma,
            .array_init,
            .array_init_comma,
            .struct_init_one,
            .struct_init_one_comma,
            .struct_init,
            .struct_init_comma,
            .call_one,
            .call_one_comma,
            .call,
            .call_comma,
            .switch_range,
            .error_union,
            => n = datas[n].lhs,

            .fn_decl,
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            => {
                var i = main_tokens[n]; // fn token
                while (i > 0) {
                    i -= 1;
                    switch (token_tags[i]) {
                        .keyword_extern,
                        .keyword_export,
                        .keyword_pub,
                        .keyword_threadlocal,
                        .string_literal,
                        => continue,

                        else => return i + 1 - end_offset,
                    }
                }
                return i - end_offset;
            },

            .@"usingnamespace" => {
                const main_token = main_tokens[n];
                if (main_token > 0 and token_tags[main_token - 1] == .keyword_pub) {
                    end_offset += 1;
                }
                return main_token - end_offset;
            },

            .async_call_one,
            .async_call_one_comma,
            .async_call,
            .async_call_comma,
            => {
                end_offset += 1; // async token
                n = datas[n].lhs;
            },

            .container_field_init,
            .container_field_align,
            .container_field,
            => {
                const name_token = main_tokens[n];
                if (name_token > 0 and token_tags[name_token - 1] == .keyword_comptime) {
                    end_offset += 1;
                }
                return name_token - end_offset;
            },

            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                var i = main_tokens[n]; // mut token
                while (i > 0) {
                    i -= 1;
                    switch (token_tags[i]) {
                        .keyword_extern,
                        .keyword_export,
                        .keyword_comptime,
                        .keyword_pub,
                        .keyword_threadlocal,
                        .string_literal,
                        => continue,

                        else => return i + 1 - end_offset,
                    }
                }
                return i - end_offset;
            },

            .block,
            .block_semicolon,
            .block_two,
            .block_two_semicolon,
            => {
                // Look for a label.
                const lbrace = main_tokens[n];
                if (token_tags[lbrace - 1] == .colon and
                    token_tags[lbrace - 2] == .identifier)
                {
                    end_offset += 2;
                }
                return lbrace - end_offset;
            },

            .container_decl,
            .container_decl_trailing,
            .container_decl_two,
            .container_decl_two_trailing,
            .container_decl_arg,
            .container_decl_arg_trailing,
            .tagged_union,
            .tagged_union_trailing,
            .tagged_union_two,
            .tagged_union_two_trailing,
            .tagged_union_enum_tag,
            .tagged_union_enum_tag_trailing,
            => {
                const main_token = main_tokens[n];
                switch (token_tags[main_token - 1]) {
                    .keyword_packed, .keyword_extern => end_offset += 1,
                    else => {},
                }
                return main_token - end_offset;
            },

            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            => {
                const main_token = main_tokens[n];
                return switch (token_tags[main_token]) {
                    .asterisk,
                    .asterisk_asterisk,
                    => switch (token_tags[main_token - 1]) {
                        .l_bracket => main_token - 1,
                        else => main_token,
                    },
                    .l_bracket => main_token,
                    else => unreachable,
                } - end_offset;
            },

            .switch_case_one => {
                if (datas[n].lhs == 0) {
                    return main_tokens[n] - 1 - end_offset; // else token
                } else {
                    n = datas[n].lhs;
                }
            },
            .switch_case => {
                const extra = tree.extraData(datas[n].lhs, Node.SubRange);
                assert(extra.end - extra.start > 0);
                n = tree.extra_data[extra.start];
            },

            .asm_output, .asm_input => {
                assert(token_tags[main_tokens[n] - 1] == .l_bracket);
                return main_tokens[n] - 1 - end_offset;
            },

            .while_simple,
            .while_cont,
            .@"while",
            .for_simple,
            .@"for",
            => {
                // Look for a label and inline.
                const main_token = main_tokens[n];
                var result = main_token;
                if (token_tags[result - 1] == .keyword_inline) {
                    result -= 1;
                }
                if (token_tags[result - 1] == .colon) {
                    result -= 2;
                }
                return result - end_offset;
            },
        };
    }

    pub fn lastToken(tree: Tree, node: Node.Index) TokenIndex {
        const tags = tree.nodes.items(.tag);
        const datas = tree.nodes.items(.data);
        const main_tokens = tree.nodes.items(.main_token);
        const token_starts = tree.tokens.items(.start);
        const token_tags = tree.tokens.items(.tag);
        var n = node;
        var end_offset: TokenIndex = 0;
        while (true) switch (tags[n]) {
            .root => return @intCast(TokenIndex, tree.tokens.len - 1),

            .@"usingnamespace",
            .bool_not,
            .negation,
            .bit_not,
            .negation_wrap,
            .address_of,
            .@"try",
            .@"await",
            .optional_type,
            .@"resume",
            .@"nosuspend",
            .@"comptime",
            => n = datas[n].lhs,

            .test_decl,
            .@"errdefer",
            .@"defer",
            .@"catch",
            .equal_equal,
            .bang_equal,
            .less_than,
            .greater_than,
            .less_or_equal,
            .greater_or_equal,
            .assign_mul,
            .assign_div,
            .assign_mod,
            .assign_add,
            .assign_sub,
            .assign_bit_shift_left,
            .assign_bit_shift_right,
            .assign_bit_and,
            .assign_bit_xor,
            .assign_bit_or,
            .assign_mul_wrap,
            .assign_add_wrap,
            .assign_sub_wrap,
            .assign,
            .merge_error_sets,
            .mul,
            .div,
            .mod,
            .array_mult,
            .mul_wrap,
            .add,
            .sub,
            .array_cat,
            .add_wrap,
            .sub_wrap,
            .bit_shift_left,
            .bit_shift_right,
            .bit_and,
            .bit_xor,
            .bit_or,
            .@"orelse",
            .bool_and,
            .bool_or,
            .anyframe_type,
            .error_union,
            .if_simple,
            .while_simple,
            .for_simple,
            .fn_proto_simple,
            .fn_proto_multi,
            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            .array_type,
            .switch_case_one,
            .switch_case,
            .switch_range,
            => n = datas[n].rhs,

            .field_access,
            .unwrap_optional,
            .grouped_expression,
            .multiline_string_literal,
            .error_set_decl,
            .asm_simple,
            .asm_output,
            .asm_input,
            .error_value,
            => return datas[n].rhs + end_offset,

            .@"anytype",
            .anyframe_literal,
            .char_literal,
            .integer_literal,
            .float_literal,
            .false_literal,
            .true_literal,
            .null_literal,
            .undefined_literal,
            .unreachable_literal,
            .identifier,
            .deref,
            .enum_literal,
            .string_literal,
            => return main_tokens[n] + end_offset,

            .@"return" => if (datas[n].lhs != 0) {
                n = datas[n].lhs;
            } else {
                return main_tokens[n] + end_offset;
            },

            .call, .async_call => {
                end_offset += 1; // for the rparen
                const params = tree.extraData(datas[n].rhs, Node.SubRange);
                if (params.end - params.start == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = tree.extra_data[params.end - 1]; // last parameter
            },
            .tagged_union_enum_tag => {
                const members = tree.extraData(datas[n].rhs, Node.SubRange);
                if (members.end - members.start == 0) {
                    end_offset += 4; // for the rparen + rparen + lbrace + rbrace
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // for the rbrace
                    n = tree.extra_data[members.end - 1]; // last parameter
                }
            },
            .call_comma,
            .async_call_comma,
            .tagged_union_enum_tag_trailing,
            => {
                end_offset += 2; // for the comma/semicolon + rparen/rbrace
                const params = tree.extraData(datas[n].rhs, Node.SubRange);
                assert(params.end > params.start);
                n = tree.extra_data[params.end - 1]; // last parameter
            },
            .@"switch" => {
                const cases = tree.extraData(datas[n].rhs, Node.SubRange);
                if (cases.end - cases.start == 0) {
                    end_offset += 3; // rparen, lbrace, rbrace
                    n = datas[n].lhs; // condition expression
                } else {
                    end_offset += 1; // for the rbrace
                    n = tree.extra_data[cases.end - 1]; // last case
                }
            },
            .container_decl_arg => {
                const members = tree.extraData(datas[n].rhs, Node.SubRange);
                if (members.end - members.start == 0) {
                    end_offset += 3; // for the rparen + lbrace + rbrace
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // for the rbrace
                    n = tree.extra_data[members.end - 1]; // last parameter
                }
            },
            .@"asm" => {
                const extra = tree.extraData(datas[n].rhs, Node.Asm);
                return extra.rparen + end_offset;
            },
            .array_init,
            .struct_init,
            => {
                const elements = tree.extraData(datas[n].rhs, Node.SubRange);
                assert(elements.end - elements.start > 0);
                end_offset += 1; // for the rbrace
                n = tree.extra_data[elements.end - 1]; // last element
            },
            .array_init_comma,
            .struct_init_comma,
            .container_decl_arg_trailing,
            .switch_comma,
            => {
                const members = tree.extraData(datas[n].rhs, Node.SubRange);
                assert(members.end - members.start > 0);
                end_offset += 2; // for the comma + rbrace
                n = tree.extra_data[members.end - 1]; // last parameter
            },
            .array_init_dot,
            .struct_init_dot,
            .block,
            .container_decl,
            .tagged_union,
            .builtin_call,
            => {
                assert(datas[n].rhs - datas[n].lhs > 0);
                end_offset += 1; // for the rbrace
                n = tree.extra_data[datas[n].rhs - 1]; // last statement
            },
            .array_init_dot_comma,
            .struct_init_dot_comma,
            .block_semicolon,
            .container_decl_trailing,
            .tagged_union_trailing,
            .builtin_call_comma,
            => {
                assert(datas[n].rhs - datas[n].lhs > 0);
                end_offset += 2; // for the comma/semicolon + rbrace/rparen
                n = tree.extra_data[datas[n].rhs - 1]; // last member
            },
            .call_one,
            .async_call_one,
            .array_access,
            => {
                end_offset += 1; // for the rparen/rbracket
                if (datas[n].rhs == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = datas[n].rhs;
            },
            .array_init_dot_two,
            .block_two,
            .builtin_call_two,
            .struct_init_dot_two,
            .container_decl_two,
            .tagged_union_two,
            => {
                if (datas[n].rhs != 0) {
                    end_offset += 1; // for the rparen/rbrace
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    end_offset += 1; // for the rparen/rbrace
                    n = datas[n].lhs;
                } else {
                    switch (tags[n]) {
                        .array_init_dot_two,
                        .block_two,
                        .struct_init_dot_two,
                        => end_offset += 1, // rbrace
                        .builtin_call_two => end_offset += 2, // lparen/lbrace + rparen/rbrace
                        .container_decl_two => {
                            var i: u32 = 2; // lbrace + rbrace
                            while (token_tags[main_tokens[n] + i] == .container_doc_comment) i += 1;
                            end_offset += i;
                        },
                        .tagged_union_two => {
                            var i: u32 = 5; // (enum) {}
                            while (token_tags[main_tokens[n] + i] == .container_doc_comment) i += 1;
                            end_offset += i;
                        },
                        else => unreachable,
                    }
                    return main_tokens[n] + end_offset;
                }
            },
            .array_init_dot_two_comma,
            .builtin_call_two_comma,
            .block_two_semicolon,
            .struct_init_dot_two_comma,
            .container_decl_two_trailing,
            .tagged_union_two_trailing,
            => {
                end_offset += 2; // for the comma/semicolon + rbrace/rparen
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    unreachable;
                }
            },
            .simple_var_decl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // from mut token to name
                    return main_tokens[n] + end_offset;
                }
            },
            .aligned_var_decl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    end_offset += 1; // for the rparen
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // from mut token to name
                    return main_tokens[n] + end_offset;
                }
            },
            .global_var_decl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else {
                    const extra = tree.extraData(datas[n].lhs, Node.GlobalVarDecl);
                    if (extra.section_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.section_node;
                    } else if (extra.align_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.align_node;
                    } else if (extra.type_node != 0) {
                        n = extra.type_node;
                    } else {
                        end_offset += 1; // from mut token to name
                        return main_tokens[n] + end_offset;
                    }
                }
            },
            .local_var_decl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else {
                    const extra = tree.extraData(datas[n].lhs, Node.LocalVarDecl);
                    if (extra.align_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.align_node;
                    } else if (extra.type_node != 0) {
                        n = extra.type_node;
                    } else {
                        end_offset += 1; // from mut token to name
                        return main_tokens[n] + end_offset;
                    }
                }
            },
            .container_field_init => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .container_field_align => {
                if (datas[n].rhs != 0) {
                    end_offset += 1; // for the rparen
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .container_field => {
                const extra = tree.extraData(datas[n].rhs, Node.ContainerField);
                if (extra.value_expr != 0) {
                    n = extra.value_expr;
                } else if (extra.align_expr != 0) {
                    end_offset += 1; // for the rparen
                    n = extra.align_expr;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },

            .array_init_one,
            .struct_init_one,
            => {
                end_offset += 1; // rbrace
                if (datas[n].rhs == 0) {
                    return main_tokens[n] + end_offset;
                } else {
                    n = datas[n].rhs;
                }
            },
            .slice_open,
            .call_one_comma,
            .async_call_one_comma,
            .array_init_one_comma,
            .struct_init_one_comma,
            => {
                end_offset += 2; // ellipsis2 + rbracket, or comma + rparen
                n = datas[n].rhs;
                assert(n != 0);
            },
            .slice => {
                const extra = tree.extraData(datas[n].rhs, Node.Slice);
                assert(extra.end != 0); // should have used slice_open
                end_offset += 1; // rbracket
                n = extra.end;
            },
            .slice_sentinel => {
                const extra = tree.extraData(datas[n].rhs, Node.SliceSentinel);
                assert(extra.sentinel != 0); // should have used slice
                end_offset += 1; // rbracket
                n = extra.sentinel;
            },

            .@"continue" => {
                if (datas[n].lhs != 0) {
                    return datas[n].lhs + end_offset;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .@"break" => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    return datas[n].lhs + end_offset;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .fn_decl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else {
                    n = datas[n].lhs;
                }
            },
            .fn_proto_one => {
                const extra = tree.extraData(datas[n].lhs, Node.FnProtoOne);
                // linksection, callconv, align can appear in any order, so we
                // find the last one here.
                var max_node: Node.Index = datas[n].rhs;
                var max_start = token_starts[main_tokens[max_node]];
                var max_offset: TokenIndex = 0;
                if (extra.align_expr != 0) {
                    const start = token_starts[main_tokens[extra.align_expr]];
                    if (start > max_start) {
                        max_node = extra.align_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                if (extra.section_expr != 0) {
                    const start = token_starts[main_tokens[extra.section_expr]];
                    if (start > max_start) {
                        max_node = extra.section_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                if (extra.callconv_expr != 0) {
                    const start = token_starts[main_tokens[extra.callconv_expr]];
                    if (start > max_start) {
                        max_node = extra.callconv_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                n = max_node;
                end_offset += max_offset;
            },
            .fn_proto => {
                const extra = tree.extraData(datas[n].lhs, Node.FnProto);
                // linksection, callconv, align can appear in any order, so we
                // find the last one here.
                var max_node: Node.Index = datas[n].rhs;
                var max_start = token_starts[main_tokens[max_node]];
                var max_offset: TokenIndex = 0;
                if (extra.align_expr != 0) {
                    const start = token_starts[main_tokens[extra.align_expr]];
                    if (start > max_start) {
                        max_node = extra.align_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                if (extra.section_expr != 0) {
                    const start = token_starts[main_tokens[extra.section_expr]];
                    if (start > max_start) {
                        max_node = extra.section_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                if (extra.callconv_expr != 0) {
                    const start = token_starts[main_tokens[extra.callconv_expr]];
                    if (start > max_start) {
                        max_node = extra.callconv_expr;
                        max_start = start;
                        max_offset = 1; // for the rparen
                    }
                }
                n = max_node;
                end_offset += max_offset;
            },
            .while_cont => {
                const extra = tree.extraData(datas[n].rhs, Node.WhileCont);
                assert(extra.then_expr != 0);
                n = extra.then_expr;
            },
            .@"while" => {
                const extra = tree.extraData(datas[n].rhs, Node.While);
                assert(extra.else_expr != 0);
                n = extra.else_expr;
            },
            .@"if", .@"for" => {
                const extra = tree.extraData(datas[n].rhs, Node.If);
                assert(extra.else_expr != 0);
                n = extra.else_expr;
            },
            .@"suspend" => {
                if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .array_type_sentinel => {
                const extra = tree.extraData(datas[n].rhs, Node.ArrayTypeSentinel);
                n = extra.elem_type;
            },
        };
    }

    pub fn tokensOnSameLine(tree: Tree, token1: TokenIndex, token2: TokenIndex) bool {
        const token_starts = tree.tokens.items(.start);
        const source = tree.source[token_starts[token1]..token_starts[token2]];
        return mem.indexOfScalar(u8, source, '\n') == null;
    }

    pub fn getNodeSource(tree: Tree, node: Node.Index) []const u8 {
        const token_starts = tree.tokens.items(.start);
        const first_token = tree.firstToken(node);
        const last_token = tree.lastToken(node);
        const start = token_starts[first_token];
        const end = token_starts[last_token] + tree.tokenSlice(last_token).len;
        return tree.source[start..end];
    }

    pub fn globalVarDecl(tree: Tree, node: Node.Index) full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .global_var_decl);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.GlobalVarDecl);
        return tree.fullVarDecl(.{
            .type_node = extra.type_node,
            .align_node = extra.align_node,
            .section_node = extra.section_node,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn localVarDecl(tree: Tree, node: Node.Index) full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .local_var_decl);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.LocalVarDecl);
        return tree.fullVarDecl(.{
            .type_node = extra.type_node,
            .align_node = extra.align_node,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn simpleVarDecl(tree: Tree, node: Node.Index) full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .simple_var_decl);
        const data = tree.nodes.items(.data)[node];
        return tree.fullVarDecl(.{
            .type_node = data.lhs,
            .align_node = 0,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn alignedVarDecl(tree: Tree, node: Node.Index) full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .aligned_var_decl);
        const data = tree.nodes.items(.data)[node];
        return tree.fullVarDecl(.{
            .type_node = 0,
            .align_node = data.lhs,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn ifSimple(tree: Tree, node: Node.Index) full.If {
        assert(tree.nodes.items(.tag)[node] == .if_simple);
        const data = tree.nodes.items(.data)[node];
        return tree.fullIf(.{
            .cond_expr = data.lhs,
            .then_expr = data.rhs,
            .else_expr = 0,
            .if_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn ifFull(tree: Tree, node: Node.Index) full.If {
        assert(tree.nodes.items(.tag)[node] == .@"if");
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.If);
        return tree.fullIf(.{
            .cond_expr = data.lhs,
            .then_expr = extra.then_expr,
            .else_expr = extra.else_expr,
            .if_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn containerField(tree: Tree, node: Node.Index) full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .container_field);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.ContainerField);
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = extra.value_expr,
            .align_expr = extra.align_expr,
        });
    }

    pub fn containerFieldInit(tree: Tree, node: Node.Index) full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .container_field_init);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = data.rhs,
            .align_expr = 0,
        });
    }

    pub fn containerFieldAlign(tree: Tree, node: Node.Index) full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .container_field_align);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = 0,
            .align_expr = data.rhs,
        });
    }

    pub fn fnProtoSimple(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .fn_proto_simple);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.lhs;
        const params = if (data.lhs == 0) buffer[0..0] else buffer[0..1];
        return tree.fullFnProto(.{
            .proto_node = node,
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = 0,
            .section_expr = 0,
            .callconv_expr = 0,
        });
    }

    pub fn fnProtoMulti(tree: Tree, node: Node.Index) full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .fn_proto_multi);
        const data = tree.nodes.items(.data)[node];
        const params_range = tree.extraData(data.lhs, Node.SubRange);
        const params = tree.extra_data[params_range.start..params_range.end];
        return tree.fullFnProto(.{
            .proto_node = node,
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = 0,
            .section_expr = 0,
            .callconv_expr = 0,
        });
    }

    pub fn fnProtoOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .fn_proto_one);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.FnProtoOne);
        buffer[0] = extra.param;
        const params = if (extra.param == 0) buffer[0..0] else buffer[0..1];
        return tree.fullFnProto(.{
            .proto_node = node,
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = extra.align_expr,
            .section_expr = extra.section_expr,
            .callconv_expr = extra.callconv_expr,
        });
    }

    pub fn fnProto(tree: Tree, node: Node.Index) full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .fn_proto);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.FnProto);
        const params = tree.extra_data[extra.params_start..extra.params_end];
        return tree.fullFnProto(.{
            .proto_node = node,
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = extra.align_expr,
            .section_expr = extra.section_expr,
            .callconv_expr = extra.callconv_expr,
        });
    }

    pub fn structInitOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .struct_init_one or
            tree.nodes.items(.tag)[node] == .struct_init_one_comma);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.rhs;
        const fields = if (data.rhs == 0) buffer[0..0] else buffer[0..1];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = fields,
            .type_expr = data.lhs,
        });
    }

    pub fn structInitDotTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .struct_init_dot_two or
            tree.nodes.items(.tag)[node] == .struct_init_dot_two_comma);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const fields = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = fields,
            .type_expr = 0,
        });
    }

    pub fn structInitDot(tree: Tree, node: Node.Index) full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .struct_init_dot or
            tree.nodes.items(.tag)[node] == .struct_init_dot_comma);
        const data = tree.nodes.items(.data)[node];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = tree.extra_data[data.lhs..data.rhs],
            .type_expr = 0,
        });
    }

    pub fn structInit(tree: Tree, node: Node.Index) full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .struct_init or
            tree.nodes.items(.tag)[node] == .struct_init_comma);
        const data = tree.nodes.items(.data)[node];
        const fields_range = tree.extraData(data.rhs, Node.SubRange);
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = tree.extra_data[fields_range.start..fields_range.end],
            .type_expr = data.lhs,
        });
    }

    pub fn arrayInitOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .array_init_one or
            tree.nodes.items(.tag)[node] == .array_init_one_comma);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.rhs;
        const elements = if (data.rhs == 0) buffer[0..0] else buffer[0..1];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = elements,
                .type_expr = data.lhs,
            },
        };
    }

    pub fn arrayInitDotTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .array_init_dot_two or
            tree.nodes.items(.tag)[node] == .array_init_dot_two_comma);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const elements = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = elements,
                .type_expr = 0,
            },
        };
    }

    pub fn arrayInitDot(tree: Tree, node: Node.Index) full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .array_init_dot or
            tree.nodes.items(.tag)[node] == .array_init_dot_comma);
        const data = tree.nodes.items(.data)[node];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = tree.extra_data[data.lhs..data.rhs],
                .type_expr = 0,
            },
        };
    }

    pub fn arrayInit(tree: Tree, node: Node.Index) full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .array_init or
            tree.nodes.items(.tag)[node] == .array_init_comma);
        const data = tree.nodes.items(.data)[node];
        const elem_range = tree.extraData(data.rhs, Node.SubRange);
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = tree.extra_data[elem_range.start..elem_range.end],
                .type_expr = data.lhs,
            },
        };
    }

    pub fn arrayType(tree: Tree, node: Node.Index) full.ArrayType {
        assert(tree.nodes.items(.tag)[node] == .array_type);
        const data = tree.nodes.items(.data)[node];
        return .{
            .ast = .{
                .lbracket = tree.nodes.items(.main_token)[node],
                .elem_count = data.lhs,
                .sentinel = 0,
                .elem_type = data.rhs,
            },
        };
    }

    pub fn arrayTypeSentinel(tree: Tree, node: Node.Index) full.ArrayType {
        assert(tree.nodes.items(.tag)[node] == .array_type_sentinel);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.ArrayTypeSentinel);
        assert(extra.sentinel != 0);
        return .{
            .ast = .{
                .lbracket = tree.nodes.items(.main_token)[node],
                .elem_count = data.lhs,
                .sentinel = extra.sentinel,
                .elem_type = extra.elem_type,
            },
        };
    }

    pub fn ptrTypeAligned(tree: Tree, node: Node.Index) full.PtrType {
        assert(tree.nodes.items(.tag)[node] == .ptr_type_aligned);
        const data = tree.nodes.items(.data)[node];
        return tree.fullPtrType(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .align_node = data.lhs,
            .sentinel = 0,
            .bit_range_start = 0,
            .bit_range_end = 0,
            .child_type = data.rhs,
        });
    }

    pub fn ptrTypeSentinel(tree: Tree, node: Node.Index) full.PtrType {
        assert(tree.nodes.items(.tag)[node] == .ptr_type_sentinel);
        const data = tree.nodes.items(.data)[node];
        return tree.fullPtrType(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .align_node = 0,
            .sentinel = data.lhs,
            .bit_range_start = 0,
            .bit_range_end = 0,
            .child_type = data.rhs,
        });
    }

    pub fn ptrType(tree: Tree, node: Node.Index) full.PtrType {
        assert(tree.nodes.items(.tag)[node] == .ptr_type);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.PtrType);
        return tree.fullPtrType(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .align_node = extra.align_node,
            .sentinel = extra.sentinel,
            .bit_range_start = 0,
            .bit_range_end = 0,
            .child_type = data.rhs,
        });
    }

    pub fn ptrTypeBitRange(tree: Tree, node: Node.Index) full.PtrType {
        assert(tree.nodes.items(.tag)[node] == .ptr_type_bit_range);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.PtrTypeBitRange);
        return tree.fullPtrType(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .align_node = extra.align_node,
            .sentinel = extra.sentinel,
            .bit_range_start = extra.bit_range_start,
            .bit_range_end = extra.bit_range_end,
            .child_type = data.rhs,
        });
    }

    pub fn sliceOpen(tree: Tree, node: Node.Index) full.Slice {
        assert(tree.nodes.items(.tag)[node] == .slice_open);
        const data = tree.nodes.items(.data)[node];
        return .{
            .ast = .{
                .sliced = data.lhs,
                .lbracket = tree.nodes.items(.main_token)[node],
                .start = data.rhs,
                .end = 0,
                .sentinel = 0,
            },
        };
    }

    pub fn slice(tree: Tree, node: Node.Index) full.Slice {
        assert(tree.nodes.items(.tag)[node] == .slice);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.Slice);
        return .{
            .ast = .{
                .sliced = data.lhs,
                .lbracket = tree.nodes.items(.main_token)[node],
                .start = extra.start,
                .end = extra.end,
                .sentinel = 0,
            },
        };
    }

    pub fn sliceSentinel(tree: Tree, node: Node.Index) full.Slice {
        assert(tree.nodes.items(.tag)[node] == .slice_sentinel);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.SliceSentinel);
        return .{
            .ast = .{
                .sliced = data.lhs,
                .lbracket = tree.nodes.items(.main_token)[node],
                .start = extra.start,
                .end = extra.end,
                .sentinel = extra.sentinel,
            },
        };
    }

    pub fn containerDeclTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .container_decl_two or
            tree.nodes.items(.tag)[node] == .container_decl_two_trailing);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const members = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = members,
            .arg = 0,
        });
    }

    pub fn containerDecl(tree: Tree, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .container_decl or
            tree.nodes.items(.tag)[node] == .container_decl_trailing);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = tree.extra_data[data.lhs..data.rhs],
            .arg = 0,
        });
    }

    pub fn containerDeclArg(tree: Tree, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .container_decl_arg or
            tree.nodes.items(.tag)[node] == .container_decl_arg_trailing);
        const data = tree.nodes.items(.data)[node];
        const members_range = tree.extraData(data.rhs, Node.SubRange);
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = tree.extra_data[members_range.start..members_range.end],
            .arg = data.lhs,
        });
    }

    pub fn taggedUnionTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .tagged_union_two or
            tree.nodes.items(.tag)[node] == .tagged_union_two_trailing);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const members = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = members,
            .arg = 0,
        });
    }

    pub fn taggedUnion(tree: Tree, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .tagged_union or
            tree.nodes.items(.tag)[node] == .tagged_union_trailing);
        const data = tree.nodes.items(.data)[node];
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = tree.extra_data[data.lhs..data.rhs],
            .arg = 0,
        });
    }

    pub fn taggedUnionEnumTag(tree: Tree, node: Node.Index) full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .tagged_union_enum_tag or
            tree.nodes.items(.tag)[node] == .tagged_union_enum_tag_trailing);
        const data = tree.nodes.items(.data)[node];
        const members_range = tree.extraData(data.rhs, Node.SubRange);
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = tree.extra_data[members_range.start..members_range.end],
            .arg = data.lhs,
        });
    }

    pub fn switchCaseOne(tree: Tree, node: Node.Index) full.SwitchCase {
        const data = &tree.nodes.items(.data)[node];
        const values: *[1]Node.Index = &data.lhs;
        return tree.fullSwitchCase(.{
            .values = if (data.lhs == 0) values[0..0] else values[0..1],
            .arrow_token = tree.nodes.items(.main_token)[node],
            .target_expr = data.rhs,
        });
    }

    pub fn switchCase(tree: Tree, node: Node.Index) full.SwitchCase {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.SubRange);
        return tree.fullSwitchCase(.{
            .values = tree.extra_data[extra.start..extra.end],
            .arrow_token = tree.nodes.items(.main_token)[node],
            .target_expr = data.rhs,
        });
    }

    pub fn asmSimple(tree: Tree, node: Node.Index) full.Asm {
        const data = tree.nodes.items(.data)[node];
        return tree.fullAsm(.{
            .asm_token = tree.nodes.items(.main_token)[node],
            .template = data.lhs,
            .items = &.{},
            .rparen = data.rhs,
        });
    }

    pub fn asmFull(tree: Tree, node: Node.Index) full.Asm {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.Asm);
        return tree.fullAsm(.{
            .asm_token = tree.nodes.items(.main_token)[node],
            .template = data.lhs,
            .items = tree.extra_data[extra.items_start..extra.items_end],
            .rparen = extra.rparen,
        });
    }

    pub fn whileSimple(tree: Tree, node: Node.Index) full.While {
        const data = tree.nodes.items(.data)[node];
        return tree.fullWhile(.{
            .while_token = tree.nodes.items(.main_token)[node],
            .cond_expr = data.lhs,
            .cont_expr = 0,
            .then_expr = data.rhs,
            .else_expr = 0,
        });
    }

    pub fn whileCont(tree: Tree, node: Node.Index) full.While {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.WhileCont);
        return tree.fullWhile(.{
            .while_token = tree.nodes.items(.main_token)[node],
            .cond_expr = data.lhs,
            .cont_expr = extra.cont_expr,
            .then_expr = extra.then_expr,
            .else_expr = 0,
        });
    }

    pub fn whileFull(tree: Tree, node: Node.Index) full.While {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.While);
        return tree.fullWhile(.{
            .while_token = tree.nodes.items(.main_token)[node],
            .cond_expr = data.lhs,
            .cont_expr = extra.cont_expr,
            .then_expr = extra.then_expr,
            .else_expr = extra.else_expr,
        });
    }

    pub fn forSimple(tree: Tree, node: Node.Index) full.While {
        const data = tree.nodes.items(.data)[node];
        return tree.fullWhile(.{
            .while_token = tree.nodes.items(.main_token)[node],
            .cond_expr = data.lhs,
            .cont_expr = 0,
            .then_expr = data.rhs,
            .else_expr = 0,
        });
    }

    pub fn forFull(tree: Tree, node: Node.Index) full.While {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.If);
        return tree.fullWhile(.{
            .while_token = tree.nodes.items(.main_token)[node],
            .cond_expr = data.lhs,
            .cont_expr = 0,
            .then_expr = extra.then_expr,
            .else_expr = extra.else_expr,
        });
    }

    pub fn callOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) full.Call {
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{data.rhs};
        const params = if (data.rhs != 0) buffer[0..1] else buffer[0..0];
        return tree.fullCall(.{
            .lparen = tree.nodes.items(.main_token)[node],
            .fn_expr = data.lhs,
            .params = params,
        });
    }

    pub fn callFull(tree: Tree, node: Node.Index) full.Call {
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.SubRange);
        return tree.fullCall(.{
            .lparen = tree.nodes.items(.main_token)[node],
            .fn_expr = data.lhs,
            .params = tree.extra_data[extra.start..extra.end],
        });
    }

    fn fullVarDecl(tree: Tree, info: full.VarDecl.Ast) full.VarDecl {
        const token_tags = tree.tokens.items(.tag);
        var result: full.VarDecl = .{
            .ast = info,
            .visib_token = null,
            .extern_export_token = null,
            .lib_name = null,
            .threadlocal_token = null,
            .comptime_token = null,
        };
        var i = info.mut_token;
        while (i > 0) {
            i -= 1;
            switch (token_tags[i]) {
                .keyword_extern, .keyword_export => result.extern_export_token = i,
                .keyword_comptime => result.comptime_token = i,
                .keyword_pub => result.visib_token = i,
                .keyword_threadlocal => result.threadlocal_token = i,
                .string_literal => result.lib_name = i,
                else => break,
            }
        }
        return result;
    }

    fn fullIf(tree: Tree, info: full.If.Ast) full.If {
        const token_tags = tree.tokens.items(.tag);
        var result: full.If = .{
            .ast = info,
            .payload_token = null,
            .error_token = null,
            .else_token = undefined,
        };
        // if (cond_expr) |x|
        //              ^ ^
        const payload_pipe = tree.lastToken(info.cond_expr) + 2;
        if (token_tags[payload_pipe] == .pipe) {
            result.payload_token = payload_pipe + 1;
        }
        if (info.else_expr != 0) {
            // then_expr else |x|
            //           ^    ^
            result.else_token = tree.lastToken(info.then_expr) + 1;
            if (token_tags[result.else_token + 1] == .pipe) {
                result.error_token = result.else_token + 2;
            }
        }
        return result;
    }

    fn fullContainerField(tree: Tree, info: full.ContainerField.Ast) full.ContainerField {
        const token_tags = tree.tokens.items(.tag);
        var result: full.ContainerField = .{
            .ast = info,
            .comptime_token = null,
        };
        // comptime name: type = init,
        // ^
        if (info.name_token > 0 and token_tags[info.name_token - 1] == .keyword_comptime) {
            result.comptime_token = info.name_token - 1;
        }
        return result;
    }

    fn fullFnProto(tree: Tree, info: full.FnProto.Ast) full.FnProto {
        const token_tags = tree.tokens.items(.tag);
        var result: full.FnProto = .{
            .ast = info,
            .visib_token = null,
            .extern_export_token = null,
            .lib_name = null,
            .name_token = null,
            .lparen = undefined,
        };
        var i = info.fn_token;
        while (i > 0) {
            i -= 1;
            switch (token_tags[i]) {
                .keyword_extern, .keyword_export => result.extern_export_token = i,
                .keyword_pub => result.visib_token = i,
                .string_literal => result.lib_name = i,
                else => break,
            }
        }
        const after_fn_token = info.fn_token + 1;
        if (token_tags[after_fn_token] == .identifier) {
            result.name_token = after_fn_token;
            result.lparen = after_fn_token + 1;
        } else {
            result.lparen = after_fn_token;
        }
        assert(token_tags[result.lparen] == .l_paren);

        return result;
    }

    fn fullStructInit(tree: Tree, info: full.StructInit.Ast) full.StructInit {
        const token_tags = tree.tokens.items(.tag);
        var result: full.StructInit = .{
            .ast = info,
        };
        return result;
    }

    fn fullPtrType(tree: Tree, info: full.PtrType.Ast) full.PtrType {
        const token_tags = tree.tokens.items(.tag);
        // TODO: looks like stage1 isn't quite smart enough to handle enum
        // literals in some places here
        const Size = std.builtin.TypeInfo.Pointer.Size;
        const size: Size = switch (token_tags[info.main_token]) {
            .asterisk,
            .asterisk_asterisk,
            => switch (token_tags[info.main_token + 1]) {
                .r_bracket, .colon => .Many,
                .identifier => if (token_tags[info.main_token - 1] == .l_bracket) Size.C else .One,
                else => .One,
            },
            .l_bracket => Size.Slice,
            else => unreachable,
        };
        var result: full.PtrType = .{
            .size = size,
            .allowzero_token = null,
            .const_token = null,
            .volatile_token = null,
            .ast = info,
        };
        // We need to be careful that we don't iterate over any sub-expressions
        // here while looking for modifiers as that could result in false
        // positives. Therefore, start after a sentinel if there is one and
        // skip over any align node and bit range nodes.
        var i = if (info.sentinel != 0) tree.lastToken(info.sentinel) + 1 else info.main_token;
        const end = tree.firstToken(info.child_type);
        while (i < end) : (i += 1) {
            switch (token_tags[i]) {
                .keyword_allowzero => result.allowzero_token = i,
                .keyword_const => result.const_token = i,
                .keyword_volatile => result.volatile_token = i,
                .keyword_align => {
                    assert(info.align_node != 0);
                    if (info.bit_range_end != 0) {
                        assert(info.bit_range_start != 0);
                        i = tree.lastToken(info.bit_range_end) + 1;
                    } else {
                        i = tree.lastToken(info.align_node) + 1;
                    }
                },
                else => {},
            }
        }
        return result;
    }

    fn fullContainerDecl(tree: Tree, info: full.ContainerDecl.Ast) full.ContainerDecl {
        const token_tags = tree.tokens.items(.tag);
        var result: full.ContainerDecl = .{
            .ast = info,
            .layout_token = null,
        };
        switch (token_tags[info.main_token - 1]) {
            .keyword_extern, .keyword_packed => result.layout_token = info.main_token - 1,
            else => {},
        }
        return result;
    }

    fn fullSwitchCase(tree: Tree, info: full.SwitchCase.Ast) full.SwitchCase {
        const token_tags = tree.tokens.items(.tag);
        var result: full.SwitchCase = .{
            .ast = info,
            .payload_token = null,
        };
        if (token_tags[info.arrow_token + 1] == .pipe) {
            result.payload_token = info.arrow_token + 2;
        }
        return result;
    }

    fn fullAsm(tree: Tree, info: full.Asm.Ast) full.Asm {
        const token_tags = tree.tokens.items(.tag);
        const node_tags = tree.nodes.items(.tag);
        var result: full.Asm = .{
            .ast = info,
            .volatile_token = null,
            .inputs = &.{},
            .outputs = &.{},
            .first_clobber = null,
        };
        if (token_tags[info.asm_token + 1] == .keyword_volatile) {
            result.volatile_token = info.asm_token + 1;
        }
        const outputs_end: usize = for (info.items) |item, i| {
            switch (node_tags[item]) {
                .asm_output => continue,
                else => break i,
            }
        } else info.items.len;

        result.outputs = info.items[0..outputs_end];
        result.inputs = info.items[outputs_end..];

        if (info.items.len == 0) {
            // asm ("foo" ::: "a", "b");
            const template_token = tree.lastToken(info.template);
            if (token_tags[template_token + 1] == .colon and
                token_tags[template_token + 2] == .colon and
                token_tags[template_token + 3] == .colon and
                token_tags[template_token + 4] == .string_literal)
            {
                result.first_clobber = template_token + 4;
            }
        } else if (result.inputs.len != 0) {
            // asm ("foo" :: [_] "" (y) : "a", "b");
            const last_input = result.inputs[result.inputs.len - 1];
            const rparen = tree.lastToken(last_input);
            var i = rparen + 1;
            // Allow a (useless) comma right after the closing parenthesis.
            if (token_tags[i] == .comma) i += 1;
            if (token_tags[i] == .colon and
                token_tags[i + 1] == .string_literal)
            {
                result.first_clobber = i + 1;
            }
        } else {
            // asm ("foo" : [_] "" (x) :: "a", "b");
            const last_output = result.outputs[result.outputs.len - 1];
            const rparen = tree.lastToken(last_output);
            var i = rparen + 1;
            // Allow a (useless) comma right after the closing parenthesis.
            if (token_tags[i] == .comma) i += 1;
            if (token_tags[i] == .colon and
                token_tags[i + 1] == .colon and
                token_tags[i + 2] == .string_literal)
            {
                result.first_clobber = i + 2;
            }
        }

        return result;
    }

    fn fullWhile(tree: Tree, info: full.While.Ast) full.While {
        const token_tags = tree.tokens.items(.tag);
        var result: full.While = .{
            .ast = info,
            .inline_token = null,
            .label_token = null,
            .payload_token = null,
            .else_token = undefined,
            .error_token = null,
        };
        var tok_i = info.while_token - 1;
        if (token_tags[tok_i] == .keyword_inline) {
            result.inline_token = tok_i;
            tok_i -= 1;
        }
        if (token_tags[tok_i] == .colon and
            token_tags[tok_i - 1] == .identifier)
        {
            result.label_token = tok_i - 1;
        }
        const last_cond_token = tree.lastToken(info.cond_expr);
        if (token_tags[last_cond_token + 2] == .pipe) {
            result.payload_token = last_cond_token + 3;
        }
        if (info.else_expr != 0) {
            // then_expr else |x|
            //           ^    ^
            result.else_token = tree.lastToken(info.then_expr) + 1;
            if (token_tags[result.else_token + 1] == .pipe) {
                result.error_token = result.else_token + 2;
            }
        }
        return result;
    }

    fn fullCall(tree: Tree, info: full.Call.Ast) full.Call {
        const token_tags = tree.tokens.items(.tag);
        var result: full.Call = .{
            .ast = info,
            .async_token = null,
        };
        const maybe_async_token = tree.firstToken(info.fn_expr) - 1;
        if (token_tags[maybe_async_token] == .keyword_async) {
            result.async_token = maybe_async_token;
        }
        return result;
    }
};

/// Fully assembled AST node information.
pub const full = struct {
    pub const VarDecl = struct {
        visib_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?TokenIndex,
        threadlocal_token: ?TokenIndex,
        comptime_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            mut_token: TokenIndex,
            type_node: Node.Index,
            align_node: Node.Index,
            section_node: Node.Index,
            init_node: Node.Index,
        };
    };

    pub const If = struct {
        /// Points to the first token after the `|`. Will either be an identifier or
        /// a `*` (with an identifier immediately after it).
        payload_token: ?TokenIndex,
        /// Points to the identifier after the `|`.
        error_token: ?TokenIndex,
        /// Populated only if else_expr != 0.
        else_token: TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            if_token: TokenIndex,
            cond_expr: Node.Index,
            then_expr: Node.Index,
            else_expr: Node.Index,
        };
    };

    pub const While = struct {
        ast: Ast,
        inline_token: ?TokenIndex,
        label_token: ?TokenIndex,
        payload_token: ?TokenIndex,
        error_token: ?TokenIndex,
        /// Populated only if else_expr != 0.
        else_token: TokenIndex,

        pub const Ast = struct {
            while_token: TokenIndex,
            cond_expr: Node.Index,
            cont_expr: Node.Index,
            then_expr: Node.Index,
            else_expr: Node.Index,
        };
    };

    pub const ContainerField = struct {
        comptime_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            name_token: TokenIndex,
            type_expr: Node.Index,
            value_expr: Node.Index,
            align_expr: Node.Index,
        };
    };

    pub const FnProto = struct {
        visib_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?TokenIndex,
        name_token: ?TokenIndex,
        lparen: TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            proto_node: Node.Index,
            fn_token: TokenIndex,
            return_type: Node.Index,
            params: []const Node.Index,
            align_expr: Node.Index,
            section_expr: Node.Index,
            callconv_expr: Node.Index,
        };

        pub const Param = struct {
            first_doc_comment: ?TokenIndex,
            name_token: ?TokenIndex,
            comptime_noalias: ?TokenIndex,
            anytype_ellipsis3: ?TokenIndex,
            type_expr: Node.Index,
        };

        /// Abstracts over the fact that anytype and ... are not included
        /// in the params slice, since they are simple identifiers and
        /// not sub-expressions.
        pub const Iterator = struct {
            tree: *const Tree,
            fn_proto: *const FnProto,
            param_i: usize,
            tok_i: TokenIndex,
            tok_flag: bool,

            pub fn next(it: *Iterator) ?Param {
                const token_tags = it.tree.tokens.items(.tag);
                while (true) {
                    var first_doc_comment: ?TokenIndex = null;
                    var comptime_noalias: ?TokenIndex = null;
                    var name_token: ?TokenIndex = null;
                    if (!it.tok_flag) {
                        if (it.param_i >= it.fn_proto.ast.params.len) {
                            return null;
                        }
                        const param_type = it.fn_proto.ast.params[it.param_i];
                        var tok_i = it.tree.firstToken(param_type) - 1;
                        while (true) : (tok_i -= 1) switch (token_tags[tok_i]) {
                            .colon => continue,
                            .identifier => name_token = tok_i,
                            .doc_comment => first_doc_comment = tok_i,
                            .keyword_comptime, .keyword_noalias => comptime_noalias = tok_i,
                            else => break,
                        };
                        it.param_i += 1;
                        it.tok_i = it.tree.lastToken(param_type) + 1;
                        // Look for anytype and ... params afterwards.
                        if (token_tags[it.tok_i] == .comma) {
                            it.tok_i += 1;
                        }
                        it.tok_flag = true;
                        return Param{
                            .first_doc_comment = first_doc_comment,
                            .comptime_noalias = comptime_noalias,
                            .name_token = name_token,
                            .anytype_ellipsis3 = null,
                            .type_expr = param_type,
                        };
                    }
                    if (token_tags[it.tok_i] == .r_paren) {
                        return null;
                    }
                    if (token_tags[it.tok_i] == .doc_comment) {
                        first_doc_comment = it.tok_i;
                        while (token_tags[it.tok_i] == .doc_comment) {
                            it.tok_i += 1;
                        }
                    }
                    switch (token_tags[it.tok_i]) {
                        .ellipsis3 => {
                            it.tok_flag = false; // Next iteration should return null.
                            return Param{
                                .first_doc_comment = first_doc_comment,
                                .comptime_noalias = null,
                                .name_token = null,
                                .anytype_ellipsis3 = it.tok_i,
                                .type_expr = 0,
                            };
                        },
                        .keyword_noalias, .keyword_comptime => {
                            comptime_noalias = it.tok_i;
                            it.tok_i += 1;
                        },
                        else => {},
                    }
                    if (token_tags[it.tok_i] == .identifier and
                        token_tags[it.tok_i + 1] == .colon)
                    {
                        name_token = it.tok_i;
                        it.tok_i += 2;
                    }
                    if (token_tags[it.tok_i] == .keyword_anytype) {
                        it.tok_i += 1;
                        return Param{
                            .first_doc_comment = first_doc_comment,
                            .comptime_noalias = comptime_noalias,
                            .name_token = name_token,
                            .anytype_ellipsis3 = it.tok_i - 1,
                            .type_expr = 0,
                        };
                    }
                    it.tok_flag = false;
                }
            }
        };

        pub fn iterate(fn_proto: FnProto, tree: Tree) Iterator {
            return .{
                .tree = &tree,
                .fn_proto = &fn_proto,
                .param_i = 0,
                .tok_i = fn_proto.lparen + 1,
                .tok_flag = true,
            };
        }
    };

    pub const StructInit = struct {
        ast: Ast,

        pub const Ast = struct {
            lbrace: TokenIndex,
            fields: []const Node.Index,
            type_expr: Node.Index,
        };
    };

    pub const ArrayInit = struct {
        ast: Ast,

        pub const Ast = struct {
            lbrace: TokenIndex,
            elements: []const Node.Index,
            type_expr: Node.Index,
        };
    };

    pub const ArrayType = struct {
        ast: Ast,

        pub const Ast = struct {
            lbracket: TokenIndex,
            elem_count: Node.Index,
            sentinel: Node.Index,
            elem_type: Node.Index,
        };
    };

    pub const PtrType = struct {
        size: std.builtin.TypeInfo.Pointer.Size,
        allowzero_token: ?TokenIndex,
        const_token: ?TokenIndex,
        volatile_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            main_token: TokenIndex,
            align_node: Node.Index,
            sentinel: Node.Index,
            bit_range_start: Node.Index,
            bit_range_end: Node.Index,
            child_type: Node.Index,
        };
    };

    pub const Slice = struct {
        ast: Ast,

        pub const Ast = struct {
            sliced: Node.Index,
            lbracket: TokenIndex,
            start: Node.Index,
            end: Node.Index,
            sentinel: Node.Index,
        };
    };

    pub const ContainerDecl = struct {
        layout_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            main_token: TokenIndex,
            /// Populated when main_token is Keyword_union.
            enum_token: ?TokenIndex,
            members: []const Node.Index,
            arg: Node.Index,
        };
    };

    pub const SwitchCase = struct {
        /// Points to the first token after the `|`. Will either be an identifier or
        /// a `*` (with an identifier immediately after it).
        payload_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            /// If empty, this is an else case
            values: []const Node.Index,
            arrow_token: TokenIndex,
            target_expr: Node.Index,
        };
    };

    pub const Asm = struct {
        ast: Ast,
        volatile_token: ?TokenIndex,
        first_clobber: ?TokenIndex,
        outputs: []const Node.Index,
        inputs: []const Node.Index,

        pub const Ast = struct {
            asm_token: TokenIndex,
            template: Node.Index,
            items: []const Node.Index,
            rparen: TokenIndex,
        };
    };

    pub const Call = struct {
        ast: Ast,
        async_token: ?TokenIndex,

        pub const Ast = struct {
            lparen: TokenIndex,
            fn_expr: Node.Index,
            params: []const Node.Index,
        };
    };
};

pub const Error = struct {
    tag: Tag,
    token: TokenIndex,
    extra: union {
        none: void,
        expected_tag: Token.Tag,
    } = .{ .none = {} },

    pub const Tag = enum {
        asterisk_after_ptr_deref,
        decl_between_fields,
        expected_block,
        expected_block_or_assignment,
        expected_block_or_expr,
        expected_block_or_field,
        expected_container_members,
        expected_expr,
        expected_expr_or_assignment,
        expected_fn,
        expected_inlinable,
        expected_labelable,
        expected_param_list,
        expected_prefix_expr,
        expected_primary_type_expr,
        expected_pub_item,
        expected_return_type,
        expected_semi_or_else,
        expected_semi_or_lbrace,
        expected_statement,
        expected_string_literal,
        expected_suffix_op,
        expected_type_expr,
        expected_var_decl,
        expected_var_decl_or_fn,
        expected_loop_payload,
        expected_container,
        extra_align_qualifier,
        extra_allowzero_qualifier,
        extra_const_qualifier,
        extra_volatile_qualifier,
        ptr_mod_on_array_child_type,
        invalid_and,
        invalid_bit_range,
        invalid_token,
        same_line_doc_comment,
        unattached_doc_comment,

        /// `expected_tag` is populated.
        expected_token,
    };
};

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = u32;

    comptime {
        // Goal is to keep this under one byte for efficiency.
        assert(@sizeOf(Tag) == 1);
    }

    /// Note: The FooComma/FooSemicolon variants exist to ease the implementation of
    /// Tree.lastToken()
    pub const Tag = enum {
        /// sub_list[lhs...rhs]
        root,
        /// `usingnamespace lhs;`. rhs unused. main_token is `usingnamespace`.
        @"usingnamespace",
        /// lhs is test name token (must be string literal), if any.
        /// rhs is the body node.
        test_decl,
        /// lhs is the index into extra_data.
        /// rhs is the initialization expression, if any.
        /// main_token is `var` or `const`.
        global_var_decl,
        /// `var a: x align(y) = rhs`
        /// lhs is the index into extra_data.
        /// main_token is `var` or `const`.
        local_var_decl,
        /// `var a: lhs = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        /// main_token is `var` or `const`.
        simple_var_decl,
        /// `var a align(lhs) = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        /// main_token is `var` or `const`.
        aligned_var_decl,
        /// lhs is the identifier token payload if any,
        /// rhs is the deferred expression.
        @"errdefer",
        /// lhs is unused.
        /// rhs is the deferred expression.
        @"defer",
        /// lhs catch rhs
        /// lhs catch |err| rhs
        /// main_token is the `catch` keyword.
        /// payload is determined by looking at the next token after the `catch` keyword.
        @"catch",
        /// `lhs.a`. main_token is the dot. rhs is the identifier token index.
        field_access,
        /// `lhs.?`. main_token is the dot. rhs is the `?` token index.
        unwrap_optional,
        /// `lhs == rhs`. main_token is op.
        equal_equal,
        /// `lhs != rhs`. main_token is op.
        bang_equal,
        /// `lhs < rhs`. main_token is op.
        less_than,
        /// `lhs > rhs`. main_token is op.
        greater_than,
        /// `lhs <= rhs`. main_token is op.
        less_or_equal,
        /// `lhs >= rhs`. main_token is op.
        greater_or_equal,
        /// `lhs *= rhs`. main_token is op.
        assign_mul,
        /// `lhs /= rhs`. main_token is op.
        assign_div,
        /// `lhs *= rhs`. main_token is op.
        assign_mod,
        /// `lhs += rhs`. main_token is op.
        assign_add,
        /// `lhs -= rhs`. main_token is op.
        assign_sub,
        /// `lhs <<= rhs`. main_token is op.
        assign_bit_shift_left,
        /// `lhs >>= rhs`. main_token is op.
        assign_bit_shift_right,
        /// `lhs &= rhs`. main_token is op.
        assign_bit_and,
        /// `lhs ^= rhs`. main_token is op.
        assign_bit_xor,
        /// `lhs |= rhs`. main_token is op.
        assign_bit_or,
        /// `lhs *%= rhs`. main_token is op.
        assign_mul_wrap,
        /// `lhs +%= rhs`. main_token is op.
        assign_add_wrap,
        /// `lhs -%= rhs`. main_token is op.
        assign_sub_wrap,
        /// `lhs = rhs`. main_token is op.
        assign,
        /// `lhs || rhs`. main_token is the `||`.
        merge_error_sets,
        /// `lhs * rhs`. main_token is the `*`.
        mul,
        /// `lhs / rhs`. main_token is the `/`.
        div,
        /// `lhs % rhs`. main_token is the `%`.
        mod,
        /// `lhs ** rhs`. main_token is the `**`.
        array_mult,
        /// `lhs *% rhs`. main_token is the `*%`.
        mul_wrap,
        /// `lhs + rhs`. main_token is the `+`.
        add,
        /// `lhs - rhs`. main_token is the `-`.
        sub,
        /// `lhs ++ rhs`. main_token is the `++`.
        array_cat,
        /// `lhs +% rhs`. main_token is the `+%`.
        add_wrap,
        /// `lhs -% rhs`. main_token is the `-%`.
        sub_wrap,
        /// `lhs << rhs`. main_token is the `<<`.
        bit_shift_left,
        /// `lhs >> rhs`. main_token is the `>>`.
        bit_shift_right,
        /// `lhs & rhs`. main_token is the `&`.
        bit_and,
        /// `lhs ^ rhs`. main_token is the `^`.
        bit_xor,
        /// `lhs | rhs`. main_token is the `|`.
        bit_or,
        /// `lhs orelse rhs`. main_token is the `orelse`.
        @"orelse",
        /// `lhs and rhs`. main_token is the `and`.
        bool_and,
        /// `lhs or rhs`. main_token is the `or`.
        bool_or,
        /// `op lhs`. rhs unused. main_token is op.
        bool_not,
        /// `op lhs`. rhs unused. main_token is op.
        negation,
        /// `op lhs`. rhs unused. main_token is op.
        bit_not,
        /// `op lhs`. rhs unused. main_token is op.
        negation_wrap,
        /// `op lhs`. rhs unused. main_token is op.
        address_of,
        /// `op lhs`. rhs unused. main_token is op.
        @"try",
        /// `op lhs`. rhs unused. main_token is op.
        @"await",
        /// `?lhs`. rhs unused. main_token is the `?`.
        optional_type,
        /// `[lhs]rhs`.
        array_type,
        /// `[lhs:a]b`. `ArrayTypeSentinel[rhs]`.
        array_type_sentinel,
        /// `[*]align(lhs) rhs`. lhs can be omitted.
        /// `*align(lhs) rhs`. lhs can be omitted.
        /// `[]rhs`.
        /// main_token is the asterisk if a pointer or the lbracket if a slice
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_aligned,
        /// `[*:lhs]rhs`. lhs can be omitted.
        /// `*rhs`.
        /// `[:lhs]rhs`.
        /// main_token is the asterisk if a pointer or the lbracket if a slice
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_sentinel,
        /// lhs is index into ptr_type. rhs is the element type expression.
        /// main_token is the asterisk if a pointer or the lbracket if a slice
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type,
        /// lhs is index into ptr_type_bit_range. rhs is the element type expression.
        /// main_token is the asterisk if a pointer or the lbracket if a slice
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_bit_range,
        /// `lhs[rhs..]`
        /// main_token is the lbracket.
        slice_open,
        /// `lhs[b..c]`. rhs is index into Slice
        /// main_token is the lbracket.
        slice,
        /// `lhs[b..c :d]`. rhs is index into SliceSentinel
        /// main_token is the lbracket.
        slice_sentinel,
        /// `lhs.*`. rhs is unused.
        deref,
        /// `lhs[rhs]`.
        array_access,
        /// `lhs{rhs}`. rhs can be omitted.
        array_init_one,
        /// `lhs{rhs,}`. rhs can *not* be omitted
        array_init_one_comma,
        /// `.{lhs, rhs}`. lhs and rhs can be omitted.
        array_init_dot_two,
        /// Same as `array_init_dot_two` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_dot_two_comma,
        /// `.{a, b}`. `sub_list[lhs..rhs]`.
        array_init_dot,
        /// Same as `array_init_dot` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_dot_comma,
        /// `lhs{a, b}`. `sub_range_list[rhs]`. lhs can be omitted which means `.{a, b}`.
        array_init,
        /// Same as `array_init` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_comma,
        /// `lhs{.a = rhs}`. rhs can be omitted making it empty.
        /// main_token is the lbrace.
        struct_init_one,
        /// `lhs{.a = rhs,}`. rhs can *not* be omitted.
        /// main_token is the lbrace.
        struct_init_one_comma,
        /// `.{.a = lhs, .b = rhs}`. lhs and rhs can be omitted.
        /// main_token is the lbrace.
        /// No trailing comma before the rbrace.
        struct_init_dot_two,
        /// Same as `struct_init_dot_two` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_dot_two_comma,
        /// `.{.a = b, .c = d}`. `sub_list[lhs..rhs]`.
        /// main_token is the lbrace.
        struct_init_dot,
        /// Same as `struct_init_dot` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_dot_comma,
        /// `lhs{.a = b, .c = d}`. `sub_range_list[rhs]`.
        /// lhs can be omitted which means `.{.a = b, .c = d}`.
        /// main_token is the lbrace.
        struct_init,
        /// Same as `struct_init` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_comma,
        /// `lhs(rhs)`. rhs can be omitted.
        /// main_token is the lparen.
        call_one,
        /// `lhs(rhs,)`. rhs can be omitted.
        /// main_token is the lparen.
        call_one_comma,
        /// `async lhs(rhs)`. rhs can be omitted.
        async_call_one,
        /// `async lhs(rhs,)`.
        async_call_one_comma,
        /// `lhs(a, b, c)`. `SubRange[rhs]`.
        /// main_token is the `(`.
        call,
        /// `lhs(a, b, c,)`. `SubRange[rhs]`.
        /// main_token is the `(`.
        call_comma,
        /// `async lhs(a, b, c)`. `SubRange[rhs]`.
        /// main_token is the `(`.
        async_call,
        /// `async lhs(a, b, c,)`. `SubRange[rhs]`.
        /// main_token is the `(`.
        async_call_comma,
        /// `switch(lhs) {}`. `SubRange[rhs]`.
        @"switch",
        /// Same as switch except there is known to be a trailing comma
        /// before the final rbrace
        switch_comma,
        /// `lhs => rhs`. If lhs is omitted it means `else`.
        /// main_token is the `=>`
        switch_case_one,
        /// `a, b, c => rhs`. `SubRange[lhs]`.
        /// main_token is the `=>`
        switch_case,
        /// `lhs...rhs`.
        switch_range,
        /// `while (lhs) rhs`.
        /// `while (lhs) |x| rhs`.
        while_simple,
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        while_cont,
        /// `while (lhs) : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else |y| c`. `While[rhs]`.
        @"while",
        /// `for (lhs) rhs`.
        for_simple,
        /// `for (lhs) a else b`. `if_list[rhs]`.
        @"for",
        /// `if (lhs) rhs`.
        /// `if (lhs) |a| rhs`.
        if_simple,
        /// `if (lhs) a else b`. `If[rhs]`.
        /// `if (lhs) |x| a else b`. `If[rhs]`.
        /// `if (lhs) |x| a else |y| b`. `If[rhs]`.
        @"if",
        /// `suspend lhs`. lhs can be omitted. rhs is unused.
        @"suspend",
        /// `resume lhs`. rhs is unused.
        @"resume",
        /// `continue`. lhs is token index of label if any. rhs is unused.
        @"continue",
        /// `break :lhs rhs`
        /// both lhs and rhs may be omitted.
        @"break",
        /// `return lhs`. lhs can be omitted. rhs is unused.
        @"return",
        /// `fn(a: lhs) rhs`. lhs can be omitted.
        /// anytype and ... parameters are omitted from the AST tree.
        /// main_token is the `fn` keyword.
        /// extern function declarations use this tag.
        fn_proto_simple,
        /// `fn(a: b, c: d) rhs`. `sub_range_list[lhs]`.
        /// anytype and ... parameters are omitted from the AST tree.
        /// main_token is the `fn` keyword.
        /// extern function declarations use this tag.
        fn_proto_multi,
        /// `fn(a: b) rhs linksection(e) callconv(f)`. `FnProtoOne[lhs]`.
        /// zero or one parameters.
        /// anytype and ... parameters are omitted from the AST tree.
        /// main_token is the `fn` keyword.
        /// extern function declarations use this tag.
        fn_proto_one,
        /// `fn(a: b, c: d) rhs linksection(e) callconv(f)`. `FnProto[lhs]`.
        /// anytype and ... parameters are omitted from the AST tree.
        /// main_token is the `fn` keyword.
        /// extern function declarations use this tag.
        fn_proto,
        /// lhs is the fn_proto.
        /// rhs is the function body block.
        /// Note that extern function declarations use the fn_proto tags rather
        /// than this one.
        fn_decl,
        /// `anyframe->rhs`. main_token is `anyframe`. `lhs` is arrow token index.
        anyframe_type,
        /// Both lhs and rhs unused.
        anyframe_literal,
        /// Both lhs and rhs unused.
        char_literal,
        /// Both lhs and rhs unused.
        integer_literal,
        /// Both lhs and rhs unused.
        float_literal,
        /// Both lhs and rhs unused.
        false_literal,
        /// Both lhs and rhs unused.
        true_literal,
        /// Both lhs and rhs unused.
        null_literal,
        /// Both lhs and rhs unused.
        undefined_literal,
        /// Both lhs and rhs unused.
        unreachable_literal,
        /// Both lhs and rhs unused.
        /// Most identifiers will not have explicit AST nodes, however for expressions
        /// which could be one of many different kinds of AST nodes, there will be an
        /// identifier AST node for it.
        identifier,
        /// lhs is the dot token index, rhs unused, main_token is the identifier.
        enum_literal,
        /// main_token is the string literal token
        /// Both lhs and rhs unused.
        string_literal,
        /// main_token is the first token index (redundant with lhs)
        /// lhs is the first token index; rhs is the last token index.
        /// Could be a series of multiline_string_literal_line tokens, or a single
        /// string_literal token.
        multiline_string_literal,
        /// `(lhs)`. main_token is the `(`; rhs is the token index of the `)`.
        grouped_expression,
        /// `@a(lhs, rhs)`. lhs and rhs may be omitted.
        /// main_token is the builtin token.
        builtin_call_two,
        /// Same as builtin_call_two but there is known to be a trailing comma before the rparen.
        builtin_call_two_comma,
        /// `@a(b, c)`. `sub_list[lhs..rhs]`.
        /// main_token is the builtin token.
        builtin_call,
        /// Same as builtin_call but there is known to be a trailing comma before the rparen.
        builtin_call_comma,
        /// `error{a, b}`.
        /// rhs is the rbrace, lhs is unused.
        error_set_decl,
        /// `struct {}`, `union {}`, `opaque {}`, `enum {}`. `extra_data[lhs..rhs]`.
        /// main_token is `struct`, `union`, `opaque`, `enum` keyword.
        container_decl,
        /// Same as ContainerDecl but there is known to be a trailing comma
        /// or semicolon before the rbrace.
        container_decl_trailing,
        /// `struct {lhs, rhs}`, `union {lhs, rhs}`, `opaque {lhs, rhs}`, `enum {lhs, rhs}`.
        /// lhs or rhs can be omitted.
        /// main_token is `struct`, `union`, `opaque`, `enum` keyword.
        container_decl_two,
        /// Same as ContainerDeclTwo except there is known to be a trailing comma
        /// or semicolon before the rbrace.
        container_decl_two_trailing,
        /// `union(lhs)` / `enum(lhs)`. `SubRange[rhs]`.
        container_decl_arg,
        /// Same as container_decl_arg but there is known to be a trailing
        /// comma or semicolon before the rbrace.
        container_decl_arg_trailing,
        /// `union(enum) {}`. `sub_list[lhs..rhs]`.
        /// Note that tagged unions with explicitly provided enums are represented
        /// by `container_decl_arg`.
        tagged_union,
        /// Same as tagged_union but there is known to be a trailing comma
        /// or semicolon before the rbrace.
        tagged_union_trailing,
        /// `union(enum) {lhs, rhs}`. lhs or rhs may be omitted.
        /// Note that tagged unions with explicitly provided enums are represented
        /// by `container_decl_arg`.
        tagged_union_two,
        /// Same as tagged_union_two but there is known to be a trailing comma
        /// or semicolon before the rbrace.
        tagged_union_two_trailing,
        /// `union(enum(lhs)) {}`. `SubRange[rhs]`.
        tagged_union_enum_tag,
        /// Same as tagged_union_enum_tag but there is known to be a trailing comma
        /// or semicolon before the rbrace.
        tagged_union_enum_tag_trailing,
        /// `a: lhs = rhs,`. lhs and rhs can be omitted.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        container_field_init,
        /// `a: lhs align(rhs),`. rhs can be omitted.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        container_field_align,
        /// `a: lhs align(c) = d,`. `container_field_list[rhs]`.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        container_field,
        /// `anytype`. both lhs and rhs unused.
        /// Used by `ContainerField`.
        @"anytype",
        /// `comptime lhs`. rhs unused.
        @"comptime",
        /// `nosuspend lhs`. rhs unused.
        @"nosuspend",
        /// `{lhs rhs}`. rhs or lhs can be omitted.
        /// main_token points at the lbrace.
        block_two,
        /// Same as block_two but there is known to be a semicolon before the rbrace.
        block_two_semicolon,
        /// `{}`. `sub_list[lhs..rhs]`.
        /// main_token points at the lbrace.
        block,
        /// Same as block but there is known to be a semicolon before the rbrace.
        block_semicolon,
        /// `asm(lhs)`. rhs is the token index of the rparen.
        asm_simple,
        /// `asm(lhs, a)`. `Asm[rhs]`.
        @"asm",
        /// `[a] "b" (c)`. lhs is 0, rhs is token index of the rparen.
        /// `[a] "b" (-> lhs)`. rhs is token index of the rparen.
        /// main_token is `a`.
        asm_output,
        /// `[a] "b" (lhs)`. rhs is token index of the rparen.
        /// main_token is `a`.
        asm_input,
        /// `error.a`. lhs is token index of `.`. rhs is token index of `a`.
        error_value,
        /// `lhs!rhs`. main_token is the `!`.
        error_union,

        pub fn isContainerField(tag: Tag) bool {
            return switch (tag) {
                .container_field_init,
                .container_field_align,
                .container_field,
                => true,

                else => false,
            };
        }
    };

    pub const Data = struct {
        lhs: Index,
        rhs: Index,
    };

    pub const LocalVarDecl = struct {
        type_node: Index,
        align_node: Index,
    };

    pub const ArrayTypeSentinel = struct {
        elem_type: Index,
        sentinel: Index,
    };

    pub const PtrType = struct {
        sentinel: Index,
        align_node: Index,
    };

    pub const PtrTypeBitRange = struct {
        sentinel: Index,
        align_node: Index,
        bit_range_start: Index,
        bit_range_end: Index,
    };

    pub const SubRange = struct {
        /// Index into sub_list.
        start: Index,
        /// Index into sub_list.
        end: Index,
    };

    pub const If = struct {
        then_expr: Index,
        else_expr: Index,
    };

    pub const ContainerField = struct {
        value_expr: Index,
        align_expr: Index,
    };

    pub const GlobalVarDecl = struct {
        type_node: Index,
        align_node: Index,
        section_node: Index,
    };

    pub const Slice = struct {
        start: Index,
        end: Index,
    };

    pub const SliceSentinel = struct {
        start: Index,
        /// May be 0 if the slice is "open"
        end: Index,
        sentinel: Index,
    };

    pub const While = struct {
        cont_expr: Index,
        then_expr: Index,
        else_expr: Index,
    };

    pub const WhileCont = struct {
        cont_expr: Index,
        then_expr: Index,
    };

    pub const FnProtoOne = struct {
        /// Populated if there is exactly 1 parameter. Otherwise there are 0 parameters.
        param: Index,
        /// Populated if align(A) is present.
        align_expr: Index,
        /// Populated if linksection(A) is present.
        section_expr: Index,
        /// Populated if callconv(A) is present.
        callconv_expr: Index,
    };

    pub const FnProto = struct {
        params_start: Index,
        params_end: Index,
        /// Populated if align(A) is present.
        align_expr: Index,
        /// Populated if linksection(A) is present.
        section_expr: Index,
        /// Populated if callconv(A) is present.
        callconv_expr: Index,
    };

    pub const Asm = struct {
        items_start: Index,
        items_end: Index,
        /// Needed to make lastToken() work.
        rparen: TokenIndex,
    };
};
