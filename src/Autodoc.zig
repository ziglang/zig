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

// The goal of autodoc is to fill up these arrays
// that will then be serialized as JSON and consumed
// by the JS frontend.
files: std.AutoHashMapUnmanaged(*File, usize) = .{},
calls: std.ArrayListUnmanaged(DocData.Call) = .{},
types: std.ArrayListUnmanaged(DocData.Type) = .{},
decls: std.ArrayListUnmanaged(DocData.Decl) = .{},
exprs: std.ArrayListUnmanaged(DocData.Expr) = .{},
ast_nodes: std.ArrayListUnmanaged(DocData.AstNode) = .{},
comptime_exprs: std.ArrayListUnmanaged(DocData.ComptimeExpr) = .{},

// These fields hold temporary state of the analysis process
// and are mainly used by the decl path resolving algorithm.
pending_ref_paths: std.AutoHashMapUnmanaged(
    *DocData.Expr, // pointer to declpath tail end (ie `&decl_path[decl_path.len - 1]`)
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},
ref_paths_pending_on_decls: std.AutoHashMapUnmanaged(
    usize,
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},
ref_paths_pending_on_types: std.AutoHashMapUnmanaged(
    usize,
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},

const RefPathResumeInfo = struct {
    file: *File,
    ref_path: []DocData.Expr,
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

/// The entry point of the Autodoc generation process.
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

    // Append all the types in Zir.Inst.Ref.
    {
        try self.types.append(self.arena, .{
            .ComptimeExpr = .{ .name = "ComptimeExpr" },
        });

        // this skipts Ref.none but it's ok becuse we replaced it with ComptimeExpr
        var i: u32 = 1;
        while (i <= @enumToInt(Ref.anyerror_void_error_union_type)) : (i += 1) {
            var tmpbuf = std.ArrayList(u8).init(self.arena);
            try Ref.typed_value_map[i].val.fmtDebug().format("", .{}, tmpbuf.writer());
            try self.types.append(
                self.arena,
                switch (@intToEnum(Ref, i)) {
                    else => blk: {
                        // TODO: map the remaining refs to a correct type
                        //       instead of just assinging "array" to them.
                        break :blk .{
                            .Array = .{
                                .len = .{
                                    .int = .{
                                        .value = 1,
                                        .negated = false,
                                    },
                                },
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

    const main_type_index = self.types.items.len;
    var root_scope = Scope{ .parent = null, .enclosing_type = main_type_index };
    try self.ast_nodes.append(self.arena, .{ .name = "(root)" });
    try self.files.put(self.arena, file, main_type_index);
    _ = try self.walkInstruction(file, &root_scope, Zir.main_struct_inst, false);

    if (self.ref_paths_pending_on_decls.count() > 0) {
        @panic("some decl paths were never fully analized (pending on decls)");
    }

    if (self.ref_paths_pending_on_types.count() > 0) {
        @panic("some decl paths were never fully analized (pending on types)");
    }

    if (self.pending_ref_paths.count() > 0) {
        @panic("some decl paths were never fully analized");
    }

    var data = DocData{
        .files = .{ .data = self.files },
        .calls = self.calls.items,
        .types = self.types.items,
        .decls = self.decls.items,
        .exprs = self.exprs.items,
        .astNodes = self.ast_nodes.items,
        .comptimeExprs = self.comptime_exprs.items,
    };

    data.packages[0].main = main_type_index;

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
    out.print(
        \\ /** @type {{DocData}} */
        \\ var zigAnalysis=
    , .{}) catch unreachable;
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
    const docs = try self.module.comp.zig_lib_directory.join(self.arena, &.{ "docs", std.fs.path.sep_str });
    var docs_dir = std.fs.openDirAbsolute(docs, .{}) catch unreachable;
    defer docs_dir.close();
    docs_dir.copyFile("main.js", output_dir, "main.js", .{}) catch unreachable;
    docs_dir.copyFile("index.html", output_dir, "index.html", .{}) catch unreachable;
}

/// Represents a chain of scopes, used to resolve decl references to the
/// corresponding entry in `self.decls`.
const Scope = struct {
    parent: ?*Scope,
    map: std.AutoHashMapUnmanaged(u32, usize) = .{}, // index into `decls`
    enclosing_type: usize, // index into `types`

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

/// The output of our analysis process.
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
    exprs: []Expr,
    comptimeExprs: []ComptimeExpr,
    const Call = struct {
        func: Expr,
        args: []Expr,
        ret: Expr,
    };

    /// All the type "families" as described by `std.builtin.TypeId`
    /// plus a couple extra that are unique to our use case.
    ///
    /// `Unanalyzed` is used so that we can refer to types that have started
    /// analysis but that haven't been fully analyzed yet (in case we find
    /// self-referential stuff, like `@This()`).
    ///
    /// `ComptimeExpr` represents the result of a piece of comptime logic
    /// that we weren't able to analyze fully. Examples of that are comptime
    /// function calls and comptime if / switch / ... expressions.
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
        isTest: bool,
        src: usize, // index into astNodes
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
        @"comptime": bool = false,
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
            size: std.builtin.TypeInfo.Pointer.Size,
            child: Expr,
        },
        Array: struct {
            len: Expr,
            child: Expr,
        },
        Struct: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: ?[]Expr = null, // (use src->fields to find names)
        },
        ComptimeExpr: struct { name: []const u8 },
        ComptimeFloat: struct { name: []const u8 },
        ComptimeInt: struct { name: []const u8 },
        Undefined: struct { name: []const u8 },
        Null: struct { name: []const u8 },
        Optional: struct {
            name: []const u8,
            child: Expr,
        },
        ErrorUnion: struct { name: []const u8 },
        ErrorSet: struct {
            name: []const u8,
            fields: []const Field,
            // TODO: fn field for inferred error sets?
        },
        Enum: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            // (use src->fields to find field names)
        },
        Union: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: []Expr = &.{}, // (use src->fields to find names)
        },
        Fn: struct {
            name: []const u8,
            src: ?usize = null, // index into astNodes
            ret: Expr,
            params: ?[]Expr = null, // (use src->fields to find names)
        },
        BoundFn: struct { name: []const u8 },
        Opaque: struct { name: []const u8 },
        Frame: struct { name: []const u8 },
        AnyFrame: struct { name: []const u8 },
        Vector: struct { name: []const u8 },
        EnumLiteral: struct { name: []const u8 },

        const Field = struct {
            name: []const u8,
            docs: []const u8,
        };

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
                .ErrorSet => |v| try printTypeBody(v, options, w),
                .Enum => |v| try printTypeBody(v, options, w),
                .Int => |v| try printTypeBody(v, options, w),
                .Float => |v| try printTypeBody(v, options, w),
                .Type => |v| try printTypeBody(v, options, w),
                .Pointer => |v| {
                    if (options.whitespace) |ws| try ws.outputIndent(w);
                    try w.print(
                        \\"size": {},
                        \\
                    , .{@enumToInt(v.size)});
                    if (options.whitespace) |ws| try ws.outputIndent(w);
                    try w.print(
                        \\"child":
                    , .{});

                    if (options.whitespace) |*ws| ws.indent_level += 1;
                    try v.child.jsonStringify(options, w);
                },
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

    /// An Expr represents the (untyped) result of analizing instructions.
    /// The data is normalized, which means that an Expr that results in a
    /// type definition will hold an index into `self.types`.
    pub const Expr = union(enum) {
        comptimeExpr: usize, // index in `comptimeExprs`
        void,
        @"unreachable",
        @"null",
        @"undefined",
        @"struct": []FieldVal,
        bool: bool,
        @"anytype",
        type: usize, // index in `types`
        this: usize, // index in `types`
        declRef: usize, // index in `decls`
        fieldRef: FieldRef,
        refPath: []Expr,
        int: struct {
            value: usize, // direct value
            negated: bool = false,
        },
        float: f64, // direct value
        array: []usize, // index in `exprs`
        call: usize, // index in `calls`
        enumLiteral: []const u8, // direct value
        typeOf: usize, // index in `exprs`
        as: As,
        sizeOf: usize, // index in `exprs`
        compileError: []const u8,
        string: []const u8, // direct value
        const As = struct {
            typeRefArg: ?usize, // index in `exprs`
            exprArg: usize, // index in `exprs`
        };
        const FieldRef = struct {
            type: usize, // index in `types`
            index: usize, // index in type.fields
        };

        const FieldVal = struct {
            name: []const u8,
            val: WalkResult,
        };

        pub fn jsonStringify(
            self: Expr,
            options: std.json.StringifyOptions,
            w: anytype,
        ) std.os.WriteError!void {
            switch (self) {
                .void, .@"unreachable", .@"anytype", .@"null", .@"undefined" => {
                    try w.print(
                        \\{{ "{s}":{{}} }}
                    , .{@tagName(self)});
                },
                .type, .comptimeExpr, .call, .this, .declRef, .typeOf => |v| {
                    try w.print(
                        \\{{ "{s}":{} }}
                    , .{ @tagName(self), v });
                },
                .int => |v| {
                    const neg = if (v.negated) "-" else "";
                    try w.print(
                        \\{{ "int": {s}{} }}
                    , .{ neg, v.value });
                },
                .float => |v| {
                    try w.print(
                        \\{{ "float": {} }}
                    , .{v});
                },
                .bool => |v| {
                    try w.print(
                        \\{{ "bool":{} }}
                    , .{v});
                },
                .sizeOf => |v| try std.json.stringify(v, options, w),
                .fieldRef => |v| try std.json.stringify(
                    struct { fieldRef: FieldRef }{ .fieldRef = v },
                    options,
                    w,
                ),
                .as => |v| try std.json.stringify(
                    struct { as: As }{ .as = v },
                    options,
                    w,
                ),
                .@"struct" => |v| try std.json.stringify(
                    struct { @"struct": []FieldVal }{ .@"struct" = v },
                    options,
                    w,
                ),
                .refPath => |v| {
                    try w.print("{{ \"refPath\": [", .{});
                    for (v) |c, i| {
                        const comma = if (i == v.len - 1) "]}" else ",\n";
                        try c.jsonStringify(options, w);
                        try w.print("{s}", .{comma});
                    }
                },
                .array => |v| try std.json.stringify(
                    struct { @"array": []usize }{ .@"array" = v },
                    options,
                    w,
                ),
                .compileError => |v| try std.json.stringify(
                    struct { compileError: []const u8 }{ .compileError = v },
                    options,
                    w,
                ),
                .string => |v| try std.json.stringify(
                    struct { string: []const u8 }{ .string = v },
                    options,
                    w,
                ),
                .enumLiteral => |v| try std.json.stringify(
                    struct { @"enumLiteral": []const u8 }{ .@"enumLiteral" = v },
                    options,
                    w,
                ),

                // try w.print("{ len: {},\n", .{v.len});

                // if (options.whitespace) |ws| try ws.outputIndent(w);
                // try w.print("typeRef: ", .{});
                // try v.typeRef.jsonStringify(options, w);

                // try w.print("{{ \"data\": [", .{});
                // for (v.data) |d, i| {
                //     const comma = if (i == v.len - 1) "]}" else ",";
                //     try w.print("{d}{s}", .{ d, comma });
                // }

            }
        }
    };

    /// A WalkResult represents the result of the analysis process done to a
    /// a Zir instruction. Walk results carry type information either inferred
    /// from the context (eg string literals are pointers to null-terminated
    /// arrays), or because of @as() instructions.
    /// Since the type information is only needed in certain contexts, the
    /// underlying normalized data (Expr) is untyped.
    const WalkResult = struct {
        typeRef: ?Expr = null, // index in `exprs`
        expr: Expr, // index in `exprs`
    };
};

/// Called when we need to analyze a Zir instruction.
/// For example it gets called by `generateZirData` on instruction 0,
/// which represents the top-level struct corresponding to the root file.
/// Note that in some situations where we're analyzing code that only allows
/// for a limited subset of Zig syntax, we don't always resort to calling
/// `walkInstruction` and instead sometimes we handle Zir directly.
/// The best example of that are instructions corresponding to function
/// params, as those can only occur while analyzing a function definition.
fn walkInstruction(
    self: *Autodoc,
    file: *File,
    parent_scope: *Scope,
    inst_index: usize,
    need_type: bool, // true if the caller needs us to provide also a typeRef
) error{OutOfMemory}!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    // We assume that the topmost ast_node entry corresponds to our decl
    const self_ast_node_index = self.ast_nodes.items.len - 1;

    switch (tags[inst_index]) {
        else => {
            printWithContext(
                file,
                inst_index,
                "TODO: implement `{s}` for walkInstruction\n\n",
                .{@tagName(tags[inst_index])},
            );
            return self.cteTodo(@tagName(tags[inst_index]));
        },
        .closure_get => {
            const inst_node = data[inst_index].inst_node;
            return try self.walkInstruction(file, parent_scope, inst_node.inst, need_type);
        },
        .closure_capture => {
            const un_tok = data[inst_index].un_tok;
            return try self.walkRef(file, parent_scope, un_tok.operand, need_type);
        },
        .import => {
            const str_tok = data[inst_index].str_tok;
            const path = str_tok.get(file.zir);
            // importFile cannot error out since all files
            // are already loaded at this point
            if (file.pkg.table.get(path) != null) {
                const cte_slot_index = self.comptime_exprs.items.len;
                try self.comptime_exprs.append(self.arena, .{
                    .code = path,
                });
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                    .expr = .{ .comptimeExpr = cte_slot_index },
                };
            }

            const new_file = self.module.importFile(file, path) catch unreachable;
            const result = try self.files.getOrPut(self.arena, new_file.file);
            if (result.found_existing) {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                    .expr = .{ .type = result.value_ptr.* },
                };
            }

            result.value_ptr.* = self.types.items.len;

            var new_scope = Scope{
                .parent = null,
                .enclosing_type = self.types.items.len,
            };

            return self.walkInstruction(
                new_file.file,
                &new_scope,
                Zir.main_struct_inst,
                need_type,
            );
        },
        .str => {
            const str = data[inst_index].str.get(file.zir);

            const tRef: ?DocData.Expr = if (!need_type) null else blk: {
                const arrTypeId = self.types.items.len;
                try self.types.append(self.arena, .{
                    .Array = .{
                        .len = .{ .int = .{ .value = str.len } },
                        .child = .{ .type = @enumToInt(Ref.u8_type) },
                    },
                });
                const ptrTypeId = self.types.items.len;
                try self.types.append(self.arena, .{
                    .Pointer = .{
                        .size = .One,
                        .child = .{ .type = arrTypeId },
                        // TODO: add sentinel!
                    },
                });
                break :blk .{ .type = ptrTypeId };
            };
            return DocData.WalkResult{
                .typeRef = tRef,
                .expr = .{ .string = str },
            };
        },
        .compile_error => {
            const un_node = data[inst_index].un_node;
            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
                false,
            );

            return DocData.WalkResult{
                .expr = .{
                    .compileError = switch (operand.expr) {
                        .string => |s| s,
                        else => "TODO: non-string @compileError arguments",
                    },
                },
            };
        },
        .enum_literal => {
            const str_tok = data[inst_index].str_tok;
            const literal = file.zir.nullTerminatedString(str_tok.start);
            return DocData.WalkResult{ .expr = .{ .enumLiteral = literal } };
        },
        .int => {
            const int = data[inst_index].int;
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                .expr = .{ .int = .{ .value = int } },
            };
        },
        .error_union_type => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            // TODO: return the actual error union instread of cheating
            return self.walkRef(file, parent_scope, extra.data.rhs, need_type);
        },
        .ptr_type_simple => {
            const ptr = data[inst_index].ptr_type_simple;
            const type_slot_index = self.types.items.len;
            const elem_type_ref = try self.walkRef(file, parent_scope, ptr.elem_type, false);
            try self.types.append(self.arena, .{
                .Pointer = .{
                    .size = ptr.size,
                    .child = elem_type_ref.expr,
                },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .ptr_type => {
            const ptr = data[inst_index].ptr_type;
            const extra = file.zir.extraData(Zir.Inst.PtrType, ptr.payload_index);

            const type_slot_index = self.types.items.len;
            const elem_type_ref = try self.walkRef(
                file,
                parent_scope,
                extra.data.elem_type,
                false,
            );
            try self.types.append(self.arena, .{
                .Pointer = .{
                    .size = ptr.size,
                    .child = elem_type_ref.expr,
                },
            });
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_type => {
            const bin = data[inst_index].bin;
            const len = try self.walkRef(file, parent_scope, bin.lhs, false);
            const child = try self.walkRef(file, parent_scope, bin.rhs, false);

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Array = .{
                    .len = len.expr,
                    .child = child.expr,
                },
            });
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_init => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len);

            // TODO: make sure that you want the array to be fully normalized for real
            // then update this code to conform to your choice.

            var array_type: ?DocData.Expr = null;
            for (operands) |op, idx| {
                // we only ask to figure out type info for the first element
                // as it will be used later on to find out the array type!
                const wr = try self.walkRef(file, parent_scope, op, idx == 0);

                if (idx == 0) {
                    array_type = wr.typeRef;
                }

                // We know that Zir wraps every operand in an @as expression
                // so we want to peel it away and only save the target type
                // once, since we need it later to define the array type.
                array_data[idx] = wr.expr.as.exprArg;
            }

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Array = .{
                    .len = .{
                        .int = .{
                            .value = operands.len,
                            .negated = false,
                        },
                    },
                    .child = array_type.?,
                },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = type_slot_index },
                .expr = .{ .array = array_data },
            };
        },
        .float => {
            const float = data[inst_index].float;
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_float_type) },
                .expr = .{ .float = float },
            };
        },
        .negate => {
            const un_node = data[inst_index].un_node;
            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
                need_type,
            );
            switch (operand.expr) {
                .int => |*int| int.negated = true,
                else => {
                    printWithContext(
                        file,
                        inst_index,
                        "TODO: support negation for more types",
                        .{},
                    );
                },
            }
            return operand;
        },
        .size_of => {
            const un_node = data[inst_index].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
                false,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                .expr = .{ .sizeOf = operand_index },
            };
        },

        .typeof => {
            const un_node = data[inst_index].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
                need_type,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeOf = operand_index },
            };
        },
        .as_node => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.As, pl_node.payload_index);
            const dest_type_walk = try self.walkRef(
                file,
                parent_scope,
                extra.data.dest_type,
                false,
            );

            const operand = try self.walkRef(
                file,
                parent_scope,
                extra.data.operand,
                false,
            );
            const operand_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            const dest_type_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, dest_type_walk.expr);

            // TODO: there's something wrong with how both `as` and `WalkrResult`
            //       try to store type information.
            return DocData.WalkResult{
                .typeRef = dest_type_walk.expr,
                .expr = .{
                    .as = .{
                        .typeRefArg = dest_type_idx,
                        .exprArg = operand_idx,
                    },
                },
            };
        },
        .optional_type => {
            const un_node = data[inst_index].un_node;
            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                un_node.operand,
                false,
            );

            const operand_idx = self.types.items.len;
            try self.types.append(self.arena, .{
                .Optional = .{ .name = "?TODO", .child = operand.expr },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = operand_idx },
            };
        },
        .decl_val, .decl_ref => {
            const str_tok = data[inst_index].str_tok;
            const decls_slot_index = parent_scope.resolveDeclName(str_tok.start);
            // While it would make sense to grab the original decl's typeRef info,
            // that decl might not have been analyzed yet! The frontend will have
            // to navigate through all declRefs to find the underlying type.
            return DocData.WalkResult{ .expr = .{ .declRef = decls_slot_index } };
        },
        .field_val, .field_call_bind, .field_ptr, .field_type => {
            // TODO: field type uses Zir.Inst.FieldType, it just happens to have the
            // same layout as Zir.Inst.Field :^)
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Field, pl_node.payload_index);

            var path: std.ArrayListUnmanaged(DocData.Expr) = .{};
            var lhs = @enumToInt(extra.data.lhs) - Ref.typed_value_map.len; // underflow = need to handle Refs

            try path.append(self.arena, .{
                .string = file.zir.nullTerminatedString(extra.data.field_name_start),
            });
            // Put inside path the starting index of each decl name that
            // we encounter as we navigate through all the field_vals
            while (tags[lhs] == .field_val or
                tags[lhs] == .field_call_bind or
                tags[lhs] == .field_ptr or
                tags[lhs] == .field_type)
            {
                const lhs_extra = file.zir.extraData(
                    Zir.Inst.Field,
                    data[lhs].pl_node.payload_index,
                );

                try path.append(self.arena, .{
                    .string = file.zir.nullTerminatedString(lhs_extra.data.field_name_start),
                });
                lhs = @enumToInt(lhs_extra.data.lhs) - Ref.typed_value_map.len; // underflow = need to handle Refs
            }

            // TODO: double check that we really don't need type info here
            const wr = try self.walkInstruction(file, parent_scope, lhs, false);
            try path.append(self.arena, wr.expr);

            // This way the data in `path` has the same ordering that the ref
            // path has in the text: most general component first.
            std.mem.reverse(DocData.Expr, path.items);

            // Righ now, every element of `path` is a string except its first
            // element (at index 0). We're now going to attempt to resolve each
            // string. If one or more components in this path are not yet fully
            // analyzed, the path will only be solved partially, but we expect
            // to eventually solve it fully(or give up in case of a
            // comptimeExpr). This means that:
            // - (1) Paths can be not fully analyzed temporarily, so any code
            //       that requires to know where a ref path leads to, neeeds to
            //       implement support for lazyness (see self.pending_ref_paths)
            // - (2) Paths can sometimes never resolve fully. This means that
            //       any value that depends on that will have to become a
            //       comptimeExpr.
            try self.tryResolveRefPath(file, lhs, path.items);
            return DocData.WalkResult{ .expr = .{ .refPath = path.items } };
        },
        .int_type => {
            const int_type = data[inst_index].int_type;
            const sign = if (int_type.signedness == .unsigned) "u" else "i";
            const bits = int_type.bit_count;
            const name = try std.fmt.allocPrint(self.arena, "{s}{}", .{ sign, bits });

            try self.types.append(self.arena, .{
                .Int = .{ .name = name },
            });
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = self.types.items.len - 1 },
            };
        },
        .block => {
            const res = DocData.WalkResult{ .expr = .{
                .comptimeExpr = self.comptime_exprs.items.len,
            } };
            try self.comptime_exprs.append(self.arena, .{
                .code = "if(banana) 1 else 0",
            });
            return res;
        },
        .block_inline => {
            return self.walkRef(
                file,
                parent_scope,
                getBlockInlineBreak(file.zir, inst_index),
                need_type,
            );
        },
        .struct_init => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.StructInit, pl_node.payload_index);
            const field_vals = try self.arena.alloc(
                DocData.Expr.FieldVal,
                extra.data.fields_len,
            );

            var type_ref: DocData.Expr = undefined;
            var idx = extra.end;
            for (field_vals) |*fv| {
                const init_extra = file.zir.extraData(Zir.Inst.StructInit.Item, idx);
                defer idx = init_extra.end;

                const field_name = blk: {
                    const field_inst_index = init_extra.data.field_type;
                    if (tags[field_inst_index] != .field_type) unreachable;
                    const field_pl_node = data[field_inst_index].pl_node;
                    const field_extra = file.zir.extraData(
                        Zir.Inst.FieldType,
                        field_pl_node.payload_index,
                    );

                    // On first iteration use field info to find out the struct type
                    if (idx == extra.end) {
                        const wr = try self.walkRef(
                            file,
                            parent_scope,
                            field_extra.data.container_type,
                            false,
                        );
                        type_ref = wr.expr;
                    }
                    break :blk file.zir.nullTerminatedString(field_extra.data.name_start);
                };
                const value = try self.walkRef(
                    file,
                    parent_scope,
                    init_extra.data.init,
                    need_type,
                );
                fv.* = .{ .name = field_name, .val = value };
            }

            return DocData.WalkResult{
                .typeRef = type_ref,
                .expr = .{ .@"struct" = field_vals },
            };
        },
        .error_set_decl => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.ErrorSetDecl, pl_node.payload_index);
            const fields = try self.arena.alloc(
                DocData.Type.Field,
                extra.data.fields_len,
            );
            var idx = extra.end;
            for (fields) |*f| {
                const name = file.zir.nullTerminatedString(file.zir.extra[idx]);
                idx += 1;

                const docs = file.zir.nullTerminatedString(file.zir.extra[idx]);
                idx += 1;

                f.* = .{
                    .name = name,
                    .docs = docs,
                };
            }

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .ErrorSet = .{
                    .name = "todo errset",
                    .fields = fields,
                },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .param_anytype => {
            // Analysis of anytype function params happens in `.func`.
            // This switch case handles the case where an expression depends
            // on an anytype field. E.g.: `fn foo(bar: anytype) @TypeOf(bar)`.
            // This means that we're looking at a generic expression.
            const str_tok = data[inst_index].str_tok;
            const name = str_tok.get(file.zir);
            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = name,
            });
            return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
        },
        .param, .param_comptime => {
            // See .param_anytype for more information.
            const pl_tok = data[inst_index].pl_tok;
            const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
            const name = file.zir.nullTerminatedString(extra.data.name);
            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = name,
            });
            return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
        },
        .call => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Call, pl_node.payload_index);

            const callee = try self.walkRef(file, parent_scope, extra.data.callee, need_type);

            const args_len = extra.data.flags.args_len;
            var args = try self.arena.alloc(DocData.Expr, args_len);
            const arg_refs = file.zir.refSlice(extra.end, args_len);
            for (arg_refs) |ref, idx| {
                // TODO: consider toggling need_type to true if we ever want
                //       to show discrepancies between the types of provided
                //       arguments and the types declared in the function
                //       signature for its parameters.
                const wr = try self.walkRef(file, parent_scope, ref, false);
                args[idx] = wr.expr;
            }

            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = "func call",
            });

            const call_slot_index = self.calls.items.len;
            try self.calls.append(self.arena, .{
                .func = callee.expr,
                .args = args,
                .ret = .{ .comptimeExpr = cte_slot_index },
            });

            return DocData.WalkResult{
                .typeRef = if (callee.typeRef) |tr| switch (tr) {
                    .type => |func_type_idx| self.types.items[func_type_idx].Fn.ret,
                    else => null,
                } else null,
                .expr = .{ .call = call_slot_index },
            };
        },
        .func, .func_inferred => {
            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .Unanalyzed = {} });

            return self.analyzeFunction(
                file,
                parent_scope,
                inst_index,
                self_ast_node_index,
                type_slot_index,
            );
        },
        .extended => {
            const extended = data[inst_index].extended;
            switch (extended.opcode) {
                else => {
                    printWithContext(
                        file,
                        inst_index,
                        "TODO: implement `walkInstruction.extended` for {s}",
                        .{@tagName(extended.opcode)},
                    );
                    return self.cteTodo(@tagName(extended.opcode));
                },

                .opaque_decl => return self.cteTodo("opaque {...}"),
                .variable => {
                    const small = @bitCast(Zir.Inst.ExtendedVar.Small, extended.small);
                    var extra_index: usize = extended.operand;
                    if (small.has_lib_name) extra_index += 1;
                    if (small.has_align) extra_index += 1;

                    const value: DocData.WalkResult = if (small.has_init) .{ .expr = .{ .void = {} } } else .{ .expr = .{ .void = {} } };

                    return value;
                },
                .union_decl => {
                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{ .Unanalyzed = {} });

                    var scope: Scope = .{
                        .parent = parent_scope,
                        .enclosing_type = type_slot_index,
                    };

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

                    extra_index += body_len;

                    var field_type_refs = try std.ArrayListUnmanaged(DocData.Expr).initCapacity(
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

                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst_index,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }

                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .type = type_slot_index },
                    };
                },
                .enum_decl => {
                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{ .Unanalyzed = {} });

                    var scope: Scope = .{
                        .parent = parent_scope,
                        .enclosing_type = type_slot_index,
                    };

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
                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst_index,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .type = type_slot_index },
                    };
                },
                .struct_decl => {
                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{ .Unanalyzed = {} });

                    var scope: Scope = .{
                        .parent = parent_scope,
                        .enclosing_type = type_slot_index,
                    };

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

                    var field_type_refs: std.ArrayListUnmanaged(DocData.Expr) = .{};
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
                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst_index,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .type = type_slot_index },
                    };
                },
                .this => {
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .this = parent_scope.enclosing_type },
                    };
                },
            }
        },
    }
}

/// Called by `walkInstruction` when encountering a container type.
/// Iterates over all decl definitions in its body and it also analyzes each
/// decl's body recursively by calling into `walkInstruction`.
///
/// Does not append to `self.decls` directly because `walkInstruction`
/// is expected to look-ahead scan all decls and reserve `body_len`
/// slots in `self.decls`, which are then filled out by this function.
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
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_section_or_addrspace = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        // const sub_index = extra_index;

        // const hash_u32s = file.zir.extra[extra_index..][0..4];
        extra_index += 4;
        const line = file.zir.extra[extra_index];
        extra_index += 1;
        const decl_name_index = file.zir.extra[extra_index];
        extra_index += 1;
        const value_index = file.zir.extra[extra_index];
        extra_index += 1;
        const doc_comment_index = file.zir.extra[extra_index];
        extra_index += 1;

        const align_inst: Zir.Inst.Ref = if (!has_align) .none else inst: {
            const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
            extra_index += 1;
            break :inst inst;
        };
        _ = align_inst;

        const section_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
            const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
            extra_index += 1;
            break :inst inst;
        };
        _ = section_inst;

        const addrspace_inst: Zir.Inst.Ref = if (!has_section_or_addrspace) .none else inst: {
            const inst = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
            extra_index += 1;
            break :inst inst;
        };
        _ = addrspace_inst;

        // const pub_str = if (is_pub) "pub " else "";
        // const hash_bytes = @bitCast([16]u8, hash_u32s.*);

        var is_test = false; // we discover if it's a test by lookin at its name
        const name: []const u8 = blk: {
            if (decl_name_index == 0) {
                break :blk if (is_exported) "usingnamespace" else "comptime";
            } else if (decl_name_index == 1) {
                is_test = true;
                break :blk "test";
            } else if (decl_name_index == 2) {
                is_test = true;
                // it is a decltest
                const decl_being_tested = scope.resolveDeclName(doc_comment_index);
                const ast_node_index = idx: {
                    const idx = self.ast_nodes.items.len;
                    const file_source = file.getSource(self.module.gpa) catch unreachable; // TODO fix this
                    const source_of_decltest_function = srcloc: {
                        const func_index = getBlockInlineBreak(file.zir, value_index);
                        // a decltest is always a function
                        const tag = file.zir.instructions.items(.tag)[Zir.refToIndex(func_index).?];
                        std.debug.assert(tag == .func_extended);

                        const pl_node = file.zir.instructions.items(.data)[Zir.refToIndex(func_index).?].pl_node;
                        const extra = file.zir.extraData(Zir.Inst.ExtendedFunc, pl_node.payload_index);
                        const bits = @bitCast(Zir.Inst.ExtendedFunc.Bits, extra.data.bits);

                        var extra_index_for_this_func: usize = extra.end;
                        if (bits.has_lib_name) extra_index_for_this_func += 1;
                        if (bits.has_cc) extra_index_for_this_func += 1;
                        if (bits.has_align) extra_index_for_this_func += 1;

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
                    .isTest = true,
                    .src = ast_node_index,
                    .value = .{ .expr = .{ .type = 0 } },
                    .kind = "const",
                };
                continue;
            } else {
                const raw_decl_name = file.zir.nullTerminatedString(decl_name_index);
                if (raw_decl_name.len == 0) {
                    is_test = true;
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

        const walk_result = if (is_test) // TODO: decide if tests should show up at all
            DocData.WalkResult{ .expr = .{ .void = {} } }
        else
            try self.walkInstruction(file, scope, value_index, true);

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
            .isTest = is_test,
            .src = ast_node_index,
            //.typeRef = decl_type_ref,
            .value = walk_result,
            .kind = "const", // find where this information can be found
        };

        // Unblock any pending decl path that was waiting for this decl.
        if (self.ref_paths_pending_on_decls.get(decls_slot_index)) |paths| {
            for (paths.items) |resume_info| {
                try self.tryResolveRefPath(
                    resume_info.file,
                    value_index,
                    resume_info.ref_path,
                );
            }

            _ = self.ref_paths_pending_on_decls.remove(decls_slot_index);
            // TODO: we should deallocate the arraylist that holds all the
            //       ref paths. not doing it now since it's arena-allocated
            //       anyway, but maybe we should put it elsewhere.
        }
    }

    return extra_index;
}

/// An unresolved path has a non-string WalkResult at its beginnig, while every
/// other element is a string WalkResult. Resolving means iteratively map each
/// string to a Decl / Type / Call / etc.
///
/// If we encounter an unanalyzed decl during the process, we append the
/// unsolved sub-path to `self.ref_paths_pending_on_decls` and bail out.
/// Same happens when a decl holds a type definition that hasn't been fully
/// analyzed yet (except that we append to `self.ref_paths_pending_on_types`.
///
/// When walkDecls / walkInstruction finishes analyzing a decl / type, it will
/// then check if there's any pending ref path blocked on it and, if any, it
/// will progress their resolution by calling tryResolveRefPath again.
///
/// Ref paths can also depend on other ref paths. See
/// `self.pending_ref_paths` for more info.
///
/// A ref path that has a component that resolves into a comptimeExpr will
/// give up its resolution process entirely, leaving the remaining components
/// as strings.
fn tryResolveRefPath(
    self: *Autodoc,
    /// File from which the decl path originates.
    file: *File,
    inst_index: usize, // used only for panicWithContext
    path: []DocData.Expr,
) error{OutOfMemory}!void {
    var i: usize = 0;
    outer: while (i < path.len - 1) : (i += 1) {
        const parent = path[i];
        const child_string = path[i + 1].string; // we expect to find a string union case

        var resolved_parent = parent;
        var j: usize = 0;
        while (j < 10_000) : (j += 1) {
            switch (resolved_parent) {
                else => break,
                .this => |t| resolved_parent = .{ .type = t },
                .declRef => |decl_index| {
                    const decl = self.decls.items[decl_index];
                    if (decl._analyzed) {
                        resolved_parent = decl.value.expr;
                        continue;
                    }

                    // This decl path is pending completion
                    {
                        const res = try self.pending_ref_paths.getOrPut(
                            self.arena,
                            &path[path.len - 1],
                        );
                        if (!res.found_existing) res.value_ptr.* = .{};
                    }

                    const res = try self.ref_paths_pending_on_decls.getOrPut(
                        self.arena,
                        decl_index,
                    );
                    if (!res.found_existing) res.value_ptr.* = .{};
                    try res.value_ptr.*.append(self.arena, .{
                        .file = file,
                        .ref_path = path[i..path.len],
                    });

                    // We return instead doing `break :outer` to prevent the
                    // code after the :outer while loop to run, as it assumes
                    // that the path will have been fully analyzed (or we
                    // have given up because of a comptimeExpr).
                    return;
                },
                .refPath => |rp| {
                    if (self.pending_ref_paths.getPtr(&rp[rp.len - 1])) |waiter_list| {
                        try waiter_list.append(self.arena, .{
                            .file = file,
                            .ref_path = path[i..path.len],
                        });

                        // This decl path is pending completion
                        {
                            const res = try self.pending_ref_paths.getOrPut(
                                self.arena,
                                &path[path.len - 1],
                            );
                            if (!res.found_existing) res.value_ptr.* = .{};
                        }

                        return;
                    }

                    // If the last element is a string or a CTE, then we give up,
                    // otherwise we resovle the parent to it and loop again.
                    // NOTE: we assume that if we find a string, it's because of
                    // a CTE component somewhere in the path. We know that the path
                    // is not pending futher evaluation because we just checked!
                    const last = rp[rp.len - 1];
                    switch (last) {
                        .comptimeExpr, .string => break :outer,
                        else => {
                            resolved_parent = last;
                            continue;
                        },
                    }
                },
            }
        } else {
            panicWithContext(
                file,
                inst_index,
                "exhausted eval quota for `{}`in tryResolveDecl\n",
                .{resolved_parent},
            );
        }

        switch (resolved_parent) {
            else => {
                // NOTE: indirect references to types / decls should be handled
                //       in the switch above this one!
                printWithContext(
                    file,
                    inst_index,
                    "TODO: handle `{s}`in tryResolveRefPath\nInfo: {}",
                    .{ @tagName(resolved_parent), resolved_parent },
                );
                path[i + 1] = (try self.cteTodo("match failure")).expr;
                continue :outer;
            },
            .comptimeExpr, .call => {
                // Since we hit a cte, we leave the remaining strings unresolved
                // and completely give up on resolving this decl path.
                //decl_path.hasCte = true;
                break :outer;
            },
            .type => |t_index| switch (self.types.items[t_index]) {
                else => {
                    panicWithContext(
                        file,
                        inst_index,
                        "TODO: handle `{s}` in tryResolveDeclPath.type\n",
                        .{@tagName(self.types.items[t_index])},
                    );
                },
                .Unanalyzed => {
                    // This decl path is pending completion
                    {
                        const res = try self.pending_ref_paths.getOrPut(
                            self.arena,
                            &path[path.len - 1],
                        );
                        if (!res.found_existing) res.value_ptr.* = .{};
                    }

                    const res = try self.ref_paths_pending_on_types.getOrPut(
                        self.arena,
                        t_index,
                    );
                    if (!res.found_existing) res.value_ptr.* = .{};
                    try res.value_ptr.*.append(self.arena, .{
                        .file = file,
                        .ref_path = path[i..path.len],
                    });

                    return;
                },
                .Enum => |t_enum| {
                    for (t_enum.pubDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }
                    for (t_enum.privDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }

                    for (self.ast_nodes.items[t_enum.src].fields.?) |ast_node, idx| {
                        const name = self.ast_nodes.items[ast_node].name.?;
                        if (std.mem.eql(u8, name, child_string)) {
                            // TODO: should we really create an artificial
                            //       decl for this type? Probably not.

                            path[i + 1] = .{
                                .fieldRef = .{
                                    .type = t_index,
                                    .index = idx,
                                },
                            };
                            continue :outer;
                        }
                    }

                    // if we got here, our search failed
                    printWithContext(
                        file,
                        inst_index,
                        "failed to match `{s}` in enum",
                        .{child_string},
                    );

                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },
                .Union => |t_union| {
                    for (t_union.pubDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }
                    for (t_union.privDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }

                    for (self.ast_nodes.items[t_union.src].fields.?) |ast_node, idx| {
                        const name = self.ast_nodes.items[ast_node].name.?;
                        if (std.mem.eql(u8, name, child_string)) {
                            // TODO: should we really create an artificial
                            //       decl for this type? Probably not.

                            path[i + 1] = .{
                                .fieldRef = .{
                                    .type = t_index,
                                    .index = idx,
                                },
                            };
                            continue :outer;
                        }
                    }

                    // if we got here, our search failed
                    printWithContext(
                        file,
                        inst_index,
                        "failed to match `{s}` in union",
                        .{child_string},
                    );
                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },

                .Struct => |t_struct| {
                    for (t_struct.pubDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }
                    for (t_struct.privDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }

                    for (self.ast_nodes.items[t_struct.src].fields.?) |ast_node, idx| {
                        const name = self.ast_nodes.items[ast_node].name.?;
                        if (std.mem.eql(u8, name, child_string)) {
                            // TODO: should we really create an artificial
                            //       decl for this type? Probably not.

                            path[i + 1] = .{
                                .fieldRef = .{
                                    .type = t_index,
                                    .index = idx,
                                },
                            };
                            continue :outer;
                        }
                    }

                    // if we got here, our search failed
                    printWithContext(
                        file,
                        inst_index,
                        "failed to match `{s}` in struct",
                        .{child_string},
                    );
                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },
            },
        }
    }

    if (self.pending_ref_paths.get(&path[path.len - 1])) |waiter_list| {
        // It's important to de-register oureslves as pending before
        // attempting to resolve any other decl.
        _ = self.pending_ref_paths.remove(&path[path.len - 1]);

        for (waiter_list.items) |resume_info| {
            try self.tryResolveRefPath(resume_info.file, inst_index, resume_info.ref_path);
        }
        // TODO: this is where we should free waiter_list, but its in the arena
        //       that said, we might want to store it elsewhere and reclaim memory asap
    }
}

fn analyzeFunction(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    inst_index: usize,
    self_ast_node_index: usize,
    type_slot_index: usize,
) error{OutOfMemory}!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);
    const fn_info = file.zir.getFnInfo(@intCast(u32, inst_index));

    try self.ast_nodes.ensureUnusedCapacity(self.arena, fn_info.total_params_len);
    var param_type_refs = try std.ArrayListUnmanaged(DocData.Expr).initCapacity(
        self.arena,
        fn_info.total_params_len,
    );
    var param_ast_indexes = try std.ArrayListUnmanaged(usize).initCapacity(
        self.arena,
        fn_info.total_params_len,
    );

    // TODO: handle scope rules for fn parameters
    for (fn_info.param_body[0..fn_info.total_params_len]) |param_index| {
        switch (tags[param_index]) {
            else => panicWithContext(
                file,
                param_index,
                "TODO: handle `{s}` in walkInstruction.func\n",
                .{@tagName(tags[param_index])},
            ),
            .param_anytype, .param_anytype_comptime => {
                // TODO: where are the doc comments?
                const str_tok = data[param_index].str_tok;

                const name = str_tok.get(file.zir);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                self.ast_nodes.appendAssumeCapacity(.{
                    .name = name,
                    .docs = "",
                    .@"comptime" = true,
                });

                param_type_refs.appendAssumeCapacity(
                    DocData.Expr{ .@"anytype" = {} },
                );
            },
            .param, .param_comptime => {
                const pl_tok = data[param_index].pl_tok;
                const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
                const doc_comment = if (extra.data.doc_comment != 0)
                    file.zir.nullTerminatedString(extra.data.doc_comment)
                else
                    "";
                const name = file.zir.nullTerminatedString(extra.data.name);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                try self.ast_nodes.append(self.arena, .{
                    .name = name,
                    .docs = doc_comment,
                    .@"comptime" = tags[param_index] == .param_comptime,
                });

                const break_index = file.zir.extra[extra.end..][extra.data.body_len - 1];
                const break_operand = data[break_index].@"break".operand;
                const param_type_ref = try self.walkRef(file, scope, break_operand, false);

                param_type_refs.appendAssumeCapacity(param_type_ref.expr);
            },
        }
    }

    // ret
    const ret_type_ref = blk: {
        const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
        const break_operand = data[last_instr_index].@"break".operand;
        const wr = try self.walkRef(file, scope, break_operand, false);
        break :blk wr;
    };

    self.ast_nodes.items[self_ast_node_index].fields = param_ast_indexes.items;
    self.types.items[type_slot_index] = .{
        .Fn = .{
            .name = "todo_name func",
            .src = self_ast_node_index,
            .params = param_type_refs.items,
            .ret = ret_type_ref.expr,
        },
    };
    return DocData.WalkResult{
        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
        .expr = .{ .type = type_slot_index },
    };
}

fn collectUnionFieldInfo(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    fields_len: usize,
    field_type_refs: *std.ArrayListUnmanaged(DocData.Expr),
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
        if (has_type) extra_index += 1;

        if (has_align) extra_index += 1;
        if (has_tag) extra_index += 1;

        // type
        {
            const walk_result = try self.walkRef(file, scope, field_type, false);
            try field_type_refs.append(self.arena, walk_result.expr);
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
    field_type_refs: *std.ArrayListUnmanaged(DocData.Expr),
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
            const walk_result = try self.walkRef(file, scope, field_type, false);
            try field_type_refs.append(self.arena, walk_result.expr);
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

/// A Zir Ref can either refer to common types and values, or to a Zir index.
/// WalkRef resolves common cases and delegates to `walkInstruction` otherwise.
fn walkRef(
    self: *Autodoc,
    file: *File,
    parent_scope: *Scope,
    ref: Ref,
    need_type: bool, // true when the caller needs also a typeRef for the return value
) !DocData.WalkResult {
    const enum_value = @enumToInt(ref);
    if (enum_value <= @enumToInt(Ref.anyerror_void_error_union_type)) {
        // We can just return a type that indexes into `types` with the
        // enum value because in the beginning we pre-filled `types` with
        // the types that are listed in `Ref`.
        return DocData.WalkResult{
            .typeRef = .{ .type = @enumToInt(std.builtin.TypeId.Type) },
            .expr = .{ .type = enum_value },
        };
    } else if (enum_value < Ref.typed_value_map.len) {
        switch (ref) {
            else => {
                std.debug.panic("TODO: handle {s} in `walkRef`\n", .{
                    @tagName(ref),
                });
            },
            .undef => {
                return DocData.WalkResult{ .expr = .@"undefined" };
            },
            .zero => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 0 } },
                };
            },
            .one => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },

            .void_value => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.void_type) },
                    .expr = .{ .void = {} },
                };
            },
            .unreachable_value => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.noreturn_type) },
                    .expr = .{ .@"unreachable" = {} },
                };
            },
            .null_value => {
                return DocData.WalkResult{ .expr = .@"null" };
            },
            .bool_true => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.bool_type) },
                    .expr = .{ .bool = true },
                };
            },
            .bool_false => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.bool_type) },
                    .expr = .{ .bool = false },
                };
            },
            .empty_struct => {
                return DocData.WalkResult{ .expr = .{ .@"struct" = &.{} } };
            },
            .zero_usize => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.usize_type) },
                    .expr = .{ .int = .{ .value = 0 } },
                };
            },
            .one_usize => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.usize_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
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
        return self.walkInstruction(file, parent_scope, zir_index, need_type);
    }
}

fn getBlockInlineBreak(zir: Zir, inst_index: usize) Zir.Inst.Ref {
    const tags = zir.instructions.items(.tag);
    const data = zir.instructions.items(.data);
    const pl_node = data[inst_index].pl_node;
    const extra = zir.extraData(Zir.Inst.Block, pl_node.payload_index);
    const break_index = zir.extra[extra.end..][extra.data.body_len - 1];
    std.debug.assert(tags[break_index] == .break_inline);
    return data[break_index].@"break".operand;
}

fn printWithContext(file: *File, inst: usize, comptime fmt: []const u8, args: anytype) void {
    std.debug.print("Context [{s}] % {}\n", .{ file.sub_file_path, inst });
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
}

fn panicWithContext(file: *File, inst: usize, comptime fmt: []const u8, args: anytype) noreturn {
    printWithContext(file, inst, fmt, args);
    unreachable;
}

fn cteTodo(self: *Autodoc, msg: []const u8) error{OutOfMemory}!DocData.WalkResult {
    const cte_slot_index = self.comptime_exprs.items.len;
    try self.comptime_exprs.append(self.arena, .{
        .code = msg,
    });
    return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
}
