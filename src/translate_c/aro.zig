const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Tokenizer = @import("Tokenizer.zig");
const CToken = Tokenizer.Token;
const ast = @import("ast.zig");
const ZigNode = ast.Node;

pub const PatternList = struct {
    patterns: []Pattern,

    /// Templates must be function-like macros
    /// first element is macro source, second element is the name of the function
    /// in std.lib.zig.c_translation.Macros which implements it
    const templates = [_][2][]const u8{
        [2][]const u8{ "f_SUFFIX(X) (X ## f)", "F_SUFFIX" },
        [2][]const u8{ "F_SUFFIX(X) (X ## F)", "F_SUFFIX" },

        [2][]const u8{ "u_SUFFIX(X) (X ## u)", "U_SUFFIX" },
        [2][]const u8{ "U_SUFFIX(X) (X ## U)", "U_SUFFIX" },

        [2][]const u8{ "l_SUFFIX(X) (X ## l)", "L_SUFFIX" },
        [2][]const u8{ "L_SUFFIX(X) (X ## L)", "L_SUFFIX" },

        [2][]const u8{ "ul_SUFFIX(X) (X ## ul)", "UL_SUFFIX" },
        [2][]const u8{ "uL_SUFFIX(X) (X ## uL)", "UL_SUFFIX" },
        [2][]const u8{ "Ul_SUFFIX(X) (X ## Ul)", "UL_SUFFIX" },
        [2][]const u8{ "UL_SUFFIX(X) (X ## UL)", "UL_SUFFIX" },

        [2][]const u8{ "ll_SUFFIX(X) (X ## ll)", "LL_SUFFIX" },
        [2][]const u8{ "LL_SUFFIX(X) (X ## LL)", "LL_SUFFIX" },

        [2][]const u8{ "ull_SUFFIX(X) (X ## ull)", "ULL_SUFFIX" },
        [2][]const u8{ "uLL_SUFFIX(X) (X ## uLL)", "ULL_SUFFIX" },
        [2][]const u8{ "Ull_SUFFIX(X) (X ## Ull)", "ULL_SUFFIX" },
        [2][]const u8{ "ULL_SUFFIX(X) (X ## ULL)", "ULL_SUFFIX" },

        [2][]const u8{ "f_SUFFIX(X) X ## f", "F_SUFFIX" },
        [2][]const u8{ "F_SUFFIX(X) X ## F", "F_SUFFIX" },

        [2][]const u8{ "u_SUFFIX(X) X ## u", "U_SUFFIX" },
        [2][]const u8{ "U_SUFFIX(X) X ## U", "U_SUFFIX" },

        [2][]const u8{ "l_SUFFIX(X) X ## l", "L_SUFFIX" },
        [2][]const u8{ "L_SUFFIX(X) X ## L", "L_SUFFIX" },

        [2][]const u8{ "ul_SUFFIX(X) X ## ul", "UL_SUFFIX" },
        [2][]const u8{ "uL_SUFFIX(X) X ## uL", "UL_SUFFIX" },
        [2][]const u8{ "Ul_SUFFIX(X) X ## Ul", "UL_SUFFIX" },
        [2][]const u8{ "UL_SUFFIX(X) X ## UL", "UL_SUFFIX" },

        [2][]const u8{ "ll_SUFFIX(X) X ## ll", "LL_SUFFIX" },
        [2][]const u8{ "LL_SUFFIX(X) X ## LL", "LL_SUFFIX" },

        [2][]const u8{ "ull_SUFFIX(X) X ## ull", "ULL_SUFFIX" },
        [2][]const u8{ "uLL_SUFFIX(X) X ## uLL", "ULL_SUFFIX" },
        [2][]const u8{ "Ull_SUFFIX(X) X ## Ull", "ULL_SUFFIX" },
        [2][]const u8{ "ULL_SUFFIX(X) X ## ULL", "ULL_SUFFIX" },

        [2][]const u8{ "CAST_OR_CALL(X, Y) (X)(Y)", "CAST_OR_CALL" },
        [2][]const u8{ "CAST_OR_CALL(X, Y) ((X)(Y))", "CAST_OR_CALL" },

        [2][]const u8{
            \\wl_container_of(ptr, sample, member)                     \
            \\(__typeof__(sample))((char *)(ptr) -                     \
            \\     offsetof(__typeof__(*sample), member))
            ,
            "WL_CONTAINER_OF",
        },

        [2][]const u8{ "IGNORE_ME(X) ((void)(X))", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) (void)(X)", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) ((const void)(X))", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) (const void)(X)", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) ((volatile void)(X))", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) (volatile void)(X)", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) ((const volatile void)(X))", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) (const volatile void)(X)", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) ((volatile const void)(X))", "DISCARD" },
        [2][]const u8{ "IGNORE_ME(X) (volatile const void)(X)", "DISCARD" },
    };

    /// Assumes that `ms` represents a tokenized function-like macro.
    fn buildArgsHash(allocator: mem.Allocator, ms: MacroSlicer, hash: *ArgsPositionMap) MacroProcessingError!void {
        assert(ms.tokens.len > 2);
        assert(ms.tokens[0].id == .identifier or ms.tokens[0].id == .extended_identifier);
        assert(ms.tokens[1].id == .l_paren);

        var i: usize = 2;
        while (true) : (i += 1) {
            const token = ms.tokens[i];
            switch (token.id) {
                .r_paren => break,
                .comma => continue,
                .identifier, .extended_identifier => {
                    const identifier = ms.slice(token);
                    try hash.put(allocator, identifier, i);
                },
                else => return error.UnexpectedMacroToken,
            }
        }
    }

    const Pattern = struct {
        tokens: []const CToken,
        source: []const u8,
        impl: []const u8,
        args_hash: ArgsPositionMap,

        fn init(self: *Pattern, allocator: mem.Allocator, template: [2][]const u8) Error!void {
            const source = template[0];
            const impl = template[1];

            var tok_list = std.ArrayList(CToken).init(allocator);
            defer tok_list.deinit();
            try tokenizeMacro(source, &tok_list);
            const tokens = try allocator.dupe(CToken, tok_list.items);

            self.* = .{
                .tokens = tokens,
                .source = source,
                .impl = impl,
                .args_hash = .{},
            };
            const ms = MacroSlicer{ .source = source, .tokens = tokens };
            buildArgsHash(allocator, ms, &self.args_hash) catch |err| switch (err) {
                error.UnexpectedMacroToken => unreachable,
                else => |e| return e,
            };
        }

        fn deinit(self: *Pattern, allocator: mem.Allocator) void {
            self.args_hash.deinit(allocator);
            allocator.free(self.tokens);
        }

        /// This function assumes that `ms` has already been validated to contain a function-like
        /// macro, and that the parsed template macro in `self` also contains a function-like
        /// macro. Please review this logic carefully if changing that assumption. Two
        /// function-like macros are considered equivalent if and only if they contain the same
        /// list of tokens, modulo parameter names.
        pub fn isEquivalent(self: Pattern, ms: MacroSlicer, args_hash: ArgsPositionMap) bool {
            if (self.tokens.len != ms.tokens.len) return false;
            if (args_hash.count() != self.args_hash.count()) return false;

            var i: usize = 2;
            while (self.tokens[i].id != .r_paren) : (i += 1) {}

            const pattern_slicer = MacroSlicer{ .source = self.source, .tokens = self.tokens };
            while (i < self.tokens.len) : (i += 1) {
                const pattern_token = self.tokens[i];
                const macro_token = ms.tokens[i];
                if (pattern_token.id != macro_token.id) return false;

                const pattern_bytes = pattern_slicer.slice(pattern_token);
                const macro_bytes = ms.slice(macro_token);
                switch (pattern_token.id) {
                    .identifier, .extended_identifier => {
                        const pattern_arg_index = self.args_hash.get(pattern_bytes);
                        const macro_arg_index = args_hash.get(macro_bytes);

                        if (pattern_arg_index == null and macro_arg_index == null) {
                            if (!mem.eql(u8, pattern_bytes, macro_bytes)) return false;
                        } else if (pattern_arg_index != null and macro_arg_index != null) {
                            if (pattern_arg_index.? != macro_arg_index.?) return false;
                        } else {
                            return false;
                        }
                    },
                    .string_literal, .char_literal, .pp_num => {
                        if (!mem.eql(u8, pattern_bytes, macro_bytes)) return false;
                    },
                    else => {
                        // other tags correspond to keywords and operators that do not contain a "payload"
                        // that can vary
                    },
                }
            }
            return true;
        }
    };

    pub fn init(allocator: mem.Allocator) Error!PatternList {
        const patterns = try allocator.alloc(Pattern, templates.len);
        for (templates, 0..) |template, i| {
            try patterns[i].init(allocator, template);
        }
        return PatternList{ .patterns = patterns };
    }

    pub fn deinit(self: *PatternList, allocator: mem.Allocator) void {
        for (self.patterns) |*pattern| pattern.deinit(allocator);
        allocator.free(self.patterns);
    }

    pub fn match(self: PatternList, allocator: mem.Allocator, ms: MacroSlicer) Error!?Pattern {
        var args_hash: ArgsPositionMap = .{};
        defer args_hash.deinit(allocator);

        buildArgsHash(allocator, ms, &args_hash) catch |err| switch (err) {
            error.UnexpectedMacroToken => return null,
            else => |e| return e,
        };

        for (self.patterns) |pattern| if (pattern.isEquivalent(ms, args_hash)) return pattern;
        return null;
    }
};

pub const MacroSlicer = struct {
    source: []const u8,
    tokens: []const CToken,

    pub fn slice(self: MacroSlicer, token: CToken) []const u8 {
        return self.source[token.start..token.end];
    }
};

// Maps macro parameter names to token position, for determining if different
// identifiers refer to the same positional argument in different macros.
pub const ArgsPositionMap = std.StringArrayHashMapUnmanaged(usize);

pub const Error = std.mem.Allocator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};
pub const TypeError = Error || error{UnsupportedType};
pub const TransError = TypeError || error{UnsupportedTranslation};

pub const SymbolTable = std.StringArrayHashMap(ast.Node);
pub const AliasList = std.ArrayList(struct {
    alias: []const u8,
    name: []const u8,
});

pub const ResultUsed = enum {
    used,
    unused,
};

pub fn ScopeExtra(comptime ScopeExtraContext: type, comptime ScopeExtraType: type) type {
    return struct {
        id: Id,
        parent: ?*ScopeExtraScope,

        const ScopeExtraScope = @This();

        pub const Id = enum {
            block,
            root,
            condition,
            loop,
            do_loop,
        };

        /// Used for the scope of condition expressions, for example `if (cond)`.
        /// The block is lazily initialised because it is only needed for rare
        /// cases of comma operators being used.
        pub const Condition = struct {
            base: ScopeExtraScope,
            block: ?Block = null,

            pub fn getBlockScope(self: *Condition, c: *ScopeExtraContext) !*Block {
                if (self.block) |*b| return b;
                self.block = try Block.init(c, &self.base, true);
                return &self.block.?;
            }

            pub fn deinit(self: *Condition) void {
                if (self.block) |*b| b.deinit();
            }
        };

        /// Represents an in-progress Node.Block. This struct is stack-allocated.
        /// When it is deinitialized, it produces an Node.Block which is allocated
        /// into the main arena.
        pub const Block = struct {
            base: ScopeExtraScope,
            statements: std.ArrayList(ast.Node),
            variables: AliasList,
            mangle_count: u32 = 0,
            label: ?[]const u8 = null,

            /// By default all variables are discarded, since we do not know in advance if they
            /// will be used. This maps the variable's name to the Discard payload, so that if
            /// the variable is subsequently referenced we can indicate that the discard should
            /// be skipped during the intermediate AST -> Zig AST render step.
            variable_discards: std.StringArrayHashMap(*ast.Payload.Discard),

            /// When the block corresponds to a function, keep track of the return type
            /// so that the return expression can be cast, if necessary
            return_type: ?ScopeExtraType = null,

            /// C static local variables are wrapped in a block-local struct. The struct
            /// is named after the (mangled) variable name, the Zig variable within the
            /// struct itself is given this name.
            pub const static_inner_name = "static";

            /// C extern variables declared within a block are wrapped in a block-local
            /// struct. The struct is named ExternLocal_[variable_name], the Zig variable
            /// within the struct itself is [variable_name] by neccessity since it's an
            /// extern reference to an existing symbol.
            pub const extern_inner_prepend = "ExternLocal";

            pub fn init(c: *ScopeExtraContext, parent: *ScopeExtraScope, labeled: bool) !Block {
                var blk = Block{
                    .base = .{
                        .id = .block,
                        .parent = parent,
                    },
                    .statements = std.ArrayList(ast.Node).init(c.gpa),
                    .variables = AliasList.init(c.gpa),
                    .variable_discards = std.StringArrayHashMap(*ast.Payload.Discard).init(c.gpa),
                };
                if (labeled) {
                    blk.label = try blk.makeMangledName(c, "blk");
                }
                return blk;
            }

            pub fn deinit(self: *Block) void {
                self.statements.deinit();
                self.variables.deinit();
                self.variable_discards.deinit();
                self.* = undefined;
            }

            pub fn complete(self: *Block, c: *ScopeExtraContext) !ast.Node {
                if (self.base.parent.?.id == .do_loop) {
                    // We reserve 1 extra statement if the parent is a do_loop. This is in case of
                    // do while, we want to put `if (cond) break;` at the end.
                    const alloc_len = self.statements.items.len + @intFromBool(self.base.parent.?.id == .do_loop);
                    var stmts = try c.arena.alloc(ast.Node, alloc_len);
                    stmts.len = self.statements.items.len;
                    @memcpy(stmts[0..self.statements.items.len], self.statements.items);
                    return ast.Node.Tag.block.create(c.arena, .{
                        .label = self.label,
                        .stmts = stmts,
                    });
                }
                if (self.statements.items.len == 0) return ast.Node.Tag.empty_block.init();
                return ast.Node.Tag.block.create(c.arena, .{
                    .label = self.label,
                    .stmts = try c.arena.dupe(ast.Node, self.statements.items),
                });
            }

            /// Given the desired name, return a name that does not shadow anything from outer scopes.
            /// Inserts the returned name into the scope.
            /// The name will not be visible to callers of getAlias.
            pub fn reserveMangledName(scope: *Block, c: *ScopeExtraContext, name: []const u8) ![]const u8 {
                return scope.createMangledName(c, name, true);
            }

            /// Same as reserveMangledName, but enables the alias immediately.
            pub fn makeMangledName(scope: *Block, c: *ScopeExtraContext, name: []const u8) ![]const u8 {
                return scope.createMangledName(c, name, false);
            }

            pub fn createMangledName(scope: *Block, c: *ScopeExtraContext, name: []const u8, reservation: bool) ![]const u8 {
                const name_copy = try c.arena.dupe(u8, name);
                var proposed_name = name_copy;
                while (scope.contains(proposed_name)) {
                    scope.mangle_count += 1;
                    proposed_name = try std.fmt.allocPrint(c.arena, "{s}_{d}", .{ name, scope.mangle_count });
                }
                const new_mangle = try scope.variables.addOne();
                if (reservation) {
                    new_mangle.* = .{ .name = name_copy, .alias = name_copy };
                } else {
                    new_mangle.* = .{ .name = name_copy, .alias = proposed_name };
                }
                return proposed_name;
            }

            pub fn getAlias(scope: *Block, name: []const u8) []const u8 {
                for (scope.variables.items) |p| {
                    if (std.mem.eql(u8, p.name, name))
                        return p.alias;
                }
                return scope.base.parent.?.getAlias(name);
            }

            /// Finds the (potentially) mangled struct name for a locally scoped extern variable given the original declaration name.
            ///
            /// Block scoped extern declarations translate to:
            ///     const MangledStructName = struct {extern [qualifiers] original_extern_variable_name: [type]};
            /// This finds MangledStructName given original_extern_variable_name for referencing correctly in transDeclRefExpr()
            pub fn getLocalExternAlias(scope: *Block, name: []const u8) ?[]const u8 {
                for (scope.statements.items) |node| {
                    if (node.tag() == .extern_local_var) {
                        const parent_node = node.castTag(.extern_local_var).?;
                        const init_node = parent_node.data.init.castTag(.var_decl).?;
                        if (std.mem.eql(u8, init_node.data.name, name)) {
                            return parent_node.data.name;
                        }
                    }
                }
                return null;
            }

            pub fn localContains(scope: *Block, name: []const u8) bool {
                for (scope.variables.items) |p| {
                    if (std.mem.eql(u8, p.alias, name))
                        return true;
                }
                return false;
            }

            pub fn contains(scope: *Block, name: []const u8) bool {
                if (scope.localContains(name))
                    return true;
                return scope.base.parent.?.contains(name);
            }

            pub fn discardVariable(scope: *Block, c: *ScopeExtraContext, name: []const u8) Error!void {
                const name_node = try ast.Node.Tag.identifier.create(c.arena, name);
                const discard = try ast.Node.Tag.discard.create(c.arena, .{ .should_skip = false, .value = name_node });
                try scope.statements.append(discard);
                try scope.variable_discards.putNoClobber(name, discard.castTag(.discard).?);
            }
        };

        pub const Root = struct {
            base: ScopeExtraScope,
            sym_table: SymbolTable,
            blank_macros: std.StringArrayHashMap(void),
            context: *ScopeExtraContext,
            nodes: std.ArrayList(ast.Node),

            pub fn init(c: *ScopeExtraContext) Root {
                return .{
                    .base = .{
                        .id = .root,
                        .parent = null,
                    },
                    .sym_table = SymbolTable.init(c.gpa),
                    .blank_macros = std.StringArrayHashMap(void).init(c.gpa),
                    .context = c,
                    .nodes = std.ArrayList(ast.Node).init(c.gpa),
                };
            }

            pub fn deinit(scope: *Root) void {
                scope.sym_table.deinit();
                scope.blank_macros.deinit();
                scope.nodes.deinit();
            }

            /// Check if the global scope contains this name, without looking into the "future", e.g.
            /// ignore the preprocessed decl and macro names.
            pub fn containsNow(scope: *Root, name: []const u8) bool {
                return scope.sym_table.contains(name);
            }

            /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
            pub fn contains(scope: *Root, name: []const u8) bool {
                return scope.containsNow(name) or scope.context.global_names.contains(name) or scope.context.weak_global_names.contains(name);
            }
        };

        pub fn findBlockScope(inner: *ScopeExtraScope, c: *ScopeExtraContext) !*Block {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => unreachable,
                    .block => return @fieldParentPtr("base", scope),
                    .condition => return @as(*Condition, @fieldParentPtr("base", scope)).getBlockScope(c),
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn findBlockReturnType(inner: *ScopeExtraScope) ScopeExtraType {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => unreachable,
                    .block => {
                        const block: *Block = @fieldParentPtr("base", scope);
                        if (block.return_type) |ty| return ty;
                        scope = scope.parent.?;
                    },
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn getAlias(scope: *ScopeExtraScope, name: []const u8) []const u8 {
            return switch (scope.id) {
                .root => name,
                .block => @as(*Block, @fieldParentPtr("base", scope)).getAlias(name),
                .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
            };
        }

        pub fn getLocalExternAlias(scope: *ScopeExtraScope, name: []const u8) ?[]const u8 {
            return switch (scope.id) {
                .root => null,
                .block => ret: {
                    const block = @as(*Block, @fieldParentPtr("base", scope));
                    break :ret block.getLocalExternAlias(name);
                },
                .loop, .do_loop, .condition => scope.parent.?.getLocalExternAlias(name),
            };
        }

        pub fn contains(scope: *ScopeExtraScope, name: []const u8) bool {
            return switch (scope.id) {
                .root => @as(*Root, @fieldParentPtr("base", scope)).contains(name),
                .block => @as(*Block, @fieldParentPtr("base", scope)).contains(name),
                .loop, .do_loop, .condition => scope.parent.?.contains(name),
            };
        }

        pub fn getBreakableScope(inner: *ScopeExtraScope) *ScopeExtraScope {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => unreachable,
                    .loop, .do_loop => return scope,
                    else => scope = scope.parent.?,
                }
            }
        }

        /// Appends a node to the first block scope if inside a function, or to the root tree if not.
        pub fn appendNode(inner: *ScopeExtraScope, node: ast.Node) !void {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => {
                        const root: *Root = @fieldParentPtr("base", scope);
                        return root.nodes.append(node);
                    },
                    .block => {
                        const block: *Block = @fieldParentPtr("base", scope);
                        return block.statements.append(node);
                    },
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn skipVariableDiscard(inner: *ScopeExtraScope, name: []const u8) void {
            if (true) {
                // TODO: due to 'local variable is never mutated' errors, we can
                // only skip discards if a variable is used as an lvalue, which
                // we don't currently have detection for in translate-c.
                // Once #17584 is completed, perhaps we can do away with this
                // logic entirely, and instead rely on render to fixup code.
                return;
            }
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => return,
                    .block => {
                        const block: *Block = @fieldParentPtr("base", scope);
                        if (block.variable_discards.get(name)) |discard| {
                            discard.data.should_skip = true;
                            return;
                        }
                    },
                    else => {},
                }
                scope = scope.parent.?;
            }
        }
    };
}

pub fn tokenizeMacro(source: []const u8, tok_list: *std.ArrayList(CToken)) Error!void {
    var tokenizer: Tokenizer = .{
        .buf = source,
        .source = .unused,
        .langopts = .{},
    };
    while (true) {
        const tok = tokenizer.next();
        switch (tok.id) {
            .whitespace => continue,
            .nl, .eof => {
                try tok_list.append(tok);
                break;
            },
            else => {},
        }
        try tok_list.append(tok);
    }
}
