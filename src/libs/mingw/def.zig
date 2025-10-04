const std = @import("std");

pub const ModuleDefinitionType = enum {
    mingw,
};

pub const ModuleDefinition = struct {
    exports: std.ArrayList(Export) = .empty,
    name: ?[]const u8 = null,
    base_address: usize = 0,
    arena: std.heap.ArenaAllocator,
    type: ModuleDefinitionType,

    pub const Export = struct {
        /// This may lack mangling, such as underscore prefixing and stdcall suffixing.
        /// In a .def file, this is `foo` in `foo` or `bar` in `foo = bar`.
        name: []const u8,
        /// Note: This is currently only set by `fixupForImportLibraryGeneration`
        mangled_symbol_name: ?[]const u8,
        /// The external, exported name.
        /// In a .def file, this is `foo` in `foo = bar`.
        ext_name: ?[]const u8,
        /// In a .def file, this is `bar` in `foo == bar`.
        import_name: ?[]const u8,
        /// In a .def file, this is `bar` in `foo EXPORTAS bar`.
        export_as: ?[]const u8,
        no_name: bool,
        ordinal: u16,
        type: std.coff.ImportType,
        private: bool,
    };

    /// Modifies `exports` such that import library generation will
    /// behave as expected. Based on LLVM's dlltool driver.
    pub fn fixupForImportLibraryGeneration(self: *ModuleDefinition, machine_type: std.coff.IMAGE.FILE.MACHINE) void {
        const kill_at = true;
        for (self.exports.items) |*e| {
            // If ExtName is set (if the "ExtName = Name" syntax was used), overwrite
            // Name with ExtName and clear ExtName. When only creating an import
            // library and not linking, the internal name is irrelevant. This avoids
            // cases where writeImportLibrary tries to transplant decoration from
            // symbol decoration onto ExtName.
            if (e.ext_name) |ext_name| {
                e.name = ext_name;
                e.ext_name = null;
            }

            if (kill_at) {
                if (e.import_name != null or std.mem.startsWith(u8, e.name, "?"))
                    continue;

                if (machine_type == .I386) {
                    // By making sure E.SymbolName != E.Name for decorated symbols,
                    // writeImportLibrary writes these symbols with the type
                    // IMPORT_NAME_UNDECORATE.
                    e.mangled_symbol_name = e.name;
                }
                // Trim off the trailing decoration. Symbols will always have a
                // starting prefix here (either _ for cdecl/stdcall, @ for fastcall
                // or ? for C++ functions). Vectorcall functions won't have any
                // fixed prefix, but the function base name will still be at least
                // one char.
                const name_len_without_at_suffix = std.mem.indexOfScalarPos(u8, e.name, 1, '@') orelse e.name.len;
                e.name = e.name[0..name_len_without_at_suffix];
            }
        }
    }

    pub fn deinit(self: *const ModuleDefinition) void {
        self.arena.deinit();
    }
};

pub const Diagnostics = struct {
    err: Error,
    token: Token,
    extra: Extra = .{ .none = {} },

    pub const Extra = union {
        none: void,
        expected: Token.Tag,
    };

    pub const Error = enum {
        invalid_byte,
        unfinished_quoted_identifier,
        /// `expected` is populated
        expected_token,
        expected_integer,
        unknown_statement,
        unimplemented,
    };

    fn formatToken(ctx: TokenFormatContext, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (ctx.token.tag) {
            .eof, .invalid => return writer.writeAll(ctx.token.tag.nameForErrorDisplay()),
            else => return writer.writeAll(ctx.token.slice(ctx.source)),
        }
    }

    const TokenFormatContext = struct {
        token: Token,
        source: []const u8,
    };

    fn fmtToken(self: Diagnostics, source: []const u8) std.fmt.Alt(TokenFormatContext, formatToken) {
        return .{ .data = .{
            .token = self.token,
            .source = source,
        } };
    }

    pub fn writeMsg(self: Diagnostics, writer: *std.Io.Writer, source: []const u8) !void {
        switch (self.err) {
            .invalid_byte => {
                return writer.print("invalid byte '{f}'", .{std.ascii.hexEscape(self.token.slice(source), .upper)});
            },
            .unfinished_quoted_identifier => {
                return writer.print("unfinished quoted identifier at '{f}', expected closing '\"'", .{self.fmtToken(source)});
            },
            .expected_token => {
                return writer.print("expected '{s}', got '{f}'", .{ self.extra.expected.nameForErrorDisplay(), self.fmtToken(source) });
            },
            .expected_integer => {
                return writer.print("expected integer, got '{f}'", .{self.fmtToken(source)});
            },
            .unimplemented => {
                return writer.print("support for '{f}' has not yet been implemented", .{self.fmtToken(source)});
            },
            .unknown_statement => {
                return writer.print("unknown/invalid statement syntax beginning with '{f}'", .{self.fmtToken(source)});
            },
        }
    }
};

pub fn parse(
    allocator: std.mem.Allocator,
    source: [:0]const u8,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_definition_type: ModuleDefinitionType,
    diagnostics: *Diagnostics,
) !ModuleDefinition {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, machine_type, module_definition_type, diagnostics);

    return parser.parse(allocator);
}

const Token = struct {
    tag: Tag,
    start: usize,
    end: usize,

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "BASE", .keyword_base },
        .{ "CONSTANT", .keyword_constant },
        .{ "DATA", .keyword_data },
        .{ "EXPORTS", .keyword_exports },
        .{ "EXPORTAS", .keyword_exportas },
        .{ "HEAPSIZE", .keyword_heapsize },
        .{ "LIBRARY", .keyword_library },
        .{ "NAME", .keyword_name },
        .{ "NONAME", .keyword_noname },
        .{ "PRIVATE", .keyword_private },
        .{ "STACKSIZE", .keyword_stacksize },
        .{ "VERSION", .keyword_version },
    });

    pub const Tag = enum {
        invalid,
        eof,
        identifier,
        comma,
        equal,
        equal_equal,
        keyword_base,
        keyword_constant,
        keyword_data,
        keyword_exports,
        keyword_exportas,
        keyword_heapsize,
        keyword_library,
        keyword_name,
        keyword_noname,
        keyword_private,
        keyword_stacksize,
        keyword_version,

        pub fn nameForErrorDisplay(self: Tag) []const u8 {
            return switch (self) {
                .invalid => "<invalid>",
                .eof => "<eof>",
                .identifier => "<identifier>",
                .comma => ",",
                .equal => "=",
                .equal_equal => "==",
                .keyword_base => "BASE",
                .keyword_constant => "CONSTANT",
                .keyword_data => "DATA",
                .keyword_exports => "EXPORTS",
                .keyword_exportas => "EXPORTAS",
                .keyword_heapsize => "HEAPSIZE",
                .keyword_library => "LIBRARY",
                .keyword_name => "NAME",
                .keyword_noname => "NONAME",
                .keyword_private => "PRIVATE",
                .keyword_stacksize => "STACKSIZE",
                .keyword_version => "VERSION",
            };
        }
    };

    /// Returns a useful slice of the token, e.g. for quoted identifiers, this
    /// will return a slice without the quotes included.
    pub fn slice(self: Token, source: []const u8) []const u8 {
        return source[self.start..self.end];
    }
};

const Tokenizer = struct {
    source: [:0]const u8,
    index: usize,
    error_context_token: ?Token = null,

    pub fn init(source: [:0]const u8) Tokenizer {
        return .{
            .source = source,
            .index = 0,
        };
    }

    const State = enum {
        start,
        identifier_or_keyword,
        quoted_identifier,
        comment,
        equal,
        eof_or_invalid,
    };

    pub const Error = error{
        InvalidByte,
        UnfinishedQuotedIdentifier,
    };

    pub fn next(self: *Tokenizer) Error!Token {
        var result: Token = .{
            .tag = undefined,
            .start = self.index,
            .end = undefined,
        };
        state: switch (State.start) {
            .start => switch (self.source[self.index]) {
                0 => continue :state .eof_or_invalid,
                '\r', '\n', ' ', '\t', '\x0B' => {
                    self.index += 1;
                    result.start = self.index;
                    continue :state .start;
                },
                ';' => continue :state .comment,
                '=' => continue :state .equal,
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                },
                '"' => continue :state .quoted_identifier,
                else => continue :state .identifier_or_keyword,
            },
            .comment => {
                self.index += 1;
                switch (self.source[self.index]) {
                    0 => continue :state .eof_or_invalid,
                    '\n' => {
                        self.index += 1;
                        result.start = self.index;
                        continue :state .start;
                    },
                    else => continue :state .comment,
                }
            },
            .equal => {
                self.index += 1;
                switch (self.source[self.index]) {
                    '=' => {
                        result.tag = .equal_equal;
                        self.index += 1;
                    },
                    else => result.tag = .equal,
                }
            },
            .quoted_identifier => {
                self.index += 1;
                switch (self.source[self.index]) {
                    0 => {
                        self.error_context_token = .{
                            .tag = .eof,
                            .start = self.index,
                            .end = self.index,
                        };
                        return error.UnfinishedQuotedIdentifier;
                    },
                    '"' => {
                        result.tag = .identifier;
                        self.index += 1;

                        // Return the token unquoted
                        return .{
                            .tag = result.tag,
                            .start = result.start + 1,
                            .end = self.index - 1,
                        };
                    },
                    else => continue :state .quoted_identifier,
                }
            },
            .identifier_or_keyword => {
                self.index += 1;
                switch (self.source[self.index]) {
                    0, '=', ',', ';', '\r', '\n', ' ', '\t', '\x0B' => {
                        const keyword = Token.keywords.get(self.source[result.start..self.index]);
                        result.tag = keyword orelse .identifier;
                    },
                    else => continue :state .identifier_or_keyword,
                }
            },
            .eof_or_invalid => {
                if (self.index == self.source.len) {
                    return .{
                        .tag = .eof,
                        .start = self.index,
                        .end = self.index,
                    };
                }
                self.error_context_token = .{
                    .tag = .invalid,
                    .start = self.index,
                    .end = self.index + 1,
                };
                return error.InvalidByte;
            },
        }

        result.end = self.index;
        return result;
    }
};

test Tokenizer {
    try testTokenizer(
        \\foo
        \\; hello
        \\BASE
        \\"bar"
        \\
    , &.{
        .identifier,
        .keyword_base,
        .identifier,
    });
}

fn testTokenizer(source: [:0]const u8, expected: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected) |expected_tag| {
        const token = try tokenizer.next();
        try std.testing.expectEqual(expected_tag, token.tag);
    }
    const last_token = try tokenizer.next();
    try std.testing.expectEqual(.eof, last_token.tag);
}

pub const Parser = struct {
    tokenizer: *Tokenizer,
    diagnostics: *Diagnostics,
    lookahead_tokenizer: Tokenizer,
    machine_type: std.coff.IMAGE.FILE.MACHINE,
    module_definition_type: ModuleDefinitionType,

    pub fn init(
        tokenizer: *Tokenizer,
        machine_type: std.coff.IMAGE.FILE.MACHINE,
        module_definition_type: ModuleDefinitionType,
        diagnostics: *Diagnostics,
    ) Parser {
        return .{
            .tokenizer = tokenizer,
            .machine_type = machine_type,
            .module_definition_type = module_definition_type,
            .diagnostics = diagnostics,
            .lookahead_tokenizer = undefined,
        };
    }

    pub const Error = error{ParseError} || std.mem.Allocator.Error;

    pub fn parse(self: *Parser, allocator: std.mem.Allocator) Error!ModuleDefinition {
        var module: ModuleDefinition = .{
            .arena = .init(allocator),
            .type = self.module_definition_type,
        };
        const arena = module.arena.allocator();
        errdefer module.deinit();
        while (true) {
            const tok = try self.nextToken();
            switch (tok.tag) {
                .eof => break,
                .keyword_library, .keyword_name => {
                    const is_library = tok.tag == .keyword_library;

                    const name = try self.lookaheadToken();
                    if (name.tag != .identifier) continue;
                    self.commitLookahead();

                    const base_tok = try self.lookaheadToken();
                    if (base_tok.tag == .keyword_base) {
                        self.commitLookahead();

                        _ = try self.expectToken(.equal);

                        module.base_address = try self.expectInteger(usize);
                    }

                    // Append .dll/.exe if there's no extension
                    const name_slice = name.slice(self.tokenizer.source);
                    module.name = if (std.fs.path.extension(name_slice).len == 0)
                        try std.mem.concat(arena, u8, &.{ name_slice, if (is_library) ".dll" else ".exe" })
                    else
                        try arena.dupe(u8, name_slice);
                },
                .keyword_exports => {
                    while (true) {
                        var name_tok = try self.lookaheadToken();
                        if (name_tok.tag != .identifier) break;
                        self.commitLookahead();

                        const ext_name_tok = ext_name: {
                            const equal = try self.lookaheadToken();
                            if (equal.tag != .equal) break :ext_name null;
                            self.commitLookahead();

                            // The syntax is `<ext_name> = <name>`, so we need to
                            // swap the current name token over to ext_name and use
                            // this token as the name.
                            const ext_name_tok = name_tok;
                            name_tok = try self.expectToken(.identifier);
                            break :ext_name ext_name_tok;
                        };

                        var name_needs_underscore = false;
                        var ext_name_needs_underscore = false;
                        if (self.machine_type == .I386) {
                            const is_decorated = isDecorated(name_tok.slice(self.tokenizer.source), self.module_definition_type);
                            const is_forward_target = ext_name_tok != null and std.mem.indexOfScalar(u8, name_tok.slice(self.tokenizer.source), '.') != null;
                            name_needs_underscore = !is_decorated and !is_forward_target;

                            if (ext_name_tok) |ext_name| {
                                ext_name_needs_underscore = !isDecorated(ext_name.slice(self.tokenizer.source), self.module_definition_type);
                            }
                        }

                        var import_name_tok: ?Token = null;
                        var export_as_tok: ?Token = null;
                        var ordinal: ?u16 = null;
                        var import_type: std.coff.ImportType = .CODE;
                        var private: bool = false;
                        var no_name: bool = false;
                        while (true) {
                            const arg_tok = try self.lookaheadToken();
                            switch (arg_tok.tag) {
                                .identifier => {
                                    const slice = arg_tok.slice(self.tokenizer.source);
                                    if (slice[0] != '@') break;

                                    // foo @ 10
                                    if (slice.len == 1) {
                                        self.commitLookahead();
                                        ordinal = try self.expectInteger(u16);
                                        continue;
                                    }
                                    // foo @10
                                    ordinal = std.fmt.parseUnsigned(u16, slice[1..], 0) catch {
                                        // e.g. foo @bar, the @bar is presumed to be the start of a separate
                                        // export (and there could be a newline between them)
                                        break;
                                    };
                                    // finally safe to commit to consuming the token
                                    self.commitLookahead();

                                    const noname_tok = try self.lookaheadToken();
                                    if (noname_tok.tag == .keyword_noname) {
                                        self.commitLookahead();
                                        no_name = true;
                                    }
                                },
                                .equal_equal => {
                                    self.commitLookahead();
                                    import_name_tok = try self.expectToken(.identifier);
                                },
                                .keyword_data => {
                                    self.commitLookahead();
                                    import_type = .DATA;
                                },
                                .keyword_constant => {
                                    self.commitLookahead();
                                    import_type = .CONST;
                                },
                                .keyword_private => {
                                    self.commitLookahead();
                                    private = true;
                                },
                                .keyword_exportas => {
                                    self.commitLookahead();
                                    export_as_tok = try self.expectToken(.identifier);
                                },
                                else => break,
                            }
                        }

                        const name = if (name_needs_underscore)
                            try std.mem.concat(arena, u8, &.{ "_", name_tok.slice(self.tokenizer.source) })
                        else
                            try arena.dupe(u8, name_tok.slice(self.tokenizer.source));

                        const ext_name: ?[]const u8 = if (ext_name_tok) |ext_name| if (name_needs_underscore)
                            try std.mem.concat(arena, u8, &.{ "_", ext_name.slice(self.tokenizer.source) })
                        else
                            try arena.dupe(u8, ext_name.slice(self.tokenizer.source)) else null;

                        try module.exports.append(arena, .{
                            .name = name,
                            .mangled_symbol_name = null,
                            .ext_name = ext_name,
                            .import_name = if (import_name_tok) |imp_name| try arena.dupe(u8, imp_name.slice(self.tokenizer.source)) else null,
                            .export_as = if (export_as_tok) |export_as| try arena.dupe(u8, export_as.slice(self.tokenizer.source)) else null,
                            .no_name = no_name,
                            .ordinal = ordinal orelse 0,
                            .type = import_type,
                            .private = private,
                        });
                    }
                },
                .keyword_heapsize,
                .keyword_stacksize,
                .keyword_version,
                => return self.unimplemented(tok),
                else => {
                    self.diagnostics.* = .{
                        .err = .unknown_statement,
                        .token = tok,
                    };
                    return error.ParseError;
                },
            }
        }
        return module;
    }

    fn isDecorated(symbol: []const u8, module_definition_type: ModuleDefinitionType) bool {
        // In def files, the symbols can either be listed decorated or undecorated.
        //
        // - For cdecl symbols, only the undecorated form is allowed.
        // - For fastcall and vectorcall symbols, both fully decorated or
        //   undecorated forms can be present.
        // - For stdcall symbols in non-MinGW environments, the decorated form is
        //   fully decorated with leading underscore and trailing stack argument
        //   size - like "_Func@0".
        // - In MinGW def files, a decorated stdcall symbol does not include the
        //   leading underscore though, like "Func@0".

        // This function controls whether a leading underscore should be added to
        // the given symbol name or not. For MinGW, treat a stdcall symbol name such
        // as "Func@0" as undecorated, i.e. a leading underscore must be added.
        // For non-MinGW, look for '@' in the whole string and consider "_Func@0"
        // as decorated, i.e. don't add any more leading underscores.
        // We can't check for a leading underscore here, since function names
        // themselves can start with an underscore, while a second one still needs
        // to be added.
        if (std.mem.startsWith(u8, symbol, "@")) return true;
        if (std.mem.indexOf(u8, symbol, "@@") != null) return true;
        if (std.mem.startsWith(u8, symbol, "?")) return true;
        if (module_definition_type != .mingw and std.mem.indexOfScalar(u8, symbol, '@') != null) return true;
        return false;
    }

    fn expectInteger(self: *Parser, T: type) Error!T {
        const tok = try self.nextToken();
        blk: {
            if (tok.tag != .identifier) break :blk;
            return std.fmt.parseUnsigned(T, tok.slice(self.tokenizer.source), 0) catch break :blk;
        }
        self.diagnostics.* = .{
            .err = .expected_integer,
            .token = tok,
        };
        return error.ParseError;
    }

    fn unimplemented(self: *Parser, tok: Token) Error {
        self.diagnostics.* = .{
            .err = .unimplemented,
            .token = tok,
        };
        return error.ParseError;
    }

    fn expectToken(self: *Parser, tag: Token.Tag) Error!Token {
        const tok = try self.nextToken();
        if (tok.tag != tag) {
            self.diagnostics.* = .{
                .err = .expected_token,
                .token = tok,
                .extra = .{ .expected = tag },
            };
            return error.ParseError;
        }
        return tok;
    }

    fn nextToken(self: *Parser) Error!Token {
        return self.nextFromTokenizer(self.tokenizer);
    }

    fn lookaheadToken(self: *Parser) Error!Token {
        self.lookahead_tokenizer = self.tokenizer.*;
        return self.nextFromTokenizer(&self.lookahead_tokenizer);
    }

    fn commitLookahead(self: *Parser) void {
        self.tokenizer.* = self.lookahead_tokenizer;
    }

    fn nextFromTokenizer(
        self: *Parser,
        tokenizer: *Tokenizer,
    ) Error!Token {
        return tokenizer.next() catch |err| {
            self.diagnostics.* = .{
                .err = switch (err) {
                    error.InvalidByte => .invalid_byte,
                    error.UnfinishedQuotedIdentifier => .unfinished_quoted_identifier,
                },
                .token = tokenizer.error_context_token.?,
            };
            return error.ParseError;
        };
    }
};

test parse {
    const source =
        \\LIBRARY "foo"
        \\; hello
        \\EXPORTS
        \\foo @ 10
        \\bar @104
        \\baz@4
        \\foo == bar
        \\alias = function
        \\
        \\data DATA
        \\constant CONSTANT
        \\
    ;

    try testParse(.AMD64, source, "foo.dll", &[_]ModuleDefinition.Export{
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 10,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "bar",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 104,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "baz@4",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = "bar",
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "function",
            .mangled_symbol_name = null,
            .ext_name = "alias",
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "data",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .DATA,
            .private = false,
        },
        .{
            .name = "constant",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CONST,
            .private = false,
        },
    });

    try testParse(.I386, source, "foo.dll", &[_]ModuleDefinition.Export{
        .{
            .name = "_foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 10,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "_bar",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 104,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "_baz@4",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "_foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = "bar",
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "_function",
            .mangled_symbol_name = null,
            .ext_name = "_alias",
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "_data",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .DATA,
            .private = false,
        },
        .{
            .name = "_constant",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CONST,
            .private = false,
        },
    });

    try testParse(.ARMNT, source, "foo.dll", &[_]ModuleDefinition.Export{
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 10,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "bar",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 104,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "baz@4",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = "bar",
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "function",
            .mangled_symbol_name = null,
            .ext_name = "alias",
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "data",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .DATA,
            .private = false,
        },
        .{
            .name = "constant",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CONST,
            .private = false,
        },
    });

    try testParse(.ARM64, source, "foo.dll", &[_]ModuleDefinition.Export{
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 10,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "bar",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 104,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "baz@4",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "foo",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = "bar",
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "function",
            .mangled_symbol_name = null,
            .ext_name = "alias",
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "data",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .DATA,
            .private = false,
        },
        .{
            .name = "constant",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CONST,
            .private = false,
        },
    });
}

test "ntdll" {
    const source =
        \\;
        \\; Definition file of ntdll.dll
        \\; Automatic generated by gendef
        \\; written by Kai Tietz 2008
        \\;
        \\LIBRARY "ntdll.dll"
        \\EXPORTS
        \\RtlDispatchAPC@12
        \\RtlActivateActivationContextUnsafeFast@0
    ;

    try testParse(.AMD64, source, "ntdll.dll", &[_]ModuleDefinition.Export{
        .{
            .name = "RtlDispatchAPC@12",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
        .{
            .name = "RtlActivateActivationContextUnsafeFast@0",
            .mangled_symbol_name = null,
            .ext_name = null,
            .import_name = null,
            .export_as = null,
            .no_name = false,
            .ordinal = 0,
            .type = .CODE,
            .private = false,
        },
    });
}

fn testParse(machine_type: std.coff.IMAGE.FILE.MACHINE, source: [:0]const u8, expected_module_name: []const u8, expected_exports: []const ModuleDefinition.Export) !void {
    var diagnostics: Diagnostics = undefined;
    const module = parse(std.testing.allocator, source, machine_type, .mingw, &diagnostics) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.ParseError => {
            const stderr = std.debug.lockStderrWriter(&.{});
            defer std.debug.unlockStderrWriter();
            try diagnostics.writeMsg(stderr, source);
            try stderr.writeByte('\n');
            return err;
        },
    };
    defer module.deinit();

    try std.testing.expectEqualStrings(expected_module_name, module.name orelse "");
    try std.testing.expectEqual(expected_exports.len, module.exports.items.len);
    for (expected_exports, module.exports.items) |expected, actual| {
        try std.testing.expectEqualStrings(expected.name, actual.name);
        try std.testing.expectEqualStrings(expected.export_as orelse "", actual.export_as orelse "");
        try std.testing.expectEqualStrings(expected.ext_name orelse "", actual.ext_name orelse "");
        try std.testing.expectEqualStrings(expected.import_name orelse "", actual.import_name orelse "");
        try std.testing.expectEqualStrings(expected.mangled_symbol_name orelse "", actual.mangled_symbol_name orelse "");
        try std.testing.expectEqual(expected.ordinal, actual.ordinal);
        try std.testing.expectEqual(expected.no_name, actual.no_name);
        try std.testing.expectEqual(expected.private, actual.private);
        try std.testing.expectEqual(expected.type, actual.type);
    }
}

test "parse errors" {
    for (&[_]std.coff.IMAGE.FILE.MACHINE{ .AMD64, .I386, .ARMNT, .ARM64 }) |machine_type| {
        try testParseErrorMsg("invalid byte '\\x00'", machine_type, "LIBRARY \x00");
        try testParseErrorMsg("unfinished quoted identifier at '<eof>', expected closing '\"'", machine_type, "LIBRARY \"foo");
        try testParseErrorMsg("expected '=', got 'foo'", machine_type, "LIBRARY foo BASE foo");
        try testParseErrorMsg("expected integer, got 'foo'", machine_type, "EXPORTS foo @ foo");
        try testParseErrorMsg("support for 'HEAPSIZE' has not yet been implemented", machine_type, "HEAPSIZE");
        try testParseErrorMsg("unknown/invalid statement syntax beginning with 'LIB'", machine_type, "LIB");
    }
}

fn testParseErrorMsg(expected_msg: []const u8, machine_type: std.coff.IMAGE.FILE.MACHINE, source: [:0]const u8) !void {
    var diagnostics: Diagnostics = undefined;
    _ = parse(std.testing.allocator, source, machine_type, .mingw, &diagnostics) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.ParseError => {
            var buf: [256]u8 = undefined;
            var writer: std.Io.Writer = .fixed(&buf);
            try diagnostics.writeMsg(&writer, source);
            try std.testing.expectEqualStrings(expected_msg, writer.buffered());
            return;
        },
    };
    return error.UnexpectedSuccess;
}
