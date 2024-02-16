const builtin = @import("builtin");
const std = @import("std");
const build_options = @import("build_options");
const Ast = std.zig.Ast;
const Autodoc = @This();
const Compilation = @import("Compilation.zig");
const Zcu = @import("Module.zig");
const File = Zcu.File;
const Module = @import("Package.zig").Module;
const Tokenizer = std.zig.Tokenizer;
const InternPool = @import("InternPool.zig");
const Zir = @import("Zir.zig");
const Ref = Zir.Inst.Ref;
const log = std.log.scoped(.autodoc);
const renderer = @import("autodoc/render_source.zig");

zcu: *Zcu,
arena: std.mem.Allocator,

// The goal of autodoc is to fill up these arrays
// that will then be serialized as JSON and consumed
// by the JS frontend.
modules: std.AutoArrayHashMapUnmanaged(*Module, DocData.DocModule) = .{},
files: std.AutoArrayHashMapUnmanaged(*File, usize) = .{},
calls: std.ArrayListUnmanaged(DocData.Call) = .{},
types: std.ArrayListUnmanaged(DocData.Type) = .{},
decls: std.ArrayListUnmanaged(DocData.Decl) = .{},
exprs: std.ArrayListUnmanaged(DocData.Expr) = .{},
ast_nodes: std.ArrayListUnmanaged(DocData.AstNode) = .{},
comptime_exprs: std.ArrayListUnmanaged(DocData.ComptimeExpr) = .{},
guide_sections: std.ArrayListUnmanaged(Section) = .{},

// These fields hold temporary state of the analysis process
// and are mainly used by the decl path resolving algorithm.
pending_ref_paths: std.AutoHashMapUnmanaged(
    *DocData.Expr, // pointer to declpath tail end (ie `&decl_path[decl_path.len - 1]`)
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},
ref_paths_pending_on_decls: std.AutoHashMapUnmanaged(
    *Scope.DeclStatus,
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},
ref_paths_pending_on_types: std.AutoHashMapUnmanaged(
    usize,
    std.ArrayListUnmanaged(RefPathResumeInfo),
) = .{},

/// A set of ZIR instruction refs which have a meaning other than the
/// instruction they refer to. For instance, during analysis of the arguments to
/// a `call`, the index of the `call` itself is repurposed to refer to the
/// parameter type.
/// TODO: there should be some kind of proper handling for these instructions;
/// currently we just ignore them!
repurposed_insts: std.AutoHashMapUnmanaged(Zir.Inst.Index, void) = .{},

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

const Section = struct {
    name: []const u8 = "", // empty string is the default section
    guides: std.ArrayListUnmanaged(Guide) = .{},

    const Guide = struct {
        name: []const u8,
        body: []const u8,
    };
};

pub fn generate(zcu: *Zcu, output_dir: std.fs.Dir) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(zcu.gpa);
    defer arena_allocator.deinit();
    var autodoc: Autodoc = .{
        .zcu = zcu,
        .arena = arena_allocator.allocator(),
    };
    try autodoc.generateZirData(output_dir);

    const lib_dir = zcu.comp.zig_lib_directory.handle;
    try lib_dir.copyFile("docs/main.js", output_dir, "main.js", .{});
    try lib_dir.copyFile("docs/ziglexer.js", output_dir, "ziglexer.js", .{});
    try lib_dir.copyFile("docs/commonmark.js", output_dir, "commonmark.js", .{});
    try lib_dir.copyFile("docs/index.html", output_dir, "index.html", .{});
}

fn generateZirData(self: *Autodoc, output_dir: std.fs.Dir) !void {
    const root_src_path = self.zcu.main_mod.root_src_path;
    const joined_src_path = try self.zcu.main_mod.root.joinString(self.arena, root_src_path);
    defer self.arena.free(joined_src_path);

    const abs_root_src_path = try std.fs.path.resolve(self.arena, &.{ ".", joined_src_path });
    defer self.arena.free(abs_root_src_path);

    const file = self.zcu.import_table.get(abs_root_src_path).?; // file is expected to be present in the import table
    // Append all the types in Zir.Inst.Ref.
    {
        comptime std.debug.assert(@intFromEnum(InternPool.Index.first_type) == 0);
        var i: u32 = 0;
        while (i <= @intFromEnum(InternPool.Index.last_type)) : (i += 1) {
            const ip_index = @as(InternPool.Index, @enumFromInt(i));
            var tmpbuf = std.ArrayList(u8).init(self.arena);
            if (ip_index == .generic_poison_type) {
                // Not a real type, doesn't have a normal name
                try tmpbuf.writer().writeAll("(generic poison)");
            } else {
                try @import("type.zig").Type.fromInterned(ip_index).fmt(self.zcu).format("", .{}, tmpbuf.writer());
            }
            try self.types.append(
                self.arena,
                switch (ip_index) {
                    .u0_type,
                    .i0_type,
                    .u1_type,
                    .u8_type,
                    .i8_type,
                    .u16_type,
                    .i16_type,
                    .u29_type,
                    .u32_type,
                    .i32_type,
                    .u64_type,
                    .i64_type,
                    .u80_type,
                    .u128_type,
                    .i128_type,
                    .usize_type,
                    .isize_type,
                    .c_char_type,
                    .c_short_type,
                    .c_ushort_type,
                    .c_int_type,
                    .c_uint_type,
                    .c_long_type,
                    .c_ulong_type,
                    .c_longlong_type,
                    .c_ulonglong_type,
                    => .{
                        .Int = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f80_type,
                    .f128_type,
                    .c_longdouble_type,
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
                    // should be different types but if we don't analyze std we don't get the ast nodes etc.
                    // since they're defined in std.builtin
                    .calling_convention_type,
                    .atomic_order_type,
                    .atomic_rmw_op_type,
                    .address_space_type,
                    .float_mode_type,
                    .reduce_op_type,
                    .call_modifier_type,
                    .prefetch_options_type,
                    .export_options_type,
                    .extern_options_type,
                    => .{
                        .Type = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .manyptr_u8_type => .{
                        .Pointer = .{
                            .size = .Many,
                            .child = .{ .type = @intFromEnum(InternPool.Index.u8_type) },
                            .is_mutable = true,
                        },
                    },
                    .manyptr_const_u8_type => .{
                        .Pointer = .{
                            .size = .Many,
                            .child = .{ .type = @intFromEnum(InternPool.Index.u8_type) },
                        },
                    },
                    .manyptr_const_u8_sentinel_0_type => .{
                        .Pointer = .{
                            .size = .Many,
                            .child = .{ .type = @intFromEnum(InternPool.Index.u8_type) },
                            .sentinel = .{ .int = .{ .value = 0 } },
                        },
                    },
                    .single_const_pointer_to_comptime_int_type => .{
                        .Pointer = .{
                            .size = .One,
                            .child = .{ .type = @intFromEnum(InternPool.Index.comptime_int_type) },
                        },
                    },
                    .slice_const_u8_type => .{
                        .Pointer = .{
                            .size = .Slice,
                            .child = .{ .type = @intFromEnum(InternPool.Index.u8_type) },
                        },
                    },
                    .slice_const_u8_sentinel_0_type => .{
                        .Pointer = .{
                            .size = .Slice,
                            .child = .{ .type = @intFromEnum(InternPool.Index.u8_type) },
                            .sentinel = .{ .int = .{ .value = 0 } },
                        },
                    },
                    // Not fully correct
                    // since it actually has no src or line_number
                    .empty_struct_type => .{
                        .Struct = .{
                            .name = "",
                            .src = 0,
                            .is_tuple = false,
                            .line_number = 0,
                            .parent_container = null,
                            .layout = null,
                        },
                    },
                    .anyerror_void_error_union_type => .{
                        .ErrorUnion = .{
                            .lhs = .{ .type = @intFromEnum(InternPool.Index.anyerror_type) },
                            .rhs = .{ .type = @intFromEnum(InternPool.Index.void_type) },
                        },
                    },
                    .anyframe_type => .{
                        .AnyFrame = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .enum_literal_type => .{
                        .EnumLiteral = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .undefined_type => .{
                        .Undefined = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .null_type => .{
                        .Null = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    .optional_noreturn_type => .{
                        .Optional = .{
                            .name = try tmpbuf.toOwnedSlice(),
                            .child = .{ .type = @intFromEnum(InternPool.Index.noreturn_type) },
                        },
                    },
                    // Poison and special tag
                    .generic_poison_type,
                    .var_args_param_type,
                    .adhoc_inferred_error_set_type,
                    => .{
                        .Type = .{ .name = try tmpbuf.toOwnedSlice() },
                    },
                    // We want to catch new types added to InternPool.Index
                    else => unreachable,
                },
            );
        }
    }

    const rootName = blk: {
        const rootName = std.fs.path.basename(self.zcu.main_mod.root_src_path);
        break :blk rootName[0 .. rootName.len - 4];
    };

    const main_type_index = self.types.items.len;
    {
        try self.modules.put(self.arena, self.zcu.main_mod, .{
            .name = rootName,
            .main = main_type_index,
            .table = .{},
        });
        try self.modules.entries.items(.value)[0].table.put(
            self.arena,
            self.zcu.main_mod,
            .{
                .name = rootName,
                .value = 0,
            },
        );
    }

    var root_scope = Scope{
        .parent = null,
        .enclosing_type = null,
    };

    const tldoc_comment = try self.getTLDocComment(file);
    const cleaned_tldoc_comment = try self.findGuidePaths(file, tldoc_comment);
    defer self.arena.free(cleaned_tldoc_comment);
    try self.ast_nodes.append(self.arena, .{
        .name = "(root)",
        .docs = cleaned_tldoc_comment,
    });
    try self.files.put(self.arena, file, main_type_index);

    _ = try self.walkInstruction(
        file,
        &root_scope,
        .{},
        .main_struct_inst,
        false,
        null,
    );

    if (self.ref_paths_pending_on_decls.count() > 0) {
        @panic("some decl paths were never fully analyzed (pending on decls)");
    }

    if (self.ref_paths_pending_on_types.count() > 0) {
        @panic("some decl paths were never fully analyzed (pending on types)");
    }

    if (self.pending_ref_paths.count() > 0) {
        @panic("some decl paths were never fully analyzed");
    }

    var data = DocData{
        .modules = self.modules,
        .files = self.files,
        .calls = self.calls.items,
        .types = self.types.items,
        .decls = self.decls.items,
        .exprs = self.exprs.items,
        .astNodes = self.ast_nodes.items,
        .comptimeExprs = self.comptime_exprs.items,
        .guideSections = self.guide_sections,
    };

    inline for (comptime std.meta.tags(std.meta.FieldEnum(DocData))) |f| {
        const field_name = @tagName(f);
        const file_name = "data-" ++ field_name ++ ".js";
        const data_js_f = try output_dir.createFile(file_name, .{});
        defer data_js_f.close();

        var buffer = std.io.bufferedWriter(data_js_f.writer());
        const out = buffer.writer();

        try out.print("var {s} =", .{field_name});

        var jsw = std.json.writeStream(out, .{
            .whitespace = .minified,
            .emit_null_optional_fields = true,
        });

        switch (f) {
            .files => try writeFileTableToJson(data.files, data.modules, &jsw),
            .guideSections => try writeGuidesToJson(data.guideSections, &jsw),
            .modules => try jsw.write(data.modules.values()),
            else => try jsw.write(@field(data, field_name)),
        }

        // try std.json.stringifyArbitraryDepth(
        //     self.arena,
        //     @field(data, field.name),
        //     .{
        //         .whitespace = .minified,
        //         .emit_null_optional_fields = true,
        //     },
        //     out,
        // );
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
            const sub_file_path = entry.key_ptr.*.sub_file_path;
            const file_module = entry.key_ptr.*.mod;
            const module_name = (self.modules.get(file_module) orelse continue).name;

            const file_path = std.fs.path.dirname(sub_file_path) orelse "";
            const file_name = if (file_path.len > 0) sub_file_path[file_path.len + 1 ..] else sub_file_path;

            const html_file_name = try std.mem.concat(self.arena, u8, &.{ file_name, ".html" });
            defer self.arena.free(html_file_name);

            const dir_name = try std.fs.path.join(self.arena, &.{ module_name, file_path });
            defer self.arena.free(dir_name);

            var dir = try html_dir.makeOpenPath(dir_name, .{});
            defer dir.close();

            const html_file = dir.createFile(html_file_name, .{}) catch |err| switch (err) {
                error.PathAlreadyExists => try dir.openFile(html_file_name, .{}),
                else => return err,
            };
            defer html_file.close();
            var buffer = std.io.bufferedWriter(html_file.writer());

            const out = buffer.writer();

            try renderer.genHtml(self.zcu.gpa, entry.key_ptr.*, out);
            try buffer.flush();
        }
    }
}

/// Represents a chain of scopes, used to resolve decl references to the
/// corresponding entry in `self.decls`. It also keeps track of whether
/// a given decl has been analyzed or not.
const Scope = struct {
    parent: ?*Scope,
    map: std.AutoHashMapUnmanaged(
        Zir.NullTerminatedString, // index into the current file's string table (decl name)
        *DeclStatus,
    ) = .{},

    enclosing_type: ?usize, // index into `types`, null = file top-level struct

    pub const DeclStatus = union(enum) {
        Analyzed: usize, // index into `decls`
        Pending,
        NotRequested: u32, // instr_index
    };

    /// Returns a pointer so that the caller has a chance to modify the value
    /// in case they decide to start analyzing a previously not requested decl.
    /// Another reason is that in some places we use the pointer to uniquely
    /// refer to a decl, as we wait for it to be analyzed. This means that
    /// those pointers must stay stable.
    pub fn resolveDeclName(self: Scope, string_table_idx: Zir.NullTerminatedString, file: *File, inst: Zir.Inst.OptionalIndex) *DeclStatus {
        var cur: ?*const Scope = &self;
        return while (cur) |s| : (cur = s.parent) {
            break s.map.get(string_table_idx) orelse continue;
        } else {
            printWithOptionalContext(
                file,
                inst,
                "Could not find `{s}`\n\n",
                .{file.zir.nullTerminatedString(string_table_idx)},
            );
            unreachable;
        };
    }

    pub fn insertDeclRef(
        self: *Scope,
        arena: std.mem.Allocator,
        decl_name_index: Zir.NullTerminatedString, // index into the current file's string table
        decl_status: DeclStatus,
    ) !void {
        const decl_status_ptr = try arena.create(DeclStatus);
        errdefer arena.destroy(decl_status_ptr);

        decl_status_ptr.* = decl_status;
        try self.map.put(arena, decl_name_index, decl_status_ptr);
    }
};

/// The output of our analysis process.
const DocData = struct {
    // NOTE: editing fields of DocData requires also updating:
    //       - the deployment script for ziglang.org
    //       - imports in index.html
    typeKinds: []const []const u8 = std.meta.fieldNames(DocTypeKinds),
    rootMod: u32 = 0,
    modules: std.AutoArrayHashMapUnmanaged(*Module, DocModule),

    // non-hardcoded stuff
    astNodes: []AstNode,
    calls: []Call,
    files: std.AutoArrayHashMapUnmanaged(*File, usize),
    types: []Type,
    decls: []Decl,
    exprs: []Expr,
    comptimeExprs: []ComptimeExpr,

    guideSections: std.ArrayListUnmanaged(Section),

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
    const DocTypeKinds = @typeInfo(Type).Union.tag_type.?;

    const ComptimeExpr = struct {
        code: []const u8,
    };
    const DocModule = struct {
        name: []const u8 = "(root)",
        file: usize = 0, // index into `files`
        main: usize = 0, // index into `types`
        table: std.AutoHashMapUnmanaged(*Module, TableEntry),
        pub const TableEntry = struct {
            name: []const u8,
            value: usize,
        };

        pub fn jsonStringify(self: DocModule, jsw: anytype) !void {
            try jsw.beginObject();
            inline for (comptime std.meta.tags(std.meta.FieldEnum(DocModule))) |f| {
                const f_name = @tagName(f);
                try jsw.objectField(f_name);
                switch (f) {
                    .table => try writeModuleTableToJson(self.table, jsw),
                    else => try jsw.write(@field(self, f_name)),
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
        is_uns: bool = false, // usingnamespace
        parent_container: ?usize, // index into `types`

        pub fn jsonStringify(self: Decl, jsw: anytype) !void {
            try jsw.beginArray();
            inline for (comptime std.meta.fields(Decl)) |f| {
                try jsw.write(@field(self, f.name));
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

        pub fn jsonStringify(self: AstNode, jsw: anytype) !void {
            try jsw.beginArray();
            inline for (comptime std.meta.fields(AstNode)) |f| {
                try jsw.write(@field(self, f.name));
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
            field_types: []Expr = &.{}, // (use src->fields to find names)
            field_defaults: []?Expr = &.{}, // default values is specified
            backing_int: ?Expr = null, // backing integer if specified
            is_tuple: bool,
            line_number: usize,
            parent_container: ?usize, // index into `types`
            layout: ?Expr, // if different than Auto
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
            values: []?Expr = &.{}, // tag values if specified
            nonexhaustive: bool,
            parent_container: ?usize, // index into `types`
        },
        Union: struct {
            name: []const u8,
            src: usize, // index into astNodes
            privDecls: []usize = &.{}, // index into decls
            pubDecls: []usize = &.{}, // index into decls
            fields: []Expr = &.{}, // (use src->fields to find names)
            tag: ?Expr, // tag type if specified
            auto_enum: bool, // tag is an auto enum
            parent_container: ?usize, // index into `types`
            layout: ?Expr, // if different than Auto
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
            parent_container: ?usize, // index into `types`
        },
        Frame: struct { name: []const u8 },
        AnyFrame: struct { name: []const u8 },
        Vector: struct { name: []const u8 },
        EnumLiteral: struct { name: []const u8 },

        const Field = struct {
            name: []const u8,
            docs: []const u8,
        };

        pub fn jsonStringify(self: Type, jsw: anytype) !void {
            const active_tag = std.meta.activeTag(self);
            try jsw.beginArray();
            try jsw.write(@intFromEnum(active_tag));
            inline for (comptime std.meta.fields(Type)) |case| {
                if (@field(Type, case.name) == active_tag) {
                    const current_value = @field(self, case.name);
                    inline for (comptime std.meta.fields(case.type)) |f| {
                        if (f.type == std.builtin.Type.Pointer.Size) {
                            try jsw.write(@intFromEnum(@field(current_value, f.name)));
                        } else {
                            try jsw.write(@field(current_value, f.name));
                        }
                    }
                }
            }
            try jsw.endArray();
        }
    };

    /// An Expr represents the (untyped) result of analyzing instructions.
    /// The data is normalized, which means that an Expr that results in a
    /// type definition will hold an index into `self.types`.
    pub const Expr = union(enum) {
        comptimeExpr: usize, // index in `comptimeExprs`
        void: struct {},
        @"unreachable": struct {},
        null: struct {},
        undefined: struct {},
        @"struct": []FieldVal,
        fieldVal: FieldVal,
        bool: bool,
        @"anytype": struct {},
        @"&": usize, // index in `exprs`
        type: usize, // index in `types`
        this: usize, // index in `types`
        declRef: *Scope.DeclStatus,
        declIndex: usize, // index into `decls`, alternative repr for `declRef`
        declName: []const u8, // unresolved decl name
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
        typeOf: usize, // index in `exprs`
        typeOf_peer: []usize,
        errorUnion: usize, // index in `types`
        as: As,
        sizeOf: usize, // index in `exprs`
        bitSizeOf: usize, // index in `exprs`
        compileError: usize, // index in `exprs`
        optionalPayload: usize, // index in `exprs`
        elemVal: ElemVal,
        errorSets: usize,
        string: []const u8, // direct value
        sliceIndex: usize,
        slice: Slice,
        sliceLength: SliceLength,
        cmpxchgIndex: usize,
        cmpxchg: Cmpxchg,
        builtin: Builtin,
        builtinIndex: usize,
        builtinBin: BuiltinBin,
        builtinBinIndex: usize,
        unionInit: UnionInit,
        builtinCall: BuiltinCall,
        mulAdd: MulAdd,
        switchIndex: usize, // index in `exprs`
        switchOp: SwitchOp,
        unOp: UnOp,
        unOpIndex: usize,
        binOp: BinOp,
        binOpIndex: usize,
        load: usize, // index in `exprs`
        const UnOp = struct {
            param: usize, // index in `exprs`
            name: []const u8 = "", // tag name
        };
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
        const UnionInit = struct {
            type: usize, // index in `exprs`
            field: usize, // index in `exprs`
            init: usize, // index in `exprs`
        };
        const Builtin = struct {
            name: []const u8 = "", // fn name
            param: usize, // index in `exprs`
        };
        const BuiltinCall = struct {
            modifier: usize, // index in `exprs`
            function: usize, // index in `exprs`
            args: usize, // index in `exprs`
        };
        const MulAdd = struct {
            mulend1: usize, // index in `exprs`
            mulend2: usize, // index in `exprs`
            addend: usize, // index in `exprs`
            type: usize, // index in `exprs`
        };
        const Slice = struct {
            lhs: usize, // index in `exprs`
            start: usize,
            end: ?usize = null,
            sentinel: ?usize = null, // index in `exprs`
        };
        const SliceLength = struct {
            lhs: usize,
            start: usize,
            len: usize,
            sentinel: ?usize = null,
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
            val: struct {
                typeRef: ?usize, // index in `exprs`
                expr: usize, // index in `exprs`
            },
        };

        const ElemVal = struct {
            lhs: usize, // index in `exprs`
            rhs: usize, // index in `exprs`
        };

        pub fn jsonStringify(self: Expr, jsw: anytype) !void {
            const active_tag = std.meta.activeTag(self);
            try jsw.beginObject();
            if (active_tag == .declIndex) {
                try jsw.objectField("declRef");
            } else {
                try jsw.objectField(@tagName(active_tag));
            }
            switch (self) {
                .int => {
                    if (self.int.negated) {
                        try jsw.write(-@as(i65, self.int.value));
                    } else {
                        try jsw.write(self.int.value);
                    }
                },
                .builtinField => {
                    try jsw.write(@tagName(self.builtinField));
                },
                .declRef => {
                    try jsw.write(self.declRef.Analyzed);
                },
                else => {
                    inline for (comptime std.meta.fields(Expr)) |case| {
                        // TODO: this is super ugly, fix once `inline else` is a thing
                        if (comptime std.mem.eql(u8, case.name, "builtinField"))
                            continue;
                        if (comptime std.mem.eql(u8, case.name, "declRef"))
                            continue;
                        if (@field(Expr, case.name) == active_tag) {
                            try jsw.write(@field(self, case.name));
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
        typeRef: ?Expr = null,
        expr: Expr,
    };
};

const AutodocErrors = error{
    OutOfMemory,
    CurrentWorkingDirectoryUnlinked,
    UnexpectedEndOfFile,
    ModuleNotFound,
    ImportOutsideModulePath,
} || std.fs.File.OpenError || std.fs.File.ReadError;

/// `call` instructions will have loopy references to themselves
///  whenever an as_node is required for a complex expression.
///  This type is used to keep track of dangerous instruction
///  numbers that we definitely don't want to recurse into.
const CallContext = struct {
    inst: Zir.Inst.Index,
    prev: ?*const CallContext,
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
    parent_src: SrcLocInfo,
    inst: Zir.Inst.Index,
    need_type: bool, // true if the caller needs us to provide also a typeRef
    call_ctx: ?*const CallContext,
) AutodocErrors!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    if (self.repurposed_insts.contains(inst)) {
        // TODO: better handling here
        return .{ .expr = .{ .comptimeExpr = 0 } };
    }

    // We assume that the topmost ast_node entry corresponds to our decl
    const self_ast_node_index = self.ast_nodes.items.len - 1;

    switch (tags[@intFromEnum(inst)]) {
        else => {
            printWithContext(
                file,
                inst,
                "TODO: implement `{s}` for walkInstruction\n\n",
                .{@tagName(tags[@intFromEnum(inst)])},
            );
            return self.cteTodo(@tagName(tags[@intFromEnum(inst)]));
        },
        .import => {
            const str_tok = data[@intFromEnum(inst)].str_tok;
            const path = str_tok.get(file.zir);

            // importFile cannot error out since all files
            // are already loaded at this point
            if (file.mod.deps.get(path)) |other_module| {
                const result = try self.modules.getOrPut(self.arena, other_module);

                // Immediately add this module to the import table of our
                // current module, regardless of wether it's new or not.
                if (self.modules.getPtr(file.mod)) |current_module| {
                    // TODO: apparently, in the stdlib a file gets analyzed before
                    //       its module gets added. I guess we're importing a file
                    //       that belongs to another module through its file path?
                    //       (ie not through its module name).
                    //       We're bailing for now, but maybe we shouldn't?
                    _ = try current_module.table.getOrPutValue(
                        self.arena,
                        other_module,
                        .{
                            .name = path,
                            .value = self.modules.getIndex(other_module).?,
                        },
                    );
                }

                if (result.found_existing) {
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                        .expr = .{ .type = result.value_ptr.main },
                    };
                }

                // create a new module entry
                const main_type_index = self.types.items.len;
                result.value_ptr.* = .{
                    .name = path,
                    .main = main_type_index,
                    .table = .{},
                };

                // TODO: Add this module as a dependency to the current module
                // TODO: this seems something that could be done in bulk
                //       at the beginning or the end, or something.
                const abs_root_src_path = try std.fs.path.resolve(self.arena, &.{
                    ".",
                    other_module.root.root_dir.path orelse ".",
                    other_module.root.sub_path,
                    other_module.root_src_path,
                });
                defer self.arena.free(abs_root_src_path);

                const new_file = self.zcu.import_table.get(abs_root_src_path).?;

                var root_scope = Scope{
                    .parent = null,
                    .enclosing_type = null,
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
                    .main_struct_inst,
                    false,
                    call_ctx,
                );
            }

            const new_file = try self.zcu.importFile(file, path);
            const result = try self.files.getOrPut(self.arena, new_file.file);
            if (result.found_existing) {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                    .expr = .{ .type = result.value_ptr.* },
                };
            }

            const maybe_tldoc_comment = try self.getTLDocComment(new_file.file);
            try self.ast_nodes.append(self.arena, .{
                .name = path,
                .docs = maybe_tldoc_comment,
            });

            result.value_ptr.* = self.types.items.len;

            var new_scope = Scope{
                .parent = null,
                .enclosing_type = null,
            };

            return self.walkInstruction(
                new_file.file,
                &new_scope,
                .{},
                .main_struct_inst,
                need_type,
                call_ctx,
            );
        },
        .ret_type => {
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = @intFromEnum(Ref.type_type) },
            };
        },
        .ret_node => {
            const un_node = data[@intFromEnum(inst)].un_node;
            return self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );
        },
        .ret_load => {
            const un_node = data[@intFromEnum(inst)].un_node;
            const res_ptr_ref = un_node.operand;
            const res_ptr_inst = @intFromEnum(res_ptr_ref.toIndex().?);
            // TODO: this instruction doesn't let us know trivially if there's
            //       branching involved or not. For now here's the strat:
            //       We search backwarts until `ret_ptr` for `store_node`,
            //       if we find only one, then that's our value, if we find more
            //       than one, then it means that there's branching involved.
            //       Maybe.

            var i = @intFromEnum(inst) - 1;
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
                return self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    rr,
                    need_type,
                    call_ctx,
                );
            }

            return DocData.WalkResult{
                .expr = .{ .comptimeExpr = 0 },
            };
        },
        .closure_get => {
            const inst_node = data[@intFromEnum(inst)].inst_node;

            const code = try self.getBlockSource(file, parent_src, inst_node.src_node);
            const idx = self.comptime_exprs.items.len;
            try self.exprs.append(self.arena, .{ .comptimeExpr = idx });
            try self.comptime_exprs.append(self.arena, .{ .code = code });

            return DocData.WalkResult{
                .expr = .{ .comptimeExpr = idx },
            };
        },
        .closure_capture => {
            const un_tok = data[@intFromEnum(inst)].un_tok;
            return try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_tok.operand,
                need_type,
                call_ctx,
            );
        },
        .str => {
            const str = data[@intFromEnum(inst)].str.get(file.zir);

            const tRef: ?DocData.Expr = if (!need_type) null else blk: {
                const arrTypeId = self.types.items.len;
                try self.types.append(self.arena, .{
                    .Array = .{
                        .len = .{ .int = .{ .value = str.len } },
                        .child = .{ .type = @intFromEnum(Ref.u8_type) },
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
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .expr = .{ .compileError = operand_index },
            };
        },
        .enum_literal => {
            const str_tok = data[@intFromEnum(inst)].str_tok;
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
            const int = data[@intFromEnum(inst)].int;
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                .expr = .{ .int = .{ .value = int } },
            };
        },
        .int_big => {
            // @check
            const str = data[@intFromEnum(inst)].str; //.get(file.zir);
            const byte_count = str.len * @sizeOf(std.math.big.Limb);
            const limb_bytes = file.zir.string_bytes[@intFromEnum(str.start)..][0..byte_count];

            const limbs = try self.arena.alloc(std.math.big.Limb, str.len);
            @memcpy(std.mem.sliceAsBytes(limbs)[0..limb_bytes.len], limb_bytes);

            const big_int = std.math.big.int.Const{
                .limbs = limbs,
                .positive = true,
            };

            const as_string = try big_int.toStringAlloc(self.arena, 10, .lower);

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                .expr = .{ .int_big = .{ .value = as_string } },
            };
        },
        .@"unreachable" => {
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.noreturn_type) },
                .expr = .{ .@"unreachable" = .{} },
            };
        },

        .slice_start => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceStart, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            self.exprs.items[slice_index] = .{ .slice = .{ .lhs = lhs_index, .start = start_index } };

            const typeRef = switch (lhs.expr) {
                .declRef => |ref| self.decls.items[ref.Analyzed].value.typeRef,
                else => null,
            };

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },
        .slice_end => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceEnd, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
                call_ctx,
            );
            const end: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.end,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            const end_index = self.exprs.items.len;
            try self.exprs.append(self.arena, end.expr);
            self.exprs.items[slice_index] = .{ .slice = .{ .lhs = lhs_index, .start = start_index, .end = end_index } };

            const typeRef = switch (lhs.expr) {
                .declRef => |ref| self.decls.items[ref.Analyzed].value.typeRef,
                else => null,
            };

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },
        .slice_sentinel => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceSentinel, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
                call_ctx,
            );
            const end: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.end,
                false,
                call_ctx,
            );
            const sentinel: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.sentinel,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            const end_index = self.exprs.items.len;
            try self.exprs.append(self.arena, end.expr);
            const sentinel_index = self.exprs.items.len;
            try self.exprs.append(self.arena, sentinel.expr);
            self.exprs.items[slice_index] = .{ .slice = .{
                .lhs = lhs_index,
                .start = start_index,
                .end = end_index,
                .sentinel = sentinel_index,
            } };

            const typeRef = switch (lhs.expr) {
                .declRef => |ref| self.decls.items[ref.Analyzed].value.typeRef,
                else => null,
            };

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },
        .slice_length => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SliceLength, pl_node.payload_index);

            const slice_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .slice = .{ .lhs = 0, .start = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const start: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.start,
                false,
                call_ctx,
            );
            const len: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.len,
                false,
                call_ctx,
            );
            const sentinel_opt: ?DocData.WalkResult = if (extra.data.sentinel != .none)
                try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    extra.data.sentinel,
                    false,
                    call_ctx,
                )
            else
                null;

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const start_index = self.exprs.items.len;
            try self.exprs.append(self.arena, start.expr);
            const len_index = self.exprs.items.len;
            try self.exprs.append(self.arena, len.expr);
            const sentinel_index = if (sentinel_opt) |sentinel| sentinel_index: {
                const index = self.exprs.items.len;
                try self.exprs.append(self.arena, sentinel.expr);
                break :sentinel_index index;
            } else null;
            self.exprs.items[slice_index] = .{ .sliceLength = .{
                .lhs = lhs_index,
                .start = start_index,
                .len = len_index,
                .sentinel = sentinel_index,
            } };

            const typeRef = switch (lhs.expr) {
                .declRef => |ref| self.decls.items[ref.Analyzed].value.typeRef,
                else => null,
            };

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .sliceIndex = slice_index },
            };
        },

        .load => {
            const un_node = data[@intFromEnum(inst)].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
                call_ctx,
            );
            const load_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            var typeRef: ?DocData.Expr = null;
            if (operand.typeRef) |ref| {
                switch (ref) {
                    .type => |t_index| {
                        switch (self.types.items[t_index]) {
                            .Pointer => |p| typeRef = p.child,
                            else => {},
                        }
                    },
                    else => {},
                }
            }

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .load = load_idx },
            };
        },
        .ref => {
            const un_tok = data[@intFromEnum(inst)].un_tok;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_tok.operand,
                need_type,
                call_ctx,
            );
            const ref_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .expr = .{ .@"&" = ref_idx },
            };
        },

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
        .xor,
        .array_cat,
        => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .binOp = .{
                .name = @tagName(tags[@intFromEnum(inst)]),
                .lhs = lhs_index,
                .rhs = rhs_index,
            } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .binOpIndex = binop_index },
            };
        },
        .array_mul => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.ArrayMul, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );
            const res_ty: ?DocData.WalkResult = if (extra.data.res_ty != .none)
                try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    extra.data.res_ty,
                    false,
                    call_ctx,
                )
            else
                null;

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .binOp = .{
                .name = @tagName(tags[@intFromEnum(inst)]),
                .lhs = lhs_index,
                .rhs = rhs_index,
            } };

            return DocData.WalkResult{
                .typeRef = if (res_ty) |rt| rt.expr else null,
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
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .binOp = .{
                .name = @tagName(tags[@intFromEnum(inst)]),
                .lhs = lhs_index,
                .rhs = rhs_index,
            } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.bool_type) },
                .expr = .{ .binOpIndex = binop_index },
            };
        },

        // builtin functions
        .align_of,
        .int_from_bool,
        .embed_file,
        .error_name,
        .panic,
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
        .abs,
        .floor,
        .ceil,
        .trunc,
        .round,
        .tag_name,
        .type_name,
        .frame_type,
        .frame_size,
        .int_from_ptr,
        .type_info,
        // @check
        .clz,
        .ctz,
        .pop_count,
        .byte_swap,
        .bit_reverse,
        => {
            const un_node = data[@intFromEnum(inst)].un_node;
            const bin_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
            const param = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            const param_index = self.exprs.items.len;
            try self.exprs.append(self.arena, param.expr);

            self.exprs.items[bin_index] = .{
                .builtin = .{
                    .name = @tagName(tags[@intFromEnum(inst)]),
                    .param = param_index,
                },
            };

            return DocData.WalkResult{
                .typeRef = param.typeRef orelse .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .builtinIndex = bin_index },
            };
        },
        .bit_not,
        .bool_not,
        .negate_wrap,
        => {
            const un_node = data[@intFromEnum(inst)].un_node;
            const un_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .unOp = .{ .param = 0 } });
            const param = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            const param_index = self.exprs.items.len;
            try self.exprs.append(self.arena, param.expr);

            self.exprs.items[un_index] = .{
                .unOp = .{
                    .name = @tagName(tags[@intFromEnum(inst)]),
                    .param = param_index,
                },
            };

            return DocData.WalkResult{
                .typeRef = param.typeRef,
                .expr = .{ .unOpIndex = un_index },
            };
        },
        .bool_br_and, .bool_br_or => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.BoolBr, pl_node.payload_index);

            const bin_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .binOp = .{ .lhs = 0, .rhs = 0 } });

            const lhs = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);

            const rhs = try self.walkInstruction(
                file,
                parent_scope,
                parent_src,
                @enumFromInt(file.zir.extra[extra.end..][extra.data.body_len - 1]),
                false,
                call_ctx,
            );
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);

            self.exprs.items[bin_index] = .{ .binOp = .{ .name = @tagName(tags[@intFromEnum(inst)]), .lhs = lhs_index, .rhs = rhs_index } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.bool_type) },
                .expr = .{ .binOpIndex = bin_index },
            };
        },
        .truncate => {
            // in the ZIR this node is a builtin `bin` but we want send it as a `un` builtin
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );

            const bin_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });

            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );

            self.exprs.items[bin_index] = .{ .builtin = .{ .name = @tagName(tags[@intFromEnum(inst)]), .param = rhs_index } };

            return DocData.WalkResult{
                .typeRef = lhs.expr,
                .expr = .{ .builtinIndex = bin_index },
            };
        },
        .int_from_float,
        .float_from_int,
        .ptr_from_int,
        .enum_from_int,
        .float_cast,
        .int_cast,
        .ptr_cast,
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
        .min,
        .max,
        => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const binop_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtinBin = .{ .lhs = 0, .rhs = 0 } });

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );

            const lhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_index = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            self.exprs.items[binop_index] = .{ .builtinBin = .{ .name = @tagName(tags[@intFromEnum(inst)]), .lhs = lhs_index, .rhs = rhs_index } };

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .builtinBinIndex = binop_index },
            };
        },
        .mul_add => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MulAdd, pl_node.payload_index);

            const mul1: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.mulend1,
                false,
                call_ctx,
            );
            const mul2: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.mulend2,
                false,
                call_ctx,
            );
            const add: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.addend,
                false,
                call_ctx,
            );

            const mul1_index = self.exprs.items.len;
            try self.exprs.append(self.arena, mul1.expr);
            const mul2_index = self.exprs.items.len;
            try self.exprs.append(self.arena, mul2.expr);
            const add_index = self.exprs.items.len;
            try self.exprs.append(self.arena, add.expr);

            const type_index: usize = self.exprs.items.len;
            try self.exprs.append(self.arena, add.typeRef orelse .{ .type = @intFromEnum(Ref.type_type) });

            return DocData.WalkResult{
                .typeRef = add.typeRef,
                .expr = .{
                    .mulAdd = .{
                        .mulend1 = mul1_index,
                        .mulend2 = mul2_index,
                        .addend = add_index,
                        .type = type_index,
                    },
                },
            };
        },
        .union_init => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.UnionInit, pl_node.payload_index);

            const union_type: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.union_type,
                false,
                call_ctx,
            );
            const field_name: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.field_name,
                false,
                call_ctx,
            );
            const init: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.init,
                false,
                call_ctx,
            );

            const union_type_index = self.exprs.items.len;
            try self.exprs.append(self.arena, union_type.expr);
            const field_name_index = self.exprs.items.len;
            try self.exprs.append(self.arena, field_name.expr);
            const init_index = self.exprs.items.len;
            try self.exprs.append(self.arena, init.expr);

            return DocData.WalkResult{
                .typeRef = union_type.expr,
                .expr = .{
                    .unionInit = .{
                        .type = union_type_index,
                        .field = field_name_index,
                        .init = init_index,
                    },
                },
            };
        },
        .builtin_call => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.BuiltinCall, pl_node.payload_index);

            const modifier: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.modifier,
                false,
                call_ctx,
            );

            const callee: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.callee,
                false,
                call_ctx,
            );

            const args: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.args,
                false,
                call_ctx,
            );

            const modifier_index = self.exprs.items.len;
            try self.exprs.append(self.arena, modifier.expr);
            const function_index = self.exprs.items.len;
            try self.exprs.append(self.arena, callee.expr);
            const args_index = self.exprs.items.len;
            try self.exprs.append(self.arena, args.expr);

            return DocData.WalkResult{
                .expr = .{
                    .builtinCall = .{
                        .modifier = modifier_index,
                        .function = function_index,
                        .args = args_index,
                    },
                },
            };
        },
        .error_union_type => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .ErrorUnion = .{
                .lhs = lhs.expr,
                .rhs = rhs.expr,
            } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .errorUnion = type_slot_index },
            };
        },
        .merge_error_sets => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);

            const lhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                false,
                call_ctx,
            );
            const rhs: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                false,
                call_ctx,
            );
            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{ .ErrorUnion = .{
                .lhs = lhs.expr,
                .rhs = rhs.expr,
            } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .errorSets = type_slot_index },
            };
        },
        // .elem_type => {
        //     const un_node = data[@intFromEnum(inst)].un_node;

        //     const operand: DocData.WalkResult = try self.walkRef(
        //         file,
        //         parent_scope, parent_src,
        //         un_node.operand,
        //         false,
        //     );

        //     return operand;
        // },
        .ptr_type => {
            const ptr = data[@intFromEnum(inst)].ptr_type;
            const extra = file.zir.extraData(Zir.Inst.PtrType, ptr.payload_index);
            var extra_index = extra.end;

            const elem_type_ref = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.elem_type,
                false,
                call_ctx,
            );

            // @check if `addrspace`, `bit_start` and `host_size` really need to be
            // present in json
            var sentinel: ?DocData.Expr = null;
            if (ptr.flags.has_sentinel) {
                const ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                sentinel = ref_result.expr;
                extra_index += 1;
            }

            var @"align": ?DocData.Expr = null;
            if (ptr.flags.has_align) {
                const ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                @"align" = ref_result.expr;
                extra_index += 1;
            }
            var address_space: ?DocData.Expr = null;
            if (ptr.flags.has_addrspace) {
                const ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                address_space = ref_result.expr;
                extra_index += 1;
            }
            const bit_start: ?DocData.Expr = null;
            if (ptr.flags.has_bit_range) {
                const ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                address_space = ref_result.expr;
                extra_index += 1;
            }

            var host_size: ?DocData.Expr = null;
            if (ptr.flags.has_bit_range) {
                const ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
                const ref_result = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
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
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_type => {
            const pl_node = data[@intFromEnum(inst)].pl_node;

            const bin = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index).data;
            const len = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                bin.lhs,
                false,
                call_ctx,
            );
            const child = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                bin.rhs,
                false,
                call_ctx,
            );

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Array = .{
                    .len = len.expr,
                    .child = child.expr,
                },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_type_sentinel => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.ArrayTypeSentinel, pl_node.payload_index);
            const len = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.len,
                false,
                call_ctx,
            );
            const sentinel = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.sentinel,
                false,
                call_ctx,
            );
            const elem_type = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.elem_type,
                false,
                call_ctx,
            );

            const type_slot_index = self.types.items.len;
            try self.types.append(self.arena, .{
                .Array = .{
                    .len = len.expr,
                    .child = elem_type.expr,
                    .sentinel = sentinel.expr,
                },
            });
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .array_init => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len - 1);

            std.debug.assert(operands.len > 0);
            const array_type = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                operands[0],
                false,
                call_ctx,
            );

            for (operands[1..], 0..) |op, idx| {
                const wr = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    op,
                    false,
                    call_ctx,
                );
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
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len);

            for (operands, 0..) |op, idx| {
                const wr = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    op,
                    false,
                    call_ctx,
                );
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
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.MultiOp, pl_node.payload_index);
            const operands = file.zir.refSlice(extra.end, extra.data.operands_len);
            const array_data = try self.arena.alloc(usize, operands.len - 1);

            std.debug.assert(operands.len > 0);
            const array_type = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                operands[0],
                false,
                call_ctx,
            );

            for (operands[1..], 0..) |op, idx| {
                const wr = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    op,
                    false,
                    call_ctx,
                );
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
        .float => {
            const float = data[@intFromEnum(inst)].float;
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_float_type) },
                .expr = .{ .float = float },
            };
        },
        // @check: In frontend I'm handling float128 with `.toFixed(2)`
        .float128 => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Float128, pl_node.payload_index);
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_float_type) },
                .expr = .{ .float128 = extra.data.get() },
            };
        },
        .negate => {
            const un_node = data[@intFromEnum(inst)].un_node;

            var operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
                call_ctx,
            );
            switch (operand.expr) {
                .int => |*int| int.negated = true,
                .int_big => |*int_big| int_big.negated = true,
                else => {
                    const un_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .unOp = .{ .param = 0 } });
                    const param_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, operand.expr);
                    self.exprs.items[un_index] = .{
                        .unOp = .{
                            .name = @tagName(tags[@intFromEnum(inst)]),
                            .param = param_index,
                        },
                    };
                    return DocData.WalkResult{
                        .typeRef = operand.typeRef,
                        .expr = .{ .unOpIndex = un_index },
                    };
                },
            }
            return operand;
        },
        .size_of => {
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);
            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                .expr = .{ .sizeOf = operand_index },
            };
        },
        .bit_size_of => {
            // not working correctly with `align()`
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
                call_ctx,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .bitSizeOf = operand_index },
            };
        },
        .int_from_enum => {
            // not working correctly with `align()`
            const un_node = data[@intFromEnum(inst)].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );
            const builtin_index = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);
            self.exprs.items[builtin_index] = .{
                .builtin = .{
                    .name = @tagName(tags[@intFromEnum(inst)]),
                    .param = operand_index,
                },
            };

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                .expr = .{ .builtinIndex = builtin_index },
            };
        },
        .switch_block => {
            // WIP
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.SwitchBlock, pl_node.payload_index);

            const switch_cond = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.operand,
                false,
                call_ctx,
            );
            const cond_index = self.exprs.items.len;
            try self.exprs.append(self.arena, switch_cond.expr);
            _ = cond_index;

            // const ast_index = self.ast_nodes.items.len;
            // const type_index = self.types.items.len - 1;

            // const ast_line = self.ast_nodes.items[ast_index - 1];

            // const sep = "=" ** 200;
            // log.debug("{s}", .{sep});
            // log.debug("SWITCH BLOCK", .{});
            // log.debug("extra = {any}", .{extra});
            // log.debug("outer_decl = {any}", .{self.types.items[type_index]});
            // log.debug("ast_lines = {}", .{ast_line});
            // log.debug("{s}", .{sep});

            const switch_index = self.exprs.items.len;

            // const src_loc = try self.srcLocInfo(file, pl_node.src_node, parent_src);

            const switch_expr = try self.getBlockSource(file, parent_src, pl_node.src_node);
            try self.exprs.append(self.arena, .{ .comptimeExpr = self.comptime_exprs.items.len });
            try self.comptime_exprs.append(self.arena, .{ .code = switch_expr });
            // try self.exprs.append(self.arena, .{ .switchOp = .{
            //     .cond_index = cond_index,
            //     .file_name = file.sub_file_path,
            //     .src = ast_index,
            //     .outer_decl = type_index,
            // } });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .switchIndex = switch_index },
            };
        },

        .typeof => {
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
                call_ctx,
            );
            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeOf = operand_index },
            };
        },
        .typeof_builtin => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Block, pl_node.payload_index);
            const body = file.zir.extra[extra.end..][extra.data.body_len - 1];
            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                data[body].@"break".operand,
                false,
                call_ctx,
            );

            const operand_index = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            return DocData.WalkResult{
                .typeRef = operand.typeRef,
                .expr = .{ .typeOf = operand_index },
            };
        },
        .as_node, .as_shift_operand => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.As, pl_node.payload_index);

            // Skip the as_node if the destination type is a call instruction
            if (extra.data.dest_type.toIndex()) |dti| {
                var maybe_cc = call_ctx;
                while (maybe_cc) |cc| : (maybe_cc = cc.prev) {
                    if (cc.inst == dti) {
                        return try self.walkRef(
                            file,
                            parent_scope,
                            parent_src,
                            extra.data.operand,
                            false,
                            call_ctx,
                        );
                    }
                }
            }

            const dest_type_walk = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.dest_type,
                false,
                call_ctx,
            );

            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.operand,
                false,
                call_ctx,
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
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            const operand_idx = self.types.items.len;
            try self.types.append(self.arena, .{
                .Optional = .{ .name = "?TODO", .child = operand.expr },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = operand_idx },
            };
        },
        .decl_val, .decl_ref => {
            const str_tok = data[@intFromEnum(inst)].str_tok;
            const decl_status = parent_scope.resolveDeclName(str_tok.start, file, inst.toOptional());
            return DocData.WalkResult{
                .expr = .{ .declRef = decl_status },
            };
        },
        .field_val, .field_ptr => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Field, pl_node.payload_index);

            var path: std.ArrayListUnmanaged(DocData.Expr) = .{};
            try path.append(self.arena, .{
                .declName = file.zir.nullTerminatedString(extra.data.field_name_start),
            });

            // Put inside path the starting index of each decl name that
            // we encounter as we navigate through all the field_*s
            const lhs_ref = blk: {
                var lhs_extra = extra;
                while (true) {
                    const lhs = @intFromEnum(lhs_extra.data.lhs.toIndex() orelse {
                        break :blk lhs_extra.data.lhs;
                    });

                    if (tags[lhs] != .field_val and
                        tags[lhs] != .field_ptr)
                    {
                        break :blk lhs_extra.data.lhs;
                    }

                    lhs_extra = file.zir.extraData(
                        Zir.Inst.Field,
                        data[lhs].pl_node.payload_index,
                    );

                    try path.append(self.arena, .{
                        .declName = file.zir.nullTerminatedString(lhs_extra.data.field_name_start),
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
                if (lhs_ref.toIndex()) |lhs_inst| switch (tags[@intFromEnum(lhs_inst)]) {
                    .call, .field_call => {
                        break :blk DocData.WalkResult{
                            .expr = .{
                                .comptimeExpr = 0,
                            },
                        };
                    },
                    else => {},
                };

                break :blk try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    lhs_ref,
                    false,
                    call_ctx,
                );
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
            try self.tryResolveRefPath(file, inst, path.items);
            return DocData.WalkResult{ .expr = .{ .refPath = path.items } };
        },
        .int_type => {
            const int_type = data[@intFromEnum(inst)].int_type;
            const sign = if (int_type.signedness == .unsigned) "u" else "i";
            const bits = int_type.bit_count;
            const name = try std.fmt.allocPrint(self.arena, "{s}{}", .{ sign, bits });

            try self.types.append(self.arena, .{
                .Int = .{ .name = name },
            });

            return DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = self.types.items.len - 1 },
            };
        },
        .block => {
            const res = DocData.WalkResult{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .comptimeExpr = self.comptime_exprs.items.len },
            };
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const block_expr = try self.getBlockSource(file, parent_src, pl_node.src_node);
            try self.comptime_exprs.append(self.arena, .{
                .code = block_expr,
            });
            return res;
        },
        .block_inline => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Block, pl_node.payload_index);
            return self.walkInlineBody(
                file,
                parent_scope,
                try self.srcLocInfo(file, pl_node.src_node, parent_src),
                parent_src,
                file.zir.bodySlice(extra.end, extra.data.body_len),
                need_type,
                call_ctx,
            );
        },
        .break_inline => {
            const @"break" = data[@intFromEnum(inst)].@"break";
            return try self.walkRef(
                file,
                parent_scope,
                parent_src,
                @"break".operand,
                need_type,
                call_ctx,
            );
        },
        .struct_init => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
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
                    const field_inst_index = @intFromEnum(init_extra.data.field_type);
                    if (tags[field_inst_index] != .struct_init_field_type) unreachable;
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
                            call_ctx,
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
                    call_ctx,
                );
                const exprIdx = self.exprs.items.len;
                try self.exprs.append(self.arena, value.expr);
                var typeRefIdx: ?usize = null;
                if (value.typeRef) |ref| {
                    typeRefIdx = self.exprs.items.len;
                    try self.exprs.append(self.arena, ref);
                }
                fv.* = .{
                    .name = field_name,
                    .val = .{
                        .typeRef = typeRefIdx,
                        .expr = exprIdx,
                    },
                };
            }

            return DocData.WalkResult{
                .typeRef = type_ref,
                .expr = .{ .@"struct" = field_vals },
            };
        },
        .struct_init_empty,
        .struct_init_empty_result,
        => {
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            return DocData.WalkResult{
                .typeRef = operand.expr,
                .expr = .{ .@"struct" = &.{} },
            };
        },
        .struct_init_empty_ref_result => {
            const un_node = data[@intFromEnum(inst)].un_node;

            const operand: DocData.WalkResult = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                false,
                call_ctx,
            );

            const struct_init_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, .{ .@"struct" = &.{} });

            return DocData.WalkResult{
                .typeRef = operand.expr,
                .expr = .{ .@"&" = struct_init_idx },
            };
        },
        .struct_init_anon => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
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
                    call_ctx,
                );

                const exprIdx = self.exprs.items.len;
                try self.exprs.append(self.arena, value.expr);
                var typeRefIdx: ?usize = null;
                if (value.typeRef) |ref| {
                    typeRefIdx = self.exprs.items.len;
                    try self.exprs.append(self.arena, ref);
                }

                fv.* = .{
                    .name = field_name,
                    .val = .{
                        .typeRef = typeRefIdx,
                        .expr = exprIdx,
                    },
                };

                idx = init_extra.end;
            }

            return DocData.WalkResult{
                .expr = .{ .@"struct" = field_vals },
            };
        },
        .error_set_decl => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.ErrorSetDecl, pl_node.payload_index);
            const fields = try self.arena.alloc(
                DocData.Type.Field,
                extra.data.fields_len,
            );
            var idx = extra.end;
            for (fields) |*f| {
                const name = file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[idx]));
                idx += 1;

                const docs = file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[idx]));
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
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .type = type_slot_index },
            };
        },
        .param_anytype, .param_anytype_comptime => {
            // @check if .param_anytype_comptime can be here
            // Analysis of anytype function params happens in `.func`.
            // This switch case handles the case where an expression depends
            // on an anytype field. E.g.: `fn foo(bar: anytype) @TypeOf(bar)`.
            // This means that we're looking at a generic expression.
            const str_tok = data[@intFromEnum(inst)].str_tok;
            const name = str_tok.get(file.zir);
            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = name,
            });
            return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
        },
        .param, .param_comptime => {
            // See .param_anytype for more information.
            const pl_tok = data[@intFromEnum(inst)].pl_tok;
            const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
            const name = file.zir.nullTerminatedString(extra.data.name);

            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = name,
            });
            return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
        },
        .call => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Call, pl_node.payload_index);

            const callee = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.callee,
                need_type,
                call_ctx,
            );

            const args_len = extra.data.flags.args_len;
            var args = try self.arena.alloc(DocData.Expr, args_len);
            const body = file.zir.extra[extra.end..];

            try self.repurposed_insts.put(self.arena, inst, {});
            defer _ = self.repurposed_insts.remove(inst);

            var i: usize = 0;
            while (i < args_len) : (i += 1) {
                const arg_end = file.zir.extra[extra.end + i];
                const break_index = body[arg_end - 1];
                const ref = data[break_index].@"break".operand;
                // TODO: consider toggling need_type to true if we ever want
                //       to show discrepancies between the types of provided
                //       arguments and the types declared in the function
                //       signature for its parameters.
                const wr = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    &.{
                        .inst = inst,
                        .prev = call_ctx,
                    },
                );
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
                    .type => |func_type_idx| switch (self.types.items[func_type_idx]) {
                        .Fn => |func| func.ret,
                        else => blk: {
                            printWithContext(
                                file,
                                inst,
                                "unexpected callee type in walkInstruction.call: `{s}`\n",
                                .{@tagName(self.types.items[func_type_idx])},
                            );

                            break :blk null;
                        },
                    },
                    else => null,
                } else null,
                .expr = .{ .call = call_slot_index },
            };
        },
        .field_call => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.FieldCall, pl_node.payload_index);

            const obj_ptr = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.obj_ptr,
                need_type,
                call_ctx,
            );

            var field_call = try self.arena.alloc(DocData.Expr, 2);

            if (obj_ptr.typeRef) |ref| {
                field_call[0] = ref;
            } else {
                field_call[0] = obj_ptr.expr;
            }
            field_call[1] = .{ .declName = file.zir.nullTerminatedString(extra.data.field_name_start) };
            try self.tryResolveRefPath(file, inst, field_call);

            const args_len = extra.data.flags.args_len;
            var args = try self.arena.alloc(DocData.Expr, args_len);
            const body = file.zir.extra[extra.end..];

            try self.repurposed_insts.put(self.arena, inst, {});
            defer _ = self.repurposed_insts.remove(inst);

            var i: usize = 0;
            while (i < args_len) : (i += 1) {
                const arg_end = file.zir.extra[extra.end + i];
                const break_index = body[arg_end - 1];
                const ref = data[break_index].@"break".operand;
                // TODO: consider toggling need_type to true if we ever want
                //       to show discrepancies between the types of provided
                //       arguments and the types declared in the function
                //       signature for its parameters.
                const wr = try self.walkRef(
                    file,
                    parent_scope,
                    parent_src,
                    ref,
                    false,
                    &.{
                        .inst = inst,
                        .prev = call_ctx,
                    },
                );
                args[i] = wr.expr;
            }

            const cte_slot_index = self.comptime_exprs.items.len;
            try self.comptime_exprs.append(self.arena, .{
                .code = "field call",
            });

            const call_slot_index = self.calls.items.len;
            try self.calls.append(self.arena, .{
                .func = .{ .refPath = field_call },
                .args = args,
                .ret = .{ .comptimeExpr = cte_slot_index },
            });

            return DocData.WalkResult{
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
                inst,
                self_ast_node_index,
                type_slot_index,
                tags[@intFromEnum(inst)] == .func_inferred,
                call_ctx,
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
                inst,
                self_ast_node_index,
                type_slot_index,
                call_ctx,
            );

            return result;
        },
        .optional_payload_safe, .optional_payload_unsafe => {
            const un_node = data[@intFromEnum(inst)].un_node;
            const operand = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                un_node.operand,
                need_type,
                call_ctx,
            );
            const optional_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, operand.expr);

            var typeRef: ?DocData.Expr = null;
            if (operand.typeRef) |ref| {
                switch (ref) {
                    .type => |t_index| {
                        const t = self.types.items[t_index];
                        switch (t) {
                            .Optional => |opt| typeRef = opt.child,
                            else => {
                                printWithContext(file, inst, "Invalid type for optional_payload_*: {}\n", .{t});
                            },
                        }
                    },
                    else => {},
                }
            }

            return DocData.WalkResult{
                .typeRef = typeRef,
                .expr = .{ .optionalPayload = optional_idx },
            };
        },
        .elem_val_node => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Bin, pl_node.payload_index);
            const lhs = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.lhs,
                need_type,
                call_ctx,
            );
            const rhs = try self.walkRef(
                file,
                parent_scope,
                parent_src,
                extra.data.rhs,
                need_type,
                call_ctx,
            );
            const lhs_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, lhs.expr);
            const rhs_idx = self.exprs.items.len;
            try self.exprs.append(self.arena, rhs.expr);
            return DocData.WalkResult{
                .expr = .{
                    .elemVal = .{
                        .lhs = lhs_idx,
                        .rhs = rhs_idx,
                    },
                },
            };
        },
        .extended => {
            const extended = data[@intFromEnum(inst)].extended;
            switch (extended.opcode) {
                else => {
                    printWithContext(
                        file,
                        inst,
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
                        const wr = try self.walkRef(
                            file,
                            parent_scope,
                            parent_src,
                            arg,
                            idx == 0,
                            call_ctx,
                        );
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

                    const extra = file.zir.extraData(Zir.Inst.OpaqueDecl, extended.operand);
                    var extra_index: usize = extra.end;

                    const src_info = try self.srcLocInfo(file, extra.data.src_node, parent_src);

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    extra_index = try self.analyzeAllDecls(
                        file,
                        &scope,
                        inst,
                        src_info,
                        &decl_indexes,
                        &priv_decl_indexes,
                        call_ctx,
                    );

                    self.types.items[type_slot_index] = .{
                        .Opaque = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                            .parent_container = parent_scope.enclosing_type,
                        },
                    };
                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                        .expr = .{ .type = type_slot_index },
                    };
                },
                .variable => {
                    const extra = file.zir.extraData(Zir.Inst.ExtendedVar, extended.operand);

                    const small = @as(Zir.Inst.ExtendedVar.Small, @bitCast(extended.small));
                    var extra_index: usize = extra.end;
                    if (small.has_lib_name) extra_index += 1;
                    if (small.has_align) extra_index += 1;

                    const var_type = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.data.var_type,
                        need_type,
                        call_ctx,
                    );

                    var value: DocData.WalkResult = .{
                        .typeRef = var_type.expr,
                        .expr = .{ .undefined = .{} },
                    };

                    if (small.has_init) {
                        const var_init_ref = @as(Ref, @enumFromInt(file.zir.extra[extra_index]));
                        const var_init = try self.walkRef(
                            file,
                            parent_scope,
                            parent_src,
                            var_init_ref,
                            need_type,
                            call_ctx,
                        );
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

                    const small = @as(Zir.Inst.UnionDecl.Small, @bitCast(extended.small));
                    const extra = file.zir.extraData(Zir.Inst.UnionDecl, extended.operand);
                    var extra_index: usize = extra.end;

                    const src_info = try self.srcLocInfo(file, extra.data.src_node, parent_src);

                    // We delay analysis because union tags can refer to
                    // decls defined inside the union itself.
                    const tag_type_ref: ?Ref = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        const tag_ref = @as(Ref, @enumFromInt(tag_type));
                        break :blk tag_ref;
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

                    const layout_expr: ?DocData.Expr = switch (small.layout) {
                        .Auto => null,
                        else => .{ .enumLiteral = @tagName(small.layout) },
                    };

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    extra_index = try self.analyzeAllDecls(
                        file,
                        &scope,
                        inst,
                        src_info,
                        &decl_indexes,
                        &priv_decl_indexes,
                        call_ctx,
                    );

                    // Analyze the tag once all decls have been analyzed
                    const tag_type = if (tag_type_ref) |tt_ref| (try self.walkRef(
                        file,
                        &scope,
                        parent_src,
                        tt_ref,
                        false,
                        call_ctx,
                    )).expr else null;

                    // Fields
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
                        call_ctx,
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
                            .parent_container = parent_scope.enclosing_type,
                            .layout = layout_expr,
                        },
                    };

                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }

                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
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

                    const small = @as(Zir.Inst.EnumDecl.Small, @bitCast(extended.small));
                    const extra = file.zir.extraData(Zir.Inst.EnumDecl, extended.operand);
                    var extra_index: usize = extra.end;

                    const src_info = try self.srcLocInfo(file, extra.data.src_node, parent_src);

                    const tag_type: ?DocData.Expr = if (small.has_tag_type) blk: {
                        const tag_type = file.zir.extra[extra_index];
                        extra_index += 1;
                        const tag_ref = @as(Ref, @enumFromInt(tag_type));
                        const wr = try self.walkRef(
                            file,
                            parent_scope,
                            parent_src,
                            tag_ref,
                            false,
                            call_ctx,
                        );
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

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    extra_index = try self.analyzeAllDecls(
                        file,
                        &scope,
                        inst,
                        src_info,
                        &decl_indexes,
                        &priv_decl_indexes,
                        call_ctx,
                    );

                    // const body = file.zir.extra[extra_index..][0..body_len];
                    extra_index += body_len;

                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var field_values: std.ArrayListUnmanaged(?DocData.Expr) = .{};
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

                            const has_value = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 1;

                            const field_name_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
                            extra_index += 1;

                            const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
                            extra_index += 1;

                            const value_expr: ?DocData.Expr = if (has_value) blk: {
                                const value_ref = file.zir.extra[extra_index];
                                extra_index += 1;
                                const value = try self.walkRef(
                                    file,
                                    &scope,
                                    src_info,
                                    @as(Ref, @enumFromInt(value_ref)),
                                    false,
                                    call_ctx,
                                );
                                break :blk value.expr;
                            } else null;
                            try field_values.append(self.arena, value_expr);

                            const field_name = file.zir.nullTerminatedString(field_name_index);

                            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
                            const doc_comment: ?[]const u8 = if (doc_comment_index != .empty)
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
                            .values = field_values.items,
                            .nonexhaustive = small.nonexhaustive,
                            .parent_container = parent_scope.enclosing_type,
                        },
                    };
                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
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

                    const small = @as(Zir.Inst.StructDecl.Small, @bitCast(extended.small));
                    const extra = file.zir.extraData(Zir.Inst.StructDecl, extended.operand);
                    var extra_index: usize = extra.end;

                    const src_info = try self.srcLocInfo(file, extra.data.src_node, parent_src);

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;

                    // We don't care about decls yet
                    if (small.has_decls_len) extra_index += 1;

                    var backing_int: ?DocData.Expr = null;
                    if (small.has_backing_int) {
                        const backing_int_body_len = file.zir.extra[extra_index];
                        extra_index += 1; // backing_int_body_len
                        if (backing_int_body_len == 0) {
                            const backing_int_ref = @as(Ref, @enumFromInt(file.zir.extra[extra_index]));
                            const backing_int_res = try self.walkRef(
                                file,
                                &scope,
                                src_info,
                                backing_int_ref,
                                true,
                                call_ctx,
                            );
                            backing_int = backing_int_res.expr;
                            extra_index += 1; // backing_int_ref
                        } else {
                            const backing_int_body = file.zir.bodySlice(extra_index, backing_int_body_len);
                            const break_inst = backing_int_body[backing_int_body.len - 1];
                            const operand = data[@intFromEnum(break_inst)].@"break".operand;
                            const backing_int_res = try self.walkRef(
                                file,
                                &scope,
                                src_info,
                                operand,
                                true,
                                call_ctx,
                            );
                            backing_int = backing_int_res.expr;
                            extra_index += backing_int_body_len; // backing_int_body_inst
                        }
                    }

                    const layout_expr: ?DocData.Expr = switch (small.layout) {
                        .Auto => null,
                        else => .{ .enumLiteral = @tagName(small.layout) },
                    };

                    var decl_indexes: std.ArrayListUnmanaged(usize) = .{};
                    var priv_decl_indexes: std.ArrayListUnmanaged(usize) = .{};

                    extra_index = try self.analyzeAllDecls(
                        file,
                        &scope,
                        inst,
                        src_info,
                        &decl_indexes,
                        &priv_decl_indexes,
                        call_ctx,
                    );

                    // Inside field init bodies, the struct decl instruction is used to refer to the
                    // field type during the second pass of analysis.
                    try self.repurposed_insts.put(self.arena, inst, {});
                    defer _ = self.repurposed_insts.remove(inst);

                    var field_type_refs: std.ArrayListUnmanaged(DocData.Expr) = .{};
                    var field_default_refs: std.ArrayListUnmanaged(?DocData.Expr) = .{};
                    var field_name_indexes: std.ArrayListUnmanaged(usize) = .{};
                    try self.collectStructFieldInfo(
                        file,
                        &scope,
                        src_info,
                        fields_len,
                        &field_type_refs,
                        &field_default_refs,
                        &field_name_indexes,
                        extra_index,
                        small.is_tuple,
                        call_ctx,
                    );

                    self.ast_nodes.items[self_ast_node_index].fields = field_name_indexes.items;

                    self.types.items[type_slot_index] = .{
                        .Struct = .{
                            .name = "todo_name",
                            .src = self_ast_node_index,
                            .privDecls = priv_decl_indexes.items,
                            .pubDecls = decl_indexes.items,
                            .field_types = field_type_refs.items,
                            .field_defaults = field_default_refs.items,
                            .is_tuple = small.is_tuple,
                            .backing_int = backing_int,
                            .line_number = self.ast_nodes.items[self_ast_node_index].line,
                            .parent_container = parent_scope.enclosing_type,
                            .layout = layout_expr,
                        },
                    };
                    if (self.ref_paths_pending_on_types.get(type_slot_index)) |paths| {
                        for (paths.items) |resume_info| {
                            try self.tryResolveRefPath(
                                resume_info.file,
                                inst,
                                resume_info.ref_path,
                            );
                        }

                        _ = self.ref_paths_pending_on_types.remove(type_slot_index);
                        // TODO: we should deallocate the arraylist that holds all the
                        //       decl paths. not doing it now since it's arena-allocated
                        //       anyway, but maybe we should put it elsewhere.
                    }
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                        .expr = .{ .type = type_slot_index },
                    };
                },
                .this => {
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                        .expr = .{
                            .this = parent_scope.enclosing_type.?,
                            // We know enclosing_type is always present
                            // because it's only null for the top-level
                            // struct instruction of a file.
                        },
                    };
                },
                .int_from_error,
                .error_from_int,
                .reify,
                => {
                    const extra = file.zir.extraData(Zir.Inst.UnNode, extended.operand).data;
                    const bin_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
                    const param = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.operand,
                        false,
                        call_ctx,
                    );

                    const param_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, param.expr);

                    self.exprs.items[bin_index] = .{ .builtin = .{ .name = @tagName(extended.opcode), .param = param_index } };

                    return DocData.WalkResult{
                        .typeRef = param.typeRef orelse .{ .type = @intFromEnum(Ref.type_type) },
                        .expr = .{ .builtinIndex = bin_index },
                    };
                },
                .work_item_id,
                .work_group_size,
                .work_group_id,
                => {
                    const extra = file.zir.extraData(Zir.Inst.UnNode, extended.operand).data;
                    const bin_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .builtin = .{ .param = 0 } });
                    const param = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.operand,
                        false,
                        call_ctx,
                    );

                    const param_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, param.expr);

                    self.exprs.items[bin_index] = .{ .builtin = .{ .name = @tagName(extended.opcode), .param = param_index } };

                    return DocData.WalkResult{
                        // from docs we know they return u32
                        .typeRef = .{ .type = @intFromEnum(Ref.u32_type) },
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
                    const ptr: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.ptr,
                        false,
                        call_ctx,
                    );
                    try self.exprs.append(self.arena, ptr.expr);

                    const expected_value_index = self.exprs.items.len;
                    const expected_value: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.expected_value,
                        false,
                        call_ctx,
                    );
                    try self.exprs.append(self.arena, expected_value.expr);

                    const new_value_index = self.exprs.items.len;
                    const new_value: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.new_value,
                        false,
                        call_ctx,
                    );
                    try self.exprs.append(self.arena, new_value.expr);

                    const success_order_index = self.exprs.items.len;
                    const success_order: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.success_order,
                        false,
                        call_ctx,
                    );
                    try self.exprs.append(self.arena, success_order.expr);

                    const failure_order_index = self.exprs.items.len;
                    const failure_order: DocData.WalkResult = try self.walkRef(
                        file,
                        parent_scope,
                        parent_src,
                        extra.failure_order,
                        false,
                        call_ctx,
                    );
                    try self.exprs.append(self.arena, failure_order.expr);

                    const cmpxchg_index = self.exprs.items.len;
                    try self.exprs.append(self.arena, .{ .cmpxchg = .{
                        .name = @tagName(tags[@intFromEnum(inst)]),
                        .type = type_index,
                        .ptr = ptr_index,
                        .expected_value = expected_value_index,
                        .new_value = new_value_index,
                        .success_order = success_order_index,
                        .failure_order = failure_order_index,
                    } });
                    return DocData.WalkResult{
                        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
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
fn analyzeAllDecls(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_inst: Zir.Inst.Index,
    parent_src: SrcLocInfo,
    decl_indexes: *std.ArrayListUnmanaged(usize),
    priv_decl_indexes: *std.ArrayListUnmanaged(usize),
    call_ctx: ?*const CallContext,
) AutodocErrors!usize {
    const first_decl_indexes_slot = decl_indexes.items.len;
    const original_it = file.zir.declIterator(parent_inst);

    // First loop to discover decl names
    {
        var it = original_it;
        while (it.next()) |zir_index| {
            const declaration, _ = file.zir.getDeclaration(zir_index);
            if (declaration.name.isNamedTest(file.zir)) continue;
            const decl_name = declaration.name.toString(file.zir) orelse continue;
            try scope.insertDeclRef(self.arena, decl_name, .Pending);
        }
    }

    // Second loop to analyze `usingnamespace` decls
    {
        var it = original_it;
        var decl_indexes_slot = first_decl_indexes_slot;
        while (it.next()) |zir_index| : (decl_indexes_slot += 1) {
            const pl_node = file.zir.instructions.items(.data)[@intFromEnum(zir_index)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Declaration, pl_node.payload_index);
            if (extra.data.name != .@"usingnamespace") continue;
            try self.analyzeUsingnamespaceDecl(
                file,
                scope,
                try self.srcLocInfo(file, pl_node.src_node, parent_src),
                decl_indexes,
                priv_decl_indexes,
                extra.data,
                @intCast(extra.end),
                call_ctx,
            );
        }
    }

    // Third loop to analyze all remaining decls
    {
        var it = original_it;
        while (it.next()) |zir_index| {
            const pl_node = file.zir.instructions.items(.data)[@intFromEnum(zir_index)].pl_node;
            const extra = file.zir.extraData(Zir.Inst.Declaration, pl_node.payload_index);
            switch (extra.data.name) {
                .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => continue,
                _ => if (extra.data.name.isNamedTest(file.zir)) continue,
            }
            try self.analyzeDecl(
                file,
                scope,
                try self.srcLocInfo(file, pl_node.src_node, parent_src),
                decl_indexes,
                priv_decl_indexes,
                zir_index,
                extra.data,
                @intCast(extra.end),
                call_ctx,
            );
        }
    }

    // Fourth loop to analyze decltests
    var it = original_it;
    while (it.next()) |zir_index| {
        const pl_node = file.zir.instructions.items(.data)[@intFromEnum(zir_index)].pl_node;
        const extra = file.zir.extraData(Zir.Inst.Declaration, pl_node.payload_index);
        if (extra.data.name != .decltest) continue;
        try self.analyzeDecltest(
            file,
            scope,
            try self.srcLocInfo(file, pl_node.src_node, parent_src),
            extra.data,
            @intCast(extra.end),
        );
    }

    return it.extra_index;
}

fn walkInlineBody(
    autodoc: *Autodoc,
    file: *File,
    scope: *Scope,
    block_src: SrcLocInfo,
    parent_src: SrcLocInfo,
    body: []const Zir.Inst.Index,
    need_type: bool,
    call_ctx: ?*const CallContext,
) AutodocErrors!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const break_inst = switch (tags[@intFromEnum(body[body.len - 1])]) {
        .condbr_inline => {
            // Unresolvable.
            const res: DocData.WalkResult = .{
                .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                .expr = .{ .comptimeExpr = autodoc.comptime_exprs.items.len },
            };
            const source = (try file.getTree(autodoc.zcu.gpa)).getNodeSource(block_src.src_node);
            try autodoc.comptime_exprs.append(autodoc.arena, .{
                .code = source,
            });
            return res;
        },
        .break_inline => body[body.len - 1],
        else => unreachable,
    };
    const break_data = file.zir.instructions.items(.data)[@intFromEnum(break_inst)].@"break";
    return autodoc.walkRef(file, scope, parent_src, break_data.operand, need_type, call_ctx);
}

// Asserts the given decl is public
fn analyzeDecl(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    decl_src: SrcLocInfo,
    decl_indexes: *std.ArrayListUnmanaged(usize),
    priv_decl_indexes: *std.ArrayListUnmanaged(usize),
    decl_inst: Zir.Inst.Index,
    declaration: Zir.Inst.Declaration,
    extra_index: u32,
    call_ctx: ?*const CallContext,
) AutodocErrors!void {
    const bodies = declaration.getBodies(extra_index, file.zir);
    const name = file.zir.nullTerminatedString(declaration.name.toString(file.zir).?);

    const doc_comment: ?[]const u8 = if (declaration.flags.has_doc_comment)
        file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[extra_index]))
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

    const walk_result = try self.walkInlineBody(
        file,
        scope,
        decl_src,
        decl_src,
        bodies.value_body,
        true,
        call_ctx,
    );

    const tree = try file.getTree(self.zcu.gpa);
    const kind_token = tree.nodes.items(.main_token)[decl_src.src_node];
    const kind: []const u8 = switch (tree.tokens.items(.tag)[kind_token]) {
        .keyword_var => "var",
        else => "const",
    };

    const decls_slot_index = self.decls.items.len;
    try self.decls.append(self.arena, .{
        .name = name,
        .src = ast_node_index,
        .value = walk_result,
        .kind = kind,
        .parent_container = scope.enclosing_type,
    });

    if (declaration.flags.is_pub) {
        try decl_indexes.append(self.arena, decls_slot_index);
    } else {
        try priv_decl_indexes.append(self.arena, decls_slot_index);
    }

    const decl_status_ptr = scope.resolveDeclName(declaration.name.toString(file.zir).?, file, .none);
    std.debug.assert(decl_status_ptr.* == .Pending);
    decl_status_ptr.* = .{ .Analyzed = decls_slot_index };

    // Unblock any pending decl path that was waiting for this decl.
    if (self.ref_paths_pending_on_decls.get(decl_status_ptr)) |paths| {
        for (paths.items) |resume_info| {
            try self.tryResolveRefPath(
                resume_info.file,
                decl_inst,
                resume_info.ref_path,
            );
        }

        _ = self.ref_paths_pending_on_decls.remove(decl_status_ptr);
        // TODO: we should deallocate the arraylist that holds all the
        //       ref paths. not doing it now since it's arena-allocated
        //       anyway, but maybe we should put it elsewhere.
    }
}

fn analyzeUsingnamespaceDecl(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    decl_src: SrcLocInfo,
    decl_indexes: *std.ArrayListUnmanaged(usize),
    priv_decl_indexes: *std.ArrayListUnmanaged(usize),
    declaration: Zir.Inst.Declaration,
    extra_index: u32,
    call_ctx: ?*const CallContext,
) AutodocErrors!void {
    const bodies = declaration.getBodies(extra_index, file.zir);

    const doc_comment: ?[]const u8 = if (declaration.flags.has_doc_comment)
        file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[extra_index]))
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

    const walk_result = try self.walkInlineBody(
        file,
        scope,
        decl_src,
        decl_src,
        bodies.value_body,
        true,
        call_ctx,
    );

    const decl_slot_index = self.decls.items.len;
    try self.decls.append(self.arena, .{
        .name = "",
        .kind = "",
        .src = ast_node_index,
        .value = walk_result,
        .is_uns = true,
        .parent_container = scope.enclosing_type,
    });

    if (declaration.flags.is_pub) {
        try decl_indexes.append(self.arena, decl_slot_index);
    } else {
        try priv_decl_indexes.append(self.arena, decl_slot_index);
    }
}

fn analyzeDecltest(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    decl_src: SrcLocInfo,
    declaration: Zir.Inst.Declaration,
    extra_index: u32,
) AutodocErrors!void {
    std.debug.assert(declaration.flags.has_doc_comment);
    const decl_name_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);

    const test_source_code = (try file.getTree(self.zcu.gpa)).getNodeSource(decl_src.src_node);

    const decl_name: ?[]const u8 = if (decl_name_index != .empty)
        file.zir.nullTerminatedString(decl_name_index)
    else
        null;

    // astnode
    const ast_node_index = idx: {
        const idx = self.ast_nodes.items.len;
        try self.ast_nodes.append(self.arena, .{
            .file = self.files.getIndex(file).?,
            .line = decl_src.line,
            .col = 0,
            .name = decl_name,
            .code = test_source_code,
        });
        break :idx idx;
    };

    const decl_status = scope.resolveDeclName(decl_name_index, file, .none);

    switch (decl_status.*) {
        .Analyzed => |idx| {
            self.decls.items[idx].decltest = ast_node_index;
        },
        else => unreachable, // we assume analyzeAllDecls analyzed other decls by this point
    }
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
/// When analyzeAllDecls / walkInstruction finishes analyzing a decl / type, it will
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
    inst: Zir.Inst.Index, // used only for panicWithContext
    path: []DocData.Expr,
) AutodocErrors!void {
    var i: usize = 0;
    outer: while (i < path.len - 1) : (i += 1) {
        const parent = path[i];
        const child_string = path[i + 1].declName; // we expect to find an unsolved decl

        var resolved_parent = parent;
        var j: usize = 0;
        while (j < 10_000) : (j += 1) {
            switch (resolved_parent) {
                else => break,
                .this => |t| resolved_parent = .{ .type = t },
                .declIndex => |decl_index| {
                    const decl = self.decls.items[decl_index];
                    resolved_parent = decl.value.expr;
                    continue;
                },
                .declRef => |decl_status_ptr| {
                    // NOTE: must be kep in sync with `findNameInUnsDecls`
                    switch (decl_status_ptr.*) {
                        // The use of unreachable here is conservative.
                        // It might be that it truly should be up to us to
                        // request the analys of this decl, but it's not clear
                        // at the moment of writing.
                        .NotRequested => unreachable,
                        .Analyzed => |decl_index| {
                            const decl = self.decls.items[decl_index];
                            resolved_parent = decl.value.expr;
                            continue;
                        },
                        .Pending => {
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
                                decl_status_ptr,
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
                    }
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

                    // If the last element is a declName or a CTE, then we give up,
                    // otherwise we resovle the parent to it and loop again.
                    // NOTE: we assume that if we find a string, it's because of
                    // a CTE component somewhere in the path. We know that the path
                    // is not pending futher evaluation because we just checked!
                    const last = rp[rp.len - 1];
                    switch (last) {
                        .comptimeExpr, .declName => break :outer,
                        else => {
                            resolved_parent = last;
                            continue;
                        },
                    }
                },
                .fieldVal => |fv| {
                    resolved_parent = self.exprs.items[fv.val.expr];
                },
            }
        } else {
            panicWithContext(
                file,
                inst,
                "exhausted eval quota for `{}`in tryResolveRefPath\n",
                .{resolved_parent},
            );
        }

        switch (resolved_parent) {
            else => {
                // NOTE: indirect references to types / decls should be handled
                //       in the switch above this one!
                printWithContext(
                    file,
                    inst,
                    "TODO: handle `{s}`in tryResolveRefPath\nInfo: {}",
                    .{ @tagName(resolved_parent), resolved_parent },
                );
                // path[i + 1] = (try self.cteTodo("<match failure>")).expr;
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
                        inst,
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
                            inst,
                            "TODO: handle `{s}` in tryResolveDeclPath.type.Array\nInfo: {}",
                            .{ child_string, resolved_parent },
                        );
                    }
                },
                // TODO: the following searches could probably
                //       be performed more efficiently on the corresponding
                //       scope
                .Enum => |t_enum| { // foo.bar.baz
                    // Look into locally-defined pub decls
                    for (t_enum.pubDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    // Look into locally-defined priv decls
                    for (t_enum.privDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    switch (try self.findNameInUnsDecls(file, path[i..path.len], resolved_parent, child_string)) {
                        .Pending => return,
                        .NotFound => {},
                        .Found => |match| {
                            path[i + 1] = match;
                            continue :outer;
                        },
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
                        inst,
                        "failed to match `{s}` in enum",
                        .{child_string},
                    );

                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },
                .Union => |t_union| {
                    // Look into locally-defined pub decls
                    for (t_union.pubDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    // Look into locally-defined priv decls
                    for (t_union.privDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    switch (try self.findNameInUnsDecls(file, path[i..path.len], resolved_parent, child_string)) {
                        .Pending => return,
                        .NotFound => {},
                        .Found => |match| {
                            path[i + 1] = match;
                            continue :outer;
                        },
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
                        inst,
                        "failed to match `{s}` in union",
                        .{child_string},
                    );
                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },

                .Struct => |t_struct| {
                    // Look into locally-defined pub decls
                    for (t_struct.pubDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    // Look into locally-defined priv decls
                    for (t_struct.privDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    switch (try self.findNameInUnsDecls(file, path[i..path.len], resolved_parent, child_string)) {
                        .Pending => return,
                        .NotFound => {},
                        .Found => |match| {
                            path[i + 1] = match;
                            continue :outer;
                        },
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
                    //     inst,
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
                    // Look into locally-defined pub decls
                    for (t_opaque.pubDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    // Look into locally-defined priv decls
                    for (t_opaque.privDecls) |idx| {
                        const d = self.decls.items[idx];
                        if (d.is_uns) continue;
                        if (std.mem.eql(u8, d.name, child_string)) {
                            path[i + 1] = .{ .declIndex = idx };
                            continue :outer;
                        }
                    }

                    // We delay looking into Uns decls since they could be
                    // not fully analyzed yet.
                    switch (try self.findNameInUnsDecls(file, path[i..path.len], resolved_parent, child_string)) {
                        .Pending => return,
                        .NotFound => {},
                        .Found => |match| {
                            path[i + 1] = match;
                            continue :outer;
                        },
                    }

                    // if we got here, our search failed
                    printWithContext(
                        file,
                        inst,
                        "failed to match `{s}` in opaque",
                        .{child_string},
                    );

                    path[i + 1] = (try self.cteTodo("match failure")).expr;
                    continue :outer;
                },
            },
            .@"struct" => |st| {
                for (st) |field| {
                    if (std.mem.eql(u8, field.name, child_string)) {
                        path[i + 1] = .{ .fieldVal = field };
                        continue :outer;
                    }
                }

                // if we got here, our search failed
                printWithContext(
                    file,
                    inst,
                    "failed to match `{s}` in struct",
                    .{child_string},
                );

                path[i + 1] = (try self.cteTodo("match failure")).expr;
                continue :outer;
            },
        }
    }

    if (self.pending_ref_paths.get(&path[path.len - 1])) |waiter_list| {
        // It's important to de-register ourselves as pending before
        // attempting to resolve any other decl.
        _ = self.pending_ref_paths.remove(&path[path.len - 1]);

        for (waiter_list.items) |resume_info| {
            try self.tryResolveRefPath(resume_info.file, inst, resume_info.ref_path);
        }
        // TODO: this is where we should free waiter_list, but its in the arena
        //       that said, we might want to store it elsewhere and reclaim memory asap
    }
}

const UnsSearchResult = union(enum) {
    Found: DocData.Expr,
    Pending,
    NotFound,
};

fn findNameInUnsDecls(
    self: *Autodoc,
    file: *File,
    tail: []DocData.Expr,
    uns_expr: DocData.Expr,
    name: []const u8,
) !UnsSearchResult {
    var to_analyze = std.SegmentedList(DocData.Expr, 1){};
    // TODO: make this an appendAssumeCapacity
    try to_analyze.append(self.arena, uns_expr);

    while (to_analyze.pop()) |cte| {
        var container_expression = cte;
        for (0..10_000) |_| {
            // TODO: handle other types of indirection, like @import
            const type_index = switch (container_expression) {
                .type => |t| t,
                .declRef => |decl_status_ptr| {
                    switch (decl_status_ptr.*) {
                        // The use of unreachable here is conservative.
                        // It might be that it truly should be up to us to
                        // request the analys of this decl, but it's not clear
                        // at the moment of writing.
                        .NotRequested => unreachable,
                        .Analyzed => |decl_index| {
                            const decl = self.decls.items[decl_index];
                            container_expression = decl.value.expr;
                            continue;
                        },
                        .Pending => {
                            // This decl path is pending completion
                            {
                                const res = try self.pending_ref_paths.getOrPut(
                                    self.arena,
                                    &tail[tail.len - 1],
                                );
                                if (!res.found_existing) res.value_ptr.* = .{};
                            }

                            const res = try self.ref_paths_pending_on_decls.getOrPut(
                                self.arena,
                                decl_status_ptr,
                            );
                            if (!res.found_existing) res.value_ptr.* = .{};
                            try res.value_ptr.*.append(self.arena, .{
                                .file = file,
                                .ref_path = tail,
                            });

                            // TODO: save some state that keeps track of our
                            //       progress because, as things stand, we
                            //       always re-start the search from scratch
                            return .Pending;
                        },
                    }
                },
                else => {
                    log.debug(
                        "Handle `{s}` in findNameInUnsDecls (first switch)",
                        .{@tagName(cte)},
                    );
                    return .{ .Found = .{ .comptimeExpr = 0 } };
                },
            };

            const t = self.types.items[type_index];
            const decls = switch (t) {
                else => {
                    log.debug(
                        "Handle `{s}` in findNameInUnsDecls (second switch)",
                        .{@tagName(cte)},
                    );
                    return .{ .Found = .{ .comptimeExpr = 0 } };
                },
                inline .Struct, .Union, .Opaque, .Enum => |c| c.pubDecls,
            };

            for (decls) |idx| {
                const d = self.decls.items[idx];
                if (d.is_uns) {
                    try to_analyze.append(self.arena, d.value.expr);
                } else if (std.mem.eql(u8, d.name, name)) {
                    return .{ .Found = .{ .declIndex = idx } };
                }
            }
        }
    }

    return .NotFound;
}

fn analyzeFancyFunction(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo,
    inst: Zir.Inst.Index,
    self_ast_node_index: usize,
    type_slot_index: usize,
    call_ctx: ?*const CallContext,
) AutodocErrors!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);
    const fn_info = file.zir.getFnInfo(inst);

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
        switch (tags[@intFromEnum(param_index)]) {
            else => {
                panicWithContext(
                    file,
                    param_index,
                    "TODO: handle `{s}` in walkInstruction.func\n",
                    .{@tagName(tags[@intFromEnum(param_index)])},
                );
            },
            .param_anytype, .param_anytype_comptime => {
                // TODO: where are the doc comments?
                const str_tok = data[@intFromEnum(param_index)].str_tok;

                const name = str_tok.get(file.zir);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                self.ast_nodes.appendAssumeCapacity(.{
                    .name = name,
                    .docs = "",
                    .@"comptime" = tags[@intFromEnum(param_index)] == .param_anytype_comptime,
                });

                param_type_refs.appendAssumeCapacity(
                    DocData.Expr{ .@"anytype" = .{} },
                );
            },
            .param, .param_comptime => {
                const pl_tok = data[@intFromEnum(param_index)].pl_tok;
                const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
                const doc_comment = if (extra.data.doc_comment != .empty)
                    file.zir.nullTerminatedString(extra.data.doc_comment)
                else
                    "";
                const name = file.zir.nullTerminatedString(extra.data.name);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                try self.ast_nodes.append(self.arena, .{
                    .name = name,
                    .docs = doc_comment,
                    .@"comptime" = tags[@intFromEnum(param_index)] == .param_comptime,
                });

                const break_index = file.zir.extra[extra.end..][extra.data.body_len - 1];
                const break_operand = data[break_index].@"break".operand;
                const param_type_ref = try self.walkRef(
                    file,
                    scope,
                    parent_src,
                    break_operand,
                    false,
                    call_ctx,
                );

                param_type_refs.appendAssumeCapacity(param_type_ref.expr);
            },
        }
    }

    self.ast_nodes.items[self_ast_node_index].fields = param_ast_indexes.items;

    const pl_node = data[@intFromEnum(inst)].pl_node;
    const extra = file.zir.extraData(Zir.Inst.FuncFancy, pl_node.payload_index);

    var extra_index: usize = extra.end;

    var lib_name: []const u8 = "";
    if (extra.data.bits.has_lib_name) {
        const lib_name_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
        lib_name = file.zir.nullTerminatedString(lib_name_index);
        extra_index += 1;
    }

    var align_index: ?usize = null;
    if (extra.data.bits.has_align_ref) {
        const align_ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
        align_index = self.exprs.items.len;
        _ = try self.walkRef(
            file,
            scope,
            parent_src,
            align_ref,
            false,
            call_ctx,
        );
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
        const addrspace_ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
        addrspace_index = self.exprs.items.len;
        _ = try self.walkRef(
            file,
            scope,
            parent_src,
            addrspace_ref,
            false,
            call_ctx,
        );
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
        const section_ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
        section_index = self.exprs.items.len;
        _ = try self.walkRef(
            file,
            scope,
            parent_src,
            section_ref,
            false,
            call_ctx,
        );
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
    if (extra.data.bits.has_cc_ref and !extra.data.bits.has_cc_body) {
        const cc_ref: Zir.Inst.Ref = @enumFromInt(file.zir.extra[extra_index]);
        const cc_expr = try self.walkRef(
            file,
            scope,
            parent_src,
            cc_ref,
            false,
            call_ctx,
        );

        cc_index = self.exprs.items.len;
        try self.exprs.append(self.arena, cc_expr.expr);

        extra_index += 1;
    } else if (extra.data.bits.has_cc_body) {
        const cc_body_len = file.zir.extra[extra_index];
        extra_index += 1;
        const cc_body = file.zir.bodySlice(extra_index, cc_body_len);

        // We assume the body ends with a break_inline
        const break_index = cc_body[cc_body.len - 1];
        const break_operand = data[@intFromEnum(break_index)].@"break".operand;
        const cc_expr = try self.walkRef(
            file,
            scope,
            parent_src,
            break_operand,
            false,
            call_ctx,
        );

        cc_index = self.exprs.items.len;
        try self.exprs.append(self.arena, cc_expr.expr);

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
                const wr = try self.walkRef(
                    file,
                    scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                break :blk wr.expr;
            },
        },
        else => blk: {
            const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
            const break_operand = data[@intFromEnum(last_instr_index)].@"break".operand;
            const wr = try self.walkRef(
                file,
                scope,
                parent_src,
                break_operand,
                false,
                call_ctx,
            );
            break :blk wr.expr;
        },
    };

    // TODO: a complete version of this will probably need a scope
    //       in order to evaluate correctly closures around funcion
    //       parameters etc.
    const generic_ret: ?DocData.Expr = switch (ret_type_ref) {
        .type => |t| blk: {
            if (fn_info.body.len == 0) break :blk null;
            if (t == @intFromEnum(Ref.type_type)) {
                break :blk try self.getGenericReturnType(
                    file,
                    scope,
                    parent_src,
                    fn_info.body[0],
                    call_ctx,
                );
            } else {
                break :blk null;
            }
        },
        else => null,
    };

    // if we're analyzing a function signature (ie without body), we
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
        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
        .expr = .{ .type = type_slot_index },
    };
}
fn analyzeFunction(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo,
    inst: Zir.Inst.Index,
    self_ast_node_index: usize,
    type_slot_index: usize,
    ret_is_inferred_error_set: bool,
    call_ctx: ?*const CallContext,
) AutodocErrors!DocData.WalkResult {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);
    const fn_info = file.zir.getFnInfo(inst);

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
        switch (tags[@intFromEnum(param_index)]) {
            else => {
                panicWithContext(
                    file,
                    param_index,
                    "TODO: handle `{s}` in walkInstruction.func\n",
                    .{@tagName(tags[@intFromEnum(param_index)])},
                );
            },
            .param_anytype, .param_anytype_comptime => {
                // TODO: where are the doc comments?
                const str_tok = data[@intFromEnum(param_index)].str_tok;

                const name = str_tok.get(file.zir);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                self.ast_nodes.appendAssumeCapacity(.{
                    .name = name,
                    .docs = "",
                    .@"comptime" = tags[@intFromEnum(param_index)] == .param_anytype_comptime,
                });

                param_type_refs.appendAssumeCapacity(
                    DocData.Expr{ .@"anytype" = .{} },
                );
            },
            .param, .param_comptime => {
                const pl_tok = data[@intFromEnum(param_index)].pl_tok;
                const extra = file.zir.extraData(Zir.Inst.Param, pl_tok.payload_index);
                const doc_comment = if (extra.data.doc_comment != .empty)
                    file.zir.nullTerminatedString(extra.data.doc_comment)
                else
                    "";
                const name = file.zir.nullTerminatedString(extra.data.name);

                param_ast_indexes.appendAssumeCapacity(self.ast_nodes.items.len);
                try self.ast_nodes.append(self.arena, .{
                    .name = name,
                    .docs = doc_comment,
                    .@"comptime" = tags[@intFromEnum(param_index)] == .param_comptime,
                });

                const break_index = file.zir.extra[extra.end..][extra.data.body_len - 1];
                const break_operand = data[break_index].@"break".operand;
                const param_type_ref = try self.walkRef(
                    file,
                    scope,
                    parent_src,
                    break_operand,
                    false,
                    call_ctx,
                );

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
                const wr = try self.walkRef(
                    file,
                    scope,
                    parent_src,
                    ref,
                    false,
                    call_ctx,
                );
                break :blk wr.expr;
            },
        },
        else => blk: {
            const last_instr_index = fn_info.ret_ty_body[fn_info.ret_ty_body.len - 1];
            const break_operand = data[@intFromEnum(last_instr_index)].@"break".operand;
            const wr = try self.walkRef(
                file,
                scope,
                parent_src,
                break_operand,
                false,
                call_ctx,
            );
            break :blk wr.expr;
        },
    };

    // TODO: a complete version of this will probably need a scope
    //       in order to evaluate correctly closures around funcion
    //       parameters etc.
    const generic_ret: ?DocData.Expr = switch (ret_type_ref) {
        .type => |t| blk: {
            if (fn_info.body.len == 0) break :blk null;
            if (t == @intFromEnum(Ref.type_type)) {
                break :blk try self.getGenericReturnType(
                    file,
                    scope,
                    parent_src,
                    fn_info.body[0],
                    call_ctx,
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

    // if we're analyzing a function signature (ie without body), we
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
        .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
        .expr = .{ .type = type_slot_index },
    };
}

fn getGenericReturnType(
    self: *Autodoc,
    file: *File,
    scope: *Scope,
    parent_src: SrcLocInfo, // function decl line
    body_main_block: Zir.Inst.Index,
    call_ctx: ?*const CallContext,
) !DocData.Expr {
    const tags = file.zir.instructions.items(.tag);
    const data = file.zir.instructions.items(.data);

    // We expect `body_main_block` to be the first instruction
    // inside the function body, and for it to be a block instruction.
    const pl_node = data[@intFromEnum(body_main_block)].pl_node;
    const extra = file.zir.extraData(Zir.Inst.Block, pl_node.payload_index);
    const body = file.zir.bodySlice(extra.end, extra.data.body_len);
    if (body.len >= 4) {
        const maybe_ret_inst = body[body.len - 4];
        switch (tags[@intFromEnum(maybe_ret_inst)]) {
            .ret_node, .ret_load => {
                const wr = try self.walkInstruction(
                    file,
                    scope,
                    parent_src,
                    maybe_ret_inst,
                    false,
                    call_ctx,
                );
                return wr.expr;
            },
            else => {},
        }
    }
    return DocData.Expr{ .comptimeExpr = 0 };
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
    call_ctx: ?*const CallContext,
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
        const has_type = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        const has_tag = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        const unused = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        _ = unused;

        const field_name = file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[extra_index]));
        extra_index += 1;
        const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
        extra_index += 1;
        const field_type: Zir.Inst.Ref = if (has_type) @enumFromInt(file.zir.extra[extra_index]) else .void_type;
        if (has_type) extra_index += 1;

        if (has_align) extra_index += 1;
        if (has_tag) extra_index += 1;

        // type
        {
            const walk_result = try self.walkRef(
                file,
                scope,
                parent_src,
                field_type,
                false,
                call_ctx,
            );
            try field_type_refs.append(self.arena, walk_result.expr);
        }

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (doc_comment_index != .empty)
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
    field_default_refs: *std.ArrayListUnmanaged(?DocData.Expr),
    field_name_indexes: *std.ArrayListUnmanaged(usize),
    ei: usize,
    is_tuple: bool,
    call_ctx: ?*const CallContext,
) !void {
    if (fields_len == 0) return;
    var extra_index = ei;

    const bits_per_field = 4;
    const fields_per_u32 = 32 / bits_per_field;
    const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;

    const Field = struct {
        field_name: Zir.NullTerminatedString,
        doc_comment_index: Zir.NullTerminatedString,
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
        const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        const has_default = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;
        // const is_comptime = @truncate(u1, cur_bit_bag) != 0;
        cur_bit_bag >>= 1;
        const has_type_body = @as(u1, @truncate(cur_bit_bag)) != 0;
        cur_bit_bag >>= 1;

        const field_name: Zir.NullTerminatedString = if (!is_tuple) blk: {
            const fname = file.zir.extra[extra_index];
            extra_index += 1;
            break :blk @enumFromInt(fname);
        } else .empty;

        const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
        extra_index += 1;

        fields[field_i] = .{
            .field_name = field_name,
            .doc_comment_index = doc_comment_index,
        };

        if (has_type_body) {
            fields[field_i].type_body_len = file.zir.extra[extra_index];
        } else {
            fields[field_i].type_ref = @enumFromInt(file.zir.extra[extra_index]);
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
                const walk_result = try self.walkRef(
                    file,
                    scope,
                    parent_src,
                    field.type_ref,
                    false,
                    call_ctx,
                );
                break :expr walk_result.expr;
            }

            std.debug.assert(field.type_body_len != 0);
            const body = file.zir.bodySlice(extra_index, field.type_body_len);
            extra_index += body.len;

            const break_inst = body[body.len - 1];
            const operand = data[@intFromEnum(break_inst)].@"break".operand;
            try self.ast_nodes.append(self.arena, .{
                .file = self.files.getIndex(file).?,
                .line = parent_src.line,
                .col = 0,
                .fields = null, // walkInstruction will fill `fields` if necessary
            });
            const walk_result = try self.walkRef(
                file,
                scope,
                parent_src,
                operand,
                false,
                call_ctx,
            );
            break :expr walk_result.expr;
        };

        extra_index += field.align_body_len;

        const default_expr: ?DocData.Expr = def: {
            if (field.init_body_len == 0) {
                break :def null;
            }

            const body = file.zir.bodySlice(extra_index, field.init_body_len);
            extra_index += body.len;

            const break_inst = body[body.len - 1];
            const operand = data[@intFromEnum(break_inst)].@"break".operand;
            const walk_result = try self.walkRef(
                file,
                scope,
                parent_src,
                operand,
                false,
                call_ctx,
            );
            break :def walk_result.expr;
        };

        try field_type_refs.append(self.arena, type_expr);
        try field_default_refs.append(self.arena, default_expr);

        // ast node
        {
            try field_name_indexes.append(self.arena, self.ast_nodes.items.len);
            const doc_comment: ?[]const u8 = if (field.doc_comment_index != .empty)
                file.zir.nullTerminatedString(field.doc_comment_index)
            else
                null;
            const field_name: []const u8 = if (field.field_name != .empty)
                file.zir.nullTerminatedString(field.field_name)
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
    call_ctx: ?*const CallContext,
) AutodocErrors!DocData.WalkResult {
    if (ref == .none) {
        return .{ .expr = .{ .comptimeExpr = 0 } };
    } else if (@intFromEnum(ref) <= @intFromEnum(InternPool.Index.last_type)) {
        // We can just return a type that indexes into `types` with the
        // enum value because in the beginning we pre-filled `types` with
        // the types that are listed in `Ref`.
        return DocData.WalkResult{
            .typeRef = .{ .type = @intFromEnum(std.builtin.TypeId.Type) },
            .expr = .{ .type = @intFromEnum(ref) },
        };
    } else if (ref.toIndex()) |zir_index| {
        return self.walkInstruction(
            file,
            parent_scope,
            parent_src,
            zir_index,
            need_type,
            call_ctx,
        );
    } else {
        switch (ref) {
            else => {
                panicWithOptionalContext(
                    file,
                    .none,
                    "TODO: handle {s} in walkRef",
                    .{@tagName(ref)},
                );
            },
            .undef => {
                return DocData.WalkResult{ .expr = .undefined };
            },
            .zero => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 0 } },
                };
            },
            .one => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.comptime_int_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },

            .void_value => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.void_type) },
                    .expr = .{ .void = .{} },
                };
            },
            .unreachable_value => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.noreturn_type) },
                    .expr = .{ .@"unreachable" = .{} },
                };
            },
            .null_value => {
                return DocData.WalkResult{ .expr = .null };
            },
            .bool_true => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.bool_type) },
                    .expr = .{ .bool = true },
                };
            },
            .bool_false => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.bool_type) },
                    .expr = .{ .bool = false },
                };
            },
            .empty_struct => {
                return DocData.WalkResult{ .expr = .{ .@"struct" = &.{} } };
            },
            .zero_usize => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.usize_type) },
                    .expr = .{ .int = .{ .value = 0 } },
                };
            },
            .one_usize => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.usize_type) },
                    .expr = .{ .int = .{ .value = 1 } },
                };
            },
            .calling_convention_type => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.type_type) },
                    .expr = .{ .type = @intFromEnum(Ref.calling_convention_type) },
                };
            },
            .calling_convention_c => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.calling_convention_type) },
                    .expr = .{ .enumLiteral = "C" },
                };
            },
            .calling_convention_inline => {
                return DocData.WalkResult{
                    .typeRef = .{ .type = @intFromEnum(Ref.calling_convention_type) },
                    .expr = .{ .enumLiteral = "Inline" },
                };
            },
            // .generic_poison => {
            //     return DocData.WalkResult{ .int = .{
            //         .type = @intFromEnum(Ref.comptime_int_type),
            //         .value = 1,
            //     } };
            // },
        }
    }
}

fn printWithContext(
    file: *File,
    inst: Zir.Inst.Index,
    comptime fmt: []const u8,
    args: anytype,
) void {
    return printWithOptionalContext(file, inst.toOptional(), fmt, args);
}

fn printWithOptionalContext(file: *File, inst: Zir.Inst.OptionalIndex, comptime fmt: []const u8, args: anytype) void {
    log.debug("Context [{s}] % {} \n " ++ fmt, .{ file.sub_file_path, inst } ++ args);
}

fn panicWithContext(
    file: *File,
    inst: Zir.Inst.Index,
    comptime fmt: []const u8,
    args: anytype,
) noreturn {
    printWithOptionalContext(file, inst.toOptional(), fmt, args);
    unreachable;
}

fn panicWithOptionalContext(
    file: *File,
    inst: Zir.Inst.OptionalIndex,
    comptime fmt: []const u8,
    args: anytype,
) noreturn {
    printWithOptionalContext(file, inst, fmt, args);
    unreachable;
}

fn cteTodo(self: *Autodoc, msg: []const u8) error{OutOfMemory}!DocData.WalkResult {
    const cte_slot_index = self.comptime_exprs.items.len;
    try self.comptime_exprs.append(self.arena, .{
        .code = msg,
    });
    return DocData.WalkResult{ .expr = .{ .comptimeExpr = cte_slot_index } };
}

fn writeFileTableToJson(
    map: std.AutoArrayHashMapUnmanaged(*File, usize),
    mods: std.AutoArrayHashMapUnmanaged(*Module, DocData.DocModule),
    jsw: anytype,
) !void {
    try jsw.beginArray();
    var it = map.iterator();
    while (it.next()) |entry| {
        try jsw.beginArray();
        try jsw.write(entry.key_ptr.*.sub_file_path);
        try jsw.write(mods.getIndex(entry.key_ptr.*.mod) orelse 0);
        try jsw.endArray();
    }
    try jsw.endArray();
}

/// Writes the data like so:
/// ```
/// {
///    "<section name>": [{name: "<guide name>", text: "<guide contents>"},],
/// }
/// ```
fn writeGuidesToJson(sections: std.ArrayListUnmanaged(Section), jsw: anytype) !void {
    try jsw.beginArray();

    for (sections.items) |s| {
        // section name
        try jsw.beginObject();
        try jsw.objectField("name");
        try jsw.write(s.name);
        try jsw.objectField("guides");

        // section value
        try jsw.beginArray();
        for (s.guides.items) |g| {
            try jsw.beginObject();
            try jsw.objectField("name");
            try jsw.write(g.name);
            try jsw.objectField("body");
            try jsw.write(g.body);
            try jsw.endObject();
        }
        try jsw.endArray();
        try jsw.endObject();
    }

    try jsw.endArray();
}

fn writeModuleTableToJson(
    map: std.AutoHashMapUnmanaged(*Module, DocData.DocModule.TableEntry),
    jsw: anytype,
) !void {
    try jsw.beginObject();
    var it = map.valueIterator();
    while (it.next()) |entry| {
        try jsw.objectField(entry.name);
        try jsw.write(entry.value);
    }
    try jsw.endObject();
}

fn srcLocInfo(
    self: Autodoc,
    file: *File,
    src_node: i32,
    parent_src: SrcLocInfo,
) !SrcLocInfo {
    const sn = @as(u32, @intCast(@as(i32, @intCast(parent_src.src_node)) + src_node));
    const tree = try file.getTree(self.zcu.gpa);
    const node_idx = @as(Ast.Node.Index, @bitCast(sn));
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
    const sn = @as(u32, @intCast(@as(i32, @intCast(parent_src.src_node)) + src_node));
    const tree = try file.getTree(self.zcu.gpa);
    const node_idx = @as(Ast.Node.Index, @bitCast(sn));
    const tokens = tree.nodes.items(.main_token);
    const tags = tree.tokens.items(.tag);

    const tok_idx = tokens[node_idx];

    // tags[tok_idx] is the token called 'mut token' in AstGen
    return (tags[tok_idx] == .keyword_var);
}

fn getBlockSource(
    self: Autodoc,
    file: *File,
    parent_src: SrcLocInfo,
    block_src_node: i32,
) AutodocErrors![]const u8 {
    const tree = try file.getTree(self.zcu.gpa);
    const block_src = try self.srcLocInfo(file, block_src_node, parent_src);
    return tree.getNodeSource(block_src.src_node);
}

fn getTLDocComment(self: *Autodoc, file: *File) ![]const u8 {
    const source = (try file.getSource(self.zcu.gpa)).bytes;
    var tokenizer = Tokenizer.init(source);
    var tok = tokenizer.next();
    var comment = std.ArrayList(u8).init(self.arena);
    while (tok.tag == .container_doc_comment) : (tok = tokenizer.next()) {
        try comment.appendSlice(source[tok.loc.start + "//!".len .. tok.loc.end + 1]);
    }

    return comment.items;
}

/// Returns the doc comment cleared of autodoc directives.
fn findGuidePaths(self: *Autodoc, file: *File, str: []const u8) ![]const u8 {
    const guide_prefix = "zig-autodoc-guide:";
    const section_prefix = "zig-autodoc-section:";

    try self.guide_sections.append(self.arena, .{}); // add a default section
    var current_section = &self.guide_sections.items[self.guide_sections.items.len - 1];

    var clean_docs: std.ArrayListUnmanaged(u8) = .{};
    errdefer clean_docs.deinit(self.arena);

    // TODO: this algo is kinda inefficient

    var it = std.mem.splitScalar(u8, str, '\n');
    while (it.next()) |line| {
        const trimmed_line = std.mem.trim(u8, line, " ");
        if (std.mem.startsWith(u8, trimmed_line, guide_prefix)) {
            const path = trimmed_line[guide_prefix.len..];
            const trimmed_path = std.mem.trim(u8, path, " ");
            try self.addGuide(file, trimmed_path, current_section);
        } else if (std.mem.startsWith(u8, trimmed_line, section_prefix)) {
            const section_name = trimmed_line[section_prefix.len..];
            const trimmed_section_name = std.mem.trim(u8, section_name, " ");
            try self.guide_sections.append(self.arena, .{
                .name = trimmed_section_name,
            });
            current_section = &self.guide_sections.items[self.guide_sections.items.len - 1];
        } else {
            try clean_docs.appendSlice(self.arena, line);
            try clean_docs.append(self.arena, '\n');
        }
    }

    return clean_docs.toOwnedSlice(self.arena);
}

fn addGuide(self: *Autodoc, file: *File, guide_path: []const u8, section: *Section) !void {
    if (guide_path.len == 0) return error.MissingAutodocGuideName;

    const resolved_path = try std.fs.path.resolve(self.arena, &[_][]const u8{
        file.sub_file_path, "..", guide_path,
    });

    var guide_file = try file.mod.root.openFile(resolved_path, .{});
    defer guide_file.close();

    const guide = guide_file.reader().readAllAlloc(self.arena, 1 * 1024 * 1024) catch |err| switch (err) {
        error.StreamTooLong => @panic("stream too long"),
        else => |e| return e,
    };

    try section.guides.append(self.arena, .{
        .name = resolved_path,
        .body = guide,
    });
}
