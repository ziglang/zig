const std = @import("std");
const Lexer = @import("lex.zig").Lexer;
const Token = @import("lex.zig").Token;
const Node = @import("ast.zig").Node;
const Tree = @import("ast.zig").Tree;
const CodePageLookup = @import("ast.zig").CodePageLookup;
const Resource = @import("rc.zig").Resource;
const Allocator = std.mem.Allocator;
const ErrorDetails = @import("errors.zig").ErrorDetails;
const Diagnostics = @import("errors.zig").Diagnostics;
const SourceBytes = @import("literals.zig").SourceBytes;
const Compiler = @import("compile.zig").Compiler;
const rc = @import("rc.zig");
const res = @import("res.zig");

// TODO: Make these configurable?
pub const max_nested_menu_level: u32 = 512;
pub const max_nested_version_level: u32 = 512;
pub const max_nested_expression_level: u32 = 200;

pub const Parser = struct {
    const Self = @This();

    lexer: *Lexer,
    /// values that need to be initialized per-parse
    state: Parser.State = undefined,
    options: Parser.Options,

    pub const Error = error{ParseError} || Allocator.Error;

    pub const Options = struct {
        warn_instead_of_error_on_invalid_code_page: bool = false,
    };

    pub fn init(lexer: *Lexer, options: Options) Parser {
        return Parser{
            .lexer = lexer,
            .options = options,
        };
    }

    pub const State = struct {
        token: Token,
        lookahead_lexer: Lexer,
        allocator: Allocator,
        arena: Allocator,
        diagnostics: *Diagnostics,
        input_code_page_lookup: CodePageLookup,
        output_code_page_lookup: CodePageLookup,
    };

    pub fn parse(self: *Self, allocator: Allocator, diagnostics: *Diagnostics) Error!*Tree {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        self.state = Parser.State{
            .token = undefined,
            .lookahead_lexer = undefined,
            .allocator = allocator,
            .arena = arena.allocator(),
            .diagnostics = diagnostics,
            .input_code_page_lookup = CodePageLookup.init(arena.allocator(), self.lexer.default_code_page),
            .output_code_page_lookup = CodePageLookup.init(arena.allocator(), self.lexer.default_code_page),
        };

        const parsed_root = try self.parseRoot();

        const tree = try self.state.arena.create(Tree);
        tree.* = .{
            .node = parsed_root,
            .input_code_pages = self.state.input_code_page_lookup,
            .output_code_pages = self.state.output_code_page_lookup,
            .source = self.lexer.buffer,
            .arena = arena.state,
            .allocator = allocator,
        };
        return tree;
    }

    fn parseRoot(self: *Self) Error!*Node {
        var statements = std.ArrayList(*Node).init(self.state.allocator);
        defer statements.deinit();

        try self.parseStatements(&statements);
        try self.check(.eof);

        const node = try self.state.arena.create(Node.Root);
        node.* = .{
            .body = try self.state.arena.dupe(*Node, statements.items),
        };
        return &node.base;
    }

    fn parseStatements(self: *Self, statements: *std.ArrayList(*Node)) Error!void {
        while (true) {
            try self.nextToken(.whitespace_delimiter_only);
            if (self.state.token.id == .eof) break;
            // The Win32 compiler will sometimes try to recover from errors
            // and then restart parsing afterwards. We don't ever do this
            // because it almost always leads to unhelpful error messages
            // (usually it will end up with bogus things like 'file
            // not found: {')
            const statement = try self.parseStatement();
            try statements.append(statement);
        }
    }

    /// Expects the current token to be the token before possible common resource attributes.
    /// After return, the current token will be the token immediately before the end of the
    /// common resource attributes (if any). If there are no common resource attributes, the
    /// current token is unchanged.
    /// The returned slice is allocated by the parser's arena
    fn parseCommonResourceAttributes(self: *Self) ![]Token {
        var common_resource_attributes = std.ArrayListUnmanaged(Token){};
        while (true) {
            const maybe_common_resource_attribute = try self.lookaheadToken(.normal);
            if (maybe_common_resource_attribute.id == .literal and rc.CommonResourceAttributes.map.has(maybe_common_resource_attribute.slice(self.lexer.buffer))) {
                try common_resource_attributes.append(self.state.arena, maybe_common_resource_attribute);
                self.nextToken(.normal) catch unreachable;
            } else {
                break;
            }
        }
        return common_resource_attributes.toOwnedSlice(self.state.arena);
    }

    /// Expects the current token to have already been dealt with, and that the
    /// optional statements will potentially start on the next token.
    /// After return, the current token will be the token immediately before the end of the
    /// optional statements (if any). If there are no optional statements, the
    /// current token is unchanged.
    /// The returned slice is allocated by the parser's arena
    fn parseOptionalStatements(self: *Self, resource: Resource) ![]*Node {
        var optional_statements = std.ArrayListUnmanaged(*Node){};
        while (true) {
            const lookahead_token = try self.lookaheadToken(.normal);
            if (lookahead_token.id != .literal) break;
            const slice = lookahead_token.slice(self.lexer.buffer);
            const optional_statement_type = rc.OptionalStatements.map.get(slice) orelse switch (resource) {
                .dialog, .dialogex => rc.OptionalStatements.dialog_map.get(slice) orelse break,
                else => break,
            };
            self.nextToken(.normal) catch unreachable;
            switch (optional_statement_type) {
                .language => {
                    const language = try self.parseLanguageStatement();
                    try optional_statements.append(self.state.arena, language);
                },
                // Number only
                .version, .characteristics, .style, .exstyle => {
                    const identifier = self.state.token;
                    const value = try self.parseExpression(.{
                        .can_contain_not_expressions = optional_statement_type == .style or optional_statement_type == .exstyle,
                        .allowed_types = .{ .number = true },
                    });
                    const node = try self.state.arena.create(Node.SimpleStatement);
                    node.* = .{
                        .identifier = identifier,
                        .value = value,
                    };
                    try optional_statements.append(self.state.arena, &node.base);
                },
                // String only
                .caption => {
                    const identifier = self.state.token;
                    try self.nextToken(.normal);
                    const value = self.state.token;
                    if (!value.isStringLiteral()) {
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .expected_something_else,
                            .token = value,
                            .extra = .{ .expected_types = .{
                                .string_literal = true,
                            } },
                        });
                    }
                    const value_node = try self.state.arena.create(Node.Literal);
                    value_node.* = .{
                        .token = value,
                    };
                    const node = try self.state.arena.create(Node.SimpleStatement);
                    node.* = .{
                        .identifier = identifier,
                        .value = &value_node.base,
                    };
                    try optional_statements.append(self.state.arena, &node.base);
                },
                // String or number
                .class => {
                    const identifier = self.state.token;
                    const value = try self.parseExpression(.{ .allowed_types = .{ .number = true, .string = true } });
                    const node = try self.state.arena.create(Node.SimpleStatement);
                    node.* = .{
                        .identifier = identifier,
                        .value = value,
                    };
                    try optional_statements.append(self.state.arena, &node.base);
                },
                // Special case
                .menu => {
                    const identifier = self.state.token;
                    try self.nextToken(.whitespace_delimiter_only);
                    try self.check(.literal);
                    const value_node = try self.state.arena.create(Node.Literal);
                    value_node.* = .{
                        .token = self.state.token,
                    };
                    const node = try self.state.arena.create(Node.SimpleStatement);
                    node.* = .{
                        .identifier = identifier,
                        .value = &value_node.base,
                    };
                    try optional_statements.append(self.state.arena, &node.base);
                },
                .font => {
                    const identifier = self.state.token;
                    const point_size = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                    // The comma between point_size and typeface is both optional and
                    // there can be any number of them
                    try self.skipAnyCommas();

                    try self.nextToken(.normal);
                    const typeface = self.state.token;
                    if (!typeface.isStringLiteral()) {
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .expected_something_else,
                            .token = typeface,
                            .extra = .{ .expected_types = .{
                                .string_literal = true,
                            } },
                        });
                    }

                    const ExSpecificValues = struct {
                        weight: ?*Node = null,
                        italic: ?*Node = null,
                        char_set: ?*Node = null,
                    };
                    var ex_specific = ExSpecificValues{};
                    ex_specific: {
                        var optional_param_parser = OptionalParamParser{ .parser = self };
                        switch (resource) {
                            .dialogex => {
                                {
                                    ex_specific.weight = try optional_param_parser.parse(.{});
                                    if (optional_param_parser.finished) break :ex_specific;
                                }
                                {
                                    if (!(try self.parseOptionalToken(.comma))) break :ex_specific;
                                    ex_specific.italic = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                                }
                                {
                                    ex_specific.char_set = try optional_param_parser.parse(.{});
                                    if (optional_param_parser.finished) break :ex_specific;
                                }
                            },
                            .dialog => {},
                            else => unreachable, // only DIALOG and DIALOGEX have FONT optional-statements
                        }
                    }

                    const node = try self.state.arena.create(Node.FontStatement);
                    node.* = .{
                        .identifier = identifier,
                        .point_size = point_size,
                        .typeface = typeface,
                        .weight = ex_specific.weight,
                        .italic = ex_specific.italic,
                        .char_set = ex_specific.char_set,
                    };
                    try optional_statements.append(self.state.arena, &node.base);
                },
            }
        }
        return optional_statements.toOwnedSlice(self.state.arena);
    }

    /// Expects the current token to be the first token of the statement.
    fn parseStatement(self: *Self) Error!*Node {
        const first_token = self.state.token;
        std.debug.assert(first_token.id == .literal);

        if (rc.TopLevelKeywords.map.get(first_token.slice(self.lexer.buffer))) |keyword| switch (keyword) {
            .language => {
                const language_statement = try self.parseLanguageStatement();
                return language_statement;
            },
            .version, .characteristics => {
                const identifier = self.state.token;
                const value = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                const node = try self.state.arena.create(Node.SimpleStatement);
                node.* = .{
                    .identifier = identifier,
                    .value = value,
                };
                return &node.base;
            },
            .stringtable => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();
                const optional_statements = try self.parseOptionalStatements(.stringtable);

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var strings = std.ArrayList(*Node).init(self.state.allocator);
                defer strings.deinit();
                while (true) {
                    const maybe_end_token = try self.lookaheadToken(.normal);
                    switch (maybe_end_token.id) {
                        .end => {
                            self.nextToken(.normal) catch unreachable;
                            break;
                        },
                        .eof => {
                            return self.addErrorDetailsAndFail(ErrorDetails{
                                .err = .unfinished_string_table_block,
                                .token = maybe_end_token,
                            });
                        },
                        else => {},
                    }
                    const id_expression = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                    const comma_token: ?Token = if (try self.parseOptionalToken(.comma)) self.state.token else null;

                    try self.nextToken(.normal);
                    if (self.state.token.id != .quoted_ascii_string and self.state.token.id != .quoted_wide_string) {
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .expected_something_else,
                            .token = self.state.token,
                            .extra = .{ .expected_types = .{ .string_literal = true } },
                        });
                    }

                    const string_node = try self.state.arena.create(Node.StringTableString);
                    string_node.* = .{
                        .id = id_expression,
                        .maybe_comma = comma_token,
                        .string = self.state.token,
                    };
                    try strings.append(&string_node.base);
                }

                if (strings.items.len == 0) {
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .expected_token, // TODO: probably a more specific error message
                        .token = self.state.token,
                        .extra = .{ .expected = .number },
                    });
                }

                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.StringTable);
                node.* = .{
                    .type = first_token,
                    .common_resource_attributes = common_resource_attributes,
                    .optional_statements = optional_statements,
                    .begin_token = begin_token,
                    .strings = try self.state.arena.dupe(*Node, strings.items),
                    .end_token = end_token,
                };
                return &node.base;
            },
        };

        // The Win32 RC compiler allows for a 'dangling' literal at the end of a file
        // (as long as it's not a valid top-level keyword), and there is actually an
        // .rc file with a such a dangling literal in the Windows-classic-samples set
        // of projects. So, we have special compatibility for this particular case.
        const maybe_eof = try self.lookaheadToken(.whitespace_delimiter_only);
        if (maybe_eof.id == .eof) {
            // TODO: emit warning
            var context = try self.state.arena.alloc(Token, 2);
            context[0] = first_token;
            context[1] = maybe_eof;
            const invalid_node = try self.state.arena.create(Node.Invalid);
            invalid_node.* = .{
                .context = context,
            };
            return &invalid_node.base;
        }

        const id_token = first_token;
        const id_code_page = self.lexer.current_code_page;
        try self.nextToken(.whitespace_delimiter_only);
        const resource = try self.checkResource();
        const type_token = self.state.token;

        if (resource == .string_num) {
            try self.addErrorDetails(.{
                .err = .string_resource_as_numeric_type,
                .token = type_token,
            });
            return self.addErrorDetailsAndFail(.{
                .err = .string_resource_as_numeric_type,
                .token = type_token,
                .type = .note,
                .print_source_line = false,
            });
        }

        if (resource == .font) {
            const id_bytes = SourceBytes{
                .slice = id_token.slice(self.lexer.buffer),
                .code_page = id_code_page,
            };
            const maybe_ordinal = res.NameOrOrdinal.maybeOrdinalFromString(id_bytes);
            if (maybe_ordinal == null) {
                const would_be_win32_rc_ordinal = res.NameOrOrdinal.maybeNonAsciiOrdinalFromString(id_bytes);
                if (would_be_win32_rc_ordinal) |win32_rc_ordinal| {
                    try self.addErrorDetails(ErrorDetails{
                        .err = .id_must_be_ordinal,
                        .token = id_token,
                        .extra = .{ .resource = resource },
                    });
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .win32_non_ascii_ordinal,
                        .token = id_token,
                        .type = .note,
                        .print_source_line = false,
                        .extra = .{ .number = win32_rc_ordinal.ordinal },
                    });
                } else {
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .id_must_be_ordinal,
                        .token = id_token,
                        .extra = .{ .resource = resource },
                    });
                }
            }
        }

        switch (resource) {
            .accelerators => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();
                const optional_statements = try self.parseOptionalStatements(resource);

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var accelerators = std.ArrayListUnmanaged(*Node){};

                while (true) {
                    const lookahead = try self.lookaheadToken(.normal);
                    switch (lookahead.id) {
                        .end, .eof => {
                            self.nextToken(.normal) catch unreachable;
                            break;
                        },
                        else => {},
                    }
                    const event = try self.parseExpression(.{ .allowed_types = .{ .number = true, .string = true } });

                    try self.nextToken(.normal);
                    try self.check(.comma);

                    const idvalue = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                    var type_and_options = std.ArrayListUnmanaged(Token){};
                    while (true) {
                        if (!(try self.parseOptionalToken(.comma))) break;

                        try self.nextToken(.normal);
                        if (!rc.AcceleratorTypeAndOptions.map.has(self.tokenSlice())) {
                            return self.addErrorDetailsAndFail(.{
                                .err = .expected_something_else,
                                .token = self.state.token,
                                .extra = .{ .expected_types = .{
                                    .accelerator_type_or_option = true,
                                } },
                            });
                        }
                        try type_and_options.append(self.state.arena, self.state.token);
                    }

                    const node = try self.state.arena.create(Node.Accelerator);
                    node.* = .{
                        .event = event,
                        .idvalue = idvalue,
                        .type_and_options = try type_and_options.toOwnedSlice(self.state.arena),
                    };
                    try accelerators.append(self.state.arena, &node.base);
                }

                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.Accelerators);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .optional_statements = optional_statements,
                    .begin_token = begin_token,
                    .accelerators = try accelerators.toOwnedSlice(self.state.arena),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .dialog, .dialogex => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();

                const x = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                _ = try self.parseOptionalToken(.comma);

                const y = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                _ = try self.parseOptionalToken(.comma);

                const width = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                _ = try self.parseOptionalToken(.comma);

                const height = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                var optional_param_parser = OptionalParamParser{ .parser = self };
                const help_id: ?*Node = try optional_param_parser.parse(.{});

                const optional_statements = try self.parseOptionalStatements(resource);

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var controls = std.ArrayListUnmanaged(*Node){};
                defer controls.deinit(self.state.allocator);
                while (try self.parseControlStatement(resource)) |control_node| {
                    // The number of controls must fit in a u16 in order for it to
                    // be able to be written into the relevant field in the .res data.
                    if (controls.items.len >= std.math.maxInt(u16)) {
                        try self.addErrorDetails(.{
                            .err = .too_many_dialog_controls_or_toolbar_buttons,
                            .token = id_token,
                            .extra = .{ .resource = resource },
                        });
                        return self.addErrorDetailsAndFail(.{
                            .err = .too_many_dialog_controls_or_toolbar_buttons,
                            .type = .note,
                            .token = control_node.getFirstToken(),
                            .token_span_end = control_node.getLastToken(),
                            .extra = .{ .resource = resource },
                        });
                    }

                    try controls.append(self.state.allocator, control_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.Dialog);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .x = x,
                    .y = y,
                    .width = width,
                    .height = height,
                    .help_id = help_id,
                    .optional_statements = optional_statements,
                    .begin_token = begin_token,
                    .controls = try self.state.arena.dupe(*Node, controls.items),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .toolbar => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();

                const button_width = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                try self.nextToken(.normal);
                try self.check(.comma);

                const button_height = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var buttons = std.ArrayListUnmanaged(*Node){};
                defer buttons.deinit(self.state.allocator);
                while (try self.parseToolbarButtonStatement()) |button_node| {
                    // The number of buttons must fit in a u16 in order for it to
                    // be able to be written into the relevant field in the .res data.
                    if (buttons.items.len >= std.math.maxInt(u16)) {
                        try self.addErrorDetails(.{
                            .err = .too_many_dialog_controls_or_toolbar_buttons,
                            .token = id_token,
                            .extra = .{ .resource = resource },
                        });
                        return self.addErrorDetailsAndFail(.{
                            .err = .too_many_dialog_controls_or_toolbar_buttons,
                            .type = .note,
                            .token = button_node.getFirstToken(),
                            .token_span_end = button_node.getLastToken(),
                            .extra = .{ .resource = resource },
                        });
                    }

                    try buttons.append(self.state.allocator, button_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.Toolbar);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .button_width = button_width,
                    .button_height = button_height,
                    .begin_token = begin_token,
                    .buttons = try self.state.arena.dupe(*Node, buttons.items),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .menu, .menuex => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();
                // help id is optional but must come between common resource attributes and optional-statements
                var help_id: ?*Node = null;
                // Note: No comma is allowed before or after help_id of MENUEX and help_id is not
                //       a possible field of MENU.
                if (resource == .menuex and try self.lookaheadCouldBeNumberExpression(.not_disallowed)) {
                    help_id = try self.parseExpression(.{
                        .is_known_to_be_number_expression = true,
                    });
                }
                const optional_statements = try self.parseOptionalStatements(.stringtable);

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var items = std.ArrayListUnmanaged(*Node){};
                defer items.deinit(self.state.allocator);
                while (try self.parseMenuItemStatement(resource, id_token, 1)) |item_node| {
                    try items.append(self.state.allocator, item_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                if (items.items.len == 0) {
                    return self.addErrorDetailsAndFail(.{
                        .err = .empty_menu_not_allowed,
                        .token = type_token,
                    });
                }

                const node = try self.state.arena.create(Node.Menu);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .optional_statements = optional_statements,
                    .help_id = help_id,
                    .begin_token = begin_token,
                    .items = try self.state.arena.dupe(*Node, items.items),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .versioninfo => {
                // common resource attributes must all be contiguous and come before optional-statements
                const common_resource_attributes = try self.parseCommonResourceAttributes();

                var fixed_info = std.ArrayListUnmanaged(*Node){};
                while (try self.parseVersionStatement()) |version_statement| {
                    try fixed_info.append(self.state.arena, version_statement);
                }

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var block_statements = std.ArrayListUnmanaged(*Node){};
                while (try self.parseVersionBlockOrValue(id_token, 1)) |block_node| {
                    try block_statements.append(self.state.arena, block_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.VersionInfo);
                node.* = .{
                    .id = id_token,
                    .versioninfo = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .fixed_info = try fixed_info.toOwnedSlice(self.state.arena),
                    .begin_token = begin_token,
                    .block_statements = try block_statements.toOwnedSlice(self.state.arena),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .dlginclude => {
                const common_resource_attributes = try self.parseCommonResourceAttributes();

                const filename_expression = try self.parseExpression(.{
                    .allowed_types = .{ .string = true },
                });

                const node = try self.state.arena.create(Node.ResourceExternal);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .filename = filename_expression,
                };
                return &node.base;
            },
            .stringtable => {
                return self.addErrorDetailsAndFail(.{
                    .err = .name_or_id_not_allowed,
                    .token = id_token,
                    .extra = .{ .resource = resource },
                });
            },
            // Just try everything as a 'generic' resource (raw data or external file)
            // TODO: More fine-grained switch cases as necessary
            else => {
                const common_resource_attributes = try self.parseCommonResourceAttributes();

                const maybe_begin = try self.lookaheadToken(.normal);
                if (maybe_begin.id == .begin) {
                    self.nextToken(.normal) catch unreachable;

                    if (!resource.canUseRawData()) {
                        try self.addErrorDetails(ErrorDetails{
                            .err = .resource_type_cant_use_raw_data,
                            .token = maybe_begin,
                            .extra = .{ .resource = resource },
                        });
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .resource_type_cant_use_raw_data,
                            .type = .note,
                            .print_source_line = false,
                            .token = maybe_begin,
                        });
                    }

                    const raw_data = try self.parseRawDataBlock();
                    const end_token = self.state.token;

                    const node = try self.state.arena.create(Node.ResourceRawData);
                    node.* = .{
                        .id = id_token,
                        .type = type_token,
                        .common_resource_attributes = common_resource_attributes,
                        .begin_token = maybe_begin,
                        .raw_data = raw_data,
                        .end_token = end_token,
                    };
                    return &node.base;
                }

                const filename_expression = try self.parseExpression(.{
                    // Don't tell the user that numbers are accepted since we error on
                    // number expressions and regular number literals are treated as unquoted
                    // literals rather than numbers, so from the users perspective
                    // numbers aren't really allowed.
                    .expected_types_override = .{
                        .literal = true,
                        .string_literal = true,
                    },
                });

                const node = try self.state.arena.create(Node.ResourceExternal);
                node.* = .{
                    .id = id_token,
                    .type = type_token,
                    .common_resource_attributes = common_resource_attributes,
                    .filename = filename_expression,
                };
                return &node.base;
            },
        }
    }

    /// Expects the current token to be a begin token.
    /// After return, the current token will be the end token.
    fn parseRawDataBlock(self: *Self) Error![]*Node {
        var raw_data = std.ArrayList(*Node).init(self.state.allocator);
        defer raw_data.deinit();
        while (true) {
            const maybe_end_token = try self.lookaheadToken(.normal);
            switch (maybe_end_token.id) {
                .comma => {
                    // comma as the first token in a raw data block is an error
                    if (raw_data.items.len == 0) {
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .expected_something_else,
                            .token = maybe_end_token,
                            .extra = .{ .expected_types = .{
                                .number = true,
                                .number_expression = true,
                                .string_literal = true,
                            } },
                        });
                    }
                    // otherwise just skip over commas
                    self.nextToken(.normal) catch unreachable;
                    continue;
                },
                .end => {
                    self.nextToken(.normal) catch unreachable;
                    break;
                },
                .eof => {
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .unfinished_raw_data_block,
                        .token = maybe_end_token,
                    });
                },
                else => {},
            }
            const expression = try self.parseExpression(.{ .allowed_types = .{ .number = true, .string = true } });
            try raw_data.append(expression);

            if (expression.isNumberExpression()) {
                const maybe_close_paren = try self.lookaheadToken(.normal);
                if (maybe_close_paren.id == .close_paren) {
                    // <number expression>) is an error
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .expected_token,
                        .token = maybe_close_paren,
                        .extra = .{ .expected = .operator },
                    });
                }
            }
        }
        return try self.state.arena.dupe(*Node, raw_data.items);
    }

    /// Expects the current token to be handled, and that the control statement will
    /// begin on the next token.
    /// After return, the current token will be the token immediately before the end of the
    /// control statement (or unchanged if the function returns null).
    fn parseControlStatement(self: *Self, resource: Resource) Error!?*Node {
        const control_token = try self.lookaheadToken(.normal);
        const control = rc.Control.map.get(control_token.slice(self.lexer.buffer)) orelse return null;
        self.nextToken(.normal) catch unreachable;

        try self.skipAnyCommas();

        var text: ?Token = null;
        if (control.hasTextParam()) {
            try self.nextToken(.normal);
            switch (self.state.token.id) {
                .quoted_ascii_string, .quoted_wide_string, .number => {
                    text = self.state.token;
                },
                else => {
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .expected_something_else,
                        .token = self.state.token,
                        .extra = .{ .expected_types = .{
                            .number = true,
                            .string_literal = true,
                        } },
                    });
                },
            }
            try self.skipAnyCommas();
        }

        const id = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

        try self.skipAnyCommas();

        var class: ?*Node = null;
        var style: ?*Node = null;
        if (control == .control) {
            class = try self.parseExpression(.{});
            if (class.?.id == .literal) {
                const class_literal: *Node.Literal = @alignCast(@fieldParentPtr("base", class.?));
                const is_invalid_control_class = class_literal.token.id == .literal and !rc.ControlClass.map.has(class_literal.token.slice(self.lexer.buffer));
                if (is_invalid_control_class) {
                    return self.addErrorDetailsAndFail(.{
                        .err = .expected_something_else,
                        .token = self.state.token,
                        .extra = .{ .expected_types = .{
                            .control_class = true,
                        } },
                    });
                }
            }
            try self.skipAnyCommas();
            style = try self.parseExpression(.{
                .can_contain_not_expressions = true,
                .allowed_types = .{ .number = true },
            });
            // If there is no comma after the style paramter, the Win32 RC compiler
            // could misinterpret the statement and end up skipping over at least one token
            // that should have been interepeted as the next parameter (x). For example:
            //   CONTROL "text", 1, BUTTON, 15 30, 1, 2, 3, 4
            // the `15` is the style parameter, but in the Win32 implementation the `30`
            // is completely ignored (i.e. the `1, 2, 3, 4` are `x`, `y`, `w`, `h`).
            // If a comma is added after the `15`, then `30` gets interpreted (correctly)
            // as the `x` value.
            //
            // Instead of emulating this behavior, we just warn about the potential for
            // weird behavior in the Win32 implementation whenever there isn't a comma after
            // the style parameter.
            const lookahead_token = try self.lookaheadToken(.normal);
            if (lookahead_token.id != .comma and lookahead_token.id != .eof) {
                try self.addErrorDetails(.{
                    .err = .rc_could_miscompile_control_params,
                    .type = .warning,
                    .token = lookahead_token,
                });
                try self.addErrorDetails(.{
                    .err = .rc_could_miscompile_control_params,
                    .type = .note,
                    .token = style.?.getFirstToken(),
                    .token_span_end = style.?.getLastToken(),
                });
            }
            try self.skipAnyCommas();
        }

        const x = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
        _ = try self.parseOptionalToken(.comma);
        const y = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
        _ = try self.parseOptionalToken(.comma);
        const width = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
        _ = try self.parseOptionalToken(.comma);
        const height = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

        var optional_param_parser = OptionalParamParser{ .parser = self };
        if (control != .control) {
            style = try optional_param_parser.parse(.{ .not_expression_allowed = true });
        }

        const exstyle: ?*Node = try optional_param_parser.parse(.{ .not_expression_allowed = true });
        const help_id: ?*Node = switch (resource) {
            .dialogex => try optional_param_parser.parse(.{}),
            else => null,
        };

        var extra_data: []*Node = &[_]*Node{};
        var extra_data_begin: ?Token = null;
        var extra_data_end: ?Token = null;
        // extra data is DIALOGEX-only
        if (resource == .dialogex and try self.parseOptionalToken(.begin)) {
            extra_data_begin = self.state.token;
            extra_data = try self.parseRawDataBlock();
            extra_data_end = self.state.token;
        }

        const node = try self.state.arena.create(Node.ControlStatement);
        node.* = .{
            .type = control_token,
            .text = text,
            .class = class,
            .id = id,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .style = style,
            .exstyle = exstyle,
            .help_id = help_id,
            .extra_data_begin = extra_data_begin,
            .extra_data = extra_data,
            .extra_data_end = extra_data_end,
        };
        return &node.base;
    }

    fn parseToolbarButtonStatement(self: *Self) Error!?*Node {
        const keyword_token = try self.lookaheadToken(.normal);
        const button_type = rc.ToolbarButton.map.get(keyword_token.slice(self.lexer.buffer)) orelse return null;
        self.nextToken(.normal) catch unreachable;

        switch (button_type) {
            .separator => {
                const node = try self.state.arena.create(Node.Literal);
                node.* = .{
                    .token = keyword_token,
                };
                return &node.base;
            },
            .button => {
                const button_id = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                const node = try self.state.arena.create(Node.SimpleStatement);
                node.* = .{
                    .identifier = keyword_token,
                    .value = button_id,
                };
                return &node.base;
            },
        }
    }

    /// Expects the current token to be handled, and that the menuitem/popup statement will
    /// begin on the next token.
    /// After return, the current token will be the token immediately before the end of the
    /// menuitem statement (or unchanged if the function returns null).
    fn parseMenuItemStatement(self: *Self, resource: Resource, top_level_menu_id_token: Token, nesting_level: u32) Error!?*Node {
        const menuitem_token = try self.lookaheadToken(.normal);
        const menuitem = rc.MenuItem.map.get(menuitem_token.slice(self.lexer.buffer)) orelse return null;
        self.nextToken(.normal) catch unreachable;

        if (nesting_level > max_nested_menu_level) {
            try self.addErrorDetails(.{
                .err = .nested_resource_level_exceeds_max,
                .token = top_level_menu_id_token,
                .extra = .{ .resource = resource },
            });
            return self.addErrorDetailsAndFail(.{
                .err = .nested_resource_level_exceeds_max,
                .type = .note,
                .token = menuitem_token,
                .extra = .{ .resource = resource },
            });
        }

        switch (resource) {
            .menu => switch (menuitem) {
                .menuitem => {
                    try self.nextToken(.normal);
                    if (rc.MenuItem.isSeparator(self.state.token.slice(self.lexer.buffer))) {
                        const separator_token = self.state.token;
                        // There can be any number of trailing commas after SEPARATOR
                        try self.skipAnyCommas();
                        const node = try self.state.arena.create(Node.MenuItemSeparator);
                        node.* = .{
                            .menuitem = menuitem_token,
                            .separator = separator_token,
                        };
                        return &node.base;
                    } else {
                        const text = self.state.token;
                        if (!text.isStringLiteral()) {
                            return self.addErrorDetailsAndFail(ErrorDetails{
                                .err = .expected_something_else,
                                .token = text,
                                .extra = .{ .expected_types = .{
                                    .string_literal = true,
                                } },
                            });
                        }
                        try self.skipAnyCommas();

                        const result = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                        _ = try self.parseOptionalToken(.comma);

                        var options = std.ArrayListUnmanaged(Token){};
                        while (true) {
                            const option_token = try self.lookaheadToken(.normal);
                            if (!rc.MenuItem.Option.map.has(option_token.slice(self.lexer.buffer))) {
                                break;
                            }
                            self.nextToken(.normal) catch unreachable;
                            try options.append(self.state.arena, option_token);
                            try self.skipAnyCommas();
                        }

                        const node = try self.state.arena.create(Node.MenuItem);
                        node.* = .{
                            .menuitem = menuitem_token,
                            .text = text,
                            .result = result,
                            .option_list = try options.toOwnedSlice(self.state.arena),
                        };
                        return &node.base;
                    }
                },
                .popup => {
                    try self.nextToken(.normal);
                    const text = self.state.token;
                    if (!text.isStringLiteral()) {
                        return self.addErrorDetailsAndFail(ErrorDetails{
                            .err = .expected_something_else,
                            .token = text,
                            .extra = .{ .expected_types = .{
                                .string_literal = true,
                            } },
                        });
                    }
                    try self.skipAnyCommas();

                    var options = std.ArrayListUnmanaged(Token){};
                    while (true) {
                        const option_token = try self.lookaheadToken(.normal);
                        if (!rc.MenuItem.Option.map.has(option_token.slice(self.lexer.buffer))) {
                            break;
                        }
                        self.nextToken(.normal) catch unreachable;
                        try options.append(self.state.arena, option_token);
                        try self.skipAnyCommas();
                    }

                    try self.nextToken(.normal);
                    const begin_token = self.state.token;
                    try self.check(.begin);

                    var items = std.ArrayListUnmanaged(*Node){};
                    while (try self.parseMenuItemStatement(resource, top_level_menu_id_token, nesting_level + 1)) |item_node| {
                        try items.append(self.state.arena, item_node);
                    }

                    try self.nextToken(.normal);
                    const end_token = self.state.token;
                    try self.check(.end);

                    if (items.items.len == 0) {
                        return self.addErrorDetailsAndFail(.{
                            .err = .empty_menu_not_allowed,
                            .token = menuitem_token,
                        });
                    }

                    const node = try self.state.arena.create(Node.Popup);
                    node.* = .{
                        .popup = menuitem_token,
                        .text = text,
                        .option_list = try options.toOwnedSlice(self.state.arena),
                        .begin_token = begin_token,
                        .items = try items.toOwnedSlice(self.state.arena),
                        .end_token = end_token,
                    };
                    return &node.base;
                },
            },
            .menuex => {
                try self.nextToken(.normal);
                const text = self.state.token;
                if (!text.isStringLiteral()) {
                    return self.addErrorDetailsAndFail(ErrorDetails{
                        .err = .expected_something_else,
                        .token = text,
                        .extra = .{ .expected_types = .{
                            .string_literal = true,
                        } },
                    });
                }

                var param_parser = OptionalParamParser{ .parser = self };
                const id = try param_parser.parse(.{});
                const item_type = try param_parser.parse(.{});
                const state = try param_parser.parse(.{});

                if (menuitem == .menuitem) {
                    // trailing comma is allowed, skip it
                    _ = try self.parseOptionalToken(.comma);

                    const node = try self.state.arena.create(Node.MenuItemEx);
                    node.* = .{
                        .menuitem = menuitem_token,
                        .text = text,
                        .id = id,
                        .type = item_type,
                        .state = state,
                    };
                    return &node.base;
                }

                const help_id = try param_parser.parse(.{});

                // trailing comma is allowed, skip it
                _ = try self.parseOptionalToken(.comma);

                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var items = std.ArrayListUnmanaged(*Node){};
                while (try self.parseMenuItemStatement(resource, top_level_menu_id_token, nesting_level + 1)) |item_node| {
                    try items.append(self.state.arena, item_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                if (items.items.len == 0) {
                    return self.addErrorDetailsAndFail(.{
                        .err = .empty_menu_not_allowed,
                        .token = menuitem_token,
                    });
                }

                const node = try self.state.arena.create(Node.PopupEx);
                node.* = .{
                    .popup = menuitem_token,
                    .text = text,
                    .id = id,
                    .type = item_type,
                    .state = state,
                    .help_id = help_id,
                    .begin_token = begin_token,
                    .items = try items.toOwnedSlice(self.state.arena),
                    .end_token = end_token,
                };
                return &node.base;
            },
            else => unreachable,
        }
        @compileError("unreachable");
    }

    pub const OptionalParamParser = struct {
        finished: bool = false,
        parser: *Self,

        pub const Options = struct {
            not_expression_allowed: bool = false,
        };

        pub fn parse(self: *OptionalParamParser, options: OptionalParamParser.Options) Error!?*Node {
            if (self.finished) return null;
            if (!(try self.parser.parseOptionalToken(.comma))) {
                self.finished = true;
                return null;
            }
            // If the next lookahead token could be part of a number expression,
            // then parse it. Otherwise, treat it as an 'empty' expression and
            // continue parsing, since 'empty' values are allowed.
            if (try self.parser.lookaheadCouldBeNumberExpression(switch (options.not_expression_allowed) {
                true => .not_allowed,
                false => .not_disallowed,
            })) {
                const node = try self.parser.parseExpression(.{
                    .allowed_types = .{ .number = true },
                    .can_contain_not_expressions = options.not_expression_allowed,
                });
                return node;
            }
            return null;
        }
    };

    /// Expects the current token to be handled, and that the version statement will
    /// begin on the next token.
    /// After return, the current token will be the token immediately before the end of the
    /// version statement (or unchanged if the function returns null).
    fn parseVersionStatement(self: *Self) Error!?*Node {
        const type_token = try self.lookaheadToken(.normal);
        const statement_type = rc.VersionInfo.map.get(type_token.slice(self.lexer.buffer)) orelse return null;
        self.nextToken(.normal) catch unreachable;
        switch (statement_type) {
            .file_version, .product_version => {
                var parts_buffer: [4]*Node = undefined;
                var parts = std.ArrayListUnmanaged(*Node).initBuffer(&parts_buffer);

                while (true) {
                    const value = try self.parseExpression(.{ .allowed_types = .{ .number = true } });
                    parts.addOneAssumeCapacity().* = value;

                    if (parts.unusedCapacitySlice().len == 0 or
                        !(try self.parseOptionalToken(.comma)))
                    {
                        break;
                    }
                }

                const node = try self.state.arena.create(Node.VersionStatement);
                node.* = .{
                    .type = type_token,
                    .parts = try self.state.arena.dupe(*Node, parts.items),
                };
                return &node.base;
            },
            else => {
                const value = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

                const node = try self.state.arena.create(Node.SimpleStatement);
                node.* = .{
                    .identifier = type_token,
                    .value = value,
                };
                return &node.base;
            },
        }
    }

    /// Expects the current token to be handled, and that the version BLOCK/VALUE will
    /// begin on the next token.
    /// After return, the current token will be the token immediately before the end of the
    /// version BLOCK/VALUE (or unchanged if the function returns null).
    fn parseVersionBlockOrValue(self: *Self, top_level_version_id_token: Token, nesting_level: u32) Error!?*Node {
        const keyword_token = try self.lookaheadToken(.normal);
        const keyword = rc.VersionBlock.map.get(keyword_token.slice(self.lexer.buffer)) orelse return null;
        self.nextToken(.normal) catch unreachable;

        if (nesting_level > max_nested_version_level) {
            try self.addErrorDetails(.{
                .err = .nested_resource_level_exceeds_max,
                .token = top_level_version_id_token,
                .extra = .{ .resource = .versioninfo },
            });
            return self.addErrorDetailsAndFail(.{
                .err = .nested_resource_level_exceeds_max,
                .type = .note,
                .token = keyword_token,
                .extra = .{ .resource = .versioninfo },
            });
        }

        try self.nextToken(.normal);
        const key = self.state.token;
        if (!key.isStringLiteral()) {
            return self.addErrorDetailsAndFail(.{
                .err = .expected_something_else,
                .token = key,
                .extra = .{ .expected_types = .{
                    .string_literal = true,
                } },
            });
        }
        // Need to keep track of this to detect a potential miscompilation when
        // the comma is omitted and the first value is a quoted string.
        const had_comma_before_first_value = try self.parseOptionalToken(.comma);
        try self.skipAnyCommas();

        const values = try self.parseBlockValuesList(had_comma_before_first_value);

        switch (keyword) {
            .block => {
                try self.nextToken(.normal);
                const begin_token = self.state.token;
                try self.check(.begin);

                var children = std.ArrayListUnmanaged(*Node){};
                while (try self.parseVersionBlockOrValue(top_level_version_id_token, nesting_level + 1)) |value_node| {
                    try children.append(self.state.arena, value_node);
                }

                try self.nextToken(.normal);
                const end_token = self.state.token;
                try self.check(.end);

                const node = try self.state.arena.create(Node.Block);
                node.* = .{
                    .identifier = keyword_token,
                    .key = key,
                    .values = values,
                    .begin_token = begin_token,
                    .children = try children.toOwnedSlice(self.state.arena),
                    .end_token = end_token,
                };
                return &node.base;
            },
            .value => {
                const node = try self.state.arena.create(Node.BlockValue);
                node.* = .{
                    .identifier = keyword_token,
                    .key = key,
                    .values = values,
                };
                return &node.base;
            },
        }
    }

    fn parseBlockValuesList(self: *Self, had_comma_before_first_value: bool) Error![]*Node {
        var values = std.ArrayListUnmanaged(*Node){};
        var seen_number: bool = false;
        var first_string_value: ?*Node = null;
        while (true) {
            const lookahead_token = try self.lookaheadToken(.normal);
            switch (lookahead_token.id) {
                .operator,
                .number,
                .open_paren,
                .quoted_ascii_string,
                .quoted_wide_string,
                => {},
                else => break,
            }
            const value = try self.parseExpression(.{});

            if (value.isNumberExpression()) {
                seen_number = true;
            } else if (first_string_value == null) {
                std.debug.assert(value.isStringLiteral());
                first_string_value = value;
            }

            const has_trailing_comma = try self.parseOptionalToken(.comma);
            try self.skipAnyCommas();

            const value_value = try self.state.arena.create(Node.BlockValueValue);
            value_value.* = .{
                .expression = value,
                .trailing_comma = has_trailing_comma,
            };
            try values.append(self.state.arena, &value_value.base);
        }
        if (seen_number and first_string_value != null) {
            // The Win32 RC compiler does some strange stuff with the data size:
            // Strings are counted as UTF-16 code units including the null-terminator
            // Numbers are counted as their byte lengths
            // So, when both strings and numbers are within a single value,
            // it incorrectly sets the value's type as binary, but then gives the
            // data length as a mixture of bytes and UTF-16 code units. This means that
            // when the length is read, it will be treated as byte length and will
            // not read the full value. We don't reproduce this behavior, so we warn
            // of the miscompilation here.
            try self.addErrorDetails(.{
                .err = .rc_would_miscompile_version_value_byte_count,
                .type = .warning,
                .token = first_string_value.?.getFirstToken(),
                .token_span_start = values.items[0].getFirstToken(),
                .token_span_end = values.items[values.items.len - 1].getLastToken(),
            });
            try self.addErrorDetails(.{
                .err = .rc_would_miscompile_version_value_byte_count,
                .type = .note,
                .token = first_string_value.?.getFirstToken(),
                .token_span_start = values.items[0].getFirstToken(),
                .token_span_end = values.items[values.items.len - 1].getLastToken(),
                .print_source_line = false,
            });
        }
        if (!had_comma_before_first_value and values.items.len > 0 and values.items[0].cast(.block_value_value).?.expression.isStringLiteral()) {
            const token = values.items[0].cast(.block_value_value).?.expression.cast(.literal).?.token;
            try self.addErrorDetails(.{
                .err = .rc_would_miscompile_version_value_padding,
                .type = .warning,
                .token = token,
            });
            try self.addErrorDetails(.{
                .err = .rc_would_miscompile_version_value_padding,
                .type = .note,
                .token = token,
                .print_source_line = false,
            });
        }
        return values.toOwnedSlice(self.state.arena);
    }

    fn numberExpressionContainsAnyLSuffixes(expression_node: *Node, source: []const u8, code_page_lookup: *const CodePageLookup) bool {
        // TODO: This could probably be done without evaluating the whole expression
        return Compiler.evaluateNumberExpression(expression_node, source, code_page_lookup).is_long;
    }

    /// Expects the current token to be a literal token that contains the string LANGUAGE
    fn parseLanguageStatement(self: *Self) Error!*Node {
        const language_token = self.state.token;

        const primary_language = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

        try self.nextToken(.normal);
        try self.check(.comma);

        const sublanguage = try self.parseExpression(.{ .allowed_types = .{ .number = true } });

        // The Win32 RC compiler errors if either parameter contains any number with an L
        // suffix. Instead of that, we want to warn and then let the values get truncated.
        // The warning is done here to allow the compiler logic to not have to deal with this.
        if (numberExpressionContainsAnyLSuffixes(primary_language, self.lexer.buffer, &self.state.input_code_page_lookup)) {
            try self.addErrorDetails(.{
                .err = .rc_would_error_u16_with_l_suffix,
                .type = .warning,
                .token = primary_language.getFirstToken(),
                .token_span_end = primary_language.getLastToken(),
                .extra = .{ .statement_with_u16_param = .language },
            });
            try self.addErrorDetails(.{
                .err = .rc_would_error_u16_with_l_suffix,
                .print_source_line = false,
                .type = .note,
                .token = primary_language.getFirstToken(),
                .token_span_end = primary_language.getLastToken(),
                .extra = .{ .statement_with_u16_param = .language },
            });
        }
        if (numberExpressionContainsAnyLSuffixes(sublanguage, self.lexer.buffer, &self.state.input_code_page_lookup)) {
            try self.addErrorDetails(.{
                .err = .rc_would_error_u16_with_l_suffix,
                .type = .warning,
                .token = sublanguage.getFirstToken(),
                .token_span_end = sublanguage.getLastToken(),
                .extra = .{ .statement_with_u16_param = .language },
            });
            try self.addErrorDetails(.{
                .err = .rc_would_error_u16_with_l_suffix,
                .print_source_line = false,
                .type = .note,
                .token = sublanguage.getFirstToken(),
                .token_span_end = sublanguage.getLastToken(),
                .extra = .{ .statement_with_u16_param = .language },
            });
        }

        const node = try self.state.arena.create(Node.LanguageStatement);
        node.* = .{
            .language_token = language_token,
            .primary_language_id = primary_language,
            .sublanguage_id = sublanguage,
        };
        return &node.base;
    }

    pub const ParseExpressionOptions = struct {
        is_known_to_be_number_expression: bool = false,
        can_contain_not_expressions: bool = false,
        nesting_context: NestingContext = .{},
        allowed_types: AllowedTypes = .{ .literal = true, .number = true, .string = true },
        expected_types_override: ?ErrorDetails.ExpectedTypes = null,

        pub const AllowedTypes = struct {
            literal: bool = false,
            number: bool = false,
            string: bool = false,
        };

        pub const NestingContext = struct {
            first_token: ?Token = null,
            last_token: ?Token = null,
            level: u32 = 0,

            /// Returns a new NestingContext with values modified appropriately for an increased nesting level
            fn incremented(ctx: NestingContext, first_token: Token, most_recent_token: Token) NestingContext {
                return .{
                    .first_token = ctx.first_token orelse first_token,
                    .last_token = most_recent_token,
                    .level = ctx.level + 1,
                };
            }
        };

        pub fn toErrorDetails(options: ParseExpressionOptions, token: Token) ErrorDetails {
            // TODO: expected_types_override interaction with is_known_to_be_number_expression?
            const expected_types = options.expected_types_override orelse ErrorDetails.ExpectedTypes{
                .number = options.allowed_types.number,
                .number_expression = options.allowed_types.number,
                .string_literal = options.allowed_types.string and !options.is_known_to_be_number_expression,
                .literal = options.allowed_types.literal and !options.is_known_to_be_number_expression,
            };
            return ErrorDetails{
                .err = .expected_something_else,
                .token = token,
                .extra = .{ .expected_types = expected_types },
            };
        }
    };

    /// Returns true if the next lookahead token is a number or could be the start of a number expression.
    /// Only useful when looking for empty expressions in optional fields.
    fn lookaheadCouldBeNumberExpression(self: *Self, not_allowed: enum { not_allowed, not_disallowed }) Error!bool {
        var lookahead_token = try self.lookaheadToken(.normal);
        switch (lookahead_token.id) {
            .literal => if (not_allowed == .not_allowed) {
                return std.ascii.eqlIgnoreCase("NOT", lookahead_token.slice(self.lexer.buffer));
            } else return false,
            .number => return true,
            .open_paren => return true,
            .operator => {
                // + can be a unary operator, see parseExpression's handling of unary +
                const operator_char = lookahead_token.slice(self.lexer.buffer)[0];
                return operator_char == '+';
            },
            else => return false,
        }
    }

    fn parsePrimary(self: *Self, options: ParseExpressionOptions) Error!*Node {
        try self.nextToken(.normal);
        const first_token = self.state.token;
        var is_close_paren_expression = false;
        var is_unary_plus_expression = false;
        switch (self.state.token.id) {
            .quoted_ascii_string, .quoted_wide_string => {
                if (!options.allowed_types.string) return self.addErrorDetailsAndFail(options.toErrorDetails(self.state.token));
                const node = try self.state.arena.create(Node.Literal);
                node.* = .{ .token = self.state.token };
                return &node.base;
            },
            .literal => {
                if (options.can_contain_not_expressions and std.ascii.eqlIgnoreCase("NOT", self.state.token.slice(self.lexer.buffer))) {
                    const not_token = self.state.token;
                    try self.nextToken(.normal);
                    try self.check(.number);
                    if (!options.allowed_types.number) return self.addErrorDetailsAndFail(options.toErrorDetails(self.state.token));
                    const node = try self.state.arena.create(Node.NotExpression);
                    node.* = .{
                        .not_token = not_token,
                        .number_token = self.state.token,
                    };
                    return &node.base;
                }
                if (!options.allowed_types.literal) return self.addErrorDetailsAndFail(options.toErrorDetails(self.state.token));
                const node = try self.state.arena.create(Node.Literal);
                node.* = .{ .token = self.state.token };
                return &node.base;
            },
            .number => {
                if (!options.allowed_types.number) return self.addErrorDetailsAndFail(options.toErrorDetails(self.state.token));
                const node = try self.state.arena.create(Node.Literal);
                node.* = .{ .token = self.state.token };
                return &node.base;
            },
            .open_paren => {
                const open_paren_token = self.state.token;

                const expression = try self.parseExpression(.{
                    .is_known_to_be_number_expression = true,
                    .can_contain_not_expressions = options.can_contain_not_expressions,
                    .nesting_context = options.nesting_context.incremented(first_token, open_paren_token),
                    .allowed_types = .{ .number = true },
                });

                try self.nextToken(.normal);
                // TODO: Add context to error about where the open paren is
                try self.check(.close_paren);

                if (!options.allowed_types.number) return self.addErrorDetailsAndFail(options.toErrorDetails(open_paren_token));
                const node = try self.state.arena.create(Node.GroupedExpression);
                node.* = .{
                    .open_token = open_paren_token,
                    .expression = expression,
                    .close_token = self.state.token,
                };
                return &node.base;
            },
            .close_paren => {
                // Note: In the Win32 implementation, a single close paren
                // counts as a valid "expression", but only when its the first and
                // only token in the expression. Such an expression is then treated
                // as a 'skip this expression' instruction. For example:
                //   1 RCDATA { 1, ), ), ), 2 }
                // will be evaluated as if it were `1 RCDATA { 1, 2 }` and only
                // 0x0001 and 0x0002 will be written to the .res data.
                //
                // This behavior is not emulated because it almost certainly has
                // no valid use cases and only introduces edge cases that are
                // not worth the effort to track down and deal with. Instead,
                // we error but also add a note about the Win32 RC behavior if
                // this edge case is detected.
                if (!options.is_known_to_be_number_expression) {
                    is_close_paren_expression = true;
                }
            },
            .operator => {
                // In the Win32 implementation, something akin to a unary +
                // is allowed but it doesn't behave exactly like a unary +.
                // Instead of emulating the Win32 behavior, we instead error
                // and add a note about unary plus not being allowed.
                //
                // This is done because unary + only works in some places,
                // and there's no real use-case for it since it's so limited
                // in how it can be used (e.g. +1 is accepted but (+1) will error)
                //
                // Even understanding when unary plus is allowed is difficult, so
                // we don't do any fancy detection of when the Win32 RC compiler would
                // allow a unary + and instead just output the note in all cases.
                //
                // Some examples of allowed expressions by the Win32 compiler:
                //  +1
                //  0|+5
                //  +1+2
                //  +~-5
                //  +(1)
                //
                // Some examples of disallowed expressions by the Win32 compiler:
                //  (+1)
                //  ++5
                //
                // TODO: Potentially re-evaluate and support the unary plus in a bug-for-bug
                //       compatible way.
                const operator_char = self.state.token.slice(self.lexer.buffer)[0];
                if (operator_char == '+') {
                    is_unary_plus_expression = true;
                }
            },
            else => {},
        }

        try self.addErrorDetails(options.toErrorDetails(self.state.token));
        if (is_close_paren_expression) {
            try self.addErrorDetails(ErrorDetails{
                .err = .close_paren_expression,
                .type = .note,
                .token = self.state.token,
                .print_source_line = false,
            });
        }
        if (is_unary_plus_expression) {
            try self.addErrorDetails(ErrorDetails{
                .err = .unary_plus_expression,
                .type = .note,
                .token = self.state.token,
                .print_source_line = false,
            });
        }
        return error.ParseError;
    }

    /// Expects the current token to have already been dealt with, and that the
    /// expression will start on the next token.
    /// After return, the current token will have been dealt with.
    fn parseExpression(self: *Self, options: ParseExpressionOptions) Error!*Node {
        if (options.nesting_context.level > max_nested_expression_level) {
            try self.addErrorDetails(.{
                .err = .nested_expression_level_exceeds_max,
                .token = options.nesting_context.first_token.?,
            });
            return self.addErrorDetailsAndFail(.{
                .err = .nested_expression_level_exceeds_max,
                .type = .note,
                .token = options.nesting_context.last_token.?,
            });
        }
        var expr: *Node = try self.parsePrimary(options);
        const first_token = expr.getFirstToken();

        // Non-number expressions can't have operators, so we can just return
        if (!expr.isNumberExpression()) return expr;

        while (try self.parseOptionalTokenAdvanced(.operator, .normal_expect_operator)) {
            const operator = self.state.token;
            const rhs_node = try self.parsePrimary(.{
                .is_known_to_be_number_expression = true,
                .can_contain_not_expressions = options.can_contain_not_expressions,
                .nesting_context = options.nesting_context.incremented(first_token, operator),
                .allowed_types = options.allowed_types,
            });

            if (!rhs_node.isNumberExpression()) {
                return self.addErrorDetailsAndFail(ErrorDetails{
                    .err = .expected_something_else,
                    .token = rhs_node.getFirstToken(),
                    .token_span_end = rhs_node.getLastToken(),
                    .extra = .{ .expected_types = .{
                        .number = true,
                        .number_expression = true,
                    } },
                });
            }

            const node = try self.state.arena.create(Node.BinaryExpression);
            node.* = .{
                .left = expr,
                .operator = operator,
                .right = rhs_node,
            };
            expr = &node.base;
        }

        return expr;
    }

    /// Skips any amount of commas (including zero)
    /// In other words, it will skip the regex `,*`
    /// Assumes the token(s) should be parsed with `.normal` as the method.
    fn skipAnyCommas(self: *Self) !void {
        while (try self.parseOptionalToken(.comma)) {}
    }

    /// Advances the current token only if the token's id matches the specified `id`.
    /// Assumes the token should be parsed with `.normal` as the method.
    /// Returns true if the token matched, false otherwise.
    fn parseOptionalToken(self: *Self, id: Token.Id) Error!bool {
        return self.parseOptionalTokenAdvanced(id, .normal);
    }

    /// Advances the current token only if the token's id matches the specified `id`.
    /// Returns true if the token matched, false otherwise.
    fn parseOptionalTokenAdvanced(self: *Self, id: Token.Id, comptime method: Lexer.LexMethod) Error!bool {
        const maybe_token = try self.lookaheadToken(method);
        if (maybe_token.id != id) return false;
        self.nextToken(method) catch unreachable;
        return true;
    }

    fn addErrorDetails(self: *Self, details: ErrorDetails) Allocator.Error!void {
        try self.state.diagnostics.append(details);
    }

    fn addErrorDetailsAndFail(self: *Self, details: ErrorDetails) Error {
        try self.addErrorDetails(details);
        return error.ParseError;
    }

    fn nextToken(self: *Self, comptime method: Lexer.LexMethod) Error!void {
        self.state.token = token: while (true) {
            const token = self.lexer.next(method) catch |err| switch (err) {
                error.CodePagePragmaInIncludedFile => {
                    // The Win32 RC compiler silently ignores such `#pragma code_point` directives,
                    // but we want to both ignore them *and* emit a warning
                    try self.addErrorDetails(.{
                        .err = .code_page_pragma_in_included_file,
                        .type = .warning,
                        .token = self.lexer.error_context_token.?,
                    });
                    continue;
                },
                error.CodePagePragmaInvalidCodePage => {
                    var details = self.lexer.getErrorDetails(err);
                    if (!self.options.warn_instead_of_error_on_invalid_code_page) {
                        return self.addErrorDetailsAndFail(details);
                    }
                    details.type = .warning;
                    try self.addErrorDetails(details);
                    continue;
                },
                error.InvalidDigitCharacterInNumberLiteral => {
                    const details = self.lexer.getErrorDetails(err);
                    try self.addErrorDetails(details);
                    return self.addErrorDetailsAndFail(.{
                        .err = details.err,
                        .type = .note,
                        .token = details.token,
                        .print_source_line = false,
                    });
                },
                else => return self.addErrorDetailsAndFail(self.lexer.getErrorDetails(err)),
            };
            break :token token;
        };
        // After every token, set the input code page for its line
        try self.state.input_code_page_lookup.setForToken(self.state.token, self.lexer.current_code_page);
        // But only set the output code page to the current code page if we are past the first code_page pragma in the file.
        // Otherwise, we want to fill the lookup using the default code page so that lookups still work for lines that
        // don't have an explicit output code page set.
        const output_code_page = if (self.lexer.seen_pragma_code_pages > 1) self.lexer.current_code_page else self.state.output_code_page_lookup.default_code_page;
        try self.state.output_code_page_lookup.setForToken(self.state.token, output_code_page);
    }

    fn lookaheadToken(self: *Self, comptime method: Lexer.LexMethod) Error!Token {
        self.state.lookahead_lexer = self.lexer.*;
        return token: while (true) {
            break :token self.state.lookahead_lexer.next(method) catch |err| switch (err) {
                // Ignore this error and get the next valid token, we'll deal with this
                // properly when getting the token for real
                error.CodePagePragmaInIncludedFile => continue,
                else => return self.addErrorDetailsAndFail(self.state.lookahead_lexer.getErrorDetails(err)),
            };
        };
    }

    fn tokenSlice(self: *Self) []const u8 {
        return self.state.token.slice(self.lexer.buffer);
    }

    /// Check that the current token is something that can be used as an ID
    fn checkId(self: *Self) !void {
        switch (self.state.token.id) {
            .literal => {},
            else => {
                return self.addErrorDetailsAndFail(ErrorDetails{
                    .err = .expected_token,
                    .token = self.state.token,
                    .extra = .{ .expected = .literal },
                });
            },
        }
    }

    fn check(self: *Self, expected_token_id: Token.Id) !void {
        if (self.state.token.id != expected_token_id) {
            return self.addErrorDetailsAndFail(ErrorDetails{
                .err = .expected_token,
                .token = self.state.token,
                .extra = .{ .expected = expected_token_id },
            });
        }
    }

    fn checkResource(self: *Self) !Resource {
        switch (self.state.token.id) {
            .literal => return Resource.fromString(.{
                .slice = self.state.token.slice(self.lexer.buffer),
                .code_page = self.lexer.current_code_page,
            }),
            else => {
                return self.addErrorDetailsAndFail(ErrorDetails{
                    .err = .expected_token,
                    .token = self.state.token,
                    .extra = .{ .expected = .literal },
                });
            },
        }
    }
};
