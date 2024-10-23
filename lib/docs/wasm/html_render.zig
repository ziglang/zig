const std = @import("std");
const Ast = std.zig.Ast;
const assert = std.debug.assert;

const Walk = @import("Walk");
const Decl = Walk.Decl;

const gpa = std.heap.wasm_allocator;
const Oom = error{OutOfMemory};

/// Delete this to find out where URL escaping needs to be added.
pub const missing_feature_url_escape = true;

pub const RenderSourceOptions = struct {
    skip_doc_comments: bool = false,
    skip_comments: bool = false,
    collapse_whitespace: bool = false,
    fn_link: Decl.Index = .none,
    /// Assumed to be sorted ascending.
    source_location_annotations: []const Annotation = &.{},
    /// Concatenated with dom_id.
    annotation_prefix: []const u8 = "l",
};

pub const Annotation = struct {
    file_byte_offset: u32,
    /// Concatenated with annotation_prefix.
    dom_id: u32,
};

pub fn fileSourceHtml(
    file_index: Walk.File.Index,
    out: *std.ArrayListUnmanaged(u8),
    root_node: Ast.Node.Index,
    options: RenderSourceOptions,
) !void {
    const ast = file_index.get_ast();
    const file = file_index.get();

    const g = struct {
        var field_access_buffer: std.ArrayListUnmanaged(u8) = .empty;
    };

    const token_tags = ast.tokens.items(.tag);
    const token_starts = ast.tokens.items(.start);
    const main_tokens = ast.nodes.items(.main_token);

    const start_token = ast.firstToken(root_node);
    const end_token = ast.lastToken(root_node) + 1;

    var cursor: usize = token_starts[start_token];

    var indent: usize = 0;
    if (std.mem.lastIndexOf(u8, ast.source[0..cursor], "\n")) |newline_index| {
        for (ast.source[newline_index + 1 .. cursor]) |c| {
            if (c == ' ') {
                indent += 1;
            } else {
                break;
            }
        }
    }

    var next_annotate_index: usize = 0;

    for (
        token_tags[start_token..end_token],
        token_starts[start_token..end_token],
        start_token..,
    ) |tag, start, token_index| {
        const between = ast.source[cursor..start];
        if (std.mem.trim(u8, between, " \t\r\n").len > 0) {
            if (!options.skip_comments) {
                try out.appendSlice(gpa, "<span class=\"tok-comment\">");
                try appendUnindented(out, between, indent);
                try out.appendSlice(gpa, "</span>");
            }
        } else if (between.len > 0) {
            if (options.collapse_whitespace) {
                if (out.items.len > 0 and out.items[out.items.len - 1] != ' ')
                    try out.append(gpa, ' ');
            } else {
                try appendUnindented(out, between, indent);
            }
        }
        if (tag == .eof) break;
        const slice = ast.tokenSlice(token_index);
        cursor = start + slice.len;

        // Insert annotations.
        while (true) {
            if (next_annotate_index >= options.source_location_annotations.len) break;
            const next_annotation = options.source_location_annotations[next_annotate_index];
            if (cursor <= next_annotation.file_byte_offset) break;
            try out.writer(gpa).print("<span id=\"{s}{d}\"></span>", .{
                options.annotation_prefix, next_annotation.dom_id,
            });
            next_annotate_index += 1;
        }

        switch (tag) {
            .eof => unreachable,

            .keyword_addrspace,
            .keyword_align,
            .keyword_and,
            .keyword_asm,
            .keyword_async,
            .keyword_await,
            .keyword_break,
            .keyword_catch,
            .keyword_comptime,
            .keyword_const,
            .keyword_continue,
            .keyword_defer,
            .keyword_else,
            .keyword_enum,
            .keyword_errdefer,
            .keyword_error,
            .keyword_export,
            .keyword_extern,
            .keyword_for,
            .keyword_if,
            .keyword_inline,
            .keyword_noalias,
            .keyword_noinline,
            .keyword_nosuspend,
            .keyword_opaque,
            .keyword_or,
            .keyword_orelse,
            .keyword_packed,
            .keyword_anyframe,
            .keyword_pub,
            .keyword_resume,
            .keyword_return,
            .keyword_linksection,
            .keyword_callconv,
            .keyword_struct,
            .keyword_suspend,
            .keyword_switch,
            .keyword_test,
            .keyword_threadlocal,
            .keyword_try,
            .keyword_union,
            .keyword_unreachable,
            .keyword_usingnamespace,
            .keyword_var,
            .keyword_volatile,
            .keyword_allowzero,
            .keyword_while,
            .keyword_anytype,
            .keyword_fn,
            => {
                try out.appendSlice(gpa, "<span class=\"tok-kw\">");
                try appendEscaped(out, slice);
                try out.appendSlice(gpa, "</span>");
            },

            .string_literal,
            .char_literal,
            .multiline_string_literal_line,
            => {
                try out.appendSlice(gpa, "<span class=\"tok-str\">");
                try appendEscaped(out, slice);
                try out.appendSlice(gpa, "</span>");
            },

            .builtin => {
                try out.appendSlice(gpa, "<span class=\"tok-builtin\">");
                try appendEscaped(out, slice);
                try out.appendSlice(gpa, "</span>");
            },

            .doc_comment,
            .container_doc_comment,
            => {
                if (!options.skip_doc_comments) {
                    try out.appendSlice(gpa, "<span class=\"tok-comment\">");
                    try appendEscaped(out, slice);
                    try out.appendSlice(gpa, "</span>");
                }
            },

            .identifier => i: {
                if (options.fn_link != .none) {
                    const fn_link = options.fn_link.get();
                    const fn_token = main_tokens[fn_link.ast_node];
                    if (token_index == fn_token + 1) {
                        try out.appendSlice(gpa, "<a class=\"tok-fn\" href=\"#");
                        _ = missing_feature_url_escape;
                        try fn_link.fqn(out);
                        try out.appendSlice(gpa, "\">");
                        try appendEscaped(out, slice);
                        try out.appendSlice(gpa, "</a>");
                        break :i;
                    }
                }

                if (token_index > 0 and token_tags[token_index - 1] == .keyword_fn) {
                    try out.appendSlice(gpa, "<span class=\"tok-fn\">");
                    try appendEscaped(out, slice);
                    try out.appendSlice(gpa, "</span>");
                    break :i;
                }

                if (Walk.isPrimitiveNonType(slice)) {
                    try out.appendSlice(gpa, "<span class=\"tok-null\">");
                    try appendEscaped(out, slice);
                    try out.appendSlice(gpa, "</span>");
                    break :i;
                }

                if (std.zig.primitives.isPrimitive(slice)) {
                    try out.appendSlice(gpa, "<span class=\"tok-type\">");
                    try appendEscaped(out, slice);
                    try out.appendSlice(gpa, "</span>");
                    break :i;
                }

                if (file.token_parents.get(token_index)) |field_access_node| {
                    g.field_access_buffer.clearRetainingCapacity();
                    try walkFieldAccesses(file_index, &g.field_access_buffer, field_access_node);
                    if (g.field_access_buffer.items.len > 0) {
                        try out.appendSlice(gpa, "<a href=\"#");
                        _ = missing_feature_url_escape;
                        try out.appendSlice(gpa, g.field_access_buffer.items);
                        try out.appendSlice(gpa, "\">");
                        try appendEscaped(out, slice);
                        try out.appendSlice(gpa, "</a>");
                    } else {
                        try appendEscaped(out, slice);
                    }
                    break :i;
                }

                {
                    g.field_access_buffer.clearRetainingCapacity();
                    try resolveIdentLink(file_index, &g.field_access_buffer, token_index);
                    if (g.field_access_buffer.items.len > 0) {
                        try out.appendSlice(gpa, "<a href=\"#");
                        _ = missing_feature_url_escape;
                        try out.appendSlice(gpa, g.field_access_buffer.items);
                        try out.appendSlice(gpa, "\">");
                        try appendEscaped(out, slice);
                        try out.appendSlice(gpa, "</a>");
                        break :i;
                    }
                }

                try appendEscaped(out, slice);
            },

            .number_literal => {
                try out.appendSlice(gpa, "<span class=\"tok-number\">");
                try appendEscaped(out, slice);
                try out.appendSlice(gpa, "</span>");
            },

            .bang,
            .pipe,
            .pipe_pipe,
            .pipe_equal,
            .equal,
            .equal_equal,
            .equal_angle_bracket_right,
            .bang_equal,
            .l_paren,
            .r_paren,
            .semicolon,
            .percent,
            .percent_equal,
            .l_brace,
            .r_brace,
            .l_bracket,
            .r_bracket,
            .period,
            .period_asterisk,
            .ellipsis2,
            .ellipsis3,
            .caret,
            .caret_equal,
            .plus,
            .plus_plus,
            .plus_equal,
            .plus_percent,
            .plus_percent_equal,
            .plus_pipe,
            .plus_pipe_equal,
            .minus,
            .minus_equal,
            .minus_percent,
            .minus_percent_equal,
            .minus_pipe,
            .minus_pipe_equal,
            .asterisk,
            .asterisk_equal,
            .asterisk_asterisk,
            .asterisk_percent,
            .asterisk_percent_equal,
            .asterisk_pipe,
            .asterisk_pipe_equal,
            .arrow,
            .colon,
            .slash,
            .slash_equal,
            .comma,
            .ampersand,
            .ampersand_equal,
            .question_mark,
            .angle_bracket_left,
            .angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left,
            .angle_bracket_angle_bracket_left_equal,
            .angle_bracket_angle_bracket_left_pipe,
            .angle_bracket_angle_bracket_left_pipe_equal,
            .angle_bracket_right,
            .angle_bracket_right_equal,
            .angle_bracket_angle_bracket_right,
            .angle_bracket_angle_bracket_right_equal,
            .tilde,
            => try appendEscaped(out, slice),

            .invalid, .invalid_periodasterisks => return error.InvalidToken,
        }
    }
}

fn appendUnindented(out: *std.ArrayListUnmanaged(u8), s: []const u8, indent: usize) !void {
    var it = std.mem.splitScalar(u8, s, '\n');
    var is_first_line = true;
    while (it.next()) |line| {
        if (is_first_line) {
            try appendEscaped(out, line);
            is_first_line = false;
        } else {
            try out.appendSlice(gpa, "\n");
            try appendEscaped(out, unindent(line, indent));
        }
    }
}

pub fn appendEscaped(out: *std.ArrayListUnmanaged(u8), s: []const u8) !void {
    for (s) |c| {
        try out.ensureUnusedCapacity(gpa, 6);
        switch (c) {
            '&' => out.appendSliceAssumeCapacity("&amp;"),
            '<' => out.appendSliceAssumeCapacity("&lt;"),
            '>' => out.appendSliceAssumeCapacity("&gt;"),
            '"' => out.appendSliceAssumeCapacity("&quot;"),
            else => out.appendAssumeCapacity(c),
        }
    }
}

fn walkFieldAccesses(
    file_index: Walk.File.Index,
    out: *std.ArrayListUnmanaged(u8),
    node: Ast.Node.Index,
) Oom!void {
    const ast = file_index.get_ast();
    const node_tags = ast.nodes.items(.tag);
    assert(node_tags[node] == .field_access);
    const node_datas = ast.nodes.items(.data);
    const main_tokens = ast.nodes.items(.main_token);
    const object_node = node_datas[node].lhs;
    const dot_token = main_tokens[node];
    const field_ident = dot_token + 1;
    switch (node_tags[object_node]) {
        .identifier => {
            const lhs_ident = main_tokens[object_node];
            try resolveIdentLink(file_index, out, lhs_ident);
        },
        .field_access => {
            try walkFieldAccesses(file_index, out, object_node);
        },
        else => {},
    }
    if (out.items.len > 0) {
        try out.append(gpa, '.');
        try out.appendSlice(gpa, ast.tokenSlice(field_ident));
    }
}

fn resolveIdentLink(
    file_index: Walk.File.Index,
    out: *std.ArrayListUnmanaged(u8),
    ident_token: Ast.TokenIndex,
) Oom!void {
    const decl_index = file_index.get().lookup_token(ident_token);
    if (decl_index == .none) return;
    try resolveDeclLink(decl_index, out);
}

fn unindent(s: []const u8, indent: usize) []const u8 {
    var indent_idx: usize = 0;
    for (s) |c| {
        if (c == ' ' and indent_idx < indent) {
            indent_idx += 1;
        } else {
            break;
        }
    }
    return s[indent_idx..];
}

pub fn resolveDeclLink(decl_index: Decl.Index, out: *std.ArrayListUnmanaged(u8)) Oom!void {
    const decl = decl_index.get();
    switch (decl.categorize()) {
        .alias => |alias_decl| try alias_decl.get().fqn(out),
        else => try decl.fqn(out),
    }
}
