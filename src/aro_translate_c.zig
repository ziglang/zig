const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const translate_c = @import("translate_c.zig");
const aro = @import("aro");
const Tree = aro.Tree;
const NodeIndex = Tree.NodeIndex;
const TokenIndex = Tree.TokenIndex;
const Type = aro.Type;
const ast = @import("translate_c/ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;

const Error = mem.Allocator.Error;
const TransError = translate_c.TransError;
const TypeError = translate_c.TypeError;
const ResultUsed = translate_c.ResultUsed;
const AliasList = translate_c.AliasList;
const SymbolTable = translate_c.SymbolTable;
pub const Compilation = aro.Compilation;

const Scope = struct {
    id: Id,
    parent: ?*Scope,

    const Id = enum {
        block,
        root,
        condition,
        loop,
        do_loop,
    };

    /// Used for the scope of condition expressions, for example `if (cond)`.
    /// The block is lazily initialised because it is only needed for rare
    /// cases of comma operators being used.
    const Condition = struct {
        base: Scope,
        block: ?Block = null,

        fn getBlockScope(self: *Condition, c: *Context) !*Block {
            if (self.block) |*b| return b;
            self.block = try Block.init(c, &self.base, true);
            return &self.block.?;
        }

        fn deinit(self: *Condition) void {
            if (self.block) |*b| b.deinit();
        }
    };

    /// Represents an in-progress ZigNode.Block. This struct is stack-allocated.
    /// When it is deinitialized, it produces an ZigNode.Block which is allocated
    /// into the main arena.
    const Block = struct {
        base: Scope,
        statements: std.ArrayList(ZigNode),
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
        const StaticInnerName = "static";

        fn init(c: *Context, parent: *Scope, labeled: bool) !Block {
            var blk = Block{
                .base = .{
                    .id = .block,
                    .parent = parent,
                },
                .statements = std.ArrayList(ZigNode).init(c.gpa),
                .variables = AliasList.init(c.gpa),
                .variable_discards = std.StringArrayHashMap(*ast.Payload.Discard).init(c.gpa),
            };
            if (labeled) {
                blk.label = try blk.makeMangledName(c, "blk");
            }
            return blk;
        }

        fn deinit(self: *Block) void {
            self.statements.deinit();
            self.variables.deinit();
            self.variable_discards.deinit();
            self.* = undefined;
        }

        fn complete(self: *Block, c: *Context) !ZigNode {
            if (self.base.parent.?.id == .do_loop) {
                // We reserve 1 extra statement if the parent is a do_loop. This is in case of
                // do while, we want to put `if (cond) break;` at the end.
                const alloc_len = self.statements.items.len + @boolToInt(self.base.parent.?.id == .do_loop);
                var stmts = try c.arena.alloc(ZigNode, alloc_len);
                stmts.len = self.statements.items.len;
                @memcpy(stmts[0..self.statements.items.len], self.statements.items);
                return ZigTag.block.create(c.arena, .{
                    .label = self.label,
                    .stmts = stmts,
                });
            }
            if (self.statements.items.len == 0) return ZigTag.empty_block.init();
            return ZigTag.block.create(c.arena, .{
                .label = self.label,
                .stmts = try c.arena.dupe(ZigNode, self.statements.items),
            });
        }

        /// Given the desired name, return a name that does not shadow anything from outer scopes.
        /// Inserts the returned name into the scope.
        /// The name will not be visible to callers of getAlias.
        fn reserveMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
            return scope.createMangledName(c, name, true);
        }

        /// Same as reserveMangledName, but enables the alias immediately.
        fn makeMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
            return scope.createMangledName(c, name, false);
        }

        fn createMangledName(scope: *Block, c: *Context, name: []const u8, reservation: bool) ![]const u8 {
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

        fn getAlias(scope: *Block, name: []const u8) []const u8 {
            for (scope.variables.items) |p| {
                if (mem.eql(u8, p.name, name))
                    return p.alias;
            }
            return scope.base.parent.?.getAlias(name);
        }

        fn localContains(scope: *Block, name: []const u8) bool {
            for (scope.variables.items) |p| {
                if (mem.eql(u8, p.alias, name))
                    return true;
            }
            return false;
        }

        fn contains(scope: *Block, name: []const u8) bool {
            if (scope.localContains(name))
                return true;
            return scope.base.parent.?.contains(name);
        }

        fn discardVariable(scope: *Block, c: *Context, name: []const u8) Error!void {
            const name_node = try ZigTag.identifier.create(c.arena, name);
            const discard = try ZigTag.discard.create(c.arena, .{ .should_skip = false, .value = name_node });
            try scope.statements.append(discard);
            try scope.variable_discards.putNoClobber(name, discard.castTag(.discard).?);
        }
    };

    const Root = struct {
        base: Scope,
        sym_table: SymbolTable,
        macro_table: SymbolTable,
        context: *Context,
        nodes: std.ArrayList(ZigNode),

        fn init(c: *Context) Root {
            return .{
                .base = .{
                    .id = .root,
                    .parent = null,
                },
                .sym_table = SymbolTable.init(c.gpa),
                .macro_table = SymbolTable.init(c.gpa),
                .context = c,
                .nodes = std.ArrayList(ZigNode).init(c.gpa),
            };
        }

        fn deinit(scope: *Root) void {
            scope.sym_table.deinit();
            scope.macro_table.deinit();
            scope.nodes.deinit();
        }

        /// Check if the global scope contains this name, without looking into the "future", e.g.
        /// ignore the preprocessed decl and macro names.
        fn containsNow(scope: *Root, name: []const u8) bool {
            return scope.sym_table.contains(name) or scope.macro_table.contains(name);
        }

        /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
        fn contains(scope: *Root, name: []const u8) bool {
            return scope.containsNow(name) or scope.context.global_names.contains(name);
        }
    };

    fn findBlockScope(inner: *Scope, c: *Context) !*Scope.Block {
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

    fn findBlockReturnType(inner: *Scope) Type {
        var scope = inner;
        while (true) {
            switch (scope.id) {
                .root => unreachable,
                .block => {
                    const block = @fieldParentPtr(Block, "base", scope);
                    if (block.return_type) |qt| return qt;
                    scope = scope.parent.?;
                },
                else => scope = scope.parent.?,
            }
        }
    }

    fn getAlias(scope: *Scope, name: []const u8) []const u8 {
        return switch (scope.id) {
            .root => return name,
            .block => @fieldParentPtr(Block, "base", scope).getAlias(name),
            .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
        };
    }

    fn contains(scope: *Scope, name: []const u8) bool {
        return switch (scope.id) {
            .root => @fieldParentPtr(Root, "base", scope).contains(name),
            .block => @fieldParentPtr(Block, "base", scope).contains(name),
            .loop, .do_loop, .condition => scope.parent.?.contains(name),
        };
    }

    fn getBreakableScope(inner: *Scope) *Scope {
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
    fn appendNode(inner: *Scope, node: ZigNode) !void {
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

    fn skipVariableDiscard(inner: *Scope, name: []const u8) void {
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

const Context = struct {
    gpa: mem.Allocator,
    arena: mem.Allocator,
    decl_table: std.AutoArrayHashMapUnmanaged(usize, []const u8) = .{},
    alias_list: translate_c.AliasList,
    global_scope: *Scope.Root,
    mangle_count: u32 = 0,
    /// Table of record decls that have been demoted to opaques.
    opaque_demotes: std.AutoHashMapUnmanaged(usize, void) = .{},
    /// Table of unnamed enums and records that are child types of typedefs.
    unnamed_typedefs: std.AutoHashMapUnmanaged(usize, []const u8) = .{},
    /// Needed to decide if we are parsing a typename
    typedefs: std.StringArrayHashMapUnmanaged(void) = .{},

    /// This one is different than the root scope's name table. This contains
    /// a list of names that we found by visiting all the top level decls without
    /// translating them. The other maps are updated as we translate; this one is updated
    /// up front in a pre-processing step.
    global_names: std.StringArrayHashMapUnmanaged(void) = .{},

    /// This is similar to `global_names`, but contains names which we would
    /// *like* to use, but do not strictly *have* to if they are unavailable.
    /// These are relevant to types, which ideally we would name like
    /// 'struct_foo' with an alias 'foo', but if either of those names is taken,
    /// may be mangled.
    /// This is distinct from `global_names` so we can detect at a type
    /// declaration whether or not the name is available.
    weak_global_names: std.StringArrayHashMapUnmanaged(void) = .{},

    pattern_list: translate_c.PatternList,
    tree: Tree,
    comp: *Compilation,
    mapper: aro.TypeMapper,

    fn getMangle(c: *Context) u32 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: TokenIndex) ![]const u8 {
        _ = c;
        _ = loc;
        // const spelling_loc = c.source_manager.getSpellingLoc(loc);
        // const filename_c = c.source_manager.getFilename(spelling_loc);
        // const filename = if (filename_c) |s| try c.str(s) else @as([]const u8, "(no file)");

        // const line = c.source_manager.getSpellingLineNumber(spelling_loc);
        // const column = c.source_manager.getSpellingColumnNumber(spelling_loc);
        // return std.fmt.allocPrint(c.arena, "{s}:{d}:{d}", .{ filename, line, column });
        return "somewhere";
    }
};

fn maybeSuppressResult(c: *Context, used: ResultUsed, result: ZigNode) TransError!ZigNode {
    if (used == .used) return result;
    return ZigTag.discard.create(c.arena, .{ .should_skip = false, .value = result });
}

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: ZigNode) !void {
    const gop = try c.global_scope.sym_table.getOrPut(name);
    if (!gop.found_existing) {
        gop.value_ptr.* = decl_node;
        try c.global_scope.nodes.append(decl_node);
    }
}

fn failDecl(c: *Context, loc: TokenIndex, name: []const u8, comptime format: []const u8, args: anytype) Error!void {
    // location
    // pub const name = @compileError(msg);
    const fail_msg = try std.fmt.allocPrint(c.arena, format, args);
    try addTopLevelDecl(c, name, try ZigTag.fail_decl.create(c.arena, .{ .actual = name, .mangled = fail_msg }));
    const str = try c.locStr(loc);
    const location_comment = try std.fmt.allocPrint(c.arena, "// {s}", .{str});
    try c.global_scope.nodes.append(try ZigTag.warning.create(c.arena, location_comment));
}

pub fn translate(
    gpa: mem.Allocator,
    comp: *Compilation,
    args: []const []const u8,
) !std.zig.Ast {
    try comp.addDefaultPragmaHandlers();
    comp.langopts.setEmulatedCompiler(aro.target_util.systemCompiler(comp.target));

    var driver: aro.Driver = .{ .comp = comp };
    defer driver.deinit();

    var macro_buf = std.ArrayList(u8).init(gpa);
    defer macro_buf.deinit();

    assert(!try driver.parseArgs(std.io.null_writer, macro_buf.writer(), args));
    assert(driver.inputs.items.len == 1);
    const source = driver.inputs.items[0];

    const builtin = try comp.generateBuiltinMacros();
    const user_macros = try comp.addSourceFromBuffer("<command line>", macro_buf.items);

    var pp = aro.Preprocessor.init(comp);
    defer pp.deinit();

    try pp.addBuiltinMacros();

    _ = try pp.preprocess(builtin);
    _ = try pp.preprocess(user_macros);
    const eof = try pp.preprocess(source);
    try pp.tokens.append(pp.comp.gpa, eof);

    var tree = try aro.Parser.parse(&pp);
    defer tree.deinit();

    if (driver.comp.diag.errors != 0) {
        return error.SemanticAnalyzeFail;
    }

    const mapper = tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch tree.comp.string_interner.getSlowTypeMapper();
    defer mapper.deinit(tree.comp.gpa);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var context = Context{
        .gpa = gpa,
        .arena = arena,
        .alias_list = translate_c.AliasList.init(gpa),
        .global_scope = try arena.create(Scope.Root),
        .pattern_list = try translate_c.PatternList.init(gpa),
        .comp = comp,
        .mapper = mapper,
        .tree = tree,
    };
    context.global_scope.* = Scope.Root.init(&context);
    defer {
        context.decl_table.deinit(gpa);
        context.alias_list.deinit();
        context.global_names.deinit(gpa);
        context.opaque_demotes.deinit(gpa);
        context.unnamed_typedefs.deinit(gpa);
        context.typedefs.deinit(gpa);
        context.global_scope.deinit();
        context.pattern_list.deinit(gpa);
    }

    inline for (@typeInfo(std.zig.c_builtins).Struct.decls) |decl| {
        const builtin_fn = try ZigTag.pub_var_simple.create(arena, .{
            .name = decl.name,
            .init = try ZigTag.import_c_builtin.create(arena, decl.name),
        });
        try addTopLevelDecl(&context, decl.name, builtin_fn);
    }

    try prepopulateGlobalNameTable(&context);
    try transTopLevelDecls(&context);

    for (context.alias_list.items) |alias| {
        if (!context.global_scope.sym_table.contains(alias.alias)) {
            const node = try ZigTag.alias.create(arena, .{ .actual = alias.alias, .mangled = alias.name });
            try addTopLevelDecl(&context, alias.alias, node);
        }
    }

    return ast.render(gpa, context.global_scope.nodes.items);
}

fn prepopulateGlobalNameTable(c: *Context) !void {
    const node_tags = c.tree.nodes.items(.tag);
    const node_types = c.tree.nodes.items(.ty);
    const node_data = c.tree.nodes.items(.data);
    for (c.tree.root_decls) |node| {
        const data = node_data[@enumToInt(node)];
        const decl_name = switch (node_tags[@enumToInt(node)]) {
            .typedef => @panic("TODO"),

            .static_assert,
            .struct_decl_two,
            .union_decl_two,
            .struct_decl,
            .union_decl,
            => blk: {
                const ty = node_types[@enumToInt(node)];
                const name_id = ty.data.record.name;
                break :blk c.mapper.lookup(name_id);
            },

            .enum_decl_two,
            .enum_decl,
            => blk: {
                const ty = node_types[@enumToInt(node)];
                const name_id = ty.data.@"enum".name;
                break :blk c.mapper.lookup(name_id);
            },

            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            .@"var",
            .static_var,
            .threadlocal_var,
            .threadlocal_static_var,
            .extern_var,
            .threadlocal_extern_var,
            => c.tree.tokSlice(data.decl.name),
            else => unreachable,
        };
        try c.global_names.put(c.gpa, decl_name, {});
    }
}

fn transTopLevelDecls(c: *Context) !void {
    const node_tags = c.tree.nodes.items(.tag);
    const node_data = c.tree.nodes.items(.data);
    for (c.tree.root_decls) |node| {
        const data = node_data[@enumToInt(node)];
        switch (node_tags[@enumToInt(node)]) {
            .typedef => {
                try transTypeDef(c, &c.global_scope.base, node);
            },

            .static_assert,
            .struct_decl_two,
            .union_decl_two,
            .struct_decl,
            .union_decl,
            => {
                try transRecordDecl(c, &c.global_scope.base, node);
            },

            .enum_decl_two,
            => {
                var fields = [2]NodeIndex{ data.bin.lhs, data.bin.rhs };
                var field_count: u8 = 0;
                if (fields[0] != .none) field_count += 1;
                if (fields[1] != .none) field_count += 1;
                try transEnumDecl(c, &c.global_scope.base, node, fields[0..field_count]);
            },
            .enum_decl,
            => {
                const fields = c.tree.data[data.range.start..data.range.end];
                try transEnumDecl(c, &c.global_scope.base, node, fields);
            },

            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            => {
                try transFnDecl(c, node);
            },

            .@"var",
            .static_var,
            .threadlocal_var,
            .threadlocal_static_var,
            .extern_var,
            .threadlocal_extern_var,
            => {
                try transVarDecl(c, node, null);
            },
            else => unreachable,
        }
    }
}

fn transTypeDef(_: *Context, _: *Scope, _: NodeIndex) Error!void {
    @panic("TODO");
}
fn transRecordDecl(_: *Context, _: *Scope, _: NodeIndex) Error!void {
    @panic("TODO");
}
fn transFnDecl(_: *Context, _: NodeIndex) Error!void {
    @panic("TODO");
}
fn transVarDecl(_: *Context, _: NodeIndex, _: ?usize) Error!void {
    @panic("TODO");
}
fn transEnumDecl(c: *Context, scope: *Scope, enum_decl: NodeIndex, field_nodes: []const NodeIndex) Error!void {
    const node_types = c.tree.nodes.items(.ty);
    const ty = node_types[@enumToInt(enum_decl)];
    const node_data = c.tree.nodes.items(.data);
    if (c.decl_table.get(@ptrToInt(ty.data.@"enum"))) |_|
        return; // Avoid processing this decl twice
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(c) else undefined;

    var is_unnamed = false;
    var bare_name: []const u8 = c.mapper.lookup(ty.data.@"enum".name);
    var name = bare_name;
    if (c.unnamed_typedefs.get(@ptrToInt(ty.data.@"enum"))) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (bare_name.len == 0) {
            bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{d}", .{c.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(c.arena, "enum_{s}", .{bare_name});
    }
    if (!toplevel) name = try bs.makeMangledName(c, name);
    try c.decl_table.putNoClobber(c.gpa, @ptrToInt(ty.data.@"enum"), name);

    const enum_type_node = if (!ty.data.@"enum".isIncomplete()) blk: {
        for (ty.data.@"enum".fields, field_nodes) |field, field_node| {
            var enum_val_name: []const u8 = c.mapper.lookup(field.name);
            if (!toplevel) {
                enum_val_name = try bs.makeMangledName(c, enum_val_name);
            }

            const enum_const_type_node: ?ZigNode = transType(c, scope, field.ty, field.name_tok) catch |err| switch (err) {
                error.UnsupportedType => null,
                else => |e| return e,
            };

            const enum_const_def = try ZigTag.enum_constant.create(c.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = transExpr(c, node_data[@enumToInt(field_node)].decl.node, .used) catch @panic("TODO"),
            });
            if (toplevel)
                try addTopLevelDecl(c, enum_val_name, enum_const_def)
            else {
                try scope.appendNode(enum_const_def);
                try bs.discardVariable(c, enum_val_name);
            }
        }

        break :blk transType(c, scope, ty.data.@"enum".tag_ty, 0) catch |err| switch (err) {
            error.UnsupportedType => {
                return failDecl(c, 0, name, "unable to translate enum integer type", .{});
            },
            else => |e| return e,
        };
    } else blk: {
        try c.opaque_demotes.put(c.gpa, @ptrToInt(ty.data.@"enum"), {});
        break :blk ZigTag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try c.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]ZigTag{ .var_simple, .pub_var_simple })[@boolToInt(is_pub)] },
        .data = .{
            .init = enum_type_node,
            .name = name,
        },
    };
    const node = ZigNode.initPayload(&payload.base);
    if (toplevel) {
        try addTopLevelDecl(c, name, node);
        if (!is_unnamed)
            try c.alias_list.append(.{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(c, name);
        }
    }
}

fn transType(c: *Context, scope: *Scope, raw_ty: Type, source_loc: TokenIndex) TypeError!ZigNode {
    _ = source_loc;
    _ = scope;
    const ty = raw_ty.canonicalize(.standard);
    switch (ty.specifier) {
        .void => return ZigTag.type.create(c.arena, "anyopaque"),
        .bool => return ZigTag.type.create(c.arena, "bool"),
        .char => return ZigTag.type.create(c.arena, "c_char"),
        .schar => return ZigTag.type.create(c.arena, "i8"),
        .uchar => return ZigTag.type.create(c.arena, "u8"),
        .short => return ZigTag.type.create(c.arena, "c_short"),
        .ushort => return ZigTag.type.create(c.arena, "c_ushort"),
        .int => return ZigTag.type.create(c.arena, "c_int"),
        .uint => return ZigTag.type.create(c.arena, "c_uint"),
        .long => return ZigTag.type.create(c.arena, "c_long"),
        .ulong => return ZigTag.type.create(c.arena, "c_ulong"),
        .long_long => return ZigTag.type.create(c.arena, "c_longlong"),
        .ulong_long => return ZigTag.type.create(c.arena, "c_ulonglong"),
        .int128 => return ZigTag.type.create(c.arena, "i128"),
        .uint128 => return ZigTag.type.create(c.arena, "u128"),
        .fp16, .float16 => return ZigTag.type.create(c.arena, "f16"),
        .float => return ZigTag.type.create(c.arena, "f32"),
        .double => return ZigTag.type.create(c.arena, "f64"),
        .long_double => return ZigTag.type.create(c.arena, "c_longdouble"),
        .float80 => return ZigTag.type.create(c.arena, "f80"),
        .float128 => return ZigTag.type.create(c.arena, "f128"),
        else => @panic("TODO"),
    }
}

fn transStmt(c: *Context, node: NodeIndex) TransError!void {
    _ = try c.transExpr(node, .unused);
}

fn transExpr(c: *Context, node: NodeIndex, result_used: ResultUsed) TransError!ZigNode {
    std.debug.assert(node != .none);
    const ty = c.tree.nodes.items(.ty)[@enumToInt(node)];
    if (c.tree.value_map.get(node)) |val| {
        // TODO handle other values
        const str = try std.fmt.allocPrint(c.arena, "{d}", .{val.data.int});
        const int = try ZigTag.integer_literal.create(c.arena, str);
        const as_node = try ZigTag.as.create(c.arena, .{
            .lhs = try transType(c, undefined, ty, undefined),
            .rhs = int,
        });
        return maybeSuppressResult(c, result_used, as_node);
    }
    const node_tags = c.tree.nodes.items(.tag);
    switch (node_tags[@enumToInt(node)]) {
        else => unreachable, // Not an expression.
    }
    return .none;
}
