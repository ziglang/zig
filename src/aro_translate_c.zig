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
const common = @import("translate_c/common.zig");
const Error = common.Error;
const MacroProcessingError = common.MacroProcessingError;
const TypeError = common.TypeError;
const TransError = common.TransError;
const SymbolTable = common.SymbolTable;
const AliasList = common.AliasList;
const ResultUsed = common.ResultUsed;
const Scope = common.ScopeExtra(Context, Type);

pub const Compilation = aro.Compilation;

const Context = struct {
    gpa: mem.Allocator,
    arena: mem.Allocator,
    decl_table: std.AutoArrayHashMapUnmanaged(usize, []const u8) = .{},
    alias_list: AliasList,
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
        .alias_list = AliasList.init(gpa),
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
        const data = node_data[@intFromEnum(node)];
        const decl_name = switch (node_tags[@intFromEnum(node)]) {
            .typedef => @panic("TODO"),

            .static_assert,
            .struct_decl_two,
            .union_decl_two,
            .struct_decl,
            .union_decl,
            => blk: {
                const ty = node_types[@intFromEnum(node)];
                const name_id = ty.data.record.name;
                break :blk c.mapper.lookup(name_id);
            },

            .enum_decl_two,
            .enum_decl,
            => blk: {
                const ty = node_types[@intFromEnum(node)];
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
        const data = node_data[@intFromEnum(node)];
        switch (node_tags[@intFromEnum(node)]) {
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

            .enum_decl_two => {
                var fields = [2]NodeIndex{ data.bin.lhs, data.bin.rhs };
                var field_count: u8 = 0;
                if (fields[0] != .none) field_count += 1;
                if (fields[1] != .none) field_count += 1;
                try transEnumDecl(c, &c.global_scope.base, node, fields[0..field_count]);
            },
            .enum_decl => {
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
    const ty = node_types[@intFromEnum(enum_decl)];
    if (c.decl_table.get(@intFromPtr(ty.data.@"enum"))) |_|
        return; // Avoid processing this decl twice
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(c) else undefined;

    var is_unnamed = false;
    var bare_name: []const u8 = c.mapper.lookup(ty.data.@"enum".name);
    var name = bare_name;
    if (c.unnamed_typedefs.get(@intFromPtr(ty.data.@"enum"))) |typedef_name| {
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
    try c.decl_table.putNoClobber(c.gpa, @intFromPtr(ty.data.@"enum"), name);

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

            const val = c.tree.value_map.get(field_node).?;
            const str = try std.fmt.allocPrint(c.arena, "{d}", .{val.data.int});
            const int = try ZigTag.integer_literal.create(c.arena, str);

            const enum_const_def = try ZigTag.enum_constant.create(c.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = int,
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
        try c.opaque_demotes.put(c.gpa, @intFromPtr(ty.data.@"enum"), {});
        break :blk ZigTag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try c.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]ZigTag{ .var_simple, .pub_var_simple })[@intFromBool(is_pub)] },
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
    const ty = c.tree.nodes.items(.ty)[@intFromEnum(node)];
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
    switch (node_tags[@intFromEnum(node)]) {
        else => unreachable, // Not an expression.
    }
    return .none;
}
