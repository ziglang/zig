const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const CallingConvention = std.builtin.CallingConvention;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;
const Tree = aro.Tree;
const Node = Tree.Node;
const TokenIndex = Tree.TokenIndex;
const QualType = aro.QualType;

const ast = @import("ast.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const builtins = @import("builtins.zig");
const helpers = @import("helpers.zig");
const MacroTranslator = @import("MacroTranslator.zig");
const PatternList = @import("PatternList.zig");
const Scope = @import("Scope.zig");

pub const Error = std.mem.Allocator.Error;
pub const MacroProcessingError = Error || error{UnexpectedMacroToken};
pub const TypeError = Error || error{UnsupportedType};
pub const TransError = TypeError || error{UnsupportedTranslation};

const Translator = @This();

/// The C AST to be translated.
tree: *const Tree,
/// The compilation corresponding to the AST.
comp: *aro.Compilation,
/// The Preprocessor that produced the source for `tree`.
pp: *const aro.Preprocessor,

gpa: mem.Allocator,
arena: mem.Allocator,

alias_list: Scope.AliasList,
global_scope: *Scope.Root,
/// Running number used for creating new unique identifiers.
mangle_count: u32 = 0,

/// Table of declarations for enum, struct, union and typedef types.
type_decls: std.AutoArrayHashMapUnmanaged(Node.Index, []const u8) = .empty,
/// Table of record decls that have been demoted to opaques.
opaque_demotes: std.AutoHashMapUnmanaged(QualType, void) = .empty,
/// Table of unnamed enums and records that are child types of typedefs.
unnamed_typedefs: std.AutoHashMapUnmanaged(QualType, []const u8) = .empty,
/// Table of anonymous record to generated field names.
anonymous_record_field_names: std.AutoHashMapUnmanaged(struct {
    parent: QualType,
    field: QualType,
}, []const u8) = .empty,

/// This one is different than the root scope's name table. This contains
/// a list of names that we found by visiting all the top level decls without
/// translating them. The other maps are updated as we translate; this one is updated
/// up front in a pre-processing step.
global_names: std.StringArrayHashMapUnmanaged(void) = .empty,

/// This is similar to `global_names`, but contains names which we would
/// *like* to use, but do not strictly *have* to if they are unavailable.
/// These are relevant to types, which ideally we would name like
/// 'struct_foo' with an alias 'foo', but if either of those names is taken,
/// may be mangled.
/// This is distinct from `global_names` so we can detect at a type
/// declaration whether or not the name is available.
weak_global_names: std.StringArrayHashMapUnmanaged(void) = .empty,

/// Set of identifiers known to refer to typedef declarations.
/// Used when parsing macros.
typedefs: std.StringArrayHashMapUnmanaged(void) = .empty,

/// The lhs lval of a compound assignment expression.
compound_assign_dummy: ?ZigNode = null,

pub fn getMangle(t: *Translator) u32 {
    t.mangle_count += 1;
    return t.mangle_count;
}

/// Convert an `aro.Source.Location` to a 'file:line:column' string.
pub fn locStr(t: *Translator, loc: aro.Source.Location) ![]const u8 {
    const source = t.comp.getSource(loc.id);
    const line_col = source.lineCol(loc);
    const filename = source.path;

    const line = source.physicalLine(loc);
    const col = line_col.col;

    return std.fmt.allocPrint(t.arena, "{s}:{d}:{d}", .{ filename, line, col });
}

fn maybeSuppressResult(t: *Translator, used: ResultUsed, result: ZigNode) TransError!ZigNode {
    if (used == .used) return result;
    return ZigTag.discard.create(t.arena, .{ .should_skip = false, .value = result });
}

pub fn addTopLevelDecl(t: *Translator, name: []const u8, decl_node: ZigNode) !void {
    const gop = try t.global_scope.sym_table.getOrPut(t.gpa, name);
    if (!gop.found_existing) {
        gop.value_ptr.* = decl_node;
        try t.global_scope.nodes.append(t.gpa, decl_node);
    }
}

fn fail(
    t: *Translator,
    err: anytype,
    source_loc: TokenIndex,
    comptime format: []const u8,
    args: anytype,
) (@TypeOf(err) || error{OutOfMemory}) {
    try t.warn(&t.global_scope.base, source_loc, format, args);
    return err;
}

pub fn failDecl(
    t: *Translator,
    scope: *Scope,
    tok_idx: TokenIndex,
    name: []const u8,
    comptime format: []const u8,
    args: anytype,
) Error!void {
    const loc = t.tree.tokens.items(.loc)[tok_idx];
    return t.failDeclExtra(scope, loc, name, format, args);
}

pub fn failDeclExtra(
    t: *Translator,
    scope: *Scope,
    loc: aro.Source.Location,
    name: []const u8,
    comptime format: []const u8,
    args: anytype,
) Error!void {
    // location
    // pub const name = @compileError(msg);
    const fail_msg = try std.fmt.allocPrint(t.arena, format, args);
    const fail_decl = try ZigTag.fail_decl.create(t.arena, .{ .actual = name, .mangled = fail_msg });

    const str = try t.locStr(loc);
    const location_comment = try std.fmt.allocPrint(t.arena, "// {s}", .{str});
    const loc_node = try ZigTag.warning.create(t.arena, location_comment);

    if (scope.id == .root) {
        try t.addTopLevelDecl(name, fail_decl);
        try scope.appendNode(loc_node);
    } else {
        try scope.appendNode(fail_decl);
        try scope.appendNode(loc_node);

        const bs = try scope.findBlockScope(t);
        try bs.discardVariable(name);
    }
}

fn warn(t: *Translator, scope: *Scope, tok_idx: TokenIndex, comptime format: []const u8, args: anytype) !void {
    const loc = t.tree.tokens.items(.loc)[tok_idx];
    const str = try t.locStr(loc);
    const value = try std.fmt.allocPrint(t.arena, "// {s}: warning: " ++ format, .{str} ++ args);
    try scope.appendNode(try ZigTag.warning.create(t.arena, value));
}

pub const Options = struct {
    gpa: mem.Allocator,
    comp: *aro.Compilation,
    pp: *const aro.Preprocessor,
    tree: *const aro.Tree,
};

pub fn translate(options: Options) mem.Allocator.Error![]u8 {
    const gpa = options.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var translator: Translator = .{
        .gpa = gpa,
        .arena = arena,
        .alias_list = .empty,
        .global_scope = try arena.create(Scope.Root),
        .comp = options.comp,
        .pp = options.pp,
        .tree = options.tree,
    };
    translator.global_scope.* = Scope.Root.init(&translator);
    defer {
        translator.type_decls.deinit(gpa);
        translator.alias_list.deinit(gpa);
        translator.global_names.deinit(gpa);
        translator.weak_global_names.deinit(gpa);
        translator.opaque_demotes.deinit(gpa);
        translator.unnamed_typedefs.deinit(gpa);
        translator.anonymous_record_field_names.deinit(gpa);
        translator.typedefs.deinit(gpa);
        translator.global_scope.deinit();
    }

    try translator.prepopulateGlobalNameTable();
    try translator.transTopLevelDecls();

    // Insert empty line before macros.
    try translator.global_scope.nodes.append(gpa, try ZigTag.warning.create(arena, "\n"));

    try translator.transMacros();

    for (translator.alias_list.items) |alias| {
        if (!translator.global_scope.sym_table.contains(alias.alias)) {
            const node = try ZigTag.alias.create(arena, .{ .actual = alias.alias, .mangled = alias.name });
            try translator.addTopLevelDecl(alias.alias, node);
        }
    }

    try translator.global_scope.processContainerMemberFns();

    var allocating: std.Io.Writer.Allocating = .init(gpa);
    defer allocating.deinit();

    allocating.writer.writeAll(
        \\pub const __builtin = @import("std").zig.c_translation.builtins;
        \\pub const __helpers = @import("std").zig.c_translation.helpers;
        \\
        \\
    ) catch return error.OutOfMemory;

    var zig_ast = try ast.render(gpa, translator.global_scope.nodes.items);
    defer {
        gpa.free(zig_ast.source);
        zig_ast.deinit(gpa);
    }
    zig_ast.render(gpa, &allocating.writer, .{}) catch return error.OutOfMemory;
    return allocating.toOwnedSlice();
}

fn prepopulateGlobalNameTable(t: *Translator) !void {
    for (t.tree.root_decls.items) |decl| {
        switch (decl.get(t.tree)) {
            .typedef => |typedef_decl| {
                const decl_name = t.tree.tokSlice(typedef_decl.name_tok);
                try t.global_names.put(t.gpa, decl_name, {});

                // Check for typedefs with unnamed enum/record child types.
                const base = typedef_decl.qt.base(t.comp);
                switch (base.type) {
                    .@"enum" => |enum_ty| {
                        if (enum_ty.name.lookup(t.comp)[0] != '(') continue;
                    },
                    .@"struct", .@"union" => |record_ty| {
                        if (record_ty.name.lookup(t.comp)[0] != '(') continue;
                    },
                    else => continue,
                }

                const gop = try t.unnamed_typedefs.getOrPut(t.gpa, base.qt);
                if (gop.found_existing) {
                    // One typedef can declare multiple names.
                    // TODO Don't put this one in `decl_table` so it's processed later.
                    continue;
                }
                gop.value_ptr.* = decl_name;
            },

            .struct_decl,
            .union_decl,
            .struct_forward_decl,
            .union_forward_decl,
            .enum_decl,
            .enum_forward_decl,
            => {
                const decl_qt = decl.qt(t.tree);
                const prefix, const name = switch (decl_qt.base(t.comp).type) {
                    .@"struct" => |struct_ty| .{ "struct", struct_ty.name.lookup(t.comp) },
                    .@"union" => |union_ty| .{ "union", union_ty.name.lookup(t.comp) },
                    .@"enum" => |enum_ty| .{ "enum", enum_ty.name.lookup(t.comp) },
                    else => unreachable,
                };
                const prefixed_name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ prefix, name });
                // `name` and `prefixed_name` are the preferred names for this type.
                // However, we can name it anything else if necessary, so these are "weak names".
                try t.weak_global_names.ensureUnusedCapacity(t.gpa, 2);
                t.weak_global_names.putAssumeCapacity(name, {});
                t.weak_global_names.putAssumeCapacity(prefixed_name, {});
            },

            .function, .variable => {
                const decl_name = t.tree.tokSlice(decl.tok(t.tree));
                try t.global_names.put(t.gpa, decl_name, {});
            },
            .static_assert => {},
            .empty_decl => {},
            .global_asm => {},
            else => unreachable,
        }
    }

    for (t.pp.defines.keys(), t.pp.defines.values()) |name, macro| {
        if (macro.is_builtin) continue;
        if (!t.isSelfDefinedMacro(name, macro)) {
            try t.global_names.put(t.gpa, name, {});
        }
    }
}

/// Determines whether macro is of the form: `#define FOO FOO` (Possibly with trailing tokens)
/// Macros of this form will not be translated.
fn isSelfDefinedMacro(t: *Translator, name: []const u8, macro: aro.Preprocessor.Macro) bool {
    if (macro.is_func) return false;

    if (macro.tokens.len < 1) return false;
    const first_tok = macro.tokens[0];

    const source = t.comp.getSource(macro.loc.id);
    const slice = source.buf[first_tok.start..first_tok.end];

    return std.mem.eql(u8, name, slice);
}

// =======================
// Declaration translation
// =======================

fn transTopLevelDecls(t: *Translator) !void {
    for (t.tree.root_decls.items) |decl| {
        try t.transDecl(&t.global_scope.base, decl);
    }
}

fn transDecl(t: *Translator, scope: *Scope, decl: Node.Index) !void {
    switch (decl.get(t.tree)) {
        .typedef => |typedef_decl| {
            // Implicit typedefs are translated only if referenced.
            if (typedef_decl.implicit) return;
            try t.transTypeDef(scope, decl);
        },

        .struct_decl, .union_decl => |record_decl| {
            try t.transRecordDecl(scope, record_decl.container_qt);
        },

        .enum_decl => |enum_decl| {
            try t.transEnumDecl(scope, enum_decl.container_qt);
        },

        .enum_field,
        .record_field,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        => return,

        .function => |function| {
            if (function.definition) |definition| {
                return t.transFnDecl(scope, definition.get(t.tree).function);
            }
            try t.transFnDecl(scope, function);
        },

        .variable => |variable| {
            if (variable.definition != null) return;
            try t.transVarDecl(scope, variable);
        },
        .static_assert => |static_assert| {
            try t.transStaticAssert(&t.global_scope.base, static_assert);
        },
        .global_asm => |global_asm| {
            try t.transGlobalAsm(&t.global_scope.base, global_asm);
        },
        .empty_decl => {},
        else => unreachable,
    }
}

pub const builtin_typedef_map = std.StaticStringMap([]const u8).initComptime(.{
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

fn transTypeDef(t: *Translator, scope: *Scope, typedef_node: Node.Index) Error!void {
    const typedef_decl = typedef_node.get(t.tree).typedef;
    if (t.type_decls.get(typedef_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var name: []const u8 = t.tree.tokSlice(typedef_decl.name_tok);
    try t.typedefs.put(t.gpa, name, {});

    if (builtin_typedef_map.get(name)) |builtin| {
        return t.type_decls.putNoClobber(t.gpa, typedef_node, builtin);
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, typedef_node, name);

    const typedef_loc = typedef_decl.name_tok;
    const init_node = t.transType(scope, typedef_decl.qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(scope, typedef_loc, name, "unable to resolve typedef child type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (toplevel) .pub_var_simple else .var_simple },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = ZigNode.initPayload(&payload.base);

    if (toplevel) {
        try t.addTopLevelDecl(name, node);
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn mangleWeakGlobalName(t: *Translator, want_name: []const u8) Error![]const u8 {
    var cur_name = want_name;

    if (!t.weak_global_names.contains(want_name)) {
        // This type wasn't noticed by the name detection pass, so nothing has been treating this as
        // a weak global name. We must mangle it to avoid conflicts with locals.
        cur_name = try std.fmt.allocPrint(t.arena, "{s}_{d}", .{ want_name, t.getMangle() });
    }

    while (t.global_names.contains(cur_name)) {
        cur_name = try std.fmt.allocPrint(t.arena, "{s}_{d}", .{ want_name, t.getMangle() });
    }
    return cur_name;
}

fn transRecordDecl(t: *Translator, scope: *Scope, record_qt: QualType) Error!void {
    const base = record_qt.base(t.comp);
    const record_ty = switch (base.type) {
        .@"struct", .@"union" => |record_ty| record_ty,
        else => unreachable,
    };

    if (t.type_decls.get(record_ty.decl_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    const container_kind: ZigTag = if (base.type == .@"union") .@"union" else .@"struct";
    const container_kind_name = @tagName(container_kind);

    var bare_name = record_ty.name.lookup(t.comp);
    var is_unnamed = false;
    var name = bare_name;

    if (t.unnamed_typedefs.get(base.qt)) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (record_ty.isAnonymous(t.comp)) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(t.arena, "{s}_{s}", .{ container_kind_name, bare_name });
        if (toplevel and !is_unnamed) {
            name = try t.mangleWeakGlobalName(name);
        }
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, record_ty.decl_node, name);

    const is_pub = toplevel and !is_unnamed;
    const init_node = init: {
        if (record_ty.layout == null) {
            try t.opaque_demotes.put(t.gpa, base.qt, {});
            break :init ZigTag.opaque_literal.init();
        }

        var fields: std.ArrayList(ast.Payload.Container.Field) = .empty;
        defer fields.deinit(t.gpa);
        try fields.ensureUnusedCapacity(t.gpa, record_ty.fields.len);

        var functions: std.ArrayList(ZigNode) = .empty;
        defer functions.deinit(t.gpa);

        var unnamed_field_count: u32 = 0;

        // If a record doesn't have any attributes that would affect the alignment and
        // layout, then we can just use a simple `extern` type. If it does have attributes,
        // then we need to inspect the layout and assign an `align` value for each field.
        const has_alignment_attributes = aligned: {
            if (record_qt.hasAttribute(t.comp, .@"packed")) break :aligned true;
            if (record_qt.hasAttribute(t.comp, .aligned)) break :aligned true;
            for (record_ty.fields) |field| {
                const field_attrs = field.attributes(t.comp);
                for (field_attrs) |field_attr| {
                    switch (field_attr.tag) {
                        .@"packed", .aligned => break :aligned true,
                        else => {},
                    }
                }
            }
            break :aligned false;
        };
        const head_field_alignment: ?c_uint = if (has_alignment_attributes) t.headFieldAlignment(record_ty) else null;

        for (record_ty.fields, 0..) |field, field_index| {
            const field_loc = field.name_tok;

            // Demote record to opaque if it contains a bitfield
            if (field.bit_width != .null) {
                try t.opaque_demotes.put(t.gpa, base.qt, {});
                try t.warn(scope, field_loc, "{s} demoted to opaque type - has bitfield", .{container_kind_name});
                break :init ZigTag.opaque_literal.init();
            }

            var field_name = field.name.lookup(t.comp);
            if (field.name_tok == 0) {
                field_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{unnamed_field_count});
                unnamed_field_count += 1;
                try t.anonymous_record_field_names.put(t.gpa, .{
                    .parent = base.qt,
                    .field = field.qt,
                }, field_name);
            }

            const field_alignment = if (has_alignment_attributes)
                t.alignmentForField(record_ty, head_field_alignment, field_index)
            else
                null;

            const field_type = field_type: {
                // Check if this is a flexible array member.
                flexible: {
                    if (field_index != record_ty.fields.len - 1 and container_kind != .@"union") break :flexible;
                    const array_ty = field.qt.get(t.comp, .array) orelse break :flexible;
                    if (array_ty.len != .incomplete and (array_ty.len != .fixed or array_ty.len.fixed != 0)) break :flexible;

                    const elem_type = t.transType(scope, array_ty.elem, field_loc) catch |err| switch (err) {
                        error.UnsupportedType => break :flexible,
                        else => |e| return e,
                    };
                    const zero_array = try ZigTag.array_type.create(t.arena, .{ .len = 0, .elem_type = elem_type });

                    const member_name = field_name;
                    field_name = try std.fmt.allocPrint(t.arena, "_{s}", .{field_name});

                    const member = try t.createFlexibleMemberFn(member_name, field_name);
                    try functions.append(t.gpa, member);

                    break :field_type zero_array;
                }

                break :field_type t.transType(scope, field.qt, field_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try t.opaque_demotes.put(t.gpa, base.qt, {});
                        try t.warn(scope, field.name_tok, "{s} demoted to opaque type - unable to translate type of field {s}", .{
                            container_kind_name,
                            field_name,
                        });
                        break :init ZigTag.opaque_literal.init();
                    },
                    else => |e| return e,
                };
            };

            // C99 introduced designated initializers for structs. Omitted fields are implicitly
            // initialized to zero. Some C APIs are designed with this in mind. Defaulting to zero
            // values for translated struct fields permits Zig code to comfortably use such an API.
            const default_value = if (container_kind == .@"struct")
                try t.createZeroValueNode(field.qt, field_type, .no_as)
            else
                null;

            fields.appendAssumeCapacity(.{
                .name = field_name,
                .type = field_type,
                .alignment = field_alignment,
                .default_value = default_value,
            });
        }

        // A record is empty if it has no fields or only flexible array fields.
        if (record_ty.fields.len == functions.items.len and
            t.comp.target.os.tag == .windows and t.comp.target.abi == .msvc)
        {
            // In MSVC empty records have the same size as their alignment.
            const padding_bits = record_ty.layout.?.size_bits;
            const alignment_bits = record_ty.layout.?.field_alignment_bits;

            try fields.append(t.gpa, .{
                .name = "_padding",
                .type = try ZigTag.type.create(t.arena, try std.fmt.allocPrint(t.arena, "u{d}", .{padding_bits})),
                .alignment = @divExact(alignment_bits, 8),
                .default_value = if (container_kind == .@"struct")
                    ZigTag.zero_literal.init()
                else
                    null,
            });
        }

        const container_payload = try t.arena.create(ast.Payload.Container);
        container_payload.* = .{
            .base = .{ .tag = container_kind },
            .data = .{
                .layout = .@"extern",
                .fields = try t.arena.dupe(ast.Payload.Container.Field, fields.items),
                .decls = try t.arena.dupe(ZigNode, functions.items),
            },
        };
        break :init ZigNode.initPayload(&container_payload.base);
    };

    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (is_pub) .pub_var_simple else .var_simple },
        .data = .{
            .name = name,
            .init = init_node,
        },
    };
    const node = ZigNode.initPayload(&payload.base);
    if (toplevel) {
        try t.addTopLevelDecl(name, node);
        // Only add the alias if the name is available *and* it was caught by
        // name detection. Don't bother performing a weak mangle, since a
        // mangled name is of no real use here.
        if (!is_unnamed and !t.global_names.contains(bare_name) and t.weak_global_names.contains(bare_name))
            try t.alias_list.append(t.gpa, .{ .alias = bare_name, .name = name });
        try t.global_scope.container_member_fns_map.put(t.gpa, record_qt, .{
            .container_decl_ptr = &payload.data.init,
        });
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn transFnDecl(t: *Translator, scope: *Scope, function: Node.Function) Error!void {
    const func_ty = function.qt.get(t.comp, .func).?;

    const is_pub = scope.id == .root;

    const fn_name = t.tree.tokSlice(function.name_tok);
    if (scope.getAlias(fn_name) != null or t.global_scope.containsNow(fn_name))
        return; // Avoid processing this decl twice

    const fn_decl_loc = function.name_tok;
    const has_body = function.body != null and func_ty.kind != .variadic;
    if (function.body != null and func_ty.kind == .variadic) {
        try t.warn(scope, function.name_tok, "TODO unable to translate variadic function, demoted to extern", .{});
    }

    const is_always_inline = has_body and function.qt.getAttribute(t.comp, .always_inline) != null;
    const proto_ctx: FnProtoContext = .{
        .fn_name = fn_name,
        .is_always_inline = is_always_inline,
        .is_extern = !has_body,
        .is_export = !function.static and has_body and !is_always_inline and !function.@"inline",
        .is_pub = is_pub,
        .has_body = has_body,
        .cc = if (function.qt.getAttribute(t.comp, .calling_convention)) |some| switch (some.cc) {
            .c => .c,
            .stdcall => .x86_stdcall,
            .thiscall => .x86_thiscall,
            .fastcall => .x86_fastcall,
            .regcall => .x86_regcall,
            .riscv_vector => .riscv_vector,
            .aarch64_sve_pcs => .aarch64_sve_pcs,
            .aarch64_vector_pcs => .aarch64_vfabi,
            .arm_aapcs => .arm_aapcs,
            .arm_aapcs_vfp => .arm_aapcs_vfp,
            .vectorcall => switch (t.comp.target.cpu.arch) {
                .x86 => .x86_vectorcall,
                .aarch64, .aarch64_be => .aarch64_vfabi,
                else => .c,
            },
            .x86_64_sysv => .x86_64_sysv,
            .x86_64_win => .x86_64_win,
        } else .c,
    };

    const proto_node = t.transFnType(&t.global_scope.base, function.qt, func_ty, fn_decl_loc, proto_ctx) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(scope, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const proto_payload = proto_node.castTag(.func).?;
    if (!has_body) {
        if (scope.id != .root) {
            const bs: *Scope.Block = try scope.findBlockScope(t);
            const mangled_name = try bs.createMangledName(fn_name, false, Scope.Block.extern_local_prefix);
            const wrapped = try ZigTag.wrapped_local.create(t.arena, .{ .name = mangled_name, .init = proto_node });
            try scope.appendNode(wrapped);
            try bs.discardVariable(mangled_name);
            return;
        }
        try t.global_scope.addMemberFunction(func_ty, proto_payload);
        return t.addTopLevelDecl(fn_name, proto_node);
    }

    // actual function definition with body
    const body_stmt = function.body.?.get(t.tree).compound_stmt;
    var block_scope = try Scope.Block.init(t, &t.global_scope.base, false);
    block_scope.return_type = func_ty.return_type;
    defer block_scope.deinit();

    var param_id: c_uint = 0;
    for (proto_payload.data.params, func_ty.params) |*param, param_info| {
        const param_name = param.name orelse {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try t.warn(&t.global_scope.base, fn_decl_loc, "function {s} parameter has no name, demoted to extern", .{fn_name});
            return t.addTopLevelDecl(fn_name, proto_node);
        };

        const is_const = param_info.qt.@"const";

        const mangled_param_name = try block_scope.makeMangledName(param_name);
        param.name = mangled_param_name;

        if (!is_const) {
            const bare_arg_name = try std.fmt.allocPrint(t.arena, "arg_{s}", .{mangled_param_name});
            const arg_name = try block_scope.makeMangledName(bare_arg_name);
            param.name = arg_name;

            const redecl_node = try ZigTag.arg_redecl.create(t.arena, .{ .actual = mangled_param_name, .mangled = arg_name });
            try block_scope.statements.append(t.gpa, redecl_node);
        }
        try block_scope.discardVariable(mangled_param_name);

        param_id += 1;
    }

    t.transCompoundStmtInline(body_stmt, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => {
            proto_payload.data.is_extern = true;
            proto_payload.data.is_export = false;
            proto_payload.data.is_inline = false;
            try t.warn(&t.global_scope.base, fn_decl_loc, "unable to translate function, demoted to extern", .{});
            return t.addTopLevelDecl(fn_name, proto_node);
        },
    };

    try t.global_scope.addMemberFunction(func_ty, proto_payload);
    proto_payload.data.body = try block_scope.complete();
    return t.addTopLevelDecl(fn_name, proto_node);
}

fn transVarDecl(t: *Translator, scope: *Scope, variable: Node.Variable) Error!void {
    const base_name = t.tree.tokSlice(variable.name_tok);
    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;
    const name, const use_base_name = blk: {
        if (toplevel) break :blk .{ base_name, false };

        // Local extern and static variables are wrapped in a struct.
        const prefix: ?[]const u8 = switch (variable.storage_class) {
            .@"extern" => Scope.Block.extern_local_prefix,
            .static => Scope.Block.static_local_prefix,
            else => null,
        };
        break :blk .{ try bs.createMangledName(base_name, false, prefix), prefix != null };
    };

    if (t.typeWasDemotedToOpaque(variable.qt)) {
        if (variable.storage_class != .@"extern" and scope.id == .root) {
            return t.failDecl(scope, variable.name_tok, name, "non-extern variable has opaque type", .{});
        } else {
            return t.failDecl(scope, variable.name_tok, name, "local variable has opaque type", .{});
        }
    }

    const type_node = (if (variable.initializer) |init|
        t.transTypeInit(scope, variable.qt, init, variable.name_tok)
    else
        t.transType(scope, variable.qt, variable.name_tok)) catch |err| switch (err) {
        error.UnsupportedType => {
            return t.failDecl(scope, variable.name_tok, name, "unable to translate variable declaration type", .{});
        },
        else => |e| return e,
    };

    const array_ty = variable.qt.get(t.comp, .array);
    var is_const = variable.qt.@"const" or (array_ty != null and array_ty.?.elem.@"const");
    var is_extern = variable.storage_class == .@"extern";

    const init_node = init: {
        if (variable.initializer) |init| {
            const maybe_literal = init.get(t.tree);
            const init_node = (if (maybe_literal == .string_literal_expr)
                t.transStringLiteralInitializer(init, maybe_literal.string_literal_expr, type_node)
            else
                t.transExprCoercing(scope, init, .used)) catch |err| switch (err) {
                error.UnsupportedTranslation, error.UnsupportedType => {
                    return t.failDecl(scope, variable.name_tok, name, "unable to resolve var init expr", .{});
                },
                else => |e| return e,
            };

            if (!variable.qt.is(t.comp, .bool) and init_node.isBoolRes()) {
                break :init try ZigTag.int_from_bool.create(t.arena, init_node);
            } else {
                break :init init_node;
            }
        }
        if (variable.storage_class == .@"extern") {
            if (array_ty != null and array_ty.?.len == .incomplete) {
                // Oh no, an extern array of unknown size! These are really fun because there's no
                // direct equivalent in Zig. To translate correctly, we'll have to create a C-pointer
                // to the data initialized via @extern.

                // Since this is really a pointer to the underlying data, we tweak a few properties.
                is_extern = false;
                is_const = true;

                const name_str = try std.fmt.allocPrint(t.arena, "\"{s}\"", .{base_name});
                break :init try ZigTag.builtin_extern.create(t.arena, .{
                    .type = type_node,
                    .name = try ZigTag.string_literal.create(t.arena, name_str),
                });
            }
            break :init null;
        }
        if (toplevel or variable.storage_class == .static or variable.thread_local) {
            // The C language specification states that variables with static or threadlocal
            // storage without an initializer are initialized to a zero value.
            break :init try t.createZeroValueNode(variable.qt, type_node, .no_as);
        }
        break :init ZigTag.undefined_literal.init();
    };

    const linksection_string = blk: {
        if (variable.qt.getAttribute(t.comp, .section)) |section| {
            break :blk t.comp.interner.get(section.name.ref()).bytes;
        }
        break :blk null;
    };

    const alignment: ?c_uint = variable.qt.requestedAlignment(t.comp) orelse null;
    var node = try ZigTag.var_decl.create(t.arena, .{
        .is_pub = toplevel,
        .is_const = is_const,
        .is_extern = is_extern,
        .is_export = toplevel and variable.storage_class == .auto,
        .is_threadlocal = variable.thread_local,
        .linksection_string = linksection_string,
        .alignment = alignment,
        .name = if (use_base_name) base_name else name,
        .type = type_node,
        .init = init_node,
    });

    if (toplevel) {
        try t.addTopLevelDecl(name, node);
    } else {
        if (use_base_name) {
            node = try ZigTag.wrapped_local.create(t.arena, .{ .name = name, .init = node });
        }
        try scope.appendNode(node);
        try bs.discardVariable(name);

        if (variable.qt.getAttribute(t.comp, .cleanup)) |cleanup_attr| {
            const cleanup_fn_name = t.tree.tokSlice(cleanup_attr.function.tok);
            const mangled_fn_name = scope.getAlias(cleanup_fn_name) orelse cleanup_fn_name;
            const fn_id = try ZigTag.identifier.create(t.arena, mangled_fn_name);

            const varname = try ZigTag.identifier.create(t.arena, name);
            const args = try t.arena.alloc(ZigNode, 1);
            args[0] = try ZigTag.address_of.create(t.arena, varname);

            const cleanup_call = try ZigTag.call.create(t.arena, .{ .lhs = fn_id, .args = args });
            const discard = try ZigTag.discard.create(t.arena, .{ .should_skip = false, .value = cleanup_call });
            const deferred_cleanup = try ZigTag.@"defer".create(t.arena, discard);

            try bs.statements.append(t.gpa, deferred_cleanup);
        }
    }
}

fn transEnumDecl(t: *Translator, scope: *Scope, enum_qt: QualType) Error!void {
    const base = enum_qt.base(t.comp);
    const enum_ty = base.type.@"enum";

    if (t.type_decls.get(enum_ty.decl_node)) |_|
        return; // Avoid processing this decl twice

    const toplevel = scope.id == .root;
    const bs: *Scope.Block = if (!toplevel) try scope.findBlockScope(t) else undefined;

    var bare_name = enum_ty.name.lookup(t.comp);
    var is_unnamed = false;
    var name = bare_name;
    if (t.unnamed_typedefs.get(base.qt)) |typedef_name| {
        bare_name = typedef_name;
        name = typedef_name;
    } else {
        if (enum_ty.isAnonymous(t.comp)) {
            bare_name = try std.fmt.allocPrint(t.arena, "unnamed_{d}", .{t.getMangle()});
            is_unnamed = true;
        }
        name = try std.fmt.allocPrint(t.arena, "enum_{s}", .{bare_name});
    }
    if (!toplevel) name = try bs.makeMangledName(name);
    try t.type_decls.putNoClobber(t.gpa, enum_ty.decl_node, name);

    const enum_type_node = if (!base.qt.hasIncompleteSize(t.comp)) blk: {
        const enum_decl = enum_ty.decl_node.get(t.tree).enum_decl;
        for (enum_ty.fields, enum_decl.fields) |field, field_node| {
            var enum_val_name = field.name.lookup(t.comp);
            if (!toplevel) {
                enum_val_name = try bs.makeMangledName(enum_val_name);
            }

            const enum_const_type_node: ?ZigNode = t.transType(scope, field.qt, field.name_tok) catch |err| switch (err) {
                error.UnsupportedType => null,
                else => |e| return e,
            };

            const val = t.tree.value_map.get(field_node).?;
            const enum_const_def = try ZigTag.enum_constant.create(t.arena, .{
                .name = enum_val_name,
                .is_public = toplevel,
                .type = enum_const_type_node,
                .value = try t.createIntNode(val),
            });
            if (toplevel)
                try t.addTopLevelDecl(enum_val_name, enum_const_def)
            else {
                try scope.appendNode(enum_const_def);
                try bs.discardVariable(enum_val_name);
            }
        }

        break :blk t.transType(scope, enum_ty.tag.?, enum_decl.name_or_kind_tok) catch |err| switch (err) {
            error.UnsupportedType => {
                return t.failDecl(scope, enum_decl.name_or_kind_tok, name, "unable to translate enum integer type", .{});
            },
            else => |e| return e,
        };
    } else blk: {
        try t.opaque_demotes.put(t.gpa, base.qt, {});
        break :blk ZigTag.opaque_literal.init();
    };

    const is_pub = toplevel and !is_unnamed;
    const payload = try t.arena.create(ast.Payload.SimpleVarDecl);
    payload.* = .{
        .base = .{ .tag = if (is_pub) .pub_var_simple else .var_simple },
        .data = .{
            .init = enum_type_node,
            .name = name,
        },
    };
    const node = ZigNode.initPayload(&payload.base);
    if (toplevel) {
        try t.addTopLevelDecl(name, node);
        if (!is_unnamed)
            try t.alias_list.append(t.gpa, .{ .alias = bare_name, .name = name });
    } else {
        try scope.appendNode(node);
        try bs.discardVariable(name);
    }
}

fn transStaticAssert(t: *Translator, scope: *Scope, static_assert: Node.StaticAssert) Error!void {
    const condition = t.transExpr(scope, static_assert.cond, .used) catch |err| switch (err) {
        error.UnsupportedTranslation, error.UnsupportedType => {
            return try t.warn(&t.global_scope.base, static_assert.cond.tok(t.tree), "unable to translate _Static_assert condition", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    // generate @compileError message that matches C compiler output
    const diagnostic = if (static_assert.message) |message| str: {
        // Aro guarantees this to be a string literal.
        const str_val = t.tree.value_map.get(message).?;
        const str_qt = message.qt(t.tree);

        const bytes = t.comp.interner.get(str_val.ref()).bytes;
        var allocating: std.Io.Writer.Allocating = .init(t.gpa);
        defer allocating.deinit();

        allocating.writer.writeAll("\"static assertion failed \\") catch return error.OutOfMemory;

        aro.Value.printString(bytes, str_qt, t.comp, &allocating.writer) catch return error.OutOfMemory;
        allocating.writer.end -= 1; // printString adds a terminating " so we need to remove it
        allocating.writer.writeAll("\\\"\"") catch return error.OutOfMemory;

        break :str try ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, allocating.written()));
    } else try ZigTag.string_literal.create(t.arena, "\"static assertion failed\"");

    const assert_node = try ZigTag.static_assert.create(t.arena, .{ .lhs = condition, .rhs = diagnostic });
    try scope.appendNode(assert_node);
}

fn transGlobalAsm(t: *Translator, scope: *Scope, global_asm: Node.SimpleAsm) Error!void {
    const asm_string = t.tree.value_map.get(global_asm.asm_str).?;
    const bytes = t.comp.interner.get(asm_string.ref()).bytes;

    var allocating: std.Io.Writer.Allocating = try .initCapacity(t.gpa, bytes.len);
    defer allocating.deinit();
    aro.Value.printString(bytes, global_asm.asm_str.qt(t.tree), t.comp, &allocating.writer) catch return error.OutOfMemory;

    const str_node = try ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, allocating.written()));

    const asm_node = try ZigTag.asm_simple.create(t.arena, str_node);
    const block = try ZigTag.block_single.create(t.arena, asm_node);
    const comptime_node = try ZigTag.@"comptime".create(t.arena, block);

    try scope.appendNode(comptime_node);
}

// ================
// Type translation
// ================

fn getTypeStr(t: *Translator, qt: QualType) ![]const u8 {
    var allocating: std.Io.Writer.Allocating = .init(t.gpa);
    defer allocating.deinit();
    qt.print(t.comp, &allocating.writer) catch return error.OutOfMemory;
    return t.arena.dupe(u8, allocating.written());
}

fn transType(t: *Translator, scope: *Scope, qt: QualType, source_loc: TokenIndex) TypeError!ZigNode {
    loop: switch (qt.type(t.comp)) {
        .atomic => {
            const type_name = try t.getTypeStr(qt);
            return t.fail(error.UnsupportedType, source_loc, "TODO support atomic type: '{s}'", .{type_name});
        },
        .void => return ZigTag.type.create(t.arena, "anyopaque"),
        .bool => return ZigTag.type.create(t.arena, "bool"),
        .int => |int_ty| switch (int_ty) {
            //.char => return ZigTag.type.create(t.arena, "c_char"), // TODO: this is the preferred translation
            .char => return ZigTag.type.create(t.arena, "u8"),
            .schar => return ZigTag.type.create(t.arena, "i8"),
            .uchar => return ZigTag.type.create(t.arena, "u8"),
            .short => return ZigTag.type.create(t.arena, "c_short"),
            .ushort => return ZigTag.type.create(t.arena, "c_ushort"),
            .int => return ZigTag.type.create(t.arena, "c_int"),
            .uint => return ZigTag.type.create(t.arena, "c_uint"),
            .long => return ZigTag.type.create(t.arena, "c_long"),
            .ulong => return ZigTag.type.create(t.arena, "c_ulong"),
            .long_long => return ZigTag.type.create(t.arena, "c_longlong"),
            .ulong_long => return ZigTag.type.create(t.arena, "c_ulonglong"),
            .int128 => return ZigTag.type.create(t.arena, "i128"),
            .uint128 => return ZigTag.type.create(t.arena, "u128"),
        },
        .float => |float_ty| switch (float_ty) {
            .fp16, .float16 => return ZigTag.type.create(t.arena, "f16"),
            .float => return ZigTag.type.create(t.arena, "f32"),
            .double => return ZigTag.type.create(t.arena, "f64"),
            .long_double => return ZigTag.type.create(t.arena, "c_longdouble"),
            .float128 => return ZigTag.type.create(t.arena, "f128"),
        },
        .pointer => |pointer_ty| {
            const child_qt = pointer_ty.child;

            const is_fn_proto = child_qt.is(t.comp, .func);
            const is_const = is_fn_proto or child_qt.@"const";
            const is_volatile = child_qt.@"volatile";
            const elem_type = try t.transType(scope, child_qt, source_loc);
            const ptr_info: @FieldType(ast.Payload.Pointer, "data") = .{
                .is_const = is_const,
                .is_volatile = is_volatile,
                .elem_type = elem_type,
                .is_allowzero = false,
            };
            if (is_fn_proto or
                t.typeIsOpaque(child_qt) or
                t.typeWasDemotedToOpaque(child_qt))
            {
                const ptr = try ZigTag.single_pointer.create(t.arena, ptr_info);
                return ZigTag.optional_type.create(t.arena, ptr);
            }

            return ZigTag.c_pointer.create(t.arena, ptr_info);
        },
        .array => |array_ty| {
            const elem_qt = array_ty.elem;
            switch (array_ty.len) {
                .incomplete, .unspecified_variable => {
                    const elem_type = try t.transType(scope, elem_qt, source_loc);
                    return ZigTag.c_pointer.create(t.arena, .{
                        .is_const = elem_qt.@"const",
                        .is_volatile = elem_qt.@"volatile",
                        .is_allowzero = false,
                        .elem_type = elem_type,
                    });
                },
                .fixed, .static => |len| {
                    const elem_type = try t.transType(scope, elem_qt, source_loc);
                    return ZigTag.array_type.create(t.arena, .{ .len = len, .elem_type = elem_type });
                },
                .variable => return t.fail(error.UnsupportedType, source_loc, "VLA unsupported '{s}'", .{try t.getTypeStr(qt)}),
            }
        },
        .func => |func_ty| return t.transFnType(scope, qt, func_ty, source_loc, .{}),
        .@"struct", .@"union" => |record_ty| {
            var trans_scope = scope;
            if (!record_ty.isAnonymous(t.comp)) {
                if (t.weak_global_names.contains(record_ty.name.lookup(t.comp))) trans_scope = &t.global_scope.base;
            }
            try t.transRecordDecl(trans_scope, qt);
            const name = t.type_decls.get(record_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .@"enum" => |enum_ty| {
            var trans_scope = scope;
            const is_anonymous = enum_ty.isAnonymous(t.comp);
            if (!is_anonymous) {
                if (t.weak_global_names.contains(enum_ty.name.lookup(t.comp))) trans_scope = &t.global_scope.base;
            }
            try t.transEnumDecl(trans_scope, qt);
            const name = t.type_decls.get(enum_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .typedef => |typedef_ty| {
            var trans_scope = scope;
            const typedef_name = typedef_ty.name.lookup(t.comp);
            if (builtin_typedef_map.get(typedef_name)) |builtin| return ZigTag.type.create(t.arena, builtin);
            if (t.global_names.contains(typedef_name)) trans_scope = &t.global_scope.base;

            try t.transTypeDef(trans_scope, typedef_ty.decl_node);
            const name = t.type_decls.get(typedef_ty.decl_node).?;
            return ZigTag.identifier.create(t.arena, name);
        },
        .attributed => |attributed_ty| continue :loop attributed_ty.base.type(t.comp),
        .typeof => |typeof_ty| continue :loop typeof_ty.base.type(t.comp),
        .vector => |vector_ty| {
            const len = try t.createNumberNode(vector_ty.len, .int);
            const elem_type = try t.transType(scope, vector_ty.elem, source_loc);
            return ZigTag.vector.create(t.arena, .{ .lhs = len, .rhs = elem_type });
        },
        else => return t.fail(error.UnsupportedType, source_loc, "unsupported type: '{s}'", .{try t.getTypeStr(qt)}),
    }
}

/// Look ahead through the fields of the record to determine what the alignment of the record
/// would be without any align/packed/etc. attributes. This helps us determine whether or not
/// the fields with 0 offset need an `align` qualifier. Strictly speaking, we could just
/// pedantically assign those fields the same alignment as the parent's pointer alignment,
/// but this helps the generated code to be a little less verbose.
fn headFieldAlignment(t: *Translator, record_decl: aro.Type.Record) ?c_uint {
    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.layout.?.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;
    var max_field_alignment_bits: u64 = 0;
    for (record_decl.fields) |field| {
        if (field.qt.getRecord(t.comp)) |field_record_decl| {
            const child_record_alignment = field_record_decl.layout.?.field_alignment_bits;
            if (child_record_alignment > max_field_alignment_bits)
                max_field_alignment_bits = child_record_alignment;
        } else {
            const field_size = field.layout.size_bits;
            if (field_size > max_field_alignment_bits)
                max_field_alignment_bits = field_size;
        }
    }
    if (max_field_alignment_bits != parent_ptr_alignment_bits) {
        return parent_ptr_alignment;
    } else {
        return null;
    }
}

/// This function inspects the generated layout of a record to determine the alignment for a
/// particular field. This approach is necessary because unlike Zig, a C compiler is not
/// required to fulfill the requested alignment, which means we'd risk generating different code
/// if we only look at the user-requested alignment.
///
/// Returns a ?c_uint to match Clang's behavior of using c_uint. The return type can be changed
/// after the Clang frontend for translate-c is removed. A null value indicates that a field is
/// 'naturally aligned'.
fn alignmentForField(
    t: *Translator,
    record_decl: aro.Type.Record,
    head_field_alignment: ?c_uint,
    field_index: usize,
) ?c_uint {
    const fields = record_decl.fields;
    assert(fields.len != 0);
    const field = fields[field_index];

    const bits_per_byte = 8;
    const parent_ptr_alignment_bits = record_decl.layout.?.pointer_alignment_bits;
    const parent_ptr_alignment = parent_ptr_alignment_bits / bits_per_byte;

    // bitfields aren't supported yet. Until support is added, records with bitfields
    // should be demoted to opaque, and this function shouldn't be called for them.
    if (field.bit_width != .null) {
        @panic("TODO: add bitfield support for records");
    }

    const field_offset_bits: u64 = field.layout.offset_bits;
    const field_size_bits: u64 = field.layout.size_bits;

    // Fields with zero width always have an alignment of 1
    if (field_size_bits == 0) {
        return 1;
    }

    // Fields with 0 offset inherit the parent's pointer alignment.
    if (field_offset_bits == 0) {
        return head_field_alignment;
    }

    // Records have a natural alignment when used as a field, and their size is
    // a multiple of this alignment value. For all other types, the natural alignment
    // is their size.
    const field_natural_alignment_bits: u64 = if (field.qt.getRecord(t.comp)) |record|
        record.layout.?.field_alignment_bits
    else
        field_size_bits;
    const rem_bits = field_offset_bits % field_natural_alignment_bits;

    // If there's a remainder, then the alignment is smaller than the field's
    // natural alignment
    if (rem_bits > 0) {
        const rem_alignment = rem_bits / bits_per_byte;
        if (rem_alignment > 0 and std.math.isPowerOfTwo(rem_alignment)) {
            const actual_alignment = @min(rem_alignment, parent_ptr_alignment);
            return @as(c_uint, @truncate(actual_alignment));
        } else {
            return 1;
        }
    }

    // A field may have an offset which positions it to be naturally aligned, but the
    // parent's pointer alignment determines if this is actually true, so we take the minimum
    // value.
    // For example, a float field (4 bytes wide) with a 4 byte offset is positioned to have natural
    // alignment, but if the parent pointer alignment is 2, then the actual alignment of the
    // float is 2.
    const field_natural_alignment: u64 = field_natural_alignment_bits / bits_per_byte;
    const offset_alignment = field_offset_bits / bits_per_byte;
    const possible_alignment = @min(parent_ptr_alignment, offset_alignment);
    if (possible_alignment == field_natural_alignment) {
        return null;
    } else if (possible_alignment < field_natural_alignment) {
        if (std.math.isPowerOfTwo(possible_alignment)) {
            return possible_alignment;
        } else {
            return 1;
        }
    } else { // possible_alignment > field_natural_alignment
        // Here, the field is positioned be at a higher alignment than it's natural alignment. This means we
        // need to determine whether it's a specified alignment. We can determine that from the padding preceding
        // the field.
        const padding_from_prev_field: u64 = blk: {
            if (field_offset_bits != 0) {
                const previous_field = fields[field_index - 1];
                break :blk (field_offset_bits - previous_field.layout.offset_bits) - previous_field.layout.size_bits;
            } else {
                break :blk 0;
            }
        };
        if (padding_from_prev_field < field_natural_alignment_bits) {
            return null;
        } else {
            return possible_alignment;
        }
    }
}

const FnProtoContext = struct {
    is_pub: bool = false,
    is_export: bool = false,
    is_extern: bool = false,
    is_always_inline: bool = false,
    fn_name: ?[]const u8 = null,
    has_body: bool = false,
    cc: ast.Payload.Func.CallingConvention = .c,
};

fn transFnType(
    t: *Translator,
    scope: *Scope,
    func_qt: QualType,
    func_ty: aro.Type.Func,
    source_loc: TokenIndex,
    ctx: FnProtoContext,
) !ZigNode {
    const param_count: usize = func_ty.params.len;
    const fn_params = try t.arena.alloc(ast.Payload.Param, param_count);

    for (func_ty.params, fn_params) |param_info, *param_node| {
        const param_qt = param_info.qt;
        const is_noalias = param_qt.restrict;

        const param_name: ?[]const u8 = if (param_info.name == .empty)
            null
        else
            param_info.name.lookup(t.comp);

        const type_node = try t.transType(scope, param_qt, param_info.name_tok);
        param_node.* = .{
            .is_noalias = is_noalias,
            .name = param_name,
            .type = type_node,
        };
    }

    const linksection_string = blk: {
        if (func_qt.getAttribute(t.comp, .section)) |section| {
            break :blk t.comp.interner.get(section.name.ref()).bytes;
        }
        break :blk null;
    };

    const alignment: ?c_uint = func_qt.requestedAlignment(t.comp) orelse null;

    const explicit_callconv = if ((ctx.is_always_inline or ctx.is_export or ctx.is_extern) and ctx.cc == .c) null else ctx.cc;

    const return_type_node = blk: {
        if (func_qt.getAttribute(t.comp, .noreturn) != null) {
            break :blk ZigTag.noreturn_type.init();
        } else {
            const return_qt = func_ty.return_type;
            if (return_qt.is(t.comp, .void)) {
                // convert primitive anyopaque to actual void (only for return type)
                break :blk ZigTag.void_type.init();
            } else {
                break :blk t.transType(scope, return_qt, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try t.warn(scope, source_loc, "unsupported function proto return type", .{});
                        return err;
                    },
                    error.OutOfMemory => |e| return e,
                };
            }
        }
    };

    const payload = try t.arena.create(ast.Payload.Func);
    payload.* = .{
        .base = .{ .tag = .func },
        .data = .{
            .is_pub = ctx.is_pub,
            .is_extern = ctx.is_extern,
            .is_export = ctx.is_export,
            .is_inline = ctx.is_always_inline,
            .is_var_args = switch (func_ty.kind) {
                .normal => false,
                .variadic => true,
                .old_style => !ctx.is_export and !ctx.is_always_inline and !ctx.has_body,
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

/// Produces a Zig AST node by translating a Type, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transTypeIntWidthOf(t: *Translator, qt: QualType, is_signed: bool) TypeError!ZigNode {
    return ZigTag.type.create(t.arena, loop: switch (qt.base(t.comp).type) {
        .int => |int_ty| switch (int_ty) {
            .char, .schar, .uchar => if (is_signed) "i8" else "u8",
            .short, .ushort => if (is_signed) "c_short" else "c_ushort",
            .int, .uint => if (is_signed) "c_int" else "c_uint",
            .long, .ulong => if (is_signed) "c_long" else "c_ulong",
            .long_long, .ulong_long => if (is_signed) "c_longlong" else "c_ulonglong",
            .int128, .uint128 => if (is_signed) "i128" else "u128",
        },
        .bit_int => |bit_int_ty| try std.fmt.allocPrint(t.arena, "{s}{d}", .{
            if (is_signed) "i" else "u",
            bit_int_ty.bits,
        }),
        .@"enum" => |enum_ty| blk: {
            const tag_ty = enum_ty.tag orelse
                break :blk if (is_signed) "c_int" else "c_uint";

            continue :loop tag_ty.base(t.comp).type;
        },
        else => unreachable, // only call this function when it has already been determined the type is int
    });
}

fn transTypeInit(
    t: *Translator,
    scope: *Scope,
    qt: QualType,
    init: Node.Index,
    source_loc: TokenIndex,
) TypeError!ZigNode {
    switch (init.get(t.tree)) {
        .string_literal_expr => |literal| {
            const elem_ty = try t.transType(scope, qt.childType(t.comp), source_loc);

            const string_lit_size = literal.qt.arrayLen(t.comp).?;
            const array_size = qt.arrayLen(t.comp).?;

            if (array_size == string_lit_size) {
                return ZigTag.null_sentinel_array_type.create(t.arena, .{ .len = array_size - 1, .elem_type = elem_ty });
            } else {
                return ZigTag.array_type.create(t.arena, .{ .len = array_size, .elem_type = elem_ty });
            }
        },
        else => {},
    }
    return t.transType(scope, qt, source_loc);
}

// ============
// Type helpers
// ============

fn typeIsOpaque(t: *Translator, qt: QualType) bool {
    return switch (qt.base(t.comp).type) {
        .void => true,
        .@"struct", .@"union" => |record_ty| {
            if (record_ty.layout == null) return true;
            for (record_ty.fields) |field| {
                if (field.bit_width != .null) return true;
            }
            return false;
        },
        else => false,
    };
}

fn typeWasDemotedToOpaque(t: *Translator, qt: QualType) bool {
    const base = qt.base(t.comp);
    switch (base.type) {
        .@"struct", .@"union" => |record_ty| {
            if (t.opaque_demotes.contains(base.qt)) return true;
            for (record_ty.fields) |field| {
                if (t.typeWasDemotedToOpaque(field.qt)) return true;
            }
            return false;
        },
        .@"enum" => return t.opaque_demotes.contains(base.qt),
        else => return false,
    }
}

fn typeHasWrappingOverflow(t: *Translator, qt: QualType) bool {
    if (t.signedness(qt) == .unsigned) {
        // unsigned integer overflow wraps around.
        return true;
    } else {
        // float, signed integer, and pointer overflow is undefined behavior.
        return false;
    }
}

/// Signedness of type when translated to Zig.
/// Different from `QualType.signedness()` for `char` and enums.
/// Returns null for non-int types.
fn signedness(t: *Translator, qt: QualType) ?std.builtin.Signedness {
    return loop: switch (qt.base(t.comp).type) {
        .bool => .unsigned,
        .bit_int => |bit_int| bit_int.signedness,
        .int => |int_ty| switch (int_ty) {
            .char => .unsigned, // Always translated as u8
            .schar, .short, .int, .long, .long_long, .int128 => .signed,
            .uchar, .ushort, .uint, .ulong, .ulong_long, .uint128 => .unsigned,
        },
        .@"enum" => |enum_ty| {
            const tag_qt = enum_ty.tag orelse return .signed;
            continue :loop tag_qt.base(t.comp).type;
        },
        else => return null,
    };
}

// =====================
// Statement translation
// =====================

fn transStmt(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    switch (stmt.get(t.tree)) {
        .compound_stmt => |compound| {
            return t.transCompoundStmt(scope, compound);
        },
        .static_assert => |static_assert| {
            try t.transStaticAssert(scope, static_assert);
            return ZigTag.declaration.init();
        },
        .return_stmt => |return_stmt| return t.transReturnStmt(scope, return_stmt),
        .null_stmt => return ZigTag.empty_block.init(),
        .if_stmt => |if_stmt| return t.transIfStmt(scope, if_stmt),
        .while_stmt => |while_stmt| return t.transWhileStmt(scope, while_stmt),
        .do_while_stmt => |do_while_stmt| return t.transDoWhileStmt(scope, do_while_stmt),
        .for_stmt => |for_stmt| return t.transForStmt(scope, for_stmt),
        .continue_stmt => return ZigTag.@"continue".init(),
        .break_stmt => return ZigTag.@"break".init(),
        .typedef => |typedef_decl| {
            assert(!typedef_decl.implicit);
            try t.transTypeDef(scope, stmt);
            return ZigTag.declaration.init();
        },
        .struct_decl, .union_decl => |record_decl| {
            try t.transRecordDecl(scope, record_decl.container_qt);
            return ZigTag.declaration.init();
        },
        .enum_decl => |enum_decl| {
            try t.transEnumDecl(scope, enum_decl.container_qt);
            return ZigTag.declaration.init();
        },
        .function => |function| {
            try t.transFnDecl(scope, function);
            return ZigTag.declaration.init();
        },
        .variable => |variable| {
            try t.transVarDecl(scope, variable);
            return ZigTag.declaration.init();
        },
        .switch_stmt => |switch_stmt| return t.transSwitch(scope, switch_stmt),
        .case_stmt, .default_stmt => {
            return t.fail(error.UnsupportedTranslation, stmt.tok(t.tree), "TODO complex switch", .{});
        },
        .goto_stmt, .computed_goto_stmt, .labeled_stmt => {
            return t.fail(error.UnsupportedTranslation, stmt.tok(t.tree), "TODO goto", .{});
        },
        else => return t.transExprCoercing(scope, stmt, .unused),
    }
}

fn transCompoundStmtInline(t: *Translator, compound: Node.CompoundStmt, block: *Scope.Block) TransError!void {
    for (compound.body) |stmt| {
        const result = try t.transStmt(&block.base, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block.statements.append(t.gpa, result),
        }
    }
}

fn transCompoundStmt(t: *Translator, scope: *Scope, compound: Node.CompoundStmt) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, false);
    defer block_scope.deinit();
    try t.transCompoundStmtInline(compound, &block_scope);
    return try block_scope.complete();
}

fn transReturnStmt(t: *Translator, scope: *Scope, return_stmt: Node.ReturnStmt) TransError!ZigNode {
    switch (return_stmt.operand) {
        .none => return ZigTag.return_void.init(),
        .expr => |operand| {
            var rhs = try t.transExprCoercing(scope, operand, .used);
            const return_qt = scope.findBlockReturnType();
            if (rhs.isBoolRes() and !return_qt.is(t.comp, .bool)) {
                rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
            }
            return ZigTag.@"return".create(t.arena, rhs);
        },
        .implicit => |zero| {
            if (zero) return ZigTag.@"return".create(t.arena, ZigTag.zero_literal.init());

            const return_qt = scope.findBlockReturnType();
            if (return_qt.is(t.comp, .void)) return ZigTag.empty_block.init();

            return ZigTag.@"return".create(t.arena, ZigTag.undefined_literal.init());
        },
    }
}

/// If a statement can possibly translate to a Zig assignment (either directly because it's
/// an assignment in C or indirectly via result assignment to `_`) AND it's the sole statement
/// in the body of an if statement or loop, then we need to put the statement into its own block.
/// The `else` case here corresponds to statements that could result in an assignment. If a statement
/// class never needs a block, add its enum to the top prong.
fn maybeBlockify(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    switch (stmt.get(t.tree)) {
        .break_stmt,
        .continue_stmt,
        .compound_stmt,
        .decl_ref_expr,
        .enumeration_ref,
        .do_while_stmt,
        .for_stmt,
        .if_stmt,
        .return_stmt,
        .null_stmt,
        .while_stmt,
        => return t.transStmt(scope, stmt),
        else => return t.blockify(scope, stmt),
    }
}

/// Translate statement and place it in its own block.
fn blockify(t: *Translator, scope: *Scope, stmt: Node.Index) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, false);
    defer block_scope.deinit();
    const result = try t.transStmt(&block_scope.base, stmt);
    try block_scope.statements.append(t.gpa, result);
    return block_scope.complete();
}

fn transIfStmt(t: *Translator, scope: *Scope, if_stmt: Node.IfStmt) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, if_stmt.cond);

    // block needed to keep else statement from attaching to inner while
    const must_blockify = (if_stmt.else_body != null) and switch (if_stmt.then_body.get(t.tree)) {
        .while_stmt, .do_while_stmt, .for_stmt => true,
        else => false,
    };

    const then_node = if (must_blockify)
        try t.blockify(scope, if_stmt.then_body)
    else
        try t.maybeBlockify(scope, if_stmt.then_body);

    const else_node = if (if_stmt.else_body) |stmt|
        try t.maybeBlockify(scope, stmt)
    else
        null;
    return ZigTag.@"if".create(t.arena, .{ .cond = cond, .then = then_node, .@"else" = else_node });
}

fn transWhileStmt(t: *Translator, scope: *Scope, while_stmt: Node.WhileStmt) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, while_stmt.cond);

    var loop_scope: Scope = .{
        .parent = scope,
        .id = .loop,
    };
    const body = try t.maybeBlockify(&loop_scope, while_stmt.body);
    return ZigTag.@"while".create(t.arena, .{ .cond = cond, .body = body, .cont_expr = null });
}

fn transDoWhileStmt(t: *Translator, scope: *Scope, do_stmt: Node.DoWhileStmt) TransError!ZigNode {
    var loop_scope: Scope = .{
        .parent = scope,
        .id = .do_loop,
    };

    // if (!cond) break;
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const cond = try t.transBoolExpr(&cond_scope.base, do_stmt.cond);
    const if_not_break = switch (cond.tag()) {
        .true_literal => {
            const body_node = try t.maybeBlockify(scope, do_stmt.body);
            return ZigTag.while_true.create(t.arena, body_node);
        },
        else => try ZigTag.if_not_break.create(t.arena, cond),
    };

    var body_node = try t.transStmt(&loop_scope, do_stmt.body);
    if (body_node.isNoreturn(true)) {
        // The body node ends in a noreturn statement. Simply put it in a while (true)
        // in case it contains breaks or continues.
    } else if (do_stmt.body.get(t.tree) == .compound_stmt) {
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
        const statements = try t.arena.alloc(ZigNode, 2);
        statements[0] = body_node;
        statements[1] = if_not_break;
        body_node = try ZigTag.block.create(t.arena, .{ .label = null, .stmts = statements });
    }
    return ZigTag.while_true.create(t.arena, body_node);
}

fn transForStmt(t: *Translator, scope: *Scope, for_stmt: Node.ForStmt) TransError!ZigNode {
    var loop_scope: Scope = .{
        .parent = scope,
        .id = .loop,
    };

    var block_scope: ?Scope.Block = null;
    defer if (block_scope) |*bs| bs.deinit();

    switch (for_stmt.init) {
        .decls => |decls| {
            block_scope = try Scope.Block.init(t, scope, false);
            loop_scope.parent = &block_scope.?.base;
            for (decls) |decl| {
                try t.transDecl(&block_scope.?.base, decl);
            }
        },
        .expr => |maybe_init| if (maybe_init) |init| {
            block_scope = try Scope.Block.init(t, scope, false);
            loop_scope.parent = &block_scope.?.base;
            const init_node = try t.transStmt(&block_scope.?.base, init);
            try loop_scope.appendNode(init_node);
        },
    }
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = &loop_scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond = if (for_stmt.cond) |cond|
        try t.transBoolExpr(&cond_scope.base, cond)
    else
        ZigTag.true_literal.init();

    const cont_expr = if (for_stmt.incr) |incr|
        try t.transExpr(&cond_scope.base, incr, .unused)
    else
        null;

    const body = try t.maybeBlockify(&loop_scope, for_stmt.body);
    const while_node = try ZigTag.@"while".create(t.arena, .{ .cond = cond, .body = body, .cont_expr = cont_expr });
    if (block_scope) |*bs| {
        try bs.statements.append(t.gpa, while_node);
        return try bs.complete();
    } else {
        return while_node;
    }
}

fn transSwitch(t: *Translator, scope: *Scope, switch_stmt: Node.SwitchStmt) TransError!ZigNode {
    var loop_scope: Scope = .{
        .parent = scope,
        .id = .loop,
    };

    var block_scope = try Scope.Block.init(t, &loop_scope, false);
    defer block_scope.deinit();

    const base_scope = &block_scope.base;

    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = base_scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();
    const switch_expr = try t.transExpr(&cond_scope.base, switch_stmt.cond, .used);

    var cases: std.ArrayList(ZigNode) = .empty;
    defer cases.deinit(t.gpa);
    var has_default = false;

    const body_node = switch_stmt.body.get(t.tree);
    if (body_node != .compound_stmt) {
        return t.fail(error.UnsupportedTranslation, switch_stmt.switch_tok, "TODO complex switch", .{});
    }
    const body = body_node.compound_stmt.body;
    // Iterate over switch body and collect all cases.
    // Fallthrough is handled by duplicating statements.
    for (body, 0..) |stmt, i| {
        switch (stmt.get(t.tree)) {
            .case_stmt => {
                var items: std.ArrayList(ZigNode) = .empty;
                defer items.deinit(t.gpa);
                const sub = try t.transCaseStmt(base_scope, stmt, &items);
                const res = try t.transSwitchProngStmt(base_scope, sub, body[i..]);

                if (items.items.len == 0) {
                    has_default = true;
                    const switch_else = try ZigTag.switch_else.create(t.arena, res);
                    try cases.append(t.gpa, switch_else);
                } else {
                    const switch_prong = try ZigTag.switch_prong.create(t.arena, .{
                        .cases = try t.arena.dupe(ZigNode, items.items),
                        .cond = res,
                    });
                    try cases.append(t.gpa, switch_prong);
                }
            },
            .default_stmt => |default_stmt| {
                has_default = true;

                var sub = default_stmt.body;
                while (true) switch (sub.get(t.tree)) {
                    .case_stmt => |sub_case| sub = sub_case.body,
                    .default_stmt => |sub_default| sub = sub_default.body,
                    else => break,
                };

                const res = try t.transSwitchProngStmt(base_scope, sub, body[i..]);

                const switch_else = try ZigTag.switch_else.create(t.arena, res);
                try cases.append(t.gpa, switch_else);
            },
            else => {}, // collected in transSwitchProngStmt
        }
    }

    if (!has_default) {
        const else_prong = try ZigTag.switch_else.create(t.arena, ZigTag.empty_block.init());
        try cases.append(t.gpa, else_prong);
    }

    const switch_node = try ZigTag.@"switch".create(t.arena, .{
        .cond = switch_expr,
        .cases = try t.arena.dupe(ZigNode, cases.items),
    });
    try block_scope.statements.append(t.gpa, switch_node);
    try block_scope.statements.append(t.gpa, ZigTag.@"break".init());
    const while_body = try block_scope.complete();

    return ZigTag.while_true.create(t.arena, while_body);
}

/// Collects all items for this case, returns the first statement after the labels.
/// If items ends up empty, the prong should be translated as an else.
fn transCaseStmt(
    t: *Translator,
    scope: *Scope,
    stmt: Node.Index,
    items: *std.ArrayList(ZigNode),
) TransError!Node.Index {
    var sub = stmt;
    var seen_default = false;
    while (true) {
        switch (sub.get(t.tree)) {
            .default_stmt => |default_stmt| {
                seen_default = true;
                items.items.len = 0;
                sub = default_stmt.body;
            },
            .case_stmt => |case_stmt| {
                if (seen_default) {
                    items.items.len = 0;
                    sub = case_stmt.body;
                    continue;
                }

                const expr = if (case_stmt.end) |end| blk: {
                    const start_node = try t.transExpr(scope, case_stmt.start, .used);
                    const end_node = try t.transExpr(scope, end, .used);

                    break :blk try ZigTag.ellipsis3.create(t.arena, .{ .lhs = start_node, .rhs = end_node });
                } else try t.transExpr(scope, case_stmt.start, .used);

                try items.append(t.gpa, expr);
                sub = case_stmt.body;
            },
            else => return sub,
        }
    }
}

/// Collects all statements seen by this case into a block.
/// Avoids creating a block if the first statement is a break or return.
fn transSwitchProngStmt(
    t: *Translator,
    scope: *Scope,
    stmt: Node.Index,
    body: []const Node.Index,
) TransError!ZigNode {
    switch (stmt.get(t.tree)) {
        .break_stmt => return ZigTag.@"break".init(),
        .return_stmt => return t.transStmt(scope, stmt),
        .case_stmt, .default_stmt => unreachable,
        else => {
            var block_scope = try Scope.Block.init(t, scope, false);
            defer block_scope.deinit();

            // we do not need to translate `stmt` since it is the first stmt of `body`
            try t.transSwitchProngStmtInline(&block_scope, body);
            return try block_scope.complete();
        },
    }
}

/// Collects all statements seen by this case into a block.
fn transSwitchProngStmtInline(
    t: *Translator,
    block: *Scope.Block,
    body: []const Node.Index,
) TransError!void {
    for (body) |stmt| {
        switch (stmt.get(t.tree)) {
            .return_stmt => {
                const result = try t.transStmt(&block.base, stmt);
                try block.statements.append(t.gpa, result);
                return;
            },
            .break_stmt => {
                try block.statements.append(t.gpa, ZigTag.@"break".init());
                return;
            },
            .case_stmt => |case_stmt| {
                var sub = case_stmt.body;
                while (true) switch (sub.get(t.tree)) {
                    .case_stmt => |sub_case| sub = sub_case.body,
                    .default_stmt => |sub_default| sub = sub_default.body,
                    else => break,
                };
                const result = try t.transStmt(&block.base, sub);
                assert(result.tag() != .declaration);
                try block.statements.append(t.gpa, result);
                if (result.isNoreturn(true)) return;
            },
            .default_stmt => |default_stmt| {
                var sub = default_stmt.body;
                while (true) switch (sub.get(t.tree)) {
                    .case_stmt => |sub_case| sub = sub_case.body,
                    .default_stmt => |sub_default| sub = sub_default.body,
                    else => break,
                };
                const result = try t.transStmt(&block.base, sub);
                assert(result.tag() != .declaration);
                try block.statements.append(t.gpa, result);
                if (result.isNoreturn(true)) return;
            },
            .compound_stmt => |compound_stmt| {
                const result = try t.transCompoundStmt(&block.base, compound_stmt);
                try block.statements.append(t.gpa, result);
                if (result.isNoreturn(true)) return;
            },
            else => {
                const result = try t.transStmt(&block.base, stmt);
                switch (result.tag()) {
                    .declaration, .empty_block => {},
                    else => try block.statements.append(t.gpa, result),
                }
            },
        }
    }
}

// ======================
// Expression translation
// ======================

const ResultUsed = enum { used, unused };

fn transExpr(t: *Translator, scope: *Scope, expr: Node.Index, used: ResultUsed) TransError!ZigNode {
    const qt = expr.qt(t.tree);
    return t.maybeSuppressResult(used, switch (expr.get(t.tree)) {
        .paren_expr => |paren_expr| {
            return t.transExpr(scope, paren_expr.operand, used);
        },
        .cast => |cast| return t.transCastExpr(scope, cast, cast.qt, used, .with_as),
        .decl_ref_expr => |decl_ref| try t.transDeclRefExpr(scope, decl_ref),
        .enumeration_ref => |enum_ref| try t.transDeclRefExpr(scope, enum_ref),
        .addr_of_expr => |addr_of_expr| try ZigTag.address_of.create(t.arena, try t.transExpr(scope, addr_of_expr.operand, .used)),
        .deref_expr => |deref_expr| res: {
            if (t.typeWasDemotedToOpaque(qt))
                return t.fail(error.UnsupportedTranslation, deref_expr.op_tok, "cannot dereference opaque type", .{});

            // Dereferencing a function pointer is a no-op.
            if (qt.is(t.comp, .func)) return t.transExpr(scope, deref_expr.operand, used);

            break :res try ZigTag.deref.create(t.arena, try t.transExpr(scope, deref_expr.operand, .used));
        },
        .bool_not_expr => |bool_not_expr| try ZigTag.not.create(t.arena, try t.transBoolExpr(scope, bool_not_expr.operand)),
        .bit_not_expr => |bit_not_expr| try ZigTag.bit_not.create(t.arena, try t.transExpr(scope, bit_not_expr.operand, .used)),
        .plus_expr => |plus_expr| return t.transExpr(scope, plus_expr.operand, used),
        .negate_expr => |negate_expr| res: {
            const operand_qt = negate_expr.operand.qt(t.tree);
            if (!t.typeHasWrappingOverflow(operand_qt)) {
                const sub_expr_node = try t.transExpr(scope, negate_expr.operand, .used);
                const to_negate = if (sub_expr_node.isBoolRes()) blk: {
                    const ty_node = try ZigTag.type.create(t.arena, "c_int");
                    const int_node = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
                    break :blk try ZigTag.as.create(t.arena, .{ .lhs = ty_node, .rhs = int_node });
                } else sub_expr_node;

                break :res try ZigTag.negate.create(t.arena, to_negate);
            } else if (t.signedness(operand_qt) == .unsigned) {
                // use -% x for unsigned integers
                break :res try ZigTag.negate_wrap.create(t.arena, try t.transExpr(scope, negate_expr.operand, .used));
            } else return t.fail(error.UnsupportedTranslation, negate_expr.op_tok, "C negation with non float non integer", .{});
        },
        .div_expr => |div_expr| res: {
            if (qt.isInt(t.comp) and t.signedness(qt) == .signed) {
                // signed integer division uses @divTrunc
                const lhs = try t.transExpr(scope, div_expr.lhs, .used);
                const rhs = try t.transExpr(scope, div_expr.rhs, .used);
                break :res try ZigTag.div_trunc.create(t.arena, .{ .lhs = lhs, .rhs = rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, div_expr, .div);
        },
        .mod_expr => |mod_expr| res: {
            if (qt.isInt(t.comp) and t.signedness(qt) == .signed) {
                // signed integer remainder uses __helpers.signedRemainder
                const lhs = try t.transExpr(scope, mod_expr.lhs, .used);
                const rhs = try t.transExpr(scope, mod_expr.rhs, .used);
                break :res try t.createHelperCallNode(.signedRemainder, &.{ lhs, rhs });
            }
            // unsigned/float division uses the operator
            break :res try t.transBinExpr(scope, mod_expr, .mod);
        },
        .add_expr => |add_expr| res: {
            // `ptr + idx` and `idx + ptr` -> ptr + @as(usize, @bitCast(@as(isize, @intCast(idx))))
            const lhs_qt = add_expr.lhs.qt(t.tree);
            const rhs_qt = add_expr.rhs.qt(t.tree);
            if (qt.isPointer(t.comp) and (t.signedness(lhs_qt) == .signed or
                t.signedness(rhs_qt) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, add_expr, .add);
            }

            if (t.signedness(qt) == .unsigned) {
                break :res try t.transBinExpr(scope, add_expr, .add_wrap);
            } else {
                break :res try t.transBinExpr(scope, add_expr, .add);
            }
        },
        .sub_expr => |sub_expr| res: {
            // `ptr - idx` -> ptr - @as(usize, @bitCast(@as(isize, @intCast(idx))))
            const lhs_qt = sub_expr.lhs.qt(t.tree);
            const rhs_qt = sub_expr.rhs.qt(t.tree);
            if (qt.isPointer(t.comp) and (t.signedness(lhs_qt) == .signed or
                t.signedness(rhs_qt) == .signed))
            {
                break :res try t.transPointerArithmeticSignedOp(scope, sub_expr, .sub);
            }

            if (sub_expr.lhs.qt(t.tree).isPointer(t.comp) and sub_expr.rhs.qt(t.tree).isPointer(t.comp)) {
                break :res try t.transPtrDiffExpr(scope, sub_expr);
            } else if (t.signedness(qt) == .unsigned) {
                break :res try t.transBinExpr(scope, sub_expr, .sub_wrap);
            } else {
                break :res try t.transBinExpr(scope, sub_expr, .sub);
            }
        },
        .mul_expr => |mul_expr| if (t.signedness(qt) == .unsigned)
            try t.transBinExpr(scope, mul_expr, .mul_wrap)
        else
            try t.transBinExpr(scope, mul_expr, .mul),

        .less_than_expr => |lt| try t.transBinExpr(scope, lt, .less_than),
        .greater_than_expr => |gt| try t.transBinExpr(scope, gt, .greater_than),
        .less_than_equal_expr => |lte| try t.transBinExpr(scope, lte, .less_than_equal),
        .greater_than_equal_expr => |gte| try t.transBinExpr(scope, gte, .greater_than_equal),
        .equal_expr => |equal_expr| try t.transBinExpr(scope, equal_expr, .equal),
        .not_equal_expr => |not_equal_expr| try t.transBinExpr(scope, not_equal_expr, .not_equal),

        .bool_and_expr => |bool_and_expr| try t.transBoolBinExpr(scope, bool_and_expr, .@"and"),
        .bool_or_expr => |bool_or_expr| try t.transBoolBinExpr(scope, bool_or_expr, .@"or"),

        .bit_and_expr => |bit_and_expr| try t.transBinExpr(scope, bit_and_expr, .bit_and),
        .bit_or_expr => |bit_or_expr| try t.transBinExpr(scope, bit_or_expr, .bit_or),
        .bit_xor_expr => |bit_xor_expr| try t.transBinExpr(scope, bit_xor_expr, .bit_xor),

        .shl_expr => |shl_expr| try t.transShiftExpr(scope, shl_expr, .shl),
        .shr_expr => |shr_expr| try t.transShiftExpr(scope, shr_expr, .shr),

        .member_access_expr => |member_access| try t.transMemberAccess(scope, .normal, member_access, null),
        .member_access_ptr_expr => |member_access| try t.transMemberAccess(scope, .ptr, member_access, null),
        .array_access_expr => |array_access| try t.transArrayAccess(scope, array_access, null),

        .builtin_ref => unreachable,
        .builtin_call_expr => |call| return t.transBuiltinCall(scope, call, used),
        .call_expr => |call| return t.transCall(scope, call, used),

        .builtin_types_compatible_p => |compatible| blk: {
            const lhs = try t.transType(scope, compatible.lhs, compatible.builtin_tok);
            const rhs = try t.transType(scope, compatible.rhs, compatible.builtin_tok);

            break :blk try ZigTag.equal.create(t.arena, .{
                .lhs = lhs,
                .rhs = rhs,
            });
        },
        .builtin_choose_expr => |choose| return t.transCondExpr(scope, choose, used),
        .cond_expr => |cond_expr| return t.transCondExpr(scope, cond_expr, used),
        .binary_cond_expr => |conditional| return t.transBinaryCondExpr(scope, conditional, used),
        .cond_dummy_expr => unreachable,

        .assign_expr => |assign| return t.transAssignExpr(scope, assign, used),
        .add_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .sub_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .mul_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .div_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .mod_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .shl_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .shr_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .bit_and_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .bit_xor_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .bit_or_assign_expr => |assign| return t.transCompoundAssign(scope, assign, used),
        .compound_assign_dummy_expr => {
            assert(used == .used);
            return t.compound_assign_dummy.?;
        },

        .comma_expr => |comma_expr| return t.transCommaExpr(scope, comma_expr, used),
        .pre_inc_expr => |un| return t.transIncDecExpr(scope, un, .pre, .inc, used),
        .pre_dec_expr => |un| return t.transIncDecExpr(scope, un, .pre, .dec, used),
        .post_inc_expr => |un| return t.transIncDecExpr(scope, un, .post, .inc, used),
        .post_dec_expr => |un| return t.transIncDecExpr(scope, un, .post, .dec, used),

        .int_literal => return t.transIntLiteral(scope, expr, used, .with_as),
        .char_literal => return t.transCharLiteral(scope, expr, used, .with_as),
        .float_literal => return t.transFloatLiteral(scope, expr, used, .with_as),
        .string_literal_expr => |literal| try t.transStringLiteral(scope, expr, literal),
        .bool_literal => res: {
            const val = t.tree.value_map.get(expr).?;
            break :res if (val.toBool(t.comp))
                ZigTag.true_literal.init()
            else
                ZigTag.false_literal.init();
        },
        .nullptr_literal => ZigTag.null_literal.init(),
        .imaginary_literal => |literal| {
            return t.fail(error.UnsupportedTranslation, literal.op_tok, "TODO complex numbers", .{});
        },
        .compound_literal_expr => |literal| return t.transCompoundLiteral(scope, literal, used),

        .default_init_expr => |default_init| return t.transDefaultInit(scope, default_init, used, .with_as),
        .array_init_expr => |array_init| return t.transArrayInit(scope, array_init, used),
        .union_init_expr => |union_init| return t.transUnionInit(scope, union_init, used),
        .struct_init_expr => |struct_init| return t.transStructInit(scope, struct_init, used),
        .array_filler_expr => unreachable,

        .sizeof_expr => |sizeof| try t.transTypeInfo(scope, .sizeof, sizeof),
        .alignof_expr => |alignof| try t.transTypeInfo(scope, .alignof, alignof),

        .imag_expr, .real_expr => |un| {
            return t.fail(error.UnsupportedTranslation, un.op_tok, "TODO complex numbers", .{});
        },
        .addr_of_label => |addr_of_label| {
            return t.fail(error.UnsupportedTranslation, addr_of_label.label_tok, "TODO computed goto", .{});
        },

        .generic_expr => |generic| return t.transExpr(scope, generic.chosen, used),
        .generic_association_expr => |generic| return t.transExpr(scope, generic.expr, used),
        .generic_default_expr => |generic| return t.transExpr(scope, generic.expr, used),

        .stmt_expr => |stmt_expr| return t.transStmtExpr(scope, stmt_expr, used),

        .builtin_convertvector => |convertvector| try t.transConvertvectorExpr(scope, convertvector),
        .builtin_shufflevector => |shufflevector| try t.transShufflevectorExpr(scope, shufflevector),

        .compound_stmt,
        .static_assert,
        .return_stmt,
        .null_stmt,
        .if_stmt,
        .while_stmt,
        .do_while_stmt,
        .for_stmt,
        .continue_stmt,
        .break_stmt,
        .labeled_stmt,
        .switch_stmt,
        .case_stmt,
        .default_stmt,
        .goto_stmt,
        .computed_goto_stmt,
        .gnu_asm_simple,
        .global_asm,
        .typedef,
        .struct_decl,
        .union_decl,
        .enum_decl,
        .function,
        .param,
        .variable,
        .enum_field,
        .record_field,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        .empty_decl,
        => unreachable, // not an expression
    });
}

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(t: *Translator, scope: *Scope, expr: Node.Index, used: ResultUsed) TransError!ZigNode {
    switch (expr.get(t.tree)) {
        .int_literal => return t.transIntLiteral(scope, expr, used, .no_as),
        .char_literal => return t.transCharLiteral(scope, expr, used, .no_as),
        .float_literal => return t.transFloatLiteral(scope, expr, used, .no_as),
        .cast => |cast| switch (cast.kind) {
            .no_op => {
                const operand = cast.operand.get(t.tree);
                if (operand == .cast) {
                    return t.transCastExpr(scope, operand.cast, cast.qt, used, .no_as);
                }
                return t.transExprCoercing(scope, cast.operand, used);
            },
            .lval_to_rval => return t.transExprCoercing(scope, cast.operand, used),
            else => return t.transCastExpr(scope, cast, cast.qt, used, .no_as),
        },
        .default_init_expr => |default_init| return try t.transDefaultInit(scope, default_init, used, .no_as),
        .compound_literal_expr => |literal| {
            if (!literal.thread_local and literal.storage_class != .static) {
                return t.transExprCoercing(scope, literal.initializer, used);
            }
        },
        else => {},
    }

    return t.transExpr(scope, expr, used);
}

fn transBoolExpr(t: *Translator, scope: *Scope, expr: Node.Index) TransError!ZigNode {
    switch (expr.get(t.tree)) {
        .int_literal => {
            const int_val = t.tree.value_map.get(expr).?;
            return if (int_val.isZero(t.comp))
                ZigTag.false_literal.init()
            else
                ZigTag.true_literal.init();
        },
        .cast => |cast| switch (cast.kind) {
            .bool_to_int => return t.transExpr(scope, cast.operand, .used),
            .array_to_pointer => {
                const operand = cast.operand.get(t.tree);
                if (operand == .string_literal_expr) {
                    // @intFromPtr("foo") != 0, always true
                    const str = try t.transStringLiteral(scope, cast.operand, operand.string_literal_expr);
                    const int_from_ptr = try ZigTag.int_from_ptr.create(t.arena, str);
                    return ZigTag.not_equal.create(t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
                }
            },
            else => {},
        },
        else => {},
    }

    const maybe_bool_res = try t.transExpr(scope, expr, .used);
    if (maybe_bool_res.isBoolRes()) {
        return maybe_bool_res;
    }

    return t.finishBoolExpr(expr.qt(t.tree), maybe_bool_res);
}

fn finishBoolExpr(t: *Translator, qt: QualType, node: ZigNode) TransError!ZigNode {
    const sk = qt.scalarKind(t.comp);
    if (sk == .bool) return node;
    if (sk == .nullptr_t) {
        // node == null, always true
        return ZigTag.equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (sk.isPointer()) {
        // node != null
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.null_literal.init() });
    }
    if (sk != .none) {
        // node != 0
        return ZigTag.not_equal.create(t.arena, .{ .lhs = node, .rhs = ZigTag.zero_literal.init() });
    }
    unreachable; // Unexpected bool expression type
}

fn transCastExpr(
    t: *Translator,
    scope: *Scope,
    cast: Node.Cast,
    dest_qt: QualType,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const operand = switch (cast.kind) {
        .no_op => {
            const operand = cast.operand.get(t.tree);
            if (operand == .cast) {
                return t.transCastExpr(scope, operand.cast, cast.qt, used, suppress_as);
            }
            return t.transExpr(scope, cast.operand, used);
        },
        .lval_to_rval, .function_to_pointer => {
            return t.transExpr(scope, cast.operand, used);
        },
        .int_cast => int_cast: {
            const src_qt = cast.operand.qt(t.tree);

            if (cast.implicit) {
                if (t.tree.value_map.get(cast.operand)) |val| {
                    const max_int = try aro.Value.maxInt(dest_qt, t.comp);
                    const min_int = try aro.Value.minInt(dest_qt, t.comp);

                    if (val.compare(.lte, max_int, t.comp) and val.compare(.gte, min_int, t.comp)) {
                        break :int_cast try t.transExprCoercing(scope, cast.operand, .used);
                    }
                }
            }
            const operand = try t.transExpr(scope, cast.operand, .used);
            break :int_cast try t.transIntCast(operand, src_qt, dest_qt);
        },
        .to_void => {
            assert(used == .unused);
            return try t.transExpr(scope, cast.operand, .unused);
        },
        .null_to_pointer => ZigTag.null_literal.init(),
        .array_to_pointer => array_to_pointer: {
            const child_qt = dest_qt.childType(t.comp);

            loop: switch (cast.operand.get(t.tree)) {
                .string_literal_expr => |literal| {
                    const sub_expr_node = try t.transExpr(scope, cast.operand, .used);

                    const ref = if (literal.kind == .utf8 or literal.kind == .ascii)
                        sub_expr_node
                    else
                        try ZigTag.address_of.create(t.arena, sub_expr_node);

                    const casted = if (child_qt.@"const")
                        ref
                    else
                        try ZigTag.const_cast.create(t.arena, sub_expr_node);

                    return t.maybeSuppressResult(used, casted);
                },
                .paren_expr => |paren_expr| {
                    continue :loop paren_expr.operand.get(t.tree);
                },
                .generic_expr => |generic| {
                    continue :loop generic.chosen.get(t.tree);
                },
                .generic_association_expr => |generic| {
                    continue :loop generic.expr.get(t.tree);
                },
                .generic_default_expr => |generic| {
                    continue :loop generic.expr.get(t.tree);
                },
                else => {},
            }

            if (cast.operand.qt(t.tree).arrayLen(t.comp) == null) {
                return try t.transExpr(scope, cast.operand, used);
            }

            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            const ref = try ZigTag.address_of.create(t.arena, sub_expr_node);
            const align_cast = try ZigTag.align_cast.create(t.arena, ref);
            break :array_to_pointer try ZigTag.ptr_cast.create(t.arena, align_cast);
        },
        .int_to_pointer => int_to_pointer: {
            var sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            const operand_qt = cast.operand.qt(t.tree);
            if (t.signedness(operand_qt) == .signed or operand_qt.bitSizeof(t.comp) > t.comp.target.ptrBitWidth()) {
                sub_expr_node = try ZigTag.as.create(t.arena, .{
                    .lhs = try ZigTag.type.create(t.arena, "usize"),
                    .rhs = try ZigTag.int_cast.create(t.arena, sub_expr_node),
                });
            }
            break :int_to_pointer try ZigTag.ptr_from_int.create(t.arena, sub_expr_node);
        },
        .int_to_bool => {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            if (sub_expr_node.isBoolRes()) return sub_expr_node;
            if (cast.operand.qt(t.tree).is(t.comp, .bool)) return sub_expr_node;
            const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.zero_literal.init() });
            return t.maybeSuppressResult(used, cmp_node);
        },
        .float_to_bool => {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.zero_literal.init() });
            return t.maybeSuppressResult(used, cmp_node);
        },
        .pointer_to_bool => {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);

            // Special case function pointers as @intFromPtr(expr) != 0
            if (cast.operand.qt(t.tree).get(t.comp, .pointer)) |ptr_ty| if (ptr_ty.child.is(t.comp, .func)) {
                const ptr_node = if (sub_expr_node.tag() == .identifier)
                    try ZigTag.address_of.create(t.arena, sub_expr_node)
                else
                    sub_expr_node;
                const int_from_ptr = try ZigTag.int_from_ptr.create(t.arena, ptr_node);
                const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
                return t.maybeSuppressResult(used, cmp_node);
            };

            const cmp_node = try ZigTag.not_equal.create(t.arena, .{ .lhs = sub_expr_node, .rhs = ZigTag.null_literal.init() });
            return t.maybeSuppressResult(used, cmp_node);
        },
        .bool_to_int => bool_to_int: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            break :bool_to_int try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
        },
        .bool_to_float => bool_to_float: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            const int_from_bool = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
            break :bool_to_float try ZigTag.float_from_int.create(t.arena, int_from_bool);
        },
        .bool_to_pointer => bool_to_pointer: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            const int_from_bool = try ZigTag.int_from_bool.create(t.arena, sub_expr_node);
            break :bool_to_pointer try ZigTag.ptr_from_int.create(t.arena, int_from_bool);
        },
        .float_cast => float_cast: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            break :float_cast try ZigTag.float_cast.create(t.arena, sub_expr_node);
        },
        .int_to_float => int_to_float: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, used);
            const int_node = if (sub_expr_node.isBoolRes())
                try ZigTag.int_from_bool.create(t.arena, sub_expr_node)
            else
                sub_expr_node;
            break :int_to_float try ZigTag.float_from_int.create(t.arena, int_node);
        },
        .float_to_int => float_to_int: {
            const sub_expr_node = try t.transExpr(scope, cast.operand, .used);
            break :float_to_int try ZigTag.int_from_float.create(t.arena, sub_expr_node);
        },
        .pointer_to_int => pointer_to_int: {
            const sub_expr_node = try t.transPointerCastExpr(scope, cast.operand);
            const ptr_node = try ZigTag.int_from_ptr.create(t.arena, sub_expr_node);
            break :pointer_to_int try ZigTag.int_cast.create(t.arena, ptr_node);
        },
        .bitcast => bitcast: {
            const sub_expr_node = try t.transPointerCastExpr(scope, cast.operand);
            const operand_qt = cast.operand.qt(t.tree);
            if (dest_qt.isPointer(t.comp) and operand_qt.isPointer(t.comp)) {
                var casted = try ZigTag.align_cast.create(t.arena, sub_expr_node);
                casted = try ZigTag.ptr_cast.create(t.arena, casted);

                const src_elem = operand_qt.childType(t.comp);
                const dest_elem = dest_qt.childType(t.comp);
                if ((src_elem.@"const" or src_elem.is(t.comp, .func)) and !dest_elem.@"const") {
                    casted = try ZigTag.const_cast.create(t.arena, casted);
                }
                if (src_elem.@"volatile" and !dest_elem.@"volatile") {
                    casted = try ZigTag.volatile_cast.create(t.arena, casted);
                }
                break :bitcast casted;
            }

            break :bitcast try ZigTag.bit_cast.create(t.arena, sub_expr_node);
        },
        .union_cast => union_cast: {
            const union_type = try t.transType(scope, dest_qt, cast.l_paren);

            const operand_qt = cast.operand.qt(t.tree);
            const union_base = dest_qt.base(t.comp);
            const field = for (union_base.type.@"union".fields) |field| {
                if (field.qt.eql(operand_qt, t.comp)) break field;
            } else unreachable;
            const field_name = if (field.name_tok == 0) t.anonymous_record_field_names.get(.{
                .parent = union_base.qt,
                .field = field.qt,
            }).? else field.name.lookup(t.comp);

            const field_init = try t.arena.create(ast.Payload.ContainerInit.Initializer);
            field_init.* = .{
                .name = field_name,
                .value = try t.transExpr(scope, cast.operand, .used),
            };
            break :union_cast try ZigTag.container_init.create(t.arena, .{
                .lhs = union_type,
                .inits = field_init[0..1],
            });
        },
        else => return t.fail(error.UnsupportedTranslation, cast.l_paren, "TODO translate {s} cast", .{@tagName(cast.kind)}),
    };
    if (suppress_as == .no_as) return t.maybeSuppressResult(used, operand);
    if (used == .unused) return t.maybeSuppressResult(used, operand);
    const as = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, dest_qt, cast.l_paren),
        .rhs = operand,
    });
    return as;
}

fn transIntCast(t: *Translator, operand: ZigNode, src_qt: QualType, dest_qt: QualType) !ZigNode {
    const src_dest_order = src_qt.intRankOrder(dest_qt, t.comp);
    const different_sign = t.signedness(src_qt) != t.signedness(dest_qt);
    const needs_bitcast = different_sign and !(t.signedness(src_qt) == .unsigned and src_dest_order == .lt);

    var casted = operand;
    if (casted.isBoolRes()) {
        casted = try ZigTag.int_from_bool.create(t.arena, casted);
    } else if (src_dest_order == .gt) {
        // No C type is smaller than the 1 bit from @intFromBool
        casted = try ZigTag.truncate.create(t.arena, casted);
    }
    if (needs_bitcast) {
        if (src_dest_order != .eq) {
            casted = try ZigTag.as.create(t.arena, .{
                .lhs = try t.transTypeIntWidthOf(dest_qt, t.signedness(src_qt) == .signed),
                .rhs = casted,
            });
        }
        return ZigTag.bit_cast.create(t.arena, casted);
    }
    return casted;
}

/// Same as `transExpr` but adds a `&` if the expression is an identifier referencing a function type.
fn transPointerCastExpr(t: *Translator, scope: *Scope, expr: Node.Index) TransError!ZigNode {
    const sub_expr_node = try t.transExpr(scope, expr, .used);
    switch (expr.get(t.tree)) {
        .cast => |cast| if (cast.kind == .function_to_pointer and sub_expr_node.tag() == .identifier) {
            return ZigTag.address_of.create(t.arena, sub_expr_node);
        },
        else => {},
    }
    return sub_expr_node;
}

fn transDeclRefExpr(t: *Translator, scope: *Scope, decl_ref: Node.DeclRef) TransError!ZigNode {
    const name = t.tree.tokSlice(decl_ref.name_tok);
    const maybe_alias = scope.getAlias(name);
    const mangled_name = maybe_alias orelse name;

    switch (decl_ref.decl.get(t.tree)) {
        .function => |function| if (function.definition == null and function.body == null) {
            // Try translating the decl again in case of out of scope declaration.
            try t.transFnDecl(scope, function);
        },
        else => {},
    }

    const decl = decl_ref.decl.get(t.tree);
    const ref_expr = blk: {
        const identifier = try ZigTag.identifier.create(t.arena, mangled_name);
        if (decl_ref.qt.is(t.comp, .func) and maybe_alias != null) {
            break :blk try ZigTag.field_access.create(t.arena, .{
                .lhs = identifier,
                .field_name = name,
            });
        }
        if (decl == .variable and maybe_alias != null) {
            switch (decl.variable.storage_class) {
                .@"extern", .static => {
                    break :blk try ZigTag.field_access.create(t.arena, .{
                        .lhs = identifier,
                        .field_name = name,
                    });
                },
                else => {},
            }
        }
        break :blk identifier;
    };

    scope.skipVariableDiscard(mangled_name);
    return ref_expr;
}

fn transBinExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) TransError!ZigNode {
    const lhs_uncasted = try t.transExpr(scope, bin.lhs, .used);
    const rhs_uncasted = try t.transExpr(scope, bin.rhs, .used);

    const lhs = if (lhs_uncasted.isBoolRes())
        try ZigTag.int_from_bool.create(t.arena, lhs_uncasted)
    else
        lhs_uncasted;

    const rhs = if (rhs_uncasted.isBoolRes())
        try ZigTag.int_from_bool.create(t.arena, rhs_uncasted)
    else
        rhs_uncasted;

    return t.createBinOpNode(op_id, lhs, rhs);
}

fn transBoolBinExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op: ZigTag) !ZigNode {
    std.debug.assert(op == .@"and" or op == .@"or");

    const lhs = try t.transBoolExpr(scope, bin.lhs);
    const rhs = try t.transBoolExpr(scope, bin.rhs);

    return t.createBinOpNode(op, lhs, rhs);
}

fn transShiftExpr(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) !ZigNode {
    std.debug.assert(op_id == .shl or op_id == .shr);

    // lhs >> @intCast(rh)
    const lhs = try t.transExpr(scope, bin.lhs, .used);

    const rhs = try t.transExprCoercing(scope, bin.rhs, .used);
    const rhs_casted = try ZigTag.int_cast.create(t.arena, rhs);

    return t.createBinOpNode(op_id, lhs, rhs_casted);
}

fn transCondExpr(
    t: *Translator,
    scope: *Scope,
    conditional: Node.Conditional,
    used: ResultUsed,
) TransError!ZigNode {
    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = scope,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const res_is_bool = conditional.qt.is(t.comp, .bool);
    const cond = try t.transBoolExpr(&cond_scope.base, conditional.cond);

    var then_body = try t.transExpr(scope, conditional.then_expr, used);
    if (!res_is_bool and then_body.isBoolRes()) {
        then_body = try ZigTag.int_from_bool.create(t.arena, then_body);
    }

    var else_body = try t.transExpr(scope, conditional.else_expr, used);
    if (!res_is_bool and else_body.isBoolRes()) {
        else_body = try ZigTag.int_from_bool.create(t.arena, else_body);
    }

    // The `ResultUsed` is forwarded to both branches so no need to suppress the result here.
    return ZigTag.@"if".create(t.arena, .{ .cond = cond, .then = then_body, .@"else" = else_body });
}

fn transBinaryCondExpr(
    t: *Translator,
    scope: *Scope,
    conditional: Node.Conditional,
    used: ResultUsed,
) TransError!ZigNode {
    // GNU extension of the ternary operator where the middle expression is
    // omitted, the condition itself is returned if it evaluates to true.

    if (used == .unused) {
        // Result unused so this can be translated as
        // if (condition) else_expr;
        var cond_scope: Scope.Condition = .{
            .base = .{
                .parent = scope,
                .id = .condition,
            },
        };
        defer cond_scope.deinit();

        return ZigTag.@"if".create(t.arena, .{
            .cond = try t.transBoolExpr(&cond_scope.base, conditional.cond),
            .then = try t.transExpr(scope, conditional.else_expr, .unused),
            .@"else" = null,
        });
    }

    const res_is_bool = conditional.qt.is(t.comp, .bool);
    // c:   (condition)?:(else_expr)
    // zig: (blk: {
    //          const _cond_temp = (condition);
    //          break :blk if (_cond_temp) _cond_temp else (else_expr);
    //      })
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const cond_temp = try block_scope.reserveMangledName("cond_temp");
    const init_node = try t.transExpr(&block_scope.base, conditional.cond, .used);
    const temp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = cond_temp, .init = init_node });
    try block_scope.statements.append(t.gpa, temp_decl);

    var cond_scope: Scope.Condition = .{
        .base = .{
            .parent = &block_scope.base,
            .id = .condition,
        },
    };
    defer cond_scope.deinit();

    const cond_ident = try ZigTag.identifier.create(t.arena, cond_temp);
    const cond_node = try t.finishBoolExpr(conditional.cond.qt(t.tree), cond_ident);
    var then_body = cond_ident;
    if (!res_is_bool and init_node.isBoolRes()) {
        then_body = try ZigTag.int_from_bool.create(t.arena, then_body);
    }

    var else_body = try t.transExpr(&block_scope.base, conditional.else_expr, .used);
    if (!res_is_bool and else_body.isBoolRes()) {
        else_body = try ZigTag.int_from_bool.create(t.arena, else_body);
    }
    const if_node = try ZigTag.@"if".create(t.arena, .{
        .cond = cond_node,
        .then = then_body,
        .@"else" = else_body,
    });
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = if_node,
    });
    try block_scope.statements.append(t.gpa, break_node);
    return block_scope.complete();
}

fn transCommaExpr(t: *Translator, scope: *Scope, bin: Node.Binary, used: ResultUsed) TransError!ZigNode {
    if (used == .unused) {
        const lhs = try t.transExprCoercing(scope, bin.lhs, .unused);
        try scope.appendNode(lhs);
        const rhs = try t.transExprCoercing(scope, bin.rhs, .unused);
        return rhs;
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const lhs = try t.transExprCoercing(&block_scope.base, bin.lhs, .unused);
    try block_scope.statements.append(t.gpa, lhs);

    const rhs = try t.transExprCoercing(&block_scope.base, bin.rhs, .used);
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = rhs,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return try block_scope.complete();
}

fn transAssignExpr(t: *Translator, scope: *Scope, bin: Node.Binary, used: ResultUsed) !ZigNode {
    if (used == .unused) {
        const lhs = try t.transExpr(scope, bin.lhs, .used);
        var rhs = try t.transExprCoercing(scope, bin.rhs, .used);

        const lhs_qt = bin.lhs.qt(t.tree);
        if (rhs.isBoolRes() and !lhs_qt.is(t.comp, .bool)) {
            rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
        }

        return t.createBinOpNode(.assign, lhs, rhs);
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.reserveMangledName("tmp");

    var rhs = try t.transExpr(&block_scope.base, bin.rhs, .used);
    const lhs_qt = bin.lhs.qt(t.tree);
    if (rhs.isBoolRes() and !lhs_qt.is(t.comp, .bool)) {
        rhs = try ZigTag.int_from_bool.create(t.arena, rhs);
    }

    const tmp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = tmp, .init = rhs });
    try block_scope.statements.append(t.gpa, tmp_decl);

    const lhs = try t.transExprCoercing(&block_scope.base, bin.lhs, .used);
    const tmp_ident = try ZigTag.identifier.create(t.arena, tmp);

    const assign = try t.createBinOpNode(.assign, lhs, tmp_ident);
    try block_scope.statements.append(t.gpa, assign);

    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = tmp_ident,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return try block_scope.complete();
}

fn transCompoundAssign(
    t: *Translator,
    scope: *Scope,
    assign: Node.Binary,
    used: ResultUsed,
) !ZigNode {
    // If the result is unused we can try using the equivalent Zig operator
    // without a block
    if (used == .unused) {
        if (try t.transCompoundAssignSimple(scope, null, assign)) |some| {
            return some;
        }
    }

    // Otherwise we need to wrap the the compound assignment in a block.
    var block_scope = try Scope.Block.init(t, scope, used == .used);
    defer block_scope.deinit();
    const ref = try block_scope.reserveMangledName("ref");

    const lhs_expr = try t.transExpr(&block_scope.base, assign.lhs, .used);
    const addr_of = try ZigTag.address_of.create(t.arena, lhs_expr);
    const ref_decl = try ZigTag.var_simple.create(t.arena, .{ .name = ref, .init = addr_of });
    try block_scope.statements.append(t.gpa, ref_decl);

    const lhs_node = try ZigTag.identifier.create(t.arena, ref);
    const ref_node = try ZigTag.deref.create(t.arena, lhs_node);

    // Use the equivalent Zig operator if possible.
    if (try t.transCompoundAssignSimple(scope, ref_node, assign)) |some| {
        try block_scope.statements.append(t.gpa, some);
    } else {
        const old_dummy = t.compound_assign_dummy;
        defer t.compound_assign_dummy = old_dummy;
        t.compound_assign_dummy = ref_node;

        // Otherwise do the operation and assignment separately.
        const rhs_node = try t.transExprCoercing(&block_scope.base, assign.rhs, .used);
        const assign_node = try t.createBinOpNode(.assign, ref_node, rhs_node);
        try block_scope.statements.append(t.gpa, assign_node);
    }

    if (used == .used) {
        const break_node = try ZigTag.break_val.create(t.arena, .{
            .label = block_scope.label,
            .val = ref_node,
        });
        try block_scope.statements.append(t.gpa, break_node);
    }
    return block_scope.complete();
}

/// Translates compound assignment using the equivalent Zig operator if possible.
fn transCompoundAssignSimple(t: *Translator, scope: *Scope, lhs_dummy_opt: ?ZigNode, assign: Node.Binary) TransError!?ZigNode {
    const assign_rhs = assign.rhs.get(t.tree);
    if (assign_rhs == .cast) return null;

    const is_signed = t.signedness(assign.qt) == .signed;
    switch (assign_rhs) {
        .div_expr, .mod_expr => if (is_signed) return null,
        else => {},
    }
    const lhs_ptr = assign.qt.isPointer(t.comp);

    const bin, const op: ZigTag, const cast: enum { none, shift, usize } = switch (assign_rhs) {
        .add_expr => |bin| .{
            bin,
            if (t.typeHasWrappingOverflow(bin.qt)) .add_wrap_assign else .add_assign,
            if (lhs_ptr and t.signedness(bin.rhs.qt(t.tree)) == .signed) .usize else .none,
        },
        .sub_expr => |bin| .{
            bin,
            if (t.typeHasWrappingOverflow(bin.qt)) .sub_wrap_assign else .sub_assign,
            if (lhs_ptr and t.signedness(bin.rhs.qt(t.tree)) == .signed) .usize else .none,
        },
        .mul_expr => |bin| .{
            bin,
            if (t.typeHasWrappingOverflow(bin.qt)) .mul_wrap_assign else .mul_assign,
            .none,
        },
        .mod_expr => |bin| .{ bin, .mod_assign, .none },
        .div_expr => |bin| .{ bin, .div_assign, .none },
        .shl_expr => |bin| .{ bin, .shl_assign, .shift },
        .shr_expr => |bin| .{ bin, .shr_assign, .shift },
        .bit_and_expr => |bin| .{ bin, .bit_and_assign, .none },
        .bit_xor_expr => |bin| .{ bin, .bit_xor_assign, .none },
        .bit_or_expr => |bin| .{ bin, .bit_or_assign, .none },
        else => unreachable,
    };

    const lhs_node = blk: {
        const old_dummy = t.compound_assign_dummy;
        defer t.compound_assign_dummy = old_dummy;
        t.compound_assign_dummy = lhs_dummy_opt orelse try t.transExpr(scope, assign.lhs, .used);

        break :blk try t.transExpr(scope, bin.lhs, .used);
    };

    const rhs_node = try t.transExprCoercing(scope, bin.rhs, .used);
    const casted_rhs = switch (cast) {
        .none => rhs_node,
        .shift => try ZigTag.int_cast.create(t.arena, rhs_node),
        .usize => try t.usizeCastForWrappingPtrArithmetic(rhs_node),
    };
    return try t.createBinOpNode(op, lhs_node, casted_rhs);
}

fn transIncDecExpr(
    t: *Translator,
    scope: *Scope,
    un: Node.Unary,
    position: enum { pre, post },
    kind: enum { inc, dec },
    used: ResultUsed,
) !ZigNode {
    const is_wrapping = t.typeHasWrappingOverflow(un.qt);
    const op: ZigTag = switch (kind) {
        .inc => if (is_wrapping) .add_wrap_assign else .add_assign,
        .dec => if (is_wrapping) .sub_wrap_assign else .sub_assign,
    };

    const one_literal = ZigTag.one_literal.init();
    if (used == .unused) {
        const operand = try t.transExpr(scope, un.operand, .used);
        return try t.createBinOpNode(op, operand, one_literal);
    }

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const ref = try block_scope.reserveMangledName("ref");
    const operand = try t.transExprCoercing(&block_scope.base, un.operand, .used);
    const operand_ref = try ZigTag.address_of.create(t.arena, operand);
    const ref_decl = try ZigTag.var_simple.create(t.arena, .{ .name = ref, .init = operand_ref });
    try block_scope.statements.append(t.gpa, ref_decl);

    const ref_ident = try ZigTag.identifier.create(t.arena, ref);
    const ref_deref = try ZigTag.deref.create(t.arena, ref_ident);
    const effect = try t.createBinOpNode(op, ref_deref, one_literal);

    switch (position) {
        .pre => {
            try block_scope.statements.append(t.gpa, effect);

            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = ref_deref,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
        .post => {
            const tmp = try block_scope.reserveMangledName("tmp");
            const tmp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = tmp, .init = ref_deref });
            try block_scope.statements.append(t.gpa, tmp_decl);

            try block_scope.statements.append(t.gpa, effect);

            const tmp_ident = try ZigTag.identifier.create(t.arena, tmp);
            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = tmp_ident,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
    }

    return try block_scope.complete();
}

fn transPtrDiffExpr(t: *Translator, scope: *Scope, bin: Node.Binary) TransError!ZigNode {
    const lhs_uncasted = try t.transExpr(scope, bin.lhs, .used);
    const rhs_uncasted = try t.transExpr(scope, bin.rhs, .used);

    const lhs = try ZigTag.int_from_ptr.create(t.arena, lhs_uncasted);
    const rhs = try ZigTag.int_from_ptr.create(t.arena, rhs_uncasted);

    const sub_res = try t.createBinOpNode(.sub_wrap, lhs, rhs);

    // @divExact(@as(<platform-ptrdiff_t>, @bitCast(@intFromPtr(lhs)) -% @intFromPtr(rhs)), @sizeOf(<lhs target type>))
    const ptrdiff_type = try t.transTypeIntWidthOf(bin.qt, true);

    const bitcast = try ZigTag.as.create(t.arena, .{
        .lhs = ptrdiff_type,
        .rhs = try ZigTag.bit_cast.create(t.arena, sub_res),
    });

    // C standard requires that pointer subtraction operands are of the same type,
    // otherwise it is undefined behavior. So we can assume the left and right
    // sides are the same Type and arbitrarily choose left.
    const lhs_ty = try t.transType(scope, bin.lhs.qt(t.tree), bin.lhs.tok(t.tree));
    const c_pointer = t.getContainer(lhs_ty).?;

    if (c_pointer.castTag(.c_pointer)) |c_pointer_payload| {
        const sizeof = try ZigTag.sizeof.create(t.arena, c_pointer_payload.data.elem_type);
        return ZigTag.div_exact.create(t.arena, .{
            .lhs = bitcast,
            .rhs = sizeof,
        });
    } else {
        // This is an opaque/incomplete type. This subtraction exhibits Undefined Behavior by the C99 spec.
        // However, allowing subtraction on `void *` and function pointers is a commonly used extension.
        // So, just return the value in byte units, mirroring the behavior of this language extension as implemented by GCC and Clang.
        return bitcast;
    }
}

/// Translate an arithmetic expression with a pointer operand and a signed-integer operand.
/// Zig requires a usize argument for pointer arithmetic, so we intCast to isize and then
/// bitcast to usize; pointer wraparound makes the math work.
/// Zig pointer addition is not commutative (unlike C); the pointer operand needs to be on the left.
/// The + operator in C is not a sequence point so it should be safe to switch the order if necessary.
fn transPointerArithmeticSignedOp(t: *Translator, scope: *Scope, bin: Node.Binary, op_id: ZigTag) TransError!ZigNode {
    std.debug.assert(op_id == .add or op_id == .sub);

    const lhs_qt = bin.lhs.qt(t.tree);
    const swap_operands = op_id == .add and t.signedness(lhs_qt) == .signed;

    const swizzled_lhs = if (swap_operands) bin.rhs else bin.lhs;
    const swizzled_rhs = if (swap_operands) bin.lhs else bin.rhs;

    const lhs_node = try t.transExpr(scope, swizzled_lhs, .used);
    const rhs_node = try t.transExpr(scope, swizzled_rhs, .used);

    const bitcast_node = try t.usizeCastForWrappingPtrArithmetic(rhs_node);

    return t.createBinOpNode(op_id, lhs_node, bitcast_node);
}

fn transMemberAccess(
    t: *Translator,
    scope: *Scope,
    kind: enum { normal, ptr },
    member_access: Node.MemberAccess,
    opt_base: ?ZigNode,
) TransError!ZigNode {
    const base_info = switch (kind) {
        .normal => member_access.base.qt(t.tree),
        .ptr => member_access.base.qt(t.tree).childType(t.comp),
    };
    const record = base_info.getRecord(t.comp).?;
    const field = record.fields[member_access.member_index];
    const field_name = if (field.name_tok == 0) t.anonymous_record_field_names.get(.{
        .parent = base_info.base(t.comp).qt,
        .field = field.qt,
    }).? else field.name.lookup(t.comp);
    const base_node = opt_base orelse try t.transExpr(scope, member_access.base, .used);
    const lhs = switch (kind) {
        .normal => base_node,
        .ptr => try ZigTag.deref.create(t.arena, base_node),
    };
    const field_access = try ZigTag.field_access.create(t.arena, .{
        .lhs = lhs,
        .field_name = field_name,
    });

    // Flexible array members are translated as member functions.
    if (member_access.member_index == record.fields.len - 1 or base_info.base(t.comp).type == .@"union") {
        if (field.qt.get(t.comp, .array)) |array_ty| {
            if (array_ty.len == .incomplete or (array_ty.len == .fixed and array_ty.len.fixed == 0)) {
                return ZigTag.call.create(t.arena, .{ .lhs = field_access, .args = &.{} });
            }
        }
    }

    return field_access;
}

fn transArrayAccess(t: *Translator, scope: *Scope, array_access: Node.ArrayAccess, opt_base: ?ZigNode) TransError!ZigNode {
    // Unwrap the base statement if it's an array decayed to a bare pointer type
    // so that we index the array itself
    const base = base: {
        const base = array_access.base.get(t.tree);
        if (base != .cast) break :base array_access.base;
        if (base.cast.kind != .array_to_pointer) break :base array_access.base;
        break :base base.cast.operand;
    };

    const base_node = opt_base orelse try t.transExpr(scope, base, .used);
    const index = index: {
        const index = try t.transExpr(scope, array_access.index, .used);
        const index_qt = array_access.index.qt(t.tree);
        const maybe_bigger_than_usize = switch (index_qt.base(t.comp).type) {
            .bool => {
                break :index try ZigTag.int_from_bool.create(t.arena, index);
            },
            .int => |int| switch (int) {
                .long_long, .ulong_long, .int128, .uint128 => true,
                else => false,
            },
            .bit_int => |bit_int| bit_int.bits > t.comp.target.ptrBitWidth(),
            else => unreachable,
        };

        const is_nonnegative_int_literal = if (t.tree.value_map.get(array_access.index)) |val|
            val.compare(.gte, .zero, t.comp)
        else
            false;
        const is_signed = t.signedness(index_qt) == .signed;

        if (is_signed and !is_nonnegative_int_literal) {
            // First cast to `isize` to get proper sign extension and
            // then @bitCast to `usize` to satisfy the compiler.
            const index_isize = try ZigTag.as.create(t.arena, .{
                .lhs = try ZigTag.type.create(t.arena, "isize"),
                .rhs = try ZigTag.int_cast.create(t.arena, index),
            });
            break :index try ZigTag.bit_cast.create(t.arena, index_isize);
        }

        if (maybe_bigger_than_usize) {
            break :index try ZigTag.int_cast.create(t.arena, index);
        }
        break :index index;
    };

    return ZigTag.array_access.create(t.arena, .{
        .lhs = base_node,
        .rhs = index,
    });
}

fn transOffsetof(t: *Translator, scope: *Scope, arg: Node.Index) TransError!ZigNode {
    // Translate __builtin_offsetof(T, designator) as
    // @intFromPtr(&(@as(*allowzero T, @ptrFromInt(0)).designator))
    const member = try t.transMemberDesignator(scope, arg);
    const address = try ZigTag.address_of.create(t.arena, member);
    return ZigTag.int_from_ptr.create(t.arena, address);
}

fn transMemberDesignator(t: *Translator, scope: *Scope, arg: Node.Index) TransError!ZigNode {
    switch (arg.get(t.tree)) {
        .default_init_expr => |default| {
            const elem_node = try t.transType(scope, default.qt, default.last_tok);
            const ptr_ty = try ZigTag.single_pointer.create(t.arena, .{
                .elem_type = elem_node,
                .is_allowzero = true,
                .is_const = false,
                .is_volatile = false,
            });
            const zero = try ZigTag.ptr_from_int.create(t.arena, ZigTag.zero_literal.init());
            return ZigTag.as.create(t.arena, .{ .lhs = ptr_ty, .rhs = zero });
        },
        .array_access_expr => |access| {
            const base = try t.transMemberDesignator(scope, access.base);
            return t.transArrayAccess(scope, access, base);
        },
        .member_access_expr => |access| {
            const base = try t.transMemberDesignator(scope, access.base);
            return t.transMemberAccess(scope, .normal, access, base);
        },
        .cast => |cast| {
            assert(cast.kind == .array_to_pointer);
            return t.transMemberDesignator(scope, cast.operand);
        },
        else => unreachable,
    }
}

fn transBuiltinCall(
    t: *Translator,
    scope: *Scope,
    call: Node.BuiltinCall,
    used: ResultUsed,
) TransError!ZigNode {
    const builtin_name = t.tree.tokSlice(call.builtin_tok);
    if (std.mem.eql(u8, builtin_name, "__builtin_offsetof")) {
        const res = try t.transOffsetof(scope, call.args[0]);
        return t.maybeSuppressResult(used, res);
    }

    const builtin = builtins.map.get(builtin_name) orelse
        return t.fail(error.UnsupportedTranslation, call.builtin_tok, "TODO implement function '{s}' in std.zig.c_builtins", .{builtin_name});

    if (builtin.tag) |tag| switch (tag) {
        .byte_swap, .ceil, .cos, .sin, .exp, .exp2, .exp10, .abs, .log, .log2, .log10, .round, .sqrt, .trunc, .floor => {
            assert(call.args.len == 1);
            const arg = try t.transExprCoercing(scope, call.args[0], .used);
            const arg_ty = try t.transType(scope, call.args[0].qt(t.tree), call.args[0].tok(t.tree));
            const coerced = try ZigTag.as.create(t.arena, .{ .lhs = arg_ty, .rhs = arg });

            const ptr = try t.arena.create(ast.Payload.UnOp);
            ptr.* = .{ .base = .{ .tag = tag }, .data = coerced };
            return t.maybeSuppressResult(used, ZigNode.initPayload(&ptr.base));
        },
        .@"unreachable" => return ZigTag.@"unreachable".init(),
        else => unreachable,
    };

    const arg_nodes = try t.arena.alloc(ZigNode, call.args.len);
    for (call.args, arg_nodes) |c_arg, *zig_arg| {
        zig_arg.* = try t.transExprCoercing(scope, c_arg, .used);
    }

    const builtin_identifier = try ZigTag.identifier.create(t.arena, "__builtin");
    const field_access = try ZigTag.field_access.create(t.arena, .{
        .lhs = builtin_identifier,
        .field_name = builtin.name,
    });

    const res = try ZigTag.call.create(t.arena, .{
        .lhs = field_access,
        .args = arg_nodes,
    });
    if (call.qt.is(t.comp, .void)) return res;
    return t.maybeSuppressResult(used, res);
}

fn transCall(
    t: *Translator,
    scope: *Scope,
    call: Node.Call,
    used: ResultUsed,
) TransError!ZigNode {
    const raw_fn_expr = try t.transExpr(scope, call.callee, .used);
    const fn_expr = blk: {
        loop: switch (call.callee.get(t.tree)) {
            .paren_expr => |paren_expr| {
                continue :loop paren_expr.operand.get(t.tree);
            },
            .decl_ref_expr => |decl_ref| {
                if (decl_ref.qt.is(t.comp, .func)) break :blk raw_fn_expr;
            },
            .cast => |cast| {
                if (cast.kind == .function_to_pointer) {
                    continue :loop cast.operand.get(t.tree);
                }
            },
            .deref_expr, .addr_of_expr => |un| {
                continue :loop un.operand.get(t.tree);
            },
            .generic_expr => |generic| {
                continue :loop generic.chosen.get(t.tree);
            },
            .generic_association_expr => |generic| {
                continue :loop generic.expr.get(t.tree);
            },
            .generic_default_expr => |generic| {
                continue :loop generic.expr.get(t.tree);
            },
            else => {},
        }
        break :blk try ZigTag.unwrap.create(t.arena, raw_fn_expr);
    };

    const callee_qt = call.callee.qt(t.tree);
    const maybe_ptr_ty = callee_qt.get(t.comp, .pointer);
    const func_qt = if (maybe_ptr_ty) |ptr| ptr.child else callee_qt;
    const func_ty = func_qt.get(t.comp, .func).?;

    const arg_nodes = try t.arena.alloc(ZigNode, call.args.len);
    for (call.args, arg_nodes, 0..) |c_arg, *zig_arg, i| {
        if (i < func_ty.params.len) {
            zig_arg.* = try t.transExprCoercing(scope, c_arg, .used);

            if (zig_arg.isBoolRes() and !func_ty.params[i].qt.is(t.comp, .bool)) {
                // In C the result type of a boolean expression is int. If this result is passed as
                // an argument to a function whose parameter is also int, there is no cast. Therefore
                // in Zig we'll need to cast it from bool to u1 (which will safely coerce to c_int).
                zig_arg.* = try ZigTag.int_from_bool.create(t.arena, zig_arg.*);
            }
        } else {
            zig_arg.* = try t.transExpr(scope, c_arg, .used);

            if (zig_arg.isBoolRes()) {
                // Same as above but now we don't have a result type.
                const u1_node = try ZigTag.int_from_bool.create(t.arena, zig_arg.*);
                const c_int_node = try ZigTag.type.create(t.arena, "c_int");
                zig_arg.* = try ZigTag.as.create(t.arena, .{ .lhs = c_int_node, .rhs = u1_node });
            }
        }
    }

    const res = try ZigTag.call.create(t.arena, .{
        .lhs = fn_expr,
        .args = arg_nodes,
    });
    if (call.qt.is(t.comp, .void)) return res;
    return t.maybeSuppressResult(used, res);
}

const SuppressCast = enum { with_as, no_as };

fn transIntLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const int_lit_node = try t.createIntNode(val);
    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, int_lit_node);
    }

    // Integer literals in C have types, and this can matter for several reasons.
    // For example, this is valid C:
    //     unsigned char y = 256;
    // How this gets evaluated is the 256 is an integer, which gets truncated to signed char, then bit-casted
    // to unsigned char, resulting in 0. In order for this to work, we have to emit this zig code:
    //     var y = @as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 256)))));

    // @as(T, x)
    const ty_node = try t.transType(scope, literal_index.qt(t.tree), literal_index.tok(t.tree));
    const as = try ZigTag.as.create(t.arena, .{ .lhs = ty_node, .rhs = int_lit_node });
    return t.maybeSuppressResult(used, as);
}

fn transCharLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const char_literal = literal_index.get(t.tree).char_literal;
    const narrow = char_literal.kind == .ascii or char_literal.kind == .utf8;

    // C has a somewhat obscure feature called multi-character character constant
    // e.g. 'abcd'
    const int_value = val.toInt(u32, t.comp).?;
    const int_lit_node = if (char_literal.kind == .ascii and int_value > 255)
        try t.createNumberNode(int_value, .int)
    else
        try t.createCharLiteralNode(narrow, int_value);

    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, int_lit_node);
    }

    // See comment in `transIntLiteral` for why this code is here.
    // @as(T, x)
    const as_node = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, char_literal.qt, char_literal.literal_tok),
        .rhs = int_lit_node,
    });
    return t.maybeSuppressResult(used, as_node);
}

fn transFloatLiteral(
    t: *Translator,
    scope: *Scope,
    literal_index: Node.Index,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    const val = t.tree.value_map.get(literal_index).?;
    const float_literal = literal_index.get(t.tree).float_literal;

    var allocating: std.Io.Writer.Allocating = .init(t.gpa);
    defer allocating.deinit();
    _ = val.print(float_literal.qt, t.comp, &allocating.writer) catch return error.OutOfMemory;

    const float_lit_node = try ZigTag.float_literal.create(t.arena, try t.arena.dupe(u8, allocating.written()));
    if (suppress_as == .no_as) {
        return t.maybeSuppressResult(used, float_lit_node);
    }

    const as_node = try ZigTag.as.create(t.arena, .{
        .lhs = try t.transType(scope, float_literal.qt, float_literal.literal_tok),
        .rhs = float_lit_node,
    });
    return t.maybeSuppressResult(used, as_node);
}

fn transStringLiteral(
    t: *Translator,
    scope: *Scope,
    expr: Node.Index,
    literal: Node.CharLiteral,
) TransError!ZigNode {
    switch (literal.kind) {
        .ascii, .utf8 => return t.transNarrowStringLiteral(expr, literal),
        .utf16, .utf32, .wide => {
            const name = try std.fmt.allocPrint(t.arena, "{s}_string_{d}", .{ @tagName(literal.kind), t.getMangle() });

            const array_type = try t.transTypeInit(scope, literal.qt, expr, literal.literal_tok);
            const lit_array = try t.transStringLiteralInitializer(expr, literal, array_type);
            const decl = try ZigTag.var_simple.create(t.arena, .{ .name = name, .init = lit_array });
            try scope.appendNode(decl);
            return ZigTag.identifier.create(t.arena, name);
        },
    }
}

fn transNarrowStringLiteral(
    t: *Translator,
    expr: Node.Index,
    literal: Node.CharLiteral,
) TransError!ZigNode {
    const val = t.tree.value_map.get(expr).?;

    const bytes = t.comp.interner.get(val.ref()).bytes;
    var allocating: std.Io.Writer.Allocating = try .initCapacity(t.gpa, bytes.len);
    defer allocating.deinit();

    aro.Value.printString(bytes, literal.qt, t.comp, &allocating.writer) catch return error.OutOfMemory;

    return ZigTag.string_literal.create(t.arena, try t.arena.dupe(u8, allocating.written()));
}

/// Translate a string literal that is initializing an array. In general narrow string
/// literals become `"<string>".*` or `"<string>"[0..<size>].*` if they need truncation.
/// Wide string literals become an array of integers. zero-fillers pad out the array to
/// the appropriate length, if necessary.
fn transStringLiteralInitializer(
    t: *Translator,
    expr: Node.Index,
    literal: Node.CharLiteral,
    array_type: ZigNode,
) TransError!ZigNode {
    assert(array_type.tag() == .array_type or array_type.tag() == .null_sentinel_array_type);

    const is_narrow = literal.kind == .ascii or literal.kind == .utf8;

    // The length of the string literal excluding the sentinel.
    const str_length = literal.qt.arrayLen(t.comp).? - 1;

    const payload = (array_type.castTag(.array_type) orelse array_type.castTag(.null_sentinel_array_type).?).data;
    const array_size = payload.len;
    const elem_type = payload.elem_type;

    if (array_size == 0) return ZigTag.empty_array.create(t.arena, array_type);

    const num_inits = @min(str_length, array_size);
    if (num_inits == 0) {
        return ZigTag.array_filler.create(t.arena, .{
            .type = elem_type,
            .filler = ZigTag.zero_literal.init(),
            .count = array_size,
        });
    }

    const init_node = if (is_narrow) blk: {
        // "string literal".* or string literal"[0..num_inits].*
        var str = try t.transNarrowStringLiteral(expr, literal);
        if (str_length != array_size) str = try ZigTag.string_slice.create(t.arena, .{ .string = str, .end = num_inits });
        break :blk try ZigTag.deref.create(t.arena, str);
    } else blk: {
        const size = literal.qt.childType(t.comp).sizeof(t.comp);

        const val = t.tree.value_map.get(expr).?;
        const bytes = t.comp.interner.get(val.ref()).bytes;

        const init_list = try t.arena.alloc(ZigNode, @intCast(num_inits));
        for (init_list, 0..) |*item, i| {
            const codepoint = switch (size) {
                2 => @as(*const u16, @ptrCast(@alignCast(bytes.ptr + i * 2))).*,
                4 => @as(*const u32, @ptrCast(@alignCast(bytes.ptr + i * 4))).*,
                else => unreachable,
            };
            item.* = try t.createCharLiteralNode(false, codepoint);
        }
        const init_args: ast.Payload.Array.ArrayTypeInfo = .{ .len = num_inits, .elem_type = elem_type };
        const init_array_type = if (array_type.tag() == .array_type)
            try ZigTag.array_type.create(t.arena, init_args)
        else
            try ZigTag.null_sentinel_array_type.create(t.arena, init_args);
        break :blk try ZigTag.array_init.create(t.arena, .{
            .cond = init_array_type,
            .cases = init_list,
        });
    };

    if (num_inits == array_size) return init_node;
    assert(array_size > str_length); // If array_size <= str_length, `num_inits == array_size` and we've already returned.

    const filler_node = try ZigTag.array_filler.create(t.arena, .{
        .type = elem_type,
        .filler = ZigTag.zero_literal.init(),
        .count = array_size - str_length,
    });
    return ZigTag.array_cat.create(t.arena, .{ .lhs = init_node, .rhs = filler_node });
}

fn transCompoundLiteral(
    t: *Translator,
    scope: *Scope,
    literal: Node.CompoundLiteral,
    used: ResultUsed,
) TransError!ZigNode {
    if (used == .unused) {
        return t.transExpr(scope, literal.initializer, .unused);
    }

    // TODO taking a reference to a compound literal should result in a mutable
    // pointer (unless the literal is const).

    const initializer = try t.transExprCoercing(scope, literal.initializer, .used);
    const ty = try t.transType(scope, literal.qt, literal.l_paren_tok);
    if (!literal.thread_local and literal.storage_class != .static) {
        // In the simple case a compound literal can be translated
        // simply as `@as(type, initializer)`.
        return ZigTag.as.create(t.arena, .{ .lhs = ty, .rhs = initializer });
    }

    // Otherwise static or thread local compound literals are translated as
    // a reference to a variable wrapped in a struct.

    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const tmp = try block_scope.reserveMangledName("tmp");
    const wrapped_name = "compound_literal";

    // const tmp = struct { var compound_literal = initializer };
    const temp_decl = try ZigTag.var_decl.create(t.arena, .{
        .is_pub = false,
        .is_const = literal.qt.@"const",
        .is_extern = false,
        .is_export = false,
        .is_threadlocal = literal.thread_local,
        .linksection_string = null,
        .alignment = null,
        .name = wrapped_name,
        .type = ty,
        .init = initializer,
    });
    const wrapped = try ZigTag.wrapped_local.create(t.arena, .{ .name = tmp, .init = temp_decl });
    try block_scope.statements.append(t.gpa, wrapped);

    // break :blk tmp.compound_literal
    const static_tmp_ident = try ZigTag.identifier.create(t.arena, tmp);
    const field_access = try ZigTag.field_access.create(t.arena, .{
        .lhs = static_tmp_ident,
        .field_name = wrapped_name,
    });
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = field_access,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return block_scope.complete();
}

fn transDefaultInit(
    t: *Translator,
    scope: *Scope,
    default_init: Node.DefaultInit,
    used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!ZigNode {
    assert(used == .used);
    const type_node = try t.transType(scope, default_init.qt, default_init.last_tok);
    return try t.createZeroValueNode(default_init.qt, type_node, suppress_as);
}

fn transArrayInit(
    t: *Translator,
    scope: *Scope,
    array_init: Node.ContainerInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const array_item_qt = array_init.container_qt.childType(t.comp);
    const array_item_type = try t.transType(scope, array_item_qt, array_init.l_brace_tok);
    var maybe_lhs: ?ZigNode = null;
    var val_list: std.ArrayListUnmanaged(ZigNode) = .empty;
    defer val_list.deinit(t.gpa);
    var i: usize = 0;
    while (i < array_init.items.len) {
        const rhs = switch (array_init.items[i].get(t.tree)) {
            .array_filler_expr => |array_filler| blk: {
                const node = try ZigTag.array_filler.create(t.arena, .{
                    .type = array_item_type,
                    .filler = try t.createZeroValueNode(array_item_qt, array_item_type, .no_as),
                    .count = @intCast(array_filler.count),
                });
                i += 1;
                break :blk node;
            },
            else => blk: {
                defer val_list.clearRetainingCapacity();
                while (i < array_init.items.len) : (i += 1) {
                    if (array_init.items[i].get(t.tree) == .array_filler_expr) break;
                    const expr = try t.transExprCoercing(scope, array_init.items[i], .used);
                    try val_list.append(t.gpa, expr);
                }
                const array_type = try ZigTag.array_type.create(t.arena, .{
                    .elem_type = array_item_type,
                    .len = val_list.items.len,
                });
                const array_init_node = try ZigTag.array_init.create(t.arena, .{
                    .cond = array_type,
                    .cases = try t.arena.dupe(ZigNode, val_list.items),
                });
                break :blk array_init_node;
            },
        };
        maybe_lhs = if (maybe_lhs) |lhs| blk: {
            const cat = try ZigTag.array_cat.create(t.arena, .{
                .lhs = lhs,
                .rhs = rhs,
            });
            break :blk cat;
        } else rhs;
    }
    return maybe_lhs orelse try ZigTag.container_init_dot.create(t.arena, &.{});
}

fn transUnionInit(
    t: *Translator,
    scope: *Scope,
    union_init: Node.UnionInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const init_expr = union_init.initializer orelse
        return ZigTag.undefined_literal.init();

    if (init_expr.get(t.tree) == .default_init_expr) {
        return try t.transExpr(scope, init_expr, used);
    }

    const union_type = try t.transType(scope, union_init.union_qt, union_init.l_brace_tok);

    const union_base = union_init.union_qt.base(t.comp);
    const field = union_base.type.@"union".fields[union_init.field_index];
    const field_name = if (field.name_tok == 0) t.anonymous_record_field_names.get(.{
        .parent = union_base.qt,
        .field = field.qt,
    }).? else field.name.lookup(t.comp);

    const field_init = try t.arena.create(ast.Payload.ContainerInit.Initializer);
    field_init.* = .{
        .name = field_name,
        .value = try t.transExprCoercing(scope, init_expr, .used),
    };
    const container_init = try ZigTag.container_init.create(t.arena, .{
        .lhs = union_type,
        .inits = field_init[0..1],
    });
    return container_init;
}

fn transStructInit(
    t: *Translator,
    scope: *Scope,
    struct_init: Node.ContainerInit,
    used: ResultUsed,
) TransError!ZigNode {
    assert(used == .used);
    const struct_type = try t.transType(scope, struct_init.container_qt, struct_init.l_brace_tok);
    const field_inits = try t.arena.alloc(ast.Payload.ContainerInit.Initializer, struct_init.items.len);

    const struct_base = struct_init.container_qt.base(t.comp);
    for (
        field_inits,
        struct_init.items,
        struct_base.type.@"struct".fields,
    ) |*init, field_expr, field| {
        const field_name = if (field.name_tok == 0) t.anonymous_record_field_names.get(.{
            .parent = struct_base.qt,
            .field = field.qt,
        }).? else field.name.lookup(t.comp);
        init.* = .{
            .name = field_name,
            .value = try t.transExprCoercing(scope, field_expr, .used),
        };
    }

    const container_init = try ZigTag.container_init.create(t.arena, .{
        .lhs = struct_type,
        .inits = field_inits,
    });
    return container_init;
}

fn transTypeInfo(
    t: *Translator,
    scope: *Scope,
    op: ZigTag,
    typeinfo: Node.TypeInfo,
) TransError!ZigNode {
    const operand = operand: {
        if (typeinfo.expr) |expr| {
            const operand = try t.transExpr(scope, expr, .used);
            break :operand try ZigTag.typeof.create(t.arena, operand);
        }
        break :operand try t.transType(scope, typeinfo.operand_qt, typeinfo.op_tok);
    };

    const payload = try t.arena.create(ast.Payload.UnOp);
    payload.* = .{
        .base = .{ .tag = op },
        .data = operand,
    };
    return ZigNode.initPayload(&payload.base);
}

fn transStmtExpr(
    t: *Translator,
    scope: *Scope,
    stmt_expr: Node.Unary,
    used: ResultUsed,
) TransError!ZigNode {
    const compound_stmt = stmt_expr.operand.get(t.tree).compound_stmt;
    if (used == .unused) {
        return t.transCompoundStmt(scope, compound_stmt);
    }
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    for (compound_stmt.body[0 .. compound_stmt.body.len - 1]) |stmt| {
        const result = try t.transStmt(&block_scope.base, stmt);
        switch (result.tag()) {
            .declaration, .empty_block => {},
            else => try block_scope.statements.append(t.gpa, result),
        }
    }

    const last_result = try t.transExpr(&block_scope.base, compound_stmt.body[compound_stmt.body.len - 1], .used);
    switch (last_result.tag()) {
        .declaration, .empty_block => {},
        else => {
            const break_node = try ZigTag.break_val.create(t.arena, .{
                .label = block_scope.label,
                .val = last_result,
            });
            try block_scope.statements.append(t.gpa, break_node);
        },
    }
    return block_scope.complete();
}

fn transConvertvectorExpr(
    t: *Translator,
    scope: *Scope,
    convertvector: Node.Convertvector,
) TransError!ZigNode {
    var block_scope = try Scope.Block.init(t, scope, true);
    defer block_scope.deinit();

    const src_expr_node = try t.transExpr(&block_scope.base, convertvector.operand, .used);
    const tmp = try block_scope.reserveMangledName("tmp");
    const tmp_decl = try ZigTag.var_simple.create(t.arena, .{ .name = tmp, .init = src_expr_node });
    try block_scope.statements.append(t.gpa, tmp_decl);
    const tmp_ident = try ZigTag.identifier.create(t.arena, tmp);

    const dest_type_node = try t.transType(&block_scope.base, convertvector.dest_qt, convertvector.builtin_tok);
    const dest_vec_ty = convertvector.dest_qt.get(t.comp, .vector).?;
    const src_vec_ty = convertvector.operand.qt(t.tree).get(t.comp, .vector).?;

    const src_elem_sk = src_vec_ty.elem.scalarKind(t.comp);
    const dest_elem_sk = convertvector.dest_qt.childType(t.comp).scalarKind(t.comp);

    const items = try t.arena.alloc(ZigNode, dest_vec_ty.len);
    for (items, 0..dest_vec_ty.len) |*item, i| {
        const value = try ZigTag.array_access.create(t.arena, .{
            .lhs = tmp_ident,
            .rhs = try t.createNumberNode(i, .int),
        });

        if (src_elem_sk == .float and dest_elem_sk == .float) {
            item.* = try ZigTag.float_cast.create(t.arena, value);
        } else if (src_elem_sk == .float) {
            item.* = try ZigTag.int_from_float.create(t.arena, value);
        } else if (dest_elem_sk == .float) {
            item.* = try ZigTag.float_from_int.create(t.arena, value);
        } else {
            item.* = try t.transIntCast(value, src_vec_ty.elem, dest_vec_ty.elem);
        }
    }

    const vec_init = try ZigTag.array_init.create(t.arena, .{
        .cond = dest_type_node,
        .cases = items,
    });
    const break_node = try ZigTag.break_val.create(t.arena, .{
        .label = block_scope.label,
        .val = vec_init,
    });
    try block_scope.statements.append(t.gpa, break_node);

    return block_scope.complete();
}

fn transShufflevectorExpr(
    t: *Translator,
    scope: *Scope,
    shufflevector: Node.Shufflevector,
) TransError!ZigNode {
    if (shufflevector.indexes.len == 0) {
        return t.fail(error.UnsupportedTranslation, shufflevector.builtin_tok, "@shuffle needs at least 1 index", .{});
    }

    const a = try t.transExpr(scope, shufflevector.lhs, .used);
    const b = try t.transExpr(scope, shufflevector.rhs, .used);

    // First two arguments to __builtin_shufflevector must be the same type
    const vector_child_type = try t.vectorTypeInfo(a, "child");
    const vector_len = try t.vectorTypeInfo(a, "len");
    const shuffle_mask = blk: {
        const mask_len = shufflevector.indexes.len;

        const mask_type = try ZigTag.vector.create(t.arena, .{
            .lhs = try t.createNumberNode(mask_len, .int),
            .rhs = try ZigTag.type.create(t.arena, "i32"),
        });

        const init_list = try t.arena.alloc(ZigNode, mask_len);
        for (init_list, shufflevector.indexes) |*init, index| {
            const index_expr = try t.transExprCoercing(scope, index, .used);
            const converted_index = try t.createHelperCallNode(.shuffleVectorIndex, &.{ index_expr, vector_len });
            init.* = converted_index;
        }

        break :blk try ZigTag.array_init.create(t.arena, .{
            .cond = mask_type,
            .cases = init_list,
        });
    };

    return ZigTag.shuffle.create(t.arena, .{
        .element_type = vector_child_type,
        .a = a,
        .b = b,
        .mask_vector = shuffle_mask,
    });
}

// =====================
// Node creation helpers
// =====================

fn createZeroValueNode(
    t: *Translator,
    qt: QualType,
    type_node: ZigNode,
    suppress_as: SuppressCast,
) !ZigNode {
    switch (qt.base(t.comp).type) {
        .bool => return ZigTag.false_literal.init(),
        .int, .bit_int, .float => {
            const zero_literal = ZigTag.zero_literal.init();
            return switch (suppress_as) {
                .with_as => try t.createBinOpNode(.as, type_node, zero_literal),
                .no_as => zero_literal,
            };
        },
        .pointer => {
            const null_literal = ZigTag.null_literal.init();
            return switch (suppress_as) {
                .with_as => try t.createBinOpNode(.as, type_node, null_literal),
                .no_as => null_literal,
            };
        },
        else => {},
    }
    return try ZigTag.std_mem_zeroes.create(t.arena, type_node);
}

fn createIntNode(t: *Translator, int: aro.Value) !ZigNode {
    var space: aro.Interner.Tag.Int.BigIntSpace = undefined;
    var big = t.comp.interner.get(int.ref()).toBigInt(&space);
    const is_negative = !big.positive;
    big.positive = true;

    const str = big.toStringAlloc(t.arena, 10, .lower) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    const res = try ZigTag.integer_literal.create(t.arena, str);
    if (is_negative) return ZigTag.negate.create(t.arena, res);
    return res;
}

fn createNumberNode(t: *Translator, num: anytype, num_kind: enum { int, float }) !ZigNode {
    const fmt_s = switch (@typeInfo(@TypeOf(num))) {
        .int, .comptime_int => "{d}",
        else => "{s}",
    };
    const str = try std.fmt.allocPrint(t.arena, fmt_s, .{num});
    if (num_kind == .float)
        return ZigTag.float_literal.create(t.arena, str)
    else
        return ZigTag.integer_literal.create(t.arena, str);
}

fn createCharLiteralNode(t: *Translator, narrow: bool, val: u32) TransError!ZigNode {
    return ZigTag.char_literal.create(t.arena, if (narrow)
        try std.fmt.allocPrint(t.arena, "'{f}'", .{std.zig.fmtChar(@as(u8, @intCast(val)))})
    else
        try std.fmt.allocPrint(t.arena, "'\\u{{{x}}}'", .{val}));
}

fn createBinOpNode(
    t: *Translator,
    op: ZigTag,
    lhs: ZigNode,
    rhs: ZigNode,
) !ZigNode {
    const payload = try t.arena.create(ast.Payload.BinOp);
    payload.* = .{
        .base = .{ .tag = op },
        .data = .{
            .lhs = lhs,
            .rhs = rhs,
        },
    };
    return ZigNode.initPayload(&payload.base);
}

pub fn createHelperCallNode(t: *Translator, name: std.meta.DeclEnum(std.zig.c_translation.helpers), args_opt: ?[]const ZigNode) !ZigNode {
    if (args_opt) |args| {
        return ZigTag.helper_call.create(t.arena, .{
            .name = @tagName(name),
            .args = try t.arena.dupe(ZigNode, args),
        });
    } else {
        return ZigTag.helper_ref.create(t.arena, @tagName(name));
    }
}

/// Cast a signed integer node to a usize, for use in pointer arithmetic. Negative numbers
/// will become very large positive numbers but that is ok since we only use this in
/// pointer arithmetic expressions, where wraparound will ensure we get the correct value.
/// node -> @as(usize, @bitCast(@as(isize, @intCast(node))))
fn usizeCastForWrappingPtrArithmetic(t: *Translator, node: ZigNode) TransError!ZigNode {
    const intcast_node = try ZigTag.as.create(t.arena, .{
        .lhs = try ZigTag.type.create(t.arena, "isize"),
        .rhs = try ZigTag.int_cast.create(t.arena, node),
    });

    return ZigTag.as.create(t.arena, .{
        .lhs = try ZigTag.type.create(t.arena, "usize"),
        .rhs = try ZigTag.bit_cast.create(t.arena, intcast_node),
    });
}

/// @typeInfo(@TypeOf(vec_node)).vector.<field>
fn vectorTypeInfo(t: *Translator, vec_node: ZigNode, field: []const u8) TransError!ZigNode {
    const typeof_call = try ZigTag.typeof.create(t.arena, vec_node);
    const typeinfo_call = try ZigTag.typeinfo.create(t.arena, typeof_call);
    const vector_type_info = try ZigTag.field_access.create(t.arena, .{ .lhs = typeinfo_call, .field_name = "vector" });
    return ZigTag.field_access.create(t.arena, .{ .lhs = vector_type_info, .field_name = field });
}

/// Build a getter function for a flexible array field in a C record
/// e.g. `T items[]` or `T items[0]`. The generated function returns a [*c] pointer
/// to the flexible array with the correct const and volatile qualifiers
fn createFlexibleMemberFn(
    t: *Translator,
    member_name: []const u8,
    field_name: []const u8,
) Error!ZigNode {
    const self_param_name = "self";
    const self_param = try ZigTag.identifier.create(t.arena, self_param_name);
    const self_type = try ZigTag.typeof.create(t.arena, self_param);

    const fn_params = try t.arena.alloc(ast.Payload.Param, 1);
    fn_params[0] = .{
        .name = self_param_name,
        .type = ZigTag.@"anytype".init(),
        .is_noalias = false,
    };

    // @typeInfo(@TypeOf(self.*.<field_name>)).pointer.child
    const dereffed = try ZigTag.deref.create(t.arena, self_param);
    const field_access = try ZigTag.field_access.create(t.arena, .{ .lhs = dereffed, .field_name = field_name });
    const type_of = try ZigTag.typeof.create(t.arena, field_access);
    const type_info = try ZigTag.typeinfo.create(t.arena, type_of);
    const array_info = try ZigTag.field_access.create(t.arena, .{ .lhs = type_info, .field_name = "array" });
    const child_info = try ZigTag.field_access.create(t.arena, .{ .lhs = array_info, .field_name = "child" });

    const return_type = try t.createHelperCallNode(.FlexibleArrayType, &.{ self_type, child_info });

    // return @ptrCast(&self.*.<field_name>);
    const address_of = try ZigTag.address_of.create(t.arena, field_access);
    const casted = try ZigTag.ptr_cast.create(t.arena, address_of);
    const return_stmt = try ZigTag.@"return".create(t.arena, casted);
    const body = try ZigTag.block_single.create(t.arena, return_stmt);

    return ZigTag.func.create(t.arena, .{
        .is_pub = true,
        .is_extern = false,
        .is_export = false,
        .is_inline = false,
        .is_var_args = false,
        .name = member_name,
        .linksection_string = null,
        .explicit_callconv = null,
        .params = fn_params,
        .return_type = return_type,
        .body = body,
        .alignment = null,
    });
}

// =================
// Macro translation
// =================

fn transMacros(t: *Translator) !void {
    var tok_list: std.ArrayList(CToken) = .empty;
    defer tok_list.deinit(t.gpa);

    var pattern_list = try PatternList.init(t.gpa);
    defer pattern_list.deinit(t.gpa);

    for (t.pp.defines.keys(), t.pp.defines.values()) |name, macro| {
        if (macro.is_builtin) continue;
        if (t.global_scope.containsNow(name)) {
            continue;
        }

        tok_list.items.len = 0;
        try tok_list.ensureUnusedCapacity(t.gpa, macro.tokens.len);
        for (macro.tokens) |tok| {
            switch (tok.id) {
                .invalid => continue,
                .whitespace => continue,
                .comment => continue,
                .macro_ws => continue,
                else => {},
            }
            tok_list.appendAssumeCapacity(tok);
        }

        if (macro.is_func) {
            const ms: PatternList.MacroSlicer = .{
                .tokens = tok_list.items,
                .source = t.comp.getSource(macro.loc.id).buf,
                .params = @intCast(macro.params.len),
            };
            if (try pattern_list.match(ms)) |impl| {
                const decl = try ZigTag.pub_var_simple.create(t.arena, .{
                    .name = name,
                    .init = try t.createHelperCallNode(impl, null),
                });
                try t.addTopLevelDecl(name, decl);
                continue;
            }
        }

        if (t.checkTranslatableMacro(tok_list.items, macro.params)) |err| {
            switch (err) {
                .undefined_identifier => |ident| try t.failDeclExtra(&t.global_scope.base, macro.loc, name, "unable to translate macro: undefined identifier `{s}`", .{ident}),
                .invalid_arg_usage => |ident| try t.failDeclExtra(&t.global_scope.base, macro.loc, name, "unable to translate macro: untranslatable usage of arg `{s}`", .{ident}),
            }
            continue;
        }

        var macro_translator: MacroTranslator = .{
            .t = t,
            .tokens = tok_list.items,
            .source = t.comp.getSource(macro.loc.id).buf,
            .name = name,
            .macro = macro,
        };

        const res = if (macro.is_func)
            macro_translator.transFnMacro()
        else
            macro_translator.transMacro();
        res catch |err| switch (err) {
            error.ParseError => continue,
            error.OutOfMemory => |e| return e,
        };
    }
}

const MacroTranslateError = union(enum) {
    undefined_identifier: []const u8,
    invalid_arg_usage: []const u8,
};

fn checkTranslatableMacro(t: *Translator, tokens: []const CToken, params: []const []const u8) ?MacroTranslateError {
    var last_is_type_kw = false;
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        const token = tokens[i];
        switch (token.id) {
            .period, .arrow => i += 1, // skip next token since field identifiers can be unknown
            .keyword_struct, .keyword_union, .keyword_enum => if (!last_is_type_kw) {
                last_is_type_kw = true;
                continue;
            },
            .macro_param, .macro_param_no_expand => {
                if (last_is_type_kw) {
                    return .{ .invalid_arg_usage = params[token.end] };
                }
            },
            .identifier, .extended_identifier => {
                const identifier = t.pp.tokSlice(token);
                if (!t.global_scope.contains(identifier) and !builtins.map.has(identifier)) {
                    return .{ .undefined_identifier = identifier };
                }
            },
            else => {},
        }
        last_is_type_kw = false;
    }
    return null;
}

fn getContainer(t: *Translator, node: ZigNode) ?ZigNode {
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
            if (t.global_scope.sym_table.get(ident.data)) |value| {
                if (value.castTag(.var_decl)) |var_decl|
                    return t.getContainer(var_decl.data.init.?);
                if (value.castTag(.var_simple) orelse value.castTag(.pub_var_simple)) |var_decl|
                    return t.getContainer(var_decl.data.init);
            }
        },

        .field_access => {
            const field_access = node.castTag(.field_access).?;

            if (t.getContainerTypeOf(field_access.data.lhs)) |ty_node| {
                if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                    for (container.data.fields) |field| {
                        if (mem.eql(u8, field.name, field_access.data.field_name)) {
                            return t.getContainer(field.type);
                        }
                    }
                }
            }
        },

        else => {},
    }
    return null;
}

fn getContainerTypeOf(t: *Translator, ref: ZigNode) ?ZigNode {
    if (ref.castTag(.identifier)) |ident| {
        if (t.global_scope.sym_table.get(ident.data)) |value| {
            if (value.castTag(.var_decl)) |var_decl| {
                return t.getContainer(var_decl.data.type);
            }
        }
    } else if (ref.castTag(.field_access)) |field_access| {
        if (t.getContainerTypeOf(field_access.data.lhs)) |ty_node| {
            if (ty_node.castTag(.@"struct") orelse ty_node.castTag(.@"union")) |container| {
                for (container.data.fields) |field| {
                    if (mem.eql(u8, field.name, field_access.data.field_name)) {
                        return t.getContainer(field.type);
                    }
                }
            } else return ty_node;
        }
    }
    return null;
}

pub fn getFnProto(t: *Translator, ref: ZigNode) ?*ast.Payload.Func {
    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init orelse return null
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        return null;
    if (t.getContainerTypeOf(init)) |ty_node| {
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
