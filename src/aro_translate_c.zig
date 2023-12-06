const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const CallingConvention = std.builtin.CallingConvention;
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
