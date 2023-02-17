const builtin = @import("builtin");
const std = @import("std");
const build_options = @import("build_options");
const Ast = std.zig.Ast;
const Autodoc = @This();
const Compilation = @import("Compilation.zig");
const Module = @import("Module.zig");
const File = Module.File;
const Package = @import("Package.zig");
const Tokenizer = std.zig.Tokenizer;
const Zir = @import("Zir.zig");
const Ref = Zir.Inst.Ref;
const log = std.log.scoped(.autodoc);
const Docgen = @import("autodoc/render_source.zig");

module: *Module,
doc_location: Compilation.EmitLoc,
arena: std.mem.Allocator,

// The goal of autodoc is to fill up these arrays
// that will then be serialized as JSON and consumed
// by the JS frontend.
packages: std.AutoArrayHashMapUnmanaged(*Package, DocData.DocPackage) = .{},
files: std.AutoArrayHashMapUnmanaged(*File, usize) = .{},
calls: std.ArrayListUnmanaged(DocData.Call) = .{},
types: std.ArrayListUnmanaged(DocData.Type) = .{},
decls: std.ArrayListUnmanaged(DocData.Decl) = .{},
exprs: std.ArrayListUnmanaged(DocData.Expr) = .{},
ast_nodes: std.ArrayListUnmanaged(DocData.AstNode) = .{},
comptime_exprs: std.ArrayListUnmanaged(DocData.ComptimeExpr) = .{},
guides: std.StringHashMapUnmanaged([]const u8) = .{},

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

/// Used to accumulate src_node offsets.
/// In ZIR, all ast node indices are relative to the parent decl.
/// More concretely, `union_decl`, `struct_decl`, `enum_decl` and `opaque_decl`
/// and the value of each of their decls participate in the relative offset
/// counting, and nothing else.
/// We keep track of the line and byte values for these instructions in order
/// to avoid tokenizing every file (on new lines) from the start every time.
const SrcLocInfo = struct {
    bytes: u32 = 0,
    line: usize = 0,
    src_node: u32 = 0,
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
            log.debug("path: {s}", .{path});
        }
    }

    log.debug("Ref map size: {}", .{Ref.typed_value_map.len});

    const root_src_dir = self.module.main_pkg.root_src_directory;
    const root_src_path = self.module.main_pkg.root_src_path;
    const joined_src_path = try root_src_dir.join(self.arena, &.{root_src_path});
    defer self.arena.free(joined_src_path);

    const abs_root_src_path = try std.fs.path.resolve(self.arena, &.{ ".", joined_src_path });
    defer self.arena.free(abs_root_src_path);

    const file = self.module.import_table.get(abs_root_src_path).?; // file is expected to be present in the import table
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
                        .Int = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f128_type,
                    => .{
                        .Float = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .comptime_int_type => .{
                        .ComptimeInt = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .comptime_float_type => .{
                        .ComptimeFloat = .{ .name = try tmpbuf.toOwnedSlice() },
                    },

                    .anyopaque_type => .{
                        .ComptimeExpr = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .bool_type => .{
                        .Bool = .{ .name = try tmpbuf.toOwnedSlice() },
                    },

                    .noreturn_type => .{
                        .NoReturn = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .void_type => .{
                        .Void = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .type_info_type => .{
                        .ComptimeExpr = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .type_type => .{
                        .Type = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .anyerror_type => .{
                        .ErrorSet = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .calling_convention_inline, .calling_convention_c, .calling_convention_type => .{
                        .EnumLiteral = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                },
            );
        }
    }

    const rootName = blk: {
        const rootName = std.fs.path.basename(self.module.main_pkg.root_src_path);
        break :blk rootName[0 .. rootName.len - 4];
    };

    const main_type_index = self.types.items.len;
    {
        try self.packages.put(self.arena, self.module.main_pkg, .{
            .name = rootName,
            .main = main_type_index,
            .table = .{},
        });
        try self.packages.entries.items(.value)[0].table.put(
            self.arena,
            self.module.main_pkg,
            .{
                .name = rootName,
                .value = 0,
            },
        );
    }

    var root_scope = Scope{
        .parent = null,
        .enclosing_type = main_type_index,
    };

    const tldoc_comment = try self.getTLDocComment(file);
    try self.ast_nodes.append(self.arena, .{
        .name = "(root)",
        .docs = tldoc_comment,
    });
    try self.files.put(self.arena, file, main_type_index);
    try self.findGuidePaths(file, tldoc_comment);

    _ = try self.walkInstruction(file, &root_scope, .{}, Zir.main_struct_inst, false);

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
        .params = .{},
        .packages = self.packages.values(),
        .files = self.files,
        .calls = self.calls.items,
        .types = self.types.items,
        .decls = self.decls.items,
        .exprs = self.exprs.items,
        .astNodes = self.ast_nodes.items,
        .comptimeExprs = self.comptime_exprs.items,
        .guides = self.guides,
    };

    const base_dir = self.doc_location.directory orelse
        self.module.zig_cache_artifact_directory;

    base_dir.handle.makeDir(self.doc_location.basename) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => |err| return err,
    };

    const output_dir = if (self.doc_location.directory) |d|
        try d.handle.openDir(self.doc_location.basename, .{})
    else
        try self.module.zig_cache_artifact_directory.handle.openDir(self.doc_location.basename, .{});

    {
        const data_js_f = try output_dir.createFile("data.js", .{});
        defer data_js_f.close();
        var buffer = std.io.bufferedWriter(data_js_f.writer());

        const out = buffer.writer();
        try out.print(
            \\ /** @type {{DocData}} */
            \\ var zigAnalysis=
        , .{});
        try std.json.stringify(
            data,
            .{
                .whitespace = .{ .indent = .None, .separator = false },
                .emit_null_optional_fields = true,
            },
            out,
        );
        try out.print(";", .{});

        // last thing (that can fail) that we do is flush
        try buffer.flush();
    }

    {
        output_dir.makeDir("src") catch |e| switch (e) {
            error.PathAlreadyExists => {},
            else => |err| return err,
        };
        const html_dir = try output_dir.openDir("src", .{});

        var files_iterator = self.files.iterator();

        while (files_iterator.next()) |entry| {
            const new_html_path = try std.mem.concat(self.arena, u8, &.{ entry.key_ptr.*.sub_file_path, ".html" });

            const html_file = try createFromPath(html_dir, new_html_path);
            defer html_file.close();
            var buffer = std.io.bufferedWriter(html_file.writer());

            const out = buffer.writer();

            try Docgen.genHtml(self.module.gpa, entry.key_ptr.*, out);
            try buffer.flush();
        }
    }

    // copy main.js, index.html
    var docs_dir = try self.module.comp.zig_lib_directory.handle.openDir("docs", .{});
    defer docs_dir.close();
    try docs_dir.copyFile("main.js", output_dir, "main.js", .{});
    try docs_dir.copyFile("index.html", output_dir, "index.html", .{});
}

fn createFromPath(base_dir: std.fs.Dir, path: []const u8) !std.fs.File {
    var path_tokens = std.mem.tokenize(u8, path, std.fs.path.sep_str);
    var dir = base_dir;
    while (path_tokens.next()) |toc| {
        if (path_tokens.peek() != null) {
            dir.makeDir(toc) catch |e| switch (e) {
                error.PathAlreadyExists => {},
                else => |err| return err,
            };
            dir = try dir.openDir(toc, .{});
        } else {
            return dir.createFile(toc, .{}) catch |e| switch (e) {
                error.PathAlreadyExists => try dir.openFile(toc, .{}),
                else => |err| return err,
            };
        }
    }
    return error.EmptyPath;
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
        zigVersion: []const u8 = build_options.version,
        target: []const u8 = "arst",
        builds: []const struct { target: []const u8 } = &.{
            .{ .target = "arst" },
        },
    },
    packages: []const DocPackage,
    errors: []struct {} = &.{},

    // non-hardcoded stuff
    astNodes: []AstNode,
    calls: []Call,
    files: std.AutoArrayHashMapUnmanaged(*File, usize),
    types: []Type,
    decls: []Decl,
    exprs: []Expr,
    comptimeExprs: []ComptimeExpr,

    guides: std.StringHashMapUnmanaged([]const u8),

    const Call = struct {
        func: Expr,
        args: []Expr,
        ret: Expr,
    };

    pub fn jsonStringify(
        self: DocData,
        opts: std.json.StringifyOptions,
        w: anytype,
    ) !void {
        var jsw = std.json.writeStream(w, 15);
        if (opts.whitespace) |ws| jsw.whitespace = ws;
        try jsw.beginObject();
        inline for (comptime std.meta.tags(std.meta.FieldEnum(DocData))) |f| {
            const f_name = @tagName(f);
            try jsw.objectField(f_name);
            switch (f) {
                .files => try writeFileTableToJson(self.files, &jsw),
                .guides => try writeGuidesToJson(self.guides, &jsw),
                else => {
                    try std.json.stringify(@field(self, f_name), opts, w);
                    jsw.state_index -= 1;
                },
            }
        }
        try jsw.endObject();
    }
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
    const DocTypeKinds = @typeInfo(Type).Union.tag_type.?;

    const ComptimeExpr = struct {
        code: []const u8,
    };
    const DocPackage = struct {
        name: []const u8 = "(root)",
        file: usize = 0, // index into `files`
        main: usize = 0, // index into `types`
        table: std.AutoHashMapUnmanaged(*Package, TableEntry),
        pub const TableEntry = struct {
            name: []const u8,
            value: usize,
        };

        pub fn jsonStringify(
            self: DocPackage,
            opts: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            var jsw = std.json.writeStream(w, 15);
            if (opts.whitespace) |ws| jsw.whitespace = ws;

            try jsw.beginObject();
            inline for (comptime std.meta.tags(std.meta.FieldEnum(DocPackage))) |f| {
                const f_name = @tagName(f);
                try jsw.objectField(f_name);
                switch (f) {
                    .table => try writePackageTableToJson(self.table, &jsw),
                    else => {
                        try std.json.stringify(@field(self, f_name), opts, w);
                        jsw.state_index -= 1;
                    },
                }
            }
            try jsw.endObject();
        }
    };

    const Decl = struct {
        name: []const u8,
        kind: []const u8,
        src: usize, // index into astNodes
        value: WalkResult,
        // The index in astNodes of the `test declname { }` node
        decltest: ?usize = null,
        _analyzed: bool, // omitted in json data

        pub fn jsonStringify(
            self: Decl,
            opts: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            var jsw = std.json.writeStream(w, 15);
            if (opts.whitespace) |ws| jsw.whitespace = ws;
            try jsw.beginArray();
            inline for (comptime std.meta.fields(Decl)) |f| {
                try jsw.arrayElem();
                try std.json.stringify(@field(self, f.name), opts, w);
                jsw.state_index -= 1;
            }
            try jsw.endArray();
        }
    };

    const AstNode = struct {
        file: usize = 0, // index into files
        line: usize = 0,
        col: usize = 0,
        name: ?[]const u8 = null,
        code: ?[]const u8 = null,
        docs: ?[]const u8 = null,
        fields: ?[]usize = null, // index into astNodes
        @"comptime": bool = false,

        pub fn jsonStringify(
            self: AstNode,
            opts: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            var jsw = std.json.writeStream(w, 15);
            if (opts.whitespace) |ws| jsw.whitespace = ws;
            try jsw.beginArray();
            inline for (comptime std.meta.fields(AstNode)) |f| {
                try jsw.arrayElem();
                try std.json.stringify(@field(self, f.name), opts, w);
                jsw.state_index -= 1;
            }
            try jsw.endArray();
        }
    };

    const Type = union(enum) {
        Unanalyzed: struct {},
        Type: struct { name: []const u8 },
        Void: struct { name: []const u8 },
        Bool: struct { name: []const u8 },
        NoReturn: struct { name: []const u8 },
        Int: struct { name: []const u8 },
        Float: struct { name: []const u8 },
        Pointer: struct {
            size: std.builtin.Type.Pointer.Size,
            child: Expr,
            sentinel: ?Expr = null,
            @"align": ?Expr = null,
            address_space: ?Expr = null,
            bit_start: ?Expr = null,
            host_size: ?Expr = null,
            is_ref: bool = false,
            is_allowzero: bool = false,
            is_mutable: bool = false,
            is_volatile: bool = false,
            has_sentinel: bool = false,
            has_align: bool = false,
            has_addrspace: bool = false,
            has_bit_range: bool = false,
        },
        Array: struct {
            len: Expr,
            child: Expr,
            sentinel: ?Expr = null,
        },
        Struct: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: ?[]Expr = null, // (use src->fields to find names)
            is_tuple: bool,
            line_number: usize,
            outer_decl: usize,
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
        ErrorUnion: struct { lhs: Expr, rhs: Expr },
        InferredErrorUnion: struct { payload: Expr },
        ErrorSet: struct {
            name: []const u8,
            fields: ?[]const Field = null,
            // TODO: fn field for inferred error sets?
        },
        Enum: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            // (use src->fields to find field names)
            tag: ?Expr = null, // tag type if specified
            nonexhaustive: bool,
        },
        Union: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: []Expr = &.{}, // (use src->fields to find names)
            tag: ?Expr, // tag type if specified
            auto_enum: bool, // tag is an auto enum
        },
        Fn: struct {
            name: []const u8,
            src: ?usize = null, // index into `astNodes`
            ret: Expr,
            generic_ret: ?Expr = null,
            params: ?[]Expr = null, // (use src->fields to find names)
            lib_name: []const u8 = "",
            is_var_args: bool = false,
            is_inferred_error: bool = false,
            has_lib_name: bool = false,
            has_cc: bool = false,
            cc: ?usize = null,
            @"align": ?usize = null,
            has_align: bool = false,
            is_test: bool = false,
            is_extern: bool = false,
        },
        Opaque: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
        },
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
            opts: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            const active_tag = std.meta.activeTag(self);
            var jsw = std.json.writeStream(w, 15);
            if (opts.whitespace) |ws| jsw.whitespace = ws;
            try jsw.beginArray();
            try jsw.arrayElem();
            try jsw.emitNumber(@enumToInt(active_tag));
            inline for (comptime std.meta.fields(Type)) |case| {
                if (@field(Type, case.name) == active_tag) {
                    const current_value = @field(self, case.name);
                    inline for (comptime std.meta.fields(case.type)) |f| {
                        try jsw.arrayElem();
                        if (f.type == std.builtin.Type.Pointer.Size) {
                            try jsw.emitNumber(@enumToInt(@field(current_value, f.name)));
                        } else {
                            try std.json.stringify(@field(current_value, f.name), opts, w);
                            jsw.state_index -= 1;
                        }
                    }
                }
            }
            try jsw.endArray();
        }
    };

    /// An Expr represents the (untyped) result of analizing instructions.
    /// The data is normalized, which means that an Expr that results in a
    /// type definition will hold an index into `self.types`.
    pub const Expr = union(enum) {
        comptimeExpr: usize, // index in `comptimeExprs`
        void: struct {},
        @"unreachable": struct {},
        null: struct {},
        undefined: struct {},
        @"struct": []FieldVal,
        bool: bool,
        @"anytype": struct {},
        @"&": usize, // index in `exprs`
        type: usize, // index in `types`
        this: usize, // index in `types`
        declRef: usize, // index in `decls`
        builtinField: enum { len, ptr },
        fieldRef: FieldRef,
        refPath: []Expr,
        int: struct {
            value: u64, // direct value
            negated: bool = false,
        },
        int_big: struct {
            value: []const u8, // string representation
            negated: bool = false,
        },
        float: f64, // direct value
        float128: f128, // direct value
        array: []usize, // index in `exprs`
        call: usize, // index in `calls`
        enumLiteral: []const u8, // direct value
        alignOf: usize, // index in `exprs`
        typeOf: usize, // index in `exprs`
        typeInfo: usize, // index in `exprs`
        typeOf_peer: []usize,
        errorUnion: usize, // index in `types`
        as: As,
        sizeOf: usize, // index in `exprs`
        bitSizeOf: usize, // index in `exprs`
        enumToInt: usize, // index in `exprs`
        compileError: usize, //index in `exprs`
        errorSets: usize,
        string: []const u8, // direct value
        sliceIndex: usize,
        slice: Slice,
        cmpxchgIndex: usize,
        cmpxchg: Cmpxchg,
        builtin: Builtin,
        builtinIndex: usize,
        builtinBin: BuiltinBin,
        builtinBinIndex: usize,
        switchIndex: usize, // index in `exprs`
        switchOp: SwitchOp,
        binOp: BinOp,
        binOpIndex: usize,
        const BinOp = struct {
            lhs: usize, // index in `exprs`
            rhs: usize, // index in `exprs`
            name: []const u8 = "", // tag name
        };
        const SwitchOp = struct {
            cond_index: usize,
            file_name: []const u8,
            src: usize,
            outer_decl: usize, // index in `types`
        };
        const BuiltinBin = struct {
            name: []const u8 = "", // fn name
            lhs: usize, // index in `exprs`
            rhs: usize, // index in `exprs`
        };
        const Builtin = struct {
            name: []const u8 = "", // fn name
            param: usize, // index in `exprs`
        };
        const Slice = struct {
            lhs: usize, // index in `exprs`
            start: usize,
            end: ?usize = null,
            sentinel: ?usize = null, // index in `exprs`
        };
        const Cmpxchg = struct {
            name: []const u8,
            type: usize,
            ptr: usize,
            expected_value: usize,
            new_value: usize,
            success_order: usize,
            failure_order: usize,
        };
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
            opts: std.json.StringifyOptions,
            w: anytype,
        ) !void {
            const active_tag = std.meta.activeTag(self);
            var jsw = std.json.writeStream(w, 15);
            if (opts.whitespace) |ws| jsw.whitespace = ws;
            try jsw.beginObject();
            try jsw.objectField(@tagName(active_tag));
            switch (self) {
                .int => {
                    if (self.int.negated) try w.writeAll("-");
                    try jsw.emitNumber(self.int.value);
                },
                .builtinField => {
                    try jsw.emitString(@tagName(self.builtinField));
                },
                else => {
                    inline for (comptime std.meta.fields(Expr)) |case| {
                        // TODO: this is super ugly, fix once `inline else` is a thing
                        if (comptime std.mem.eql(u8, case.name, "builtinField"))
                            continue;
                        if (@field(Expr, case.name) == active_tag) {
                            try std.json.stringify(@field(self, case.name), opts, w);
                            jsw.state_index -= 1;
                            // TODO: we should not reach into the state of the
                            //       json writer, but alas, this is what's
                            //       necessary with the current api.
                            //       would be nice to have a proper integration
                            //       between the json writer and the generic
                            //       std.json.stringify implementation
                        }
                    }
                },
            }
            try jsw.endObject();
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

const AutodocErrors = error{
    OutOfMemory,
    CurrentWorkingDirectoryUnlinked,
    UnexpectedEndOfFile,
} || std.fs.File.OpenError || std.fs.File.ReadError;

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
    parent_src: SrcLocInfo,
    inst_index: usize,
    need_type: bool, // true if the caller needs us to provide also a typeRef
) AutodocErrors!DocData.WalkResult {
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
        .import => {
            const str_tok = data[inst_index].str_tok;
            var path = str_tok.get(file.zir);

            // importFile cannot error out since all files
            // are already loaded at this point
            if (file.pkg.table.get(path)) |other_package| {
                const result = try self.packages.getOrPut(self.arena, other_package);

                // Immediately add this package to the import table of our
                // current package, regardless of wether it's new or not.
                if (self.packages.getPtr(file.pkg)) |current_package| {
                    // TODO: apparently, in the stdlib a file gets analized before
                    //       its package gets added. I guess we're importing a file
                    //       that belongs to another package through its file path?
                    //       (ie not through its package name).
                    //       We're bailing for now, but maybe we shouldn't?
                    _ = try current_package.table.getOrPutValue(
                        self.arena,
                        other_package,
                        .{
                            .name = path,
                            .value = self.packages.getIndex(other_package).?,
                        },
                    );
                }

                if (result.found_existing) {
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .type = result.value_ptr.main },
                    };
                }

                // create a new package entry
                const main_type_index = self.types.items.len;
                result.value_ptr.* = .{
                    .name = path,
                    .main = main_type_index,
                    .table = .{},
                };

                // TODO: Add this package as a dependency to the current pakcage
                // TODO: this seems something that could be done in bulk
                //       at the beginning or the end, or something.
                const root_src_dir = other_package.root_src_directory;
                const root_src_path = other_package.root_src_path;
                const joined_src_path = try root_src_dir.join(self.arena, &.{root_src_path});
                defer self.arena.free(joined_src_path);

                const abs_root_src_path = try std.fs.path.resolve(self.arena, &.{ ".", joined_src_path });
                defer self.arena.free(abs_root_src_path);

                const new_file = self.module.import_table.get(abs_root_src_path).?;

                var root_scope = Scope{
                    .parent = null,
                    .enclosing_type = main_type_index,
                };
                const maybe_tldoc_comment = try self.getTLDocComment(file);
                try self.ast_nodes.append(self.arena, .{
                    .name = "(root)",
                    .docs = maybe_tldoc_comment,
                });
                try self.files.put(self.arena, new_file, main_type_index);
                return self.walkInstruction(
                    new_file,
                    &root_scope,
                    .{},
                    Zir.main_struct_inst,
                    false,
                );
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
                .{},
                Zir.main_struct_inst,
                need_type,
            );
        },
        .ret_type => {
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = @enumToInt(Ref.type_type) },
            };
        },
        .ret_node => {
            const un_node = data[inst_index].un_node;
            return self.walkRef(file, parent_scope, parent_src, un_node.operand, false);
        },
        .ret_load => {
            const un_node = data[inst_index].un_node;
            const res_ptr_ref = un_node.operand;
            const res_ptr_inst = @enumToInt(res_ptr_ref) - Ref.typed_value_map.len;
            // TODO: this instruction doesn't let us know trivially if there's
            //       branching involved or not. For now here's the strat:
            //       We search backwarts until `ret_ptr` for `store_node`,
            //       if we find only one, then that's our value, if we find more
            //       than one, then it means that there's branching involved.
            //       Maybe.

            var i = inst_index - 1;
            var result_ref: ?Ref = null;
            while (i > res_ptr_inst) : (i -= 1) {
                if (tags[i] == .store_node) {
                    const pl_node = data[i].pl_node;
                    const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);
                    if (extra.data.lhs == res_ptr_ref) {
                        // this store_load instruction is indeed pointing at
                        // the result location that we care about!
                        if (result_ref != null) return DocData.WalkResult{
                            .expr = .{ .comptimeExpr = 0 },
                        };
                        result_ref = extra.data.rhs;
                    }
                }
            }

            if (result_ref) |rr| {
                return self.walkRef(file, parent_scope, parent_src, rr, need_type);
            }

            return DocData.WalkResult{
                .expr = .{ .comptimeExpr = 0 },
            };
        },
        .closure_get => {
            const inst_node = data[inst_index].inst_node;
            return try self.walkInstruction(file, parent_scope, parent_src, inst_node.inst, need_type);
        },
        .closure_capture => {
            const un_tok = data[inst_index].un_tok;
            return try self.walkRef(file, parent_scope, parent_src, un_tok.operand, need_type);
        },
        .str => {
            const str = data[inst_index].str.get(file.zir);

            const tRef: ?DocData.Expr = if (!need_type) null else blk: {
                const arrTypeId = self.types.items.len;
                try self.types.append(self.arena, .{
                    .Array = .{
                        .len = .{ .int = .{ .value = str.len } },
                        .child = .{ .type = @enumToInt(Ref.u8_type) },
                        .sentinel = .{ .int = .{
                            .value = 0,
                            .negated = false,
                        } },
                    },
                });
                // const sentinel: ?usize = if (ptr.flags.has_sentinel) 0 else null;
                const ptrTypeId = self.types.items.len;
                try self.types.append(self.arena, .{
                    .Pointer = .{
                        .size = .One,
                        .child = .{ .type = arrTypeId },
                        .sentinel = .{ .int = .{
                            .value = 0,
                            .negated = false,
                        } },
                        .is_mutable = false,
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
                parent_src,
                un_node.operand,
                false,
            );

            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .expr = .{ .compileError = operand_index },
            };
        },
        .enum_literal => {
            const str_tok = data[inst_index].str_tok;
            const literal = file.zir.nullTerminatedString(str_tok.start);
            const type_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .EnumLiteral = .{ .name = "todo enum literal" },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = type_index },
                .expr = .{ .enumLiteral = literal },
            };
        },
        .int => {
            const int = data[inst_index].int;
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                .expr = .{ .int = .{ .value = int } },
            };
        },
        .int_big => {
            // @check
            const str = data[inst_index].str; //.get(file.zir);
            const byte_count = str.len * @sizeOf(std.math.big.Limb);
            const limb_bytes = file.zir.string_bytes[str.start..][0..byte_count];

            var limbs = try self.arena.alloc(std.math.big.Limb, str.len);
            std.mem.copy(u8, std.mem.sliceAsBytes(limbs), limb_bytes);

            const big_int = std.math.big.int.Const{
                .limbs = limbs,
                .positive = true,
            };

            const as_string = try big_int.toStringAlloc(self.arena, 10, .lower);

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                .expr = .{ .int_big = .{ .value = as_string } },
            };
        },

        .slice_start => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceStart, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            self.exprs.items[slice_index] = .{ .slice = .{ .lhs = lhs_index, .start = start_index } };

            return DocData.WalkResult{
                .typeRef = self.decls.items[lhs.expr.declRef].value.typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },
        .slice_end => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceEnd, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
            );
            var end: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.end,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            const end_index = self.exprs.items.len;
            try self.exprs.append(self.arena, end.expr);
            self.exprs.items[slice_index] = .{ .slice = .{ .lhs = lhs_index, .start = start_index, .end = end_index } };

            return DocData.WalkResult{
                .typeRef = self.decls.items[lhs.expr.declRef].value.typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },
        .slice_sentinel => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceSentinel, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
            );
            var end: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.end,
                false,
            );
            var sentinel: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.sentinel,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            const end_index = self.exprs.items.len;
            try self.exprs.append(self.arena, end.expr);
            const sentinel_index = self.exprs.items.len;
            try self.exprs.append(self.arena, sentinel.expr);
            self.exprs.items[slice_index] = .{ .slice = .{ .lhs = lhs_index, .start = start_index, .end = end_index, .sentinel = sentinel_index } };

            return DocData.WalkResult{
                .typeRef = self.decls.items[lhs.expr.declRef].value.typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },

        // @check array_cat and array_mul
        .add,
        .addwrap,
        .add_sat,
        .sub,
        .subwrap,
        .sub_sat,
        .mul,
        .mulwrap,
        .mul_sat,
        .div,
        .shl,
        .shl_sat,
        .shr,
        .bit_or,
        .bit_and,
        // @check still not working when applied in std
        // .array_cat,
        // .array_mul,
        => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .binOp = .{
                .name = @tagName(tags[inst_index]),
                .lhs = lhs_index,
                .rhs = rhs_index,
            } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .binOpIndex = binop_index },
            };
        },
        // compare operators
        .cmp_eq,
        .cmp_neq,
        .cmp_gt,
        .cmp_gte,
        .cmp_lt,
        .cmp_lte,
        => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .binOp = .{
                .name = @tagName(tags[inst_index]),
                .lhs = lhs_index,
                .rhs = rhs_index,
            } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.bool_type) },
                .expr = .{ .binOpIndex = binop_index },
            };
        },

        // builtin functions
        .align_of,
        .bool_to_int,
        .embed_file,
        .error_name,
        .panic,
        .set_cold, // @check
        .set_runtime_safety, // @check
        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .fabs,
        .floor,
        .ceil,
        .trunc,
        .round,
        .tag_name,
        .type_name,
        .frame_type,
        .frame_size,
        .ptr_to_int,
        .min,
        .max,
        .bit_not,
        // @check
        .clz,
        .ctz,
        .pop_count,
        .byte_swap,
        .bit_reverse,
        => {
            const un_node = data[inst_index].un_node;
            const bin_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
            const param = try self.walkRef(file, parent_scope, parent_src, un_node.operand, false);

            const param_index = self.exprs.items.len;
            try self.exprs.append(self.arena, param.expr);

            self.exprs.items[bin_index] = .{ .builtin = .{ .name = @tagName(tags[inst_index]), .param = param_index } };

            return DocData.WalkResult{
                .typeRef = param.typeRef orelse .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .builtinIndex = bin_index },
            };
        },

        .float_to_int,
        .int_to_float,
        .int_to_ptr,
        .int_to_enum,
        .float_cast,
        .int_cast,
        .ptr_cast,
        .truncate,
        .align_cast,
        .has_decl,
        .has_field,
        .div_exact,
        .div_floor,
        .div_trunc,
        .mod,
        .rem,
        .mod_rem,
        .shl_exact,
        .shr_exact,
        .bitcast,
        .vector_type,
        // @check
        .bit_offset_of,
        .offset_of,
        .splat,
        .reduce,
        => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtinBin = .{ .lhs = 0, .rhs = 0 } });

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .builtinBin = .{ .name = @tagName(tags[inst_index]), .lhs = lhs_index, .rhs = rhs_index } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .builtinBinIndex = binop_index },
            };
        },
        .error_union_type => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
            );

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .ErrorUnion = .{
                .lhs = lhs.expr,
                .rhs = rhs.expr,
            } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .errorUnion = type_slot_index },
            };
        },
        .merge_error_sets => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            var lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
            );
            var rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
            );
            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .ErrorUnion = .{
                .lhs = lhs.expr,
                .rhs = rhs.expr,
            } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .errorSets = type_slot_index },
            };
        },
        // .elem_type => {
        //     const un_node = data[inst_index].un_node;

        //     var operand: DocData.WalkResult = try self.walkRef(
        //         file,
        //         parent_scope, parent_src,
        //         un_node.operand,
        //         false,
        //     );

        //     return operand;
        // },
        .ptr_type => {
            const ptr = data[inst_index].ptr_type;
            const extra = file.zir.extraData(Zir.Inst.PtrType, ptr.payload_index);
            var extra_index = extra.end;

            const elem_type_ref = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.elem_type,
                false,
            );

            // @check if `addrspace`, `bit_start` and `host_size` really need to be
            // present in json
            var sentinel: ?DocData.Expr = null;
            if (ptr.flags.has_sentinel) {
                const ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(file, parent_scope, parent_src, ref, false);
                sentinel = ref_result.expr;
                extra_index += 1;
            }

            var @"align": ?DocData.Expr = null;
            if (ptr.flags.has_align) {
                const ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(file, parent_scope, parent_src, ref, false);
                @"align" = ref_result.expr;
                extra_index += 1;
            }
            var address_space: ?DocData.Expr = null;
            if (ptr.flags.has_addrspace) {
                const ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(file, parent_scope, parent_src, ref, false);
                address_space = ref_result.expr;
                extra_index += 1;
            }
            var bit_start: ?DocData.Expr = null;
            if (ptr.flags.has_bit_range) {
                const ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(file, parent_scope, parent_src, ref, false);
                address_space = ref_result.expr;
                extra_index += 1;
            }

            var host_size: ?DocData.Expr = null;
            if (ptr.flags.has_bit_range) {
                const ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(file, parent_scope, parent_src, ref, false);
                host_size = ref_result.expr;
            }

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Pointer = .{
                    .size = ptr.size,
                    .child = elem_type_ref.expr,
                    .has_align = ptr.flags.has_align,
                    .@"align" = @"align",
                    .has_addrspace = ptr.flags.has_addrspace,
                    .address_space = address_space,
                    .has_sentinel = ptr.flags.has_sentinel,
                    .sentinel = sentinel,
                    .is_mutable = ptr.flags.is_mutable,
                    .is_volatile = ptr.flags.is_volatile,
                    .has_bit_range = ptr.flags.has_bit_range,
                    .bit_start = bit_start,
                    .host_size = host_size,
                },
            });
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_type => {
            const pl_node = data[inst_index].pl_node;

            const bin = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index).data;
            const len = try self.walkRef(file, parent_scope, parent_src, bin.lhs, false);
            const child = try self.walkRef(file, parent_scope, parent_src, bin.rhs, false);

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
        .array_type_sentinel => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.ArrayTypeSentinel, pl_node.payload_index);
            const len = try self.walkRef(file, parent_scope, parent_src, extra.data.len, false);
            const sentinel = try self.walkRef(file, parent_scope, parent_src, extra.data.sentinel, false);
            const elem_type = try self.walkRef(file, parent_scope, parent_src, extra.data.elem_type, false);

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Array = .{
                    .len = len.expr,
                    .child = elem_type.expr,
                    .sentinel = sentinel.expr,
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
            const array_data = try self.arena.alloc(usize, operands.len - 1);

            std.debug.assert(operands.len > 0);
            var array_type = try self.walkRef(file, parent_scope, parent_src, operands[0], false);

            for (operands[1..], 0..) |op, idx| {
                const wr = try self.walkRef(file, parent_scope, parent_src, op, false);
                const expr_index = self.exprs.items.len;
                try self.exprs.append(self.arena, wr.expr);
                array_data[idx] = expr_index;
            }

            return DocData.WalkResult{
                .typeRef = array_type.expr,
                .expr = .{ .array = array_data },
            };
        },
        .array_init_anon => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len);

            for (operands, 0..) |op, idx| {
                const wr = try self.walkRef(file, parent_scope, parent_src, op, false);
                const expr_index = self.exprs.items.len;
                try self.exprs.append(self.arena, wr.expr);
                array_data[idx] = expr_index;
            }

            return DocData.WalkResult{
                .typeRef = null,
                .expr = .{ .array = array_data },
            };
        },
        .array_init_ref => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len - 1);

            std.debug.assert(operands.len > 0);
            var array_type = try self.walkRef(file, parent_scope, parent_src, operands[0], false);

            for (operands[1..], 0..) |op, idx| {
                const wr = try self.walkRef(file, parent_scope, parent_src, op, false);
                const expr_index = self.exprs.items.len;
                try self.exprs.append(self.arena, wr.expr);
                array_data[idx] = expr_index;
            }

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Pointer = .{
                    .size = .One,
                    .child = array_type.expr,
                },
            });

            const expr_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .array = array_data });

            return DocData.WalkResult{
                .typeRef = .{ .type = type_slot_index },
                .expr = .{ .@"&" = expr_index },
            };
        },
        .array_init_anon_ref => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len);

            for (operands, 0..) |op, idx| {
                const wr = try self.walkRef(file, parent_scope, parent_src, op, false);
                const expr_index = self.exprs.items.len;
                try self.exprs.append(self.arena, wr.expr);
                array_data[idx] = expr_index;
            }

            const expr_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .array = array_data });

            return DocData.WalkResult{
                .typeRef = null,
                .expr = .{ .@"&" = expr_index },
            };
        },
        .float => {
            const float = data[inst_index].float;
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_float_type) },
                .expr = .{ .float = float },
            };
        },
        // @check: In frontend I'm handling float128 with `.toFixed(2)`
        .float128 => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Float128, pl_node.payload_index);
            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_float_type) },
                .expr = .{ .float128 = extra.data.get() },
            };
        },
        .negate => {
            const un_node = data[inst_index].un_node;

            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
            );
            switch (operand.expr) {
                .int => |*int| int.negated = true,
                .int_big => |*int_big| int_big.negated = true,
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
                parent_src,
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
        .bit_size_of => {
            // not working correctly with `align()`
            const un_node = data[inst_index].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .bitSizeOf = operand_index },
            };
        },
        .enum_to_int => {
            // not working correctly with `align()`
            const un_node = data[inst_index].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                .expr = .{ .enumToInt = operand_index },
            };
        },
        .switch_block => {
            // WIP
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SwitchBlock, pl_node.payload_index);
            const cond_index = self.exprs.items.len;

            _ = try self.walkRef(file, parent_scope, parent_src, extra.data.operand, false);

            const ast_index = self.ast_nodes.items.len;
            const type_index = self.types.items.len - 1;

            // const ast_line = self.ast_nodes.items[ast_index - 1];

            // const sep = "=" ** 200;
            // log.debug("{s}", .{sep});
            // log.debug("SWITCH BLOCK", .{});
            // log.debug("extra = {any}", .{extra});
            // log.debug("outer_decl = {any}", .{self.types.items[type_index]});
            // log.debug("ast_lines = {}", .{ast_line});
            // log.debug("{s}", .{sep});

            const switch_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .switchOp = .{
                .cond_index = cond_index,
                .file_name = file.sub_file_path,
                .src = ast_index,
                .outer_decl = type_index,
            } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                .expr = .{ .switchIndex = switch_index },
            };
        },
        .switch_cond => {
            const un_node = data[inst_index].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            // const ast_index = self.ast_nodes.items.len;
            // const sep = "=" ** 200;
            // log.debug("{s}", .{sep});
            // log.debug("SWITCH COND", .{});
            // log.debug("ast index = {}", .{ast_index});
            // log.debug("ast previous = {}", .{self.ast_nodes.items[ast_index - 1]});
            // log.debug("{s}", .{sep});

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeOf = operand_index },
            };
        },

        .typeof => {
            const un_node = data[inst_index].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
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
        .typeof_builtin => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Block, pl_node.payload_index);
            const body = file.zir.extra[extra.end..][extra.data.body_len - 1];
            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                data[body].@"break".operand,
                false,
            );

            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeOf = operand_index },
            };
        },
        .type_info => {
            // @check
            const un_node = data[inst_index].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
            );

            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeInfo = operand_index },
            };
        },
        .as_node, .as_shift_operand => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.As, pl_node.payload_index);
            const dest_type_walk = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.dest_type,
                false,
            );

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
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
                parent_src,
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
            return DocData.WalkResult{
                .expr = .{ .declRef = decls_slot_index },
            };
        },
        .field_val, .field_call_bind, .field_ptr, .field_type => {
            // TODO: field type uses Zir.Inst.FieldType, it just happens to have the
            // same layout as Zir.Inst.Field :^)
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Field, pl_node.payload_index);

            var path: std.ArrayListUnmanaged(DocData.Expr) = .{};
            try path.append(self.arena, .{
                .string = file.zir.nullTerminatedString(extra.data.field_name_start),
            });

            // Put inside path the starting index of each decl name that
            // we encounter as we navigate through all the field_*s
            const lhs_ref = blk: {
                var lhs_extra = extra;
                while (true) {
                    if (@enumToInt(lhs_extra.data.lhs) < Ref.typed_value_map.len) {
                        break :blk lhs_extra.data.lhs;
                    }

                    const lhs = @enumToInt(lhs_extra.data.lhs) - Ref.typed_value_map.len;
                    if (tags[lhs] != .field_val and
                        tags[lhs] != .field_call_bind and
                        tags[lhs] != .field_ptr and
                        tags[lhs] != .field_type) break :blk lhs_extra.data.lhs;

                    lhs_extra = file.zir.extraData(
                        Zir.Inst.Field,
                        data[lhs].pl_node.payload_index,
                    );

                    try path.append(self.arena, .{
                        .string = file.zir.nullTerminatedString(lhs_extra.data.field_name_start),
                    });
                }
            };

            // If the lhs is a `call` instruction, it means that we're inside
            // a function call and we're referring to one of its arguments.
            // We can't just blindly analyze the instruction or we will
            // start recursing forever.
            // TODO: add proper resolution of the container type for `calls`
            // TODO: we're like testing lhs as an instruction twice
            //       (above and below) this todo, maybe a cleaer solution woul
            //       avoid that.
            // TODO: double check that we really don't need type info here

            const wr = blk: {
                if (@enumToInt(lhs_ref) >= Ref.typed_value_map.len) {
                    const lhs_inst = @enumToInt(lhs_ref) - Ref.typed_value_map.len;
                    if (tags[lhs_inst] == .call) {
                        break :blk DocData.WalkResult{
                            .expr = .{
                                .comptimeExpr = 0,
                            },
                        };
                    }
                }

                break :blk try self.walkRef(file, parent_scope, parent_src, lhs_ref, false);
            };
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
            try self.tryResolveRefPath(file, inst_index, path.items);
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
                .code = "if (...) { ... }",
            });
            return res;
        },
        .block_inline => {
            return self.walkRef(
                file,
                parent_scope,
                parent_src,
                getBlockInlineBreak(file.zir, inst_index) orelse {
                    const res = DocData.WalkResult{ .expr = .{
                        .comptimeExpr = self.comptime_exprs.items.len,
                    } };
                    try self.comptime_exprs.append(self.arena, .{
                        .code = "if (...) { ... }",
                    });
                    return res;
                },
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
                    const field_src = try self.srcLocInfo(
                        file,
                        field_pl_node.src_node,
                        parent_src,
                    );

                    // On first iteration use field info to find out the struct type
                    if (idx == extra.end) {
                        const wr = try self.walkRef(
                            file,
                            parent_scope,
                            field_src,
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
                    parent_src,
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
        .struct_init_empty => {
            const un_node = data[inst_index].un_node;

            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
            );

            return DocData.WalkResult{
                .typeRef = operand.expr,
                .expr = .{ .@"struct" = &.{} },
            };
        },
        .struct_init_anon => {
            const pl_node = data[inst_index].pl_node;
            const extra = file.zir.extraData(Zir.Inst.StructInitAnon, pl_node.payload_index);

            const field_vals = try self.arena.alloc(
                DocData.Expr.FieldVal,
                extra.data.fields_len,
            );

            var idx = extra.end;
            for (field_vals) |*fv| {
                const init_extra = file.zir.extraData(Zir.Inst.StructInitAnon.Item, idx);
                const field_name = file.zir.nullTerminatedString(init_extra.data.field_name);
                const value = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    init_extra.data.init,
                    need_type,
                );
                fv.* = .{ .name = field_name, .val = value };
                idx = init_extra.end;
            }

            return DocData.WalkResult{
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
        .param_anytype, .param_anytype_comptime => {
            // @check if .param_anytype_comptime can be here
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

            const callee = try self.walkRef(file, parent_scope, parent_src, extra.data.callee, need_type);

            const args_len = extra.data.flags.args_len;
            var args = try self.arena.alloc(DocData.Expr, args_len);
            const body = file.zir.extra[extra.end..];

            var i: usize = 0;
            while (i < args_len) : (i += 1) {
                const arg_end = file.zir.extra[extra.end + i];
                const break_index = body[arg_end - 1];
                const ref = data[break_index].@"break".operand;
                // TODO: consider toggling need_type to true if we ever want
                //       to show discrepancies between the types of provided
                //       arguments and the types declared in the function
                //       signature for its parameters.
                const wr = try self.walkRef(file, parent_scope, parent_src, ref, false);
                args[i] = wr.expr;
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
            try self.types.append(self.arena, .{ .Unanalyzed = .{} });

            const result = self.analyzeFunction(
                file,
                parent_scope,
                parent_src,
                inst_index,
                self_ast_node_index,
                type_slot_index,
                tags[inst_index] == .func_inferred,
            );

            return result;
        },
        .func_fancy => {
            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .Unanalyzed = .{} });

            const result = self.analyzeFancyFunction(
                file,
                parent_scope,
                parent_src,
                inst_index,
                self_ast_node_index,
                type_slot_index,
            );

            return result;
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
                .typeof_peer => {
                    // Zir says it's a NodeMultiOp but in this case it's TypeOfPeer
                    const extra = file.zir.extraData(Zir.Inst.TypeOfPeer, extended.operand);
                    const args = file.zir.refSlice(extra.end, extended.small);
                    const array_data = try self.arena.alloc(usize, args.len);

                    var array_type: ?DocData.Expr = null;
                    for (args, 0..) |arg, idx| {
                        const wr = try self.walkRef(file, parent_scope, parent_src, arg, idx == 0);
                        if (idx == 0) {
                            array_type = wr.typeRef;
                        }

                        const expr_index = self.exprs.items.len;
                        try self.exprs.append(self.arena, wr.expr);
                        array_data[idx] = expr_index;
                    }

                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{
                        .Array = .{
                            .len = .{
                                .int = .{
                                    .value = args.len,
                                    .negated = false,
                                },
                            },
                            .child = .{ .type = 0 },
                        },
                    });
                    const result = DocData.WalkResult{
                        .typeRef = .{ .type = type_slot_index },
                        .expr = .{ .typeOf_peer = array_data },
                    };

                    return result;
                },
                .opaque_decl => {
                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{ .Unanalyzed = .{} });

                    var scope: Scope = .{
                        .parent = parent_scope,
                        .enclosing_type = type_slot_index,
                    };

                    const small = @bitCast(Zir.Inst.OpaqueDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;

                    const src_node: ?i32 = if (small.has_src_node) blk: {
                        const src_node = @bitCast(i32, file.zir.extra[extra_index]);
                        extra_index += 1;
                        break :blk src_node;
                    } else null;

                    const src_info = if (src_node) |sn|
                        try self.srcLocInfo(file, sn, parent_src)
                    else
                        parent_src;

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
                        while (it.next()) |d| {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            switch (decl_name_index) {
                                0, 1, 2 => continue,
                                else => if (file.zir.string_bytes[decl_name_index] == 0) {
                                    continue;
                                },
                            }

                            const decl_slot_index = self.decls.items.len;
                            try self.decls.append(self.arena, undefined);
                            self.decls.items[decl_slot_index]._analyzed = false;

                            // TODO: inspect usingnamespace decls and unpack their contents!

                            try scope.insertDeclRef(self.arena, decl_name_index, decl_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        src_info,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    self.types.items[type_slot_index] = .{
                        .Opaque = .{
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
                .variable => {
                    const extra = file.zir.extraData(Zir.Inst.ExtendedVar, extended.operand);

                    const small = @bitCast(Zir.Inst.ExtendedVar.Small, extended.small);
                    var extra_index: usize = extra.end;
                    if (small.has_lib_name) extra_index += 1;
                    if (small.has_align) extra_index += 1;

                    const var_type = try self.walkRef(file, parent_scope, parent_src, extra.data.var_type, need_type);

                    var value: DocData.WalkResult = .{
                        .typeRef = var_type.expr,
                        .expr = .{ .undefined = .{} },
                    };

                    if (small.has_init) {
                        const var_init_ref = @intToEnum(Ref, file.zir.extra[extra_index]);
                        const var_init = try self.walkRef(file, parent_scope, parent_src, var_init_ref, need_type);
                        value.expr = var_init.expr;
                        value.typeRef = var_init.typeRef;
                    }

                    return value;
                },
                .union_decl => {
                    const type_slot_index = self.types.items.len;
                    try self.types.append(self.arena, .{ .Unanalyzed = .{} });

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

                    const src_info = if (src_node) |sn|
                        try self.srcLocInfo(file, sn, parent_src)
                    else
                        parent_src;

                    const tag_type: ?DocData.Expr = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        const tag_ref = @intToEnum(Ref, tag_type);
                        const wr = try self.walkRef(file, parent_scope, parent_src, tag_ref, false);
                        break :blk wr.expr;
                    } else null;

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
                        while (it.next()) |d| {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            switch (decl_name_index) {
                                0, 1, 2 => continue,
                                else => if (file.zir.string_bytes[decl_name_index] == 0) {
                                    continue;
                                },
                            }

                            const decl_slot_index = self.decls.items.len;
                            try self.decls.append(self.arena, undefined);
                            self.decls.items[decl_slot_index]._analyzed = false;

                            // TODO: inspect usingnamespace decls and unpack their contents!

                            try scope.insertDeclRef(self.arena, decl_name_index, decl_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        src_info,
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
                        src_info,
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
                            .tag = tag_type,
                            .auto_enum = small.auto_enum_tag,
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
                    try self.types.append(self.arena, .{ .Unanalyzed = .{} });

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

                    const src_info = if (src_node) |sn|
                        try self.srcLocInfo(file, sn, parent_src)
                    else
                        parent_src;

                    const tag_type: ?DocData.Expr = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        const tag_ref = @intToEnum(Ref, tag_type);
                        const wr = try self.walkRef(file, parent_scope, parent_src, tag_ref, false);
                        break :blk wr.expr;
                    } else null;

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
                        while (it.next()) |d| {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            switch (decl_name_index) {
                                0, 1, 2 => continue,
                                else => if (file.zir.string_bytes[decl_name_index] == 0) {
                                    continue;
                                },
                            }

                            const decl_slot_index = self.decls.items.len;
                            try self.decls.append(self.arena, undefined);
                            self.decls.items[decl_slot_index]._analyzed = false;

                            // TODO: inspect usingnamespace decls and unpack their contents!

                            try scope.insertDeclRef(self.arena, decl_name_index, decl_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        src_info,
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
                            .tag = tag_type,
                            .nonexhaustive = small.nonexhaustive,
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
                    try self.types.append(self.arena, .{ .Unanalyzed = .{} });

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

                    const src_info = if (src_node) |sn|
                        try self.srcLocInfo(file, sn, parent_src)
                    else
                        parent_src;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk decls_len;
                    } else 0;

                    // TODO: Expose explicit backing integer types in some way.
                    if (small.has_backing_int) {
                        const backing_int_body_len = file.zir.extra[extra_index];
                        extra_index += 1; // backing_int_body_len
                        if (backing_int_body_len == 0) {
                            extra_index += 1; // backing_int_ref
                        } else {
                            extra_index += backing_int_body_len; // backing_int_body_inst
                        }
                    }

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    const decls_first_index = self.decls.items.len;
                    // Decl name lookahead for reserving slots in `scope` (and `decls`).
                    // Done to make sure that all decl refs can be resolved correctly,
                    // even if we haven't fully analyzed the decl yet.
                    {
                        var it = file.zir.declIterator(@intCast(u32, inst_index));
                        while (it.next()) |d| {
                            const decl_name_index = file.zir.extra[d.sub_index + 5];
                            switch (decl_name_index) {
                                0, 1, 2 => continue,
                                else => if (file.zir.string_bytes[decl_name_index] == 0) {
                                    continue;
                                },
                            }

                            const decl_slot_index = self.decls.items.len;
                            try self.decls.append(self.arena, undefined);
                            self.decls.items[decl_slot_index]._analyzed = false;

                            // TODO: inspect usingnamespace decls and unpack their contents!

                            try scope.insertDeclRef(self.arena, decl_name_index, decl_slot_index);
                        }
                    }

                    extra_index = try self.walkDecls(
                        file,
                        &scope,
                        src_info,
                        decls_first_index,
                        decls_len,
                        &decl_indexes,
                        &priv_decl_indexes,
                        extra_index,
                    );

                    var field_type_refs: std.ArrayListUnmanaged(DocData.Expr) = .{};
                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    try self.collectStructFieldInfo(
                        file,
                        &scope,
                        src_info,
                        fields_len,
                        &field_type_refs,
                        &field_name_indexes,
                        extra_index,
                        small.is_tuple,
                    );

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    self.types.items[type_slot_index] = .{
                        .Struct = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                            .fields = field_type_refs.items,
                            .is_tuple = small.is_tuple,
                            .line_number = self.ast_nodes.items[self_ast_node_index].line,
                            .outer_decl = type_slot_index - 1,
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
                .error_to_int,
                .int_to_error,
                .reify,
                .const_cast,
                .volatile_cast,
                => {
                    const extra = file.zir.extraData(Zir.Inst.UnNode, extended.operand).data;
                    const bin_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
                    const param = try self.walkRef(file, parent_scope, parent_src, extra.operand, false);

                    const param_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, param.expr);

                    self.exprs.items[bin_index] = .{ .builtin = .{ .name = @tagName(tags[inst_index]), .param = param_index } };

                    return DocData.WalkResult{
                        .typeRef = param.typeRef orelse .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .builtinIndex = bin_index },
                    };
                },
                .cmpxchg => {
                    const extra = file.zir.extraData(Zir.Inst.Cmpxchg, extended.operand).data;

                    const last_type_index = self.exprs.items.len;
                    const last_type = self.exprs.items[last_type_index - 1];
                    const type_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, last_type);

                    const ptr_index = self.exprs.items.len;
                    var ptr: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.ptr,
                        false,
                    );
                    try self.exprs.append(self.arena, ptr.expr);

                    const expected_value_index = self.exprs.items.len;
                    var expected_value: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.expected_value,
                        false,
                    );
                    try self.exprs.append(self.arena, expected_value.expr);

                    const new_value_index = self.exprs.items.len;
                    var new_value: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.new_value,
                        false,
                    );
                    try self.exprs.append(self.arena, new_value.expr);

                    const success_order_index = self.exprs.items.len;
                    var success_order: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.success_order,
                        false,
                    );
                    try self.exprs.append(self.arena, success_order.expr);

                    const failure_order_index = self.exprs.items.len;
                    var failure_order: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.failure_order,
                        false,
                    );
                    try self.exprs.append(self.arena, failure_order.expr);

                    const cmpxchg_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .cmpxchg = .{
                        .name = @tagName(tags[inst_index]),
                        .type = type_index,
                        .ptr = ptr_index,
                        .expected_value = expected_value_index,
                        .new_value = new_value_index,
                        .success_order = success_order_index,
                        .failure_order = failure_order_index,
                    } });
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
                        .expr = .{ .cmpxchgIndex = cmpxchg_index },
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
    parent_src: SrcLocInfo,
    decls_first_index: usize,
    decls_len: usize,
    decl_indexes: *std.ArrayListUnmanaged(usize),
    priv_decl_indexes: *std.ArrayListUnmanaged(usize),
    extra_start: usize,
) AutodocErrors!usize {
    const data = file.zir.instructions.items(.data);
    const bit_bags_count = std.math.divCeil(usize, decls_len, 8) catch unreachable;
    var extra_index = extra_start + bit_bags_count;
    var bit_bag_index: usize = extra_start;
    var cur_bit_bag: u32 = undefined;
    var decl_i: u32 = 0;

    // NOTE: we're not outputting every ZIR decl as a Autodoc decl.
    //       tests, comptime blocks and usingnamespace are skipped.
    //       this is why we `need good_decls_i`.
    var good_decls_i: usize = 0;
    while (decl_i < decls_len) : (decl_i += 1) {
        const decls_slot_index = decls_first_index + good_decls_i;

        if (decl_i % 8 == 0) {
            cur_bit_bag = file.zir.extra[bit_bag_index];
            bit_bag_index += 1;
        }
        const is_pub = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const is_exported = @truncate(u1, cur_bit_bag) != 0;
        _ = is_exported;
        cur_bit_bag >>= 1;
        const has_align = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_section_or_addrspace = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        // const sub_index = extra_index;

        // const hash_u32s = file.zir.extra[extra_index..][0..4];
        extra_index += 4;

        // const line = file.zir.extra[extra_index];
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

        // This is known to work because decl values are always block_inlines
        const value_pl_node = data[value_index].pl_node;
        const decl_src = try self.srcLocInfo(file, value_pl_node.src_node, parent_src);

        const name: []const u8 = switch (decl_name_index) {
            0, 1 => continue, // comptime or usingnamespace decl
            2 => {
                // decl test
                const decl_being_tested = scope.resolveDeclName(doc_comment_index);
                const func_index = getBlockInlineBreak(file.zir, value_index).?;

                const pl_node = data[Zir.refToIndex(func_index).?].pl_node;
                const fn_src = try self.srcLocInfo(file, pl_node.src_node, decl_src);
                const tree = try file.getTree(self.module.gpa);
                const test_source_code = tree.getNodeSource(fn_src.src_node);

                const ast_node_index = self.ast_nodes.items.len;
                try self.ast_nodes.append(self.arena, .{
                    .file = 0,
                    .line = 0,
                    .col = 0,
                    .code = test_source_code,
                });
                self.decls.items[decl_being_tested].decltest = ast_node_index;
                continue;
            },
            else => blk: {
                if (file.zir.string_bytes[decl_name_index] == 0) {
                    // test decl
                    continue;
                }
                break :blk file.zir.nullTerminatedString(decl_name_index);
            },
        };

        // If we got here, it means that this decl is not a test, usingnamespace
        // or a comptime block decl.
        good_decls_i += 1;

        const doc_comment: ?[]const u8 = if (doc_comment_index != 0)
            file.zir.nullTerminatedString(doc_comment_index)
        else
            null;

        // astnode
        const ast_node_index = idx: {
            const idx = self.ast_nodes.items.len;
            try self.ast_nodes.append(self.arena, .{
                .file = self.files.getIndex(file).?,
                .line = decl_src.line,
                .col = 0,
                .docs = doc_comment,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            break :idx idx;
        };

        const walk_result = try self.walkInstruction(file, scope, decl_src, value_index, true);

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

        const kind: []const u8 = if (try self.declIsVar(file, value_pl_node.src_node, parent_src)) "var" else "const";

        self.decls.items[decls_slot_index] = .{
            ._analyzed = true,
            .name = name,
            .src = ast_node_index,
            //.typeRef = decl_type_ref,
            .value = walk_result,
            .kind = kind,
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
) AutodocErrors!void {
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
                path[i + 1] = (try self.cteTodo("<match failure>")).expr;
                continue :outer;
            },
            .comptimeExpr, .call, .typeOf => {
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
                        "TODO: handle `{s}` in tryResolveDeclPath.type\nInfo: {}",
                        .{ @tagName(self.types.items[t_index]), resolved_parent },
                    );
                },
                .ComptimeExpr => {
                    // Same as the comptimeExpr branch above
                    break :outer;
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
                .Array => {
                    if (std.mem.eql(u8, child_string, "len")) {
                        path[i + 1] = .{
                            .builtinField = .len,
                        };
                    } else {
                        panicWithContext(
                            file,
                            inst_index,
                            "TODO: handle `{s}` in tryResolveDeclPath.type.Array\nInfo: {}",
                            .{ child_string, resolved_parent },
                        );
                    }
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

                    for (self.ast_nodes.items[t_enum.src].fields.?, 0..) |ast_node, idx| {
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

                    for (self.ast_nodes.items[t_union.src].fields.?, 0..) |ast_node, idx| {
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

                    for (self.ast_nodes.items[t_struct.src].fields.?, 0..) |ast_node, idx| {
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
                    // printWithContext(
                    //     file,
                    //     inst_index,
                    //     "failed to match `{s}` in struct",
                    //     .{child_string},
                    // );
                    // path[i + 1] = (try self.cteTodo("match failure")).expr;
                    //
                    // that's working
                    path[i + 1] = (try self.cteTodo(child_string)).expr;
                    continue :outer;
                },
                .Opaque => |t_opaque| {
                    for (t_opaque.pubDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }
                    for (t_opaque.privDecls) |d| {
                        // TODO: this could be improved a lot
                        //       by having our own string table!
                        const decl = self.decls.items[d];
                        if (std.mem.eql(u8, decl.name, child_string)) {
                            path[i + 1] = .{ .declRef = d };
                            continue :outer;
                        }
                    }

                    // if we got here, our search failed
                    printWithContext(
                        file,
                        inst_index,
                        "failed to match `{s}` in opaque",
                        .{child_string},
                    );

                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },
            },
        }
    }

    if (self.pending_ref_paths.get(&path[path.len - 1])) |waiter_list| {
        // It's important to de-register ourselves as pending before
        // attempting to resolve any other decl.
        _ = self.pending_ref_paths.remove(&path[path.len - 1]);

        for (waiter_list.items) |resume_info| {
            try self.tryResolveRefPath(resume_info.file, inst_index, resume_info.ref_path);
        }
        // TODO: this is where we should free waiter_list, but its in the arena
        //       that said, we might want to store it elsewhere and reclaim memory asap
    }
}
fn analyzeFancyFunction(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo,
    inst_index: usize,
    self_ast_node_index: usize,
    type_slot_index: usize,
) AutodocErrors!DocData.WalkResult {
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
            else => {
                panicWithContext(
                    file,
                    param_index,
                    "TODO: handle `{s}` in walkInstruction.func\n",
                    .{@tagName(tags[param_index])},
                );
            },
            .param_anytype, .param_anytype_comptime => {
                // TODO: where are the doc comments?
                const str_tok = data[param_index].str_tok;

                const name = str_tok.get(file.zir);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                self.ast_nodes.appendAssumeCapacity(.{
                    .name = name,
                    .docs = "",
                    .@"comptime" = tags[param_index] == .param_anytype_comptime,
                });

                param_type_refs.appendAssumeCapacity(
                    DocData.Expr{ .@"anytype" = .{} },
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
                const param_type_ref = try self.walkRef(file, scope, parent_src, break_operand, false);

                param_type_refs.appendAssumeCapacity(param_type_ref.expr);
            },
        }
    }

    self.ast_nodes.items[self_ast_node_index].fields = param_ast_indexes.items;

    const pl_node = data[inst_index].pl_node;
    const extra = file.zir.extraData(Zir.Inst.FuncFancy, pl_node.payload_index);

    var extra_index: usize = extra.end;

    var lib_name: []const u8 = "";
    if (extra.data.bits.has_lib_name) {
        lib_name = file.zir.nullTerminatedString(file.zir.extra[extra_index]);
        extra_index += 1;
    }

    var align_index: ?usize = null;
    if (extra.data.bits.has_align_ref) {
        const align_ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        align_index = self.exprs.items.len;
        _ = try self.walkRef(file, scope, parent_src, align_ref, false);
        extra_index += 1;
    } else if (extra.data.bits.has_align_body) {
        const align_body_len = file.zir.extra[extra_index];
        extra_index += 1;
        const align_body = file.zir.extra[extra_index .. extra_index + align_body_len];
        _ = align_body;
        // TODO: analyze the block (or bail with a comptimeExpr)
        extra_index += align_body_len;
    } else {
        // default alignment
    }

    var addrspace_index: ?usize = null;
    if (extra.data.bits.has_addrspace_ref) {
        const addrspace_ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        addrspace_index = self.exprs.items.len;
        _ = try self.walkRef(file, scope, parent_src, addrspace_ref, false);
        extra_index += 1;
    } else if (extra.data.bits.has_addrspace_body) {
        const addrspace_body_len = file.zir.extra[extra_index];
        extra_index += 1;
        const addrspace_body = file.zir.extra[extra_index .. extra_index + addrspace_body_len];
        _ = addrspace_body;
        // TODO: analyze the block (or bail with a comptimeExpr)
        extra_index += addrspace_body_len;
    } else {
        // default alignment
    }

    var section_index: ?usize = null;
    if (extra.data.bits.has_section_ref) {
        const section_ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        section_index = self.exprs.items.len;
        _ = try self.walkRef(file, scope, parent_src, section_ref, false);
        extra_index += 1;
    } else if (extra.data.bits.has_section_body) {
        const section_body_len = file.zir.extra[extra_index];
        extra_index += 1;
        const section_body = file.zir.extra[extra_index .. extra_index + section_body_len];
        _ = section_body;
        // TODO: analyze the block (or bail with a comptimeExpr)
        extra_index += section_body_len;
    } else {
        // default alignment
    }

    var cc_index: ?usize = null;
    if (extra.data.bits.has_cc_ref) {
        const cc_ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        cc_index = self.exprs.items.len;
        _ = try self.walkRef(file, scope, parent_src, cc_ref, false);
        extra_index += 1;
    } else if (extra.data.bits.has_cc_body) {
        const cc_body_len = file.zir.extra[extra_index];
        extra_index += 1;
        const cc_body = file.zir.extra[extra_index .. extra_index + cc_body_len];
        _ = cc_body;
        // TODO: analyze the block (or bail with a comptimeExpr)
        extra_index += cc_body_len;
    } else {
        // auto calling convention
    }

    // ret
    const ret_type_ref: DocData.Expr = switch (fn_info.ret_ty_body.len) {
        0 => switch (fn_info.ret_ty_ref) {
            .none => DocData.Expr{ .void = .{} },
            else => blk: {
                const ref = fn_info.ret_ty_ref;
                const wr = try self.walkRef(file, scope, parent_src, ref, false);
                break :blk wr.expr;
            },
        },
        else => blk: {
            const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
            const break_operand = data[last_instr_index].@"break".operand;
            const wr = try self.walkRef(file, scope, parent_src, break_operand, false);
            break :blk wr.expr;
        },
    };

    // TODO: a complete version of this will probably need a scope
    //       in order to evaluate correctly closures around funcion
    //       parameters etc.
    const generic_ret: ?DocData.Expr = switch (ret_type_ref) {
        .type => |t| blk: {
            if (fn_info.body.len == 0) break :blk null;
            if (t == @enumToInt(Ref.type_type)) {
                break :blk try self.getGenericReturnType(
                    file,
                    scope,
                    parent_src,
                    fn_info.body[0],
                );
            } else {
                break :blk null;
            }
        },
        else => null,
    };

    // if we're analyzing a funcion signature (ie without body), we
    // actually don't have an ast_node reserved for us, but since
    // we don't have a name, we don't need it.
    const src = if (fn_info.body.len == 0) 0 else self_ast_node_index;

    self.types.items[type_slot_index] = .{
        .Fn = .{
            .name = "todo_name func",
            .src = src,
            .params = param_type_refs.items,
            .ret = ret_type_ref,
            .generic_ret = generic_ret,
            .is_extern = extra.data.bits.is_extern,
            .has_cc = cc_index != null,
            .has_align = align_index != null,
            .has_lib_name = extra.data.bits.has_lib_name,
            .lib_name = lib_name,
            .is_inferred_error = extra.data.bits.is_inferred_error,
            .cc = cc_index,
            .@"align" = align_index,
        },
    };

    return DocData.WalkResult{
        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
        .expr = .{ .type = type_slot_index },
    };
}
fn analyzeFunction(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo,
    inst_index: usize,
    self_ast_node_index: usize,
    type_slot_index: usize,
    ret_is_inferred_error_set: bool,
) AutodocErrors!DocData.WalkResult {
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
            else => {
                panicWithContext(
                    file,
                    param_index,
                    "TODO: handle `{s}` in walkInstruction.func\n",
                    .{@tagName(tags[param_index])},
                );
            },
            .param_anytype, .param_anytype_comptime => {
                // TODO: where are the doc comments?
                const str_tok = data[param_index].str_tok;

                const name = str_tok.get(file.zir);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                self.ast_nodes.appendAssumeCapacity(.{
                    .name = name,
                    .docs = "",
                    .@"comptime" = tags[param_index] == .param_anytype_comptime,
                });

                param_type_refs.appendAssumeCapacity(
                    DocData.Expr{ .@"anytype" = .{} },
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
                const param_type_ref = try self.walkRef(file, scope, parent_src, break_operand, false);

                param_type_refs.appendAssumeCapacity(param_type_ref.expr);
            },
        }
    }

    // ret
    const ret_type_ref: DocData.Expr = switch (fn_info.ret_ty_body.len) {
        0 => switch (fn_info.ret_ty_ref) {
            .none => DocData.Expr{ .void = .{} },
            else => blk: {
                const ref = fn_info.ret_ty_ref;
                const wr = try self.walkRef(file, scope, parent_src, ref, false);
                break :blk wr.expr;
            },
        },
        else => blk: {
            const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
            const break_operand = data[last_instr_index].@"break".operand;
            const wr = try self.walkRef(file, scope, parent_src, break_operand, false);
            break :blk wr.expr;
        },
    };

    // TODO: a complete version of this will probably need a scope
    //       in order to evaluate correctly closures around funcion
    //       parameters etc.
    const generic_ret: ?DocData.Expr = switch (ret_type_ref) {
        .type => |t| blk: {
            if (fn_info.body.len == 0) break :blk null;
            if (t == @enumToInt(Ref.type_type)) {
                break :blk try self.getGenericReturnType(
                    file,
                    scope,
                    parent_src,
                    fn_info.body[0],
                );
            } else {
                break :blk null;
            }
        },
        else => null,
    };

    const ret_type: DocData.Expr = blk: {
        if (ret_is_inferred_error_set) {
            const ret_type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .InferredErrorUnion = .{ .payload = ret_type_ref },
            });
            break :blk .{ .type = ret_type_slot_index };
        } else break :blk ret_type_ref;
    };

    // if we're analyzing a funcion signature (ie without body), we
    // actually don't have an ast_node reserved for us, but since
    // we don't have a name, we don't need it.
    const src = if (fn_info.body.len == 0) 0 else self_ast_node_index;

    self.ast_nodes.items[self_ast_node_index].fields = param_ast_indexes.items;
    self.types.items[type_slot_index] = .{
        .Fn = .{
            .name = "todo_name func",
            .src = src,
            .params = param_type_refs.items,
            .ret = ret_type,
            .generic_ret = generic_ret,
        },
    };

    return DocData.WalkResult{
        .typeRef = .{ .type = @enumToInt(Ref.type_type) },
        .expr = .{ .type = type_slot_index },
    };
}

fn getGenericReturnType(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo, // function decl line
    body_main_block: usize,
) !DocData.Expr {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    // We expect `body_main_block` to be the first instruction
    // inside the function body, and for it to be a block instruction.
    const pl_node = data[body_main_block].pl_node;
    const extra = file.zir.extraData(Zir.Inst.Block, pl_node.payload_index);
    const maybe_ret_node = file.zir.extra[extra.end..][extra.data.body_len - 4];
    switch (tags[maybe_ret_node]) {
        .ret_node, .ret_load => {
            const wr = try self.walkInstruction(file, scope, parent_src, maybe_ret_node, false);
            return wr.expr;
        },
        else => {
            return DocData.Expr{ .comptimeExpr = 0 };
        },
    }
}

fn collectUnionFieldInfo(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo,
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
            const walk_result = try self.walkRef(file, scope, parent_src, field_type, false);
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
    parent_src: SrcLocInfo,
    fields_len: usize,
    field_type_refs: *std.ArrayListUnmanaged(DocData.Expr),
    field_name_indexes: *std.ArrayListUnmanaged(usize),
    ei: usize,
    is_tuple: bool,
) !void {
    if (fields_len == 0) return;
    var extra_index = ei;

    const bits_per_field = 4;
    const fields_per_u32 = 32 / bits_per_field;
    const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;

    const Field = struct {
        field_name: ?u32,
        doc_comment_index: u32,
        type_body_len: u32 = 0,
        align_body_len: u32 = 0,
        init_body_len: u32 = 0,
        type_ref: Zir.Inst.Ref = .none,
    };
    const fields = try self.arena.alloc(Field, fields_len);

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
        const has_type_body = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;

        const field_name: ?u32 = if (!is_tuple) blk: {
            const fname = file.zir.extra[extra_index];
            extra_index += 1;
            break :blk fname;
        } else null;

        const doc_comment_index = file.zir.extra[extra_index];
        extra_index += 1;

        fields[field_i] = .{
            .field_name = field_name,
            .doc_comment_index = doc_comment_index,
        };

        if (has_type_body) {
            fields[field_i].type_body_len = file.zir.extra[extra_index];
        } else {
            fields[field_i].type_ref = @intToEnum(Zir.Inst.Ref, file.zir.extra[extra_index]);
        }
        extra_index += 1;

        if (has_align) {
            fields[field_i].align_body_len = file.zir.extra[extra_index];
            extra_index += 1;
        }
        if (has_default) {
            fields[field_i].init_body_len = file.zir.extra[extra_index];
            extra_index += 1;
        }
    }

    const data = file.zir.instructions.items(.data);

    for (fields) |field| {
        const type_expr = expr: {
            if (field.type_ref != .none) {
                const walk_result = try self.walkRef(file, scope, parent_src, field.type_ref, false);
                break :expr walk_result.expr;
            }

            std.debug.assert(field.type_body_len != 0);
            const body = file.zir.extra[extra_index..][0..field.type_body_len];
            extra_index += body.len;

            const break_inst = body[body.len - 1];
            const operand = data[break_inst].@"break".operand;
            try self.ast_nodes.append(self.arena, .{
                .file = self.files.getIndex(file).?,
                .line = parent_src.line,
                .col = 0,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            const walk_result = try self.walkRef(file, scope, parent_src, operand, false);
            break :expr walk_result.expr;
        };

        extra_index += field.align_body_len;
        extra_index += field.init_body_len;

        try field_type_refs.append(self.arena, type_expr);

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (field.doc_comment_index != 0)
                file.zir.nullTerminatedString(field.doc_comment_index)
            else
                null;
            const field_name: []const u8 = if (field.field_name) |f_name|
                file.zir.nullTerminatedString(f_name)
            else
                "";

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
    parent_src: SrcLocInfo,
    ref: Ref,
    need_type: bool, // true when the caller needs also a typeRef for the return value
) AutodocErrors!DocData.WalkResult {
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
                panicWithContext(
                    file,
                    0,
                    "TODO: handle {s} in walkRef",
                    .{@tagName(ref)},
                );
            },
            .undef => {
                return DocData.WalkResult{ .expr = .undefined };
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
                    .expr = .{ .void = .{} },
                };
            },
            .unreachable_value => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.noreturn_type) },
                    .expr = .{ .@"unreachable" = .{} },
                };
            },
            .null_value => {
                return DocData.WalkResult{ .expr = .null };
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
            .calling_convention_type => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.calling_convention_type) },
                    // .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },
            .calling_convention_c => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.calling_convention_c) },
                    // .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },
            .calling_convention_inline => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @enumToInt(Ref.calling_convention_inline) },
                    // .typeRef = .{ .type = @enumToInt(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },
            // .generic_poison => {
            //     return DocData.WalkResult{ .int = .{
            //         .type = @enumToInt(Ref.comptime_int_type),
            //         .value = 1,
            //     } };
            // },
        }
    } else {
        const zir_index = enum_value - Ref.typed_value_map.len;
        return self.walkInstruction(file, parent_scope, parent_src, zir_index, need_type);
    }
}

fn getBlockInlineBreak(zir: Zir, inst_index: usize) ?Zir.Inst.Ref {
    const tags = zir.instructions.items(.tag);
    const data = zir.instructions.items(.data);
    const pl_node = data[inst_index].pl_node;
    const extra = zir.extraData(Zir.Inst.Block, pl_node.payload_index);
    const break_index = zir.extra[extra.end..][extra.data.body_len - 1];
    if (tags[break_index] == .condbr_inline) return null;
    std.debug.assert(tags[break_index] == .break_inline);
    return data[break_index].@"break".operand;
}

fn printWithContext(file: *File, inst: usize, comptime fmt: []const u8, args: anytype) void {
    log.debug("Context [{s}] % {} \n " ++ fmt, .{ file.sub_file_path, inst } ++ args);
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

fn writeFileTableToJson(map: std.AutoArrayHashMapUnmanaged(*File, usize), jsw: anytype) !void {
    try jsw.beginArray();
    var it = map.iterator();
    while (it.next()) |entry| {
        try jsw.arrayElem();
        try jsw.emitString(entry.key_ptr.*.sub_file_path);
    }
    try jsw.endArray();
}

fn writeGuidesToJson(map: std.StringHashMapUnmanaged([]const u8), jsw: anytype) !void {
    try jsw.beginObject();
    var it = map.iterator();
    while (it.next()) |entry| {
        try jsw.objectField(entry.key_ptr.*);
        try jsw.emitString(entry.value_ptr.*);
    }
    try jsw.endObject();
}

fn writePackageTableToJson(
    map: std.AutoHashMapUnmanaged(*Package, DocData.DocPackage.TableEntry),
    jsw: anytype,
) !void {
    try jsw.beginObject();
    var it = map.valueIterator();
    while (it.next()) |entry| {
        try jsw.objectField(entry.name);
        try jsw.emitNumber(entry.value);
    }
    try jsw.endObject();
}

fn srcLocInfo(
    self: Autodoc,
    file: *File,
    src_node: i32,
    parent_src: SrcLocInfo,
) !SrcLocInfo {
    const sn = @intCast(u32, @intCast(i32, parent_src.src_node) + src_node);
    const tree = try file.getTree(self.module.gpa);
    const node_idx = @bitCast(Ast.Node.Index, sn);
    const tokens = tree.nodes.items(.main_token);

    const tok_idx = tokens[node_idx];
    const start = tree.tokens.items(.start)[tok_idx];
    const loc = tree.tokenLocation(parent_src.bytes, tok_idx);
    return SrcLocInfo{
        .line = parent_src.line + loc.line,
        .bytes = start,
        .src_node = sn,
    };
}

fn declIsVar(
    self: Autodoc,
    file: *File,
    src_node: i32,
    parent_src: SrcLocInfo,
) !bool {
    const sn = @intCast(u32, @intCast(i32, parent_src.src_node) + src_node);
    const tree = try file.getTree(self.module.gpa);
    const node_idx = @bitCast(Ast.Node.Index, sn);
    const tokens = tree.nodes.items(.main_token);
    const tags = tree.tokens.items(.tag);

    const tok_idx = tokens[node_idx];

    // tags[tok_idx] is the token called 'mut token' in AstGen
    return (tags[tok_idx] == .keyword_var);
}

fn getTLDocComment(self: *Autodoc, file: *File) ![]const u8 {
    const source = (try file.getSource(self.module.gpa)).bytes;
    var tokenizer = Tokenizer.init(source);
    var tok = tokenizer.next();
    var comment = std.ArrayList(u8).init(self.arena);
    while (tok.tag == .container_doc_comment) : (tok = tokenizer.next()) {
        try comment.appendSlice(source[tok.loc.start + "//!".len .. tok.loc.end + 1]);
    }

    return comment.items;
}

fn findGuidePaths(self: *Autodoc, file: *File, str: []const u8) !void {
    const prefix = "zig-autodoc-guide:";
    var it = std.mem.tokenize(u8, str, "\n");
    while (it.next()) |line| {
        const trimmed_line = std.mem.trim(u8, line, " ");
        if (std.mem.startsWith(u8, trimmed_line, prefix)) {
            const path = trimmed_line[prefix.len..];
            const trimmed_path = std.mem.trim(u8, path, " ");
            try self.addGuide(file, trimmed_path);
        }
    }
}

fn addGuide(self: *Autodoc, file: *File, guide_path: []const u8) !void {
    if (guide_path.len == 0) return error.MissingAutodocGuideName;

    const cur_pkg_dir_path = file.pkg.root_src_directory.path orelse ".";
    const resolved_path = try std.fs.path.resolve(self.arena, &[_][]const u8{
        cur_pkg_dir_path, file.sub_file_path, "..", guide_path,
    });

    var guide_file = try file.pkg.root_src_directory.handle.openFile(resolved_path, .{});
    defer guide_file.close();

    const guide = guide_file.reader().readAllAlloc(self.arena, 1 * 1024 * 1024) catch |err| switch (err) {
        error.StreamTooLong => @panic("stream too long"),
        else => |e| return e,
    };

    try self.guides.put(self.arena, resolved_path, guide);
}
