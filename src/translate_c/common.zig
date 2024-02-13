const std = @import("std");
const ast = @import("ast.zig");
const Node = ast.Node;
const Tag = Node.Tag;

const CallingConvention = std.builtin.CallingConvention;

pub const Error = std.mem.Allocator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};
pub const TypeError = Error || error{UnsupportedType};
pub const TransError = TypeError || error{UnsupportedTranslation};

pub const SymbolTable = std.StringArrayHashMap(Node);
pub const AliasList = std.ArrayList(struct {
    alias: []const u8,
    name: []const u8,
});

pub const ResultUsed = enum {
    used,
    unused,
};

pub fn ScopeExtra(comptime Context: type, comptime Type: type) type {
    return struct {
        id: Id,
        parent: ?*Scope,

        const Scope = @This();

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
            base: Scope,
            block: ?Block = null,

            pub fn getBlockScope(self: *Condition, c: *Context) !*Block {
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
            base: Scope,
            statements: std.ArrayList(Node),
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
            return_type: ?Type = null,

            /// C static local variables are wrapped in a block-local struct. The struct
            /// is named after the (mangled) variable name, the Zig variable within the
            /// struct itself is given this name.
            pub const static_inner_name = "static";

            pub fn init(c: *Context, parent: *Scope, labeled: bool) !Block {
                var blk = Block{
                    .base = .{
                        .id = .block,
                        .parent = parent,
                    },
                    .statements = std.ArrayList(Node).init(c.gpa),
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

            pub fn complete(self: *Block, c: *Context) !Node {
                if (self.base.parent.?.id == .do_loop) {
                    // We reserve 1 extra statement if the parent is a do_loop. This is in case of
                    // do while, we want to put `if (cond) break;` at the end.
                    const alloc_len = self.statements.items.len + @intFromBool(self.base.parent.?.id == .do_loop);
                    var stmts = try c.arena.alloc(Node, alloc_len);
                    stmts.len = self.statements.items.len;
                    @memcpy(stmts[0..self.statements.items.len], self.statements.items);
                    return Tag.block.create(c.arena, .{
                        .label = self.label,
                        .stmts = stmts,
                    });
                }
                if (self.statements.items.len == 0) return Tag.empty_block.init();
                return Tag.block.create(c.arena, .{
                    .label = self.label,
                    .stmts = try c.arena.dupe(Node, self.statements.items),
                });
            }

            /// Given the desired name, return a name that does not shadow anything from outer scopes.
            /// Inserts the returned name into the scope.
            /// The name will not be visible to callers of getAlias.
            pub fn reserveMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
                return scope.createMangledName(c, name, true);
            }

            /// Same as reserveMangledName, but enables the alias immediately.
            pub fn makeMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
                return scope.createMangledName(c, name, false);
            }

            pub fn createMangledName(scope: *Block, c: *Context, name: []const u8, reservation: bool) ![]const u8 {
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

            pub fn discardVariable(scope: *Block, c: *Context, name: []const u8) Error!void {
                const name_node = try Tag.identifier.create(c.arena, name);
                const discard = try Tag.discard.create(c.arena, .{ .should_skip = false, .value = name_node });
                try scope.statements.append(discard);
                try scope.variable_discards.putNoClobber(name, discard.castTag(.discard).?);
            }
        };

        pub const Root = struct {
            base: Scope,
            sym_table: SymbolTable,
            macro_table: SymbolTable,
            blank_macros: std.StringArrayHashMap(void),
            context: *Context,
            nodes: std.ArrayList(Node),

            pub fn init(c: *Context) Root {
                return .{
                    .base = .{
                        .id = .root,
                        .parent = null,
                    },
                    .sym_table = SymbolTable.init(c.gpa),
                    .macro_table = SymbolTable.init(c.gpa),
                    .blank_macros = std.StringArrayHashMap(void).init(c.gpa),
                    .context = c,
                    .nodes = std.ArrayList(Node).init(c.gpa),
                };
            }

            pub fn deinit(scope: *Root) void {
                scope.sym_table.deinit();
                scope.macro_table.deinit();
                scope.blank_macros.deinit();
                scope.nodes.deinit();
            }

            /// Check if the global scope contains this name, without looking into the "future", e.g.
            /// ignore the preprocessed decl and macro names.
            pub fn containsNow(scope: *Root, name: []const u8) bool {
                return scope.sym_table.contains(name) or scope.macro_table.contains(name);
            }

            /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
            pub fn contains(scope: *Root, name: []const u8) bool {
                return scope.containsNow(name) or scope.context.global_names.contains(name) or scope.context.weak_global_names.contains(name);
            }
        };

        pub fn findBlockScope(inner: *Scope, c: *Context) !*Scope.Block {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => unreachable,
                    .block => return @fieldParentPtr(Block, "base", scope),
                    .condition => return @fieldParentPtr(Condition, "base", scope).getBlockScope(c),
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn findBlockReturnType(inner: *Scope) Type {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => unreachable,
                    .block => {
                        const block = @fieldParentPtr(Block, "base", scope);
                        if (block.return_type) |ty| return ty;
                        scope = scope.parent.?;
                    },
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn getAlias(scope: *Scope, name: []const u8) []const u8 {
            return switch (scope.id) {
                .root => return name,
                .block => @fieldParentPtr(Block, "base", scope).getAlias(name),
                .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
            };
        }

        pub fn contains(scope: *Scope, name: []const u8) bool {
            return switch (scope.id) {
                .root => @fieldParentPtr(Root, "base", scope).contains(name),
                .block => @fieldParentPtr(Block, "base", scope).contains(name),
                .loop, .do_loop, .condition => scope.parent.?.contains(name),
            };
        }

        pub fn getBreakableScope(inner: *Scope) *Scope {
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
        pub fn appendNode(inner: *Scope, node: Node) !void {
            var scope = inner;
            while (true) {
                switch (scope.id) {
                    .root => {
                        const root = @fieldParentPtr(Root, "base", scope);
                        return root.nodes.append(node);
                    },
                    .block => {
                        const block = @fieldParentPtr(Block, "base", scope);
                        return block.statements.append(node);
                    },
                    else => scope = scope.parent.?,
                }
            }
        }

        pub fn skipVariableDiscard(inner: *Scope, name: []const u8) void {
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
                        const block = @fieldParentPtr(Block, "base", scope);
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
