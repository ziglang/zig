const std = @import("std");

const aro = @import("aro");

const ast = @import("ast.zig");
const Translator = @import("Translator.zig");

const Scope = @This();

pub const SymbolTable = std.StringArrayHashMapUnmanaged(ast.Node);
pub const AliasList = std.ArrayListUnmanaged(struct {
    alias: []const u8,
    name: []const u8,
});

/// Associates a container (structure or union) with its relevant member functions.
pub const ContainerMemberFns = struct {
    container_decl_ptr: *ast.Node,
    member_fns: std.ArrayListUnmanaged(*ast.Payload.Func) = .empty,
};
pub const ContainerMemberFnsHashMap = std.AutoArrayHashMapUnmanaged(aro.QualType, ContainerMemberFns);

id: Id,
parent: ?*Scope,

pub const Id = enum {
    block,
    root,
    condition,
    loop,
    do_loop,
};

/// Used for the scope of condition expressions, for example `if (cond)`.
/// The block is lazily initialized because it is only needed for rare
/// cases of comma operators being used.
pub const Condition = struct {
    base: Scope,
    block: ?Block = null,

    fn getBlockScope(cond: *Condition, t: *Translator) !*Block {
        if (cond.block) |*b| return b;
        cond.block = try Block.init(t, &cond.base, true);
        return &cond.block.?;
    }

    pub fn deinit(cond: *Condition) void {
        if (cond.block) |*b| b.deinit();
    }
};

/// Represents an in-progress Node.Block. This struct is stack-allocated.
/// When it is deinitialized, it produces an Node.Block which is allocated
/// into the main arena.
pub const Block = struct {
    base: Scope,
    translator: *Translator,
    statements: std.ArrayListUnmanaged(ast.Node),
    variables: AliasList,
    mangle_count: u32 = 0,
    label: ?[]const u8 = null,

    /// By default all variables are discarded, since we do not know in advance if they
    /// will be used. This maps the variable's name to the Discard payload, so that if
    /// the variable is subsequently referenced we can indicate that the discard should
    /// be skipped during the intermediate AST -> Zig AST render step.
    variable_discards: std.StringArrayHashMapUnmanaged(*ast.Payload.Discard),

    /// When the block corresponds to a function, keep track of the return type
    /// so that the return expression can be cast, if necessary
    return_type: ?aro.QualType = null,

    /// C static local variables are wrapped in a block-local struct. The struct
    /// is named `mangle(static_local_ + name)` and the Zig variable within the
    /// struct keeps the name of the C variable.
    pub const static_local_prefix = "static_local";

    /// C extern local variables are wrapped in a block-local struct. The struct
    /// is named `mangle(extern_local + name)` and the Zig variable within the
    /// struct keeps the name of the C variable.
    pub const extern_local_prefix = "extern_local";

    pub fn init(t: *Translator, parent: *Scope, labeled: bool) !Block {
        var blk: Block = .{
            .base = .{
                .id = .block,
                .parent = parent,
            },
            .translator = t,
            .statements = .empty,
            .variables = .empty,
            .variable_discards = .empty,
        };
        if (labeled) {
            blk.label = try blk.makeMangledName("blk");
        }
        return blk;
    }

    pub fn deinit(block: *Block) void {
        block.statements.deinit(block.translator.gpa);
        block.variables.deinit(block.translator.gpa);
        block.variable_discards.deinit(block.translator.gpa);
        block.* = undefined;
    }

    pub fn complete(block: *Block) !ast.Node {
        const arena = block.translator.arena;
        if (block.base.parent.?.id == .do_loop) {
            // We reserve 1 extra statement if the parent is a do_loop. This is in case of
            // do while, we want to put `if (cond) break;` at the end.
            const alloc_len = block.statements.items.len + @intFromBool(block.base.parent.?.id == .do_loop);
            var stmts = try arena.alloc(ast.Node, alloc_len);
            stmts.len = block.statements.items.len;
            @memcpy(stmts[0..block.statements.items.len], block.statements.items);
            return ast.Node.Tag.block.create(arena, .{
                .label = block.label,
                .stmts = stmts,
            });
        }
        if (block.statements.items.len == 0) return ast.Node.Tag.empty_block.init();
        return ast.Node.Tag.block.create(arena, .{
            .label = block.label,
            .stmts = try arena.dupe(ast.Node, block.statements.items),
        });
    }

    /// Given the desired name, return a name that does not shadow anything from outer scopes.
    /// Inserts the returned name into the scope.
    /// The name will not be visible to callers of getAlias.
    pub fn reserveMangledName(block: *Block, name: []const u8) ![]const u8 {
        return block.createMangledName(name, true, null);
    }

    /// Same as reserveMangledName, but enables the alias immediately.
    pub fn makeMangledName(block: *Block, name: []const u8) ![]const u8 {
        return block.createMangledName(name, false, null);
    }

    pub fn createMangledName(block: *Block, name: []const u8, reservation: bool, prefix_opt: ?[]const u8) ![]const u8 {
        const arena = block.translator.arena;
        const name_copy = try arena.dupe(u8, name);
        const alias_base = if (prefix_opt) |prefix|
            try std.fmt.allocPrint(arena, "{s}_{s}", .{ prefix, name })
        else
            name;
        var proposed_name = alias_base;
        while (block.contains(proposed_name)) {
            block.mangle_count += 1;
            proposed_name = try std.fmt.allocPrint(arena, "{s}_{d}", .{ alias_base, block.mangle_count });
        }
        const new_mangle = try block.variables.addOne(block.translator.gpa);
        if (reservation) {
            new_mangle.* = .{ .name = name_copy, .alias = name_copy };
        } else {
            new_mangle.* = .{ .name = name_copy, .alias = proposed_name };
        }
        return proposed_name;
    }

    fn getAlias(block: *Block, name: []const u8) ?[]const u8 {
        for (block.variables.items) |p| {
            if (std.mem.eql(u8, p.name, name))
                return p.alias;
        }
        return block.base.parent.?.getAlias(name);
    }

    fn localContains(block: *Block, name: []const u8) bool {
        for (block.variables.items) |p| {
            if (std.mem.eql(u8, p.alias, name))
                return true;
        }
        return false;
    }

    fn contains(block: *Block, name: []const u8) bool {
        if (block.localContains(name))
            return true;
        return block.base.parent.?.contains(name);
    }

    pub fn discardVariable(block: *Block, name: []const u8) Translator.Error!void {
        const gpa = block.translator.gpa;
        const arena = block.translator.arena;
        const name_node = try ast.Node.Tag.identifier.create(arena, name);
        const discard = try ast.Node.Tag.discard.create(arena, .{ .should_skip = false, .value = name_node });
        try block.statements.append(gpa, discard);
        try block.variable_discards.putNoClobber(gpa, name, discard.castTag(.discard).?);
    }
};

pub const Root = struct {
    base: Scope,
    translator: *Translator,
    sym_table: SymbolTable,
    blank_macros: std.StringArrayHashMapUnmanaged(void),
    nodes: std.ArrayListUnmanaged(ast.Node),
    container_member_fns_map: ContainerMemberFnsHashMap,

    pub fn init(t: *Translator) Root {
        return .{
            .base = .{
                .id = .root,
                .parent = null,
            },
            .translator = t,
            .sym_table = .empty,
            .blank_macros = .empty,
            .nodes = .empty,
            .container_member_fns_map = .empty,
        };
    }

    pub fn deinit(root: *Root) void {
        root.sym_table.deinit(root.translator.gpa);
        root.blank_macros.deinit(root.translator.gpa);
        root.nodes.deinit(root.translator.gpa);
        for (root.container_member_fns_map.values()) |*members| {
            members.member_fns.deinit(root.translator.gpa);
        }
        root.container_member_fns_map.deinit(root.translator.gpa);
    }

    /// Check if the global scope contains this name, without looking into the "future", e.g.
    /// ignore the preprocessed decl and macro names.
    pub fn containsNow(root: *Root, name: []const u8) bool {
        return root.sym_table.contains(name);
    }

    /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
    pub fn contains(root: *Root, name: []const u8) bool {
        return root.containsNow(name) or root.translator.global_names.contains(name) or root.translator.weak_global_names.contains(name);
    }

    pub fn addMemberFunction(root: *Root, func_ty: aro.Type.Func, func: *ast.Payload.Func) !void {
        std.debug.assert(func.data.name != null);
        if (func_ty.params.len == 0) return;

        const param1_base = func_ty.params[0].qt.base(root.translator.comp);
        const container_qt = if (param1_base.type == .pointer)
            param1_base.type.pointer.child.base(root.translator.comp).qt
        else
            param1_base.qt;

        if (root.container_member_fns_map.getPtr(container_qt)) |members| {
            try members.member_fns.append(root.translator.gpa, func);
        }
    }

    pub fn processContainerMemberFns(root: *Root) !void {
        const gpa = root.translator.gpa;
        const arena = root.translator.arena;

        var member_names: std.StringArrayHashMapUnmanaged(u32) = .empty;
        defer member_names.deinit(gpa);
        for (root.container_member_fns_map.values()) |members| {
            member_names.clearRetainingCapacity();
            const decls_ptr = switch (members.container_decl_ptr.tag()) {
                .@"struct", .@"union" => blk_record: {
                    const payload: *ast.Payload.Container = @alignCast(@fieldParentPtr("base", members.container_decl_ptr.ptr_otherwise));
                    // Avoid duplication with field names
                    for (payload.data.fields) |field| {
                        try member_names.put(gpa, field.name, 0);
                    }
                    break :blk_record &payload.data.decls;
                },
                .opaque_literal => blk_opaque: {
                    const container_decl = try ast.Node.Tag.@"opaque".create(arena, .{
                        .layout = .none,
                        .fields = &.{},
                        .decls = &.{},
                    });
                    members.container_decl_ptr.* = container_decl;
                    break :blk_opaque &container_decl.castTag(.@"opaque").?.data.decls;
                },
                else => return,
            };

            const old_decls = decls_ptr.*;
            const new_decls = try arena.alloc(ast.Node, old_decls.len + members.member_fns.items.len);
            @memcpy(new_decls[0..old_decls.len], old_decls);
            // Assume the allocator of payload.data.decls is arena,
            // so don't add arena.free(old_variables).
            const func_ref_vars = new_decls[old_decls.len..];
            var count: u32 = 0;
            for (members.member_fns.items) |func| {
                const func_name = func.data.name.?;

                const last_index = std.mem.lastIndexOf(u8, func_name, "_");
                const last_name = if (last_index) |index| func_name[index + 1 ..] else continue;
                var same_count: u32 = 0;
                const gop = try member_names.getOrPutValue(gpa, last_name, same_count);
                if (gop.found_existing) {
                    gop.value_ptr.* += 1;
                    same_count = gop.value_ptr.*;
                }
                const var_name = if (same_count == 0)
                    last_name
                else
                    try std.fmt.allocPrint(arena, "{s}{d}", .{ last_name, same_count });

                func_ref_vars[count] = try ast.Node.Tag.pub_var_simple.create(arena, .{
                    .name = var_name,
                    .init = try ast.Node.Tag.identifier.create(arena, func_name),
                });
                count += 1;
            }
            decls_ptr.* = new_decls[0 .. old_decls.len + count];
        }
    }
};

pub fn findBlockScope(inner: *Scope, t: *Translator) !*Block {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => unreachable,
            .block => return @fieldParentPtr("base", scope),
            .condition => return @as(*Condition, @fieldParentPtr("base", scope)).getBlockScope(t),
            else => scope = scope.parent.?,
        }
    }
}

pub fn findBlockReturnType(inner: *Scope) aro.QualType {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => unreachable,
            .block => {
                const block: *Block = @fieldParentPtr("base", scope);
                if (block.return_type) |qt| return qt;
                scope = scope.parent.?;
            },
            else => scope = scope.parent.?,
        }
    }
}

pub fn getAlias(scope: *Scope, name: []const u8) ?[]const u8 {
    return switch (scope.id) {
        .root => null,
        .block => @as(*Block, @fieldParentPtr("base", scope)).getAlias(name),
        .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
    };
}

fn contains(scope: *Scope, name: []const u8) bool {
    return switch (scope.id) {
        .root => @as(*Root, @fieldParentPtr("base", scope)).contains(name),
        .block => @as(*Block, @fieldParentPtr("base", scope)).contains(name),
        .loop, .do_loop, .condition => scope.parent.?.contains(name),
    };
}

/// Appends a node to the first block scope if inside a function, or to the root tree if not.
pub fn appendNode(inner: *Scope, node: ast.Node) !void {
    var scope = inner;
    while (true) {
        switch (scope.id) {
            .root => {
                const root: *Root = @fieldParentPtr("base", scope);
                return root.nodes.append(root.translator.gpa, node);
            },
            .block => {
                const block: *Block = @fieldParentPtr("base", scope);
                return block.statements.append(block.translator.gpa, node);
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
