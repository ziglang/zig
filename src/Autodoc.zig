const std = @import("std");
const Autodoc = @This();
const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const Zir = @import("Zir.zig");

module: *Module,
doc_location: Compilation.EmitLoc,

pub fn init(m: *Module, dl: Compilation.EmitLoc) Autodoc {
    return .{
        .doc_location = dl,
        .module = m,
    };
}

pub fn generateZirData(self: Autodoc) !void {
    const gpa = self.module.gpa;
    std.debug.print("yay, you called me!\n", .{});
    if (self.doc_location.directory) |dir| {
        if (dir.path) |path| {
            std.debug.print("path: {s}\n", .{path});
        }
    }
    std.debug.print("basename: {s}\n", .{self.doc_location.basename});

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const dir =
        if (self.module.main_pkg.root_src_directory.path) |rp|
        std.os.realpath(rp, &buf) catch unreachable
    else
        std.os.getcwd(&buf) catch unreachable;
    const root_file_path = self.module.main_pkg.root_src_path;
    const abs_root_path = try std.fs.path.join(gpa, &.{ dir, root_file_path });
    defer gpa.free(abs_root_path);
    const zir = self.module.import_table.get(abs_root_path).?.zir;

    var types = std.ArrayList(DocData.Type).init(gpa);
    var decls = std.ArrayList(DocData.Decl).init(gpa);
    var ast_nodes = std.ArrayList(DocData.AstNode).init(gpa);

    // var decl_map = std.AutoHashMap(Zir.Inst.Index, usize); // values are positions in the `decls` array

    try types.append(.{
        .kind = 0,
        .name = "type",
    });
    // append all the types in Zir.Inst.Ref
    {
        // we don't count .none
        var i: u32 = 1;
        while (i <= @enumToInt(Zir.Inst.Ref.anyerror_void_error_union_type)) : (i += 1) {
            var tmpbuf = std.ArrayList(u8).init(gpa);
            try Zir.Inst.Ref.typed_value_map[i].val.format("", .{}, tmpbuf.writer());
            try types.append(.{
                .kind = 0,
                .name = tmpbuf.toOwnedSlice(),
            });
        }
    }

    var root_scope: Scope = .{ .parent = null };
    try ast_nodes.append(.{ .name = "(root)" });
    const main_type_index = try walkInstruction(zir, gpa, &root_scope, &types, &decls, &ast_nodes, Zir.main_struct_inst);

    var data = DocData{
        .files = &[1][]const u8{root_file_path},
        .types = types.items,
        .decls = decls.items,
        .astNodes = ast_nodes.items,
    };

    data.packages[0].main = main_type_index.type;

    if (self.doc_location.directory) |d|
        (d.handle.makeDir(self.doc_location.basename) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => unreachable,
        })
    else
        (self.module.zig_cache_artifact_directory.handle.makeDir(self.doc_location.basename) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => unreachable,
        });
    const output_dir = if (self.doc_location.directory) |d|
        (d.handle.openDir(self.doc_location.basename, .{}) catch unreachable)
    else
        (self.module.zig_cache_artifact_directory.handle.openDir(self.doc_location.basename, .{}) catch unreachable);
    const data_js_f = output_dir.createFile("data.js", .{}) catch unreachable;
    defer data_js_f.close();
    const out = data_js_f.writer();
    out.print("zigAnalysis=", .{}) catch unreachable;
    std.json.stringify(
        data,
        .{
            .whitespace = .{},
            .emit_null_optional_fields = false,
        },
        out,
    ) catch unreachable;
    out.print(";", .{}) catch unreachable;
    // copy main.js, index.html
    const special = try self.module.comp.zig_lib_directory.join(gpa, &.{ "std", "special", "docs", std.fs.path.sep_str });
    var special_dir = std.fs.openDirAbsolute(special, .{}) catch unreachable;
    defer special_dir.close();
    special_dir.copyFile("main.js", output_dir, "main.js", .{}) catch unreachable;
    special_dir.copyFile("index.html", output_dir, "index.html", .{}) catch unreachable;
}

const Scope = struct {
    parent: ?*Scope,
    map: std.AutoHashMapUnmanaged(u32, usize) = .{}, // index into `decls`

    /// Assumes all decls in present scope and upper scopes have already
    /// been either fully resolved or at least reserved.
    pub fn resolveDeclName(self: Scope, string_table_idx: u32) usize {
        var cur: ?*const Scope = &self;
        return while (cur) |s| : (cur = s.parent) {
            break s.map.get(string_table_idx) orelse continue;
        } else unreachable;
    }

    pub fn insertDeclRef(
        self: *Scope,
        gpa: std.mem.Allocator,
        decl_name_index: u32, // decl name
        decls_slot_index: usize,
    ) !void {
        try self.map.put(gpa, decl_name_index, decls_slot_index);
    }
};

const DocData = struct {
    typeKinds: []const []const u8 = std.meta.fieldNames(std.builtin.TypeId),
    rootPkg: u32 = 0,
    params: struct {
        zigId: []const u8 = "arst",
        zigVersion: []const u8 = "arst",
        target: []const u8 = "arst",
        rootName: []const u8 = "arst",
        builds: []const struct { target: []const u8 } = &.{
            .{ .target = "arst" },
        },
    } = .{},
    packages: [1]Package = .{.{}},
    fns: []struct {} = &.{},
    errors: []struct {} = &.{},
    calls: []struct {} = &.{},

    // non-hardcoded stuff
    astNodes: []AstNode,
    files: []const []const u8,
    types: []Type,
    decls: []Decl,

    const Package = struct {
        name: []const u8 = "root",
        file: usize = 0, // index into files
        main: usize = 0, // index into decls
        table: struct { root: usize } = .{
            .root = 0,
        },
    };

    const Decl = struct {
        name: []const u8,
        kind: []const u8, // TODO: where do we find this info?
        src: usize, // index into astNodes
        type: usize, // index into types
        value: usize,
    };

    const AstNode = struct {
        file: usize = 0, // index into files
        line: usize = 0,
        col: usize = 0,
        name: ?[]const u8 = null,
        docs: ?[]const u8 = null,
        fields: ?[]usize = null, // index into astNodes
    };

    const Type = struct {
        kind: u32, // index into typeKinds
        name: []const u8,
        src: ?usize = null, // index into astNodes
        privDecls: ?[]usize = null, // index into decls
        pubDecls: ?[]usize = null, // index into decls
        fields: ?[]WalkResult = null, // (use src->fields to find names)
    };

    const WalkResult = union(enum) {
        failure: bool,
        type: usize, // index in `types`
        decl_ref: usize, // index in `decls`

        pub fn jsonStringify(
            self: WalkResult,
            _: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            switch (self) {
                .failure => |v| {
                    try w.print(
                        \\{{ "failure":{} }}
                    , .{v});
                },
                .type, .decl_ref => |v| {
                    try w.print(
                        \\{{ "{s}":{} }}
                    , .{ @tagName(self), v });
                },

                // .decl_ref => |v| {
                //     try w.print(
                //         \\{{ "{s}":"{s}" }}
                //     , .{ @tagName(self), v });
                // },
            }
        }
    };
};

fn walkInstruction(
    zir: Zir,
    gpa: std.mem.Allocator,
    parent_scope: *Scope,
    types: *std.ArrayList(DocData.Type),
    decls: *std.ArrayList(DocData.Decl),
    ast_nodes: *std.ArrayList(DocData.AstNode),
    inst_index: usize,
) error{OutOfMemory}!DocData.WalkResult {
    const tags = zir.instructions.items(.tag);
    const data = zir.instructions.items(.data);

    // We assume that the topmost ast_node entry corresponds to our decl
    const self_ast_node_index = ast_nodes.items.len - 1;

    switch (tags[inst_index]) {
        else => {
            std.debug.print(
                "TODO: implement `walkInstruction` for {s}\n\n",
                .{@tagName(tags[inst_index])},
            );
            return DocData.WalkResult{ .failure = true };
        },
        .decl_val => {
            const str_tok = data[inst_index].str_tok;
            const decls_slot_index = parent_scope.resolveDeclName(str_tok.start);
            return DocData.WalkResult{ .decl_ref = decls_slot_index };
        },
        .int_type => {
            const int_type = data[inst_index].int_type;
            const sign = if (int_type.signedness == .unsigned) "u" else "i";
            const bits = int_type.bit_count;
            const name = try std.fmt.allocPrint(gpa, "{s}{}", .{ sign, bits });

            try types.append(.{
                .kind = @enumToInt(std.builtin.TypeId.Int),
                .name = name,
            });
            return DocData.WalkResult{ .type = types.items.len - 1 };
        },
        .block_inline => {
            const pl_node = data[inst_index].pl_node;
            const extra = zir.extraData(Zir.Inst.Block, pl_node.payload_index);
            const break_index = zir.extra[extra.end..][extra.data.body_len - 1];

            std.debug.print("[instr: {}] body len: {} last instr idx: {}\n", .{
                inst_index,
                extra.data.body_len,
                break_index,
            });

            const break_operand = data[break_index].@"break".operand;
            return if (Zir.refToIndex(break_operand)) |bi|
                walkInstruction(zir, gpa, parent_scope, types, decls, ast_nodes, bi)
            else if (@enumToInt(break_operand) <= @enumToInt(Zir.Inst.Ref.anyerror_void_error_union_type))
                // we append all the types in ref first, so we can just do this if we encounter a ref that is a type
                return DocData.WalkResult{ .type = @enumToInt(break_operand) }
            else
                std.debug.todo("generate WalkResults for refs that are not types");
        },
        .extended => {
            const extended = data[inst_index].extended;
            switch (extended.opcode) {
                else => {
                    std.debug.print(
                        "TODO: implement `walkInstruction` (inside .extended case) for {s}\n\n",
                        .{@tagName(extended.opcode)},
                    );
                    return DocData.WalkResult{ .failure = true };
                },
                .struct_decl => {
                    var scope: Scope = .{ .parent = parent_scope };

                    const small = @bitCast(Zir.Inst.StructDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;

                    const src_node: ?i32 = if (small.has_src_node) blk: {
                        const src_node = @bitCast(i32, zir.extra[extra_index]);
                        extra_index += 1;
                        break :blk src_node;
                    } else null;
                    _ = src_node;

                    const body_len = if (small.has_body_len) blk: {
                        const body_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :blk body_len;
                    } else 0;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;
                    _ = fields_len;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :blk decls_len;
                    } else 0;

                    var decl_indexes = std.ArrayList(usize).init(gpa);
                    var priv_decl_indexes = std.ArrayList(usize).init(gpa);

                    const decls_first_index = decls.items.len;
                    // Decl name lookahead for reserving slots in `scope` (and `decls`).
                    // Done to make sure that all decl refs can be resolved correctly,
                    // even if we haven't fully analyzed the decl yet.
                    {
                        var it = zir.declIterator(@intCast(u32, inst_index));
                        try decls.resize(decls_first_index + it.decls_len);
                        var decls_slot_index = decls_first_index;
                        while (it.next()) |d| : (decls_slot_index += 1) {
                            const decl_name_index = zir.extra[d.sub_index + 5];
                            try scope.insertDeclRef(gpa, decl_name_index, decls_slot_index);
                        }
                    }

                    extra_index = try walkDecls(
                        zir,
                        gpa,
                        &scope,
                        decls,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        types,
                        ast_nodes,
                        extra_index,
                    );

                    // const body = zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_type_indexes = std.ArrayList(DocData.WalkResult).init(gpa);
                    var field_name_indexes = std.ArrayList(usize).init(gpa);
                    try collectFieldInfo(
                        zir,
                        gpa,
                        &scope,
                        types,
                        decls,
                        fields_len,
                        &field_type_indexes,
                        &field_name_indexes,
                        ast_nodes,
                        extra_index,
                    );

                    ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    try types.append(.{
                        .kind = @enumToInt(std.builtin.TypeId.Struct),
                        .name = "todo_name",
                        .src = self_ast_node_index,
                        .privDecls = priv_decl_indexes.items,
                        .pubDecls = decl_indexes.items,
                        .fields = field_type_indexes.items,
                    });

                    return DocData.WalkResult{ .type = types.items.len - 1 };
                },
            }
        },
    }
}

fn walkDecls(
    zir: Zir,
    gpa: std.mem.Allocator,
    scope: *Scope,
    decls: *std.ArrayList(DocData.Decl),
    decls_first_index: usize,
    decls_len: u32,
    decl_indexes: *std.ArrayList(usize),
    priv_decl_indexes: *std.ArrayList(usize),
    types: *std.ArrayList(DocData.Type),
    ast_nodes: *std.ArrayList(DocData.AstNode),
    extra_start: usize,
) error{OutOfMemory}!usize {
    const bit_bags_count = std.math.divCeil(usize, decls_len, 8) catch unreachable;
    var extra_index = extra_start + bit_bags_count;
    var bit_bag_index: usize = extra_start;
    var cur_bit_bag: u32 = undefined;
    var decl_i: u32 = 0;

    while (decl_i < decls_len) : (decl_i += 1) {
        const decls_slot_index = decls_first_index + decl_i;

        if (decl_i % 8 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const is_pub = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const is_exported = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        // const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        // const has_section_or_addrspace = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        // const sub_index = extra_index;

        // const hash_u32s = zir.extra[extra_index..][0..4];
        extra_index += 4;
        // const line = zir.extra[extra_index];
        extra_index += 1;
        const decl_name_index = zir.extra[extra_index];
        extra_index += 1;
        const decl_index = zir.extra[extra_index];
        extra_index += 1;
        const doc_comment_index = zir.extra[extra_index];
        extra_index += 1;

        // const align_inst: Zir.Inst.Ref = if (!has_align) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        //     extra_index += 1;
        //     break :inst inst;
        // };
        // const section_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        //     extra_index += 1;
        //     break :inst inst;
        // };
        // const addrspace_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        //     extra_index += 1;
        //     break :inst inst;
        // };

        // const pub_str = if (is_pub) "pub " else "";
        // const hash_bytes = @bitCast([16]u8, hash_u32s.*);

        const name: []const u8 = blk: {
            if (decl_name_index == 0) {
                break :blk if (is_exported) "usingnamespace" else "comptime";
            } else if (decl_name_index == 1) {
                break :blk "test";
            } else {
                const raw_decl_name = zir.nullTerminatedString(decl_name_index);
                if (raw_decl_name.len == 0) {
                    break :blk zir.nullTerminatedString(decl_name_index + 1);
                } else {
                    break :blk raw_decl_name;
                }
            }
        };

        const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
            zir.nullTerminatedString(doc_comment_index)
        else
            null;

        // astnode
        const ast_node_index = idx: {
            const idx = ast_nodes.items.len;
            try ast_nodes.append(.{
                .file = 0,
                .line = 0,
                .col = 0,
                .docs = doc_comment,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            break :idx idx;
        };

        const walk_result = try walkInstruction(zir, gpa, scope, types, decls, ast_nodes, decl_index);
        const type_index = walk_result.type;

        if (is_pub) {
            try decl_indexes.append(decls_slot_index);
        } else {
            try priv_decl_indexes.append(decls_slot_index);
        }

        decls.items[decls_slot_index] = .{
            .name = name,
            .src = ast_node_index,
            .type = 0,
            .value = type_index,
            .kind = "const", // find where this information can be found
        };
    }

    return extra_index;
}

fn collectFieldInfo(
    zir: Zir,
    gpa: std.mem.Allocator,
    scope: *Scope,
    types: *std.ArrayList(DocData.Type),
    decls: *std.ArrayList(DocData.Decl),
    fields_len: usize,
    field_type_indexes: *std.ArrayList(DocData.WalkResult),
    field_name_indexes: *std.ArrayList(usize),
    ast_nodes: *std.ArrayList(DocData.AstNode),
    ei: usize,
) !void {
    if (fields_len == 0) return;
    var extra_index = ei;

    const bits_per_field = 4;
    const fields_per_u32 = 32 / bits_per_field;
    const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
    var bit_bag_index: usize = extra_index;
    extra_index += bit_bags_count;

    var cur_bit_bag: u32 = undefined;
    var field_i: u32 = 0;
    while (field_i < fields_len) : (field_i += 1) {
        if (field_i % fields_per_u32 == 0) {
            cur_bit_bag = zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        // const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        // const has_default = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        // const is_comptime = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const unused = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        _ = unused;

        const field_name = zir.nullTerminatedString(zir.extra[extra_index]);
        extra_index += 1;
        const field_type = @intToEnum(Zir.Inst.Ref, zir.extra[extra_index]);
        extra_index += 1;
        const doc_comment_index = zir.extra[extra_index];
        extra_index += 1;

        // type
        {
            switch (field_type) {
                .void_type => {
                    try field_type_indexes.append(.{ .type = types.items.len });
                    try types.append(.{
                        .kind = @enumToInt(std.builtin.TypeId.Void),
                        .name = "void",
                    });
                },
                .usize_type => {
                    try field_type_indexes.append(.{ .type = types.items.len });
                    try types.append(.{
                        .kind = @enumToInt(std.builtin.TypeId.Int),
                        .name = "usize",
                    });
                },

                else => {
                    const enum_value = @enumToInt(field_type);
                    if (enum_value < Zir.Inst.Ref.typed_value_map.len) {
                        std.debug.print(
                            "TODO: handle ref type: {s}",
                            .{@tagName(field_type)},
                        );
                        try field_type_indexes.append(DocData.WalkResult{ .failure = true });
                    } else {
                        const zir_index = enum_value - Zir.Inst.Ref.typed_value_map.len;
                        const walk_result = try walkInstruction(
                            zir,
                            gpa,
                            scope,
                            types,
                            decls,
                            ast_nodes,
                            zir_index,
                        );
                        try field_type_indexes.append(walk_result);
                    }
                },
            }
        }

        // ast node
        {
            try field_name_indexes.append(ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
                zir.nullTerminatedString(doc_comment_index)
            else
                null;
            try ast_nodes.append(.{
                .name = field_name,
                .docs = doc_comment,
            });
        }
    }
}
