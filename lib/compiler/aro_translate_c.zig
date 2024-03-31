const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const CallingConvention = std.builtin.CallingConvention;
const aro = @import("aro");
const CToken = aro.Tokenizer.Token;
const Tree = aro.Tree;
const NodeIndex = Tree.NodeIndex;
const TokenIndex = Tree.TokenIndex;
const Type = aro.Type;
pub const ast = @import("aro_translate_c/ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const Scope = ScopeExtra(Context, Type);
const Context = @This();

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

pattern_list: PatternList,
tree: Tree,
comp: *aro.Compilation,
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

fn warn(c: *Context, scope: *Scope, loc: TokenIndex, comptime format: []const u8, args: anytype) !void {
    const str = try c.locStr(loc);
    const value = try std.fmt.allocPrint(c.arena, "// {s}: warning: " ++ format, .{str} ++ args);
    try scope.appendNode(try ZigTag.warning.create(c.arena, value));
}

pub fn translate(
    gpa: mem.Allocator,
    comp: *aro.Compilation,
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

    const builtin_macros = try comp.generateBuiltinMacros(.include_system_defines);
    const user_macros = try comp.addSourceFromBuffer("<command line>", macro_buf.items);

    var pp = try aro.Preprocessor.initDefault(comp);
    defer pp.deinit();

    try pp.preprocessSources(&.{ source, builtin_macros, user_macros });

    var tree = try pp.parse();
    defer tree.deinit();

    if (driver.comp.diagnostics.errors != 0) {
        return error.SemanticAnalyzeFail;
    }

    const mapper = tree.comp.string_interner.getFastTypeMapper(tree.comp.gpa) catch tree.comp.string_interner.getSlowTypeMapper();
    defer mapper.deinit(tree.comp.gpa);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var context = Context{
        .gpa = gpa,
        .arena = arena,
        .alias_list = AliasList.init(gpa),
        .global_scope = try arena.create(Scope.Root),
        .pattern_list = try PatternList.init(gpa),
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

fn transFnDecl(c: *Context, fn_decl: NodeIndex) Error!void {
    const raw_ty = c.tree.nodes.items(.ty)[@intFromEnum(fn_decl)];
    const fn_ty = raw_ty.canonicalize(.standard);
    const node_data = c.tree.nodes.items(.data)[@intFromEnum(fn_decl)];
    if (c.decl_table.get(@intFromPtr(fn_ty.data.func))) |_|
        return; // Avoid processing this decl twice

    const fn_name = c.tree.tokSlice(node_data.decl.name);
    if (c.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    const fn_decl_loc = 0; // TODO
    const has_body = node_data.decl.node != .none;
    const is_always_inline = has_body and raw_ty.getAttribute(.always_inline) != null;
    const proto_ctx = FnProtoContext{
        .fn_name = fn_name,
        .is_inline = is_always_inline,
        .is_extern = !has_body,
        .is_export = switch (c.tree.nodes.items(.tag)[@intFromEnum(fn_decl)]) {
            .fn_proto, .fn_def => has_body and !is_always_inline,

            .inline_fn_proto, .inline_fn_def, .inline_static_fn_proto, .inline_static_fn_def, .static_fn_proto, .static_fn_def => false,

            else => unreachable,
        },
    };

    const proto_node = transFnType(c, &c.global_scope.base, raw_ty, fn_ty, fn_decl_loc, proto_ctx) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    if (!has_body) {
        return addTopLevelDecl(c, fn_name, proto_node);
    }
    const proto_payload = proto_node.castTag(.func).?;

    // actual function definition with body
    const body_stmt = node_data.decl.node;
    var block_scope = try Scope.Block.init(c, &c.global_scope.base, false);
    block_scope.return_type = fn_ty.data.func.return_type;
    defer block_scope.deinit();

    var scope = &block_scope.base;
    _ = &scope;

    var param_id: c_uint = 0;
    for (proto_payload.data.params, fn_ty.data.func.params) |*param, param_info| {
        const param_name = param.name orelse {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try warn(c, &c.global_scope.base, fn_decl_loc, "function {s} parameter has no name, demoted to extern", .{fn_name});
            return addTopLevelDecl(c, fn_name, proto_node);
        };

        const is_const = param_info.ty.qual.@"const";

        const mangled_param_name = try block_scope.makeMangledName(c, param_name);
        param.name = mangled_param_name;

        if (!is_const) {
            const bare_arg_name = try std.fmt.allocPrint(c.arena, "arg_{s}", .{mangled_param_name});
            const arg_name = try block_scope.makeMangledName(c, bare_arg_name);
            param.name = arg_name;

            const redecl_node = try ZigTag.arg_redecl.create(c.arena, .{ .actual = mangled_param_name, .mangled = arg_name });
            try block_scope.statements.append(redecl_node);
        }
        try block_scope.discardVariable(c, mangled_param_name);

        param_id += 1;
    }

    transCompoundStmtInline(c, body_stmt, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try warn(c, &c.global_scope.base, fn_decl_loc, "unable to translate function, demoted to extern", .{});
            return addTopLevelDecl(c, fn_name, proto_node);
        },
    };

    proto_payload.data.body = try block_scope.complete(c);
    return addTopLevelDecl(c, fn_name, proto_node);
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
            const enum_const_def = try ZigTag.enum_constant.create(c.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = try transCreateNodeAPInt(c, val),
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
        .func,
        .var_args_func,
        .old_style_func,
        => return transFnType(c, scope, raw_ty, ty, source_loc, .{}),
        else => return error.UnsupportedType,
    }
}

fn zigAlignment(bit_alignment: u29) u32 {
    return bit_alignment / 8;
}

const FnProtoContext = struct {
    is_pub: bool = false,
    is_export: bool = false,
    is_extern: bool = false,
    is_inline: bool = false,
    fn_name: ?[]const u8 = null,
};

fn transFnType(
    c: *Context,
    scope: *Scope,
    raw_ty: Type,
    fn_ty: Type,
    source_loc: TokenIndex,
    ctx: FnProtoContext,
) !ZigNode {
    const param_count: usize = fn_ty.data.func.params.len;
    const fn_params = try c.arena.alloc(ast.Payload.Param, param_count);

    for (fn_ty.data.func.params, fn_params) |param_info, *param_node| {
        const param_ty = param_info.ty;
        const is_noalias = param_ty.qual.restrict;

        const param_name: ?[]const u8 = if (param_info.name == .empty)
            null
        else
            c.mapper.lookup(param_info.name);

        const type_node = try transType(c, scope, param_ty, param_info.name_tok);
        param_node.* = .{
            .is_noalias = is_noalias,
            .name = param_name,
            .type = type_node,
        };
    }

    const linksection_string = blk: {
        if (raw_ty.getAttribute(.section)) |section| {
            break :blk c.comp.interner.get(section.name.ref()).bytes;
        }
        break :blk null;
    };

    const alignment = if (raw_ty.requestedAlignment(c.comp)) |alignment| zigAlignment(alignment) else null;

    const explicit_callconv = null;
    // const explicit_callconv = if ((ctx.is_inline or ctx.is_export or ctx.is_extern) and ctx.cc == .C) null else ctx.cc;

    const return_type_node = blk: {
        if (raw_ty.getAttribute(.noreturn) != null) {
            break :blk ZigTag.noreturn_type.init();
        } else {
            const return_ty = fn_ty.data.func.return_type;
            if (return_ty.is(.void)) {
                // convert primitive anyopaque to actual void (only for return type)
                break :blk ZigTag.void_type.init();
            } else {
                break :blk transType(c, scope, return_ty, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try warn(c, scope, source_loc, "unsupported function proto return type", .{});
                        return err;
                    },
                    error.OutOfMemory => |e| return e,
                };
            }
        }
    };

    const payload = try c.arena.create(ast.Payload.Func);
    payload.* = .{
        .base = .{ .tag = .func },
        .data = .{
            .is_pub = ctx.is_pub,
            .is_extern = ctx.is_extern,
            .is_export = ctx.is_export,
            .is_inline = ctx.is_inline,
            .is_var_args = switch (fn_ty.specifier) {
                .func => false,
                .var_args_func => true,
                .old_style_func => !ctx.is_export and !ctx.is_inline,
                else => unreachable,
            },
            .name = ctx.fn_name,
            .linksection_string = linksection_string,
            .explicit_callconv = explicit_callconv,
            .params = fn_params,
            .return_type = return_type_node,
            .body = null,
            .alignment = alignment,
        },
    };
    return ZigNode.initPayload(&payload.base);
}

fn transStmt(c: *Context, node: NodeIndex) TransError!ZigNode {
    return transExpr(c, node, .unused);
}

fn transCompoundStmtInline(c: *Context, compound: NodeIndex, block: *Scope.Block) TransError!void {
    const data = c.tree.nodes.items(.data)[@intFromEnum(compound)];
    var buf: [2]NodeIndex = undefined;
    // TODO move these helpers to Aro
    const stmts = switch (c.tree.nodes.items(.tag)[@intFromEnum(compound)]) {
        .compound_stmt_two => blk: {
            if (data.bin.lhs != .none) buf[0] = data.bin.lhs;
            if (data.bin.rhs != .none) buf[1] = data.bin.rhs;
            break :blk buf[0 .. @as(u32, @intFromBool(data.bin.lhs != .none)) + @intFromBool(data.bin.rhs != .none)];
        },
        .compound_stmt => c.tree.data[data.range.start..data.range.end],
        else => unreachable,
    };
    for (stmts) |stmt| {
        const result = try transStmt(c, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block.statements.append(result),
        }
    }
}

fn transCompoundStmt(c: *Context, scope: *Scope, compound: NodeIndex) TransError!ZigNode {
    var block_scope = try Scope.Block.init(c, scope, false);
    defer block_scope.deinit();
    try transCompoundStmtInline(c, compound, &block_scope);
    return try block_scope.complete(c);
}

fn transExpr(c: *Context, node: NodeIndex, result_used: ResultUsed) TransError!ZigNode {
    std.debug.assert(node != .none);
    const ty = c.tree.nodes.items(.ty)[@intFromEnum(node)];
    if (c.tree.value_map.get(node)) |val| {
        // TODO handle other values
        const int = try transCreateNodeAPInt(c, val);
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

fn transCreateNodeAPInt(c: *Context, int: aro.Value) !ZigNode {
    var space: aro.Interner.Tag.Int.BigIntSpace = undefined;
    var big = int.toBigInt(&space, c.comp);
    const is_negative = !big.positive;
    big.positive = true;

    const str = big.toStringAlloc(c.arena, 10, .lower) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    const res = try ZigTag.integer_literal.create(c.arena, str);
    if (is_negative) return ZigTag.negate.create(c.arena, res);
    return res;
}

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
            macro_table: SymbolTable,
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
                    .macro_table = SymbolTable.init(c.gpa),
                    .blank_macros = std.StringArrayHashMap(void).init(c.gpa),
                    .context = c,
                    .nodes = std.ArrayList(ast.Node).init(c.gpa),
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
                .root => return name,
                .block => @as(*Block, @fieldParentPtr("base", scope)).getAlias(name),
                .loop, .do_loop, .condition => scope.parent.?.getAlias(name),
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
    var tokenizer: aro.Tokenizer = .{
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

// Testing here instead of test/translate_c.zig allows us to also test that the
// mapped function exists in `std.zig.c_translation.Macros`
test "Macro matching" {
    const testing = std.testing;
    const helper = struct {
        const MacroFunctions = std.zig.c_translation.Macros;
        fn checkMacro(allocator: mem.Allocator, pattern_list: PatternList, source: []const u8, comptime expected_match: ?[]const u8) !void {
            var tok_list = std.ArrayList(CToken).init(allocator);
            defer tok_list.deinit();
            try tokenizeMacro(source, &tok_list);
            const macro_slicer: MacroSlicer = .{ .source = source, .tokens = tok_list.items };
            const matched = try pattern_list.match(allocator, macro_slicer);
            if (expected_match) |expected| {
                try testing.expectEqualStrings(expected, matched.?.impl);
                try testing.expect(@hasDecl(MacroFunctions, expected));
            } else {
                try testing.expectEqual(@as(@TypeOf(matched), null), matched);
            }
        }
    };
    const allocator = std.testing.allocator;
    var pattern_list = try PatternList.init(allocator);
    defer pattern_list.deinit(allocator);

    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## F)", "F_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## U)", "U_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## L)", "L_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## LL)", "LL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## UL)", "UL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list, "BAR(Z) (Z ## ULL)", "ULL_SUFFIX");
    try helper.checkMacro(allocator, pattern_list,
        \\container_of(a, b, c)                             \
        \\(__typeof__(b))((char *)(a) -                     \
        \\     offsetof(__typeof__(*b), c))
    , "WL_CONTAINER_OF");

    try helper.checkMacro(allocator, pattern_list, "NO_MATCH(X, Y) (X + Y)", null);
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) (X)(Y)", "CAST_OR_CALL");
    try helper.checkMacro(allocator, pattern_list, "CAST_OR_CALL(X, Y) ((X)(Y))", "CAST_OR_CALL");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (const volatile void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((const volatile void)(X))", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) (volatile const void)(X)", "DISCARD");
    try helper.checkMacro(allocator, pattern_list, "IGNORE_ME(X) ((volatile const void)(X))", "DISCARD");
}

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);

    var aro_comp = aro.Compilation.init(gpa);
    defer aro_comp.deinit();

    var tree = translate(gpa, &aro_comp, args) catch |err| switch (err) {
        error.SemanticAnalyzeFail, error.FatalError => {
            aro.Diagnostics.render(&aro_comp, std.io.tty.detectConfig(std.io.getStdErr()));
            std.process.exit(1);
        },
        error.OutOfMemory => return error.OutOfMemory,
        error.StreamTooLong => std.zig.fatal("StreamTooLong?", .{}),
    };
    defer tree.deinit(gpa);

    const formatted = try tree.render(arena);
    try std.io.getStdOut().writeAll(formatted);
    return std.process.cleanExit();
}
