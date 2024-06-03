const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const meta = std.meta;
const CallingConvention = std.builtin.CallingConvention;
const clang = @import("clang.zig");
const aro = @import("aro");
const CToken = aro.Tokenizer.Token;
const Node = ast.Node;
const Tag = Node.Tag;
const common = @import("aro_translate_c");
const ast = common.ast;
const Error = common.Error;
const MacroProcessingError = common.MacroProcessingError;
const TypeError = common.TypeError;
const TransError = common.TransError;
const SymbolTable = common.SymbolTable;
const AliasList = common.AliasList;
const ResultUsed = common.ResultUsed;
const Scope = common.ScopeExtra(Context, clang.QualType);
const PatternList = common.PatternList;
const MacroSlicer = common.MacroSlicer;

pub const Context = struct {
    gpa: mem.Allocator,
    arena: mem.Allocator,
    source_manager: *clang.SourceManager,
    decl_table: std.AutoArrayHashMapUnmanaged(usize, []const u8) = .{},
    alias_list: AliasList,
    global_scope: *Scope.Root,
    clang_context: *clang.ASTContext,
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

    fn getMangle(c: *Context) u32 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*:0]const u8) ![]u8 {
        return c.arena.dupe(u8, mem.sliceTo(s, 0));
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: clang.SourceLocation) ![]u8 {
        const spelling_loc = c.source_manager.getSpellingLoc(loc);
        const filename_c = c.source_manager.getFilename(spelling_loc);
        const filename = if (filename_c) |s| try c.str(s) else @as([]const u8, "(no file)");

        const line = c.source_manager.getSpellingLineNumber(spelling_loc);
        const column = c.source_manager.getSpellingColumnNumber(spelling_loc);
        return std.fmt.allocPrint(c.arena, "{s}:{d}:{d}", .{ filename, line, column });
    }
};

pub fn translate(
    gpa: mem.Allocator,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors: *std.zig.ErrorBundle,
    resources_path: [*:0]const u8,
) !std.zig.Ast {
    var clang_errors: []clang.ErrorMsg = &.{};

    const ast_unit = clang.LoadFromCommandLine(
        args_begin,
        args_end,
        &clang_errors.ptr,
        &clang_errors.len,
        resources_path,
    ) orelse {
        defer clang.ErrorMsg.delete(clang_errors.ptr, clang_errors.len);

        var bundle: std.zig.ErrorBundle.Wip = undefined;
        try bundle.init(gpa);
        defer bundle.deinit();

        for (clang_errors) |c_error| {
            const line = line: {
                const source = c_error.source orelse break :line 0;
                var start = c_error.offset;
                while (start > 0) : (start -= 1) {
                    if (source[start - 1] == '\n') break;
                }
                var end = c_error.offset;
                while (true) : (end += 1) {
                    if (source[end] == 0) break;
                    if (source[end] == '\n') break;
                }
                break :line try bundle.addString(source[start..end]);
            };

            try bundle.addRootErrorMessage(.{
                .msg = try bundle.addString(c_error.msg_ptr[0..c_error.msg_len]),
                .src_loc = if (c_error.filename_ptr) |filename_ptr| try bundle.addSourceLocation(.{
                    .src_path = try bundle.addString(filename_ptr[0..c_error.filename_len]),
                    .span_start = c_error.offset,
                    .span_main = c_error.offset,
                    .span_end = c_error.offset + 1,
                    .line = c_error.line,
                    .column = c_error.column,
                    .source_line = line,
                }) else .none,
            });
        }
        errors.* = try bundle.toOwnedBundle("");

        return error.SemanticAnalyzeFail;
    };
    defer ast_unit.delete();

    // For memory that has the same lifetime as the Ast that we return
    // from this function.
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var context = Context{
        .gpa = gpa,
        .arena = arena,
        .source_manager = ast_unit.getSourceManager(),
        .alias_list = AliasList.init(gpa),
        .global_scope = try arena.create(Scope.Root),
        .clang_context = ast_unit.getASTContext(),
        .pattern_list = try PatternList.init(gpa),
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
        const builtin = try Tag.pub_var_simple.create(arena, .{
            .name = decl.name,
            .init = try Tag.import_c_builtin.create(arena, decl.name),
        });
        try addTopLevelDecl(&context, decl.name, builtin);
    }

    try prepopulateGlobalNameTable(ast_unit, &context);

    if (!ast_unit.visitLocalTopLevelDecls(&context, declVisitorC)) {
        return error.OutOfMemory;
    }

    try transPreprocessorEntities(&context, ast_unit);

    for (context.alias_list.items) |alias| {
        const node = try Tag.alias.create(arena, .{ .actual = alias.alias, .mangled = alias.name });
        try addTopLevelDecl(&context, alias.alias, node);
    }

    return ast.render(gpa, context.global_scope.nodes.items);
}

/// Determines whether macro is of the form: `#define FOO FOO` (Possibly with trailing tokens)
/// Macros of this form will not be translated.
fn isSelfDefinedMacro(unit: *const clang.ASTUnit, c: *const Context, macro: *const clang.MacroDefinitionRecord) !bool {
    const source = try getMacroText(unit, c, macro);
    var tokenizer: aro.Tokenizer = .{
        .buf = source,
        .source = .unused,
        .langopts = .{},
    };
    const name_tok = tokenizer.nextNoWS();
    const name = source[name_tok.start..name_tok.end];

    const first_tok = tokenizer.nextNoWS();
    // We do not just check for `.Identifier` below because keyword tokens are preferentially matched first by
    // the tokenizer.
    // In other words we would miss `#define inline inline` (`inline` is a valid c89 identifier)
    if (first_tok.id == .eof) return false;
    return mem.eql(u8, name, source[first_tok.start..first_tok.end]);
}

fn prepopulateGlobalNameTable(ast_unit: *clang.ASTUnit, c: *Context) !void {
    if (!ast_unit.visitLocalTopLevelDecls(c, declVisitorNamesOnlyC)) {
        return error.OutOfMemory;
    }

    // TODO if we see #undef, delete it from the table
    var it = ast_unit.getLocalPreprocessingEntities_begin();
    const it_end = ast_unit.getLocalPreprocessingEntities_end();

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = it.deref();
        switch (entity.getKind()) {
            .MacroDefinitionKind => {
                const macro = @as(*clang.MacroDefinitionRecord, @ptrCast(entity));
                const raw_name = macro.getName_getNameStart();
                const name = try c.str(raw_name);

                if (!try isSelfDefinedMacro(ast_unit, c, macro)) {
                    try c.global_names.put(c.gpa, name, {});
                }
            },
            else => {},
        }
    }
}

fn declVisitorNamesOnlyC(context: ?*anyopaque, decl: *const clang.Decl) callconv(.C) bool {
    const c: *Context = @ptrCast(@alignCast(context));
    declVisitorNamesOnly(c, decl) catch return false;
    return true;
}

fn declVisitorC(context: ?*anyopaque, decl: *const clang.Decl) callconv(.C) bool {
    const c: *Context = @ptrCast(@alignCast(context));
    declVisitor(c, decl) catch return false;
    return true;
}

fn declVisitorNamesOnly(c: *Context, decl: *const clang.Decl) Error!void {
    if (decl.castToNamedDecl()) |named_decl| {
        const decl_name = try c.str(named_decl.getName_bytes_begin());

        switch (decl.getKind()) {
            .Record, .Enum => {
                // These types are prefixed with the container kind.
                const container_prefix = if (decl.getKind() == .Record) prefix: {
                    const record_decl: *const clang.RecordDecl = @ptrCast(decl);
                    if (record_decl.isUnion()) {
                        break :prefix "union";
                    } else {
                        break :prefix "struct";
                    }
                } else "enum";
                const prefixed_name = try std.fmt.allocPrint(c.arena, "{s}_{s}", .{ container_prefix, decl_name });
                // `decl_name` and `prefixed_name` are the preferred names for this type.
                // However, we can name it anything else if necessary, so these are "weak names".
                try c.weak_global_names.ensureUnusedCapacity(c.gpa, 2);
                c.weak_global_names.putAssumeCapacity(decl_name, {});
                c.weak_global_names.putAssumeCapacity(prefixed_name, {});
            },
            else => {
                try c.global_names.put(c.gpa, decl_name, {});
            },
        }

        // Check for typedefs with unnamed enum/record child types.
        if (decl.getKind() == .Typedef) {
            const typedef_decl = @as(*const clang.TypedefNameDecl, @ptrCast(decl));
            var child_ty = typedef_decl.getUnderlyingType().getTypePtr();
            const addr: usize = while (true) switch (child_ty.getTypeClass()) {
                .Enum => {
                    const enum_ty = @as(*const clang.EnumType, @ptrCast(child_ty));
                    const enum_decl = enum_ty.getDecl();
                    // check if this decl is unnamed
                    if (@as(*const clang.NamedDecl, @ptrCast(enum_decl)).getName_bytes_begin()[0] != 0) return;
                    break @intFromPtr(enum_decl.getCanonicalDecl());
                },
                .Record => {
                    const record_ty = @as(*const clang.RecordType, @ptrCast(child_ty));
                    const record_decl = record_ty.getDecl();
                    // check if this decl is unnamed
                    if (@as(*const clang.NamedDecl, @ptrCast(record_decl)).getName_bytes_begin()[0] != 0) return;
                    break @intFromPtr(record_decl.getCanonicalDecl());
                },
                .Elaborated => {
                    const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(child_ty));
                    child_ty = elaborated_ty.getNamedType().getTypePtr();
                },
                .Decayed => {
                    const decayed_ty = @as(*const clang.DecayedType, @ptrCast(child_ty));
                    child_ty = decayed_ty.getDecayedType().getTypePtr();
                },
                .Attributed => {
                    const attributed_ty = @as(*const clang.AttributedType, @ptrCast(child_ty));
                    child_ty = attributed_ty.getEquivalentType().getTypePtr();
                },
                .MacroQualified => {
                    const macroqualified_ty = @as(*const clang.MacroQualifiedType, @ptrCast(child_ty));
                    child_ty = macroqualified_ty.getModifiedType().getTypePtr();
                },
                else => return,
            };

            const result = try c.unnamed_typedefs.getOrPut(c.gpa, addr);
            if (result.found_existing) {
                // One typedef can declare multiple names.
                // Don't put this one in `decl_table` so it's processed later.
                return;
            }
            result.value_ptr.* = decl_name;
            // Put this typedef in the decl_table to avoid redefinitions.
            try c.decl_table.putNoClobber(c.gpa, @intFromPtr(typedef_decl.getCanonicalDecl()), decl_name);
            try c.typedefs.put(c.gpa, decl_name, {});
        }
    }
}

fn declVisitor(c: *Context, decl: *const clang.Decl) Error!void {
    switch (decl.getKind()) {
        .Function => {
            return visitFnDecl(c, @as(*const clang.FunctionDecl, @ptrCast(decl)));
        },
        .Typedef => {
            try transTypeDef(c, &c.global_scope.base, @as(*const clang.TypedefNameDecl, @ptrCast(decl)));
        },
        .Enum => {
            try transEnumDecl(c, &c.global_scope.base, @as(*const clang.EnumDecl, @ptrCast(decl)));
        },
        .Record => {
            try transRecordDecl(c, &c.global_scope.base, @as(*const clang.RecordDecl, @ptrCast(decl)));
        },
        .Var => {
            return visitVarDecl(c, @as(*const clang.VarDecl, @ptrCast(decl)), null);
        },
        .Empty => {
            // Do nothing
        },
        .FileScopeAsm => {
            try transFileScopeAsm(c, &c.global_scope.base, @as(*const clang.FileScopeAsmDecl, @ptrCast(decl)));
        },
        else => {
            const decl_name = try c.str(decl.getDeclKindName());
            try warn(c, &c.global_scope.base, decl.getLocation(), "ignoring {s} declaration", .{decl_name});
        },
    }
}

fn transFileScopeAsm(c: *Context, scope: *Scope, file_scope_asm: *const clang.FileScopeAsmDecl) Error!void {
    const asm_string = file_scope_asm.getAsmString();
    var len: usize = undefined;
    const bytes_ptr = asm_string.getString_bytes_begin_size(&len);

    const str = try std.fmt.allocPrint(c.arena, "\"{}\"", .{std.zig.fmtEscapes(bytes_ptr[0..len])});
    const str_node = try Tag.string_literal.create(c.arena, str);

    const asm_node = try Tag.asm_simple.create(c.arena, str_node);
    const block = try Tag.block_single.create(c.arena, asm_node);
    const comptime_node = try Tag.@"comptime".create(c.arena, block);

    try scope.appendNode(comptime_node);
}

fn visitFnDecl(c: *Context, fn_decl: *const clang.FunctionDecl) Error!void {
    const fn_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(fn_decl)).getName_bytes_begin());
    if (c.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    // Skip this declaration if a proper definition exists
    if (!fn_decl.isThisDeclarationADefinition()) {
        if (fn_decl.getDefinition()) |def|
            return visitFnDecl(c, def);
    }

    const fn_decl_loc = fn_decl.getLocation();
    const has_body = fn_decl.hasBody();
    const storage_class = fn_decl.getStorageClass();
    const is_always_inline = has_body and fn_decl.hasAlwaysInlineAttr();
    var decl_ctx = FnDeclContext{
        .fn_name = fn_name,
        .has_body = has_body,
        .storage_class = storage_class,
        .is_always_inline = is_always_inline,
        .is_export = switch (storage_class) {
            .None => has_body and !is_always_inline and !fn_decl.isInlineSpecified(),
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern", .{}),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        },
    };

    var fn_qt = fn_decl.getType();

    const fn_type = while (true) {
        const fn_type = fn_qt.getTypePtr();

        switch (fn_type.getTypeClass()) {
            .Attributed => {
                const attr_type = @as(*const clang.AttributedType, @ptrCast(fn_type));
                fn_qt = attr_type.getEquivalentType();
            },
            .Paren => {
                const paren_type = @as(*const clang.ParenType, @ptrCast(fn_type));
                fn_qt = paren_type.getInnerType();
            },
            else => break fn_type,
        }
    };
    const fn_ty = @as(*const clang.FunctionType, @ptrCast(fn_type));
    const return_qt = fn_ty.getReturnType();

    const proto_node = switch (fn_type.getTypeClass()) {
        .FunctionProto => blk: {
            const fn_proto_type = @as(*const clang.FunctionProtoType, @ptrCast(fn_type));
            if (has_body and fn_proto_type.isVariadic()) {
                decl_ctx.has_body = false;
                decl_ctx.storage_class = .Extern;
                decl_ctx.is_export = false;
                decl_ctx.is_always_inline = false;
                try warn(c, &c.global_scope.base, fn_decl_loc, "TODO unable to translate variadic function, demoted to extern", .{});
            }
            break :blk transFnProto(c, fn_decl, fn_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
                },
                error.OutOfMemory => |e| return e,
            };
        },
        .FunctionNoProto => blk: {
            const fn_no_proto_type = @as(*const clang.FunctionType, @ptrCast(fn_type));
            break :blk transFnNoProto(c, fn_no_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
                },
                error.OutOfMemory => |e| return e,
            };
        },
        else => return failDecl(c, fn_decl_loc, fn_name, "unable to resolve function type {}", .{fn_type.getTypeClass()}),
    };

    if (!decl_ctx.has_body) {
        return addTopLevelDecl(c, fn_name, Node.initPayload(&proto_node.base));
    }

    // actual function definition with body
    const body_stmt = fn_decl.getBody();
    var block_scope = try Scope.Block.init(c, &c.global_scope.base, false);
    block_scope.return_type = return_qt;
    defer block_scope.deinit();

    const scope = &block_scope.base;

    var param_id: c_uint = 0;
    for (proto_node.data.params) |*param| {
        const param_name = param.name orelse {
            proto_node.data.is_extern = true;
            proto_node.data.is_export = false;
            proto_node.data.is_inline = false;
            try warn(c, &c.global_scope.base, fn_decl_loc, "function {s} parameter has no name, demoted to extern", .{fn_name});
            return addTopLevelDecl(c, fn_name, Node.initPayload(&proto_node.base));
        };

        const c_param = fn_decl.getParamDecl(param_id);
        const qual_type = c_param.getOriginalType();
        const is_const = qual_type.isConstQualified();

        const mangled_param_name = try block_scope.makeMangledName(c, param_name);
        param.name = mangled_param_name;

        if (!is_const) {
            const bare_arg_name = try std.fmt.allocPrint(c.arena, "arg_{s}", .{mangled_param_name});
            const arg_name = try block_scope.makeMangledName(c, bare_arg_name);
            param.name = arg_name;

            const redecl_node = try Tag.arg_redecl.create(c.arena, .{ .actual = mangled_param_name, .mangled = arg_name });
            try block_scope.statements.append(redecl_node);
        }
        try block_scope.discardVariable(c, mangled_param_name);

        param_id += 1;
    }

    const casted_body = @as(*const clang.CompoundStmt, @ptrCast(body_stmt));
    transCompoundStmtInline(c, casted_body, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => {
            proto_node.data.is_extern = true;
            proto_node.data.is_export = false;
            proto_node.data.is_inline = false;
            try warn(c, &c.global_scope.base, fn_decl_loc, "unable to translate function, demoted to extern", .{});
            return addTopLevelDecl(c, fn_name, Node.initPayload(&proto_node.base));
        },
    };
    // add return statement if the function didn't have one
    blk: {
        const maybe_body = try block_scope.complete(c);
        if (fn_ty.getNoReturnAttr() or isAnyopaque(return_qt) or maybe_body.isNoreturn(false)) {
            proto_node.data.body = maybe_body;
            break :blk;
        }

        const rhs = transZeroInitExpr(c, scope, fn_decl_loc, return_qt.getTypePtr()) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            error.UnsupportedTranslation,
            error.UnsupportedType,
            => {
                proto_node.data.is_extern = true;
                proto_node.data.is_export = false;
                proto_node.data.is_inline = false;
                try warn(c, &c.global_scope.base, fn_decl_loc, "unable to create a return value for function, demoted to extern", .{});
                return addTopLevelDecl(c, fn_name, Node.initPayload(&proto_node.base));
            },
        };
        const ret = try Tag.@"return".create(c.arena, rhs);
        try block_scope.statements.append(ret);
        proto_node.data.body = try block_scope.complete(c);
    }

    return addTopLevelDecl(c, fn_name, Node.initPayload(&proto_node.base));
}

fn transQualTypeMaybeInitialized(c: *Context, scope: *Scope, qt: clang.QualType, decl_init: ?*const clang.Expr, loc: clang.SourceLocation) TransError!Node {
    return if (decl_init) |init_expr|
        transQualTypeInitialized(c, scope, qt, init_expr, loc)
    else
        transQualType(c, scope, qt, loc);
}

/// This is used in global scope to convert a string literal `S` to [*c]u8:
/// &(struct {
///     var static = S.*;
/// }).static;
fn stringLiteralToCharStar(c: *Context, str: Node) Error!Node {
    const var_name = Scope.Block.static_inner_name;

    const variables = try c.arena.alloc(Node, 1);
    variables[0] = try Tag.mut_str.create(c.arena, .{ .name = var_name, .init = str });

    const anon_struct = try Tag.@"struct".create(c.arena, .{
        .layout = .none,
        .fields = &.{},
        .functions = &.{},
        .variables = variables,
    });

    const member_access = try Tag.field_access.create(c.arena, .{
        .lhs = anon_struct,
        .field_name = var_name,
    });
    return Tag.address_of.create(c.arena, member_access);
}

/// if mangled_name is not null, this var decl was declared in a block scope.
fn visitVarDecl(c: *Context, var_decl: *const clang.VarDecl, mangled_name: ?[]const u8) Error!void {
    const var_name = mangled_name orelse try c.str(@as(*const clang.NamedDecl, @ptrCast(var_decl)).getName_bytes_begin());
    if (c.global_scope.sym_table.contains(var_name))
        return; // Avoid processing this decl twice

    const is_pub = mangled_name == null;
    const is_threadlocal = var_decl.getTLSKind() != .None;
    const scope = &c.global_scope.base;
    const var_decl_loc = var_decl.getLocation();

    const qual_type = var_decl.getTypeSourceInfo_getType();
    const storage_class = var_decl.getStorageClass();
    const has_init = var_decl.hasInit();
    const decl_init = var_decl.getInit();
    var is_const = qual_type.isConstQualified();

    // In C extern variables with initializers behave like Zig exports.
    // extern int foo = 2;
    // does the same as:
    // extern int foo;
    // int foo = 2;
    var is_extern = storage_class == .Extern and !has_init;
    var is_export = !is_extern and storage_class != .Static;

    if (!is_extern and qualTypeWasDemotedToOpaque(c, qual_type)) {
        return failDecl(c, var_decl_loc, var_name, "non-extern variable has opaque type", .{});
    }

    const type_node = transQualTypeMaybeInitialized(c, scope, qual_type, decl_init, var_decl_loc) catch |err| switch (err) {
        error.UnsupportedTranslation, error.UnsupportedType => {
            return failDecl(c, var_decl_loc, var_name, "unable to resolve variable type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    var init_node: ?Node = null;

    // If the initialization expression is not present, initialize with undefined.
    // If it is an integer literal, we can skip the @as since it will be redundant
    // with the variable type.
    if (has_init) trans_init: {
        if (decl_init) |expr| {
            const node_or_error = if (expr.getStmtClass() == .StringLiteralClass)
                transStringLiteralInitializer(c, @as(*const clang.StringLiteral, @ptrCast(expr)), type_node)
            else
                transExprCoercing(c, scope, expr, .used);
            init_node = node_or_error catch |err| switch (err) {
                error.UnsupportedTranslation,
                error.UnsupportedType,
                => {
                    is_extern = true;
                    is_export = false;
                    try warn(c, scope, var_decl_loc, "unable to translate variable initializer, demoted to extern", .{});
                    break :trans_init;
                },
                error.OutOfMemory => |e| return e,
            };
            if (!qualTypeIsBoolean(qual_type) and isBoolRes(init_node.?)) {
                init_node = try Tag.int_from_bool.create(c.arena, init_node.?);
            } else if (init_node.?.tag() == .string_literal and qualTypeIsCharStar(qual_type)) {
                init_node = try stringLiteralToCharStar(c, init_node.?);
            }
        } else {
            init_node = Tag.undefined_literal.init();
        }
    } else if (storage_class != .Extern) {
        // The C language specification states that variables with static or threadlocal
        // storage without an initializer are initialized to a zero value.

        // std.mem.zeroes(T)
        init_node = try Tag.std_mem_zeroes.create(c.arena, type_node);
    } else if (qual_type.getTypeClass() == .IncompleteArray) {
        // Oh no, an extern array of unknown size! These are really fun because there's no
        // direct equivalent in Zig. To translate correctly, we'll have to create a C-pointer
        // to the data initialized via @extern.

        const name_str = try std.fmt.allocPrint(c.arena, "\"{s}\"", .{var_name});
        init_node = try Tag.builtin_extern.create(c.arena, .{
            .type = type_node,
            .name = try Tag.string_literal.create(c.arena, name_str),
        });

        // Since this is really a pointer to the underlying data, we tweak a few properties.
        is_extern = false;
        is_const = true;
    }

    const linksection_string = blk: {
        var str_len: usize = undefined;
        if (var_decl.getSectionAttribute(&str_len)) |str_ptr| {
            break :blk str_ptr[0..str_len];
        }
        break :blk null;
    };

    const node = try Tag.var_decl.create(c.arena, .{
        .is_pub = is_pub,
        .is_const = is_const,
        .is_extern = is_extern,
        .is_export = is_export,
        .is_threadlocal = is_threadlocal,
        .linksection_string = linksection_string,
        .alignment = ClangAlignment.forVar(c, var_decl).zigAlignment(),
        .name = var_name,
        .type = type_node,
        .init = init_node,
    });
    return addTopLevelDecl(c, var_name, node);
}

const builtin_typedef_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "uint8_t", "u8" },
    .{ "int8_t", "i8" },
    .{ "uint16_t", "u16" },
    .{ "int16_t", "i16" },
    .{ "uint32_t", "u32" },
    .{ "int32_t", "i32" },
    .{ "uint64_t", "u64" },
    .{ "int64_t", "i64" },
    .{ "intptr_t", "isize" },
    .{ "uintptr_t", "usize" },
    .{ "ssize_t", "isize" },
    .{ "size_t", "usize" },
});

fn transTypeDef(c: *Context, scope: *Scope, typedef_decl: *const clang.TypedefNameDecl) Error!void {
    if (c.decl_table.get(@intFromPtr(typedef_decl.getCanonicalDecl()))) |_|
        return; // Avoid processing this decl twice
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(c) else undefined;

    var name: []const u8 = try c.str(@as(*const clang.NamedDecl, @ptrCast(typedef_decl)).getName_bytes_begin());
    try c.typedefs.put(c.gpa, name, {});

    if (builtin_typedef_map.get(name)) |builtin| {
        return c.decl_table.putNoClobber(c.gpa, @intFromPtr(typedef_decl.getCanonicalDecl()), builtin);
    }
    if (!toplevel) name = try bs.makeMangledName(c, name);
    try c.decl_table.putNoClobber(c.gpa, @intFromPtr(typedef_decl.getCanonicalDecl()), name);

    const child_qt = typedef_decl.getUnderlyingType();
    const typedef_loc = typedef_decl.getLocation();
    const init_node = transQualType(c, scope, child_qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, typedef_loc, name, "unable to resolve typedef child type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const payload = try c.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]Tag{ .var_simple, .pub_var_simple })[@intFromBool(toplevel)] },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = Node.initPayload(&payload.base);

    if (toplevel) {
        try addTopLevelDecl(c, name, node);
    } else {
        try scope.appendNode(node);
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(c, name);
        }
    }
}

/// Build a getter function for a flexible array member at the end of a C struct
/// e.g. `T items[]` or `T items[0]`. The generated function returns a [*c] pointer
/// to the flexible array with the correct const and volatile qualifiers
fn buildFlexibleArrayFn(
    c: *Context,
    scope: *Scope,
    layout: *const clang.ASTRecordLayout,
    field_name: []const u8,
    field_decl: *const clang.FieldDecl,
) TypeError!Node {
    const field_qt = field_decl.getType();
    const field_qt_canon = qualTypeCanon(field_qt);

    const u8_type = try Tag.type.create(c.arena, "u8");
    const self_param_name = "self";
    const self_param = try Tag.identifier.create(c.arena, self_param_name);
    const self_type = try Tag.typeof.create(c.arena, self_param);

    const fn_params = try c.arena.alloc(ast.Payload.Param, 1);

    fn_params[0] = .{
        .name = self_param_name,
        .type = Tag.@"anytype".init(),
        .is_noalias = false,
    };

    const array_type = @as(*const clang.ArrayType, @ptrCast(field_qt_canon));
    const element_qt = array_type.getElementType();
    const element_type = try transQualType(c, scope, element_qt, field_decl.getLocation());

    var block_scope = try Scope.Block.init(c, scope, false);
    defer block_scope.deinit();

    const intermediate_type_name = try block_scope.makeMangledName(c, "Intermediate");
    const intermediate_type = try Tag.helpers_flexible_array_type.create(c.arena, .{ .lhs = self_type, .rhs = u8_type });
    const intermediate_type_decl = try Tag.var_simple.create(c.arena, .{
        .name = intermediate_type_name,
        .init = intermediate_type,
    });
    try block_scope.statements.append(intermediate_type_decl);
    const intermediate_type_ident = try Tag.identifier.create(c.arena, intermediate_type_name);

    const return_type_name = try block_scope.makeMangledName(c, "ReturnType");
    const return_type = try Tag.helpers_flexible_array_type.create(c.arena, .{ .lhs = self_type, .rhs = element_type });
    const return_type_decl = try Tag.var_simple.create(c.arena, .{
        .name = return_type_name,
        .init = return_type,
    });
    try block_scope.statements.append(return_type_decl);
    const return_type_ident = try Tag.identifier.create(c.arena, return_type_name);

    const field_index = field_decl.getFieldIndex();
    const bit_offset = layout.getFieldOffset(field_index); // this is a target-specific constant based on the struct layout
    const byte_offset = bit_offset / 8;

    const casted_self = try Tag.as.create(c.arena, .{
        .lhs = intermediate_type_ident,
        .rhs = try Tag.ptr_cast.create(c.arena, self_param),
    });
    const field_offset = try transCreateNodeNumber(c, byte_offset, .int);
    const field_ptr = try Tag.add.create(c.arena, .{ .lhs = casted_self, .rhs = field_offset });

    const ptr_cast = try Tag.as.create(c.arena, .{
        .lhs = return_type_ident,
        .rhs = try Tag.ptr_cast.create(
            c.arena,
            try Tag.align_cast.create(
                c.arena,
                field_ptr,
            ),
        ),
    });
    const return_stmt = try Tag.@"return".create(c.arena, ptr_cast);
    try block_scope.statements.append(return_stmt);

    const payload = try c.arena.create(ast.Payload.Func);
    payload.* = .{
        .base = .{ .tag = .func },
        .data = .{
            .is_pub = true,
            .is_extern = false,
            .is_export = false,
            .is_inline = false,
            .is_var_args = false,
            .name = field_name,
            .linksection_string = null,
            .explicit_callconv = null,
            .params = fn_params,
            .return_type = return_type,
            .body = try block_scope.complete(c),
            .alignment = null,
        },
    };
    return Node.initPayload(&payload.base);
}

/// Return true if `field_decl` is the flexible array field for its parent record
fn isFlexibleArrayFieldDecl(c: *Context, field_decl: *const clang.FieldDecl) bool {
    const record_decl = field_decl.getParent() orelse return false;
    const record_flexible_field = flexibleArrayField(c, record_decl) orelse return false;
    return field_decl == record_flexible_field;
}

/// Find the flexible array field for a record if any. A flexible array field is an
/// incomplete or zero-length array that occurs as the last field of a record.
/// clang's RecordDecl::hasFlexibleArrayMember is not suitable for determining
/// this because it returns false for a record that ends with a zero-length
/// array, but we consider those to be flexible arrays
fn flexibleArrayField(c: *Context, record_def: *const clang.RecordDecl) ?*const clang.FieldDecl {
    var it = record_def.field_begin();
    const end_it = record_def.field_end();
    var flexible_field: ?*const clang.FieldDecl = null;
    while (it.neq(end_it)) : (it = it.next()) {
        const field_decl = it.deref();
        const ty = qualTypeCanon(field_decl.getType());
        const incomplete_or_zero_size = ty.isIncompleteOrZeroLengthArrayType(c.clang_context);
        if (incomplete_or_zero_size) {
            flexible_field = field_decl;
        } else {
            flexible_field = null;
        }
    }
    return flexible_field;
}

fn mangleWeakGlobalName(c: *Context, want_name: []const u8) ![]const u8 {
    var cur_name = want_name;

    if (!c.weak_global_names.contains(want_name)) {
        // This type wasn't noticed by the name detection pass, so nothing has been treating this as
        // a weak global name. We must mangle it to avoid conflicts with locals.
        cur_name = try std.fmt.allocPrint(c.arena, "{s}_{d}", .{ want_name, c.getMangle() });
    }

    while (c.global_names.contains(cur_name)) {
        cur_name = try std.fmt.allocPrint(c.arena, "{s}_{d}", .{ want_name, c.getMangle() });
    }
    return cur_name;
}

fn transRecordDecl(c: *Context, scope: *Scope, record_decl: *const clang.RecordDecl) Error!void {
    if (c.decl_table.get(@intFromPtr(record_decl.getCanonicalDecl()))) |_|
        return; // Avoid processing this decl twice
    const record_loc = record_decl.getLocation();
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(c) else undefined;

    var is_union = false;
    var container_kind_name: []const u8 = undefined;
    var bare_name: []const u8 = try c.str(@as(*const clang.NamedDecl, @ptrCast(record_decl)).getName_bytes_begin());

    if (record_decl.isUnion()) {
        container_kind_name = "union";
        is_union = true;
    } else if (record_decl.isStruct()) {
        container_kind_name = "struct";
    } else {
        try c.decl_table.putNoClobber(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), bare_name);
        return failDecl(c, record_loc, bare_name, "record {s} is not a struct or union", .{bare_name});
    }

    var is_unnamed = false;
    var name = bare_name;
    if (c.unnamed_typedefs.get(@intFromPtr(record_decl.getCanonicalDecl()))) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        // Record declarations such as `struct {...} x` have no name but they're not
        // anonymous hence here isAnonymousStructOrUnion is not needed
        if (bare_name.len == 0) {
            bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{d}", .{c.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(c.arena, "{s}_{s}", .{ container_kind_name, bare_name });
        if (toplevel and !is_unnamed) {
            name = try mangleWeakGlobalName(c, name);
        }
    }
    if (!toplevel) name = try bs.makeMangledName(c, name);
    try c.decl_table.putNoClobber(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), name);

    const is_pub = toplevel and !is_unnamed;
    const init_node = blk: {
        const record_def = record_decl.getDefinition() orelse {
            try c.opaque_demotes.put(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), {});
            break :blk Tag.opaque_literal.init();
        };

        var fields = std.ArrayList(ast.Payload.Record.Field).init(c.gpa);
        defer fields.deinit();

        var functions = std.ArrayList(Node).init(c.gpa);
        defer functions.deinit();

        const flexible_field = flexibleArrayField(c, record_def);
        var unnamed_field_count: u32 = 0;
        var it = record_def.field_begin();
        const end_it = record_def.field_end();
        const layout = record_def.getASTRecordLayout(c.clang_context);
        const record_alignment = layout.getAlignment();

        while (it.neq(end_it)) : (it = it.next()) {
            const field_decl = it.deref();
            const field_loc = field_decl.getLocation();
            const field_qt = field_decl.getType();

            if (field_decl.isBitField()) {
                try c.opaque_demotes.put(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), {});
                try warn(c, scope, field_loc, "{s} demoted to opaque type - has bitfield", .{container_kind_name});
                break :blk Tag.opaque_literal.init();
            }

            var is_anon = false;
            var field_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(field_decl)).getName_bytes_begin());
            if (field_decl.isAnonymousStructOrUnion() or field_name.len == 0) {
                // Context.getMangle() is not used here because doing so causes unpredictable field names for anonymous fields.
                field_name = try std.fmt.allocPrint(c.arena, "unnamed_{d}", .{unnamed_field_count});
                unnamed_field_count += 1;
                is_anon = true;
            }
            if (flexible_field == field_decl) {
                const flexible_array_fn = buildFlexibleArrayFn(c, scope, layout, field_name, field_decl) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try c.opaque_demotes.put(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), {});
                        try warn(c, scope, record_loc, "{s} demoted to opaque type - unable to translate type of flexible array field {s}", .{ container_kind_name, field_name });
                        break :blk Tag.opaque_literal.init();
                    },
                    else => |e| return e,
                };
                try functions.append(flexible_array_fn);
                continue;
            }
            const field_type = transQualType(c, scope, field_qt, field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    try c.opaque_demotes.put(c.gpa, @intFromPtr(record_decl.getCanonicalDecl()), {});
                    try warn(c, scope, record_loc, "{s} demoted to opaque type - unable to translate type of field {s}", .{ container_kind_name, field_name });
                    break :blk Tag.opaque_literal.init();
                },
                else => |e| return e,
            };

            const alignment = if (flexible_field != null and field_decl.getFieldIndex() == 0)
                @as(c_uint, @intCast(record_alignment))
            else
                ClangAlignment.forField(c, field_decl, record_def).zigAlignment();

            // C99 introduced designated initializers for structs. Omitted fields are implicitly
            // initialized to zero. Some C APIs are designed with this in mind. Defaulting to zero
            // values for translated struct fields permits Zig code to comfortably use such an API.
            const default_value = if (record_decl.isStruct())
                try Tag.std_mem_zeroes.create(c.arena, field_type)
            else
                null;

            if (is_anon) {
                try c.decl_table.putNoClobber(c.gpa, @intFromPtr(field_decl.getCanonicalDecl()), field_name);
            }

            try fields.append(.{
                .name = field_name,
                .type = field_type,
                .alignment = alignment,
                .default_value = default_value,
            });
        }

        const record_payload = try c.arena.create(ast.Payload.Record);
        record_payload.* = .{
            .base = .{ .tag = ([2]Tag{ .@"struct", .@"union" })[@intFromBool(is_union)] },
            .data = .{
                .layout = .@"extern",
                .fields = try c.arena.dupe(ast.Payload.Record.Field, fields.items),
                .functions = try c.arena.dupe(Node, functions.items),
                .variables = &.{},
            },
        };
        break :blk Node.initPayload(&record_payload.base);
    };

    const payload = try c.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]Tag{ .var_simple, .pub_var_simple })[@intFromBool(is_pub)] },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = Node.initPayload(&payload.base);
    if (toplevel) {
        try addTopLevelDecl(c, name, node);
        // Only add the alias if the name is available *and* it was caught by
        // name detection. Don't bother performing a weak mangle, since a
        // mangled name is of no real use here.
        if (!is_unnamed and !c.global_names.contains(bare_name) and c.weak_global_names.contains(bare_name))
            try c.alias_list.append(.{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(c, name);
        }
    }
}

fn transEnumDecl(c: *Context, scope: *Scope, enum_decl: *const clang.EnumDecl) Error!void {
    if (c.decl_table.get(@intFromPtr(enum_decl.getCanonicalDecl()))) |_|
        return; // Avoid processing this decl twice
    const enum_loc = enum_decl.getLocation();
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(c) else undefined;

    var is_unnamed = false;
    var bare_name: []const u8 = try c.str(@as(*const clang.NamedDecl, @ptrCast(enum_decl)).getName_bytes_begin());
    var name = bare_name;
    if (c.unnamed_typedefs.get(@intFromPtr(enum_decl.getCanonicalDecl()))) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (bare_name.len == 0) {
            bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{d}", .{c.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(c.arena, "enum_{s}", .{bare_name});
        if (toplevel and !is_unnamed) {
            name = try mangleWeakGlobalName(c, name);
        }
    }
    if (!toplevel) name = try bs.makeMangledName(c, name);
    try c.decl_table.putNoClobber(c.gpa, @intFromPtr(enum_decl.getCanonicalDecl()), name);

    const enum_type_node = if (enum_decl.getDefinition()) |enum_def| blk: {
        var it = enum_def.enumerator_begin();
        const end_it = enum_def.enumerator_end();
        while (it.neq(end_it)) : (it = it.next()) {
            const enum_const = it.deref();
            var enum_val_name: []const u8 = try c.str(@as(*const clang.NamedDecl, @ptrCast(enum_const)).getName_bytes_begin());
            if (!toplevel) {
                enum_val_name = try bs.makeMangledName(c, enum_val_name);
            }

            const enum_const_qt = @as(*const clang.ValueDecl, @ptrCast(enum_const)).getType();
            const enum_const_loc = @as(*const clang.Decl, @ptrCast(enum_const)).getLocation();
            const enum_const_type_node: ?Node = transQualType(c, scope, enum_const_qt, enum_const_loc) catch |err| switch (err) {
                error.UnsupportedType => null,
                else => |e| return e,
            };

            const enum_const_def = try Tag.enum_constant.create(c.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                // TODO: as of LLVM 18, the return value from `enum_const.getInitVal` here needs
                // to be freed with a call to its free() method.
                .value = try transCreateNodeAPInt(c, enum_const.getInitVal()),
            });
            if (toplevel)
                try addTopLevelDecl(c, enum_val_name, enum_const_def)
            else {
                try scope.appendNode(enum_const_def);
                try bs.discardVariable(c, enum_val_name);
            }
        }

        const int_type = enum_decl.getIntegerType();
        // The underlying type may be null in case of forward-declared enum
        // types, while that's not ISO-C compliant many compilers allow this and
        // default to the usual integer type used for all the enums.

        // default to c_int since msvc and gcc default to different types
        break :blk if (int_type.ptr != null)
            transQualType(c, scope, int_type, enum_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, enum_loc, name, "unable to translate enum integer type", .{});
                },
                else => |e| return e,
            }
        else
            try Tag.type.create(c.arena, "c_int");
    } else blk: {
        try c.opaque_demotes.put(c.gpa, @intFromPtr(enum_decl.getCanonicalDecl()), {});
        break :blk Tag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try c.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = ([2]Tag{ .var_simple, .pub_var_simple })[@intFromBool(is_pub)] },
        .data = .{
            .init = enum_type_node,
            .name = name,
        },
    };
    const node = Node.initPayload(&payload.base);
    if (toplevel) {
        try addTopLevelDecl(c, name, node);
        // Only add the alias if the name is available *and* it was caught by
        // name detection. Don't bother performing a weak mangle, since a
        // mangled name is of no real use here.
        if (!is_unnamed and !c.global_names.contains(bare_name) and c.weak_global_names.contains(bare_name))
            try c.alias_list.append(.{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        if (node.tag() != .pub_var_simple) {
            try bs.discardVariable(c, name);
        }
    }
}

fn transStmt(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.Stmt,
    result_used: ResultUsed,
) TransError!Node {
    const sc = stmt.getStmtClass();
    switch (sc) {
        .BinaryOperatorClass => return transBinaryOperator(c, scope, @as(*const clang.BinaryOperator, @ptrCast(stmt)), result_used),
        .CompoundStmtClass => return transCompoundStmt(c, scope, @as(*const clang.CompoundStmt, @ptrCast(stmt))),
        .CStyleCastExprClass => return transCStyleCastExprClass(c, scope, @as(*const clang.CStyleCastExpr, @ptrCast(stmt)), result_used),
        .DeclStmtClass => return transDeclStmt(c, scope, @as(*const clang.DeclStmt, @ptrCast(stmt))),
        .DeclRefExprClass => return transDeclRefExpr(c, scope, @as(*const clang.DeclRefExpr, @ptrCast(stmt))),
        .ImplicitCastExprClass => return transImplicitCastExpr(c, scope, @as(*const clang.ImplicitCastExpr, @ptrCast(stmt)), result_used),
        .IntegerLiteralClass => return transIntegerLiteral(c, scope, @as(*const clang.IntegerLiteral, @ptrCast(stmt)), result_used, .with_as),
        .ReturnStmtClass => return transReturnStmt(c, scope, @as(*const clang.ReturnStmt, @ptrCast(stmt))),
        .StringLiteralClass => return transStringLiteral(c, scope, @as(*const clang.StringLiteral, @ptrCast(stmt)), result_used),
        .ParenExprClass => {
            const expr = try transExpr(c, scope, @as(*const clang.ParenExpr, @ptrCast(stmt)).getSubExpr(), .used);
            return maybeSuppressResult(c, result_used, expr);
        },
        .InitListExprClass => return transInitListExpr(c, scope, @as(*const clang.InitListExpr, @ptrCast(stmt)), result_used),
        .ImplicitValueInitExprClass => return transImplicitValueInitExpr(c, scope, @as(*const clang.Expr, @ptrCast(stmt))),
        .IfStmtClass => return transIfStmt(c, scope, @as(*const clang.IfStmt, @ptrCast(stmt))),
        .WhileStmtClass => return transWhileLoop(c, scope, @as(*const clang.WhileStmt, @ptrCast(stmt))),
        .DoStmtClass => return transDoWhileLoop(c, scope, @as(*const clang.DoStmt, @ptrCast(stmt))),
        .NullStmtClass => {
            return Tag.empty_block.init();
        },
        .ContinueStmtClass => return Tag.@"continue".init(),
        .BreakStmtClass => return Tag.@"break".init(),
        .ForStmtClass => return transForLoop(c, scope, @as(*const clang.ForStmt, @ptrCast(stmt))),
        .FloatingLiteralClass => return transFloatingLiteral(c, @as(*const clang.FloatingLiteral, @ptrCast(stmt)), result_used),
        .ConditionalOperatorClass => {
            return transConditionalOperator(c, scope, @as(*const clang.ConditionalOperator, @ptrCast(stmt)), result_used);
        },
        .BinaryConditionalOperatorClass => {
            return transBinaryConditionalOperator(c, scope, @as(*const clang.BinaryConditionalOperator, @ptrCast(stmt)), result_used);
        },
        .SwitchStmtClass => return transSwitch(c, scope, @as(*const clang.SwitchStmt, @ptrCast(stmt))),
        .CaseStmtClass, .DefaultStmtClass => {
            return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "TODO complex switch", .{});
        },
        .ConstantExprClass => return transConstantExpr(c, scope, @as(*const clang.Expr, @ptrCast(stmt)), result_used),
        .PredefinedExprClass => return transPredefinedExpr(c, scope, @as(*const clang.PredefinedExpr, @ptrCast(stmt)), result_used),
        .CharacterLiteralClass => return transCharLiteral(c, scope, @as(*const clang.CharacterLiteral, @ptrCast(stmt)), result_used, .with_as),
        .StmtExprClass => return transStmtExpr(c, scope, @as(*const clang.StmtExpr, @ptrCast(stmt)), result_used),
        .MemberExprClass => return transMemberExpr(c, scope, @as(*const clang.MemberExpr, @ptrCast(stmt)), result_used),
        .ArraySubscriptExprClass => return transArrayAccess(c, scope, @as(*const clang.ArraySubscriptExpr, @ptrCast(stmt)), result_used),
        .CallExprClass => return transCallExpr(c, scope, @as(*const clang.CallExpr, @ptrCast(stmt)), result_used),
        .UnaryExprOrTypeTraitExprClass => return transUnaryExprOrTypeTraitExpr(c, scope, @as(*const clang.UnaryExprOrTypeTraitExpr, @ptrCast(stmt)), result_used),
        .UnaryOperatorClass => return transUnaryOperator(c, scope, @as(*const clang.UnaryOperator, @ptrCast(stmt)), result_used),
        .CompoundAssignOperatorClass => return transCompoundAssignOperator(c, scope, @as(*const clang.CompoundAssignOperator, @ptrCast(stmt)), result_used),
        .OpaqueValueExprClass => {
            const source_expr = @as(*const clang.OpaqueValueExpr, @ptrCast(stmt)).getSourceExpr().?;
            const expr = try transExpr(c, scope, source_expr, .used);
            return maybeSuppressResult(c, result_used, expr);
        },
        .OffsetOfExprClass => return transOffsetOfExpr(c, @as(*const clang.OffsetOfExpr, @ptrCast(stmt)), result_used),
        .CompoundLiteralExprClass => {
            const compound_literal = @as(*const clang.CompoundLiteralExpr, @ptrCast(stmt));
            return transExpr(c, scope, compound_literal.getInitializer(), result_used);
        },
        .GenericSelectionExprClass => {
            const gen_sel = @as(*const clang.GenericSelectionExpr, @ptrCast(stmt));
            return transExpr(c, scope, gen_sel.getResultExpr(), result_used);
        },
        .ConvertVectorExprClass => {
            const conv_vec = @as(*const clang.ConvertVectorExpr, @ptrCast(stmt));
            const conv_vec_node = try transConvertVectorExpr(c, scope, conv_vec);
            return maybeSuppressResult(c, result_used, conv_vec_node);
        },
        .ShuffleVectorExprClass => {
            const shuffle_vec_expr = @as(*const clang.ShuffleVectorExpr, @ptrCast(stmt));
            const shuffle_vec_node = try transShuffleVectorExpr(c, scope, shuffle_vec_expr);
            return maybeSuppressResult(c, result_used, shuffle_vec_node);
        },
        .ChooseExprClass => {
            const choose_expr = @as(*const clang.ChooseExpr, @ptrCast(stmt));
            return transExpr(c, scope, choose_expr.getChosenSubExpr(), result_used);
        },
        // When adding new cases here, see comment for maybeBlockify()
        .GCCAsmStmtClass,
        .GotoStmtClass,
        .IndirectGotoStmtClass,
        .AttributedStmtClass,
        .AddrLabelExprClass,
        .AtomicExprClass,
        .BlockExprClass,
        .UserDefinedLiteralClass,
        .BuiltinBitCastExprClass,
        .DesignatedInitExprClass,
        .LabelStmtClass,
        => return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "TODO implement translation of stmt class {s}", .{@tagName(sc)}),
        else => return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "unsupported stmt class {s}", .{@tagName(sc)}),
    }
}

/// See https://clang.llvm.org/docs/LanguageExtensions.html#langext-builtin-convertvector
fn transConvertVectorExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.ConvertVectorExpr,
) TransError!Node {
    const base_stmt = @as(*const clang.Stmt, @ptrCast(expr));

    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const src_expr = expr.getSrcExpr();
    const src_type = qualTypeCanon(src_expr.getType());
    const src_vector_ty = @as(*const clang.VectorType, @ptrCast(src_type));
    const src_element_qt = src_vector_ty.getElementType();

    const src_expr_node = try transExpr(c, &block_scope.base, src_expr, .used);

    const dst_qt = expr.getTypeSourceInfo_getType();
    const dst_type_node = try transQualType(c, &block_scope.base, dst_qt, base_stmt.getBeginLoc());
    const dst_vector_ty = @as(*const clang.VectorType, @ptrCast(qualTypeCanon(dst_qt)));
    const num_elements = dst_vector_ty.getNumElements();
    const dst_element_qt = dst_vector_ty.getElementType();

    // workaround for https://github.com/ziglang/zig/issues/8322
    // we store the casted results into temp variables and use those
    // to initialize the vector. Eventually we can just directly
    // construct the init_list from casted source members
    var i: usize = 0;
    while (i < num_elements) : (i += 1) {
        const mangled_name = try block_scope.makeMangledName(c, "tmp");
        const value = try Tag.array_access.create(c.arena, .{
            .lhs = src_expr_node,
            .rhs = try transCreateNodeNumber(c, i, .int),
        });
        const tmp_decl_node = try Tag.var_simple.create(c.arena, .{
            .name = mangled_name,
            .init = try transCCast(c, &block_scope.base, base_stmt.getBeginLoc(), dst_element_qt, src_element_qt, value),
        });
        try block_scope.statements.append(tmp_decl_node);
    }

    const init_list = try c.arena.alloc(Node, num_elements);
    for (init_list, 0..) |*init, init_index| {
        const tmp_decl = block_scope.statements.items[init_index];
        const name = tmp_decl.castTag(.var_simple).?.data.name;
        init.* = try Tag.identifier.create(c.arena, name);
    }

    const vec_init = try Tag.array_init.create(c.arena, .{
        .cond = dst_type_node,
        .cases = init_list,
    });

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = vec_init,
    });
    try block_scope.statements.append(break_node);
    return block_scope.complete(c);
}

fn makeShuffleMask(c: *Context, scope: *Scope, expr: *const clang.ShuffleVectorExpr, vector_len: Node) TransError!Node {
    const num_subexprs = expr.getNumSubExprs();
    assert(num_subexprs >= 3); // two source vectors + at least 1 index expression
    const mask_len = num_subexprs - 2;

    const mask_type = try Tag.vector.create(c.arena, .{
        .lhs = try transCreateNodeNumber(c, mask_len, .int),
        .rhs = try Tag.type.create(c.arena, "i32"),
    });

    const init_list = try c.arena.alloc(Node, mask_len);

    for (init_list, 0..) |*init, i| {
        const index_expr = try transExprCoercing(c, scope, expr.getExpr(@as(c_uint, @intCast(i + 2))), .used);
        const converted_index = try Tag.helpers_shuffle_vector_index.create(c.arena, .{ .lhs = index_expr, .rhs = vector_len });
        init.* = converted_index;
    }

    return Tag.array_init.create(c.arena, .{
        .cond = mask_type,
        .cases = init_list,
    });
}

/// @typeInfo(@TypeOf(vec_node)).Vector.<field>
fn vectorTypeInfo(arena: mem.Allocator, vec_node: Node, field: []const u8) TransError!Node {
    const typeof_call = try Tag.typeof.create(arena, vec_node);
    const typeinfo_call = try Tag.typeinfo.create(arena, typeof_call);
    const vector_type_info = try Tag.field_access.create(arena, .{ .lhs = typeinfo_call, .field_name = "Vector" });
    return Tag.field_access.create(arena, .{ .lhs = vector_type_info, .field_name = field });
}

fn transShuffleVectorExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.ShuffleVectorExpr,
) TransError!Node {
    const base_expr = @as(*const clang.Expr, @ptrCast(expr));
    const num_subexprs = expr.getNumSubExprs();
    if (num_subexprs < 3) return fail(c, error.UnsupportedTranslation, base_expr.getBeginLoc(), "ShuffleVector needs at least 1 index", .{});

    const a = try transExpr(c, scope, expr.getExpr(0), .used);
    const b = try transExpr(c, scope, expr.getExpr(1), .used);

    // clang requires first two arguments to __builtin_shufflevector to be same type
    const vector_child_type = try vectorTypeInfo(c.arena, a, "child");
    const vector_len = try vectorTypeInfo(c.arena, a, "len");
    const shuffle_mask = try makeShuffleMask(c, scope, expr, vector_len);

    return Tag.shuffle.create(c.arena, .{
        .element_type = vector_child_type,
        .a = a,
        .b = b,
        .mask_vector = shuffle_mask,
    });
}

/// Translate a "simple" offsetof expression containing exactly one component,
/// when that component is of kind .Field - e.g. offsetof(mytype, myfield)
fn transSimpleOffsetOfExpr(c: *Context, expr: *const clang.OffsetOfExpr) TransError!Node {
    assert(expr.getNumComponents() == 1);
    const component = expr.getComponent(0);
    if (component.getKind() == .Field) {
        const field_decl = component.getField();
        if (field_decl.getParent()) |record_decl| {
            if (c.decl_table.get(@intFromPtr(record_decl.getCanonicalDecl()))) |type_name| {
                const type_node = try Tag.type.create(c.arena, type_name);

                const raw_field_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(field_decl)).getName_bytes_begin());
                const quoted_field_name = try std.fmt.allocPrint(c.arena, "\"{s}\"", .{raw_field_name});
                const field_name_node = try Tag.string_literal.create(c.arena, quoted_field_name);

                return Tag.offset_of.create(c.arena, .{
                    .lhs = type_node,
                    .rhs = field_name_node,
                });
            }
        }
    }
    return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "failed to translate simple OffsetOfExpr", .{});
}

fn transOffsetOfExpr(
    c: *Context,
    expr: *const clang.OffsetOfExpr,
    result_used: ResultUsed,
) TransError!Node {
    if (expr.getNumComponents() == 1) {
        const offsetof_expr = try transSimpleOffsetOfExpr(c, expr);
        return maybeSuppressResult(c, result_used, offsetof_expr);
    }

    // TODO implement OffsetOfExpr with more than 1 component
    // OffsetOfExpr API:
    //     call expr.getComponent(idx) while idx < expr.getNumComponents()
    //     component.getKind() will be either .Array or .Field (other kinds are C++-only)
    //     if .Field, use component.getField() to retrieve *clang.FieldDecl
    //     if .Array, use component.getArrayExprIndex() to get a c_uint which
    //         can be passed to expr.getIndexExpr(expr_index) to get the *clang.Expr for the array index

    return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "TODO: implement complex OffsetOfExpr translation", .{});
}

/// Cast a signed integer node to a usize, for use in pointer arithmetic. Negative numbers
/// will become very large positive numbers but that is ok since we only use this in
/// pointer arithmetic expressions, where wraparound will ensure we get the correct value.
/// node -> @bitCast(usize, @intCast(isize, node))
fn usizeCastForWrappingPtrArithmetic(gpa: mem.Allocator, node: Node) TransError!Node {
    const intcast_node = try Tag.as.create(gpa, .{
        .lhs = try Tag.type.create(gpa, "isize"),
        .rhs = try Tag.int_cast.create(gpa, node),
    });

    return Tag.as.create(gpa, .{
        .lhs = try Tag.type.create(gpa, "usize"),
        .rhs = try Tag.bit_cast.create(gpa, intcast_node),
    });
}

/// Translate an arithmetic expression with a pointer operand and a signed-integer operand.
/// Zig requires a usize argument for pointer arithmetic, so we intCast to isize and then
/// bitcast to usize; pointer wraparound make the math work.
/// Zig pointer addition is not commutative (unlike C); the pointer operand needs to be on the left.
/// The + operator in C is not a sequence point so it should be safe to switch the order if necessary.
fn transCreatePointerArithmeticSignedOp(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.BinaryOperator,
    result_used: ResultUsed,
) TransError!Node {
    const is_add = stmt.getOpcode() == .Add;
    const lhs = stmt.getLHS();
    const rhs = stmt.getRHS();
    const swap_operands = is_add and cIsSignedInteger(getExprQualType(c, lhs));

    const swizzled_lhs = if (swap_operands) rhs else lhs;
    const swizzled_rhs = if (swap_operands) lhs else rhs;

    const lhs_node = try transExpr(c, scope, swizzled_lhs, .used);
    const rhs_node = try transExpr(c, scope, swizzled_rhs, .used);

    const bitcast_node = try usizeCastForWrappingPtrArithmetic(c.arena, rhs_node);

    return transCreateNodeInfixOp(
        c,
        if (is_add) .add else .sub,
        lhs_node,
        bitcast_node,
        result_used,
    );
}

fn transBinaryOperator(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.BinaryOperator,
    result_used: ResultUsed,
) TransError!Node {
    const op = stmt.getOpcode();
    const qt = stmt.getType();
    const isPointerDiffExpr = cIsPointerDiffExpr(stmt);
    switch (op) {
        .Assign => return try transCreateNodeAssign(c, scope, result_used, stmt.getLHS(), stmt.getRHS()),
        .Comma => {
            var block_scope = try Scope.Block.init(c, scope, true);
            defer block_scope.deinit();

            const lhs = try transExpr(c, &block_scope.base, stmt.getLHS(), .unused);
            try block_scope.statements.append(lhs);

            const rhs = try transExpr(c, &block_scope.base, stmt.getRHS(), .used);
            const break_node = try Tag.break_val.create(c.arena, .{
                .label = block_scope.label,
                .val = rhs,
            });
            try block_scope.statements.append(break_node);
            const block_node = try block_scope.complete(c);
            return maybeSuppressResult(c, result_used, block_node);
        },
        .Div => {
            if (cIsSignedInteger(qt)) {
                // signed integer division uses @divTrunc
                const lhs = try transExpr(c, scope, stmt.getLHS(), .used);
                const rhs = try transExpr(c, scope, stmt.getRHS(), .used);
                const div_trunc = try Tag.div_trunc.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
                return maybeSuppressResult(c, result_used, div_trunc);
            }
        },
        .Rem => {
            if (cIsSignedInteger(qt)) {
                // signed integer remainder uses std.zig.c_translation.signedRemainder
                const lhs = try transExpr(c, scope, stmt.getLHS(), .used);
                const rhs = try transExpr(c, scope, stmt.getRHS(), .used);
                const rem = try Tag.signed_remainder.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
                return maybeSuppressResult(c, result_used, rem);
            }
        },
        .Shl => {
            return transCreateNodeShiftOp(c, scope, stmt, .shl, result_used);
        },
        .Shr => {
            return transCreateNodeShiftOp(c, scope, stmt, .shr, result_used);
        },
        .LAnd => {
            return transCreateNodeBoolInfixOp(c, scope, stmt, .@"and", result_used);
        },
        .LOr => {
            return transCreateNodeBoolInfixOp(c, scope, stmt, .@"or", result_used);
        },
        .Add, .Sub => {
            // `ptr + idx` and `idx + ptr` -> ptr + @bitCast(usize, @intCast(isize, idx))
            // `ptr - idx` -> ptr - @bitCast(usize, @intCast(isize, idx))
            if (qualTypeIsPtr(qt) and (cIsSignedInteger(getExprQualType(c, stmt.getLHS())) or
                cIsSignedInteger(getExprQualType(c, stmt.getRHS())))) return transCreatePointerArithmeticSignedOp(c, scope, stmt, result_used);
        },
        else => {},
    }
    var op_id: Tag = undefined;
    switch (op) {
        .Add => {
            if (cIsUnsignedInteger(qt)) {
                op_id = .add_wrap;
            } else {
                op_id = .add;
            }
        },
        .Sub => {
            if (cIsUnsignedInteger(qt) or isPointerDiffExpr) {
                op_id = .sub_wrap;
            } else {
                op_id = .sub;
            }
        },
        .Mul => {
            if (cIsUnsignedInteger(qt)) {
                op_id = .mul_wrap;
            } else {
                op_id = .mul;
            }
        },
        .Div => {
            // unsigned/float division uses the operator
            op_id = .div;
        },
        .Rem => {
            // unsigned/float division uses the operator
            op_id = .mod;
        },
        .LT => {
            op_id = .less_than;
        },
        .GT => {
            op_id = .greater_than;
        },
        .LE => {
            op_id = .less_than_equal;
        },
        .GE => {
            op_id = .greater_than_equal;
        },
        .EQ => {
            op_id = .equal;
        },
        .NE => {
            op_id = .not_equal;
        },
        .And => {
            op_id = .bit_and;
        },
        .Xor => {
            op_id = .bit_xor;
        },
        .Or => {
            op_id = .bit_or;
        },
        else => unreachable,
    }

    const lhs_uncasted = try transExpr(c, scope, stmt.getLHS(), .used);
    const rhs_uncasted = try transExpr(c, scope, stmt.getRHS(), .used);

    const lhs = if (isBoolRes(lhs_uncasted))
        try Tag.int_from_bool.create(c.arena, lhs_uncasted)
    else if (isPointerDiffExpr)
        try Tag.int_from_ptr.create(c.arena, lhs_uncasted)
    else
        lhs_uncasted;

    const rhs = if (isBoolRes(rhs_uncasted))
        try Tag.int_from_bool.create(c.arena, rhs_uncasted)
    else if (isPointerDiffExpr)
        try Tag.int_from_ptr.create(c.arena, rhs_uncasted)
    else
        rhs_uncasted;

    const infixOpNode = try transCreateNodeInfixOp(c, op_id, lhs, rhs, result_used);
    if (isPointerDiffExpr) {
        // @divExact(@bitCast(<platform-ptrdiff_t>, @intFromPtr(lhs) -% @intFromPtr(rhs)), @sizeOf(<lhs target type>))
        const ptrdiff_type = try transQualTypeIntWidthOf(c, qt, true);

        // C standard requires that pointer subtraction operands are of the same type,
        // otherwise it is undefined behavior. So we can assume the left and right
        // sides are the same QualType and arbitrarily choose left.
        const lhs_expr = stmt.getLHS();
        const lhs_qt = getExprQualType(c, lhs_expr);
        const lhs_qt_translated = try transQualType(c, scope, lhs_qt, lhs_expr.getBeginLoc());
        const c_pointer = getContainer(c, lhs_qt_translated).?;
        const elem_type = c_pointer.castTag(.c_pointer).?.data.elem_type;
        const sizeof = try Tag.sizeof.create(c.arena, elem_type);

        const bitcast = try Tag.as.create(c.arena, .{
            .lhs = ptrdiff_type,
            .rhs = try Tag.bit_cast.create(c.arena, infixOpNode),
        });

        return Tag.div_exact.create(c.arena, .{
            .lhs = bitcast,
            .rhs = sizeof,
        });
    }
    return infixOpNode;
}

fn transCompoundStmtInline(
    c: *Context,
    stmt: *const clang.CompoundStmt,
    block: *Scope.Block,
) TransError!void {
    var it = stmt.body_begin();
    const end_it = stmt.body_end();
    while (it != end_it) : (it += 1) {
        const result = try transStmt(c, &block.base, it[0], .unused);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block.statements.append(result),
        }
    }
}

fn transCompoundStmt(c: *Context, scope: *Scope, stmt: *const clang.CompoundStmt) TransError!Node {
    var block_scope = try Scope.Block.init(c, scope, false);
    defer block_scope.deinit();
    try transCompoundStmtInline(c, stmt, &block_scope);
    return try block_scope.complete(c);
}

fn transCStyleCastExprClass(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.CStyleCastExpr,
    result_used: ResultUsed,
) TransError!Node {
    const cast_expr = @as(*const clang.CastExpr, @ptrCast(stmt));
    const sub_expr = stmt.getSubExpr();
    const dst_type = stmt.getType();
    const src_type = sub_expr.getType();
    const sub_expr_node = try transExpr(c, scope, sub_expr, .used);
    const loc = stmt.getBeginLoc();

    const cast_node = if (cast_expr.getCastKind() == .ToUnion) blk: {
        const field_decl = cast_expr.getTargetFieldForToUnionCast(dst_type, src_type).?; // C syntax error if target field is null
        const field_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(field_decl)).getName_bytes_begin());

        const union_ty = try transQualType(c, scope, dst_type, loc);

        const inits = [1]ast.Payload.ContainerInit.Initializer{.{ .name = field_name, .value = sub_expr_node }};
        break :blk try Tag.container_init.create(c.arena, .{
            .lhs = union_ty,
            .inits = try c.arena.dupe(ast.Payload.ContainerInit.Initializer, &inits),
        });
    } else (try transCCast(
        c,
        scope,
        loc,
        dst_type,
        src_type,
        sub_expr_node,
    ));
    return maybeSuppressResult(c, result_used, cast_node);
}

/// The alignment of a variable or field
const ClangAlignment = struct {
    /// Clang reports the alignment in bits, we use bytes
    /// Clang uses 0 for "no alignment specified", we use null
    bit_alignment: c_uint,
    /// If the field or variable is marked as 'packed'
    ///
    /// According to the GCC variable attribute docs, this impacts alignment
    /// https://gcc.gnu.org/onlinedocs/gcc/Common-Variable-Attributes.html
    ///
    /// > The packed attribute specifies that a structure member
    /// > should have the smallest possible alignment
    ///
    /// Note also that specifying the 'packed' attribute on a structure
    /// implicitly packs all its fields (making their alignment 1).
    ///
    /// This will be null if the AST node doesn't support packing (functions)
    is_packed: ?bool,

    /// Get the alignment for a field, optionally taking into account the parent record
    pub fn forField(c: *const Context, field: *const clang.FieldDecl, parent: ?*const clang.RecordDecl) ClangAlignment {
        const parent_packed = if (parent) |record| record.getPackedAttribute() else false;
        // NOTE: According to GCC docs, parent attribute packed implies child attribute packed
        return ClangAlignment{
            .bit_alignment = field.getAlignedAttribute(c.clang_context),
            .is_packed = field.getPackedAttribute() or parent_packed,
        };
    }

    pub fn forVar(c: *const Context, var_decl: *const clang.VarDecl) ClangAlignment {
        return ClangAlignment{
            .bit_alignment = var_decl.getAlignedAttribute(c.clang_context),
            .is_packed = var_decl.getPackedAttribute(),
        };
    }

    pub fn forFunc(c: *const Context, fun: *const clang.FunctionDecl) ClangAlignment {
        return ClangAlignment{
            .bit_alignment = fun.getAlignedAttribute(c.clang_context),
            .is_packed = null, // not supported by GCC/clang (or meaningful),
        };
    }

    /// Translate the clang alignment info into a zig alignment
    ///
    /// Returns null if there is no special alignment info
    pub fn zigAlignment(self: ClangAlignment) ?c_uint {
        if (self.bit_alignment != 0) {
            return self.bit_alignment / 8;
        } else if (self.is_packed orelse false) {
            return 1;
        } else {
            return null;
        }
    }
};

fn transDeclStmtOne(
    c: *Context,
    scope: *Scope,
    decl: *const clang.Decl,
    block_scope: *Scope.Block,
) TransError!void {
    switch (decl.getKind()) {
        .Var => {
            const var_decl = @as(*const clang.VarDecl, @ptrCast(decl));
            const decl_init = var_decl.getInit();
            const loc = decl.getLocation();

            const qual_type = var_decl.getTypeSourceInfo_getType();
            const name = try c.str(@as(*const clang.NamedDecl, @ptrCast(var_decl)).getName_bytes_begin());
            const mangled_name = try block_scope.makeMangledName(c, name);

            if (var_decl.getStorageClass() == .Extern) {
                // This is actually a global variable, put it in the global scope and reference it.
                // `_ = mangled_name;`
                return visitVarDecl(c, var_decl, mangled_name);
            } else if (qualTypeWasDemotedToOpaque(c, qual_type)) {
                return fail(c, error.UnsupportedTranslation, loc, "local variable has opaque type", .{});
            }

            const is_static_local = var_decl.isStaticLocal();
            const is_const = qual_type.isConstQualified();
            const type_node = try transQualTypeMaybeInitialized(c, scope, qual_type, decl_init, loc);

            var init_node = if (decl_init) |expr|
                if (expr.getStmtClass() == .StringLiteralClass)
                    try transStringLiteralInitializer(c, @as(*const clang.StringLiteral, @ptrCast(expr)), type_node)
                else
                    try transExprCoercing(c, scope, expr, .used)
            else if (is_static_local)
                try Tag.std_mem_zeroes.create(c.arena, type_node)
            else
                Tag.undefined_literal.init();
            if (!qualTypeIsBoolean(qual_type) and isBoolRes(init_node)) {
                init_node = try Tag.int_from_bool.create(c.arena, init_node);
            } else if (init_node.tag() == .string_literal and qualTypeIsCharStar(qual_type)) {
                const dst_type_node = try transQualType(c, scope, qual_type, loc);
                init_node = try removeCVQualifiers(c, dst_type_node, init_node);
            }

            const var_name: []const u8 = if (is_static_local) Scope.Block.static_inner_name else mangled_name;
            var node = try Tag.var_decl.create(c.arena, .{
                .is_pub = false,
                .is_const = is_const,
                .is_extern = false,
                .is_export = false,
                .is_threadlocal = var_decl.getTLSKind() != .None,
                .linksection_string = null,
                .alignment = ClangAlignment.forVar(c, var_decl).zigAlignment(),
                .name = var_name,
                .type = type_node,
                .init = init_node,
            });
            if (is_static_local) {
                node = try Tag.static_local_var.create(c.arena, .{ .name = mangled_name, .init = node });
            }
            try block_scope.statements.append(node);
            try block_scope.discardVariable(c, mangled_name);

            const cleanup_attr = var_decl.getCleanupAttribute();
            if (cleanup_attr) |fn_decl| {
                const cleanup_fn_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(fn_decl)).getName_bytes_begin());
                const fn_id = try Tag.identifier.create(c.arena, cleanup_fn_name);

                const varname = try Tag.identifier.create(c.arena, mangled_name);
                const args = try c.arena.alloc(Node, 1);
                args[0] = try Tag.address_of.create(c.arena, varname);

                const cleanup_call = try Tag.call.create(c.arena, .{ .lhs = fn_id, .args = args });
                const discard = try Tag.discard.create(c.arena, .{ .should_skip = false, .value = cleanup_call });
                const deferred_cleanup = try Tag.@"defer".create(c.arena, discard);

                try block_scope.statements.append(deferred_cleanup);
            }
        },
        .Typedef => {
            try transTypeDef(c, scope, @as(*const clang.TypedefNameDecl, @ptrCast(decl)));
        },
        .Record => {
            try transRecordDecl(c, scope, @as(*const clang.RecordDecl, @ptrCast(decl)));
        },
        .Enum => {
            try transEnumDecl(c, scope, @as(*const clang.EnumDecl, @ptrCast(decl)));
        },
        .Function => {
            try visitFnDecl(c, @as(*const clang.FunctionDecl, @ptrCast(decl)));
        },
        else => {
            const decl_name = try c.str(decl.getDeclKindName());
            try warn(c, &c.global_scope.base, decl.getLocation(), "ignoring {s} declaration", .{decl_name});
        },
    }
}

fn transDeclStmt(c: *Context, scope: *Scope, stmt: *const clang.DeclStmt) TransError!Node {
    const block_scope = try scope.findBlockScope(c);

    var it = stmt.decl_begin();
    const end_it = stmt.decl_end();
    while (it != end_it) : (it += 1) {
        try transDeclStmtOne(c, scope, it[0], block_scope);
    }
    return Tag.declaration.init();
}

fn transDeclRefExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.DeclRefExpr,
) TransError!Node {
    const value_decl = expr.getDecl();
    const name = try c.str(@as(*const clang.NamedDecl, @ptrCast(value_decl)).getName_bytes_begin());
    const mangled_name = scope.getAlias(name);
    var ref_expr = if (cIsFunctionDeclRef(@as(*const clang.Expr, @ptrCast(expr))))
        try Tag.fn_identifier.create(c.arena, mangled_name)
    else
        try Tag.identifier.create(c.arena, mangled_name);

    if (@as(*const clang.Decl, @ptrCast(value_decl)).getKind() == .Var) {
        const var_decl = @as(*const clang.VarDecl, @ptrCast(value_decl));
        if (var_decl.isStaticLocal()) {
            ref_expr = try Tag.field_access.create(c.arena, .{
                .lhs = ref_expr,
                .field_name = Scope.Block.static_inner_name,
            });
        }
    }
    scope.skipVariableDiscard(mangled_name);
    return ref_expr;
}

fn transImplicitCastExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.ImplicitCastExpr,
    result_used: ResultUsed,
) TransError!Node {
    const sub_expr = expr.getSubExpr();
    const dest_type = getExprQualType(c, @as(*const clang.Expr, @ptrCast(expr)));
    const src_type = getExprQualType(c, sub_expr);
    switch (expr.getCastKind()) {
        .BitCast, .FloatingCast, .FloatingToIntegral, .IntegralToFloating, .IntegralCast, .PointerToIntegral, .IntegralToPointer => {
            const sub_expr_node = try transExpr(c, scope, sub_expr, .used);
            const casted = try transCCast(c, scope, expr.getBeginLoc(), dest_type, src_type, sub_expr_node);
            return maybeSuppressResult(c, result_used, casted);
        },
        .LValueToRValue, .NoOp, .FunctionToPointerDecay => {
            const sub_expr_node = try transExpr(c, scope, sub_expr, .used);
            return maybeSuppressResult(c, result_used, sub_expr_node);
        },
        .ArrayToPointerDecay => {
            const sub_expr_node = try transExpr(c, scope, sub_expr, .used);
            if (exprIsNarrowStringLiteral(sub_expr) or exprIsFlexibleArrayRef(c, sub_expr)) {
                return maybeSuppressResult(c, result_used, sub_expr_node);
            }

            const addr = try Tag.address_of.create(c.arena, sub_expr_node);
            const casted = try transCPtrCast(c, scope, expr.getBeginLoc(), dest_type, src_type, addr);
            return maybeSuppressResult(c, result_used, casted);
        },
        .NullToPointer => {
            return Tag.null_literal.init();
        },
        .PointerToBoolean => {
            // @intFromPtr(val) != 0
            const ptr_node = try transExpr(c, scope, sub_expr, .used);
            const int_from_ptr = try Tag.int_from_ptr.create(c.arena, ptr_node);

            const ne = try Tag.not_equal.create(c.arena, .{ .lhs = int_from_ptr, .rhs = Tag.zero_literal.init() });
            return maybeSuppressResult(c, result_used, ne);
        },
        .IntegralToBoolean, .FloatingToBoolean => {
            const sub_expr_node = try transExpr(c, scope, sub_expr, .used);

            // The expression is already a boolean one, return it as-is
            if (isBoolRes(sub_expr_node))
                return maybeSuppressResult(c, result_used, sub_expr_node);

            // val != 0
            const ne = try Tag.not_equal.create(c.arena, .{ .lhs = sub_expr_node, .rhs = Tag.zero_literal.init() });
            return maybeSuppressResult(c, result_used, ne);
        },
        .BuiltinFnToFnPtr => {
            return transBuiltinFnExpr(c, scope, sub_expr, result_used);
        },
        .ToVoid => {
            // Should only appear in the rhs and lhs of a ConditionalOperator
            return transExpr(c, scope, sub_expr, .unused);
        },
        else => |kind| return fail(
            c,
            error.UnsupportedTranslation,
            @as(*const clang.Stmt, @ptrCast(expr)).getBeginLoc(),
            "unsupported CastKind {s}",
            .{@tagName(kind)},
        ),
    }
}

fn isBuiltinDefined(name: []const u8) bool {
    inline for (@typeInfo(std.zig.c_builtins).Struct.decls) |decl| {
        if (std.mem.eql(u8, name, decl.name)) return true;
    }
    return false;
}

fn transBuiltinFnExpr(c: *Context, scope: *Scope, expr: *const clang.Expr, used: ResultUsed) TransError!Node {
    const node = try transExpr(c, scope, expr, used);
    if (node.castTag(.fn_identifier)) |ident| {
        const name = ident.data;
        if (!isBuiltinDefined(name)) return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "TODO implement function '{s}' in std.zig.c_builtins", .{name});
    }
    return node;
}

fn transBoolExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.Expr,
    used: ResultUsed,
) TransError!Node {
    if (@as(*const clang.Stmt, @ptrCast(expr)).getStmtClass() == .IntegerLiteralClass) {
        var signum: c_int = undefined;
        if (!(@as(*const clang.IntegerLiteral, @ptrCast(expr)).getSignum(&signum, c.clang_context))) {
            return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "invalid integer literal", .{});
        }
        const is_zero = signum == 0;
        return Node{ .tag_if_small_enough = @intFromEnum(([2]Tag{ .true_literal, .false_literal })[@intFromBool(is_zero)]) };
    }

    const res = try transExpr(c, scope, expr, used);
    if (isBoolRes(res)) {
        return maybeSuppressResult(c, used, res);
    }

    const ty = getExprQualType(c, expr).getTypePtr();
    const node = try finishBoolExpr(c, scope, expr.getBeginLoc(), ty, res, used);

    return maybeSuppressResult(c, used, node);
}

fn exprIsBooleanType(expr: *const clang.Expr) bool {
    return qualTypeIsBoolean(expr.getType());
}

fn exprIsNarrowStringLiteral(expr: *const clang.Expr) bool {
    switch (expr.getStmtClass()) {
        .StringLiteralClass => {
            const string_lit = @as(*const clang.StringLiteral, @ptrCast(expr));
            return string_lit.getCharByteWidth() == 1;
        },
        .PredefinedExprClass => return true,
        .UnaryOperatorClass => {
            const op_expr = @as(*const clang.UnaryOperator, @ptrCast(expr)).getSubExpr();
            return exprIsNarrowStringLiteral(op_expr);
        },
        .ParenExprClass => {
            const op_expr = @as(*const clang.ParenExpr, @ptrCast(expr)).getSubExpr();
            return exprIsNarrowStringLiteral(op_expr);
        },
        .GenericSelectionExprClass => {
            const gen_sel = @as(*const clang.GenericSelectionExpr, @ptrCast(expr));
            return exprIsNarrowStringLiteral(gen_sel.getResultExpr());
        },
        else => return false,
    }
}

fn exprIsFlexibleArrayRef(c: *Context, expr: *const clang.Expr) bool {
    if (expr.getStmtClass() == .MemberExprClass) {
        const member_expr = @as(*const clang.MemberExpr, @ptrCast(expr));
        const member_decl = member_expr.getMemberDecl();
        const decl_kind = @as(*const clang.Decl, @ptrCast(member_decl)).getKind();
        if (decl_kind == .Field) {
            const field_decl = @as(*const clang.FieldDecl, @ptrCast(member_decl));
            return isFlexibleArrayFieldDecl(c, field_decl);
        }
    }
    return false;
}

fn isBoolRes(res: Node) bool {
    switch (res.tag()) {
        .@"or",
        .@"and",
        .equal,
        .not_equal,
        .less_than,
        .less_than_equal,
        .greater_than,
        .greater_than_equal,
        .not,
        .false_literal,
        .true_literal,
        => return true,
        else => return false,
    }
}

fn finishBoolExpr(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    ty: *const clang.Type,
    node: Node,
    used: ResultUsed,
) TransError!Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));

            switch (builtin_ty.getKind()) {
                .Bool => return node,
                .Char_U,
                .UChar,
                .Char_S,
                .SChar,
                .UShort,
                .UInt,
                .ULong,
                .ULongLong,
                .Short,
                .Int,
                .Long,
                .LongLong,
                .UInt128,
                .Int128,
                .Float,
                .Double,
                .Float128,
                .LongDouble,
                .WChar_U,
                .Char8,
                .Char16,
                .Char32,
                .WChar_S,
                .Float16,
                => {
                    // node != 0
                    return Tag.not_equal.create(c.arena, .{ .lhs = node, .rhs = Tag.zero_literal.init() });
                },
                .NullPtr => {
                    // node == null
                    return Tag.equal.create(c.arena, .{ .lhs = node, .rhs = Tag.null_literal.init() });
                },
                else => {},
            }
        },
        .Pointer => {
            if (node.tag() == .string_literal) {
                // @intFromPtr(node) != 0
                const int_from_ptr = try Tag.int_from_ptr.create(c.arena, node);
                return Tag.not_equal.create(c.arena, .{ .lhs = int_from_ptr, .rhs = Tag.zero_literal.init() });
            }
            // node != null
            return Tag.not_equal.create(c.arena, .{ .lhs = node, .rhs = Tag.null_literal.init() });
        },
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));
            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return finishBoolExpr(c, scope, loc, underlying_type.getTypePtr(), node, used);
        },
        .Enum => {
            // node != 0
            return Tag.not_equal.create(c.arena, .{ .lhs = node, .rhs = Tag.zero_literal.init() });
        },
        .Elaborated => {
            const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(ty));
            const named_type = elaborated_ty.getNamedType();
            return finishBoolExpr(c, scope, loc, named_type.getTypePtr(), node, used);
        },
        else => {},
    }
    return fail(c, error.UnsupportedType, loc, "unsupported bool expression type", .{});
}

const SuppressCast = enum {
    with_as,
    no_as,
};
fn transIntegerLiteral(
    c: *Context,
    scope: *Scope,
    expr: *const clang.IntegerLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!Node {
    var eval_result: clang.ExprEvalResult = undefined;
    if (!expr.EvaluateAsInt(&eval_result, c.clang_context)) {
        const loc = expr.getBeginLoc();
        return fail(c, error.UnsupportedTranslation, loc, "invalid integer literal", .{});
    }

    if (suppress_as == .no_as) {
        const int_lit_node = try transCreateNodeAPInt(c, eval_result.Val.getInt());
        return maybeSuppressResult(c, result_used, int_lit_node);
    }

    // Integer literals in C have types, and this can matter for several reasons.
    // For example, this is valid C:
    //     unsigned char y = 256;
    // How this gets evaluated is the 256 is an integer, which gets truncated to signed char, then bit-casted
    // to unsigned char, resulting in 0. In order for this to work, we have to emit this zig code:
    //     var y = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 256)))));
    // Ideally in translate-c we could flatten this out to simply:
    //     var y: u8 = 0;
    // But the first step is to be correct, and the next step is to make the output more elegant.

    // @as(T, x)
    const expr_base = @as(*const clang.Expr, @ptrCast(expr));
    const ty_node = try transQualType(c, scope, expr_base.getType(), expr_base.getBeginLoc());
    const rhs = try transCreateNodeAPInt(c, eval_result.Val.getInt());
    const as = try Tag.as.create(c.arena, .{ .lhs = ty_node, .rhs = rhs });
    return maybeSuppressResult(c, result_used, as);
}

fn transReturnStmt(
    c: *Context,
    scope: *Scope,
    expr: *const clang.ReturnStmt,
) TransError!Node {
    const val_expr = expr.getRetValue() orelse
        return Tag.return_void.init();

    var rhs = try transExprCoercing(c, scope, val_expr, .used);
    const return_qt = scope.findBlockReturnType();
    if (isBoolRes(rhs) and !qualTypeIsBoolean(return_qt)) {
        rhs = try Tag.int_from_bool.create(c.arena, rhs);
    }
    return Tag.@"return".create(c.arena, rhs);
}

fn transNarrowStringLiteral(
    c: *Context,
    stmt: *const clang.StringLiteral,
    result_used: ResultUsed,
) TransError!Node {
    var len: usize = undefined;
    const bytes_ptr = stmt.getString_bytes_begin_size(&len);

    const str = try std.fmt.allocPrint(c.arena, "\"{}\"", .{std.zig.fmtEscapes(bytes_ptr[0..len])});
    const node = try Tag.string_literal.create(c.arena, str);
    return maybeSuppressResult(c, result_used, node);
}

fn transStringLiteral(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.StringLiteral,
    result_used: ResultUsed,
) TransError!Node {
    const kind = stmt.getKind();
    switch (kind) {
        .Ascii, .UTF8 => return transNarrowStringLiteral(c, stmt, result_used),
        .UTF16, .UTF32, .Wide => {
            const str_type = @tagName(stmt.getKind());
            const name = try std.fmt.allocPrint(c.arena, "zig.{s}_string_{d}", .{ str_type, c.getMangle() });

            const expr_base = @as(*const clang.Expr, @ptrCast(stmt));
            const array_type = try transQualTypeInitialized(c, scope, expr_base.getType(), expr_base, expr_base.getBeginLoc());
            const lit_array = try transStringLiteralInitializer(c, stmt, array_type);
            const decl = try Tag.var_simple.create(c.arena, .{ .name = name, .init = lit_array });
            try scope.appendNode(decl);
            const node = try Tag.identifier.create(c.arena, name);
            return maybeSuppressResult(c, result_used, node);
        },
    }
}

fn getArrayPayload(array_type: Node) ast.Payload.Array.ArrayTypeInfo {
    return (array_type.castTag(.array_type) orelse array_type.castTag(.null_sentinel_array_type).?).data;
}

/// Translate a string literal that is initializing an array. In general narrow string
/// literals become `"<string>".*` or `"<string>"[0..<size>].*` if they need truncation.
/// Wide string literals become an array of integers. zero-fillers pad out the array to
/// the appropriate length, if necessary.
fn transStringLiteralInitializer(
    c: *Context,
    stmt: *const clang.StringLiteral,
    array_type: Node,
) TransError!Node {
    assert(array_type.tag() == .array_type or array_type.tag() == .null_sentinel_array_type);

    const is_narrow = stmt.getKind() == .Ascii or stmt.getKind() == .UTF8;

    const str_length = stmt.getLength();
    const payload = getArrayPayload(array_type);
    const array_size = payload.len;
    const elem_type = payload.elem_type;

    if (array_size == 0) return Tag.empty_array.create(c.arena, elem_type);

    const num_inits = @min(str_length, array_size);
    const init_node = if (num_inits > 0) blk: {
        if (is_narrow) {
            // "string literal".* or string literal"[0..num_inits].*
            var str = try transNarrowStringLiteral(c, stmt, .used);
            if (str_length != array_size) str = try Tag.string_slice.create(c.arena, .{ .string = str, .end = num_inits });
            break :blk try Tag.deref.create(c.arena, str);
        } else {
            const init_list = try c.arena.alloc(Node, num_inits);
            var i: c_uint = 0;
            while (i < num_inits) : (i += 1) {
                init_list[i] = try transCreateCharLitNode(c, false, stmt.getCodeUnit(i));
            }
            const init_args = .{ .len = num_inits, .elem_type = elem_type };
            const init_array_type = try if (array_type.tag() == .array_type) Tag.array_type.create(c.arena, init_args) else Tag.null_sentinel_array_type.create(c.arena, init_args);
            break :blk try Tag.array_init.create(c.arena, .{
                .cond = init_array_type,
                .cases = init_list,
            });
        }
    } else null;

    if (num_inits == array_size) return init_node.?; // init_node is only null if num_inits == 0; but if num_inits == array_size == 0 we've already returned
    assert(array_size > str_length); // If array_size <= str_length, `num_inits == array_size` and we've already returned.

    const filler_node = try Tag.array_filler.create(c.arena, .{
        .type = elem_type,
        .filler = Tag.zero_literal.init(),
        .count = array_size - str_length,
    });

    if (init_node) |some| {
        return Tag.array_cat.create(c.arena, .{ .lhs = some, .rhs = filler_node });
    } else {
        return filler_node;
    }
}

/// determine whether `stmt` is a "pointer subtraction expression" - a subtraction where
/// both operands resolve to addresses. The C standard requires that both operands
/// point to elements of the same array object, but we do not verify that here.
fn cIsPointerDiffExpr(stmt: *const clang.BinaryOperator) bool {
    const lhs = @as(*const clang.Stmt, @ptrCast(stmt.getLHS()));
    const rhs = @as(*const clang.Stmt, @ptrCast(stmt.getRHS()));
    return stmt.getOpcode() == .Sub and
        qualTypeIsPtr(@as(*const clang.Expr, @ptrCast(lhs)).getType()) and
        qualTypeIsPtr(@as(*const clang.Expr, @ptrCast(rhs)).getType());
}

fn cIsEnum(qt: clang.QualType) bool {
    return qt.getCanonicalType().getTypeClass() == .Enum;
}

fn cIsVector(qt: clang.QualType) bool {
    return qt.getCanonicalType().getTypeClass() == .Vector;
}

/// Get the underlying int type of an enum. The C compiler chooses a signed int
/// type that is large enough to hold all of the enum's values. It is not required
/// to be the smallest possible type that can hold all the values.
fn cIntTypeForEnum(enum_qt: clang.QualType) clang.QualType {
    assert(cIsEnum(enum_qt));
    const ty = enum_qt.getCanonicalType().getTypePtr();
    const enum_ty = @as(*const clang.EnumType, @ptrCast(ty));
    const enum_decl = enum_ty.getDecl();
    return enum_decl.getIntegerType();
}

// when modifying this function, make sure to also update std.zig.c_translation.cast
fn transCCast(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    dst_type: clang.QualType,
    src_type: clang.QualType,
    expr: Node,
) !Node {
    if (qualTypeCanon(dst_type).isVoidType()) return expr;
    if (dst_type.eq(src_type)) return expr;
    if (qualTypeIsPtr(dst_type) and qualTypeIsPtr(src_type))
        return transCPtrCast(c, scope, loc, dst_type, src_type, expr);
    if (cIsEnum(dst_type)) return transCCast(c, scope, loc, cIntTypeForEnum(dst_type), src_type, expr);
    if (cIsEnum(src_type)) return transCCast(c, scope, loc, dst_type, cIntTypeForEnum(src_type), expr);

    const dst_node = try transQualType(c, scope, dst_type, loc);
    if (cIsInteger(dst_type) and cIsInteger(src_type)) {
        // 1. If src_type is an enum, determine the underlying signed int type
        // 2. Extend or truncate without changing signed-ness.
        // 3. Bit-cast to correct signed-ness
        const src_type_is_signed = cIsSignedInteger(src_type);
        var src_int_expr = expr;

        if (isBoolRes(src_int_expr)) {
            src_int_expr = try Tag.int_from_bool.create(c.arena, src_int_expr);
            return Tag.as.create(c.arena, .{ .lhs = dst_node, .rhs = src_int_expr });
        }

        switch (cIntTypeCmp(dst_type, src_type)) {
            .lt => {
                // @truncate(SameSignSmallerInt, src_int_expr)
                const ty_node = try transQualTypeIntWidthOf(c, dst_type, src_type_is_signed);
                src_int_expr = try Tag.as.create(c.arena, .{
                    .lhs = ty_node,
                    .rhs = try Tag.truncate.create(c.arena, src_int_expr),
                });
            },
            .gt => {
                // @as(SameSignBiggerInt, src_int_expr)
                const ty_node = try transQualTypeIntWidthOf(c, dst_type, src_type_is_signed);
                src_int_expr = try Tag.as.create(c.arena, .{ .lhs = ty_node, .rhs = src_int_expr });
            },
            .eq => {
                // src_int_expr = src_int_expr
            },
        }
        // @as(dest_type, @bitCast(intermediate_value))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.bit_cast.create(c.arena, src_int_expr),
        });
    }
    if (cIsVector(src_type) or cIsVector(dst_type)) {
        // C cast where at least 1 operand is a vector requires them to be same size
        // @as(dest_type, @bitCast(val))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.bit_cast.create(c.arena, expr),
        });
    }
    if (cIsInteger(dst_type) and qualTypeIsPtr(src_type)) {
        // @intCast(dest_type, @intFromPtr(val))
        const int_from_ptr = try Tag.int_from_ptr.create(c.arena, expr);
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.int_cast.create(c.arena, int_from_ptr),
        });
    }
    if (cIsInteger(src_type) and qualTypeIsPtr(dst_type)) {
        // @as(dest_type, @ptrFromInt(val))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.ptr_from_int.create(c.arena, expr),
        });
    }
    if (cIsFloating(src_type) and cIsFloating(dst_type)) {
        // @as(dest_type, @floatCast(val))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.float_cast.create(c.arena, expr),
        });
    }
    if (cIsFloating(src_type) and !cIsFloating(dst_type)) {
        // bool expression: floating val != 0
        if (qualTypeIsBoolean(dst_type)) {
            return Tag.not_equal.create(c.arena, .{
                .lhs = expr,
                .rhs = Tag.zero_literal.init(),
            });
        }

        // @as(dest_type, @intFromFloat(val))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.int_from_float.create(c.arena, expr),
        });
    }
    if (!cIsFloating(src_type) and cIsFloating(dst_type)) {
        var rhs = expr;
        if (qualTypeIsBoolean(src_type) or isBoolRes(rhs)) rhs = try Tag.int_from_bool.create(c.arena, expr);
        // @as(dest_type, @floatFromInt(val))
        return Tag.as.create(c.arena, .{
            .lhs = dst_node,
            .rhs = try Tag.float_from_int.create(c.arena, rhs),
        });
    }
    if (qualTypeIsBoolean(src_type) and !qualTypeIsBoolean(dst_type)) {
        // @intFromBool returns a u1
        // TODO: if dst_type is 1 bit & signed (bitfield) we need @bitCast
        // instead of @as
        const int_from_bool = try Tag.int_from_bool.create(c.arena, expr);
        return Tag.as.create(c.arena, .{ .lhs = dst_node, .rhs = int_from_bool });
    }
    // @as(dest_type, val)
    return Tag.as.create(c.arena, .{ .lhs = dst_node, .rhs = expr });
}

fn transExpr(c: *Context, scope: *Scope, expr: *const clang.Expr, used: ResultUsed) TransError!Node {
    return transStmt(c, scope, @as(*const clang.Stmt, @ptrCast(expr)), used);
}

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(c: *Context, scope: *Scope, expr: *const clang.Expr, used: ResultUsed) TransError!Node {
    switch (@as(*const clang.Stmt, @ptrCast(expr)).getStmtClass()) {
        .IntegerLiteralClass => {
            return transIntegerLiteral(c, scope, @as(*const clang.IntegerLiteral, @ptrCast(expr)), .used, .no_as);
        },
        .CharacterLiteralClass => {
            return transCharLiteral(c, scope, @as(*const clang.CharacterLiteral, @ptrCast(expr)), .used, .no_as);
        },
        .UnaryOperatorClass => {
            const un_expr = @as(*const clang.UnaryOperator, @ptrCast(expr));
            if (un_expr.getOpcode() == .Extension) {
                return transExprCoercing(c, scope, un_expr.getSubExpr(), used);
            }
        },
        .ImplicitCastExprClass => {
            const cast_expr = @as(*const clang.ImplicitCastExpr, @ptrCast(expr));
            const sub_expr = cast_expr.getSubExpr();
            switch (@as(*const clang.Stmt, @ptrCast(sub_expr)).getStmtClass()) {
                .IntegerLiteralClass, .CharacterLiteralClass => switch (cast_expr.getCastKind()) {
                    .IntegralToFloating => return transExprCoercing(c, scope, sub_expr, used),
                    .IntegralCast => {
                        const dest_type = getExprQualType(c, expr);
                        if (literalFitsInType(c, sub_expr, dest_type))
                            return transExprCoercing(c, scope, sub_expr, used);
                    },
                    else => {},
                },
                else => {},
            }
        },
        else => {},
    }
    return transExpr(c, scope, expr, .used);
}

fn literalFitsInType(c: *Context, expr: *const clang.Expr, qt: clang.QualType) bool {
    var width = qualTypeIntBitWidth(c, qt) catch 8;
    if (width == 0) width = 8; // Byte is the smallest type.
    const is_signed = cIsSignedInteger(qt);
    const width_max_int = (@as(u64, 1) << math.lossyCast(u6, width - @intFromBool(is_signed))) - 1;

    switch (@as(*const clang.Stmt, @ptrCast(expr)).getStmtClass()) {
        .CharacterLiteralClass => {
            const char_lit = @as(*const clang.CharacterLiteral, @ptrCast(expr));
            const val = char_lit.getValue();
            // If the val is less than the max int then it fits.
            return val <= width_max_int;
        },
        .IntegerLiteralClass => {
            const int_lit = @as(*const clang.IntegerLiteral, @ptrCast(expr));
            var eval_result: clang.ExprEvalResult = undefined;
            if (!int_lit.EvaluateAsInt(&eval_result, c.clang_context)) {
                return false;
            }

            const int = eval_result.Val.getInt();
            return int.lessThanEqual(width_max_int);
        },
        else => unreachable,
    }
}

fn transInitListExprRecord(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    expr: *const clang.InitListExpr,
    ty: *const clang.Type,
) TransError!Node {
    var is_union_type = false;
    // Unions and Structs are both represented as RecordDecl
    const record_ty = ty.getAsRecordType() orelse
        blk: {
        is_union_type = true;
        break :blk ty.getAsUnionType();
    } orelse unreachable;
    const record_decl = record_ty.getDecl();
    const record_def = record_decl.getDefinition() orelse
        unreachable;

    const ty_node = try transType(c, scope, ty, loc);
    const init_count = expr.getNumInits();
    var field_inits = std.ArrayList(ast.Payload.ContainerInit.Initializer).init(c.gpa);
    defer field_inits.deinit();

    if (init_count == 0) {
        const source_loc = @as(*const clang.Expr, @ptrCast(expr)).getBeginLoc();
        return transZeroInitExpr(c, scope, source_loc, ty);
    }

    var init_i: c_uint = 0;
    var it = record_def.field_begin();
    const end_it = record_def.field_end();
    while (it.neq(end_it)) : (it = it.next()) {
        const field_decl = it.deref();

        // The initializer for a union type has a single entry only
        if (is_union_type and field_decl != expr.getInitializedFieldInUnion()) {
            continue;
        }

        assert(init_i < init_count);
        const elem_expr = expr.getInit(init_i);
        init_i += 1;

        // Generate the field assignment expression:
        //     .field_name = expr
        var raw_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(field_decl)).getName_bytes_begin());
        if (field_decl.isAnonymousStructOrUnion()) {
            const name = c.decl_table.get(@intFromPtr(field_decl.getCanonicalDecl())).?;
            raw_name = try c.arena.dupe(u8, name);
        }

        var init_expr = try transExpr(c, scope, elem_expr, .used);
        const field_qt = field_decl.getType();
        if (init_expr.tag() == .string_literal and qualTypeIsCharStar(field_qt)) {
            if (scope.id == .root) {
                init_expr = try stringLiteralToCharStar(c, init_expr);
            } else {
                const dst_type_node = try transQualType(c, scope, field_qt, loc);
                init_expr = try removeCVQualifiers(c, dst_type_node, init_expr);
            }
        }
        try field_inits.append(.{
            .name = raw_name,
            .value = init_expr,
        });
    }
    if (ty_node.castTag(.identifier)) |ident_node| {
        scope.skipVariableDiscard(ident_node.data);
    }
    return Tag.container_init.create(c.arena, .{
        .lhs = ty_node,
        .inits = try c.arena.dupe(ast.Payload.ContainerInit.Initializer, field_inits.items),
    });
}

fn transInitListExprArray(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    expr: *const clang.InitListExpr,
    ty: *const clang.Type,
) TransError!Node {
    const arr_type = ty.getAsArrayTypeUnsafe();
    const child_qt = arr_type.getElementType();
    const child_type = try transQualType(c, scope, child_qt, loc);
    const init_count = expr.getNumInits();
    assert(@as(*const clang.Type, @ptrCast(arr_type)).isConstantArrayType());
    const const_arr_ty = @as(*const clang.ConstantArrayType, @ptrCast(arr_type));
    const size_ap_int = const_arr_ty.getSize();
    const all_count = size_ap_int.getLimitedValue(usize);
    const leftover_count = all_count - init_count;

    if (all_count == 0) {
        return Tag.empty_array.create(c.arena, child_type);
    }

    if (expr.isStringLiteralInit()) {
        assert(init_count == 1);
        const init_expr = expr.getInit(0);
        const string_literal = init_expr.castToStringLiteral().?;
        return try transStringLiteral(c, scope, string_literal, .used);
    }

    const init_node = if (init_count != 0) blk: {
        const init_list = try c.arena.alloc(Node, init_count);

        for (init_list, 0..) |*init, i| {
            const elem_expr = expr.getInit(@as(c_uint, @intCast(i)));
            init.* = try transExprCoercing(c, scope, elem_expr, .used);
        }
        const init_node = try Tag.array_init.create(c.arena, .{
            .cond = try Tag.array_type.create(c.arena, .{ .len = init_count, .elem_type = child_type }),
            .cases = init_list,
        });
        if (leftover_count == 0) {
            return init_node;
        }
        break :blk init_node;
    } else null;

    assert(expr.hasArrayFiller());
    const filler_val_expr = expr.getArrayFiller();
    const filler_node = try Tag.array_filler.create(c.arena, .{
        .type = child_type,
        .filler = try transExprCoercing(c, scope, filler_val_expr, .used),
        .count = leftover_count,
    });

    if (init_node) |some| {
        return Tag.array_cat.create(c.arena, .{ .lhs = some, .rhs = filler_node });
    } else {
        return filler_node;
    }
}

fn transInitListExprVector(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    expr: *const clang.InitListExpr,
) TransError!Node {
    const qt = getExprQualType(c, @as(*const clang.Expr, @ptrCast(expr)));
    const vector_ty = @as(*const clang.VectorType, @ptrCast(qualTypeCanon(qt)));

    const init_count = expr.getNumInits();
    const num_elements = vector_ty.getNumElements();
    const element_qt = vector_ty.getElementType();

    if (init_count == 0) {
        const vec_node = try Tag.vector.create(c.arena, .{
            .lhs = try transCreateNodeNumber(c, num_elements, .int),
            .rhs = try transQualType(c, scope, element_qt, loc),
        });

        return Tag.as.create(c.arena, .{
            .lhs = vec_node,
            .rhs = try Tag.vector_zero_init.create(c.arena, Tag.zero_literal.init()),
        });
    }

    const vector_type = try transQualType(c, scope, qt, loc);

    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    // workaround for https://github.com/ziglang/zig/issues/8322
    // we store the initializers in temp variables and use those
    // to initialize the vector. Eventually we can just directly
    // construct the init_list from casted source members
    var i: usize = 0;
    while (i < init_count) : (i += 1) {
        const mangled_name = try block_scope.makeMangledName(c, "tmp");
        const init_expr = expr.getInit(@as(c_uint, @intCast(i)));
        const tmp_decl_node = try Tag.var_simple.create(c.arena, .{
            .name = mangled_name,
            .init = try transExpr(c, &block_scope.base, init_expr, .used),
        });
        try block_scope.statements.append(tmp_decl_node);
    }

    const init_list = try c.arena.alloc(Node, num_elements);
    for (init_list, 0..) |*init, init_index| {
        if (init_index < init_count) {
            const tmp_decl = block_scope.statements.items[init_index];
            const name = tmp_decl.castTag(.var_simple).?.data.name;
            init.* = try Tag.identifier.create(c.arena, name);
        } else {
            init.* = Tag.undefined_literal.init();
        }
    }

    const array_init = try Tag.array_init.create(c.arena, .{
        .cond = vector_type,
        .cases = init_list,
    });
    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = array_init,
    });
    try block_scope.statements.append(break_node);

    return block_scope.complete(c);
}

fn transInitListExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.InitListExpr,
    used: ResultUsed,
) TransError!Node {
    const qt = getExprQualType(c, @as(*const clang.Expr, @ptrCast(expr)));
    var qual_type = qt.getTypePtr();
    const source_loc = @as(*const clang.Expr, @ptrCast(expr)).getBeginLoc();

    if (qualTypeWasDemotedToOpaque(c, qt)) {
        return fail(c, error.UnsupportedTranslation, source_loc, "cannot initialize opaque type", .{});
    }

    if (qual_type.isRecordType()) {
        return maybeSuppressResult(c, used, try transInitListExprRecord(
            c,
            scope,
            source_loc,
            expr,
            qual_type,
        ));
    } else if (qual_type.isArrayType()) {
        return maybeSuppressResult(c, used, try transInitListExprArray(
            c,
            scope,
            source_loc,
            expr,
            qual_type,
        ));
    } else if (qual_type.isVectorType()) {
        return maybeSuppressResult(c, used, try transInitListExprVector(c, scope, source_loc, expr));
    } else {
        const type_name = try c.str(qual_type.getTypeClassName());
        return fail(c, error.UnsupportedType, source_loc, "unsupported initlist type: '{s}'", .{type_name});
    }
}

fn transZeroInitExpr(
    c: *Context,
    scope: *Scope,
    source_loc: clang.SourceLocation,
    ty: *const clang.Type,
) TransError!Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));
            switch (builtin_ty.getKind()) {
                .Bool => return Tag.false_literal.init(),
                .Char_U,
                .UChar,
                .Char_S,
                .Char8,
                .SChar,
                .UShort,
                .UInt,
                .ULong,
                .ULongLong,
                .Short,
                .Int,
                .Long,
                .LongLong,
                .UInt128,
                .Int128,
                .Float,
                .Double,
                .Float128,
                .Float16,
                .LongDouble,
                => return Tag.zero_literal.init(),
                else => return fail(c, error.UnsupportedType, source_loc, "unsupported builtin type", .{}),
            }
        },
        .Pointer => return Tag.null_literal.init(),
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));
            const typedef_decl = typedef_ty.getDecl();
            return transZeroInitExpr(
                c,
                scope,
                source_loc,
                typedef_decl.getUnderlyingType().getTypePtr(),
            );
        },
        else => return Tag.std_mem_zeroes.create(c.arena, try transType(c, scope, ty, source_loc)),
    }
}

fn transImplicitValueInitExpr(
    c: *Context,
    scope: *Scope,
    expr: *const clang.Expr,
) TransError!Node {
    const source_loc = expr.getBeginLoc();
    const qt = getExprQualType(c, expr);
    const ty = qt.getTypePtr();
    return transZeroInitExpr(c, scope, source_loc, ty);
}

/// If a statement can possibly translate to a Zig assignment (either directly because it's
/// an assignment in C or indirectly via result assignment to `_`) AND it's the sole statement
/// in the body of an if statement or loop, then we need to put the statement into its own block.
/// The `else` case here corresponds to statements that could result in an assignment. If a statement
/// class never needs a block, add its enum to the top prong.
fn maybeBlockify(c: *Context, scope: *Scope, stmt: *const clang.Stmt) TransError!Node {
    switch (stmt.getStmtClass()) {
        .BreakStmtClass,
        .CompoundStmtClass,
        .ContinueStmtClass,
        .DeclRefExprClass,
        .DeclStmtClass,
        .DoStmtClass,
        .ForStmtClass,
        .IfStmtClass,
        .ReturnStmtClass,
        .NullStmtClass,
        .WhileStmtClass,
        => return transStmt(c, scope, stmt, .unused),
        else => return blockify(c, scope, stmt),
    }
}

fn blockify(c: *Context, scope: *Scope, stmt: *const clang.Stmt) TransError!Node {
    var block_scope = try Scope.Block.init(c, scope, false);
    defer block_scope.deinit();
    const result = try transStmt(c, &block_scope.base, stmt, .unused);
    try block_scope.statements.append(result);
    return block_scope.complete(c);
}

fn transIfStmt(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.IfStmt,
) TransError!Node {
    // if (c) t
    // if (c) t else e
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond_expr = @as(*const clang.Expr, @ptrCast(stmt.getCond()));
    const cond = try transBoolExpr(c, &cond_scope.base, cond_expr, .used);

    const then_stmt = stmt.getThen();
    const else_stmt = stmt.getElse();
    const then_class = then_stmt.getStmtClass();
    // block needed to keep else statement from attaching to inner while
    const must_blockify = (else_stmt != null) and switch (then_class) {
        .DoStmtClass, .ForStmtClass, .WhileStmtClass => true,
        else => false,
    };

    const then_body = if (must_blockify)
        try blockify(c, scope, then_stmt)
    else
        try maybeBlockify(c, scope, then_stmt);

    const else_body = if (else_stmt) |expr|
        try maybeBlockify(c, scope, expr)
    else
        null;
    return Tag.@"if".create(c.arena, .{ .cond = cond, .then = then_body, .@"else" = else_body });
}

fn transWhileLoop(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.WhileStmt,
) TransError!Node {
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond_expr = @as(*const clang.Expr, @ptrCast(stmt.getCond()));
    const cond = try transBoolExpr(c, &cond_scope.base, cond_expr, .used);

    var loop_scope = Scope{
        .parent = scope,
        .id = .loop,
    };
    const body = try maybeBlockify(c, &loop_scope, stmt.getBody());
    return Tag.@"while".create(c.arena, .{ .cond = cond, .body = body, .cont_expr = null });
}

fn transDoWhileLoop(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.DoStmt,
) TransError!Node {
    var loop_scope = Scope{
        .parent = scope,
        .id = .do_loop,
    };

    // if (!cond) break;
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try transBoolExpr(c, &cond_scope.base, @as(*const clang.Expr, @ptrCast(stmt.getCond())), .used);
    const if_not_break = switch (cond.tag()) {
        .true_literal => {
            const body_node = try maybeBlockify(c, scope, stmt.getBody());
            return Tag.while_true.create(c.arena, body_node);
        },
        else => try Tag.if_not_break.create(c.arena, cond),
    };

    var body_node = try transStmt(c, &loop_scope, stmt.getBody(), .unused);
    if (body_node.isNoreturn(true)) {
        // The body node ends in a noreturn statement. Simply put it in a while (true)
        // in case it contains breaks or continues.
    } else if (stmt.getBody().getStmtClass() == .CompoundStmtClass) {
        // there's already a block in C, so we'll append our condition to it.
        // c: do {
        // c:   a;
        // c:   b;
        // c: } while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   b;
        // zig:   if (!cond) break;
        // zig: }
        const block = body_node.castTag(.block).?;
        block.data.stmts.len += 1; // This is safe since we reserve one extra space in Scope.Block.complete.
        block.data.stmts[block.data.stmts.len - 1] = if_not_break;
    } else {
        // the C statement is without a block, so we need to create a block to contain it.
        // c: do
        // c:   a;
        // c: while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   if (!cond) break;
        // zig: }
        const statements = try c.arena.alloc(Node, 2);
        statements[0] = body_node;
        statements[1] = if_not_break;
        body_node = try Tag.block.create(c.arena, .{ .label = null, .stmts = statements });
    }
    return Tag.while_true.create(c.arena, body_node);
}

fn transForLoop(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.ForStmt,
) TransError!Node {
    var loop_scope = Scope{
        .parent = scope,
        .id = .loop,
    };

    var block_scope: ?Scope.Block = null;
    defer if (block_scope) |*bs| bs.deinit();

    if (stmt.getInit()) |init| {
        block_scope = try Scope.Block.init(c, scope, false);
        loop_scope.parent = &block_scope.?.base;
        const init_node = try transStmt(c, &block_scope.?.base, init, .unused);
        if (init_node.tag() != .declaration) try block_scope.?.statements.append(init_node);
    }
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = &loop_scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond = if (stmt.getCond()) |cond|
        try transBoolExpr(c, &cond_scope.base, cond, .used)
    else
        Tag.true_literal.init();

    const cont_expr = if (stmt.getInc()) |incr|
        try transExpr(c, &cond_scope.base, incr, .unused)
    else
        null;

    const body = try maybeBlockify(c, &loop_scope, stmt.getBody());
    const while_node = try Tag.@"while".create(c.arena, .{ .cond = cond, .body = body, .cont_expr = cont_expr });
    if (block_scope) |*bs| {
        try bs.statements.append(while_node);
        return try bs.complete(c);
    } else {
        return while_node;
    }
}

fn transSwitch(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.SwitchStmt,
) TransError!Node {
    var loop_scope = Scope{
        .parent = scope,
        .id = .loop,
    };

    var block_scope = try Scope.Block.init(c, &loop_scope, false);
    defer block_scope.deinit();

    const base_scope = &block_scope.base;

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = base_scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const switch_expr = try transExpr(c, &cond_scope.base, stmt.getCond(), .used);

    var cases = std.ArrayList(Node).init(c.gpa);
    defer cases.deinit();
    var has_default = false;

    const body = stmt.getBody();
    assert(body.getStmtClass() == .CompoundStmtClass);
    const compound_stmt = @as(*const clang.CompoundStmt, @ptrCast(body));
    var it = compound_stmt.body_begin();
    const end_it = compound_stmt.body_end();
    // Iterate over switch body and collect all cases.
    // Fallthrough is handled by duplicating statements.
    while (it != end_it) : (it += 1) {
        switch (it[0].getStmtClass()) {
            .CaseStmtClass => {
                var items = std.ArrayList(Node).init(c.gpa);
                defer items.deinit();
                const sub = try transCaseStmt(c, base_scope, it[0], &items);
                const res = try transSwitchProngStmt(c, base_scope, sub, it, end_it);

                if (items.items.len == 0) {
                    has_default = true;
                    const switch_else = try Tag.switch_else.create(c.arena, res);
                    try cases.append(switch_else);
                } else {
                    const switch_prong = try Tag.switch_prong.create(c.arena, .{
                        .cases = try c.arena.dupe(Node, items.items),
                        .cond = res,
                    });
                    try cases.append(switch_prong);
                }
            },
            .DefaultStmtClass => {
                has_default = true;
                const default_stmt = @as(*const clang.DefaultStmt, @ptrCast(it[0]));

                var sub = default_stmt.getSubStmt();
                while (true) switch (sub.getStmtClass()) {
                    .CaseStmtClass => sub = @as(*const clang.CaseStmt, @ptrCast(sub)).getSubStmt(),
                    .DefaultStmtClass => sub = @as(*const clang.DefaultStmt, @ptrCast(sub)).getSubStmt(),
                    else => break,
                };

                const res = try transSwitchProngStmt(c, base_scope, sub, it, end_it);

                const switch_else = try Tag.switch_else.create(c.arena, res);
                try cases.append(switch_else);
            },
            else => {}, // collected in transSwitchProngStmt
        }
    }

    if (!has_default) {
        const else_prong = try Tag.switch_else.create(c.arena, Tag.empty_block.init());
        try cases.append(else_prong);
    }

    const switch_node = try Tag.@"switch".create(c.arena, .{
        .cond = switch_expr,
        .cases = try c.arena.dupe(Node, cases.items),
    });
    try block_scope.statements.append(switch_node);
    try block_scope.statements.append(Tag.@"break".init());
    const while_body = try block_scope.complete(c);

    return Tag.while_true.create(c.arena, while_body);
}

/// Collects all items for this case, returns the first statement after the labels.
/// If items ends up empty, the prong should be translated as an else.
fn transCaseStmt(c: *Context, scope: *Scope, stmt: *const clang.Stmt, items: *std.ArrayList(Node)) TransError!*const clang.Stmt {
    var sub = stmt;
    var seen_default = false;
    while (true) {
        switch (sub.getStmtClass()) {
            .DefaultStmtClass => {
                seen_default = true;
                items.items.len = 0;
                const default_stmt = @as(*const clang.DefaultStmt, @ptrCast(sub));
                sub = default_stmt.getSubStmt();
            },
            .CaseStmtClass => {
                const case_stmt = @as(*const clang.CaseStmt, @ptrCast(sub));

                if (seen_default) {
                    items.items.len = 0;
                    sub = case_stmt.getSubStmt();
                    continue;
                }

                const expr = if (case_stmt.getRHS()) |rhs| blk: {
                    const lhs_node = try transExprCoercing(c, scope, case_stmt.getLHS(), .used);
                    const rhs_node = try transExprCoercing(c, scope, rhs, .used);

                    break :blk try Tag.ellipsis3.create(c.arena, .{ .lhs = lhs_node, .rhs = rhs_node });
                } else try transExprCoercing(c, scope, case_stmt.getLHS(), .used);

                try items.append(expr);
                sub = case_stmt.getSubStmt();
            },
            else => return sub,
        }
    }
}

/// Collects all statements seen by this case into a block.
/// Avoids creating a block if the first statement is a break or return.
fn transSwitchProngStmt(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.Stmt,
    parent_it: clang.CompoundStmt.ConstBodyIterator,
    parent_end_it: clang.CompoundStmt.ConstBodyIterator,
) TransError!Node {
    switch (stmt.getStmtClass()) {
        .BreakStmtClass => return Tag.@"break".init(),
        .ReturnStmtClass => return transStmt(c, scope, stmt, .unused),
        .CaseStmtClass, .DefaultStmtClass => unreachable,
        else => {
            var block_scope = try Scope.Block.init(c, scope, false);
            defer block_scope.deinit();

            // we do not need to translate `stmt` since it is the first stmt of `parent_it`
            try transSwitchProngStmtInline(c, &block_scope, parent_it, parent_end_it);
            return try block_scope.complete(c);
        },
    }
}

/// Collects all statements seen by this case into a block.
fn transSwitchProngStmtInline(
    c: *Context,
    block: *Scope.Block,
    start_it: clang.CompoundStmt.ConstBodyIterator,
    end_it: clang.CompoundStmt.ConstBodyIterator,
) TransError!void {
    var it = start_it;
    while (it != end_it) : (it += 1) {
        switch (it[0].getStmtClass()) {
            .ReturnStmtClass => {
                const result = try transStmt(c, &block.base, it[0], .unused);
                try block.statements.append(result);
                return;
            },
            .BreakStmtClass => {
                try block.statements.append(Tag.@"break".init());
                return;
            },
            .CaseStmtClass => {
                var sub = @as(*const clang.CaseStmt, @ptrCast(it[0])).getSubStmt();
                while (true) switch (sub.getStmtClass()) {
                    .CaseStmtClass => sub = @as(*const clang.CaseStmt, @ptrCast(sub)).getSubStmt(),
                    .DefaultStmtClass => sub = @as(*const clang.DefaultStmt, @ptrCast(sub)).getSubStmt(),
                    else => break,
                };
                const result = try transStmt(c, &block.base, sub, .unused);
                assert(result.tag() != .declaration);
                try block.statements.append(result);
                if (result.isNoreturn(true)) {
                    return;
                }
            },
            .DefaultStmtClass => {
                var sub = @as(*const clang.DefaultStmt, @ptrCast(it[0])).getSubStmt();
                while (true) switch (sub.getStmtClass()) {
                    .CaseStmtClass => sub = @as(*const clang.CaseStmt, @ptrCast(sub)).getSubStmt(),
                    .DefaultStmtClass => sub = @as(*const clang.DefaultStmt, @ptrCast(sub)).getSubStmt(),
                    else => break,
                };
                const result = try transStmt(c, &block.base, sub, .unused);
                assert(result.tag() != .declaration);
                try block.statements.append(result);
                if (result.isNoreturn(true)) {
                    return;
                }
            },
            .CompoundStmtClass => {
                const result = try transCompoundStmt(c, &block.base, @as(*const clang.CompoundStmt, @ptrCast(it[0])));
                try block.statements.append(result);
                if (result.isNoreturn(true)) {
                    return;
                }
            },
            else => {
                const result = try transStmt(c, &block.base, it[0], .unused);
                switch (result.tag()) {
                    .declaration, .empty_block => {},
                    else => try block.statements.append(result),
                }
            },
        }
    }
    return;
}

fn transConstantExpr(c: *Context, scope: *Scope, expr: *const clang.Expr, used: ResultUsed) TransError!Node {
    var result: clang.ExprEvalResult = undefined;
    if (!expr.evaluateAsConstantExpr(&result, .Normal, c.clang_context))
        return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "invalid constant expression", .{});

    switch (result.Val.getKind()) {
        .Int => {
            // See comment in `transIntegerLiteral` for why this code is here.
            // @as(T, x)
            const expr_base = @as(*const clang.Expr, @ptrCast(expr));
            const as_node = try Tag.as.create(c.arena, .{
                .lhs = try transQualType(c, scope, expr_base.getType(), expr_base.getBeginLoc()),
                .rhs = try transCreateNodeAPInt(c, result.Val.getInt()),
            });
            return maybeSuppressResult(c, used, as_node);
        },
        else => |kind| {
            return fail(c, error.UnsupportedTranslation, expr.getBeginLoc(), "unsupported constant expression kind '{}'", .{kind});
        },
    }
}

fn transPredefinedExpr(c: *Context, scope: *Scope, expr: *const clang.PredefinedExpr, used: ResultUsed) TransError!Node {
    return transStringLiteral(c, scope, expr.getFunctionName(), used);
}

fn transCreateCharLitNode(c: *Context, narrow: bool, val: u32) TransError!Node {
    return Tag.char_literal.create(c.arena, if (narrow)
        try std.fmt.allocPrint(c.arena, "'{'}'", .{std.zig.fmtEscapes(&.{@as(u8, @intCast(val))})})
    else
        try std.fmt.allocPrint(c.arena, "'\\u{{{x}}}'", .{val}));
}

fn transCharLiteral(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.CharacterLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!Node {
    const kind = stmt.getKind();
    const val = stmt.getValue();
    const narrow = kind == .Ascii or kind == .UTF8;
    // C has a somewhat obscure feature called multi-character character constant
    // e.g. 'abcd'
    const int_lit_node = if (kind == .Ascii and val > 255)
        try transCreateNodeNumber(c, val, .int)
    else
        try transCreateCharLitNode(c, narrow, val);

    if (suppress_as == .no_as) {
        return maybeSuppressResult(c, result_used, int_lit_node);
    }
    // See comment in `transIntegerLiteral` for why this code is here.
    // @as(T, x)
    const expr_base = @as(*const clang.Expr, @ptrCast(stmt));
    const as_node = try Tag.as.create(c.arena, .{
        .lhs = try transQualType(c, scope, expr_base.getType(), expr_base.getBeginLoc()),
        .rhs = int_lit_node,
    });
    return maybeSuppressResult(c, result_used, as_node);
}

fn transStmtExpr(c: *Context, scope: *Scope, stmt: *const clang.StmtExpr, used: ResultUsed) TransError!Node {
    const comp = stmt.getSubStmt();
    if (used == .unused) {
        return transCompoundStmt(c, scope, comp);
    }
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    var it = comp.body_begin();
    const end_it = comp.body_end();
    while (it != end_it - 1) : (it += 1) {
        const result = try transStmt(c, &block_scope.base, it[0], .unused);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block_scope.statements.append(result),
        }
    }

    const last_result = try transStmt(c, &block_scope.base, it[0], .used);
    switch (last_result.tag()) {
        .declaration, .empty_block => {},
        else => {
            const break_node = try Tag.break_val.create(c.arena, .{
                .label = block_scope.label,
                .val = last_result,
            });
            try block_scope.statements.append(break_node);
        },
    }
    const res = try block_scope.complete(c);
    return maybeSuppressResult(c, used, res);
}

fn transMemberExpr(c: *Context, scope: *Scope, stmt: *const clang.MemberExpr, result_used: ResultUsed) TransError!Node {
    var container_node = try transExpr(c, scope, stmt.getBase(), .used);
    if (stmt.isArrow()) {
        container_node = try Tag.deref.create(c.arena, container_node);
    }

    const member_decl = stmt.getMemberDecl();
    const name = blk: {
        const decl_kind = @as(*const clang.Decl, @ptrCast(member_decl)).getKind();
        // If we're referring to a anonymous struct/enum find the bogus name
        // we've assigned to it during the RecordDecl translation
        if (decl_kind == .Field) {
            const field_decl = @as(*const clang.FieldDecl, @ptrCast(member_decl));
            if (field_decl.isAnonymousStructOrUnion()) {
                const name = c.decl_table.get(@intFromPtr(field_decl.getCanonicalDecl())).?;
                break :blk try c.arena.dupe(u8, name);
            }
        }
        const decl = @as(*const clang.NamedDecl, @ptrCast(member_decl));
        break :blk try c.str(decl.getName_bytes_begin());
    };

    var node = try Tag.field_access.create(c.arena, .{ .lhs = container_node, .field_name = name });
    if (exprIsFlexibleArrayRef(c, @as(*const clang.Expr, @ptrCast(stmt)))) {
        node = try Tag.call.create(c.arena, .{ .lhs = node, .args = &.{} });
    }
    return maybeSuppressResult(c, result_used, node);
}

/// ptr[subscr] (`subscr` is a signed integer expression, `ptr` a pointer) becomes:
/// (blk: {
///     const tmp = subscr;
///     if (tmp >= 0) break :blk ptr + @intCast(usize, tmp) else break :blk ptr - ~@bitCast(usize, @intCast(isize, tmp) +% -1);
/// }).*
/// Todo: rip this out once `[*]T + isize` becomes valid.
fn transSignedArrayAccess(
    c: *Context,
    scope: *Scope,
    container_expr: *const clang.Expr,
    subscr_expr: *const clang.Expr,
    result_used: ResultUsed,
) TransError!Node {
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.makeMangledName(c, "tmp");

    const subscr_node = try transExpr(c, &block_scope.base, subscr_expr, .used);
    const subscr_decl = try Tag.var_simple.create(c.arena, .{ .name = tmp, .init = subscr_node });
    try block_scope.statements.append(subscr_decl);

    const tmp_ref = try Tag.identifier.create(c.arena, tmp);

    const container_node = try transExpr(c, &block_scope.base, container_expr, .used);

    const cond_node = try Tag.greater_than_equal.create(c.arena, .{ .lhs = tmp_ref, .rhs = Tag.zero_literal.init() });

    const then_value = try Tag.add.create(c.arena, .{
        .lhs = container_node,
        .rhs = try Tag.as.create(c.arena, .{
            .lhs = try Tag.type.create(c.arena, "usize"),
            .rhs = try Tag.int_cast.create(c.arena, tmp_ref),
        }),
    });

    const then_body = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = then_value,
    });

    const minuend = container_node;
    const signed_size = try Tag.as.create(c.arena, .{
        .lhs = try Tag.type.create(c.arena, "isize"),
        .rhs = try Tag.int_cast.create(c.arena, tmp_ref),
    });
    const to_cast = try Tag.add_wrap.create(c.arena, .{
        .lhs = signed_size,
        .rhs = try Tag.negate.create(c.arena, Tag.one_literal.init()),
    });
    const bitcast_node = try Tag.as.create(c.arena, .{
        .lhs = try Tag.type.create(c.arena, "usize"),
        .rhs = try Tag.bit_cast.create(c.arena, to_cast),
    });
    const subtrahend = try Tag.bit_not.create(c.arena, bitcast_node);
    const difference = try Tag.sub.create(c.arena, .{
        .lhs = minuend,
        .rhs = subtrahend,
    });
    const else_body = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = difference,
    });

    const if_node = try Tag.@"if".create(c.arena, .{
        .cond = cond_node,
        .then = then_body,
        .@"else" = else_body,
    });

    try block_scope.statements.append(if_node);
    const block_node = try block_scope.complete(c);

    const derefed = try Tag.deref.create(c.arena, block_node);

    return maybeSuppressResult(c, result_used, derefed);
}

fn transArrayAccess(c: *Context, scope: *Scope, stmt: *const clang.ArraySubscriptExpr, result_used: ResultUsed) TransError!Node {
    const base_stmt = stmt.getBase();
    const base_qt = getExprQualType(c, base_stmt);
    const is_vector = cIsVector(base_qt);

    const subscr_expr = stmt.getIdx();
    const subscr_qt = getExprQualType(c, subscr_expr);
    const is_longlong = cIsLongLongInteger(subscr_qt);
    const is_signed = cIsSignedInteger(subscr_qt);
    const is_nonnegative_int_literal = cIsNonNegativeIntLiteral(c, subscr_expr);

    // Unwrap the base statement if it's an array decayed to a bare pointer type
    // so that we index the array itself
    var unwrapped_base = base_stmt;
    if (@as(*const clang.Stmt, @ptrCast(base_stmt)).getStmtClass() == .ImplicitCastExprClass) {
        const implicit_cast = @as(*const clang.ImplicitCastExpr, @ptrCast(base_stmt));

        if (implicit_cast.getCastKind() == .ArrayToPointerDecay) {
            unwrapped_base = implicit_cast.getSubExpr();
        }
    }

    // Special case: actual pointer (not decayed array) and signed integer subscript
    // See discussion at https://github.com/ziglang/zig/pull/8589
    if (is_signed and (base_stmt == unwrapped_base) and !is_vector and !is_nonnegative_int_literal)
        return transSignedArrayAccess(c, scope, base_stmt, subscr_expr, result_used);

    const container_node = try transExpr(c, scope, unwrapped_base, .used);
    const rhs = if (is_longlong or is_signed) blk: {
        // check if long long first so that signed long long doesn't just become unsigned long long
        const typeid_node = if (is_longlong) try Tag.type.create(c.arena, "usize") else try transQualTypeIntWidthOf(c, subscr_qt, false);
        break :blk try Tag.as.create(c.arena, .{
            .lhs = typeid_node,
            .rhs = try Tag.int_cast.create(
                c.arena,
                try transExpr(c, scope, subscr_expr, .used),
            ),
        });
    } else try transExpr(c, scope, subscr_expr, .used);

    const node = try Tag.array_access.create(c.arena, .{
        .lhs = container_node,
        .rhs = rhs,
    });
    return maybeSuppressResult(c, result_used, node);
}

/// Check if an expression is ultimately a reference to a function declaration
/// (which means it should not be unwrapped with `.?` in translated code)
fn cIsFunctionDeclRef(expr: *const clang.Expr) bool {
    switch (expr.getStmtClass()) {
        .ParenExprClass => {
            const op_expr = @as(*const clang.ParenExpr, @ptrCast(expr)).getSubExpr();
            return cIsFunctionDeclRef(op_expr);
        },
        .DeclRefExprClass => {
            const decl_ref = @as(*const clang.DeclRefExpr, @ptrCast(expr));
            const value_decl = decl_ref.getDecl();
            const qt = value_decl.getType();
            return qualTypeChildIsFnProto(qt);
        },
        .ImplicitCastExprClass => {
            const implicit_cast = @as(*const clang.ImplicitCastExpr, @ptrCast(expr));
            const cast_kind = implicit_cast.getCastKind();
            if (cast_kind == .BuiltinFnToFnPtr) return true;
            if (cast_kind == .FunctionToPointerDecay) {
                return cIsFunctionDeclRef(implicit_cast.getSubExpr());
            }
            return false;
        },
        .UnaryOperatorClass => {
            const un_op = @as(*const clang.UnaryOperator, @ptrCast(expr));
            const opcode = un_op.getOpcode();
            return (opcode == .AddrOf or opcode == .Deref) and cIsFunctionDeclRef(un_op.getSubExpr());
        },
        .GenericSelectionExprClass => {
            const gen_sel = @as(*const clang.GenericSelectionExpr, @ptrCast(expr));
            return cIsFunctionDeclRef(gen_sel.getResultExpr());
        },
        else => return false,
    }
}

fn transCallExpr(c: *Context, scope: *Scope, stmt: *const clang.CallExpr, result_used: ResultUsed) TransError!Node {
    const callee = stmt.getCallee();
    const raw_fn_expr = try transExpr(c, scope, callee, .used);

    var is_ptr = false;
    const fn_ty = qualTypeGetFnProto(callee.getType(), &is_ptr);

    const fn_expr = if (is_ptr and fn_ty != null and !cIsFunctionDeclRef(callee))
        try Tag.unwrap.create(c.arena, raw_fn_expr)
    else
        raw_fn_expr;

    const num_args = stmt.getNumArgs();
    const args = try c.arena.alloc(Node, num_args);

    const c_args = stmt.getArgs();
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        var arg = try transExpr(c, scope, c_args[i], .used);

        // In C the result type of a boolean expression is int. If this result is passed as
        // an argument to a function whose parameter is also int, there is no cast. Therefore
        // in Zig we'll need to cast it from bool to u1 (which will safely coerce to c_int).
        if (fn_ty) |ty| {
            switch (ty) {
                .Proto => |fn_proto| {
                    const param_count = fn_proto.getNumParams();
                    if (i < param_count) {
                        const param_qt = fn_proto.getParamType(@as(c_uint, @intCast(i)));
                        if (isBoolRes(arg) and cIsNativeInt(param_qt)) {
                            arg = try Tag.int_from_bool.create(c.arena, arg);
                        } else if (arg.tag() == .string_literal and qualTypeIsCharStar(param_qt)) {
                            const loc = @as(*const clang.Stmt, @ptrCast(stmt)).getBeginLoc();
                            const dst_type_node = try transQualType(c, scope, param_qt, loc);
                            arg = try removeCVQualifiers(c, dst_type_node, arg);
                        }
                    }
                },
                else => {},
            }
        }
        args[i] = arg;
    }
    const node = try Tag.call.create(c.arena, .{ .lhs = fn_expr, .args = args });
    if (fn_ty) |ty| {
        const canon = ty.getReturnType().getCanonicalType();
        const ret_ty = canon.getTypePtr();
        if (ret_ty.isVoidType()) {
            return node;
        }
    }

    return maybeSuppressResult(c, result_used, node);
}

const ClangFunctionType = union(enum) {
    Proto: *const clang.FunctionProtoType,
    NoProto: *const clang.FunctionType,

    fn getReturnType(self: @This()) clang.QualType {
        switch (@as(meta.Tag(@This()), self)) {
            .Proto => return self.Proto.getReturnType(),
            .NoProto => return self.NoProto.getReturnType(),
        }
    }
};

fn qualTypeGetFnProto(qt: clang.QualType, is_ptr: *bool) ?ClangFunctionType {
    const canon = qt.getCanonicalType();
    var ty = canon.getTypePtr();
    is_ptr.* = false;

    if (ty.getTypeClass() == .Pointer) {
        is_ptr.* = true;
        const child_qt = ty.getPointeeType();
        ty = child_qt.getTypePtr();
    }
    if (ty.getTypeClass() == .FunctionProto) {
        return ClangFunctionType{ .Proto = @as(*const clang.FunctionProtoType, @ptrCast(ty)) };
    }
    if (ty.getTypeClass() == .FunctionNoProto) {
        return ClangFunctionType{ .NoProto = @as(*const clang.FunctionType, @ptrCast(ty)) };
    }
    return null;
}

fn transUnaryExprOrTypeTraitExpr(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.UnaryExprOrTypeTraitExpr,
    result_used: ResultUsed,
) TransError!Node {
    const loc = stmt.getBeginLoc();
    const type_node = try transQualType(c, scope, stmt.getTypeOfArgument(), loc);

    const kind = stmt.getKind();
    const node = switch (kind) {
        .SizeOf => try Tag.sizeof.create(c.arena, type_node),
        .AlignOf => try Tag.alignof.create(c.arena, type_node),
        .DataSizeOf,
        .PreferredAlignOf,
        .VecStep,
        .OpenMPRequiredSimdAlign,
        => return fail(
            c,
            error.UnsupportedTranslation,
            loc,
            "unsupported type trait kind {}",
            .{kind},
        ),
    };
    return maybeSuppressResult(c, result_used, node);
}

fn qualTypeHasWrappingOverflow(qt: clang.QualType) bool {
    if (cIsUnsignedInteger(qt)) {
        // unsigned integer overflow wraps around.
        return true;
    } else {
        // float, signed integer, and pointer overflow is undefined behavior.
        return false;
    }
}

fn transUnaryOperator(c: *Context, scope: *Scope, stmt: *const clang.UnaryOperator, used: ResultUsed) TransError!Node {
    const op_expr = stmt.getSubExpr();
    switch (stmt.getOpcode()) {
        .PostInc => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePostCrement(c, scope, stmt, .add_wrap_assign, used)
        else
            return transCreatePostCrement(c, scope, stmt, .add_assign, used),
        .PostDec => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePostCrement(c, scope, stmt, .sub_wrap_assign, used)
        else
            return transCreatePostCrement(c, scope, stmt, .sub_assign, used),
        .PreInc => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePreCrement(c, scope, stmt, .add_wrap_assign, used)
        else
            return transCreatePreCrement(c, scope, stmt, .add_assign, used),
        .PreDec => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePreCrement(c, scope, stmt, .sub_wrap_assign, used)
        else
            return transCreatePreCrement(c, scope, stmt, .sub_assign, used),
        .AddrOf => {
            return Tag.address_of.create(c.arena, try transExpr(c, scope, op_expr, used));
        },
        .Deref => {
            if (qualTypeWasDemotedToOpaque(c, stmt.getType()))
                return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "cannot dereference opaque type", .{});

            const node = try transExpr(c, scope, op_expr, used);
            var is_ptr = false;
            const fn_ty = qualTypeGetFnProto(op_expr.getType(), &is_ptr);
            if (fn_ty != null and is_ptr)
                return node;
            return Tag.deref.create(c.arena, node);
        },
        .Plus => return transExpr(c, scope, op_expr, used),
        .Minus => {
            if (!qualTypeHasWrappingOverflow(op_expr.getType())) {
                const sub_expr_node = try transExpr(c, scope, op_expr, .used);
                const to_negate = if (isBoolRes(sub_expr_node)) blk: {
                    const ty_node = try Tag.type.create(c.arena, "c_int");
                    const int_node = try Tag.int_from_bool.create(c.arena, sub_expr_node);
                    break :blk try Tag.as.create(c.arena, .{ .lhs = ty_node, .rhs = int_node });
                } else sub_expr_node;
                return Tag.negate.create(c.arena, to_negate);
            } else if (cIsUnsignedInteger(op_expr.getType())) {
                // use -% x for unsigned integers
                return Tag.negate_wrap.create(c.arena, try transExpr(c, scope, op_expr, .used));
            } else return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "C negation with non float non integer", .{});
        },
        .Not => {
            return Tag.bit_not.create(c.arena, try transExpr(c, scope, op_expr, .used));
        },
        .LNot => {
            return Tag.not.create(c.arena, try transBoolExpr(c, scope, op_expr, .used));
        },
        .Extension => {
            return transExpr(c, scope, stmt.getSubExpr(), used);
        },
        else => return fail(c, error.UnsupportedTranslation, stmt.getBeginLoc(), "unsupported C translation {}", .{stmt.getOpcode()}),
    }
}

fn transCreatePreCrement(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.UnaryOperator,
    op: Tag,
    used: ResultUsed,
) TransError!Node {
    const op_expr = stmt.getSubExpr();

    if (used == .unused) {
        // common case
        // c: ++expr
        // zig: expr += 1
        const lhs = try transExpr(c, scope, op_expr, .used);
        const rhs = Tag.one_literal.init();
        return transCreateNodeInfixOp(c, op, lhs, rhs, .used);
    }
    // worst case
    // c: ++expr
    // zig: (blk: {
    // zig:     const _ref = &expr;
    // zig:     _ref.* += 1;
    // zig:     break :blk _ref.*
    // zig: })
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const ref = try block_scope.reserveMangledName(c, "ref");
    const expr = try transExpr(c, &block_scope.base, op_expr, .used);
    const addr_of = try Tag.address_of.create(c.arena, expr);
    const ref_decl = try Tag.var_simple.create(c.arena, .{ .name = ref, .init = addr_of });
    try block_scope.statements.append(ref_decl);

    const lhs_node = try Tag.identifier.create(c.arena, ref);
    const ref_node = try Tag.deref.create(c.arena, lhs_node);
    const node = try transCreateNodeInfixOp(c, op, ref_node, Tag.one_literal.init(), .used);
    try block_scope.statements.append(node);

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = ref_node,
    });
    try block_scope.statements.append(break_node);
    return block_scope.complete(c);
}

fn transCreatePostCrement(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.UnaryOperator,
    op: Tag,
    used: ResultUsed,
) TransError!Node {
    const op_expr = stmt.getSubExpr();

    if (used == .unused) {
        // common case
        // c: expr++
        // zig: expr += 1
        const lhs = try transExpr(c, scope, op_expr, .used);
        const rhs = Tag.one_literal.init();
        return transCreateNodeInfixOp(c, op, lhs, rhs, .used);
    }
    // worst case
    // c: expr++
    // zig: (blk: {
    // zig:     const _ref = &expr;
    // zig:     const _tmp = _ref.*;
    // zig:     _ref.* += 1;
    // zig:     break :blk _tmp
    // zig: })
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();
    const ref = try block_scope.reserveMangledName(c, "ref");
    const tmp = try block_scope.reserveMangledName(c, "tmp");

    const expr = try transExpr(c, &block_scope.base, op_expr, .used);
    const addr_of = try Tag.address_of.create(c.arena, expr);
    const ref_decl = try Tag.var_simple.create(c.arena, .{ .name = ref, .init = addr_of });
    try block_scope.statements.append(ref_decl);

    const lhs_node = try Tag.identifier.create(c.arena, ref);
    const ref_node = try Tag.deref.create(c.arena, lhs_node);

    const tmp_decl = try Tag.var_simple.create(c.arena, .{ .name = tmp, .init = ref_node });
    try block_scope.statements.append(tmp_decl);

    const node = try transCreateNodeInfixOp(c, op, ref_node, Tag.one_literal.init(), .used);
    try block_scope.statements.append(node);

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = try Tag.identifier.create(c.arena, tmp),
    });
    try block_scope.statements.append(break_node);
    return block_scope.complete(c);
}

fn transCompoundAssignOperator(c: *Context, scope: *Scope, stmt: *const clang.CompoundAssignOperator, used: ResultUsed) TransError!Node {
    switch (stmt.getOpcode()) {
        .MulAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreateCompoundAssign(c, scope, stmt, .mul_wrap_assign, used)
        else
            return transCreateCompoundAssign(c, scope, stmt, .mul_assign, used),
        .AddAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreateCompoundAssign(c, scope, stmt, .add_wrap_assign, used)
        else
            return transCreateCompoundAssign(c, scope, stmt, .add_assign, used),
        .SubAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreateCompoundAssign(c, scope, stmt, .sub_wrap_assign, used)
        else
            return transCreateCompoundAssign(c, scope, stmt, .sub_assign, used),
        .DivAssign => return transCreateCompoundAssign(c, scope, stmt, .div_assign, used),
        .RemAssign => return transCreateCompoundAssign(c, scope, stmt, .mod_assign, used),
        .ShlAssign => return transCreateCompoundAssign(c, scope, stmt, .shl_assign, used),
        .ShrAssign => return transCreateCompoundAssign(c, scope, stmt, .shr_assign, used),
        .AndAssign => return transCreateCompoundAssign(c, scope, stmt, .bit_and_assign, used),
        .XorAssign => return transCreateCompoundAssign(c, scope, stmt, .bit_xor_assign, used),
        .OrAssign => return transCreateCompoundAssign(c, scope, stmt, .bit_or_assign, used),
        else => return fail(
            c,
            error.UnsupportedTranslation,
            stmt.getBeginLoc(),
            "unsupported C translation {}",
            .{stmt.getOpcode()},
        ),
    }
}

fn transCreateCompoundAssign(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.CompoundAssignOperator,
    op: Tag,
    used: ResultUsed,
) TransError!Node {
    const is_shift = op == .shl_assign or op == .shr_assign;
    const is_div = op == .div_assign;
    const is_mod = op == .mod_assign;
    const lhs = stmt.getLHS();
    const rhs = stmt.getRHS();
    const loc = stmt.getBeginLoc();
    const lhs_qt = getExprQualType(c, lhs);
    const rhs_qt = getExprQualType(c, rhs);
    const is_signed = cIsSignedInteger(lhs_qt);
    const is_ptr_op_signed = qualTypeIsPtr(lhs_qt) and cIsSignedInteger(rhs_qt);
    const requires_cast = !lhs_qt.eq(rhs_qt) and !is_ptr_op_signed;

    if (used == .unused) {
        // common case
        // c: lhs += rhs
        // zig: lhs += rhs
        const lhs_node = try transExpr(c, scope, lhs, .used);
        var rhs_node = try transExpr(c, scope, rhs, .used);
        if (is_ptr_op_signed) rhs_node = try usizeCastForWrappingPtrArithmetic(c.arena, rhs_node);

        if ((is_mod or is_div) and is_signed) {
            if (requires_cast) rhs_node = try transCCast(c, scope, loc, lhs_qt, rhs_qt, rhs_node);
            const operands = .{ .lhs = lhs_node, .rhs = rhs_node };
            const builtin = if (is_mod)
                try Tag.signed_remainder.create(c.arena, operands)
            else
                try Tag.div_trunc.create(c.arena, operands);

            return transCreateNodeInfixOp(c, .assign, lhs_node, builtin, .used);
        }

        if (is_shift) {
            rhs_node = try Tag.int_cast.create(c.arena, rhs_node);
        } else if (requires_cast) {
            rhs_node = try transCCast(c, scope, loc, lhs_qt, rhs_qt, rhs_node);
        }
        return transCreateNodeInfixOp(c, op, lhs_node, rhs_node, .used);
    }
    // worst case
    // c:   lhs += rhs
    // zig: (blk: {
    // zig:     const _ref = &lhs;
    // zig:     _ref.* += rhs;
    // zig:     break :blk _ref.*
    // zig: })
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();
    const ref = try block_scope.reserveMangledName(c, "ref");

    const expr = try transExpr(c, &block_scope.base, lhs, .used);
    const addr_of = try Tag.address_of.create(c.arena, expr);
    const ref_decl = try Tag.var_simple.create(c.arena, .{ .name = ref, .init = addr_of });
    try block_scope.statements.append(ref_decl);

    const lhs_node = try Tag.identifier.create(c.arena, ref);
    const ref_node = try Tag.deref.create(c.arena, lhs_node);

    var rhs_node = try transExpr(c, &block_scope.base, rhs, .used);
    if (is_ptr_op_signed) rhs_node = try usizeCastForWrappingPtrArithmetic(c.arena, rhs_node);
    if ((is_mod or is_div) and is_signed) {
        if (requires_cast) rhs_node = try transCCast(c, scope, loc, lhs_qt, rhs_qt, rhs_node);
        const operands = .{ .lhs = ref_node, .rhs = rhs_node };
        const builtin = if (is_mod)
            try Tag.signed_remainder.create(c.arena, operands)
        else
            try Tag.div_trunc.create(c.arena, operands);

        const assign = try transCreateNodeInfixOp(c, .assign, ref_node, builtin, .used);
        try block_scope.statements.append(assign);
    } else {
        if (is_shift) {
            rhs_node = try Tag.int_cast.create(c.arena, rhs_node);
        } else if (requires_cast) {
            rhs_node = try transCCast(c, &block_scope.base, loc, lhs_qt, rhs_qt, rhs_node);
        }

        const assign = try transCreateNodeInfixOp(c, op, ref_node, rhs_node, .used);
        try block_scope.statements.append(assign);
    }

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = ref_node,
    });
    try block_scope.statements.append(break_node);
    return block_scope.complete(c);
}

fn removeCVQualifiers(c: *Context, dst_type_node: Node, expr: Node) Error!Node {
    const const_casted = try Tag.const_cast.create(c.arena, expr);
    const volatile_casted = try Tag.volatile_cast.create(c.arena, const_casted);
    return Tag.as.create(c.arena, .{
        .lhs = dst_type_node,
        .rhs = try Tag.ptr_cast.create(c.arena, volatile_casted),
    });
}

fn transCPtrCast(
    c: *Context,
    scope: *Scope,
    loc: clang.SourceLocation,
    dst_type: clang.QualType,
    src_type: clang.QualType,
    expr: Node,
) !Node {
    const ty = dst_type.getTypePtr();
    const child_type = ty.getPointeeType();
    const src_ty = src_type.getTypePtr();
    const src_child_type = src_ty.getPointeeType();
    const dst_type_node = try transType(c, scope, ty, loc);

    if (!src_ty.isArrayType() and ((src_child_type.isConstQualified() and
        !child_type.isConstQualified()) or
        (src_child_type.isVolatileQualified() and
        !child_type.isVolatileQualified())))
    {
        return removeCVQualifiers(c, dst_type_node, expr);
    } else {
        // Implicit downcasting from higher to lower alignment values is forbidden,
        // use @alignCast to side-step this problem
        const rhs = if (qualTypeCanon(child_type).isVoidType())
            // void has 1-byte alignment, so @alignCast is not needed
            expr
        else if (typeIsOpaque(c, qualTypeCanon(child_type), loc))
            // For opaque types a ptrCast is enough
            expr
        else blk: {
            break :blk try Tag.align_cast.create(c.arena, expr);
        };
        return Tag.as.create(c.arena, .{
            .lhs = dst_type_node,
            .rhs = try Tag.ptr_cast.create(c.arena, rhs),
        });
    }
}

fn transFloatingLiteral(c: *Context, expr: *const clang.FloatingLiteral, used: ResultUsed) TransError!Node {
    // TODO use something more accurate than widening to a larger float type and printing that result
    switch (expr.getRawSemantics()) {
        .IEEEhalf, // f16
        .IEEEsingle, // f32
        .IEEEdouble, // f64
        => {
            var dbl = expr.getValueAsApproximateDouble();
            const is_negative = dbl < 0; // -0.0 is considered non-negative
            if (is_negative) dbl = -dbl;
            const str = if (dbl == @floor(dbl))
                try std.fmt.allocPrint(c.arena, "{d}.0", .{dbl})
            else
                try std.fmt.allocPrint(c.arena, "{d}", .{dbl});
            var node = try Tag.float_literal.create(c.arena, str);
            if (is_negative) node = try Tag.negate.create(c.arena, node);
            return maybeSuppressResult(c, used, node);
        },
        .x87DoubleExtended, // f80
        .IEEEquad, // f128
        => return transFloatingLiteralQuad(c, expr, used),
        else => |format| return fail(
            c,
            error.UnsupportedTranslation,
            expr.getBeginLoc(),
            "unsupported floating point constant format {}",
            .{format},
        ),
    }
}

fn transFloatingLiteralQuad(c: *Context, expr: *const clang.FloatingLiteral, used: ResultUsed) TransError!Node {
    assert(switch (expr.getRawSemantics()) {
        .x87DoubleExtended, .IEEEquad => true,
        else => false,
    });

    var low: u64 = undefined;
    var high: u64 = undefined;
    expr.getValueAsApproximateQuadBits(&low, &high);
    var quad: f128 = @bitCast(low | @as(u128, high) << 64);
    const is_negative = quad < 0; // -0.0 is considered non-negative
    if (is_negative) quad = -quad;

    // TODO implement decimal format for f128 <https://github.com/ziglang/zig/issues/1181>
    // in the meantime, if the value can be roundtripped by casting it to f64, serializing it to
    // the decimal format and parsing it back as the exact same f128 value, then use that serialized form
    const str = fmt_decimal: {
        var buf: [512]u8 = undefined; // should be large enough to print any f64 in decimal form
        const dbl: f64 = @floatCast(quad);
        const temp_str = if (dbl == @floor(dbl))
            std.fmt.bufPrint(&buf, "{d}.0", .{dbl}) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
            }
        else
            std.fmt.bufPrint(&buf, "{d}", .{dbl}) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
            };
        const could_roundtrip = if (std.fmt.parseFloat(f128, temp_str)) |parsed_quad|
            quad == parsed_quad
        else |_|
            false;
        break :fmt_decimal if (could_roundtrip) try c.arena.dupe(u8, temp_str) else null;
    }
    // otherwise, fall back to the hexadecimal format
    orelse try std.fmt.allocPrint(c.arena, "{x}", .{quad});

    var node = try Tag.float_literal.create(c.arena, str);
    if (is_negative) node = try Tag.negate.create(c.arena, node);
    return maybeSuppressResult(c, used, node);
}

fn transBinaryConditionalOperator(c: *Context, scope: *Scope, stmt: *const clang.BinaryConditionalOperator, used: ResultUsed) TransError!Node {
    // GNU extension of the ternary operator where the middle expression is
    // omitted, the condition itself is returned if it evaluates to true
    const qt = @as(*const clang.Expr, @ptrCast(stmt)).getType();
    const res_is_bool = qualTypeIsBoolean(qt);
    const casted_stmt = @as(*const clang.AbstractConditionalOperator, @ptrCast(stmt));
    const cond_expr = casted_stmt.getCond();
    const false_expr = casted_stmt.getFalseExpr();

    // c:   (cond_expr)?:(false_expr)
    // zig: (blk: {
    //          const _cond_temp = (cond_expr);
    //          break :blk if (_cond_temp) _cond_temp else (false_expr);
    //      })
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const cond_temp = try block_scope.reserveMangledName(c, "cond_temp");
    const init_node = try transExpr(c, &block_scope.base, cond_expr, .used);
    const ref_decl = try Tag.var_simple.create(c.arena, .{ .name = cond_temp, .init = init_node });
    try block_scope.statements.append(ref_decl);

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = &block_scope.base,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond_ident = try Tag.identifier.create(c.arena, cond_temp);
    const ty = getExprQualType(c, cond_expr).getTypePtr();
    const cond_node = try finishBoolExpr(c, &cond_scope.base, cond_expr.getBeginLoc(), ty, cond_ident, .used);
    var then_body = cond_ident;
    if (!res_is_bool and isBoolRes(init_node)) {
        then_body = try Tag.int_from_bool.create(c.arena, then_body);
    }

    var else_body = try transExpr(c, &block_scope.base, false_expr, .used);
    if (!res_is_bool and isBoolRes(else_body)) {
        else_body = try Tag.int_from_bool.create(c.arena, else_body);
    }
    const if_node = try Tag.@"if".create(c.arena, .{
        .cond = cond_node,
        .then = then_body,
        .@"else" = else_body,
    });
    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = if_node,
    });
    try block_scope.statements.append(break_node);
    const res = try block_scope.complete(c);
    return maybeSuppressResult(c, used, res);
}

fn transConditionalOperator(c: *Context, scope: *Scope, stmt: *const clang.ConditionalOperator, used: ResultUsed) TransError!Node {
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const qt = @as(*const clang.Expr, @ptrCast(stmt)).getType();
    const res_is_bool = qualTypeIsBoolean(qt);
    const casted_stmt = @as(*const clang.AbstractConditionalOperator, @ptrCast(stmt));
    const cond_expr = casted_stmt.getCond();
    const true_expr = casted_stmt.getTrueExpr();
    const false_expr = casted_stmt.getFalseExpr();

    const cond = try transBoolExpr(c, &cond_scope.base, cond_expr, .used);

    var then_body = try transExpr(c, scope, true_expr, used);
    if (!res_is_bool and isBoolRes(then_body)) {
        then_body = try Tag.int_from_bool.create(c.arena, then_body);
    }

    var else_body = try transExpr(c, scope, false_expr, used);
    if (!res_is_bool and isBoolRes(else_body)) {
        else_body = try Tag.int_from_bool.create(c.arena, else_body);
    }

    const if_node = try Tag.@"if".create(c.arena, .{
        .cond = cond,
        .then = then_body,
        .@"else" = else_body,
    });
    // Clang inserts ImplicitCast(ToVoid)'s to both rhs and lhs so we don't need to suppress the result here.
    return if_node;
}

fn maybeSuppressResult(c: *Context, used: ResultUsed, result: Node) TransError!Node {
    if (used == .used) return result;
    return Tag.discard.create(c.arena, .{ .should_skip = false, .value = result });
}

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: Node) !void {
    const gop = try c.global_scope.sym_table.getOrPut(name);
    if (!gop.found_existing) {
        gop.value_ptr.* = decl_node;
        try c.global_scope.nodes.append(decl_node);
    }
}

fn transQualTypeInitializedStringLiteral(c: *Context, elem_ty: Node, string_lit: *const clang.StringLiteral) TypeError!Node {
    const string_lit_size = string_lit.getLength();
    const array_size = @as(usize, @intCast(string_lit_size));

    // incomplete array initialized with empty string, will be translated as [1]T{0}
    // see https://github.com/ziglang/zig/issues/8256
    if (array_size == 0) return Tag.array_type.create(c.arena, .{ .len = 1, .elem_type = elem_ty });

    return Tag.null_sentinel_array_type.create(c.arena, .{ .len = array_size, .elem_type = elem_ty });
}

/// Translate a qualtype for a variable with an initializer. This only matters
/// for incomplete arrays, since the initializer determines the size of the array.
fn transQualTypeInitialized(
    c: *Context,
    scope: *Scope,
    qt: clang.QualType,
    decl_init: *const clang.Expr,
    source_loc: clang.SourceLocation,
) TypeError!Node {
    const ty = qt.getTypePtr();
    if (ty.getTypeClass() == .IncompleteArray) {
        const incomplete_array_ty = @as(*const clang.IncompleteArrayType, @ptrCast(ty));
        const elem_ty = try transType(c, scope, incomplete_array_ty.getElementType().getTypePtr(), source_loc);

        switch (decl_init.getStmtClass()) {
            .StringLiteralClass => {
                const string_lit = @as(*const clang.StringLiteral, @ptrCast(decl_init));
                return transQualTypeInitializedStringLiteral(c, elem_ty, string_lit);
            },
            .InitListExprClass => {
                const init_expr = @as(*const clang.InitListExpr, @ptrCast(decl_init));
                const size = init_expr.getNumInits();

                if (init_expr.isStringLiteralInit()) {
                    assert(size == 1);
                    const string_lit = init_expr.getInit(0).castToStringLiteral().?;
                    return transQualTypeInitializedStringLiteral(c, elem_ty, string_lit);
                }

                return Tag.array_type.create(c.arena, .{ .len = size, .elem_type = elem_ty });
            },
            else => {},
        }
    }
    return transQualType(c, scope, qt, source_loc);
}

fn transQualType(c: *Context, scope: *Scope, qt: clang.QualType, source_loc: clang.SourceLocation) TypeError!Node {
    return transType(c, scope, qt.getTypePtr(), source_loc);
}

/// Produces a Zig AST node by translating a Clang QualType, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transQualTypeIntWidthOf(c: *Context, ty: clang.QualType, is_signed: bool) TypeError!Node {
    return transTypeIntWidthOf(c, qualTypeCanon(ty), is_signed);
}

/// Produces a Zig AST node by translating a Clang Type, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transTypeIntWidthOf(c: *Context, ty: *const clang.Type, is_signed: bool) TypeError!Node {
    assert(ty.getTypeClass() == .Builtin);
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));
    return Tag.type.create(c.arena, switch (builtin_ty.getKind()) {
        .Char_U, .Char_S, .UChar, .SChar, .Char8 => if (is_signed) "i8" else "u8",
        .UShort, .Short => if (is_signed) "c_short" else "c_ushort",
        .UInt, .Int => if (is_signed) "c_int" else "c_uint",
        .ULong, .Long => if (is_signed) "c_long" else "c_ulong",
        .ULongLong, .LongLong => if (is_signed) "c_longlong" else "c_ulonglong",
        .UInt128, .Int128 => if (is_signed) "i128" else "u128",
        .Char16 => if (is_signed) "i16" else "u16",
        .Char32 => if (is_signed) "i32" else "u32",
        else => unreachable, // only call this function when it has already been determined the type is int
    });
}

fn isCBuiltinType(qt: clang.QualType, kind: clang.BuiltinTypeKind) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin)
        return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return builtin_ty.getKind() == kind;
}

fn qualTypeIsPtr(qt: clang.QualType) bool {
    return qualTypeCanon(qt).getTypeClass() == .Pointer;
}

fn qualTypeIsBoolean(qt: clang.QualType) bool {
    return qualTypeCanon(qt).isBooleanType();
}

fn qualTypeIntBitWidth(c: *Context, qt: clang.QualType) !u32 {
    const ty = qt.getTypePtr();

    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));

            switch (builtin_ty.getKind()) {
                .Char_U,
                .UChar,
                .Char_S,
                .SChar,
                => return 8,
                .UInt128,
                .Int128,
                => return 128,
                else => return 0,
            }

            unreachable;
        },
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));
            const typedef_decl = typedef_ty.getDecl();
            const type_name = try c.str(@as(*const clang.NamedDecl, @ptrCast(typedef_decl)).getName_bytes_begin());

            if (mem.eql(u8, type_name, "uint8_t") or mem.eql(u8, type_name, "int8_t")) {
                return 8;
            } else if (mem.eql(u8, type_name, "uint16_t") or mem.eql(u8, type_name, "int16_t")) {
                return 16;
            } else if (mem.eql(u8, type_name, "uint32_t") or mem.eql(u8, type_name, "int32_t")) {
                return 32;
            } else if (mem.eql(u8, type_name, "uint64_t") or mem.eql(u8, type_name, "int64_t")) {
                return 64;
            } else {
                return 0;
            }
        },
        else => return 0,
    }
}

fn qualTypeChildIsFnProto(qt: clang.QualType) bool {
    const ty = qualTypeCanon(qt);

    switch (ty.getTypeClass()) {
        .FunctionProto, .FunctionNoProto => return true,
        else => return false,
    }
}

fn qualTypeCanon(qt: clang.QualType) *const clang.Type {
    const canon = qt.getCanonicalType();
    return canon.getTypePtr();
}

fn getExprQualType(c: *Context, expr: *const clang.Expr) clang.QualType {
    blk: {
        // If this is a C `char *`, turn it into a `const char *`
        if (expr.getStmtClass() != .ImplicitCastExprClass) break :blk;
        const cast_expr = @as(*const clang.ImplicitCastExpr, @ptrCast(expr));
        if (cast_expr.getCastKind() != .ArrayToPointerDecay) break :blk;
        const sub_expr = cast_expr.getSubExpr();
        if (sub_expr.getStmtClass() != .StringLiteralClass) break :blk;
        const array_qt = sub_expr.getType();
        const array_type = @as(*const clang.ArrayType, @ptrCast(array_qt.getTypePtr()));
        var pointee_qt = array_type.getElementType();
        pointee_qt.addConst();
        return c.clang_context.getPointerType(pointee_qt);
    }
    return expr.getType();
}

fn typeIsOpaque(c: *Context, ty: *const clang.Type, loc: clang.SourceLocation) bool {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));
            return builtin_ty.getKind() == .Void;
        },
        .Record => {
            const record_ty = @as(*const clang.RecordType, @ptrCast(ty));
            const record_decl = record_ty.getDecl();
            const record_def = record_decl.getDefinition() orelse
                return true;
            var it = record_def.field_begin();
            const end_it = record_def.field_end();
            while (it.neq(end_it)) : (it = it.next()) {
                const field_decl = it.deref();

                if (field_decl.isBitField()) {
                    return true;
                }
            }
            return false;
        },
        .Elaborated => {
            const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(ty));
            const qt = elaborated_ty.getNamedType();
            return typeIsOpaque(c, qt.getTypePtr(), loc);
        },
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));
            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return typeIsOpaque(c, underlying_type.getTypePtr(), loc);
        },
        else => return false,
    }
}

/// plain `char *` (not const; not explicitly signed or unsigned)
fn qualTypeIsCharStar(qt: clang.QualType) bool {
    if (qualTypeIsPtr(qt)) {
        const child_qt = qualTypeCanon(qt).getPointeeType();
        return cIsUnqualifiedChar(child_qt) and !child_qt.isConstQualified();
    }
    return false;
}

/// C `char` without explicit signed or unsigned qualifier
fn cIsUnqualifiedChar(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .Char_S, .Char_U => true,
        else => false,
    };
}

fn cIsInteger(qt: clang.QualType) bool {
    return cIsSignedInteger(qt) or cIsUnsignedInteger(qt);
}

fn cIsUnsignedInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .Char_U,
        .UChar,
        .Char_S,
        .UShort,
        .UInt,
        .ULong,
        .ULongLong,
        .UInt128,
        .WChar_U,
        => true,
        else => false,
    };
}

fn cIntTypeToIndex(qt: clang.QualType) u8 {
    const c_type = qualTypeCanon(qt);
    assert(c_type.getTypeClass() == .Builtin);
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .Bool, .Char_U, .Char_S, .UChar, .SChar, .Char8 => 1,
        .WChar_U, .WChar_S => 2,
        .UShort, .Short, .Char16 => 3,
        .UInt, .Int, .Char32 => 4,
        .ULong, .Long => 5,
        .ULongLong, .LongLong => 6,
        .UInt128, .Int128 => 7,
        else => unreachable,
    };
}

fn cIntTypeCmp(a: clang.QualType, b: clang.QualType) math.Order {
    const a_index = cIntTypeToIndex(a);
    const b_index = cIntTypeToIndex(b);
    return math.order(a_index, b_index);
}

/// Checks if expr is an integer literal >= 0
fn cIsNonNegativeIntLiteral(c: *Context, expr: *const clang.Expr) bool {
    if (@as(*const clang.Stmt, @ptrCast(expr)).getStmtClass() == .IntegerLiteralClass) {
        var signum: c_int = undefined;
        if (!(@as(*const clang.IntegerLiteral, @ptrCast(expr)).getSignum(&signum, c.clang_context))) {
            return false;
        }
        return signum >= 0;
    }
    return false;
}

fn cIsSignedInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .SChar,
        .Short,
        .Int,
        .Long,
        .LongLong,
        .Int128,
        .WChar_S,
        => true,
        else => false,
    };
}

fn cIsNativeInt(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return builtin_ty.getKind() == .Int;
}

fn cIsFloating(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .Float,
        .Double,
        .Float128,
        .LongDouble,
        => true,
        else => false,
    };
}

fn cIsLongLongInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(c_type));
    return switch (builtin_ty.getKind()) {
        .LongLong, .ULongLong, .Int128, .UInt128 => true,
        else => false,
    };
}
fn transCreateNodeAssign(
    c: *Context,
    scope: *Scope,
    result_used: ResultUsed,
    lhs: *const clang.Expr,
    rhs: *const clang.Expr,
) !Node {
    // common case
    // c:   lhs = rhs
    // zig: lhs = rhs
    if (result_used == .unused) {
        const lhs_node = try transExpr(c, scope, lhs, .used);
        var rhs_node = try transExprCoercing(c, scope, rhs, .used);
        if (!exprIsBooleanType(lhs) and isBoolRes(rhs_node)) {
            rhs_node = try Tag.int_from_bool.create(c.arena, rhs_node);
        }
        return transCreateNodeInfixOp(c, .assign, lhs_node, rhs_node, .used);
    }

    // worst case
    // c:   lhs = rhs
    // zig: (blk: {
    // zig:     const _tmp = rhs;
    // zig:     lhs = _tmp;
    // zig:     break :blk _tmp
    // zig: })
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.reserveMangledName(c, "tmp");
    var rhs_node = try transExpr(c, &block_scope.base, rhs, .used);
    if (!exprIsBooleanType(lhs) and isBoolRes(rhs_node)) {
        rhs_node = try Tag.int_from_bool.create(c.arena, rhs_node);
    }

    const tmp_decl = try Tag.var_simple.create(c.arena, .{ .name = tmp, .init = rhs_node });
    try block_scope.statements.append(tmp_decl);

    const lhs_node = try transExpr(c, &block_scope.base, lhs, .used);
    const tmp_ident = try Tag.identifier.create(c.arena, tmp);
    const assign = try transCreateNodeInfixOp(c, .assign, lhs_node, tmp_ident, .used);
    try block_scope.statements.append(assign);

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = tmp_ident,
    });
    try block_scope.statements.append(break_node);
    return block_scope.complete(c);
}

fn transCreateNodeInfixOp(
    c: *Context,
    op: Tag,
    lhs: Node,
    rhs: Node,
    used: ResultUsed,
) !Node {
    const payload = try c.arena.create(ast.Payload.BinOp);
    payload.* = .{
        .base = .{ .tag = op },
        .data = .{
            .lhs = lhs,
            .rhs = rhs,
        },
    };
    return maybeSuppressResult(c, used, Node.initPayload(&payload.base));
}

fn transCreateNodeBoolInfixOp(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.BinaryOperator,
    op: Tag,
    used: ResultUsed,
) !Node {
    std.debug.assert(op == .@"and" or op == .@"or");

    const lhs = try transBoolExpr(c, scope, stmt.getLHS(), .used);
    const rhs = try transBoolExpr(c, scope, stmt.getRHS(), .used);

    return transCreateNodeInfixOp(c, op, lhs, rhs, used);
}

fn transCreateNodeAPInt(c: *Context, int: *const clang.APSInt) !Node {
    const num_limbs = math.cast(usize, int.getNumWords()) orelse return error.OutOfMemory;
    var aps_int = int;
    const is_negative = int.isSigned() and int.isNegative();
    if (is_negative) aps_int = aps_int.negate();
    defer if (is_negative) {
        aps_int.free();
    };

    const limbs = try c.arena.alloc(math.big.Limb, num_limbs);
    defer c.arena.free(limbs);

    const data = aps_int.getRawData();
    switch (@sizeOf(math.big.Limb)) {
        8 => {
            var i: usize = 0;
            while (i < num_limbs) : (i += 1) {
                limbs[i] = data[i];
            }
        },
        4 => {
            var limb_i: usize = 0;
            var data_i: usize = 0;
            while (limb_i < num_limbs) : ({
                limb_i += 2;
                data_i += 1;
            }) {
                limbs[limb_i] = @as(u32, @truncate(data[data_i]));
                limbs[limb_i + 1] = @as(u32, @truncate(data[data_i] >> 32));
            }
        },
        else => @compileError("unimplemented"),
    }

    const big: math.big.int.Const = .{ .limbs = limbs, .positive = true };
    const str = big.toStringAlloc(c.arena, 10, .lower) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    const res = try Tag.integer_literal.create(c.arena, str);
    if (is_negative) return Tag.negate.create(c.arena, res);
    return res;
}

fn transCreateNodeNumber(c: *Context, num: anytype, num_kind: enum { int, float }) !Node {
    const fmt_s = switch (@typeInfo(@TypeOf(num))) {
        .Int, .ComptimeInt => "{d}",
        else => "{s}",
    };
    const str = try std.fmt.allocPrint(c.arena, fmt_s, .{num});
    if (num_kind == .float)
        return Tag.float_literal.create(c.arena, str)
    else
        return Tag.integer_literal.create(c.arena, str);
}

fn transCreateNodeMacroFn(c: *Context, name: []const u8, ref: Node, proto_alias: *ast.Payload.Func) !Node {
    var fn_params = std.ArrayList(ast.Payload.Param).init(c.gpa);
    defer fn_params.deinit();

    for (proto_alias.data.params) |param| {
        const param_name = param.name orelse
            try std.fmt.allocPrint(c.arena, "arg_{d}", .{c.getMangle()});

        try fn_params.append(.{
            .name = param_name,
            .type = param.type,
            .is_noalias = param.is_noalias,
        });
    }

    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init.?
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        unreachable;

    const unwrap_expr = try Tag.unwrap.create(c.arena, init);
    const args = try c.arena.alloc(Node, fn_params.items.len);
    for (fn_params.items, 0..) |param, i| {
        args[i] = try Tag.identifier.create(c.arena, param.name.?);
    }
    const call_expr = try Tag.call.create(c.arena, .{
        .lhs = unwrap_expr,
        .args = args,
    });
    const return_expr = try Tag.@"return".create(c.arena, call_expr);
    const block = try Tag.block_single.create(c.arena, return_expr);

    return Tag.pub_inline_fn.create(c.arena, .{
        .name = name,
        .params = try c.arena.dupe(ast.Payload.Param, fn_params.items),
        .return_type = proto_alias.data.return_type,
        .body = block,
    });
}

fn transCreateNodeShiftOp(
    c: *Context,
    scope: *Scope,
    stmt: *const clang.BinaryOperator,
    op: Tag,
    used: ResultUsed,
) !Node {
    std.debug.assert(op == .shl or op == .shr);

    const lhs_expr = stmt.getLHS();
    const rhs_expr = stmt.getRHS();
    // lhs >> @as(u5, rh)

    const lhs = try transExpr(c, scope, lhs_expr, .used);

    const rhs = try transExprCoercing(c, scope, rhs_expr, .used);
    const rhs_casted = try Tag.int_cast.create(c.arena, rhs);

    return transCreateNodeInfixOp(c, op, lhs, rhs_casted, used);
}

fn transType(c: *Context, scope: *Scope, ty: *const clang.Type, source_loc: clang.SourceLocation) TypeError!Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));
            return Tag.type.create(c.arena, switch (builtin_ty.getKind()) {
                .Void => "anyopaque",
                .Bool => "bool",
                .Char_U, .UChar, .Char_S, .Char8 => "u8",
                .SChar => "i8",
                .UShort => "c_ushort",
                .UInt => "c_uint",
                .ULong => "c_ulong",
                .ULongLong => "c_ulonglong",
                .Short => "c_short",
                .Int => "c_int",
                .Long => "c_long",
                .LongLong => "c_longlong",
                .UInt128 => "u128",
                .Int128 => "i128",
                .Float => "f32",
                .Double => "f64",
                .Float128 => "f128",
                .Float16 => "f16",
                .LongDouble => "c_longdouble",
                else => return fail(c, error.UnsupportedType, source_loc, "unsupported builtin type", .{}),
            });
        },
        .FunctionProto => {
            const fn_proto_ty = @as(*const clang.FunctionProtoType, @ptrCast(ty));
            const fn_proto = try transFnProto(c, null, fn_proto_ty, source_loc, null, false);
            return Node.initPayload(&fn_proto.base);
        },
        .FunctionNoProto => {
            const fn_no_proto_ty = @as(*const clang.FunctionType, @ptrCast(ty));
            const fn_proto = try transFnNoProto(c, fn_no_proto_ty, source_loc, null, false);
            return Node.initPayload(&fn_proto.base);
        },
        .Paren => {
            const paren_ty = @as(*const clang.ParenType, @ptrCast(ty));
            return transQualType(c, scope, paren_ty.getInnerType(), source_loc);
        },
        .Pointer => {
            const child_qt = ty.getPointeeType();
            const is_fn_proto = qualTypeChildIsFnProto(child_qt);
            const is_const = is_fn_proto or child_qt.isConstQualified();
            const is_volatile = child_qt.isVolatileQualified();
            const elem_type = try transQualType(c, scope, child_qt, source_loc);
            const ptr_info = .{
                .is_const = is_const,
                .is_volatile = is_volatile,
                .elem_type = elem_type,
            };
            if (is_fn_proto or
                typeIsOpaque(c, child_qt.getTypePtr(), source_loc) or
                qualTypeWasDemotedToOpaque(c, child_qt))
            {
                const ptr = try Tag.single_pointer.create(c.arena, ptr_info);
                return Tag.optional_type.create(c.arena, ptr);
            }

            return Tag.c_pointer.create(c.arena, ptr_info);
        },
        .ConstantArray => {
            const const_arr_ty = @as(*const clang.ConstantArrayType, @ptrCast(ty));

            const size_ap_int = const_arr_ty.getSize();
            const size = size_ap_int.getLimitedValue(usize);
            const elem_type = try transType(c, scope, const_arr_ty.getElementType().getTypePtr(), source_loc);

            return Tag.array_type.create(c.arena, .{ .len = size, .elem_type = elem_type });
        },
        .IncompleteArray => {
            const incomplete_array_ty = @as(*const clang.IncompleteArrayType, @ptrCast(ty));

            const child_qt = incomplete_array_ty.getElementType();
            const is_const = child_qt.isConstQualified();
            const is_volatile = child_qt.isVolatileQualified();
            const elem_type = try transQualType(c, scope, child_qt, source_loc);

            return Tag.c_pointer.create(c.arena, .{ .is_const = is_const, .is_volatile = is_volatile, .elem_type = elem_type });
        },
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));

            const typedef_decl = typedef_ty.getDecl();
            var trans_scope = scope;
            if (@as(*const clang.Decl, @ptrCast(typedef_decl)).castToNamedDecl()) |named_decl| {
                const decl_name = try c.str(named_decl.getName_bytes_begin());
                if (c.global_names.get(decl_name)) |_| trans_scope = &c.global_scope.base;
                if (builtin_typedef_map.get(decl_name)) |builtin| return Tag.type.create(c.arena, builtin);
            }
            try transTypeDef(c, trans_scope, typedef_decl);
            const name = c.decl_table.get(@intFromPtr(typedef_decl.getCanonicalDecl())).?;
            return Tag.identifier.create(c.arena, name);
        },
        .Record => {
            const record_ty = @as(*const clang.RecordType, @ptrCast(ty));

            const record_decl = record_ty.getDecl();
            var trans_scope = scope;
            if (@as(*const clang.Decl, @ptrCast(record_decl)).castToNamedDecl()) |named_decl| {
                const decl_name = try c.str(named_decl.getName_bytes_begin());
                if (c.weak_global_names.contains(decl_name)) trans_scope = &c.global_scope.base;
            }
            try transRecordDecl(c, trans_scope, record_decl);
            const name = c.decl_table.get(@intFromPtr(record_decl.getCanonicalDecl())).?;
            return Tag.identifier.create(c.arena, name);
        },
        .Enum => {
            const enum_ty = @as(*const clang.EnumType, @ptrCast(ty));

            const enum_decl = enum_ty.getDecl();
            var trans_scope = scope;
            if (@as(*const clang.Decl, @ptrCast(enum_decl)).castToNamedDecl()) |named_decl| {
                const decl_name = try c.str(named_decl.getName_bytes_begin());
                if (c.weak_global_names.contains(decl_name)) trans_scope = &c.global_scope.base;
            }
            try transEnumDecl(c, trans_scope, enum_decl);
            const name = c.decl_table.get(@intFromPtr(enum_decl.getCanonicalDecl())).?;
            return Tag.identifier.create(c.arena, name);
        },
        .Elaborated => {
            const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(ty));
            return transQualType(c, scope, elaborated_ty.getNamedType(), source_loc);
        },
        .Decayed => {
            const decayed_ty = @as(*const clang.DecayedType, @ptrCast(ty));
            return transQualType(c, scope, decayed_ty.getDecayedType(), source_loc);
        },
        .Attributed => {
            const attributed_ty = @as(*const clang.AttributedType, @ptrCast(ty));
            return transQualType(c, scope, attributed_ty.getEquivalentType(), source_loc);
        },
        .MacroQualified => {
            const macroqualified_ty = @as(*const clang.MacroQualifiedType, @ptrCast(ty));
            return transQualType(c, scope, macroqualified_ty.getModifiedType(), source_loc);
        },
        .TypeOf => {
            const typeof_ty = @as(*const clang.TypeOfType, @ptrCast(ty));
            return transQualType(c, scope, typeof_ty.getUnmodifiedType(), source_loc);
        },
        .TypeOfExpr => {
            const typeofexpr_ty = @as(*const clang.TypeOfExprType, @ptrCast(ty));
            const underlying_expr = transExpr(c, scope, typeofexpr_ty.getUnderlyingExpr(), .used) catch |err| switch (err) {
                error.UnsupportedTranslation => {
                    return fail(c, error.UnsupportedType, source_loc, "unsupported underlying expression for TypeOfExpr", .{});
                },
                else => |e| return e,
            };
            return Tag.typeof.create(c.arena, underlying_expr);
        },
        .Vector => {
            const vector_ty = @as(*const clang.VectorType, @ptrCast(ty));
            const num_elements = vector_ty.getNumElements();
            const element_qt = vector_ty.getElementType();
            return Tag.vector.create(c.arena, .{
                .lhs = try transCreateNodeNumber(c, num_elements, .int),
                .rhs = try transQualType(c, scope, element_qt, source_loc),
            });
        },
        .BitInt, .ExtVector => {
            const type_name = try c.str(ty.getTypeClassName());
            return fail(c, error.UnsupportedType, source_loc, "TODO implement translation of type: '{s}'", .{type_name});
        },
        else => {
            const type_name = try c.str(ty.getTypeClassName());
            return fail(c, error.UnsupportedType, source_loc, "unsupported type: '{s}'", .{type_name});
        },
    }
}

fn qualTypeWasDemotedToOpaque(c: *Context, qt: clang.QualType) bool {
    const ty = qt.getTypePtr();
    switch (qt.getTypeClass()) {
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));

            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return qualTypeWasDemotedToOpaque(c, underlying_type);
        },
        .Record => {
            const record_ty = @as(*const clang.RecordType, @ptrCast(ty));

            const record_decl = record_ty.getDecl();
            const canonical = @intFromPtr(record_decl.getCanonicalDecl());
            if (c.opaque_demotes.contains(canonical)) return true;

            // check all childern for opaque types.
            var it = record_decl.field_begin();
            const end_it = record_decl.field_end();
            while (it.neq(end_it)) : (it = it.next()) {
                const field_decl = it.deref();
                if (qualTypeWasDemotedToOpaque(c, field_decl.getType())) return true;
            }
            return false;
        },
        .Enum => {
            const enum_ty = @as(*const clang.EnumType, @ptrCast(ty));

            const enum_decl = enum_ty.getDecl();
            const canonical = @intFromPtr(enum_decl.getCanonicalDecl());
            return c.opaque_demotes.contains(canonical);
        },
        .Elaborated => {
            const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(ty));
            return qualTypeWasDemotedToOpaque(c, elaborated_ty.getNamedType());
        },
        .Decayed => {
            const decayed_ty = @as(*const clang.DecayedType, @ptrCast(ty));
            return qualTypeWasDemotedToOpaque(c, decayed_ty.getDecayedType());
        },
        .Attributed => {
            const attributed_ty = @as(*const clang.AttributedType, @ptrCast(ty));
            return qualTypeWasDemotedToOpaque(c, attributed_ty.getEquivalentType());
        },
        .MacroQualified => {
            const macroqualified_ty = @as(*const clang.MacroQualifiedType, @ptrCast(ty));
            return qualTypeWasDemotedToOpaque(c, macroqualified_ty.getModifiedType());
        },
        else => return false,
    }
}

fn isAnyopaque(qt: clang.QualType) bool {
    const ty = qt.getTypePtr();
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @as(*const clang.BuiltinType, @ptrCast(ty));
            return builtin_ty.getKind() == .Void;
        },
        .Typedef => {
            const typedef_ty = @as(*const clang.TypedefType, @ptrCast(ty));
            const typedef_decl = typedef_ty.getDecl();
            return isAnyopaque(typedef_decl.getUnderlyingType());
        },
        .Elaborated => {
            const elaborated_ty = @as(*const clang.ElaboratedType, @ptrCast(ty));
            return isAnyopaque(elaborated_ty.getNamedType().getCanonicalType());
        },
        .Decayed => {
            const decayed_ty = @as(*const clang.DecayedType, @ptrCast(ty));
            return isAnyopaque(decayed_ty.getDecayedType().getCanonicalType());
        },
        .Attributed => {
            const attributed_ty = @as(*const clang.AttributedType, @ptrCast(ty));
            return isAnyopaque(attributed_ty.getEquivalentType().getCanonicalType());
        },
        .MacroQualified => {
            const macroqualified_ty = @as(*const clang.MacroQualifiedType, @ptrCast(ty));
            return isAnyopaque(macroqualified_ty.getModifiedType().getCanonicalType());
        },
        else => return false,
    }
}

const FnDeclContext = struct {
    fn_name: []const u8,
    has_body: bool,
    storage_class: clang.StorageClass,
    is_always_inline: bool,
    is_export: bool,
};

fn transCC(
    c: *Context,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
) !CallingConvention {
    const clang_cc = fn_ty.getCallConv();
    switch (clang_cc) {
        .C => return CallingConvention.C,
        .X86StdCall => return CallingConvention.Stdcall,
        .X86FastCall => return CallingConvention.Fastcall,
        .X86VectorCall, .AArch64VectorCall => return CallingConvention.Vectorcall,
        .X86ThisCall => return CallingConvention.Thiscall,
        .AAPCS => return CallingConvention.AAPCS,
        .AAPCS_VFP => return CallingConvention.AAPCSVFP,
        .X86_64SysV => return CallingConvention.SysV,
        else => return fail(
            c,
            error.UnsupportedType,
            source_loc,
            "unsupported calling convention: {s}",
            .{@tagName(clang_cc)},
        ),
    }
}

fn transFnProto(
    c: *Context,
    fn_decl: ?*const clang.FunctionDecl,
    fn_proto_ty: *const clang.FunctionProtoType,
    source_loc: clang.SourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Payload.Func {
    const fn_ty = @as(*const clang.FunctionType, @ptrCast(fn_proto_ty));
    const cc = try transCC(c, fn_ty, source_loc);
    const is_var_args = fn_proto_ty.isVariadic();
    return finishTransFnProto(c, fn_decl, fn_proto_ty, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn transFnNoProto(
    c: *Context,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Payload.Func {
    const cc = try transCC(c, fn_ty, source_loc);
    const is_var_args = if (fn_decl_context) |ctx| (!ctx.is_export and ctx.storage_class != .Static and !ctx.is_always_inline) else true;
    return finishTransFnProto(c, null, null, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn finishTransFnProto(
    c: *Context,
    fn_decl: ?*const clang.FunctionDecl,
    fn_proto_ty: ?*const clang.FunctionProtoType,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_var_args: bool,
    cc: CallingConvention,
    is_pub: bool,
) !*ast.Payload.Func {
    const is_export = if (fn_decl_context) |ctx| ctx.is_export else false;
    const is_extern = if (fn_decl_context) |ctx| !ctx.has_body else false;
    const is_inline = if (fn_decl_context) |ctx| ctx.is_always_inline else false;
    const scope = &c.global_scope.base;

    const param_count: usize = if (fn_proto_ty != null) fn_proto_ty.?.getNumParams() else 0;
    var fn_params = try std.ArrayList(ast.Payload.Param).initCapacity(c.gpa, param_count);
    defer fn_params.deinit();

    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        const param_qt = fn_proto_ty.?.getParamType(@as(c_uint, @intCast(i)));
        const is_noalias = param_qt.isRestrictQualified();

        const param_name: ?[]const u8 =
            if (fn_decl) |decl|
        blk: {
            const param = decl.getParamDecl(@as(c_uint, @intCast(i)));
            const param_name: []const u8 = try c.str(@as(*const clang.NamedDecl, @ptrCast(param)).getName_bytes_begin());
            if (param_name.len < 1)
                break :blk null;

            break :blk param_name;
        } else null;
        const type_node = try transQualType(c, scope, param_qt, source_loc);

        fn_params.addOneAssumeCapacity().* = .{
            .is_noalias = is_noalias,
            .name = param_name,
            .type = type_node,
        };
    }

    const linksection_string = blk: {
        if (fn_decl) |decl| {
            var str_len: usize = undefined;
            if (decl.getSectionAttribute(&str_len)) |str_ptr| {
                break :blk str_ptr[0..str_len];
            }
        }
        break :blk null;
    };

    const alignment = if (fn_decl) |decl| ClangAlignment.forFunc(c, decl).zigAlignment() else null;

    const explicit_callconv = if ((is_inline or is_export or is_extern) and cc == .C) null else cc;

    const return_type_node = blk: {
        if (fn_ty.getNoReturnAttr()) {
            break :blk Tag.noreturn_type.init();
        } else {
            const return_qt = fn_ty.getReturnType();
            if (isAnyopaque(return_qt)) {
                // convert primitive anyopaque to actual void (only for return type)
                break :blk Tag.void_type.init();
            } else {
                break :blk transQualType(c, scope, return_qt, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try warn(c, scope, source_loc, "unsupported function proto return type", .{});
                        return err;
                    },
                    error.OutOfMemory => |e| return e,
                };
            }
        }
    };
    const name: ?[]const u8 = if (fn_decl_context) |ctx| ctx.fn_name else null;
    const payload = try c.arena.create(ast.Payload.Func);
    payload.* = .{
        .base = .{ .tag = .func },
        .data = .{
            .is_pub = is_pub,
            .is_extern = is_extern,
            .is_export = is_export,
            .is_inline = is_inline,
            .is_var_args = is_var_args,
            .name = name,
            .linksection_string = linksection_string,
            .explicit_callconv = explicit_callconv,
            .params = try c.arena.dupe(ast.Payload.Param, fn_params.items),
            .return_type = return_type_node,
            .body = null,
            .alignment = alignment,
        },
    };
    return payload;
}

fn warn(c: *Context, scope: *Scope, loc: clang.SourceLocation, comptime format: []const u8, args: anytype) !void {
    const str = try c.locStr(loc);
    const value = try std.fmt.allocPrint(c.arena, "// {s}: warning: " ++ format, .{str} ++ args);
    try scope.appendNode(try Tag.warning.create(c.arena, value));
}

fn fail(
    c: *Context,
    err: anytype,
    source_loc: clang.SourceLocation,
    comptime format: []const u8,
    args: anytype,
) (@TypeOf(err) || error{OutOfMemory}) {
    try warn(c, &c.global_scope.base, source_loc, format, args);
    return err;
}

pub fn failDecl(c: *Context, loc: clang.SourceLocation, name: []const u8, comptime format: []const u8, args: anytype) Error!void {
    // location
    // pub const name = @compileError(msg);
    const fail_msg = try std.fmt.allocPrint(c.arena, format, args);
    try addTopLevelDecl(c, name, try Tag.fail_decl.create(c.arena, .{ .actual = name, .mangled = fail_msg }));
    const str = try c.locStr(loc);
    const location_comment = try std.fmt.allocPrint(c.arena, "// {s}", .{str});
    try c.global_scope.nodes.append(try Tag.warning.create(c.arena, location_comment));
}

const MacroCtx = struct {
    source: []const u8,
    list: []const CToken,
    i: usize = 0,
    loc: clang.SourceLocation,
    name: []const u8,
    refs_var_decl: bool = false,

    fn peek(self: *MacroCtx) ?CToken.Id {
        if (self.i >= self.list.len) return null;
        return self.list[self.i + 1].id;
    }

    fn next(self: *MacroCtx) ?CToken.Id {
        if (self.i >= self.list.len) return null;
        self.i += 1;
        return self.list[self.i].id;
    }

    fn skip(self: *MacroCtx, c: *Context, expected_id: CToken.Id) ParseError!void {
        const next_id = self.next().?;
        if (next_id != expected_id and !(expected_id == .identifier and next_id == .extended_identifier)) {
            try self.fail(
                c,
                "unable to translate C expr: expected '{s}' instead got '{s}'",
                .{ expected_id.symbol(), next_id.symbol() },
            );
            return error.ParseError;
        }
    }

    fn slice(self: *MacroCtx) []const u8 {
        const tok = self.list[self.i];
        return self.source[tok.start..tok.end];
    }

    fn fail(self: *MacroCtx, c: *Context, comptime fmt: []const u8, args: anytype) !void {
        return failDecl(c, self.loc, self.name, fmt, args);
    }

    fn makeSlicer(self: *const MacroCtx) MacroSlicer {
        return .{ .source = self.source, .tokens = self.list };
    }

    const MacroTranslateError = union(enum) {
        undefined_identifier: []const u8,
        invalid_arg_usage: []const u8,
    };

    fn checkTranslatableMacro(self: *MacroCtx, scope: *Scope, params: []const ast.Payload.Param) ?MacroTranslateError {
        const slicer = self.makeSlicer();
        var last_is_type_kw = false;
        var i: usize = 1; // index 0 is the macro name
        while (i < self.list.len) : (i += 1) {
            const token = self.list[i];
            switch (token.id) {
                .period, .arrow => i += 1, // skip next token since field identifiers can be unknown
                .keyword_struct, .keyword_union, .keyword_enum => if (!last_is_type_kw) {
                    last_is_type_kw = true;
                    continue;
                },
                .identifier, .extended_identifier => {
                    const identifier = slicer.slice(token);
                    const is_param = for (params) |param| {
                        if (param.name != null and mem.eql(u8, identifier, param.name.?)) break true;
                    } else false;
                    if (is_param and last_is_type_kw) {
                        return .{ .invalid_arg_usage = identifier };
                    }
                    if (!scope.contains(identifier) and !isBuiltinDefined(identifier) and !is_param) {
                        return .{ .undefined_identifier = identifier };
                    }
                },
                else => {},
            }
            last_is_type_kw = false;
        }
        return null;
    }
};

fn getMacroText(unit: *const clang.ASTUnit, c: *const Context, macro: *const clang.MacroDefinitionRecord) ![]const u8 {
    const begin_loc = macro.getSourceRange_getBegin();
    const end_loc = clang.Lexer.getLocForEndOfToken(macro.getSourceRange_getEnd(), c.source_manager, unit);

    const begin_c = c.source_manager.getCharacterData(begin_loc);
    const end_c = c.source_manager.getCharacterData(end_loc);
    const slice_len = @intFromPtr(end_c) - @intFromPtr(begin_c);

    var comp = aro.Compilation.init(c.gpa);
    defer comp.deinit();
    const result = comp.addSourceFromBuffer("", begin_c[0..slice_len]) catch return error.OutOfMemory;

    return c.arena.dupe(u8, result.buf);
}

fn transPreprocessorEntities(c: *Context, unit: *clang.ASTUnit) Error!void {
    // TODO if we see #undef, delete it from the table
    var it = unit.getLocalPreprocessingEntities_begin();
    const it_end = unit.getLocalPreprocessingEntities_end();
    var tok_list = std.ArrayList(CToken).init(c.gpa);
    defer tok_list.deinit();
    const scope = c.global_scope;

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = it.deref();
        tok_list.items.len = 0;
        switch (entity.getKind()) {
            .MacroDefinitionKind => {
                const macro = @as(*clang.MacroDefinitionRecord, @ptrCast(entity));
                const raw_name = macro.getName_getNameStart();
                const begin_loc = macro.getSourceRange_getBegin();

                const name = try c.str(raw_name);
                if (scope.containsNow(name)) {
                    continue;
                }

                const source = try getMacroText(unit, c, macro);

                try common.tokenizeMacro(source, &tok_list);

                var macro_ctx = MacroCtx{
                    .source = source,
                    .list = tok_list.items,
                    .name = name,
                    .loc = begin_loc,
                };
                assert(mem.eql(u8, macro_ctx.slice(), name));

                var macro_fn = false;
                switch (macro_ctx.peek().?) {
                    .identifier, .extended_identifier => {
                        // if it equals itself, ignore. for example, from stdio.h:
                        // #define stdin stdin
                        const tok = macro_ctx.list[1];
                        if (mem.eql(u8, name, source[tok.start..tok.end])) {
                            assert(!c.global_names.contains(source[tok.start..tok.end]));
                            continue;
                        }
                    },
                    .nl, .eof => {
                        // this means it is a macro without a value
                        // We define it as an empty string so that it can still be used with ++
                        const str_node = try Tag.string_literal.create(c.arena, "\"\"");
                        const var_decl = try Tag.pub_var_simple.create(c.arena, .{ .name = name, .init = str_node });
                        try addTopLevelDecl(c, name, var_decl);
                        try c.global_scope.blank_macros.put(name, {});
                        continue;
                    },
                    .l_paren => {
                        // if the name is immediately followed by a '(' then it is a function
                        macro_fn = macro_ctx.list[0].end == macro_ctx.list[1].start;
                    },
                    else => {},
                }

                (if (macro_fn)
                    transMacroFnDefine(c, &macro_ctx)
                else
                    transMacroDefine(c, &macro_ctx)) catch |err| switch (err) {
                    error.ParseError => continue,
                    error.OutOfMemory => |e| return e,
                };
            },
            else => {},
        }
    }
}

fn transMacroDefine(c: *Context, m: *MacroCtx) ParseError!void {
    const scope = &c.global_scope.base;

    if (m.checkTranslatableMacro(scope, &.{})) |err| switch (err) {
        .undefined_identifier => |ident| return m.fail(c, "unable to translate macro: undefined identifier `{s}`", .{ident}),
        .invalid_arg_usage => unreachable, // no args
    };

    // Check if the macro only uses other blank macros.
    while (true) {
        switch (m.peek().?) {
            .identifier, .extended_identifier => {
                const tok = m.list[m.i + 1];
                const slice = m.source[tok.start..tok.end];
                if (c.global_scope.blank_macros.contains(slice)) {
                    m.i += 1;
                    continue;
                }
            },
            .eof, .nl => {
                try c.global_scope.blank_macros.put(m.name, {});
                const init_node = try Tag.string_literal.create(c.arena, "\"\"");
                const var_decl = try Tag.pub_var_simple.create(c.arena, .{ .name = m.name, .init = init_node });
                try addTopLevelDecl(c, m.name, var_decl);
                return;
            },
            else => {},
        }
        break;
    }

    const init_node = try parseCExpr(c, m, scope);
    const last = m.next().?;
    if (last != .eof and last != .nl)
        return m.fail(c, "unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const node = node: {
        const var_decl = try Tag.pub_var_simple.create(c.arena, .{ .name = m.name, .init = init_node });

        if (getFnProto(c, var_decl)) |proto_node| {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            break :node try transCreateNodeMacroFn(c, m.name, var_decl, proto_node);
        } else if (m.refs_var_decl) {
            const return_type = try Tag.typeof.create(c.arena, init_node);
            const return_expr = try Tag.@"return".create(c.arena, init_node);
            const block = try Tag.block_single.create(c.arena, return_expr);
            try warn(c, scope, m.loc, "macro '{s}' contains a runtime value, translated to function", .{m.name});

            break :node try Tag.pub_inline_fn.create(c.arena, .{
                .name = m.name,
                .params = &.{},
                .return_type = return_type,
                .body = block,
            });
        }

        break :node var_decl;
    };

    try addTopLevelDecl(c, m.name, node);
}

fn transMacroFnDefine(c: *Context, m: *MacroCtx) ParseError!void {
    const macro_slicer = m.makeSlicer();
    if (try c.pattern_list.match(c.gpa, macro_slicer)) |pattern| {
        const decl = try Tag.pub_var_simple.create(c.arena, .{
            .name = m.name,
            .init = try Tag.helpers_macro.create(c.arena, pattern.impl),
        });
        try addTopLevelDecl(c, m.name, decl);
        return;
    }

    var block_scope = try Scope.Block.init(c, &c.global_scope.base, false);
    defer block_scope.deinit();
    const scope = &block_scope.base;

    try m.skip(c, .l_paren);

    var fn_params = std.ArrayList(ast.Payload.Param).init(c.gpa);
    defer fn_params.deinit();

    while (true) {
        switch (m.peek().?) {
            .identifier, .extended_identifier => _ = m.next(),
            else => break,
        }

        const mangled_name = try block_scope.makeMangledName(c, m.slice());
        try fn_params.append(.{
            .is_noalias = false,
            .name = mangled_name,
            .type = Tag.@"anytype".init(),
        });
        try block_scope.discardVariable(c, mangled_name);
        if (m.peek().? != .comma) break;
        _ = m.next();
    }

    try m.skip(c, .r_paren);

    if (m.checkTranslatableMacro(scope, fn_params.items)) |err| switch (err) {
        .undefined_identifier => |ident| return m.fail(c, "unable to translate macro: undefined identifier `{s}`", .{ident}),
        .invalid_arg_usage => |ident| return m.fail(c, "unable to translate macro: untranslatable usage of arg `{s}`", .{ident}),
    };

    const expr = try parseCExpr(c, m, scope);
    const last = m.next().?;
    if (last != .eof and last != .nl)
        return m.fail(c, "unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const typeof_arg = if (expr.castTag(.block)) |some| blk: {
        const stmts = some.data.stmts;
        const blk_last = stmts[stmts.len - 1];
        const br = blk_last.castTag(.break_val).?;
        break :blk br.data.val;
    } else expr;

    const return_type = if (typeof_arg.castTag(.helpers_cast) orelse typeof_arg.castTag(.std_mem_zeroinit)) |some|
        some.data.lhs
    else if (typeof_arg.castTag(.std_mem_zeroes)) |some|
        some.data
    else
        try Tag.typeof.create(c.arena, typeof_arg);

    const return_expr = try Tag.@"return".create(c.arena, expr);
    try block_scope.statements.append(return_expr);

    const fn_decl = try Tag.pub_inline_fn.create(c.arena, .{
        .name = m.name,
        .params = try c.arena.dupe(ast.Payload.Param, fn_params.items),
        .return_type = return_type,
        .body = try block_scope.complete(c),
    });
    try addTopLevelDecl(c, m.name, fn_decl);
}

const ParseError = Error || error{ParseError};

fn parseCExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    // TODO parseCAssignExpr here
    var block_scope = try Scope.Block.init(c, scope, true);
    defer block_scope.deinit();

    const node = try parseCCondExpr(c, m, &block_scope.base);
    if (m.next().? != .comma) {
        m.i -= 1;
        return node;
    }

    var last = node;
    while (true) {
        // suppress result
        const ignore = try Tag.discard.create(c.arena, .{ .should_skip = false, .value = last });
        try block_scope.statements.append(ignore);

        last = try parseCCondExpr(c, m, &block_scope.base);
        if (m.next().? != .comma) {
            m.i -= 1;
            break;
        }
    }

    const break_node = try Tag.break_val.create(c.arena, .{
        .label = block_scope.label,
        .val = last,
    });
    try block_scope.statements.append(break_node);
    return try block_scope.complete(c);
}

fn parseCNumLit(ctx: *Context, m: *MacroCtx) ParseError!Node {
    const lit_bytes = m.slice();
    var bytes = try std.ArrayListUnmanaged(u8).initCapacity(ctx.arena, lit_bytes.len + 3);

    const prefix = aro.Tree.Token.NumberPrefix.fromString(lit_bytes);
    switch (prefix) {
        .binary => bytes.appendSliceAssumeCapacity("0b"),
        .octal => bytes.appendSliceAssumeCapacity("0o"),
        .hex => bytes.appendSliceAssumeCapacity("0x"),
        .decimal => {},
    }

    const after_prefix = lit_bytes[prefix.stringLen()..];
    const after_int = for (after_prefix, 0..) |c, i| switch (c) {
        '.' => {
            if (i == 0) {
                bytes.appendAssumeCapacity('0');
            }
            break after_prefix[i..];
        },
        'e', 'E' => {
            if (prefix != .hex) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        'p', 'P' => break after_prefix[i..],
        '0'...'9', 'a'...'d', 'A'...'D', 'f', 'F' => {
            if (!prefix.digitAllowed(c)) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        '\'' => {
            bytes.appendAssumeCapacity('_');
        },
        else => break after_prefix[i..],
    } else "";

    const after_frac = frac: {
        if (after_int.len == 0 or after_int[0] != '.') break :frac after_int;
        bytes.appendAssumeCapacity('.');
        for (after_int[1..], 1..) |c, i| {
            if (c == '\'') {
                bytes.appendAssumeCapacity('_');
                continue;
            }
            if (!prefix.digitAllowed(c)) break :frac after_int[i..];
            bytes.appendAssumeCapacity(c);
        }
        break :frac "";
    };

    const suffix_str = exponent: {
        if (after_frac.len == 0) break :exponent after_frac;
        switch (after_frac[0]) {
            'e', 'E' => {},
            'p', 'P' => if (prefix != .hex) break :exponent after_frac,
            else => break :exponent after_frac,
        }
        bytes.appendAssumeCapacity(after_frac[0]);
        for (after_frac[1..], 1..) |c, i| switch (c) {
            '+', '-', '0'...'9' => {
                bytes.appendAssumeCapacity(c);
            },
            '\'' => {
                bytes.appendAssumeCapacity('_');
            },
            else => break :exponent after_frac[i..],
        };
        break :exponent "";
    };

    const is_float = after_int.len != suffix_str.len;
    const suffix = aro.Tree.Token.NumberSuffix.fromString(suffix_str, if (is_float) .float else .int) orelse {
        try m.fail(ctx, "invalid number suffix: '{s}'", .{suffix_str});
        return error.ParseError;
    };
    if (suffix.isImaginary()) {
        try m.fail(ctx, "TODO: imaginary literals", .{});
        return error.ParseError;
    }
    if (suffix.isBitInt()) {
        try m.fail(ctx, "TODO: _BitInt literals", .{});
        return error.ParseError;
    }

    if (is_float) {
        const type_node = try Tag.type.create(ctx.arena, switch (suffix) {
            .F16 => "f16",
            .F => "f32",
            .None => "f64",
            .L => "c_longdouble",
            .W => "f80",
            .Q, .F128 => "f128",
            else => unreachable,
        });
        const rhs = try Tag.float_literal.create(ctx.arena, bytes.items);
        return Tag.as.create(ctx.arena, .{ .lhs = type_node, .rhs = rhs });
    } else {
        const type_node = try Tag.type.create(ctx.arena, switch (suffix) {
            .None => "c_int",
            .U => "c_uint",
            .L => "c_long",
            .UL => "c_ulong",
            .LL => "c_longlong",
            .ULL => "c_ulonglong",
            else => unreachable,
        });
        const value = std.fmt.parseInt(i128, bytes.items, 0) catch math.maxInt(i128);

        // make the output less noisy by skipping promoteIntLiteral where
        // it's guaranteed to not be required because of C standard type constraints
        const guaranteed_to_fit = switch (suffix) {
            .None => math.cast(i16, value) != null,
            .U => math.cast(u16, value) != null,
            .L => math.cast(i32, value) != null,
            .UL => math.cast(u32, value) != null,
            .LL => math.cast(i64, value) != null,
            .ULL => math.cast(u64, value) != null,
            else => unreachable,
        };

        const literal_node = try Tag.integer_literal.create(ctx.arena, bytes.items);
        if (guaranteed_to_fit) {
            return Tag.as.create(ctx.arena, .{ .lhs = type_node, .rhs = literal_node });
        } else {
            return Tag.helpers_promoteIntLiteral.create(ctx.arena, .{
                .type = type_node,
                .value = literal_node,
                .base = try Tag.enum_literal.create(ctx.arena, @tagName(prefix)),
            });
        }
    }
}

fn zigifyEscapeSequences(ctx: *Context, m: *MacroCtx) ![]const u8 {
    var source = m.slice();
    for (source, 0..) |c, i| {
        if (c == '\"' or c == '\'') {
            source = source[i..];
            break;
        }
    }
    for (source) |c| {
        if (c == '\\' or c == '\t') {
            break;
        }
    } else return source;
    var bytes = try ctx.arena.alloc(u8, source.len * 2);
    var state: enum {
        start,
        escape,
        hex,
        octal,
    } = .start;
    var i: usize = 0;
    var count: u8 = 0;
    var num: u8 = 0;
    for (source) |c| {
        switch (state) {
            .escape => {
                switch (c) {
                    'n', 'r', 't', '\\', '\'', '\"' => {
                        bytes[i] = c;
                    },
                    '0'...'7' => {
                        count += 1;
                        num += c - '0';
                        state = .octal;
                        bytes[i] = 'x';
                    },
                    'x' => {
                        state = .hex;
                        bytes[i] = 'x';
                    },
                    'a' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '7';
                    },
                    'b' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '8';
                    },
                    'f' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'C';
                    },
                    'v' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'B';
                    },
                    '?' => {
                        i -= 1;
                        bytes[i] = '?';
                    },
                    'u', 'U' => {
                        try m.fail(ctx, "macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.ParseError;
                    },
                    else => {
                        try m.fail(ctx, "macro tokenizing failed: unknown escape sequence", .{});
                        return error.ParseError;
                    },
                }
                i += 1;
                if (state == .escape)
                    state = .start;
            },
            .start => {
                if (c == '\t') {
                    bytes[i] = '\\';
                    i += 1;
                    bytes[i] = 't';
                    i += 1;
                    continue;
                }
                if (c == '\\') {
                    state = .escape;
                }
                bytes[i] = c;
                i += 1;
            },
            .hex => {
                switch (c) {
                    '0'...'9' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'A' + 10;
                    },
                    else => {
                        i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                        num = 0;
                        if (c == '\\')
                            state = .escape
                        else
                            state = .start;
                        bytes[i] = c;
                        i += 1;
                    },
                }
            },
            .octal => {
                const accept_digit = switch (c) {
                    // The maximum length of a octal literal is 3 digits
                    '0'...'7' => count < 3,
                    else => false,
                };

                if (accept_digit) {
                    count += 1;
                    num = std.math.mul(u8, num, 8) catch {
                        try m.fail(ctx, "macro tokenizing failed: octal literal overflowed", .{});
                        return error.ParseError;
                    };
                    num += c - '0';
                } else {
                    i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                    num = 0;
                    count = 0;
                    if (c == '\\')
                        state = .escape
                    else
                        state = .start;
                    bytes[i] = c;
                    i += 1;
                }
            },
        }
    }
    if (state == .hex or state == .octal)
        i += std.fmt.formatIntBuf(bytes[i..], num, 16, .lower, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
    return bytes[0..i];
}

/// non-ASCII characters (c > 127) are also treated as non-printable by fmtSliceEscapeLower.
/// If a C string literal or char literal in a macro is not valid UTF-8, we need to escape
/// non-ASCII characters so that the Zig source we output will itself be UTF-8.
fn escapeUnprintables(ctx: *Context, m: *MacroCtx) ![]const u8 {
    const zigified = try zigifyEscapeSequences(ctx, m);
    if (std.unicode.utf8ValidateSlice(zigified)) return zigified;

    const formatter = std.fmt.fmtSliceEscapeLower(zigified);
    const encoded_size = @as(usize, @intCast(std.fmt.count("{s}", .{formatter})));
    const output = try ctx.arena.alloc(u8, encoded_size);
    return std.fmt.bufPrint(output, "{s}", .{formatter}) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
        else => |e| return e,
    };
}

fn parseCPrimaryExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    const tok = m.next().?;
    const slice = m.slice();
    switch (tok) {
        .char_literal,
        .char_literal_utf_8,
        .char_literal_utf_16,
        .char_literal_utf_32,
        .char_literal_wide,
        => {
            if (slice[0] != '\'' or slice[1] == '\\' or slice.len == 3) {
                return Tag.char_literal.create(c.arena, try escapeUnprintables(c, m));
            } else {
                const str = try std.fmt.allocPrint(c.arena, "0x{s}", .{std.fmt.fmtSliceHexLower(slice[1 .. slice.len - 1])});
                return Tag.integer_literal.create(c.arena, str);
            }
        },
        .string_literal,
        .string_literal_utf_16,
        .string_literal_utf_8,
        .string_literal_utf_32,
        .string_literal_wide,
        => {
            return Tag.string_literal.create(c.arena, try escapeUnprintables(c, m));
        },
        .pp_num => {
            return parseCNumLit(c, m);
        },
        .identifier, .extended_identifier => {
            if (c.global_scope.blank_macros.contains(slice)) {
                return parseCPrimaryExpr(c, m, scope);
            }
            const mangled_name = scope.getAlias(slice);
            if (builtin_typedef_map.get(mangled_name)) |ty| return Tag.type.create(c.arena, ty);
            const identifier = try Tag.identifier.create(c.arena, mangled_name);
            scope.skipVariableDiscard(identifier.castTag(.identifier).?.data);
            refs_var: {
                const ident_node = c.global_scope.sym_table.get(slice) orelse break :refs_var;
                const var_decl_node = ident_node.castTag(.var_decl) orelse break :refs_var;
                if (!var_decl_node.data.is_const) m.refs_var_decl = true;
            }
            return identifier;
        },
        .l_paren => {
            const inner_node = try parseCExpr(c, m, scope);

            try m.skip(c, .r_paren);
            return inner_node;
        },
        else => {
            // for handling type macros (EVIL)
            // TODO maybe detect and treat type macros as typedefs in parseCSpecifierQualifierList?
            m.i -= 1;
            if (try parseCTypeName(c, m, scope, true)) |type_name| {
                return type_name;
            }
            try m.fail(c, "unable to translate C expr: unexpected token '{s}'", .{tok.symbol()});
            return error.ParseError;
        },
    }
}

fn macroIntFromBool(c: *Context, node: Node) !Node {
    if (!isBoolRes(node)) {
        return node;
    }

    return Tag.int_from_bool.create(c.arena, node);
}

fn macroIntToBool(c: *Context, node: Node) !Node {
    if (isBoolRes(node)) {
        return node;
    }
    if (node.tag() == .string_literal) {
        // @intFromPtr(node) != 0
        const int_from_ptr = try Tag.int_from_ptr.create(c.arena, node);
        return Tag.not_equal.create(c.arena, .{ .lhs = int_from_ptr, .rhs = Tag.zero_literal.init() });
    }
    // node != 0
    return Tag.not_equal.create(c.arena, .{ .lhs = node, .rhs = Tag.zero_literal.init() });
}

fn parseCCondExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    const node = try parseCOrExpr(c, m, scope);
    if (m.peek().? != .question_mark) {
        return node;
    }
    _ = m.next();

    const then_body = try parseCOrExpr(c, m, scope);
    try m.skip(c, .colon);
    const else_body = try parseCCondExpr(c, m, scope);
    return Tag.@"if".create(c.arena, .{ .cond = node, .then = then_body, .@"else" = else_body });
}

fn parseCOrExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCAndExpr(c, m, scope);
    while (m.next().? == .pipe_pipe) {
        const lhs = try macroIntToBool(c, node);
        const rhs = try macroIntToBool(c, try parseCAndExpr(c, m, scope));
        node = try Tag.@"or".create(c.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    m.i -= 1;
    return node;
}

fn parseCAndExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCBitOrExpr(c, m, scope);
    while (m.next().? == .ampersand_ampersand) {
        const lhs = try macroIntToBool(c, node);
        const rhs = try macroIntToBool(c, try parseCBitOrExpr(c, m, scope));
        node = try Tag.@"and".create(c.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    m.i -= 1;
    return node;
}

fn parseCBitOrExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCBitXorExpr(c, m, scope);
    while (m.next().? == .pipe) {
        const lhs = try macroIntFromBool(c, node);
        const rhs = try macroIntFromBool(c, try parseCBitXorExpr(c, m, scope));
        node = try Tag.bit_or.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    m.i -= 1;
    return node;
}

fn parseCBitXorExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCBitAndExpr(c, m, scope);
    while (m.next().? == .caret) {
        const lhs = try macroIntFromBool(c, node);
        const rhs = try macroIntFromBool(c, try parseCBitAndExpr(c, m, scope));
        node = try Tag.bit_xor.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    m.i -= 1;
    return node;
}

fn parseCBitAndExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCEqExpr(c, m, scope);
    while (m.next().? == .ampersand) {
        const lhs = try macroIntFromBool(c, node);
        const rhs = try macroIntFromBool(c, try parseCEqExpr(c, m, scope));
        node = try Tag.bit_and.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    m.i -= 1;
    return node;
}

fn parseCEqExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCRelExpr(c, m, scope);
    while (true) {
        switch (m.peek().?) {
            .bang_equal => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCRelExpr(c, m, scope));
                node = try Tag.not_equal.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .equal_equal => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCRelExpr(c, m, scope));
                node = try Tag.equal.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCRelExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCShiftExpr(c, m, scope);
    while (true) {
        switch (m.peek().?) {
            .angle_bracket_right => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCShiftExpr(c, m, scope));
                node = try Tag.greater_than.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_right_equal => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCShiftExpr(c, m, scope));
                node = try Tag.greater_than_equal.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCShiftExpr(c, m, scope));
                node = try Tag.less_than.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left_equal => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCShiftExpr(c, m, scope));
                node = try Tag.less_than_equal.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCShiftExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCAddSubExpr(c, m, scope);
    while (true) {
        switch (m.peek().?) {
            .angle_bracket_angle_bracket_left => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCAddSubExpr(c, m, scope));
                node = try Tag.shl.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_angle_bracket_right => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCAddSubExpr(c, m, scope));
                node = try Tag.shr.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCAddSubExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCMulExpr(c, m, scope);
    while (true) {
        switch (m.peek().?) {
            .plus => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCMulExpr(c, m, scope));
                node = try Tag.add.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .minus => {
                _ = m.next();
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCMulExpr(c, m, scope));
                node = try Tag.sub.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCMulExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    var node = try parseCCastExpr(c, m, scope);
    while (true) {
        switch (m.next().?) {
            .asterisk => {
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCCastExpr(c, m, scope));
                node = try Tag.mul.create(c.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .slash => {
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCCastExpr(c, m, scope));
                node = try Tag.macro_arithmetic.create(c.arena, .{ .op = .div, .lhs = lhs, .rhs = rhs });
            },
            .percent => {
                const lhs = try macroIntFromBool(c, node);
                const rhs = try macroIntFromBool(c, try parseCCastExpr(c, m, scope));
                node = try Tag.macro_arithmetic.create(c.arena, .{ .op = .rem, .lhs = lhs, .rhs = rhs });
            },
            else => {
                m.i -= 1;
                return node;
            },
        }
    }
}

fn parseCCastExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    switch (m.next().?) {
        .l_paren => {
            if (try parseCTypeName(c, m, scope, true)) |type_name| {
                while (true) {
                    const next_token = m.next().?;
                    switch (next_token) {
                        .r_paren => break,
                        else => |next_tag| {
                            // Skip trailing blank defined before the RParen.
                            if ((next_tag == .identifier or next_tag == .extended_identifier) and
                                c.global_scope.blank_macros.contains(m.slice()))
                                continue;

                            try m.fail(
                                c,
                                "unable to translate C expr: expected ')' instead got '{s}'",
                                .{next_token.symbol()},
                            );
                            return error.ParseError;
                        },
                    }
                }
                if (m.peek().? == .l_brace) {
                    // initializer list
                    return parseCPostfixExpr(c, m, scope, type_name);
                }
                const node_to_cast = try parseCCastExpr(c, m, scope);
                return Tag.helpers_cast.create(c.arena, .{ .lhs = type_name, .rhs = node_to_cast });
            }
        },
        else => {},
    }
    m.i -= 1;
    return parseCUnaryExpr(c, m, scope);
}

// allow_fail is set when unsure if we are parsing a type-name
fn parseCTypeName(c: *Context, m: *MacroCtx, scope: *Scope, allow_fail: bool) ParseError!?Node {
    if (try parseCSpecifierQualifierList(c, m, scope, allow_fail)) |node| {
        return try parseCAbstractDeclarator(c, m, node);
    } else {
        return null;
    }
}

fn parseCSpecifierQualifierList(c: *Context, m: *MacroCtx, scope: *Scope, allow_fail: bool) ParseError!?Node {
    const tok = m.next().?;
    switch (tok) {
        .identifier, .extended_identifier => {
            if (c.global_scope.blank_macros.contains(m.slice())) {
                return try parseCSpecifierQualifierList(c, m, scope, allow_fail);
            }
            const mangled_name = scope.getAlias(m.slice());
            if (!allow_fail or c.typedefs.contains(mangled_name)) {
                if (builtin_typedef_map.get(mangled_name)) |ty| return try Tag.type.create(c.arena, ty);
                return try Tag.identifier.create(c.arena, mangled_name);
            }
        },
        .keyword_void => return try Tag.type.create(c.arena, "anyopaque"),
        .keyword_bool => return try Tag.type.create(c.arena, "bool"),
        .keyword_char,
        .keyword_int,
        .keyword_short,
        .keyword_long,
        .keyword_float,
        .keyword_double,
        .keyword_signed,
        .keyword_unsigned,
        .keyword_complex,
        => {
            m.i -= 1;
            return try parseCNumericType(c, m);
        },
        .keyword_enum, .keyword_struct, .keyword_union => {
            // struct Foo will be declared as struct_Foo by transRecordDecl
            const slice = m.slice();
            try m.skip(c, .identifier);

            const name = try std.fmt.allocPrint(c.arena, "{s}_{s}", .{ slice, m.slice() });
            return try Tag.identifier.create(c.arena, name);
        },
        else => {},
    }

    if (allow_fail) {
        m.i -= 1;
        return null;
    } else {
        try m.fail(c, "unable to translate C expr: unexpected token '{s}'", .{tok.symbol()});
        return error.ParseError;
    }
}

fn parseCNumericType(c: *Context, m: *MacroCtx) ParseError!Node {
    const KwCounter = struct {
        double: u8 = 0,
        long: u8 = 0,
        int: u8 = 0,
        float: u8 = 0,
        short: u8 = 0,
        char: u8 = 0,
        unsigned: u8 = 0,
        signed: u8 = 0,
        complex: u8 = 0,

        fn eql(self: @This(), other: @This()) bool {
            return meta.eql(self, other);
        }
    };

    // Yes, these can be in *any* order
    // This still doesn't cover cases where for example volatile is intermixed

    var kw = KwCounter{};
    // prevent overflow
    var i: u8 = 0;
    while (i < math.maxInt(u8)) : (i += 1) {
        switch (m.next().?) {
            .keyword_double => kw.double += 1,
            .keyword_long => kw.long += 1,
            .keyword_int => kw.int += 1,
            .keyword_float => kw.float += 1,
            .keyword_short => kw.short += 1,
            .keyword_char => kw.char += 1,
            .keyword_unsigned => kw.unsigned += 1,
            .keyword_signed => kw.signed += 1,
            .keyword_complex => kw.complex += 1,
            else => {
                m.i -= 1;
                break;
            },
        }
    }

    if (kw.eql(.{ .int = 1 }) or kw.eql(.{ .signed = 1 }) or kw.eql(.{ .signed = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_int");

    if (kw.eql(.{ .unsigned = 1 }) or kw.eql(.{ .unsigned = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_uint");

    if (kw.eql(.{ .long = 1 }) or kw.eql(.{ .signed = 1, .long = 1 }) or kw.eql(.{ .long = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_long");

    if (kw.eql(.{ .unsigned = 1, .long = 1 }) or kw.eql(.{ .unsigned = 1, .long = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_ulong");

    if (kw.eql(.{ .long = 2 }) or kw.eql(.{ .signed = 1, .long = 2 }) or kw.eql(.{ .long = 2, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 2, .int = 1 }))
        return Tag.type.create(c.arena, "c_longlong");

    if (kw.eql(.{ .unsigned = 1, .long = 2 }) or kw.eql(.{ .unsigned = 1, .long = 2, .int = 1 }))
        return Tag.type.create(c.arena, "c_ulonglong");

    if (kw.eql(.{ .signed = 1, .char = 1 }))
        return Tag.type.create(c.arena, "i8");

    if (kw.eql(.{ .char = 1 }) or kw.eql(.{ .unsigned = 1, .char = 1 }))
        return Tag.type.create(c.arena, "u8");

    if (kw.eql(.{ .short = 1 }) or kw.eql(.{ .signed = 1, .short = 1 }) or kw.eql(.{ .short = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .short = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_short");

    if (kw.eql(.{ .unsigned = 1, .short = 1 }) or kw.eql(.{ .unsigned = 1, .short = 1, .int = 1 }))
        return Tag.type.create(c.arena, "c_ushort");

    if (kw.eql(.{ .float = 1 }))
        return Tag.type.create(c.arena, "f32");

    if (kw.eql(.{ .double = 1 }))
        return Tag.type.create(c.arena, "f64");

    if (kw.eql(.{ .long = 1, .double = 1 })) {
        try m.fail(c, "unable to translate: TODO long double", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .float = 1, .complex = 1 })) {
        try m.fail(c, "unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .double = 1, .complex = 1 })) {
        try m.fail(c, "unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .long = 1, .double = 1, .complex = 1 })) {
        try m.fail(c, "unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    try m.fail(c, "unable to translate: invalid numeric type", .{});
    return error.ParseError;
}

fn parseCAbstractDeclarator(c: *Context, m: *MacroCtx, node: Node) ParseError!Node {
    switch (m.next().?) {
        .asterisk => {
            // last token of `node`
            const prev_id = m.list[m.i - 1].id;

            if (prev_id == .keyword_void) {
                const ptr = try Tag.single_pointer.create(c.arena, .{
                    .is_const = false,
                    .is_volatile = false,
                    .elem_type = node,
                });
                return Tag.optional_type.create(c.arena, ptr);
            } else {
                return Tag.c_pointer.create(c.arena, .{
                    .is_const = false,
                    .is_volatile = false,
                    .elem_type = node,
                });
            }
        },
        else => {
            m.i -= 1;
            return node;
        },
    }
}

fn parseCPostfixExpr(c: *Context, m: *MacroCtx, scope: *Scope, type_name: ?Node) ParseError!Node {
    var node = try parseCPostfixExprInner(c, m, scope, type_name);
    // In C the preprocessor would handle concatting strings while expanding macros.
    // This should do approximately the same by concatting any strings and identifiers
    // after a primary or postfix expression.
    while (true) {
        switch (m.peek().?) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => {},
            .identifier, .extended_identifier => {
                const tok = m.list[m.i + 1];
                const slice = m.source[tok.start..tok.end];
                if (c.global_scope.blank_macros.contains(slice)) {
                    m.i += 1;
                    continue;
                }
            },
            else => break,
        }
        const rhs = try parseCPostfixExprInner(c, m, scope, type_name);
        node = try Tag.array_cat.create(c.arena, .{ .lhs = node, .rhs = rhs });
    }
    return node;
}

fn parseCPostfixExprInner(c: *Context, m: *MacroCtx, scope: *Scope, type_name: ?Node) ParseError!Node {
    var node = type_name orelse try parseCPrimaryExpr(c, m, scope);
    while (true) {
        switch (m.next().?) {
            .period => {
                try m.skip(c, .identifier);

                node = try Tag.field_access.create(c.arena, .{ .lhs = node, .field_name = m.slice() });
            },
            .arrow => {
                try m.skip(c, .identifier);

                const deref = try Tag.deref.create(c.arena, node);
                node = try Tag.field_access.create(c.arena, .{ .lhs = deref, .field_name = m.slice() });
            },
            .l_bracket => {
                const index_val = try macroIntFromBool(c, try parseCExpr(c, m, scope));
                const index = try Tag.as.create(c.arena, .{
                    .lhs = try Tag.type.create(c.arena, "usize"),
                    .rhs = try Tag.int_cast.create(c.arena, index_val),
                });
                node = try Tag.array_access.create(c.arena, .{ .lhs = node, .rhs = index });
                try m.skip(c, .r_bracket);
            },
            .l_paren => {
                if (m.peek().? == .r_paren) {
                    m.i += 1;
                    node = try Tag.call.create(c.arena, .{ .lhs = node, .args = &[0]Node{} });
                } else {
                    var args = std.ArrayList(Node).init(c.gpa);
                    defer args.deinit();
                    while (true) {
                        const arg = try parseCCondExpr(c, m, scope);
                        try args.append(arg);
                        const next_id = m.next().?;
                        switch (next_id) {
                            .comma => {},
                            .r_paren => break,
                            else => {
                                try m.fail(c, "unable to translate C expr: expected ',' or ')' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    node = try Tag.call.create(c.arena, .{ .lhs = node, .args = try c.arena.dupe(Node, args.items) });
                }
            },
            .l_brace => {
                // Check for designated field initializers
                if (m.peek().? == .period) {
                    var init_vals = std.ArrayList(ast.Payload.ContainerInitDot.Initializer).init(c.gpa);
                    defer init_vals.deinit();

                    while (true) {
                        try m.skip(c, .period);
                        try m.skip(c, .identifier);
                        const name = m.slice();
                        try m.skip(c, .equal);

                        const val = try parseCCondExpr(c, m, scope);
                        try init_vals.append(.{ .name = name, .value = val });
                        const next_id = m.next().?;
                        switch (next_id) {
                            .comma => {},
                            .r_brace => break,
                            else => {
                                try m.fail(c, "unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    const tuple_node = try Tag.container_init_dot.create(c.arena, try c.arena.dupe(ast.Payload.ContainerInitDot.Initializer, init_vals.items));
                    node = try Tag.std_mem_zeroinit.create(c.arena, .{ .lhs = node, .rhs = tuple_node });
                    continue;
                }

                var init_vals = std.ArrayList(Node).init(c.gpa);
                defer init_vals.deinit();

                while (true) {
                    const val = try parseCCondExpr(c, m, scope);
                    try init_vals.append(val);
                    const next_id = m.next().?;
                    switch (next_id) {
                        .comma => {},
                        .r_brace => break,
                        else => {
                            try m.fail(c, "unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                            return error.ParseError;
                        },
                    }
                }
                const tuple_node = try Tag.tuple.create(c.arena, try c.arena.dupe(Node, init_vals.items));
                node = try Tag.std_mem_zeroinit.create(c.arena, .{ .lhs = node, .rhs = tuple_node });
            },
            .plus_plus, .minus_minus => {
                try m.fail(c, "TODO postfix inc/dec expr", .{});
                return error.ParseError;
            },
            else => {
                m.i -= 1;
                return node;
            },
        }
    }
}

fn parseCUnaryExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!Node {
    switch (m.next().?) {
        .bang => {
            const operand = try macroIntToBool(c, try parseCCastExpr(c, m, scope));
            return Tag.not.create(c.arena, operand);
        },
        .minus => {
            const operand = try macroIntFromBool(c, try parseCCastExpr(c, m, scope));
            return Tag.negate.create(c.arena, operand);
        },
        .plus => return try parseCCastExpr(c, m, scope),
        .tilde => {
            const operand = try macroIntFromBool(c, try parseCCastExpr(c, m, scope));
            return Tag.bit_not.create(c.arena, operand);
        },
        .asterisk => {
            const operand = try parseCCastExpr(c, m, scope);
            return Tag.deref.create(c.arena, operand);
        },
        .ampersand => {
            const operand = try parseCCastExpr(c, m, scope);
            return Tag.address_of.create(c.arena, operand);
        },
        .keyword_sizeof => {
            const operand = if (m.peek().? == .l_paren) blk: {
                _ = m.next();
                const inner = (try parseCTypeName(c, m, scope, false)).?;
                try m.skip(c, .r_paren);
                break :blk inner;
            } else try parseCUnaryExpr(c, m, scope);

            return Tag.helpers_sizeof.create(c.arena, operand);
        },
        .keyword_alignof => {
            // TODO this won't work if using <stdalign.h>'s
            // #define alignof _Alignof
            try m.skip(c, .l_paren);
            const operand = (try parseCTypeName(c, m, scope, false)).?;
            try m.skip(c, .r_paren);

            return Tag.alignof.create(c.arena, operand);
        },
        .plus_plus, .minus_minus => {
            try m.fail(c, "TODO unary inc/dec expr", .{});
            return error.ParseError;
        },
        else => {
            m.i -= 1;
            return try parseCPostfixExpr(c, m, scope, null);
        },
    }
}

fn getContainer(c: *Context, node: Node) ?Node {
    switch (node.tag()) {
        .@"union",
        .@"struct",
        .address_of,
        .bit_not,
        .not,
        .optional_type,
        .negate,
        .negate_wrap,
        .array_type,
        .c_pointer,
        .single_pointer,
        => return node,

        .identifier => {
            const ident = node.castTag(.identifier).?;
            if (c.global_scope.sym_table.get(ident.data)) |value| {
                if (value.castTag(.var_decl)) |var_decl|
                    return getContainer(c, var_decl.data.init.?);
                if (value.castTag(.var_simple) orelse value.castTag(.pub_var_simple)) |var_decl|
                    return getContainer(c, var_decl.data.init);
            }
        },

        .field_access => {
            const field_access = node.castTag(.field_access).?;

            if (getContainerTypeOf(c, field_access.data.lhs)) |ty_node| {
                if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                    for (container.data.fields) |field| {
                        if (mem.eql(u8, field.name, field_access.data.field_name)) {
                            return getContainer(c, field.type);
                        }
                    }
                }
            }
        },

        else => {},
    }
    return null;
}

fn getContainerTypeOf(c: *Context, ref: Node) ?Node {
    if (ref.castTag(.identifier)) |ident| {
        if (c.global_scope.sym_table.get(ident.data)) |value| {
            if (value.castTag(.var_decl)) |var_decl| {
                return getContainer(c, var_decl.data.type);
            }
        }
    } else if (ref.castTag(.field_access)) |field_access| {
        if (getContainerTypeOf(c, field_access.data.lhs)) |ty_node| {
            if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                for (container.data.fields) |field| {
                    if (mem.eql(u8, field.name, field_access.data.field_name)) {
                        return getContainer(c, field.type);
                    }
                }
            } else return ty_node;
        }
    }
    return null;
}

fn getFnProto(c: *Context, ref: Node) ?*ast.Payload.Func {
    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init orelse return null
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        return null;
    if (getContainerTypeOf(c, init)) |ty_node| {
        if (ty_node.castTag(.optional_type)) |prefix| {
            if (prefix.data.castTag(.single_pointer)) |sp| {
                if (sp.data.elem_type.castTag(.func)) |fn_proto| {
                    return fn_proto;
                }
            }
        }
    }
    return null;
}
