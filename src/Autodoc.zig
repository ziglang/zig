const std = @import("std");
const Autodoc = @This();
const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const File = Module.File;
const Zir = @import("Zir.zig");
const Ref = Zir.Inst.Ref;

module: *Module,
doc_location: Compilation.EmitLoc,
arena: std.mem.Allocator,
files: std.AutoHashMapUnmanaged(*File, usize) = .{},
calls: std.ArrayListUnmanaged(DocData.Call) = .{},
types: std.ArrayListUnmanaged(DocData.Type) = .{},
decls: std.ArrayListUnmanaged(DocData.Decl) = .{},
ast_nodes: std.ArrayListUnmanaged(DocData.AstNode) = .{},
comptime_exprs: std.ArrayListUnmanaged(DocData.ComptimeExpr) = .{},
decl_paths_pending_on_decls: std.AutoHashMapUnmanaged(
    usize,
    std.ArrayListUnmanaged(DeclPathResumeInfo),
) = .{},
decl_paths_pending_on_types: std.AutoHashMapUnmanaged(
    usize,
    std.ArrayListUnmanaged(DeclPathResumeInfo),
) = .{},

const DeclPathResumeInfo = struct {
    file: *File,
    path: []usize,
};

var arena_allocator: std.heap.ArenaAllocator = undefined;
pub fn init(m: *Module, doc_location: Compilation.EmitLoc) Autodoc {
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
    const abs_root_path = try std.fs.path.join(self.arena, &.{ dir, root_file_path });
    defer self.arena.free(abs_root_path);
    const file = self.module.import_table.get(abs_root_path).?;

    // append all the types in Zir.Inst.Ref
    {
        try self.types.append(self.arena, .{
            .ComptimeExpr = .{ .name = "ComptimeExpr" },
        });
        // this skipts Ref.none but it's ok becuse we replaced it with ComptimeExpr
        var i: u32 = 1;
        while (i <= @enumToInt(Ref.anyerror_void_error_union_type)) : (i += 1) {
            var tmpbuf = std.ArrayList(u8).init(self.arena);
            try Ref.typed_value_map[i].val.format("", .{}, tmpbuf.writer());
            try self.types.append(
                self.arena,
                switch (@intToEnum(Ref, i)) {
                    else => blk: {
                        //std.debug.print("TODO: categorize `{s}` in typeKinds\n", .{
                        //    @tagName(t),
                        //});
                        break :blk .{
                            .Array = .{
                                .len = 1,
                                .name = tmpbuf.toOwnedSlice(),
                                .child = .{ .type = 0 },
                            },
                        };
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
                    => .{
                        .Int = .{ .name = tmpbuf.toOwnedSlice() },
                    },
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f128_type,
                    => .{
                        .Float = .{ .name = tmpbuf.toOwnedSlice() },
                    },
                    .comptime_int_type => .{
                        .ComptimeInt = .{ .name = tmpbuf.toOwnedSlice() },
                    },
                    .comptime_float_type => .{
                        .ComptimeFloat = .{ .name = tmpbuf.toOwnedSlice() },
                    },

                    .bool_type => .{
                        .Bool = .{ .name = tmpbuf.toOwnedSlice() },
                    },

                    .void_type => .{
                        .Void = .{ .name = tmpbuf.toOwnedSlice() },
                    },
                    .type_type => .{
                        .Type = .{ .name = tmpbuf.toOwnedSlice() },
                    },
                },
            );
        }
    }

    var root_scope = Scope{ .parent = null };
    try self.ast_nodes.append(self.arena, .{ .name = "(root)" });
    try self.files.put(self.arena, file, self.types.items.len);
    const main_type_index = try self.walkInstruction(file, &root_scope, Zir.main_struct_inst);

    if (self.decl_paths_pending_on_decls.count() > 0) {
        @panic("some decl paths were never fully analized (pending on decls)");
    }

    if (self.decl_paths_pending_on_types.count() > 0) {
        @panic("some decl paths were never fully analized (pending on types)");
    }

    var data = DocData{
        .files = .{ .data = self.files },
        .calls = self.calls.items,
        .types = self.types.items,
        .decls = self.decls.items,
        .astNodes = self.ast_nodes.items,
        .comptimeExprs = self.comptime_exprs.items,
    };

    data.packages[0].main = main_type_index.type;

    if (self.doc_location.directory) |d| {
        d.handle.makeDir(
            self.doc_location.basename,
        ) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => unreachable,
        };
    } else {
        self.module.zig_cache_artifact_directory.handle.makeDir(
            self.doc_location.basename,
        ) catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => unreachable,
        };
    }
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
    typeKinds: []const []const u8 = std.meta.fieldNames(DocTypeKinds),
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
    errors: []struct {} = &.{},

    // non-hardcoded stuff
    astNodes: []AstNode,
    calls: []Call,
    files: struct {
        // this struct is a temporary hack to support json serialization
        data: std.AutoHashMapUnmanaged(*File, usize),
        pub fn jsonStringify(
            self: @This(),
            opt: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            var idx: usize = 0;
            var it = self.data.iterator();
            try w.writeAll("{\n");

            var options = opt;
            if (options.whitespace) |*ws| ws.indent_level += 1;
            while (it.next()) |kv| : (idx += 1) {
                if (options.whitespace) |ws| try ws.outputIndent(w);
                try w.print("\"{s}\": {d}", .{
                    kv.key_ptr.*.sub_file_path,
                    kv.value_ptr.*,
                });
                if (idx != self.data.count() - 1) try w.writeByte(',');
                try w.writeByte('\n');
            }
            if (opt.whitespace) |ws| try ws.outputIndent(w);
            try w.writeAll("}");
        }
    },
    types: []Type,
    decls: []Decl,
    comptimeExprs: []ComptimeExpr,
    const Call = struct {
        func: TypeRef,
        args: []WalkResult,
        ret: WalkResult,
    };
    const DocTypeKinds = blk: {
        var info = @typeInfo(std.builtin.TypeId);
        const original_len = info.Enum.fields.len;
        info.Enum.fields = info.Enum.fields ++ [2]std.builtin.TypeInfo.EnumField{
            .{
                .name = "ComptimeExpr",
                .value = original_len,
            },
            .{
                .name = "Unanalyzed",
                .value = original_len + 1,
            },
        };
        break :blk @Type(info);
    };

    const ComptimeExpr = struct {
        code: []const u8,
        typeRef: TypeRef,
    };
    const Package = struct {
        name: []const u8 = "root",
        file: usize = 0, // index into `files`
        main: usize = 0, // index into `decls`
        table: struct { root: usize } = .{
            .root = 0,
        },
    };

    const Decl = struct {
        name: []const u8,
        kind: []const u8,
        src: usize, // index into astNodes
        // typeRef: TypeRef,
        value: WalkResult,
        // The index in astNodes of the `test declname { }` node
        decltest: ?usize = null,
        _analyzed: bool, // omitted in json data
    };

    const AstNode = struct {
        file: usize = 0, // index into files
        line: usize = 0,
        col: usize = 0,
        name: ?[]const u8 = null,
        docs: ?[]const u8 = null,
        fields: ?[]usize = null, // index into astNodes
    };

    const Type = union(DocTypeKinds) {
        Unanalyzed: void,
        Type: struct { name: []const u8 },
        Void: struct { name: []const u8 },
        Bool: struct { name: []const u8 },
        NoReturn: struct { name: []const u8 },
        Int: struct { name: []const u8 },
        Float: struct { name: []const u8 },
        Pointer: struct {
            name: []const u8,
            child: TypeRef,
        },
        Array: struct {
            name: []const u8,
            len: usize,
            child: TypeRef,
        },
        Struct: struct {
            name: []const u8,
            src: ?usize = null, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: ?[]TypeRef = null, // (use src->fields to find names)
        },
        ComptimeExpr: struct { name: []const u8 },
        ComptimeFloat: struct { name: []const u8 },
        ComptimeInt: struct { name: []const u8 },
        Undefined: struct { name: []const u8 },
        Null: struct { name: []const u8 },
        Optional: struct {
            name: []const u8,
            child: TypeRef,
        },
        ErrorUnion: struct { name: []const u8 },
        ErrorSet: struct { name: []const u8 },
        Enum: struct {
            name: []const u8,
            src: ?usize = null, // index into astNodes
            privDecls: ?[]usize = null, // index into decls
            pubDecls: ?[]usize = null, // index into decls
            // (use src->fields to find field names)
        },
        Union: struct {
            name: []const u8,
            src: ?usize = null, // index into astNodes
            privDecls: ?[]usize = null, // index into decls
            pubDecls: ?[]usize = null, // index into decls
            fields: ?[]TypeRef = null, // (use src->fields to find names)
        },
        Fn: struct {
            name: []const u8,
            src: ?usize = null, // index into astNodes
            ret: TypeRef,
            params: ?[]TypeRef = null, // (use src->fields to find names)
        },
        BoundFn: struct { name: []const u8 },
        Opaque: struct { name: []const u8 },
        Frame: struct { name: []const u8 },
        AnyFrame: struct { name: []const u8 },
        Vector: struct { name: []const u8 },
        EnumLiteral: struct { name: []const u8 },

        pub fn jsonStringify(
            self: Type,
            opt: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            try w.print(
                \\{{ "kind": {},
                \\
            , .{@enumToInt(std.meta.activeTag(self))});
            var options = opt;
            if (options.whitespace) |*ws| ws.indent_level += 1;
            switch (self) {
                .Array => |v| try printTypeBody(v, options, w),
                .Bool => |v| try printTypeBody(v, options, w),
                .Void => |v| try printTypeBody(v, options, w),
                .ComptimeExpr => |v| try printTypeBody(v, options, w),
                .ComptimeInt => |v| try printTypeBody(v, options, w),
                .ComptimeFloat => |v| try printTypeBody(v, options, w),
                .Null => |v| try printTypeBody(v, options, w),
                .Optional => |v| try printTypeBody(v, options, w),

                .Struct => |v| try printTypeBody(v, options, w),
                .Fn => |v| try printTypeBody(v, options, w),
                .Union => |v| try printTypeBody(v, options, w),
                .Enum => |v| try printTypeBody(v, options, w),
                .Int => |v| try printTypeBody(v, options, w),
                .Float => |v| try printTypeBody(v, options, w),
                .Type => |v| try printTypeBody(v, options, w),
                else => {
                    std.debug.print(
                        "TODO: add {s} to `DocData.Type.jsonStringify`\n",
                        .{@tagName(self)},
                    );
                },
            }
            try w.print("}}", .{});
        }

        fn printTypeBody(
            body: anytype,
            options: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            const fields = std.meta.fields(@TypeOf(body));
            inline for (fields) |f, idx| {
                if (options.whitespace) |ws| try ws.outputIndent(w);
                try w.print("\"{s}\": ", .{f.name});
                try std.json.stringify(@field(body, f.name), options, w);
                if (idx != fields.len - 1) try w.writeByte(',');
                try w.writeByte('\n');
            }
            if (options.whitespace) |ws| {
                var up = ws;
                up.indent_level -= 1;
                try up.outputIndent(w);
            }
        }
    };

    const TypeRef = union(enum) {
        unspecified,
        declPath: []usize, // indexes in `decls`
        type: usize, // index in `types`
        comptimeExpr: usize, // index in `comptimeExprs`

        pub fn fromWalkResult(wr: WalkResult) TypeRef {
            return switch (wr) {
                .declPath => |v| .{ .declPath = v },
                .type => |v| .{ .type = v },
                else => @panic("Found non-type WalkResult"),
            };
        }

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

                .type, .comptimeExpr => |v| {
                    try w.print(
                        \\{{ "{s}":{} }}
                    , .{ @tagName(self), v });
                },
                .declPath => |v| {
                    try w.print("{{ \"declPath\": [", .{});
                    for (v) |d, i| {
                        const comma = if (i == v.len - 1) "]}" else ",";
                        try w.print("{d}{s}", .{ d, comma });
                    }
                },
            }
        }
    };

    const WalkResult = union(enum) {
        comptimeExpr: usize, // index in `comptimeExprs`
        void,
        @"unreachable",
        @"null": TypeRef,
        @"undefined": TypeRef,
        @"struct": Struct,
        bool: bool,
        type: usize, // index in `types`
        declPath: []usize, // indices in `decl`
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
        call: usize, // index in `calls`

        const Struct = struct {
            typeRef: TypeRef,
            fieldVals: []struct {
                name: []const u8,
                val: WalkResult,
            },
        };
        pub fn jsonStringify(
            self: WalkResult,
            options: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            switch (self) {
                .void, .@"unreachable" => {
                    try w.print(
                        \\{{ "{s}":{{}} }}
                    , .{@tagName(self)});
                },
                .type, .comptimeExpr, .call => |v| {
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
                .@"struct" => |v| try std.json.stringify(
                    struct { @"struct": Struct }{ .@"struct" = v },
                    options,
                    w,
                ),
                .declPath => |v| {
                    try w.print("{{ \"declPath\": [", .{});
                    for (v) |d, i| {
                        const comma = if (i == v.len - 1) "]}" else ",";
                        try w.print("{d}{s}", .{ d, comma });
                    }
                },
            }
        }
    };
};

fn walkInstruction(
    self: *Autodoc,
    file: *File,
    parent_scope: *Scope,
    inst_index: usize,
) error{OutOfMemory}!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    // We assume that the topmost ast_node entry corresponds to our decl
    const self_ast_node_index = self.ast_nodes.items.len - 1;

    switch (tags[inst_index]) {
        else => {
            std.debug.panic(
                "TODO: implement `walkInstruction` for {s}\n\n",
                .{@tagName(tags[inst_index])},
            );
        },
        .import => {
            const str_tok = data[inst_index].str_tok;
            const path = str_tok.get(file.zir);
            // importFile cannot error out since all files
            // are already loaded at this point
            const new_file = self.module.importFile(file, path) catch unreachable;
            const result = try self.files.getOrPut(self.arena, new_file.file);
            if (result.found_existing) {
                return DocData.WalkResult{ .type = result.value_ptr.* };
            }

            result.value_ptr.* = self.types.items.len;

            var new_scope = Scope{ .parent = null };
            const new_file_walk_result = self.walkInstruction(
                new_file.file,
                &new_scope,
                Zir.main_struct_inst,
            );

            return new_file_walk_result;
        },

        .int => {
            const int = data[inst_index].int;
            return DocData.WalkResult{
                .int = .{
                    .typeRef = .{
                        .type = @enumToInt(Ref.comptime_int_type),
                    },
                    .value = int,
                },
            };
        },
        .float => {
            const float = data[inst_index].float;
            return DocData.WalkResult{
                .float = .{
                    .typeRef = .{
                        .type = @enumToInt(Ref.comptime_float_type),
                    },
                    .value = float,
                },
            };
        },
        .negate => {
            const un_node = data[inst_index].un_node;
            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
            );
            operand.int.negated = true; // only support ints for now
            return operand;
        },
        .as_node => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.As, pl_node.payload_index);
            const dest_type_walk = try self.walkRef(file, parent_scope, extra.data.dest_type);
            const dest_type_ref = walkResultToTypeRef(dest_type_walk);

            var operand = try self.walkRef(file, parent_scope, extra.data.operand);

            switch (operand) {
                else => std.debug.panic(
                    "TODO: handle {s} in `walkInstruction.as_node`\n",
                    .{@tagName(operand)},
                ),
                .declPath, .type => {},
                // we don't do anything because up until now,
                // I've only seen this used as such:
                //       @as(@as(type, Baz), .{})
                // and we don't want to toss away the
                // decl_val information (eg by replacing it with
                // a WalkResult.type).
                // TODO: Actually, this is a good moment to check if
                // the result is indeed a type!!
                .comptimeExpr => {
                    self.comptime_exprs.items[operand.comptimeExpr].typeRef = dest_type_ref;
                },
                .int => operand.int.typeRef = dest_type_ref,
                .@"struct" => operand.@"struct".typeRef = dest_type_ref,
                .@"undefined" => operand.@"undefined" = dest_type_ref,
            }

            return operand;
        },
        .optional_type => {
            const un_node = data[inst_index].un_node;
            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
            );
            const type_ref = walkResultToTypeRef(operand);
            const res = DocData.WalkResult{ .type = self.types.items.len };
            try self.types.append(self.arena, .{
                .Optional = .{ .name = "?TODO", .child = type_ref },
            });
            return res;
        },
        .decl_val => {
            const str_tok = data[inst_index].str_tok;
            const decls_slot_index = parent_scope.resolveDeclName(str_tok.start);
            var path = try self.arena.alloc(usize, 1);
            path[0] = decls_slot_index;
            return DocData.WalkResult{ .declPath = path };
        },
        .field_val => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Field, pl_node.payload_index);

            var path: std.ArrayListUnmanaged(usize) = .{};
            var lhs = @enumToInt(extra.data.lhs) - Ref.typed_value_map.len; // underflow = need to handle Refs

            try path.append(self.arena, extra.data.field_name_start);
            // Put inside path the starting index of each decl name
            // that we encounter as we navigate through all the field_vals
            while (tags[lhs] == .field_val) {
                const lhs_extra = file.zir.extraData(
                    Zir.Inst.Field,
                    data[lhs].pl_node.payload_index,
                );

                try path.append(self.arena, lhs_extra.data.field_name_start);
                lhs = @enumToInt(lhs_extra.data.lhs) - Ref.typed_value_map.len; // underflow = need to handle Refs
            }

            if (tags[lhs] != .decl_val) {
                @panic("TODO: handle non-decl_val endings in walkInstruction.field_val");
            }
            const str_tok = data[lhs].str_tok;
            const decls_slot_index = parent_scope.resolveDeclName(str_tok.start);
            try path.append(self.arena, decls_slot_index);

            // Righ now, every element of `path` is the first index of a
            // decl name except for the final element, which instead points to
            // the analyzed data corresponding to the top-most decl of this path.
            // We are now going to reverse loop over `path` to resolve each name
            // to its corresponding index in `decls`.
            try self.tryResolveDeclPath(file, path.items);
            return DocData.WalkResult{ .declPath = path.items };
        },
        .int_type => {
            const int_type = data[inst_index].int_type;
            const sign = if (int_type.signedness == .unsigned) "u" else "i";
            const bits = int_type.bit_count;
            const name = try std.fmt.allocPrint(self.arena, "{s}{}", .{ sign, bits });

            try self.types.append(self.arena, .{
                .Int = .{ .name = name },
            });
            return DocData.WalkResult{ .type = self.types.items.len - 1 };
        },
        .block => {
            const res = DocData.WalkResult{ .comptimeExpr = self.comptime_exprs.items.len };
            try self.comptime_exprs.append(self.arena, .{
                .code = "if(banana) 1 else 0",
                .typeRef = .{ .type = 0 },
            });
            return res;
        },
        .block_inline => {
            return self.walkRef(file, parent_scope, getBlockInlineBreak(file.zir, inst_index));
        },
        .call => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Call, pl_node.payload_index);

            // TODO: handle the way scoping works with fn args
            const callee = DocData.TypeRef.fromWalkResult(
                try self.walkRef(file, parent_scope, extra.data.callee),
            );

            const args_len = extra.data.flags.args_len;
            var args = try self.arena.alloc(DocData.WalkResult, args_len);
            const arg_refs = file.zir.refSlice(extra.end, args_len);
            for (arg_refs) |ref, idx| {
                args[idx] = try self.walkRef(file, parent_scope, ref);
            }

            const call_slot_index = self.calls.items.len;
            try self.calls.append(self.arena, .{
                .func = callee,
                .args = args,
                .ret = .{ .void = {} }, // TODO: handle returns!
            });

            return DocData.WalkResult{ .call = call_slot_index };
        },
        .func => {
            const fn_info = file.zir.getFnInfo(@intCast(u32, inst_index));

            // TODO: change this to a resize and change the appends accordingly
            try self.ast_nodes.ensureUnusedCapacity(self.arena, fn_info.total_params_len);
            try self.types.ensureUnusedCapacity(self.arena, fn_info.total_params_len);
            var param_type_refs = try std.ArrayListUnmanaged(DocData.TypeRef).initCapacity(
                self.arena,
                fn_info.total_params_len,
            );
            var param_ast_indexes = try std.ArrayListUnmanaged(usize).initCapacity(
                self.arena,
                fn_info.total_params_len,
            );
            for (fn_info.param_body[0..fn_info.total_params_len]) |param_index| {
                if (tags[param_index] != .param) unreachable; // TODO: handle more param types
                const pl_tok = data[param_index].pl_tok;
                const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
                const doc_comment = if (extra.data.doc_comment != 0)
                    file.zir.nullTerminatedString(extra.data.doc_comment)
                else
                    "";

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                try self.ast_nodes.append(self.arena, .{
                    .name = file.zir.nullTerminatedString(extra.data.name),
                    .docs = doc_comment,
                });

                const break_index = file.zir.extra[extra.end..][extra.data.body_len - 1];
                const break_operand = data[break_index].@"break".operand;
                const param_type_ref = try self.walkRef(file, parent_scope, break_operand);

                param_type_refs.appendAssumeCapacity(
                    DocData.TypeRef.fromWalkResult(param_type_ref),
                );
            }

            // ret
            const ret_type_ref = blk: {
                const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
                const break_operand = data[last_instr_index].@"break".operand;
                const wr = try self.walkRef(file, parent_scope, break_operand);
                break :blk DocData.TypeRef.fromWalkResult(wr);
            };

            self.ast_nodes.items[self_ast_node_index].fields = param_ast_indexes.items;
            try self.types.append(self.arena, .{
                .Fn = .{
                    .name = "todo_name func",
                    .src = self_ast_node_index,
                    .params = param_type_refs.items,
                    .ret = ret_type_ref,
                },
            });
            return DocData.WalkResult{ .type = self.types.items.len - 1 };
        },
        .extended => {
            // TODO: this assumes that we always return a type when analyzing
            //       an extended instruction. Also we willingfully not reserve
            //       a slot for functions (handled right above) despite them
            //       being stored in `types`. The reason why we reserve a slot
            //       in here, is for decl paths and their resolution system.
            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .Unanalyzed = {} });

            defer {
                if (self.decl_paths_pending_on_types.get(type_slot_index)) |paths| {
                    for (paths.items) |resume_info| {
                        self.tryResolveDeclPath(resume_info.file, resume_info.path) catch {
                            @panic("Out of memory");
                        };
                    }

                    _ = self.decl_paths_pending_on_types.remove(type_slot_index);
                    // TODO: we should deallocate the arraylist that holds all the
                    //       decl paths. not doing it now since it's arena-allocated
                    //       anyway, but maybe we should put it elsewhere.
                }
            }

            const extended = data[inst_index].extended;
            switch (extended.opcode) {
                else => {
                    std.debug.panic(
                        "TODO: implement `walkinstruction.extended` for {s}\n\n",
                        .{@tagName(extended.opcode)},
                    );
                },
                .union_decl => {
                    var scope: Scope = .{ .parent = parent_scope };

                    const small = @bitCast(Zir.Inst.UnionDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;

                    const src_node: ?i32 = if (small.has_src_node) blk: {
                        const src_node = @bitCast(i32, file.zir.extra[extra_index]);
                        extra_index += 1;
                        break :blk src_node;
                    } else null;
                    _ = src_node;

                    const tag_type: ?Ref = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk @intToEnum(Ref, tag_type);
                    } else null;
                    _ = tag_type;

                    const body_len = if (small.has_body_len) blk: {
                        const body_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk body_len;
                    } else 0;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;
                    _ = fields_len;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = file.zir.extra[extra_index];
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
                        var it = file.zir.declIterator(@intCast(u32, inst_index));
                        try self.decls.resize(self.arena, decls_first_index + it.decls_len);
                        for (self.decls.items[decls_first_index..]) |*slot| {
                            slot._analyzed = false;
                        }
                        var decls_slot_index = decls_first_index;
                        while (it.next()) |d| : (decls_slot_index += 1) {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            try scope.insertDeclRef(self.arena, decl_name_index, decls_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    // const body = file.zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_type_refs = try std.ArrayListUnmanaged(DocData.TypeRef).initCapacity(
                        self.arena,
                        fields_len,
                    );
                    var field_name_indexes = try std.ArrayListUnmanaged(usize).initCapacity(
                        self.arena,
                        fields_len,
                    );
                    try self.collectUnionFieldInfo(
                        file,
                        &scope,
                        fields_len,
                        &field_type_refs,
                        &field_name_indexes,
                        extra_index,
                    );

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    self.types.items[type_slot_index] = .{
                        .Union = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                            .fields = field_type_refs.items,
                        },
                    };

                    return DocData.WalkResult{ .type = type_slot_index };
                },
                .enum_decl => {
                    var scope: Scope = .{ .parent = parent_scope };

                    const small = @bitCast(Zir.Inst.EnumDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;

                    const src_node: ?i32 = if (small.has_src_node) blk: {
                        const src_node = @bitCast(i32, file.zir.extra[extra_index]);
                        extra_index += 1;
                        break :blk src_node;
                    } else null;
                    _ = src_node;

                    const tag_type: ?Ref = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk @intToEnum(Ref, tag_type);
                    } else null;
                    _ = tag_type;

                    const body_len = if (small.has_body_len) blk: {
                        const body_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk body_len;
                    } else 0;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;
                    _ = fields_len;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = file.zir.extra[extra_index];
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
                        var it = file.zir.declIterator(@intCast(u32, inst_index));
                        try self.decls.resize(self.arena, decls_first_index + it.decls_len);
                        for (self.decls.items[decls_first_index..]) |*slot| {
                            slot._analyzed = false;
                        }
                        var decls_slot_index = decls_first_index;
                        while (it.next()) |d| : (decls_slot_index += 1) {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            try scope.insertDeclRef(self.arena, decl_name_index, decls_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    // const body = file.zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    {
                        var bit_bag_idx = extra_index;
                        var cur_bit_bag: u32 = undefined;
                        extra_index += std.math.divCeil(usize, fields_len, 32) catch unreachable;

                        var idx: usize = 0;
                        while (idx < fields_len) : (idx += 1) {
                            if (idx % 32 == 0) {
                                cur_bit_bag = file.zir.extra[bit_bag_idx];
                                bit_bag_idx += 1;
                            }

                            const has_value = @truncate(u1, cur_bit_bag) != 0;
                            cur_bit_bag >>= 1;

                            const field_name_index = file.zir.extra[extra_index];
                            extra_index += 1;

                            const doc_comment_index = file.zir.extra[extra_index];
                            extra_index += 1;

                            const value_ref: ?Ref = if (has_value) blk: {
                                const value_ref = file.zir.extra[extra_index];
                                extra_index += 1;
                                break :blk @intToEnum(Ref, value_ref);
                            } else null;
                            _ = value_ref;

                            const field_name = file.zir.nullTerminatedString(field_name_index);

                            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
                            const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
                                file.zir.nullTerminatedString(doc_comment_index)
                            else
                                null;
                            try self.ast_nodes.append(self.arena, .{
                                .name = field_name,
                                .docs = doc_comment,
                            });
                        }
                    }

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    self.types.items[type_slot_index] = .{
                        .Enum = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                        },
                    };

                    return DocData.WalkResult{ .type = type_slot_index };
                },
                .struct_decl => {
                    var scope: Scope = .{ .parent = parent_scope };

                    const small = @bitCast(Zir.Inst.StructDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;

                    const src_node: ?i32 = if (small.has_src_node) blk: {
                        const src_node = @bitCast(i32, file.zir.extra[extra_index]);
                        extra_index += 1;
                        break :blk src_node;
                    } else null;
                    _ = src_node;

                    const body_len = if (small.has_body_len) blk: {
                        const body_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk body_len;
                    } else 0;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;
                    _ = fields_len;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = file.zir.extra[extra_index];
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
                        var it = file.zir.declIterator(@intCast(u32, inst_index));
                        try self.decls.resize(self.arena, decls_first_index + it.decls_len);
                        for (self.decls.items[decls_first_index..]) |*slot| {
                            slot._analyzed = false;
                        }
                        var decls_slot_index = decls_first_index;
                        while (it.next()) |d| : (decls_slot_index += 1) {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            try scope.insertDeclRef(self.arena, decl_name_index, decls_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    // const body = file.zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_type_refs: std.ArrayListUnmanaged(DocData.TypeRef) = .{};
                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    try self.collectStructFieldInfo(
                        file,
                        &scope,
                        fields_len,
                        &field_type_refs,
                        &field_name_indexes,
                        extra_index,
                    );

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    self.types.items[type_slot_index] = .{
                        .Struct = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                            .fields = field_type_refs.items,
                        },
                    };

                    return DocData.WalkResult{ .type = type_slot_index };
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
    file: *File,
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
            cur_bit_bag = file.zir.extra[bit_bag_index];
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

        // const hash_u32s = file.zir.extra[extra_index..][0..4];
        extra_index += 4;
        const line = file.zir.extra[extra_index];
        extra_index += 1;
        const decl_name_index = file.zir.extra[extra_index];
        extra_index += 1;
        const decl_index = file.zir.extra[extra_index];
        extra_index += 1;
        const doc_comment_index = file.zir.extra[extra_index];
        extra_index += 1;

        // const align_inst: Zir.Inst.Ref = if (!has_align) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        //     extra_index += 1;
        //     break :inst inst;
        // };
        // const section_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        //     extra_index += 1;
        //     break :inst inst;
        // };
        // const addrspace_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
        //     const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
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
            } else if (decl_name_index == 2) {
                // it is a decltest
                const decl_being_tested = scope.resolveDeclName(doc_comment_index);
                const ast_node_index = idx: {
                    const idx = self.ast_nodes.items.len;
                    const file_source = file.getSource(self.module.gpa) catch unreachable; // TODO fix this
                    const source_of_decltest_function = srcloc: {
                        const func_index = getBlockInlineBreak(file.zir, decl_index);
                        // a decltest is always a function
                        const tag = file.zir.instructions.items(.tag)[Zir.refToIndex(func_index).?];
                        std.debug.assert(tag == .extended);

                        const extended = file.zir.instructions.items(.data)[Zir.refToIndex(func_index).?].extended;
                        const extra = file.zir.extraData(Zir.Inst.ExtendedFunc, extended.operand);
                        const small = @bitCast(Zir.Inst.ExtendedFunc.Small, extended.small);

                        var extra_index_for_this_func: usize = extra.end;
                        if (small.has_lib_name) extra_index_for_this_func += 1;
                        if (small.has_cc) extra_index_for_this_func += 1;
                        if (small.has_align) extra_index_for_this_func += 1;

                        const ret_ty_body = file.zir.extra[extra_index_for_this_func..][0..extra.data.ret_body_len];
                        extra_index_for_this_func += ret_ty_body.len;

                        const body = file.zir.extra[extra_index_for_this_func..][0..extra.data.body_len];
                        extra_index_for_this_func += body.len;

                        var src_locs: Zir.Inst.Func.SrcLocs = undefined;
                        if (body.len != 0) {
                            src_locs = file.zir.extraData(Zir.Inst.Func.SrcLocs, extra_index_for_this_func).data;
                        } else {
                            src_locs = .{
                                .lbrace_line = line,
                                .rbrace_line = line,
                                .columns = 0, // TODO get columns when body.len == 0
                            };
                        }
                        break :srcloc src_locs;
                    };
                    const source_slice = slice: {
                        var start_byte_offset: u32 = 0;
                        var end_byte_offset: u32 = 0;
                        const rbrace_col = @truncate(u16, source_of_decltest_function.columns >> 16);
                        var lines: u32 = 0;
                        for (file_source.bytes) |b, i| {
                            if (b == '\n') {
                                lines += 1;
                            }
                            if (lines == source_of_decltest_function.lbrace_line) {
                                start_byte_offset = @intCast(u32, i);
                            }
                            if (lines == source_of_decltest_function.rbrace_line) {
                                end_byte_offset = @intCast(u32, i) + rbrace_col;
                                break;
                            }
                        }
                        break :slice file_source.bytes[start_byte_offset..end_byte_offset];
                    };
                    try self.ast_nodes.append(self.arena, .{
                        .file = 0,
                        .line = line,
                        .col = 0,
                        .name = try self.arena.dupe(u8, source_slice),
                    });
                    break :idx idx;
                };
                self.decls.items[decl_being_tested].decltest = ast_node_index;
                self.decls.items[decls_slot_index] = .{
                    ._analyzed = true,
                    .name = "test",
                    .src = ast_node_index,
                    .value = .{ .type = 0 },
                    .kind = "const",
                };
                continue;
            } else {
                const raw_decl_name = file.zir.nullTerminatedString(decl_name_index);
                if (raw_decl_name.len == 0) {
                    break :blk file.zir.nullTerminatedString(decl_name_index + 1);
                } else {
                    break :blk raw_decl_name;
                }
            }
        };

        const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
            file.zir.nullTerminatedString(doc_comment_index)
        else
            null;

        // astnode
        const ast_node_index = idx: {
            const idx = self.ast_nodes.items.len;
            try self.ast_nodes.append(self.arena, .{
                .file = 0,
                .line = line,
                .col = 0,
                .docs = doc_comment,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            break :idx idx;
        };

        const walk_result = try self.walkInstruction(file, scope, decl_index);

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
            ._analyzed = true,
            .name = name,
            .src = ast_node_index,
            // .typeRef = decl_type_ref,
            .value = walk_result,
            .kind = "const", // find where this information can be found
        };

        // Unblock any pending decl path that was waiting for this decl.
        if (self.decl_paths_pending_on_decls.get(decls_slot_index)) |paths| {
            for (paths.items) |resume_info| {
                try self.tryResolveDeclPath(resume_info.file, resume_info.path);
            }

            _ = self.decl_paths_pending_on_decls.remove(decls_slot_index);
            // TODO: we should deallocate the arraylist that holds all the
            //       decl paths. not doing it now since it's arena-allocated
            //       anyway, but maybe we should put it elsewhere.
        }
    }

    return extra_index;
}

/// An unresolved path has a decl index at its end, while every other element
/// is an index into the string table. Resolving means resolving iteratively
/// each string into a decl_index. If we encounter an unanalyzed decl during
/// the process, we append the unsolved sub-path to `self.decl_paths_pending_on_decls`
/// and bail out.
fn tryResolveDeclPath(
    self: *Autodoc,
    /// File from which the decl path originates.
    file: *File,
    path: []usize,
) !void {
    var i: usize = path.len;
    while (i > 1) {
        i -= 1;
        const decl_index = path[i];
        const string_index = path[i - 1];

        const parent = self.decls.items[decl_index];
        if (!parent._analyzed) {
            const res = try self.decl_paths_pending_on_decls.getOrPut(self.arena, decl_index);
            if (!res.found_existing) res.value_ptr.* = .{};
            try res.value_ptr.*.append(self.arena, .{
                .file = file,
                .path = path[0 .. i + 1],
            });
            return;
        }

        const child_decl_name = file.zir.nullTerminatedString(string_index);
        switch (parent.value) {
            else => {
                std.debug.panic(
                    "TODO: handle `{s}`in walkInstruction.field_val\n",
                    .{@tagName(parent.value)},
                );
            },
            .type => |t_index| switch (self.types.items[t_index]) {
                else => {
                    std.debug.panic(
                        "TODO: handle `{s}` in tryResolveDeclPath.type\n",
                        .{@tagName(self.types.items[t_index])},
                    );
                },
                .Unanalyzed => {
                    const res = try self.decl_paths_pending_on_types.getOrPut(
                        self.arena,
                        t_index,
                    );
                    if (!res.found_existing) res.value_ptr.* = .{};
                    try res.value_ptr.*.append(self.arena, .{
                        .file = file,
                        .path = path[0 .. i + 1],
                    });
                    return;
                },
                .Struct => |t_struct| {
                    for (t_struct.pubDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_decl_name)) {
                            path[i - 1] = d;
                            continue;
                        }
                    }
                    for (t_struct.privDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_decl_name)) {
                            path[i - 1] = d;
                            continue;
                        }
                    }
                },
            },
        }
    }
}

fn collectUnionFieldInfo(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    fields_len: usize,
    field_type_refs: *std.ArrayListUnmanaged(DocData.TypeRef),
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
            cur_bit_bag = file.zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const has_type = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_tag = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const unused = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        _ = unused;

        const field_name = file.zir.nullTerminatedString(file.zir.extra[extra_index]);
        extra_index += 1;
        const doc_comment_index = file.zir.extra[extra_index];
        extra_index += 1;
        const field_type = if (has_type)
            @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index])
        else
            .void_type;
        extra_index += 1;

        if (has_align) extra_index += 1;
        if (has_tag) extra_index += 1;

        // type
        {
            const walk_result = try self.walkRef(file, scope, field_type);
            try field_type_refs.append(
                self.arena,
                walkResultToTypeRef(walk_result),
            );
        }

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
                file.zir.nullTerminatedString(doc_comment_index)
            else
                null;
            try self.ast_nodes.append(self.arena, .{
                .name = field_name,
                .docs = doc_comment,
            });
        }
    }
}

fn collectStructFieldInfo(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    fields_len: usize,
    field_type_refs: *std.ArrayListUnmanaged(DocData.TypeRef),
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
            cur_bit_bag = file.zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_default = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        // const is_comptime = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const unused = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        _ = unused;

        const field_name = file.zir.nullTerminatedString(file.zir.extra[extra_index]);
        extra_index += 1;
        const field_type = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        extra_index += 1;
        const doc_comment_index = file.zir.extra[extra_index];
        extra_index += 1;

        if (has_align) extra_index += 1;
        if (has_default) extra_index += 1;

        // type
        {
            const walk_result = try self.walkRef(file, scope, field_type);
            try field_type_refs.append(
                self.arena,
                walkResultToTypeRef(walk_result),
            );
        }

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
                file.zir.nullTerminatedString(doc_comment_index)
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
    file: *File,
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
        return self.walkInstruction(file, parent_scope, zir_index);
    }
}

fn walkResultToTypeRef(wr: DocData.WalkResult) DocData.TypeRef {
    return switch (wr) {
        else => std.debug.panic(
            "TODO: handle `{s}` in `walkResultToTypeRef.as_node.dest_type`\n",
            .{@tagName(wr)},
        ),

        .declPath => |v| .{ .declPath = v },
        .type => |v| .{ .type = v },
    };
}

//fn collectParamInfo(self: *Autodoc, file: *File, scope: *Scope, inst_idx: Zir.Index) void {

//}
fn getBlockInlineBreak(zir: Zir, inst_index: usize) Zir.Inst.Ref {
    const data = zir.instructions.items(.data);
    const pl_node = data[inst_index].pl_node;
    const extra = zir.extraData(Zir.Inst.Block, pl_node.payload_index);
    const break_index = zir.extra[extra.end..][extra.data.body_len - 1];
    return data[break_index].@"break".operand;
}
