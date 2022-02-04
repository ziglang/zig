const std = @import("std");
const Autodoc = @This();
const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const Zir = @import("Zir.zig");
const Ref = Zir.Inst.Ref;

module: *Module,
doc_location: ?Compilation.EmitLoc,
arena: std.mem.Allocator,
types: std.ArrayListUnmanaged(DocData.Type) = .{},
decls: std.ArrayListUnmanaged(DocData.Decl) = .{},
ast_nodes: std.ArrayListUnmanaged(DocData.AstNode) = .{},

var arena_allocator: std.heap.ArenaAllocator = undefined;
pub fn init(m: *Module, doc_location: ?Compilation.EmitLoc) Autodoc {
    arena_allocator = std.heap.ArenaAllocator.init(m.gpa);
    return .{
        .module = m,
        .doc_location = doc_location,
        .arena = arena_allocator.allocator(),
    };
}

pub fn deinit(_: *Autodoc) void {
    arena_allocator.deinit();
}

pub fn generateZirData(self: *Autodoc) !void {
    if (self.doc_location) |loc| {
        if (loc.directory) |dir| {
            if (dir.path) |path| {
                std.debug.print("path: {s}\n", .{path});
            }
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
    const abs_root_path = try std.fs.path.join(self.arena, &.{ dir, root_file_path });
    defer self.arena.free(abs_root_path);
    const zir = self.module.import_table.get(abs_root_path).?.zir;

    // var decl_map = std.AutoHashMap(Zir.Inst.Index, usize); // values are positions in the `decls` array

    // append all the types in Zir.Inst.Ref
    {

        // TODO: we don't want to add .none, but the index math has to check out
        var i: u32 = 0;
        while (i <= @enumToInt(Ref.anyerror_void_error_union_type)) : (i += 1) {
            var tmpbuf = std.ArrayList(u8).init(self.arena);
            try Ref.typed_value_map[i].val.format("", .{}, tmpbuf.writer());
            try self.types.append(self.arena, .{
                .name = tmpbuf.toOwnedSlice(),
                .kind = switch (@intToEnum(Ref, i)) {
                    else => |t| blk: {
                        std.debug.print("TODO: categorize `{s}` in typeKinds\n", .{
                            @tagName(t),
                        });
                        break :blk 7;
                    },
                    .u1_type,
                    .u8_type,
                    .i8_type,
                    .u16_type,
                    .i16_type,
                    .u32_type,
                    .i32_type,
                    .u64_type,
                    .i64_type,
                    .u128_type,
                    .i128_type,
                    .usize_type,
                    .isize_type,
                    .c_short_type,
                    .c_ushort_type,
                    .c_int_type,
                    .c_uint_type,
                    .c_long_type,
                    .c_ulong_type,
                    .c_longlong_type,
                    .c_ulonglong_type,
                    .c_longdouble_type,
                    => @enumToInt(std.builtin.TypeId.Int),
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f128_type,
                    => @enumToInt(std.builtin.TypeId.Float),
                    .comptime_int_type => @enumToInt(std.builtin.TypeId.ComptimeInt),
                    .comptime_float_type => @enumToInt(std.builtin.TypeId.ComptimeFloat),
                    .bool_type => @enumToInt(std.builtin.TypeId.Bool),
                    .void_type => @enumToInt(std.builtin.TypeId.Void),
                    .type_type => @enumToInt(std.builtin.TypeId.Type),
                },
            });
        }
    }

    var root_scope: Scope = .{ .parent = null };
    try self.ast_nodes.append(self.arena, .{ .name = "(root)" });
    const main_type_index = try self.walkInstruction(zir, &root_scope, Zir.main_struct_inst);

    var data = DocData{
        .files = &[1][]const u8{root_file_path},
        .types = self.types.items,
        .decls = self.decls.items,
        .astNodes = self.ast_nodes.items,
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
    const special = try self.module.comp.zig_lib_directory.join(self.arena, &.{ "std", "special", "docs", std.fs.path.sep_str });
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
        arena: std.mem.Allocator,
        decl_name_index: u32, // decl name
        decls_slot_index: usize,
    ) !void {
        try self.map.put(arena, decl_name_index, decls_slot_index);
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
        // typeRef: TypeRef,
        value: WalkResult,
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
    const TypeRef = union(enum) {
        unspecified,
        declRef: usize, // index in `decls`
        type: usize, // index in `types`
        pub fn jsonStringify(
            self: TypeRef,
            _: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            switch (self) {
                .unspecified => {
                    try w.print(
                        \\{{ "unspecified":{{}} }}
                    , .{});
                },
                .declRef, .type => |v| {
                    try w.print(
                        \\{{ "{s}":{} }}
                    , .{ @tagName(self), v });
                },
            }
        }
    };

    const WalkResult = union(enum) {
        void,
        @"unreachable",
        @"null": TypeRef,
        @"undefined": TypeRef,
        @"struct": struct {
            typeRef: TypeRef,
            fieldVals: []struct {
                name: []const u8,
                val: WalkResult,
            },
        },
        bool: bool,
        type: usize, // index in `types`
        declRef: usize, // index in `decls`
        int: struct {
            typeRef: TypeRef,
            value: usize, // direct value
            negated: bool = false,
        },
        float: struct {
            typeRef: TypeRef,
            value: f64, // direct value
            negated: bool = false,
        },
        pub fn jsonStringify(
            self: WalkResult,
            options: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            switch (self) {
                .void,
                .@"unreachable",
                => {
                    try w.print(
                        \\{{ "{s}":{{}} }}
                    , .{@tagName(self)});
                },
                .type, .declRef => |v| {
                    try w.print(
                        \\{{ "{s}":{} }}
                    , .{ @tagName(self), v });
                },
                .int => |v| {
                    const neg = if (v.negated) "-" else "";
                    try w.print(
                        \\{{ "int": {{ "typeRef": 
                    , .{});
                    try v.typeRef.jsonStringify(options, w);
                    try w.print(
                        \\, "value": {s}{} }} }}
                    , .{ neg, v.value });
                },
                .float => |v| {
                    const neg = if (v.negated) "-" else "";
                    try w.print(
                        \\{{ "float": {{ "typeRef": 
                    , .{});
                    try v.typeRef.jsonStringify(options, w);
                    try w.print(
                        \\, "value": {s}{} }} }}
                    , .{ neg, v.value });
                },
                .bool => |v| {
                    try w.print(
                        \\{{ "bool":{} }}
                    , .{v});
                },
                .@"undefined" => |v| try std.json.stringify(v, options, w),
                .@"null" => |v| try std.json.stringify(v, options, w),
                .@"struct" => |v| try std.json.stringify(v, options, w),
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
    self: *Autodoc,
    zir: Zir,
    parent_scope: *Scope,
    inst_index: usize,
) error{OutOfMemory}!DocData.WalkResult {
    const tags = zir.instructions.items(.tag);
    const data = zir.instructions.items(.data);

    // We assume that the topmost ast_node entry corresponds to our decl
    const self_ast_node_index = self.ast_nodes.items.len - 1;

    switch (tags[inst_index]) {
        else => {
            std.debug.panic(
                "TODO: implement `walkInstruction` for {s}\n\n",
                .{@tagName(tags[inst_index])},
            );
        },
        .int => {
            const int = data[inst_index].int;
            return DocData.WalkResult{
                .int = .{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .value = int,
                },
            };
        },
        .float => {
            const float = data[inst_index].float;
            return DocData.WalkResult{
                .float = .{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_float_type) },
                    .value = float,
                },
            };
        },
        .negate => {
            const un_node = data[inst_index].un_node;
            var operand = try self.walkRef(zir, parent_scope, un_node.operand);
            operand.int.negated = true; // only support ints for now
            return operand;
        },
        .as_node => {
            const pl_node = data[inst_index].pl_node;
            const extra = zir.extraData(Zir.Inst.As, pl_node.payload_index);
            const dest_type_walk = try self.walkRef(zir, parent_scope, extra.data.dest_type);
            const dest_type_ref = walkResultToTypeRef(dest_type_walk);

            var operand = try self.walkRef(zir, parent_scope, extra.data.operand);

            switch (operand) {
                else => std.debug.panic(
                    "TODO: handle {s} in `walkInstruction.as_node`\n",
                    .{@tagName(operand)},
                ),
                .declRef => {},
                // we don't do anything because up until now,
                // I've only seen this used as such:
                //       @as(@as(type, Baz), .{})
                // and we don't want to toss away the
                // decl_val information (eg by replacing it with
                // a WalkResult.type).

                .int => operand.int.typeRef = dest_type_ref,
                .@"struct" => operand.@"struct".typeRef = dest_type_ref,
                .@"undefined" => operand.@"undefined" = dest_type_ref,
            }

            return operand;
        },
        .decl_val => {
            const str_tok = data[inst_index].str_tok;
            const decls_slot_index = parent_scope.resolveDeclName(str_tok.start);
            return DocData.WalkResult{ .declRef = decls_slot_index };
        },
        .int_type => {
            const int_type = data[inst_index].int_type;
            const sign = if (int_type.signedness == .unsigned) "u" else "i";
            const bits = int_type.bit_count;
            const name = try std.fmt.allocPrint(self.arena, "{s}{}", .{ sign, bits });

            try self.types.append(self.arena, .{
                .kind = @enumToInt(std.builtin.TypeId.Int),
                .name = name,
            });
            return DocData.WalkResult{ .type = self.types.items.len - 1 };
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
            return self.walkRef(zir, parent_scope, break_operand);
        },
        .extended => {
            const extended = data[inst_index].extended;
            switch (extended.opcode) {
                else => {
                    std.debug.panic(
                        "TODO: implement `walkInstruction` (inside .extended case) for {s}\n\n",
                        .{@tagName(extended.opcode)},
                    );
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

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    const decls_first_index = self.decls.items.len;
                    // Decl name lookahead for reserving slots in `scope` (and `decls`).
                    // Done to make sure that all decl refs can be resolved correctly,
                    // even if we haven't fully analyzed the decl yet.
                    {
                        var it = zir.declIterator(@intCast(u32, inst_index));
                        try self.decls.resize(self.arena, decls_first_index + it.decls_len);
                        var decls_slot_index = decls_first_index;
                        while (it.next()) |d| : (decls_slot_index += 1) {
                            const decl_name_index = zir.extra[d.sub_index + 5];
                            try scope.insertDeclRef(self.arena, decl_name_index, decls_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        zir,
                        &scope,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    // const body = zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_type_indexes: std.ArrayListUnmanaged(DocData.WalkResult) = .{};
                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    try self.collectFieldInfo(
                        zir,
                        &scope,
                        fields_len,
                        &field_type_indexes,
                        &field_name_indexes,
                        extra_index,
                    );

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    try self.types.append(self.arena, .{
                        .kind = @enumToInt(std.builtin.TypeId.Struct),
                        .name = "todo_name",
                        .src = self_ast_node_index,
                        .privDecls = priv_decl_indexes.items,
                        .pubDecls = decl_indexes.items,
                        .fields = field_type_indexes.items,
                    });

                    return DocData.WalkResult{ .type = self.types.items.len - 1 };
                },
            }
        },
    }
}

/// Called by `walkInstruction` when encountering a container type, 
/// iterates over all decl definitions in its body.
/// It also analyzes each decl's body recursively. 
///
/// Does not append to `self.decls` directly because `walkInstruction` 
/// is expected to (look-ahead) scan all decls and reserve `body_len` 
/// slots in `self.decls`, which are then filled out by `walkDecls`.
fn walkDecls(
    self: *Autodoc,
    zir: Zir,
    scope: *Scope,
    decls_first_index: usize,
    decls_len: u32,
    decl_indexes: *std.ArrayListUnmanaged(usize),
    priv_decl_indexes: *std.ArrayListUnmanaged(usize),
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
            const idx = self.ast_nodes.items.len;
            try self.ast_nodes.append(self.arena, .{
                .file = 0,
                .line = 0,
                .col = 0,
                .docs = doc_comment,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            break :idx idx;
        };

        const walk_result = try self.walkInstruction(zir, scope, decl_index);

        if (is_pub) {
            try decl_indexes.append(self.arena, decls_slot_index);
        } else {
            try priv_decl_indexes.append(self.arena, decls_slot_index);
        }

        // // decl.typeRef == decl.val...typeRef
        // const decl_type_ref: DocData.TypeRef = switch (walk_result) {
        //     .int => |i| i.typeRef,
        //     .void => .{ .type = @enumToInt(Ref.void_type) },
        //     .@"undefined", .@"null" => |v| v,
        //     .@"unreachable" => .{ .type = @enumToInt(Ref.noreturn_type) },
        //     .@"struct" => |s| s.typeRef,
        //     .bool => .{ .type = @enumToInt(Ref.bool_type) },
        //     .type => .{ .type = @enumToInt(Ref.type_type) },
        //     // this last case is special becauese it's not pointing
        //     // at the type of the value, but rather at the value itself
        //     // the js better be aware ot this!
        //     .declRef => |d| .{ .declRef = d },
        // };

        self.decls.items[decls_slot_index] = .{
            .name = name,
            .src = ast_node_index,
            // .typeRef = decl_type_ref,
            .value = walk_result,
            .kind = "const", // find where this information can be found
        };
    }

    return extra_index;
}

fn collectFieldInfo(
    self: *Autodoc,
    zir: Zir,
    scope: *Scope,
    fields_len: usize,
    field_type_indexes: *std.ArrayListUnmanaged(DocData.WalkResult),
    field_name_indexes: *std.ArrayListUnmanaged(usize),
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
            const walk_result = try self.walkRef(zir, scope, field_type);
            try field_type_indexes.append(self.arena, walk_result);
        }

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
                zir.nullTerminatedString(doc_comment_index)
            else
                null;
            try self.ast_nodes.append(self.arena, .{
                .name = field_name,
                .docs = doc_comment,
            });
        }
    }
}

fn walkRef(
    self: *Autodoc,
    zir: Zir,
    parent_scope: *Scope,
    ref: Ref,
) !DocData.WalkResult {
    const enum_value = @enumToInt(ref);
    if (enum_value <= @enumToInt(Ref.anyerror_void_error_union_type)) {
        // We can just return a type that indexes into `types` with the
        // enum value because in the beginning we pre-filled `types` with
        // the types that are listed in `Ref`.
        return DocData.WalkResult{ .type = enum_value };
    } else if (enum_value < Ref.typed_value_map.len) {
        switch (ref) {
            else => {
                std.debug.panic("TODO: handle {s} in `walkRef`\n", .{
                    @tagName(ref),
                });
            },
            .undef => {
                return DocData.WalkResult{ .@"undefined" = .unspecified };
            },
            .zero => {
                return DocData.WalkResult{ .int = .{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .value = 0,
                } };
            },
            .one => {
                return DocData.WalkResult{ .int = .{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .value = 1,
                } };
            },

            .void_value => {
                return DocData.WalkResult{ .void = {} };
            },
            .unreachable_value => {
                return DocData.WalkResult{ .@"unreachable" = {} };
            },
            .null_value => {
                return DocData.WalkResult{ .@"null" = .unspecified };
            },
            .bool_true => {
                return DocData.WalkResult{ .bool = true };
            },
            .bool_false => {
                return DocData.WalkResult{ .bool = false };
            },
            .empty_struct => {
                return DocData.WalkResult{ .@"struct" = .{
                    .typeRef = .unspecified,
                    .fieldVals = &.{},
                } };
            },
            .zero_usize => {
                return DocData.WalkResult{ .int = .{
                    .typeRef = .{ .type = @enumToInt(Ref.usize_type) },
                    .value = 0,
                } };
            },
            .one_usize => {
                return DocData.WalkResult{ .int = .{
                    .typeRef = .{ .type = @enumToInt(Ref.usize_type) },
                    .value = 1,
                } };
            },
            // TODO: dunno what to do with those
            // .calling_convention_c => {
            //     return DocData.WalkResult{ .int = .{
            //         .type = @enumToInt(Ref.comptime_int_type),
            //         .value = 1,
            //     } };
            // },
            // .calling_convention_inline => {
            //     return DocData.WalkResult{ .int = .{
            //         .type = @enumToInt(Ref.comptime_int_type),
            //         .value = 1,
            //     } };
            // },
            // .generic_poison => {
            //     return DocData.WalkResult{ .int = .{
            //         .type = @enumToInt(Ref.comptime_int_type),
            //         .value = 1,
            //     } };
            // },
        }
    } else {
        const zir_index = enum_value - Ref.typed_value_map.len;
        return self.walkInstruction(zir, parent_scope, zir_index);
    }
}

fn walkResultToTypeRef(wr: DocData.WalkResult) DocData.TypeRef {
    return switch (wr) {
        else => std.debug.panic(
            "TODO: handle `{s}` in `walkInstruction.as_node.dest_type`\n",
            .{@tagName(wr)},
        ),

        .declRef => |v| .{ .declRef = v },
        .type => |v| .{ .type = v },
    };
}
