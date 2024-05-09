//! Find and annotate identifiers with links to their declarations.
pub var files: std.StringArrayHashMapUnmanaged(File) = .{};
pub var decls: std.ArrayListUnmanaged(Decl) = .{};
pub var modules: std.StringArrayHashMapUnmanaged(File.Index) = .{};

file: File.Index,

/// keep in sync with "CAT_" constants in main.js
pub const Category = union(enum(u8)) {
    namespace: Ast.Node.Index,
    global_variable: Ast.Node.Index,
    /// A function that has not been detected as returning a type.
    function: Ast.Node.Index,
    primitive: Ast.Node.Index,
    error_set: Ast.Node.Index,
    global_const: Ast.Node.Index,
    alias: Decl.Index,
    /// A primitive identifier that is also a type.
    type,
    /// Specifically it is the literal `type`.
    type_type,
    /// A function that returns a type.
    type_function: Ast.Node.Index,

    pub const Tag = @typeInfo(Category).Union.tag_type.?;
};

pub const File = struct {
    ast: Ast,
    /// Maps identifiers to the declarations they point to.
    ident_decls: std.AutoArrayHashMapUnmanaged(Ast.TokenIndex, Ast.Node.Index) = .{},
    /// Maps field access identifiers to the containing field access node.
    token_parents: std.AutoArrayHashMapUnmanaged(Ast.TokenIndex, Ast.Node.Index) = .{},
    /// Maps declarations to their global index.
    node_decls: std.AutoArrayHashMapUnmanaged(Ast.Node.Index, Decl.Index) = .{},
    /// Maps function declarations to doctests.
    doctests: std.AutoArrayHashMapUnmanaged(Ast.Node.Index, Ast.Node.Index) = .{},
    /// root node => its namespace scope
    /// struct/union/enum/opaque decl node => its namespace scope
    /// local var decl node => its local variable scope
    scopes: std.AutoArrayHashMapUnmanaged(Ast.Node.Index, *Scope) = .{},

    pub fn lookup_token(file: *File, token: Ast.TokenIndex) Decl.Index {
        const decl_node = file.ident_decls.get(token) orelse return .none;
        return file.node_decls.get(decl_node) orelse return .none;
    }

    pub fn field_count(file: *const File, node: Ast.Node.Index) u32 {
        const scope = file.scopes.get(node) orelse return 0;
        if (scope.tag != .namespace) return 0;
        const namespace: *Scope.Namespace = @alignCast(@fieldParentPtr("base", scope));
        return namespace.field_count;
    }

    pub const Index = enum(u32) {
        _,

        fn add_decl(i: Index, node: Ast.Node.Index, parent_decl: Decl.Index) Oom!Decl.Index {
            try decls.append(gpa, .{
                .ast_node = node,
                .file = i,
                .parent = parent_decl,
            });
            const decl_index: Decl.Index = @enumFromInt(decls.items.len - 1);
            try i.get().node_decls.put(gpa, node, decl_index);
            return decl_index;
        }

        pub fn get(i: File.Index) *File {
            return &files.values()[@intFromEnum(i)];
        }

        pub fn get_ast(i: File.Index) *Ast {
            return &i.get().ast;
        }

        pub fn path(i: File.Index) []const u8 {
            return files.keys()[@intFromEnum(i)];
        }

        pub fn findRootDecl(file_index: File.Index) Decl.Index {
            return file_index.get().node_decls.values()[0];
        }

        pub fn categorize_decl(file_index: File.Index, node: Ast.Node.Index) Category {
            const ast = file_index.get_ast();
            const node_tags = ast.nodes.items(.tag);
            const token_tags = ast.tokens.items(.tag);
            switch (node_tags[node]) {
                .root => return .{ .namespace = node },

                .global_var_decl,
                .local_var_decl,
                .simple_var_decl,
                .aligned_var_decl,
                => {
                    const var_decl = ast.fullVarDecl(node).?;
                    if (token_tags[var_decl.ast.mut_token] == .keyword_var)
                        return .{ .global_variable = node };

                    return categorize_expr(file_index, var_decl.ast.init_node);
                },

                .fn_proto,
                .fn_proto_multi,
                .fn_proto_one,
                .fn_proto_simple,
                .fn_decl,
                => {
                    var buf: [1]Ast.Node.Index = undefined;
                    const full = ast.fullFnProto(&buf, node).?;
                    return categorize_func(file_index, node, full);
                },

                else => unreachable,
            }
        }

        pub fn categorize_func(
            file_index: File.Index,
            node: Ast.Node.Index,
            full: Ast.full.FnProto,
        ) Category {
            return switch (categorize_expr(file_index, full.ast.return_type)) {
                .namespace, .error_set, .type_type => .{ .type_function = node },
                else => .{ .function = node },
            };
        }

        pub fn categorize_expr_deep(file_index: File.Index, node: Ast.Node.Index) Category {
            return switch (categorize_expr(file_index, node)) {
                .alias => |aliasee| aliasee.get().categorize(),
                else => |result| result,
            };
        }

        pub fn categorize_expr(file_index: File.Index, node: Ast.Node.Index) Category {
            const file = file_index.get();
            const ast = file_index.get_ast();
            const node_tags = ast.nodes.items(.tag);
            const node_datas = ast.nodes.items(.data);
            const main_tokens = ast.nodes.items(.main_token);
            //log.debug("categorize_expr tag {s}", .{@tagName(node_tags[node])});
            return switch (node_tags[node]) {
                .container_decl,
                .container_decl_trailing,
                .container_decl_arg,
                .container_decl_arg_trailing,
                .container_decl_two,
                .container_decl_two_trailing,
                .tagged_union,
                .tagged_union_trailing,
                .tagged_union_enum_tag,
                .tagged_union_enum_tag_trailing,
                .tagged_union_two,
                .tagged_union_two_trailing,
                => .{ .namespace = node },

                .error_set_decl,
                .merge_error_sets,
                => .{ .error_set = node },

                .identifier => {
                    const name_token = ast.nodes.items(.main_token)[node];
                    const ident_name = ast.tokenSlice(name_token);
                    if (std.mem.eql(u8, ident_name, "type"))
                        return .type_type;

                    if (isPrimitiveNonType(ident_name))
                        return .{ .primitive = node };

                    if (std.zig.primitives.isPrimitive(ident_name))
                        return .type;

                    if (file.ident_decls.get(name_token)) |decl_node| {
                        const decl_index = file.node_decls.get(decl_node) orelse .none;
                        if (decl_index != .none) return .{ .alias = decl_index };
                        return categorize_decl(file_index, decl_node);
                    }

                    return .{ .global_const = node };
                },

                .field_access => {
                    const object_node = node_datas[node].lhs;
                    const dot_token = main_tokens[node];
                    const field_ident = dot_token + 1;
                    const field_name = ast.tokenSlice(field_ident);

                    switch (categorize_expr(file_index, object_node)) {
                        .alias => |aliasee| if (aliasee.get().get_child(field_name)) |decl_index| {
                            return .{ .alias = decl_index };
                        },
                        else => {},
                    }

                    return .{ .global_const = node };
                },

                .builtin_call_two, .builtin_call_two_comma => {
                    if (node_datas[node].lhs == 0) {
                        const params = [_]Ast.Node.Index{};
                        return categorize_builtin_call(file_index, node, &params);
                    } else if (node_datas[node].rhs == 0) {
                        const params = [_]Ast.Node.Index{node_datas[node].lhs};
                        return categorize_builtin_call(file_index, node, &params);
                    } else {
                        const params = [_]Ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
                        return categorize_builtin_call(file_index, node, &params);
                    }
                },
                .builtin_call, .builtin_call_comma => {
                    const params = ast.extra_data[node_datas[node].lhs..node_datas[node].rhs];
                    return categorize_builtin_call(file_index, node, params);
                },

                .call_one,
                .call_one_comma,
                .async_call_one,
                .async_call_one_comma,
                .call,
                .call_comma,
                .async_call,
                .async_call_comma,
                => {
                    var buf: [1]Ast.Node.Index = undefined;
                    return categorize_call(file_index, node, ast.fullCall(&buf, node).?);
                },

                .if_simple,
                .@"if",
                => {
                    const if_full = ast.fullIf(node).?;
                    if (if_full.ast.else_expr != 0) {
                        const then_cat = categorize_expr_deep(file_index, if_full.ast.then_expr);
                        const else_cat = categorize_expr_deep(file_index, if_full.ast.else_expr);
                        if (then_cat == .type_type and else_cat == .type_type) {
                            return .type_type;
                        } else if (then_cat == .error_set and else_cat == .error_set) {
                            return .{ .error_set = node };
                        } else if (then_cat == .type or else_cat == .type or
                            then_cat == .namespace or else_cat == .namespace or
                            then_cat == .error_set or else_cat == .error_set or
                            then_cat == .type_function or else_cat == .type_function)
                        {
                            return .type;
                        }
                    }
                    return .{ .global_const = node };
                },

                .@"switch", .switch_comma => return categorize_switch(file_index, node),

                .optional_type,
                .array_type,
                .array_type_sentinel,
                .ptr_type_aligned,
                .ptr_type_sentinel,
                .ptr_type,
                .ptr_type_bit_range,
                .anyframe_type,
                => .type,

                else => .{ .global_const = node },
            };
        }

        fn categorize_call(
            file_index: File.Index,
            node: Ast.Node.Index,
            call: Ast.full.Call,
        ) Category {
            return switch (categorize_expr(file_index, call.ast.fn_expr)) {
                .type_function => .type,
                .alias => |aliasee| categorize_decl_as_callee(aliasee, node),
                else => .{ .global_const = node },
            };
        }

        fn categorize_decl_as_callee(decl_index: Decl.Index, call_node: Ast.Node.Index) Category {
            return switch (decl_index.get().categorize()) {
                .type_function => .type,
                .alias => |aliasee| categorize_decl_as_callee(aliasee, call_node),
                else => .{ .global_const = call_node },
            };
        }

        fn categorize_builtin_call(
            file_index: File.Index,
            node: Ast.Node.Index,
            params: []const Ast.Node.Index,
        ) Category {
            const ast = file_index.get_ast();
            const main_tokens = ast.nodes.items(.main_token);
            const builtin_token = main_tokens[node];
            const builtin_name = ast.tokenSlice(builtin_token);
            if (std.mem.eql(u8, builtin_name, "@import")) {
                const str_lit_token = main_tokens[params[0]];
                const str_bytes = ast.tokenSlice(str_lit_token);
                const file_path = std.zig.string_literal.parseAlloc(gpa, str_bytes) catch @panic("OOM");
                defer gpa.free(file_path);
                if (modules.get(file_path)) |imported_file_index| {
                    return .{ .alias = File.Index.findRootDecl(imported_file_index) };
                }
                const base_path = file_index.path();
                const resolved_path = std.fs.path.resolvePosix(gpa, &.{
                    base_path, "..", file_path,
                }) catch @panic("OOM");
                defer gpa.free(resolved_path);
                log.debug("from '{s}' @import '{s}' resolved='{s}'", .{
                    base_path, file_path, resolved_path,
                });
                if (files.getIndex(resolved_path)) |imported_file_index| {
                    return .{ .alias = File.Index.findRootDecl(@enumFromInt(imported_file_index)) };
                } else {
                    log.warn("import target '{s}' did not resolve to any file", .{resolved_path});
                }
            } else if (std.mem.eql(u8, builtin_name, "@This")) {
                if (file_index.get().node_decls.get(node)) |decl_index| {
                    return .{ .alias = decl_index };
                } else {
                    log.warn("@This() is missing link to Decl.Index", .{});
                }
            }

            return .{ .global_const = node };
        }

        fn categorize_switch(file_index: File.Index, node: Ast.Node.Index) Category {
            const ast = file_index.get_ast();
            const node_datas = ast.nodes.items(.data);
            const extra = ast.extraData(node_datas[node].rhs, Ast.Node.SubRange);
            const case_nodes = ast.extra_data[extra.start..extra.end];
            var all_type_type = true;
            var all_error_set = true;
            var any_type = false;
            if (case_nodes.len == 0) return .{ .global_const = node };
            for (case_nodes) |case_node| {
                const case = ast.fullSwitchCase(case_node).?;
                switch (categorize_expr_deep(file_index, case.ast.target_expr)) {
                    .type_type => {
                        any_type = true;
                        all_error_set = false;
                    },
                    .error_set => {
                        any_type = true;
                        all_type_type = false;
                    },
                    .type, .namespace, .type_function => {
                        any_type = true;
                        all_error_set = false;
                        all_type_type = false;
                    },
                    else => {
                        all_error_set = false;
                        all_type_type = false;
                    },
                }
            }
            if (all_type_type) return .type_type;
            if (all_error_set) return .{ .error_set = node };
            if (any_type) return .type;
            return .{ .global_const = node };
        }
    };
};

pub const ModuleIndex = enum(u32) {
    _,
};

pub fn add_file(file_name: []const u8, bytes: []u8) !File.Index {
    const ast = try parse(bytes);
    const file_index: File.Index = @enumFromInt(files.entries.len);
    try files.put(gpa, file_name, .{ .ast = ast });

    if (ast.errors.len > 0) {
        log.err("can't index '{s}' because it has syntax errors", .{file_index.path()});
        return file_index;
    }

    var w: Walk = .{
        .file = file_index,
    };
    const scope = try gpa.create(Scope);
    scope.* = .{ .tag = .top };

    const decl_index = try file_index.add_decl(0, .none);
    try struct_decl(&w, scope, decl_index, 0, ast.containerDeclRoot());

    const file = file_index.get();
    shrinkToFit(&file.ident_decls);
    shrinkToFit(&file.token_parents);
    shrinkToFit(&file.node_decls);
    shrinkToFit(&file.doctests);
    shrinkToFit(&file.scopes);

    return file_index;
}

fn parse(source: []u8) Oom!Ast {
    // Require every source file to end with a newline so that Zig's tokenizer
    // can continue to require null termination and Autodoc implementation can
    // avoid copying source bytes from the decompressed tar file buffer.
    const adjusted_source: [:0]const u8 = s: {
        if (source.len == 0)
            break :s "";

        assert(source[source.len - 1] == '\n');
        source[source.len - 1] = 0;
        break :s source[0 .. source.len - 1 :0];
    };

    return Ast.parse(gpa, adjusted_source, .zig);
}

pub const Scope = struct {
    tag: Tag,

    const Tag = enum { top, local, namespace };

    const Local = struct {
        base: Scope = .{ .tag = .local },
        parent: *Scope,
        var_node: Ast.Node.Index,
    };

    const Namespace = struct {
        base: Scope = .{ .tag = .namespace },
        parent: *Scope,
        names: std.StringArrayHashMapUnmanaged(Ast.Node.Index) = .{},
        doctests: std.StringArrayHashMapUnmanaged(Ast.Node.Index) = .{},
        decl_index: Decl.Index,
        field_count: u32,
    };

    fn getNamespaceDecl(start_scope: *Scope) Decl.Index {
        var it: *Scope = start_scope;
        while (true) switch (it.tag) {
            .top => unreachable,
            .local => {
                const local: *Local = @alignCast(@fieldParentPtr("base", it));
                it = local.parent;
            },
            .namespace => {
                const namespace: *Namespace = @alignCast(@fieldParentPtr("base", it));
                return namespace.decl_index;
            },
        };
    }

    pub fn get_child(scope: *Scope, name: []const u8) ?Ast.Node.Index {
        switch (scope.tag) {
            .top, .local => return null,
            .namespace => {
                const namespace: *Namespace = @alignCast(@fieldParentPtr("base", scope));
                return namespace.names.get(name);
            },
        }
    }

    pub fn lookup(start_scope: *Scope, ast: *const Ast, name: []const u8) ?Ast.Node.Index {
        const main_tokens = ast.nodes.items(.main_token);
        var it: *Scope = start_scope;
        while (true) switch (it.tag) {
            .top => break,
            .local => {
                const local: *Local = @alignCast(@fieldParentPtr("base", it));
                const name_token = main_tokens[local.var_node] + 1;
                const ident_name = ast.tokenSlice(name_token);
                if (std.mem.eql(u8, ident_name, name)) {
                    return local.var_node;
                }
                it = local.parent;
            },
            .namespace => {
                const namespace: *Namespace = @alignCast(@fieldParentPtr("base", it));
                if (namespace.names.get(name)) |node| {
                    return node;
                }
                it = namespace.parent;
            },
        };
        return null;
    }
};

fn struct_decl(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    node: Ast.Node.Index,
    container_decl: Ast.full.ContainerDecl,
) Oom!void {
    const ast = w.file.get_ast();
    const node_tags = ast.nodes.items(.tag);
    const node_datas = ast.nodes.items(.data);

    const namespace = try gpa.create(Scope.Namespace);
    namespace.* = .{
        .parent = scope,
        .decl_index = parent_decl,
        .field_count = 0,
    };
    try w.file.get().scopes.putNoClobber(gpa, node, &namespace.base);
    try w.scanDecls(namespace, container_decl.ast.members);

    for (container_decl.ast.members) |member| switch (node_tags[member]) {
        .container_field_init,
        .container_field_align,
        .container_field,
        => try w.container_field(&namespace.base, parent_decl, ast.fullContainerField(member).?),

        .fn_proto,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto_simple,
        .fn_decl,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            const full = ast.fullFnProto(&buf, member).?;
            const fn_name_token = full.ast.fn_token + 1;
            const fn_name = ast.tokenSlice(fn_name_token);
            if (namespace.doctests.get(fn_name)) |doctest_node| {
                try w.file.get().doctests.put(gpa, member, doctest_node);
            }
            const decl_index = try w.file.add_decl(member, parent_decl);
            const body = if (node_tags[member] == .fn_decl) node_datas[member].rhs else 0;
            try w.fn_decl(&namespace.base, decl_index, body, full);
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            const decl_index = try w.file.add_decl(member, parent_decl);
            try w.global_var_decl(&namespace.base, decl_index, ast.fullVarDecl(member).?);
        },

        .@"comptime",
        .@"usingnamespace",
        => try w.expr(&namespace.base, parent_decl, node_datas[member].lhs),

        .test_decl => try w.expr(&namespace.base, parent_decl, node_datas[member].rhs),

        else => unreachable,
    };
}

fn comptime_decl(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    full: Ast.full.VarDecl,
) Oom!void {
    try w.expr(scope, parent_decl, full.ast.type_node);
    try w.maybe_expr(scope, parent_decl, full.ast.align_node);
    try w.maybe_expr(scope, parent_decl, full.ast.addrspace_node);
    try w.maybe_expr(scope, parent_decl, full.ast.section_node);
    try w.expr(scope, parent_decl, full.ast.init_node);
}

fn global_var_decl(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    full: Ast.full.VarDecl,
) Oom!void {
    try w.maybe_expr(scope, parent_decl, full.ast.type_node);
    try w.maybe_expr(scope, parent_decl, full.ast.align_node);
    try w.maybe_expr(scope, parent_decl, full.ast.addrspace_node);
    try w.maybe_expr(scope, parent_decl, full.ast.section_node);
    try w.maybe_expr(scope, parent_decl, full.ast.init_node);
}

fn container_field(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    full: Ast.full.ContainerField,
) Oom!void {
    try w.maybe_expr(scope, parent_decl, full.ast.type_expr);
    try w.maybe_expr(scope, parent_decl, full.ast.align_expr);
    try w.maybe_expr(scope, parent_decl, full.ast.value_expr);
}

fn fn_decl(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    body: Ast.Node.Index,
    full: Ast.full.FnProto,
) Oom!void {
    for (full.ast.params) |param| {
        try expr(w, scope, parent_decl, param);
    }
    try expr(w, scope, parent_decl, full.ast.return_type);
    try maybe_expr(w, scope, parent_decl, full.ast.align_expr);
    try maybe_expr(w, scope, parent_decl, full.ast.addrspace_expr);
    try maybe_expr(w, scope, parent_decl, full.ast.section_expr);
    try maybe_expr(w, scope, parent_decl, full.ast.callconv_expr);
    try maybe_expr(w, scope, parent_decl, body);
}

fn maybe_expr(w: *Walk, scope: *Scope, parent_decl: Decl.Index, node: Ast.Node.Index) Oom!void {
    if (node != 0) return expr(w, scope, parent_decl, node);
}

fn expr(w: *Walk, scope: *Scope, parent_decl: Decl.Index, node: Ast.Node.Index) Oom!void {
    assert(node != 0);
    const ast = w.file.get_ast();
    const node_tags = ast.nodes.items(.tag);
    const node_datas = ast.nodes.items(.data);
    const main_tokens = ast.nodes.items(.main_token);
    switch (node_tags[node]) {
        .root => unreachable, // Top-level declaration.
        .@"usingnamespace" => unreachable, // Top-level declaration.
        .test_decl => unreachable, // Top-level declaration.
        .container_field_init => unreachable, // Top-level declaration.
        .container_field_align => unreachable, // Top-level declaration.
        .container_field => unreachable, // Top-level declaration.
        .fn_decl => unreachable, // Top-level declaration.

        .global_var_decl => unreachable, // Handled in `block`.
        .local_var_decl => unreachable, // Handled in `block`.
        .simple_var_decl => unreachable, // Handled in `block`.
        .aligned_var_decl => unreachable, // Handled in `block`.
        .@"defer" => unreachable, // Handled in `block`.
        .@"errdefer" => unreachable, // Handled in `block`.

        .switch_case => unreachable, // Handled in `switchExpr`.
        .switch_case_inline => unreachable, // Handled in `switchExpr`.
        .switch_case_one => unreachable, // Handled in `switchExpr`.
        .switch_case_inline_one => unreachable, // Handled in `switchExpr`.

        .asm_output => unreachable, // Handled in `asmExpr`.
        .asm_input => unreachable, // Handled in `asmExpr`.

        .for_range => unreachable, // Handled in `forExpr`.

        .assign,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_and,
        .assign_bit_or,
        .assign_bit_xor,
        .assign_div,
        .assign_sub,
        .assign_sub_wrap,
        .assign_sub_sat,
        .assign_mod,
        .assign_add,
        .assign_add_wrap,
        .assign_add_sat,
        .assign_mul,
        .assign_mul_wrap,
        .assign_mul_sat,
        .shl,
        .shr,
        .add,
        .add_wrap,
        .add_sat,
        .sub,
        .sub_wrap,
        .sub_sat,
        .mul,
        .mul_wrap,
        .mul_sat,
        .div,
        .mod,
        .shl_sat,

        .bit_and,
        .bit_or,
        .bit_xor,
        .bang_equal,
        .equal_equal,
        .greater_than,
        .greater_or_equal,
        .less_than,
        .less_or_equal,
        .array_cat,

        .array_mult,
        .error_union,
        .merge_error_sets,
        .bool_and,
        .bool_or,
        .@"catch",
        .@"orelse",
        .array_type,
        .array_access,
        .switch_range,
        => {
            try expr(w, scope, parent_decl, node_datas[node].lhs);
            try expr(w, scope, parent_decl, node_datas[node].rhs);
        },

        .assign_destructure => {
            const full = ast.assignDestructure(node);
            for (full.ast.variables) |variable_node| try expr(w, scope, parent_decl, variable_node);
            _ = try expr(w, scope, parent_decl, full.ast.value_expr);
        },

        .bool_not,
        .bit_not,
        .negation,
        .negation_wrap,
        .@"return",
        .deref,
        .address_of,
        .optional_type,
        .unwrap_optional,
        .grouped_expression,
        .@"comptime",
        .@"nosuspend",
        .@"suspend",
        .@"await",
        .@"resume",
        .@"try",
        => try maybe_expr(w, scope, parent_decl, node_datas[node].lhs),

        .anyframe_type,
        .@"break",
        => try maybe_expr(w, scope, parent_decl, node_datas[node].rhs),

        .identifier => {
            const ident_token = main_tokens[node];
            const ident_name = ast.tokenSlice(ident_token);
            if (scope.lookup(ast, ident_name)) |var_node| {
                try w.file.get().ident_decls.put(gpa, ident_token, var_node);
            }
        },
        .field_access => {
            const object_node = node_datas[node].lhs;
            const dot_token = main_tokens[node];
            const field_ident = dot_token + 1;
            try w.file.get().token_parents.put(gpa, field_ident, node);
            // This will populate the left-most field object if it is an
            // identifier, allowing rendering code to piece together the link.
            try expr(w, scope, parent_decl, object_node);
        },

        .string_literal,
        .multiline_string_literal,
        .number_literal,
        .unreachable_literal,
        .enum_literal,
        .error_value,
        .anyframe_literal,
        .@"continue",
        .char_literal,
        .error_set_decl,
        => {},

        .asm_simple,
        .@"asm",
        => {
            const full = ast.fullAsm(node).?;
            for (full.ast.items) |n| {
                // There is a missing call here to expr() for .asm_input and
                // .asm_output nodes.
                _ = n;
            }
            try expr(w, scope, parent_decl, full.ast.template);
        },

        .builtin_call_two, .builtin_call_two_comma => {
            if (node_datas[node].lhs == 0) {
                const params = [_]Ast.Node.Index{};
                return builtin_call(w, scope, parent_decl, node, &params);
            } else if (node_datas[node].rhs == 0) {
                const params = [_]Ast.Node.Index{node_datas[node].lhs};
                return builtin_call(w, scope, parent_decl, node, &params);
            } else {
                const params = [_]Ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
                return builtin_call(w, scope, parent_decl, node, &params);
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = ast.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return builtin_call(w, scope, parent_decl, node, params);
        },

        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            const full = ast.fullCall(&buf, node).?;
            try expr(w, scope, parent_decl, full.ast.fn_expr);
            for (full.ast.params) |param| {
                try expr(w, scope, parent_decl, param);
            }
        },

        .if_simple,
        .@"if",
        => {
            const full = ast.fullIf(node).?;
            try expr(w, scope, parent_decl, full.ast.cond_expr);
            try expr(w, scope, parent_decl, full.ast.then_expr);
            try maybe_expr(w, scope, parent_decl, full.ast.else_expr);
        },

        .while_simple,
        .while_cont,
        .@"while",
        => {
            try while_expr(w, scope, parent_decl, ast.fullWhile(node).?);
        },

        .for_simple, .@"for" => {
            const full = ast.fullFor(node).?;
            for (full.ast.inputs) |input| {
                if (node_tags[input] == .for_range) {
                    try expr(w, scope, parent_decl, node_datas[input].lhs);
                    try maybe_expr(w, scope, parent_decl, node_datas[input].rhs);
                } else {
                    try expr(w, scope, parent_decl, input);
                }
            }
            try expr(w, scope, parent_decl, full.ast.then_expr);
            try maybe_expr(w, scope, parent_decl, full.ast.else_expr);
        },

        .slice => return slice(w, scope, parent_decl, ast.slice(node)),
        .slice_open => return slice(w, scope, parent_decl, ast.sliceOpen(node)),
        .slice_sentinel => return slice(w, scope, parent_decl, ast.sliceSentinel(node)),

        .block_two, .block_two_semicolon => {
            const statements = [2]Ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
            if (node_datas[node].lhs == 0) {
                return block(w, scope, parent_decl, statements[0..0]);
            } else if (node_datas[node].rhs == 0) {
                return block(w, scope, parent_decl, statements[0..1]);
            } else {
                return block(w, scope, parent_decl, statements[0..2]);
            }
        },
        .block, .block_semicolon => {
            const statements = ast.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return block(w, scope, parent_decl, statements);
        },

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => {
            const full = ast.fullPtrType(node).?;
            try maybe_expr(w, scope, parent_decl, full.ast.align_node);
            try maybe_expr(w, scope, parent_decl, full.ast.addrspace_node);
            try maybe_expr(w, scope, parent_decl, full.ast.sentinel);
            try maybe_expr(w, scope, parent_decl, full.ast.bit_range_start);
            try maybe_expr(w, scope, parent_decl, full.ast.bit_range_end);
            try expr(w, scope, parent_decl, full.ast.child_type);
        },

        .container_decl,
        .container_decl_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            return struct_decl(w, scope, parent_decl, node, ast.fullContainerDecl(&buf, node).?);
        },

        .array_type_sentinel => {
            const extra = ast.extraData(node_datas[node].rhs, Ast.Node.ArrayTypeSentinel);
            try expr(w, scope, parent_decl, node_datas[node].lhs);
            try expr(w, scope, parent_decl, extra.elem_type);
            try expr(w, scope, parent_decl, extra.sentinel);
        },
        .@"switch", .switch_comma => {
            const operand_node = node_datas[node].lhs;
            try expr(w, scope, parent_decl, operand_node);
            const extra = ast.extraData(node_datas[node].rhs, Ast.Node.SubRange);
            const case_nodes = ast.extra_data[extra.start..extra.end];
            for (case_nodes) |case_node| {
                const case = ast.fullSwitchCase(case_node).?;
                for (case.ast.values) |value_node| {
                    try expr(w, scope, parent_decl, value_node);
                }
                try expr(w, scope, parent_decl, case.ast.target_expr);
            }
        },

        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = ast.fullArrayInit(&buf, node).?;
            try maybe_expr(w, scope, parent_decl, full.ast.type_expr);
            for (full.ast.elements) |elem| {
                try expr(w, scope, parent_decl, elem);
            }
        },

        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = ast.fullStructInit(&buf, node).?;
            try maybe_expr(w, scope, parent_decl, full.ast.type_expr);
            for (full.ast.fields) |field| {
                try expr(w, scope, parent_decl, field);
            }
        },

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return fn_decl(w, scope, parent_decl, 0, ast.fullFnProto(&buf, node).?);
        },
    }
}

fn slice(w: *Walk, scope: *Scope, parent_decl: Decl.Index, full: Ast.full.Slice) Oom!void {
    try expr(w, scope, parent_decl, full.ast.sliced);
    try expr(w, scope, parent_decl, full.ast.start);
    try maybe_expr(w, scope, parent_decl, full.ast.end);
    try maybe_expr(w, scope, parent_decl, full.ast.sentinel);
}

fn builtin_call(
    w: *Walk,
    scope: *Scope,
    parent_decl: Decl.Index,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) Oom!void {
    const ast = w.file.get_ast();
    const main_tokens = ast.nodes.items(.main_token);
    const builtin_token = main_tokens[node];
    const builtin_name = ast.tokenSlice(builtin_token);
    if (std.mem.eql(u8, builtin_name, "@This")) {
        try w.file.get().node_decls.put(gpa, node, scope.getNamespaceDecl());
    }

    for (params) |param| {
        try expr(w, scope, parent_decl, param);
    }
}

fn block(
    w: *Walk,
    parent_scope: *Scope,
    parent_decl: Decl.Index,
    statements: []const Ast.Node.Index,
) Oom!void {
    const ast = w.file.get_ast();
    const node_tags = ast.nodes.items(.tag);
    const node_datas = ast.nodes.items(.data);

    var scope = parent_scope;

    for (statements) |node| {
        switch (node_tags[node]) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                const full = ast.fullVarDecl(node).?;
                try global_var_decl(w, scope, parent_decl, full);
                const local = try gpa.create(Scope.Local);
                local.* = .{
                    .parent = scope,
                    .var_node = node,
                };
                try w.file.get().scopes.putNoClobber(gpa, node, &local.base);
                scope = &local.base;
            },

            .assign_destructure => {
                log.debug("walk assign_destructure not implemented yet", .{});
            },

            .grouped_expression => try expr(w, scope, parent_decl, node_datas[node].lhs),

            .@"defer",
            .@"errdefer",
            => try expr(w, scope, parent_decl, node_datas[node].rhs),

            else => try expr(w, scope, parent_decl, node),
        }
    }
}

fn while_expr(w: *Walk, scope: *Scope, parent_decl: Decl.Index, full: Ast.full.While) Oom!void {
    try expr(w, scope, parent_decl, full.ast.cond_expr);
    try maybe_expr(w, scope, parent_decl, full.ast.cont_expr);
    try expr(w, scope, parent_decl, full.ast.then_expr);
    try maybe_expr(w, scope, parent_decl, full.ast.else_expr);
}

fn scanDecls(w: *Walk, namespace: *Scope.Namespace, members: []const Ast.Node.Index) Oom!void {
    const ast = w.file.get_ast();
    const node_tags = ast.nodes.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);
    const token_tags = ast.tokens.items(.tag);
    const node_datas = ast.nodes.items(.data);

    for (members) |member_node| {
        const name_token = switch (node_tags[member_node]) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => main_tokens[member_node] + 1,

            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            => blk: {
                const ident = main_tokens[member_node] + 1;
                if (token_tags[ident] != .identifier) continue;
                break :blk ident;
            },

            .test_decl => {
                const ident_token = node_datas[member_node].lhs;
                const is_doctest = token_tags[ident_token] == .identifier;
                if (is_doctest) {
                    const token_bytes = ast.tokenSlice(ident_token);
                    try namespace.doctests.put(gpa, token_bytes, member_node);
                }
                continue;
            },

            .container_field_init,
            .container_field_align,
            .container_field,
            => {
                namespace.field_count += 1;
                continue;
            },

            else => continue,
        };

        const token_bytes = ast.tokenSlice(name_token);
        try namespace.names.put(gpa, token_bytes, member_node);
    }
}

pub fn isPrimitiveNonType(name: []const u8) bool {
    return std.mem.eql(u8, name, "undefined") or
        std.mem.eql(u8, name, "null") or
        std.mem.eql(u8, name, "true") or
        std.mem.eql(u8, name, "false");
}

//test {
//    const gpa = std.testing.allocator;
//
//    var arena_instance = std.heap.ArenaAllocator.init(gpa);
//    defer arena_instance.deinit();
//    const arena = arena_instance.allocator();
//
//    // example test command:
//    // zig test --dep input.zig -Mroot=src/Walk.zig -Minput.zig=/home/andy/dev/zig/lib/std/fs/File/zig
//    var ast = try Ast.parse(gpa, @embedFile("input.zig"), .zig);
//    defer ast.deinit(gpa);
//
//    var w: Walk = .{
//        .arena = arena,
//        .token_links = .{},
//        .ast = &ast,
//    };
//
//    try w.root();
//}

const Walk = @This();
const std = @import("std");
const Ast = std.zig.Ast;
const assert = std.debug.assert;
const Decl = @import("Decl.zig");
const log = std.log;
const gpa = std.heap.wasm_allocator;
const Oom = error{OutOfMemory};

fn shrinkToFit(m: anytype) void {
    m.shrinkAndFree(gpa, m.entries.len);
}
