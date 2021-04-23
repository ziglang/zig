//! Compilation of all Zig source code is represented by one `Module`.
//! Each `Compilation` has exactly one or zero `Module`, depending on whether
//! there is or is not any zig source code, respectively.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const assert = std.debug.assert;
const log = std.log.scoped(.module);
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const ast = std.zig.ast;

const Module = @This();
const Compilation = @import("Compilation.zig");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Package = @import("Package.zig");
const link = @import("link.zig");
const ir = @import("ir.zig");
const Zir = @import("Zir.zig");
const trace = @import("tracy.zig").trace;
const AstGen = @import("AstGen.zig");
const Sema = @import("Sema.zig");
const target_util = @import("target.zig");

/// General-purpose allocator. Used for both temporary and long-term storage.
gpa: *Allocator,
comp: *Compilation,

/// Where our incremental compilation metadata serialization will go.
zig_cache_artifact_directory: Compilation.Directory,
/// Pointer to externally managed resource. `null` if there is no zig file being compiled.
root_pkg: *Package,
/// It's rare for a decl to be exported, so we save memory by having a sparse map of
/// Decl pointers to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself is owned by this table.
/// The slice is guaranteed to not be empty.
decl_exports: std.AutoArrayHashMapUnmanaged(*Decl, []*Export) = .{},
/// We track which export is associated with the given symbol name for quick
/// detection of symbol collisions.
symbol_exports: std.StringArrayHashMapUnmanaged(*Export) = .{},
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoArrayHashMapUnmanaged(*Decl, []*Export) = .{},
/// Maps fully qualified namespaced names to the Decl struct for them.
decl_table: std.ArrayHashMapUnmanaged(Scope.NameHash, *Decl, Scope.name_hash_hash, Scope.name_hash_eql, false) = .{},
/// The set of all the files in the Module. We keep track of this in order to iterate
/// over it and check which source files have been modified on the file system when
/// an update is requested, as well as to cache `@import` results.
/// Keys are fully resolved file paths. This table owns the keys and values.
import_table: std.StringArrayHashMapUnmanaged(*Scope.File) = .{},

/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's general purpose allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoArrayHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// When emit_h is non-null, each Decl gets one more compile error slot for
/// emit-h failing for that Decl. This table is also how we tell if a Decl has
/// failed emit-h or succeeded.
emit_h_failed_decls: std.AutoArrayHashMapUnmanaged(*Decl, *ErrorMsg) = .{},
/// Keep track of one `@compileLog` callsite per owner Decl.
compile_log_decls: std.AutoArrayHashMapUnmanaged(*Decl, SrcLoc) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Scope.File`, using Module's general purpose allocator.
failed_files: std.AutoArrayHashMapUnmanaged(*Scope.File, ?*ErrorMsg) = .{},
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's general purpose allocator.
failed_exports: std.AutoArrayHashMapUnmanaged(*Export, *ErrorMsg) = .{},

next_anon_name_index: usize = 0,

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.AutoArrayHashMapUnmanaged(*Decl, void) = .{},

/// Error tags and their values, tag names are duped with mod.gpa.
/// Corresponds with `error_name_list`.
global_error_set: std.StringHashMapUnmanaged(ErrorInt) = .{},

/// ErrorInt -> []const u8 for fast lookups for @intToError at comptime
/// Corresponds with `global_error_set`.
error_name_list: ArrayListUnmanaged([]const u8) = .{},

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

/// When populated it means there was an error opening/reading the root source file.
failed_root_src_file: ?anyerror = null,

stage1_flags: packed struct {
    have_winmain: bool = false,
    have_wwinmain: bool = false,
    have_winmain_crt_startup: bool = false,
    have_wwinmain_crt_startup: bool = false,
    have_dllmain_crt_startup: bool = false,
    have_c_main: bool = false,
    reserved: u2 = 0,
} = .{},

emit_h: ?Compilation.EmitLoc,

job_queued_update_builtin_zig: bool = true,

compile_log_text: ArrayListUnmanaged(u8) = .{},

pub const ErrorInt = u32;

pub const Export = struct {
    options: std.builtin.ExportOptions,
    src: LazySrcLoc,
    /// Represents the position of the export, if any, in the output file.
    link: link.File.Export,
    /// The Decl that performs the export. Note that this is *not* the Decl being exported.
    owner_decl: *Decl,
    /// The Decl being exported. Note this is *not* the Decl performing the export.
    exported_decl: *Decl,
    status: enum {
        in_progress,
        failed,
        /// Indicates that the failure was due to a temporary issue, such as an I/O error
        /// when writing to the output file. Retrying the export may succeed.
        failed_retryable,
        complete,
    },
};

/// When Module emit_h field is non-null, each Decl is allocated via this struct, so that
/// there can be EmitH state attached to each Decl.
pub const DeclPlusEmitH = struct {
    decl: Decl,
    emit_h: EmitH,
};

pub const Decl = struct {
    /// This name is relative to the containing namespace of the decl. It uses
    /// null-termination to save bytes, since there can be a lot of decls in a
    /// compilation. The null byte is not allowed in symbol names, because
    /// executable file formats use null-terminated strings for symbol names.
    /// All Decls have names, even values that are not bound to a zig namespace.
    /// This is necessary for mapping them to an address in the output file.
    /// Memory owned by this decl, using Module's allocator.
    name: [*:0]const u8,
    /// The direct parent namespace of the Decl.
    /// Reference to externally owned memory.
    /// This is `null` for the Decl that represents a `File`.
    namespace: *Scope.Namespace,

    /// An integer that can be checked against the corresponding incrementing
    /// generation field of Module. This is used to determine whether `complete` status
    /// represents pre- or post- re-analysis.
    generation: u32,
    /// The AST node index of this declaration.
    /// Must be recomputed when the corresponding source file is modified.
    src_node: ast.Node.Index,

    /// The most recent value of the Decl after a successful semantic analysis.
    typed_value: union(enum) {
        never_succeeded: void,
        most_recent: TypedValue.Managed,
    },
    /// Represents the "shallow" analysis status. For example, for decls that are functions,
    /// the function type is analyzed with this set to `in_progress`, however, the semantic
    /// analysis of the function body is performed with this value set to `success`. Functions
    /// have their own analysis status field.
    analysis: enum {
        /// This Decl corresponds to an AST Node that has not been referenced yet, and therefore
        /// because of Zig's lazy declaration analysis, it will remain unanalyzed until referenced.
        unreferenced,
        /// Semantic analysis for this Decl is running right now. This state detects dependency loops.
        in_progress,
        /// This Decl might be OK but it depends on another one which did not successfully complete
        /// semantic analysis.
        dependency_failure,
        /// Semantic analysis failure.
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        sema_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// This indicates the failure was something like running out of disk space,
        /// and attempting semantic analysis again may succeed.
        sema_failure_retryable,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        codegen_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// This indicates the failure was something like running out of disk space,
        /// and attempting codegen again may succeed.
        codegen_failure_retryable,
        /// Everything is done. During an update, this Decl may be out of date, depending
        /// on its dependencies. The `generation` field can be used to determine if this
        /// completion status occurred before or after a given update.
        complete,
        /// A Module update is in progress, and this Decl has been flagged as being known
        /// to require re-analysis.
        outdated,
    },
    /// This flag is set when this Decl is added to `Module.deletion_set`, and cleared
    /// when removed.
    deletion_flag: bool,
    /// Whether the corresponding AST decl has a `pub` keyword.
    is_pub: bool,

    /// Represents the position of the code in the output file.
    /// This is populated regardless of semantic analysis and code generation.
    link: link.File.LinkBlock,

    /// Represents the function in the linked output file, if the `Decl` is a function.
    /// This is stored here and not in `Fn` because `Decl` survives across updates but
    /// `Fn` does not.
    /// TODO Look into making `Fn` a longer lived structure and moving this field there
    /// to save on memory usage.
    fn_link: link.File.LinkFn,

    contents_hash: std.zig.SrcHash,

    /// The shallow set of other decls whose typed_value could possibly change if this Decl's
    /// typed_value is modified.
    dependants: DepsTable = .{},
    /// The shallow set of other decls whose typed_value changing indicates that this Decl's
    /// typed_value may need to be regenerated.
    dependencies: DepsTable = .{},

    /// The reason this is not `std.AutoArrayHashMapUnmanaged` is a workaround for
    /// stage1 compiler giving me: `error: struct 'Module.Decl' depends on itself`
    pub const DepsTable = std.ArrayHashMapUnmanaged(*Decl, void, std.array_hash_map.getAutoHashFn(*Decl), std.array_hash_map.getAutoEqlFn(*Decl), false);

    pub fn destroy(decl: *Decl, module: *Module) void {
        const gpa = module.gpa;
        gpa.free(mem.spanZ(decl.name));
        if (decl.typedValueManaged()) |tvm| {
            if (tvm.typed_value.val.castTag(.function)) |payload| {
                const func = payload.data;
                func.deinit(gpa);
            }
            tvm.deinit(gpa);
        }
        decl.dependants.deinit(gpa);
        decl.dependencies.deinit(gpa);
        if (module.emit_h != null) {
            const decl_plus_emit_h = @fieldParentPtr(DeclPlusEmitH, "decl", decl);
            decl_plus_emit_h.emit_h.fwd_decl.deinit(gpa);
            gpa.destroy(decl_plus_emit_h);
        } else {
            gpa.destroy(decl);
        }
    }

    pub fn relativeToNodeIndex(decl: Decl, offset: i32) ast.Node.Index {
        return @bitCast(ast.Node.Index, offset + @bitCast(i32, decl.src_node));
    }

    pub fn nodeIndexToRelative(decl: Decl, node_index: ast.Node.Index) i32 {
        return @bitCast(i32, node_index) - @bitCast(i32, decl.src_node);
    }

    pub fn tokSrcLoc(decl: Decl, token_index: ast.TokenIndex) LazySrcLoc {
        return .{ .token_offset = token_index - decl.srcToken() };
    }

    pub fn nodeSrcLoc(decl: Decl, node_index: ast.Node.Index) LazySrcLoc {
        return .{ .node_offset = decl.nodeIndexToRelative(node_index) };
    }

    pub fn srcLoc(decl: Decl) SrcLoc {
        return .{
            .file_scope = decl.getFileScope(),
            .parent_decl_node = decl.src_node,
            .lazy = .{ .node_offset = 0 },
        };
    }

    pub fn srcToken(decl: Decl) ast.TokenIndex {
        const tree = &decl.namespace.file_scope.tree;
        return tree.firstToken(decl.src_node);
    }

    pub fn srcByteOffset(decl: Decl) u32 {
        const tree = &decl.namespace.file_scope.tree;
        return tree.tokens.items(.start)[decl.srcToken()];
    }

    pub fn fullyQualifiedNameHash(decl: Decl) Scope.NameHash {
        return decl.namespace.fullyQualifiedNameHash(mem.spanZ(decl.name));
    }

    pub fn renderFullyQualifiedName(decl: Decl, writer: anytype) !void {
        const unqualified_name = mem.spanZ(decl.name);
        return decl.namespace.renderFullyQualifiedName(unqualified_name, writer);
    }

    pub fn getFullyQualifiedName(decl: Decl, gpa: *Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();
        try decl.renderFullyQualifiedName(buffer.writer());
        return buffer.toOwnedSlice();
    }

    pub fn typedValue(decl: *Decl) error{AnalysisFail}!TypedValue {
        const tvm = decl.typedValueManaged() orelse return error.AnalysisFail;
        return tvm.typed_value;
    }

    pub fn value(decl: *Decl) error{AnalysisFail}!Value {
        return (try decl.typedValue()).val;
    }

    pub fn dump(decl: *Decl) void {
        const loc = std.zig.findLineColumn(decl.scope.source.bytes, decl.src);
        std.debug.print("{s}:{d}:{d} name={s} status={s}", .{
            decl.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.spanZ(decl.name),
            @tagName(decl.analysis),
        });
        if (decl.typedValueManaged()) |tvm| {
            std.debug.print(" ty={} val={}", .{ tvm.typed_value.ty, tvm.typed_value.val });
        }
        std.debug.print("\n", .{});
    }

    pub fn typedValueManaged(decl: *Decl) ?*TypedValue.Managed {
        switch (decl.typed_value) {
            .most_recent => |*x| return x,
            .never_succeeded => return null,
        }
    }

    pub fn getFileScope(decl: Decl) *Scope.File {
        return decl.namespace.file_scope;
    }

    pub fn getEmitH(decl: *Decl, module: *Module) *EmitH {
        assert(module.emit_h != null);
        const decl_plus_emit_h = @fieldParentPtr(DeclPlusEmitH, "decl", decl);
        return &decl_plus_emit_h.emit_h;
    }

    fn removeDependant(decl: *Decl, other: *Decl) void {
        decl.dependants.removeAssertDiscard(other);
    }

    fn removeDependency(decl: *Decl, other: *Decl) void {
        decl.dependencies.removeAssertDiscard(other);
    }
};

/// This state is attached to every Decl when Module emit_h is non-null.
pub const EmitH = struct {
    fwd_decl: ArrayListUnmanaged(u8) = .{},
};

/// Represents the data that an explicit error set syntax provides.
pub const ErrorSet = struct {
    owner_decl: *Decl,
    /// Offset from Decl node index, points to the error set AST node.
    node_offset: i32,
    names_len: u32,
    /// The string bytes are stored in the owner Decl arena.
    /// They are in the same order they appear in the AST.
    names_ptr: [*]const []const u8,

    pub fn srcLoc(self: ErrorSet) SrcLoc {
        return .{
            .file_scope = self.owner_decl.getFileScope(),
            .parent_decl_node = self.owner_decl.src_node,
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Represents the data that a struct declaration provides.
pub const Struct = struct {
    owner_decl: *Decl,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(Field),
    /// Represents the declarations inside this struct.
    namespace: Scope.Namespace,

    /// Offset from `owner_decl`, points to the struct AST node.
    node_offset: i32,

    pub const Field = struct {
        ty: Type,
        abi_align: Value,
        /// Uses `unreachable_value` to indicate no default.
        default_val: Value,
    };

    pub fn getFullyQualifiedName(s: *Struct, gpa: *Allocator) ![]u8 {
        return s.owner_decl.getFullyQualifiedName(gpa);
    }

    pub fn srcLoc(s: Struct) SrcLoc {
        return .{
            .file_scope = s.owner_decl.getFileScope(),
            .parent_decl_node = s.owner_decl.src_node,
            .lazy = .{ .node_offset = s.node_offset },
        };
    }
};

/// Represents the data that an enum declaration provides, when the fields
/// are auto-numbered, and there are no declarations. The integer tag type
/// is inferred to be the smallest power of two unsigned int that fits
/// the number of fields.
pub const EnumSimple = struct {
    owner_decl: *Decl,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(void),
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,

    pub fn srcLoc(self: EnumSimple) SrcLoc {
        return .{
            .file_scope = self.owner_decl.getFileScope(),
            .parent_decl_node = self.owner_decl.src_node,
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Represents the data that an enum declaration provides, when there is
/// at least one tag value explicitly specified, or at least one declaration.
pub const EnumFull = struct {
    owner_decl: *Decl,
    /// An integer type which is used for the numerical value of the enum.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    tag_ty: Type,
    /// Set of field names in declaration order.
    fields: std.StringArrayHashMapUnmanaged(void),
    /// Maps integer tag value to field index.
    /// Entries are in declaration order, same as `fields`.
    /// If this hash map is empty, it means the enum tags are auto-numbered.
    values: ValueMap,
    /// Represents the declarations inside this struct.
    namespace: Scope.Namespace,
    /// Offset from `owner_decl`, points to the enum decl AST node.
    node_offset: i32,

    pub const ValueMap = std.ArrayHashMapUnmanaged(Value, void, Value.hash_u32, Value.eql, false);

    pub fn srcLoc(self: EnumFull) SrcLoc {
        return .{
            .file_scope = self.owner_decl.getFileScope(),
            .parent_decl_node = self.owner_decl.src_node,
            .lazy = .{ .node_offset = self.node_offset },
        };
    }
};

/// Some Fn struct memory is owned by the Decl's TypedValue.Managed arena allocator.
/// Extern functions do not have this data structure; they are represented by
/// the `Decl` only, with a `Value` tag of `extern_fn`.
pub const Fn = struct {
    owner_decl: *Decl,
    /// Contains un-analyzed ZIR instructions generated from Zig source AST.
    /// Even after we finish analysis, the ZIR is kept in memory, so that
    /// comptime and inline function calls can happen.
    /// Parameter names are stored here so that they may be referenced for debug info,
    /// without having source code bytes loaded into memory.
    /// The number of parameters is determined by referring to the type.
    /// The first N elements of `extra` are indexes into `string_bytes` to
    /// a null-terminated string.
    /// This memory is managed with gpa, must be freed when the function is freed.
    zir: Zir,
    /// undefined unless analysis state is `success`.
    body: ir.Body,
    state: Analysis,

    pub const Analysis = enum {
        queued,
        /// This function intentionally only has ZIR generated because it is marked
        /// inline, which means no runtime version of the function will be generated.
        inline_only,
        in_progress,
        /// There will be a corresponding ErrorMsg in Module.failed_decls
        sema_failure,
        /// This Fn might be OK but it depends on another Decl which did not
        /// successfully complete semantic analysis.
        dependency_failure,
        success,
    };

    /// For debugging purposes.
    pub fn dump(func: *Fn, mod: Module) void {
        ir.dumpFn(mod, func);
    }

    pub fn deinit(func: *Fn, gpa: *Allocator) void {
        func.zir.deinit(gpa);
    }
};

pub const Var = struct {
    /// if is_extern == true this is undefined
    init: Value,
    owner_decl: *Decl,

    is_extern: bool,
    is_mutable: bool,
    is_threadlocal: bool,
};

pub const Scope = struct {
    tag: Tag,

    pub const NameHash = [16]u8;

    pub fn cast(base: *Scope, comptime T: type) ?*T {
        if (T == Defer) {
            switch (base.tag) {
                .defer_normal, .defer_error => return @fieldParentPtr(T, "base", base),
                else => return null,
            }
        }
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn ownerDecl(scope: *Scope) ?*Decl {
        return switch (scope.tag) {
            .block => scope.cast(Block).?.sema.owner_decl,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .defer_normal => unreachable,
            .defer_error => unreachable,
            .file => null,
            .namespace => null,
            .decl_ref => scope.cast(DeclRef).?.decl,
        };
    }

    pub fn srcDecl(scope: *Scope) ?*Decl {
        return switch (scope.tag) {
            .block => scope.cast(Block).?.src_decl,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .defer_normal => unreachable,
            .defer_error => unreachable,
            .file => null,
            .namespace => null,
            .decl_ref => scope.cast(DeclRef).?.decl,
        };
    }

    /// Asserts the scope has a parent which is a Namespace and returns it.
    pub fn namespace(scope: *Scope) *Namespace {
        switch (scope.tag) {
            .block => return scope.cast(Block).?.sema.owner_decl.namespace,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .defer_normal => unreachable,
            .defer_error => unreachable,
            .file => return scope.cast(File).?.namespace,
            .namespace => return scope.cast(Namespace).?,
            .decl_ref => return scope.cast(DeclRef).?.decl.namespace,
        }
    }

    /// Asserts the scope has a parent which is a Namespace or File and
    /// returns the sub_file_path field.
    pub fn subFilePath(base: *Scope) []const u8 {
        switch (base.tag) {
            .namespace => return @fieldParentPtr(Namespace, "base", base).file_scope.sub_file_path,
            .file => return @fieldParentPtr(File, "base", base).sub_file_path,
            .block => unreachable,
            .gen_zir => unreachable,
            .local_val => unreachable,
            .local_ptr => unreachable,
            .defer_normal => unreachable,
            .defer_error => unreachable,
            .decl_ref => unreachable,
        }
    }

    /// When called from inside a Block Scope, chases the src_decl, not the owner_decl.
    pub fn getFileScope(base: *Scope) *Scope.File {
        var cur = base;
        while (true) {
            cur = switch (cur.tag) {
                .namespace => return @fieldParentPtr(Namespace, "base", cur).file_scope,
                .file => return @fieldParentPtr(File, "base", cur),
                .gen_zir => return @fieldParentPtr(GenZir, "base", cur).astgen.file,
                .local_val => return @fieldParentPtr(LocalVal, "base", cur).gen_zir.astgen.file,
                .local_ptr => return @fieldParentPtr(LocalPtr, "base", cur).gen_zir.astgen.file,
                .defer_normal => @fieldParentPtr(Defer, "base", cur).parent,
                .defer_error => @fieldParentPtr(Defer, "base", cur).parent,
                .block => return @fieldParentPtr(Block, "base", cur).src_decl.namespace.file_scope,
                .decl_ref => return @fieldParentPtr(DeclRef, "base", cur).decl.namespace.file_scope,
            };
        }
    }

    fn name_hash_hash(x: NameHash) u32 {
        return @truncate(u32, @bitCast(u128, x));
    }

    fn name_hash_eql(a: NameHash, b: NameHash) bool {
        return @bitCast(u128, a) == @bitCast(u128, b);
    }

    pub const Tag = enum {
        /// .zig source code.
        file,
        /// Namespace owned by structs, enums, unions, and opaques for decls.
        namespace,
        block,
        gen_zir,
        local_val,
        local_ptr,
        /// Used for simple error reporting. Only contains a reference to a
        /// `Decl` for use with `srcDecl` and `ownerDecl`.
        /// Has no parents or children.
        decl_ref,
        defer_normal,
        defer_error,
    };

    /// The container that structs, enums, unions, and opaques have.
    pub const Namespace = struct {
        pub const base_tag: Tag = .namespace;
        base: Scope = Scope{ .tag = base_tag },

        parent: ?*Namespace,
        file_scope: *Scope.File,
        parent_name_hash: NameHash,
        /// Will be a struct, enum, union, or opaque.
        ty: Type,
        /// Direct children of the namespace. Used during an update to detect
        /// which decls have been added/removed from source.
        decls: std.AutoArrayHashMapUnmanaged(*Decl, void) = .{},
        usingnamespace_set: std.AutoHashMapUnmanaged(*Namespace, bool) = .{},

        pub fn deinit(ns: *Namespace, gpa: *Allocator) void {
            ns.decls.deinit(gpa);
            ns.* = undefined;
        }

        pub fn removeDecl(ns: *Namespace, child: *Decl) void {
            _ = ns.decls.swapRemove(child);
        }

        /// Must generate unique bytes with no collisions with other decls.
        /// The point of hashing here is only to limit the number of bytes of
        /// the unique identifier to a fixed size (16 bytes).
        pub fn fullyQualifiedNameHash(ns: Namespace, name: []const u8) NameHash {
            return std.zig.hashName(ns.parent_name_hash, ".", name);
        }

        pub fn renderFullyQualifiedName(ns: Namespace, name: []const u8, writer: anytype) !void {
            // TODO this should render e.g. "std.fs.Dir.OpenOptions"
            return writer.writeAll(name);
        }

        pub fn getDecl(ns: Namespace) *Decl {
            return ns.ty.getOwnerDecl();
        }
    };

    pub const File = struct {
        pub const base_tag: Tag = .file;
        base: Scope = Scope{ .tag = base_tag },
        status: enum {
            never_loaded,
            parse_failure,
            astgen_failure,
            retryable_failure,
            success,
        },
        source_loaded: bool,
        tree_loaded: bool,
        zir_loaded: bool,
        /// Relative to the owning package's root_src_dir.
        /// Memory is stored in gpa, owned by File.
        sub_file_path: []const u8,
        /// Whether this is populated depends on `source_loaded`.
        source: [:0]const u8,
        /// Whether this is populated depends on `status`.
        stat_size: u64,
        /// Whether this is populated depends on `status`.
        stat_inode: std.fs.File.INode,
        /// Whether this is populated depends on `status`.
        stat_mtime: i128,
        /// Whether this is populated or not depends on `tree_loaded`.
        tree: ast.Tree,
        /// Whether this is populated or not depends on `zir_loaded`.
        zir: Zir,
        /// Package that this file is a part of, managed externally.
        pkg: *Package,
        /// The namespace of the struct that represents this file.
        /// Populated only when status is success.
        namespace: *Namespace,

        pub fn unload(file: *File, gpa: *Allocator) void {
            file.unloadTree(gpa);
            file.unloadSource(gpa);
            file.unloadZir(gpa);
        }

        pub fn unloadTree(file: *File, gpa: *Allocator) void {
            if (file.tree_loaded) {
                file.tree_loaded = false;
                file.tree.deinit(gpa);
            }
        }

        pub fn unloadSource(file: *File, gpa: *Allocator) void {
            if (file.source_loaded) {
                file.source_loaded = false;
                gpa.free(file.source);
            }
        }

        pub fn unloadZir(file: *File, gpa: *Allocator) void {
            if (file.zir_loaded) {
                file.zir_loaded = false;
                file.zir.deinit(gpa);
            }
        }

        pub fn deinit(file: *File, gpa: *Allocator) void {
            gpa.free(file.sub_file_path);
            file.unload(gpa);
            file.* = undefined;
        }

        pub fn getSource(file: *File, gpa: *Allocator) ![:0]const u8 {
            if (file.source_loaded) return file.source;

            const root_dir_path = file.pkg.root_src_directory.path orelse ".";
            log.debug("File.getSource, not cached. pkgdir={s} sub_file_path={s}", .{
                root_dir_path, file.sub_file_path,
            });

            // Keep track of inode, file size, mtime, hash so we can detect which files
            // have been modified when an incremental update is requested.
            var f = try file.pkg.root_src_directory.handle.openFile(file.sub_file_path, .{});
            defer f.close();

            const stat = try f.stat();

            if (stat.size > std.math.maxInt(u32))
                return error.FileTooBig;

            const source = try gpa.allocSentinel(u8, stat.size, 0);
            defer if (!file.source_loaded) gpa.free(source);
            const amt = try f.readAll(source);
            if (amt != stat.size)
                return error.UnexpectedEndOfFile;

            // Here we do not modify stat fields because this function is the one
            // used for error reporting. We need to keep the stat fields stale so that
            // astGenFile can know to regenerate ZIR.

            file.source = source;
            file.source_loaded = true;
            return source;
        }

        pub fn destroy(file: *File, gpa: *Allocator) void {
            file.deinit(gpa);
            gpa.destroy(file);
        }

        pub fn dumpSrc(file: *File, src: LazySrcLoc) void {
            const loc = std.zig.findLineColumn(file.source.bytes, src);
            std.debug.print("{s}:{d}:{d}\n", .{ file.sub_file_path, loc.line + 1, loc.column + 1 });
        }
    };

    /// This is the context needed to semantically analyze ZIR instructions and
    /// produce TZIR instructions.
    /// This is a temporary structure stored on the stack; references to it are valid only
    /// during semantic analysis of the block.
    pub const Block = struct {
        pub const base_tag: Tag = .block;

        base: Scope = Scope{ .tag = base_tag },
        parent: ?*Block,
        /// Shared among all child blocks.
        sema: *Sema,
        /// This Decl is the Decl according to the Zig source code corresponding to this Block.
        /// This can vary during inline or comptime function calls. See `Sema.owner_decl`
        /// for the one that will be the same for all Block instances.
        src_decl: *Decl,
        instructions: ArrayListUnmanaged(*ir.Inst),
        label: ?Label = null,
        inlining: ?*Inlining,
        is_comptime: bool,

        /// This `Block` maps a block ZIR instruction to the corresponding
        /// TZIR instruction for break instruction analysis.
        pub const Label = struct {
            zir_block: Zir.Inst.Index,
            merges: Merges,
        };

        /// This `Block` indicates that an inline function call is happening
        /// and return instructions should be analyzed as a break instruction
        /// to this TZIR block instruction.
        /// It is shared among all the blocks in an inline or comptime called
        /// function.
        pub const Inlining = struct {
            merges: Merges,
        };

        pub const Merges = struct {
            block_inst: *ir.Inst.Block,
            /// Separate array list from break_inst_list so that it can be passed directly
            /// to resolvePeerTypes.
            results: ArrayListUnmanaged(*ir.Inst),
            /// Keeps track of the break instructions so that the operand can be replaced
            /// if we need to add type coercion at the end of block analysis.
            /// Same indexes, capacity, length as `results`.
            br_list: ArrayListUnmanaged(*ir.Inst.Br),
        };

        /// For debugging purposes.
        pub fn dump(block: *Block, mod: Module) void {
            Zir.dumpBlock(mod, block);
        }

        pub fn makeSubBlock(parent: *Block) Block {
            return .{
                .parent = parent,
                .sema = parent.sema,
                .src_decl = parent.src_decl,
                .instructions = .{},
                .label = null,
                .inlining = parent.inlining,
                .is_comptime = parent.is_comptime,
            };
        }

        pub fn wantSafety(block: *const Block) bool {
            // TODO take into account scope's safety overrides
            return switch (block.sema.mod.optimizeMode()) {
                .Debug => true,
                .ReleaseSafe => true,
                .ReleaseFast => false,
                .ReleaseSmall => false,
            };
        }

        pub fn getFileScope(block: *Block) *Scope.File {
            return block.src_decl.namespace.file_scope;
        }

        pub fn addNoOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            comptime tag: ir.Inst.Tag,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(tag.Type());
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addUnOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            tag: ir.Inst.Tag,
            operand: *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.UnOp);
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
                .operand = operand,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addBinOp(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            tag: ir.Inst.Tag,
            lhs: *ir.Inst,
            rhs: *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.BinOp);
            inst.* = .{
                .base = .{
                    .tag = tag,
                    .ty = ty,
                    .src = src,
                },
                .lhs = lhs,
                .rhs = rhs,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addBr(
            scope_block: *Scope.Block,
            src: LazySrcLoc,
            target_block: *ir.Inst.Block,
            operand: *ir.Inst,
        ) !*ir.Inst.Br {
            const inst = try scope_block.sema.arena.create(ir.Inst.Br);
            inst.* = .{
                .base = .{
                    .tag = .br,
                    .ty = Type.initTag(.noreturn),
                    .src = src,
                },
                .operand = operand,
                .block = target_block,
            };
            try scope_block.instructions.append(scope_block.sema.gpa, &inst.base);
            return inst;
        }

        pub fn addCondBr(
            block: *Scope.Block,
            src: LazySrcLoc,
            condition: *ir.Inst,
            then_body: ir.Body,
            else_body: ir.Body,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.CondBr);
            inst.* = .{
                .base = .{
                    .tag = .condbr,
                    .ty = Type.initTag(.noreturn),
                    .src = src,
                },
                .condition = condition,
                .then_body = then_body,
                .else_body = else_body,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addCall(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            func: *ir.Inst,
            args: []const *ir.Inst,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.Call);
            inst.* = .{
                .base = .{
                    .tag = .call,
                    .ty = ty,
                    .src = src,
                },
                .func = func,
                .args = args,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addSwitchBr(
            block: *Scope.Block,
            src: LazySrcLoc,
            operand: *ir.Inst,
            cases: []ir.Inst.SwitchBr.Case,
            else_body: ir.Body,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.SwitchBr);
            inst.* = .{
                .base = .{
                    .tag = .switchbr,
                    .ty = Type.initTag(.noreturn),
                    .src = src,
                },
                .target = operand,
                .cases = cases,
                .else_body = else_body,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addDbgStmt(block: *Scope.Block, src: LazySrcLoc, abs_byte_off: u32) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.DbgStmt);
            inst.* = .{
                .base = .{
                    .tag = .dbg_stmt,
                    .ty = Type.initTag(.void),
                    .src = src,
                },
                .byte_offset = abs_byte_off,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }

        pub fn addStructFieldPtr(
            block: *Scope.Block,
            src: LazySrcLoc,
            ty: Type,
            struct_ptr: *ir.Inst,
            field_index: u32,
        ) !*ir.Inst {
            const inst = try block.sema.arena.create(ir.Inst.StructFieldPtr);
            inst.* = .{
                .base = .{
                    .tag = .struct_field_ptr,
                    .ty = ty,
                    .src = src,
                },
                .struct_ptr = struct_ptr,
                .field_index = field_index,
            };
            try block.instructions.append(block.sema.gpa, &inst.base);
            return &inst.base;
        }
    };

    /// This is a temporary structure; references to it are valid only
    /// while constructing a `Zir`.
    pub const GenZir = struct {
        pub const base_tag: Tag = .gen_zir;
        base: Scope = Scope{ .tag = base_tag },
        force_comptime: bool,
        /// The end of special indexes. `Zir.Inst.Ref` subtracts against this number to convert
        /// to `Zir.Inst.Index`. The default here is correct if there are 0 parameters.
        ref_start_index: u32 = Zir.Inst.Ref.typed_value_map.len,
        /// The containing decl AST node.
        decl_node_index: ast.Node.Index,
        /// Parents can be: `GenZir`, `File`
        parent: *Scope,
        /// All `GenZir` scopes for the same ZIR share this.
        astgen: *AstGen,
        /// Keeps track of the list of instructions in this scope only. Indexes
        /// to instructions in `astgen`.
        instructions: ArrayListUnmanaged(Zir.Inst.Index) = .{},
        label: ?Label = null,
        break_block: Zir.Inst.Index = 0,
        continue_block: Zir.Inst.Index = 0,
        /// Only valid when setBreakResultLoc is called.
        break_result_loc: AstGen.ResultLoc = undefined,
        /// When a block has a pointer result location, here it is.
        rl_ptr: Zir.Inst.Ref = .none,
        /// When a block has a type result location, here it is.
        rl_ty_inst: Zir.Inst.Ref = .none,
        /// Keeps track of how many branches of a block did not actually
        /// consume the result location. astgen uses this to figure out
        /// whether to rely on break instructions or writing to the result
        /// pointer for the result instruction.
        rvalue_rl_count: usize = 0,
        /// Keeps track of how many break instructions there are. When astgen is finished
        /// with a block, it can check this against rvalue_rl_count to find out whether
        /// the break instructions should be downgraded to break_void.
        break_count: usize = 0,
        /// Tracks `break :foo bar` instructions so they can possibly be elided later if
        /// the labeled block ends up not needing a result location pointer.
        labeled_breaks: ArrayListUnmanaged(Zir.Inst.Index) = .{},
        /// Tracks `store_to_block_ptr` instructions that correspond to break instructions
        /// so they can possibly be elided later if the labeled block ends up not needing
        /// a result location pointer.
        labeled_store_to_block_ptr_list: ArrayListUnmanaged(Zir.Inst.Index) = .{},

        pub const Label = struct {
            token: ast.TokenIndex,
            block_inst: Zir.Inst.Index,
            used: bool = false,
        };

        pub fn refIsNoReturn(gz: GenZir, inst_ref: Zir.Inst.Ref) bool {
            if (inst_ref == .unreachable_value) return true;
            if (gz.refToIndex(inst_ref)) |inst_index| {
                return gz.astgen.instructions.items(.tag)[inst_index].isNoReturn();
            }
            return false;
        }

        pub fn tokSrcLoc(gz: GenZir, token_index: ast.TokenIndex) LazySrcLoc {
            return .{ .token_offset = token_index - gz.srcToken() };
        }

        pub fn nodeSrcLoc(gz: GenZir, node_index: ast.Node.Index) LazySrcLoc {
            return .{ .node_offset = gz.nodeIndexToRelative(node_index) };
        }

        pub fn nodeIndexToRelative(gz: GenZir, node_index: ast.Node.Index) i32 {
            return @bitCast(i32, node_index) - @bitCast(i32, gz.decl_node_index);
        }

        pub fn tokenIndexToRelative(gz: GenZir, token: ast.TokenIndex) u32 {
            return token - gz.srcToken();
        }

        pub fn srcToken(gz: GenZir) ast.TokenIndex {
            return gz.astgen.file.tree.firstToken(gz.decl_node_index);
        }

        pub fn tree(gz: *const GenZir) *const ast.Tree {
            return &gz.astgen.file.tree;
        }

        pub fn indexToRef(gz: GenZir, inst: Zir.Inst.Index) Zir.Inst.Ref {
            return @intToEnum(Zir.Inst.Ref, gz.ref_start_index + inst);
        }

        pub fn refToIndex(gz: GenZir, inst: Zir.Inst.Ref) ?Zir.Inst.Index {
            const ref_int = @enumToInt(inst);
            if (ref_int >= gz.ref_start_index) {
                return ref_int - gz.ref_start_index;
            } else {
                return null;
            }
        }

        pub fn setBreakResultLoc(gz: *GenZir, parent_rl: AstGen.ResultLoc) void {
            // Depending on whether the result location is a pointer or value, different
            // ZIR needs to be generated. In the former case we rely on storing to the
            // pointer to communicate the result, and use breakvoid; in the latter case
            // the block break instructions will have the result values.
            // One more complication: when the result location is a pointer, we detect
            // the scenario where the result location is not consumed. In this case
            // we emit ZIR for the block break instructions to have the result values,
            // and then rvalue() on that to pass the value to the result location.
            switch (parent_rl) {
                .ty => |ty_inst| {
                    gz.rl_ty_inst = ty_inst;
                    gz.break_result_loc = parent_rl;
                },
                .none_or_ref => {
                    gz.break_result_loc = .ref;
                },
                .discard, .none, .ptr, .ref => {
                    gz.break_result_loc = parent_rl;
                },

                .inferred_ptr => |ptr| {
                    gz.rl_ptr = ptr;
                    gz.break_result_loc = .{ .block_ptr = gz };
                },

                .block_ptr => |parent_block_scope| {
                    gz.rl_ty_inst = parent_block_scope.rl_ty_inst;
                    gz.rl_ptr = parent_block_scope.rl_ptr;
                    gz.break_result_loc = .{ .block_ptr = gz };
                },
            }
        }

        pub fn setBoolBrBody(gz: GenZir, inst: Zir.Inst.Index) !void {
            const gpa = gz.astgen.gpa;
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(Zir.Inst.Block).Struct.fields.len + gz.instructions.items.len);
            const zir_datas = gz.astgen.instructions.items(.data);
            zir_datas[inst].bool_br.payload_index = gz.astgen.addExtraAssumeCapacity(
                Zir.Inst.Block{ .body_len = @intCast(u32, gz.instructions.items.len) },
            );
            gz.astgen.extra.appendSliceAssumeCapacity(gz.instructions.items);
        }

        pub fn setBlockBody(gz: GenZir, inst: Zir.Inst.Index) !void {
            const gpa = gz.astgen.gpa;
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(Zir.Inst.Block).Struct.fields.len + gz.instructions.items.len);
            const zir_datas = gz.astgen.instructions.items(.data);
            zir_datas[inst].pl_node.payload_index = gz.astgen.addExtraAssumeCapacity(
                Zir.Inst.Block{ .body_len = @intCast(u32, gz.instructions.items.len) },
            );
            gz.astgen.extra.appendSliceAssumeCapacity(gz.instructions.items);
        }

        /// Same as `setBlockBody` except we don't copy instructions which are
        /// `store_to_block_ptr` instructions with lhs set to .none.
        pub fn setBlockBodyEliding(gz: GenZir, inst: Zir.Inst.Index) !void {
            const gpa = gz.astgen.gpa;
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(Zir.Inst.Block).Struct.fields.len + gz.instructions.items.len);
            const zir_datas = gz.astgen.instructions.items(.data);
            const zir_tags = gz.astgen.instructions.items(.tag);
            const block_pl_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Block{
                .body_len = @intCast(u32, gz.instructions.items.len),
            });
            zir_datas[inst].pl_node.payload_index = block_pl_index;
            for (gz.instructions.items) |sub_inst| {
                if (zir_tags[sub_inst] == .store_to_block_ptr and
                    zir_datas[sub_inst].bin.lhs == .none)
                {
                    // Decrement `body_len`.
                    gz.astgen.extra.items[block_pl_index] -= 1;
                    continue;
                }
                gz.astgen.extra.appendAssumeCapacity(sub_inst);
            }
        }

        pub fn identAsString(gz: *GenZir, ident_token: ast.TokenIndex) !u32 {
            const astgen = gz.astgen;
            const gpa = astgen.gpa;
            const string_bytes = &astgen.string_bytes;
            const str_index = @intCast(u32, string_bytes.items.len);
            try astgen.appendIdentStr(ident_token, string_bytes);
            const key = string_bytes.items[str_index..];
            const gop = try astgen.string_table.getOrPut(gpa, key);
            if (gop.found_existing) {
                string_bytes.shrinkRetainingCapacity(str_index);
                return gop.entry.value;
            } else {
                // We have to dupe the key into the arena, otherwise the memory
                // becomes invalidated when string_bytes gets data appended.
                // TODO https://github.com/ziglang/zig/issues/8528
                gop.entry.key = try astgen.arena.dupe(u8, key);
                gop.entry.value = str_index;
                try string_bytes.append(gpa, 0);
                return str_index;
            }
        }

        pub const IndexSlice = struct { index: u32, len: u32 };

        pub fn strLitAsString(gz: *GenZir, str_lit_token: ast.TokenIndex) !IndexSlice {
            const astgen = gz.astgen;
            const gpa = astgen.gpa;
            const string_bytes = &astgen.string_bytes;
            const str_index = @intCast(u32, string_bytes.items.len);
            const token_bytes = astgen.file.tree.tokenSlice(str_lit_token);
            try astgen.parseStrLit(str_lit_token, string_bytes, token_bytes, 0);
            const key = string_bytes.items[str_index..];
            const gop = try astgen.string_table.getOrPut(gpa, key);
            if (gop.found_existing) {
                string_bytes.shrinkRetainingCapacity(str_index);
                return IndexSlice{
                    .index = gop.entry.value,
                    .len = @intCast(u32, key.len),
                };
            } else {
                // We have to dupe the key into the arena, otherwise the memory
                // becomes invalidated when string_bytes gets data appended.
                // TODO https://github.com/ziglang/zig/issues/8528
                gop.entry.key = try astgen.arena.dupe(u8, key);
                gop.entry.value = str_index;
                // Still need a null byte because we are using the same table
                // to lookup null terminated strings, so if we get a match, it has to
                // be null terminated for that to work.
                try string_bytes.append(gpa, 0);
                return IndexSlice{
                    .index = str_index,
                    .len = @intCast(u32, key.len),
                };
            }
        }

        pub fn addFunc(gz: *GenZir, args: struct {
            src_node: ast.Node.Index,
            param_types: []const Zir.Inst.Ref,
            body: []const Zir.Inst.Index,
            ret_ty: Zir.Inst.Ref,
            cc: Zir.Inst.Ref,
            lib_name: u32,
            is_var_args: bool,
            is_inferred_error: bool,
        }) !Zir.Inst.Ref {
            assert(args.src_node != 0);
            assert(args.ret_ty != .none);
            const astgen = gz.astgen;
            const gpa = astgen.gpa;

            try gz.instructions.ensureUnusedCapacity(gpa, 1);
            try astgen.instructions.ensureUnusedCapacity(gpa, 1);

            if (args.cc != .none or args.lib_name != 0 or args.is_var_args) {
                try astgen.extra.ensureUnusedCapacity(
                    gpa,
                    @typeInfo(Zir.Inst.ExtendedFunc).Struct.fields.len +
                        args.param_types.len + args.body.len +
                        @boolToInt(args.lib_name != 0) +
                        @boolToInt(args.cc != .none),
                );
                const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.ExtendedFunc{
                    .src_node = gz.nodeIndexToRelative(args.src_node),
                    .return_type = args.ret_ty,
                    .param_types_len = @intCast(u32, args.param_types.len),
                    .body_len = @intCast(u32, args.body.len),
                });
                if (args.cc != .none) {
                    astgen.extra.appendAssumeCapacity(@enumToInt(args.cc));
                }
                if (args.lib_name != 0) {
                    astgen.extra.appendAssumeCapacity(args.lib_name);
                }
                astgen.appendRefsAssumeCapacity(args.param_types);
                astgen.extra.appendSliceAssumeCapacity(args.body);

                const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
                astgen.instructions.appendAssumeCapacity(.{
                    .tag = .extended,
                    .data = .{ .extended = .{
                        .opcode = .func,
                        .small = @bitCast(u16, Zir.Inst.ExtendedFunc.Small{
                            .is_var_args = args.is_var_args,
                            .is_inferred_error = args.is_inferred_error,
                            .has_lib_name = args.lib_name != 0,
                            .has_cc = args.cc != .none,
                        }),
                        .operand = payload_index,
                    } },
                });
                gz.instructions.appendAssumeCapacity(new_index);
                return gz.indexToRef(new_index);
            } else {
                try gz.astgen.extra.ensureUnusedCapacity(
                    gpa,
                    @typeInfo(Zir.Inst.Func).Struct.fields.len +
                        args.param_types.len + args.body.len,
                );

                const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Func{
                    .return_type = args.ret_ty,
                    .param_types_len = @intCast(u32, args.param_types.len),
                    .body_len = @intCast(u32, args.body.len),
                });
                gz.astgen.appendRefsAssumeCapacity(args.param_types);
                gz.astgen.extra.appendSliceAssumeCapacity(args.body);

                const tag: Zir.Inst.Tag = if (args.is_inferred_error) .func_inferred else .func;
                const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
                gz.astgen.instructions.appendAssumeCapacity(.{
                    .tag = tag,
                    .data = .{ .pl_node = .{
                        .src_node = gz.nodeIndexToRelative(args.src_node),
                        .payload_index = payload_index,
                    } },
                });
                gz.instructions.appendAssumeCapacity(new_index);
                return gz.indexToRef(new_index);
            }
        }

        pub fn addCall(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            callee: Zir.Inst.Ref,
            args: []const Zir.Inst.Ref,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !Zir.Inst.Ref {
            assert(callee != .none);
            assert(src_node != 0);
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);
            try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
                @typeInfo(Zir.Inst.Call).Struct.fields.len + args.len);

            const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Call{
                .callee = callee,
                .args_len = @intCast(u32, args.len),
            });
            gz.astgen.appendRefsAssumeCapacity(args);

            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.indexToRef(new_index);
        }

        /// Note that this returns a `Zir.Inst.Index` not a ref.
        /// Leaves the `payload_index` field undefined.
        pub fn addBoolBr(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            lhs: Zir.Inst.Ref,
        ) !Zir.Inst.Index {
            assert(lhs != .none);
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .bool_br = .{
                    .lhs = lhs,
                    .payload_index = undefined,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }

        pub fn addInt(gz: *GenZir, integer: u64) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = .int,
                .data = .{ .int = integer },
            });
        }

        pub fn addIntBig(gz: *GenZir, limbs: []const std.math.big.Limb) !Zir.Inst.Ref {
            const astgen = gz.astgen;
            const gpa = astgen.gpa;
            try gz.instructions.ensureUnusedCapacity(gpa, 1);
            try astgen.instructions.ensureUnusedCapacity(gpa, 1);
            try astgen.string_bytes.ensureUnusedCapacity(gpa, @sizeOf(std.math.big.Limb) * limbs.len);

            const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
            astgen.instructions.appendAssumeCapacity(.{
                .tag = .int_big,
                .data = .{ .str = .{
                    .start = @intCast(u32, astgen.string_bytes.items.len),
                    .len = @intCast(u32, limbs.len),
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            astgen.string_bytes.appendSliceAssumeCapacity(mem.sliceAsBytes(limbs));
            return gz.indexToRef(new_index);
        }

        pub fn addFloat(gz: *GenZir, number: f32, src_node: ast.Node.Index) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = .float,
                .data = .{ .float = .{
                    .src_node = gz.nodeIndexToRelative(src_node),
                    .number = number,
                } },
            });
        }

        pub fn addUnNode(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            operand: Zir.Inst.Ref,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !Zir.Inst.Ref {
            assert(operand != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .un_node = .{
                    .operand = operand,
                    .src_node = gz.nodeIndexToRelative(src_node),
                } },
            });
        }

        pub fn addPlNode(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
            extra: anytype,
        ) !Zir.Inst.Ref {
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const payload_index = try gz.astgen.addExtra(extra);
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.indexToRef(new_index);
        }

        pub fn addExtendedPayload(
            gz: *GenZir,
            opcode: Zir.Inst.Extended,
            extra: anytype,
        ) !Zir.Inst.Ref {
            const gpa = gz.astgen.gpa;

            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const payload_index = try gz.astgen.addExtra(extra);
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = .extended,
                .data = .{ .extended = .{
                    .opcode = opcode,
                    .small = undefined,
                    .operand = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.indexToRef(new_index);
        }

        pub fn addArrayTypeSentinel(
            gz: *GenZir,
            len: Zir.Inst.Ref,
            sentinel: Zir.Inst.Ref,
            elem_type: Zir.Inst.Ref,
        ) !Zir.Inst.Ref {
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const payload_index = try gz.astgen.addExtra(Zir.Inst.ArrayTypeSentinel{
                .sentinel = sentinel,
                .elem_type = elem_type,
            });
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = .array_type_sentinel,
                .data = .{ .array_type_sentinel = .{
                    .len = len,
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.indexToRef(new_index);
        }

        pub fn addUnTok(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            operand: Zir.Inst.Ref,
            /// Absolute token index. This function does the conversion to Decl offset.
            abs_tok_index: ast.TokenIndex,
        ) !Zir.Inst.Ref {
            assert(operand != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .un_tok = .{
                    .operand = operand,
                    .src_tok = gz.tokenIndexToRelative(abs_tok_index),
                } },
            });
        }

        pub fn addStrTok(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            str_index: u32,
            /// Absolute token index. This function does the conversion to Decl offset.
            abs_tok_index: ast.TokenIndex,
        ) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .str_tok = .{
                    .start = str_index,
                    .src_tok = gz.tokenIndexToRelative(abs_tok_index),
                } },
            });
        }

        pub fn addBreak(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            break_block: Zir.Inst.Index,
            operand: Zir.Inst.Ref,
        ) !Zir.Inst.Index {
            return gz.addAsIndex(.{
                .tag = tag,
                .data = .{ .@"break" = .{
                    .block_inst = break_block,
                    .operand = operand,
                } },
            });
        }

        pub fn addBin(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            lhs: Zir.Inst.Ref,
            rhs: Zir.Inst.Ref,
        ) !Zir.Inst.Ref {
            assert(lhs != .none);
            assert(rhs != .none);
            return gz.add(.{
                .tag = tag,
                .data = .{ .bin = .{
                    .lhs = lhs,
                    .rhs = rhs,
                } },
            });
        }

        pub fn addDecl(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            decl_index: u32,
            src_node: ast.Node.Index,
        ) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(src_node),
                    .payload_index = decl_index,
                } },
            });
        }

        pub fn addNode(
            gz: *GenZir,
            tag: Zir.Inst.Tag,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = tag,
                .data = .{ .node = gz.nodeIndexToRelative(src_node) },
            });
        }

        pub fn addNodeExtended(
            gz: *GenZir,
            opcode: Zir.Inst.Extended,
            /// Absolute node index. This function does the conversion to offset from Decl.
            src_node: ast.Node.Index,
        ) !Zir.Inst.Ref {
            return gz.add(.{
                .tag = .extended,
                .data = .{ .extended = .{
                    .opcode = opcode,
                    .small = undefined,
                    .operand = @bitCast(u32, gz.nodeIndexToRelative(src_node)),
                } },
            });
        }

        pub fn addAllocExtended(
            gz: *GenZir,
            args: struct {
                /// Absolute node index. This function does the conversion to offset from Decl.
                node: ast.Node.Index,
                type_inst: Zir.Inst.Ref,
                align_inst: Zir.Inst.Ref,
                is_const: bool,
                is_comptime: bool,
            },
        ) !Zir.Inst.Ref {
            const astgen = gz.astgen;
            const gpa = astgen.gpa;

            try gz.instructions.ensureUnusedCapacity(gpa, 1);
            try astgen.instructions.ensureUnusedCapacity(gpa, 1);
            try astgen.extra.ensureUnusedCapacity(
                gpa,
                @typeInfo(Zir.Inst.AllocExtended).Struct.fields.len +
                    @as(usize, @boolToInt(args.type_inst != .none)) +
                    @as(usize, @boolToInt(args.align_inst != .none)),
            );
            const payload_index = gz.astgen.addExtra(Zir.Inst.AllocExtended{
                .src_node = gz.nodeIndexToRelative(args.node),
            }) catch unreachable; // ensureUnusedCapacity above
            if (args.type_inst != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.type_inst));
            }
            if (args.align_inst != .none) {
                astgen.extra.appendAssumeCapacity(@enumToInt(args.align_inst));
            }

            const has_type: u4 = @boolToInt(args.type_inst != .none);
            const has_align: u4 = @boolToInt(args.align_inst != .none);
            const is_const: u4 = @boolToInt(args.is_const);
            const is_comptime: u4 = @boolToInt(args.is_comptime);
            const small: u16 = has_type | (has_align << 1) | (is_const << 2) | (is_comptime << 3);

            const new_index = @intCast(Zir.Inst.Index, astgen.instructions.len);
            astgen.instructions.appendAssumeCapacity(.{
                .tag = .extended,
                .data = .{ .extended = .{
                    .opcode = .alloc,
                    .small = small,
                    .operand = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return gz.indexToRef(new_index);
        }

        /// Note that this returns a `Zir.Inst.Index` not a ref.
        /// Does *not* append the block instruction to the scope.
        /// Leaves the `payload_index` field undefined.
        pub fn addBlock(gz: *GenZir, tag: Zir.Inst.Tag, node: ast.Node.Index) !Zir.Inst.Index {
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            const gpa = gz.astgen.gpa;
            try gz.astgen.instructions.append(gpa, .{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(node),
                    .payload_index = undefined,
                } },
            });
            return new_index;
        }

        /// Note that this returns a `Zir.Inst.Index` not a ref.
        /// Leaves the `payload_index` field undefined.
        pub fn addCondBr(gz: *GenZir, tag: Zir.Inst.Tag, node: ast.Node.Index) !Zir.Inst.Index {
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            try gz.astgen.instructions.append(gpa, .{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(node),
                    .payload_index = undefined,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }

        pub fn add(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Ref {
            return gz.indexToRef(try gz.addAsIndex(inst));
        }

        pub fn addAsIndex(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Index {
            const gpa = gz.astgen.gpa;
            try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
            try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);

            const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(inst);
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index;
        }
    };

    /// This is always a `const` local and importantly the `inst` is a value type, not a pointer.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalVal = struct {
        pub const base_tag: Tag = .local_val;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`.
        parent: *Scope,
        gen_zir: *GenZir,
        name: []const u8,
        inst: Zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        token_src: ast.TokenIndex,
    };

    /// This could be a `const` or `var` local. It has a pointer instead of a value.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    pub const LocalPtr = struct {
        pub const base_tag: Tag = .local_ptr;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`.
        parent: *Scope,
        gen_zir: *GenZir,
        name: []const u8,
        ptr: Zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        token_src: ast.TokenIndex,
    };

    pub const Defer = struct {
        base: Scope,
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`.
        parent: *Scope,
        defer_node: ast.Node.Index,
    };

    pub const DeclRef = struct {
        pub const base_tag: Tag = .decl_ref;
        base: Scope = Scope{ .tag = base_tag },
        decl: *Decl,
    };
};

/// This struct holds data necessary to construct API-facing `AllErrors.Message`.
/// Its memory is managed with the general purpose allocator so that they
/// can be created and destroyed in response to incremental updates.
/// In some cases, the Scope.File could have been inferred from where the ErrorMsg
/// is stored. For example, if it is stored in Module.failed_decls, then the Scope.File
/// would be determined by the Decl Scope. However, the data structure contains the field
/// anyway so that `ErrorMsg` can be reused for error notes, which may be in a different
/// file than the parent error message. It also simplifies processing of error messages.
pub const ErrorMsg = struct {
    src_loc: SrcLoc,
    msg: []const u8,
    notes: []ErrorMsg = &.{},

    pub fn create(
        gpa: *Allocator,
        src_loc: SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !*ErrorMsg {
        const err_msg = try gpa.create(ErrorMsg);
        errdefer gpa.destroy(err_msg);
        err_msg.* = try init(gpa, src_loc, format, args);
        return err_msg;
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with `gpa`,
    /// as well as all notes.
    pub fn destroy(err_msg: *ErrorMsg, gpa: *Allocator) void {
        err_msg.deinit(gpa);
        gpa.destroy(err_msg);
    }

    pub fn init(
        gpa: *Allocator,
        src_loc: SrcLoc,
        comptime format: []const u8,
        args: anytype,
    ) !ErrorMsg {
        return ErrorMsg{
            .src_loc = src_loc,
            .msg = try std.fmt.allocPrint(gpa, format, args),
        };
    }

    pub fn deinit(err_msg: *ErrorMsg, gpa: *Allocator) void {
        for (err_msg.notes) |*note| {
            note.deinit(gpa);
        }
        gpa.free(err_msg.notes);
        gpa.free(err_msg.msg);
        err_msg.* = undefined;
    }
};

/// Canonical reference to a position within a source file.
pub const SrcLoc = struct {
    file_scope: *Scope.File,
    /// Might be 0 depending on tag of `lazy`.
    parent_decl_node: ast.Node.Index,
    /// Relative to `parent_decl_node`.
    lazy: LazySrcLoc,

    pub fn declSrcToken(src_loc: SrcLoc) ast.TokenIndex {
        const tree = src_loc.file_scope.tree;
        return tree.firstToken(src_loc.parent_decl_node);
    }

    pub fn declRelativeToNodeIndex(src_loc: SrcLoc, offset: i32) ast.TokenIndex {
        return @bitCast(ast.Node.Index, offset + @bitCast(i32, src_loc.parent_decl_node));
    }

    pub fn byteOffset(src_loc: SrcLoc) !u32 {
        switch (src_loc.lazy) {
            .unneeded => unreachable,
            .entire_file => return 0,

            .byte_abs => |byte_index| return byte_index,

            .token_abs => |tok_index| {
                const tree = src_loc.file_scope.tree;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_abs => |node| {
                const tree = src_loc.file_scope.tree;
                const token_starts = tree.tokens.items(.start);
                const tok_index = tree.firstToken(node);
                return token_starts[tok_index];
            },
            .byte_offset => |byte_off| {
                const tree = src_loc.file_scope.tree;
                const token_starts = tree.tokens.items(.start);
                return token_starts[src_loc.declSrcToken()] + byte_off;
            },
            .token_offset => |tok_off| {
                const tok_index = src_loc.declSrcToken() + tok_off;
                const tree = src_loc.file_scope.tree;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset, .node_offset_bin_op => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_back2tok => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const tok_index = tree.firstToken(node) - 2;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_var_decl_ty => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_tags = tree.nodes.items(.tag);
                const full = switch (node_tags[node]) {
                    .global_var_decl => tree.globalVarDecl(node),
                    .local_var_decl => tree.localVarDecl(node),
                    .simple_var_decl => tree.simpleVarDecl(node),
                    .aligned_var_decl => tree.alignedVarDecl(node),
                    else => unreachable,
                };
                const tok_index = if (full.ast.type_node != 0) blk: {
                    const main_tokens = tree.nodes.items(.main_token);
                    break :blk main_tokens[full.ast.type_node];
                } else blk: {
                    break :blk full.ast.mut_token + 1; // the name token
                };
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_builtin_call_arg0 => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const param = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => node_datas[node].lhs,
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs],
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[param];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_builtin_call_arg1 => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const param = switch (node_tags[node]) {
                    .builtin_call_two, .builtin_call_two_comma => node_datas[node].rhs,
                    .builtin_call, .builtin_call_comma => tree.extra_data[node_datas[node].lhs + 1],
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[param];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_array_access_index => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[node_datas[node].rhs];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_slice_sentinel => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .slice_open => tree.sliceOpen(node),
                    .slice => tree.slice(node),
                    .slice_sentinel => tree.sliceSentinel(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.sentinel];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_call_func => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .call_one,
                    .call_one_comma,
                    .async_call_one,
                    .async_call_one_comma,
                    => tree.callOne(&params, node),

                    .call,
                    .call_comma,
                    .async_call,
                    .async_call_comma,
                    => tree.callFull(node),

                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.fn_expr];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_field_name => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tok_index = switch (node_tags[node]) {
                    .field_access => node_datas[node].rhs,
                    else => tree.firstToken(node) - 2,
                };
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_deref_ptr => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tok_index = node_datas[node].lhs;
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_asm_source => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.template];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_asm_ret_ty => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const full = switch (node_tags[node]) {
                    .asm_simple => tree.asmSimple(node),
                    .@"asm" => tree.asmFull(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.outputs[0]];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_for_cond, .node_offset_if_cond => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_tags = tree.nodes.items(.tag);
                const src_node = switch (node_tags[node]) {
                    .if_simple => tree.ifSimple(node).ast.cond_expr,
                    .@"if" => tree.ifFull(node).ast.cond_expr,
                    .while_simple => tree.whileSimple(node).ast.cond_expr,
                    .while_cont => tree.whileCont(node).ast.cond_expr,
                    .@"while" => tree.whileFull(node).ast.cond_expr,
                    .for_simple => tree.forSimple(node).ast.cond_expr,
                    .@"for" => tree.forFull(node).ast.cond_expr,
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_bin_lhs => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].lhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
            .node_offset_bin_rhs => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].rhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_switch_operand => |node_off| {
                const node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const src_node = node_datas[node].lhs;
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[src_node];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_switch_special_prong => |node_off| {
                const switch_node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
                const case_nodes = tree.extra_data[extra.start..extra.end];
                for (case_nodes) |case_node| {
                    const case = switch (node_tags[case_node]) {
                        .switch_case_one => tree.switchCaseOne(case_node),
                        .switch_case => tree.switchCase(case_node),
                        else => unreachable,
                    };
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                        node_tags[case.ast.values[0]] == .identifier and
                        mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"));
                    if (!is_special) continue;

                    const tok_index = main_tokens[case_node];
                    const token_starts = tree.tokens.items(.start);
                    return token_starts[tok_index];
                } else unreachable;
            },

            .node_offset_switch_range => |node_off| {
                const switch_node = src_loc.declRelativeToNodeIndex(node_off);
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const main_tokens = tree.nodes.items(.main_token);
                const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
                const case_nodes = tree.extra_data[extra.start..extra.end];
                for (case_nodes) |case_node| {
                    const case = switch (node_tags[case_node]) {
                        .switch_case_one => tree.switchCaseOne(case_node),
                        .switch_case => tree.switchCase(case_node),
                        else => unreachable,
                    };
                    const is_special = (case.ast.values.len == 0) or
                        (case.ast.values.len == 1 and
                        node_tags[case.ast.values[0]] == .identifier and
                        mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"));
                    if (is_special) continue;

                    for (case.ast.values) |item_node| {
                        if (node_tags[item_node] == .switch_range) {
                            const tok_index = main_tokens[item_node];
                            const token_starts = tree.tokens.items(.start);
                            return token_starts[tok_index];
                        }
                    }
                } else unreachable;
            },

            .node_offset_fn_type_cc => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.callconv_expr];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },

            .node_offset_fn_type_ret_ty => |node_off| {
                const tree = src_loc.file_scope.tree;
                const node_datas = tree.nodes.items(.data);
                const node_tags = tree.nodes.items(.tag);
                const node = src_loc.declRelativeToNodeIndex(node_off);
                var params: [1]ast.Node.Index = undefined;
                const full = switch (node_tags[node]) {
                    .fn_proto_simple => tree.fnProtoSimple(&params, node),
                    .fn_proto_multi => tree.fnProtoMulti(node),
                    .fn_proto_one => tree.fnProtoOne(&params, node),
                    .fn_proto => tree.fnProto(node),
                    else => unreachable,
                };
                const main_tokens = tree.nodes.items(.main_token);
                const tok_index = main_tokens[full.ast.return_type];
                const token_starts = tree.tokens.items(.start);
                return token_starts[tok_index];
            },
        }
    }
};

/// Resolving a source location into a byte offset may require doing work
/// that we would rather not do unless the error actually occurs.
/// Therefore we need a data structure that contains the information necessary
/// to lazily produce a `SrcLoc` as required.
/// Most of the offsets in this data structure are relative to the containing Decl.
/// This makes the source location resolve properly even when a Decl gets
/// shifted up or down in the file, as long as the Decl's contents itself
/// do not change.
pub const LazySrcLoc = union(enum) {
    /// When this tag is set, the code that constructed this `LazySrcLoc` is asserting
    /// that all code paths which would need to resolve the source location are
    /// unreachable. If you are debugging this tag incorrectly being this value,
    /// look into using reverse-continue with a memory watchpoint to see where the
    /// value is being set to this tag.
    unneeded,
    /// Means the source location points to an entire file; not any particular
    /// location within the file. `file_scope` union field will be active.
    entire_file,
    /// The source location points to a byte offset within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    byte_abs: u32,
    /// The source location points to a token within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    token_abs: u32,
    /// The source location points to an AST node within a source file,
    /// offset from 0. The source file is determined contextually.
    /// Inside a `SrcLoc`, the `file_scope` union field will be active.
    node_abs: u32,
    /// The source location points to a byte offset within a source file,
    /// offset from the byte offset of the Decl within the file.
    /// The Decl is determined contextually.
    byte_offset: u32,
    /// This data is the offset into the token list from the Decl token.
    /// The Decl is determined contextually.
    token_offset: u32,
    /// The source location points to an AST node, which is this value offset
    /// from its containing Decl node AST index.
    /// The Decl is determined contextually.
    node_offset: i32,
    /// The source location points to two tokens left of the first token of an AST node,
    /// which is this value offset from its containing Decl node AST index.
    /// The Decl is determined contextually.
    node_offset_back2tok: i32,
    /// The source location points to a variable declaration type expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a variable declaration AST node. Next, navigate
    /// to the type expression.
    /// The Decl is determined contextually.
    node_offset_var_decl_ty: i32,
    /// The source location points to a for loop condition expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a for loop AST node. Next, navigate
    /// to the condition expression.
    /// The Decl is determined contextually.
    node_offset_for_cond: i32,
    /// The source location points to the first parameter of a builtin
    /// function call, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a builtin call AST node. Next, navigate
    /// to the first parameter.
    /// The Decl is determined contextually.
    node_offset_builtin_call_arg0: i32,
    /// Same as `node_offset_builtin_call_arg0` except arg index 1.
    node_offset_builtin_call_arg1: i32,
    /// The source location points to the index expression of an array access
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an array access AST node. Next, navigate
    /// to the index expression.
    /// The Decl is determined contextually.
    node_offset_array_access_index: i32,
    /// The source location points to the sentinel expression of a slice
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a slice AST node. Next, navigate
    /// to the sentinel expression.
    /// The Decl is determined contextually.
    node_offset_slice_sentinel: i32,
    /// The source location points to the callee expression of a function
    /// call expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function call AST node. Next, navigate
    /// to the callee expression.
    /// The Decl is determined contextually.
    node_offset_call_func: i32,
    /// The payload is offset from the containing Decl AST node.
    /// The source location points to the field name of:
    ///  * a field access expression (`a.b`), or
    ///  * the operand ("b" node) of a field initialization expression (`.a = b`)
    /// The Decl is determined contextually.
    node_offset_field_name: i32,
    /// The source location points to the pointer of a pointer deref expression,
    /// found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a pointer deref AST node. Next, navigate
    /// to the pointer expression.
    /// The Decl is determined contextually.
    node_offset_deref_ptr: i32,
    /// The source location points to the assembly source code of an inline assembly
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to inline assembly AST node. Next, navigate
    /// to the asm template source code.
    /// The Decl is determined contextually.
    node_offset_asm_source: i32,
    /// The source location points to the return type of an inline assembly
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to inline assembly AST node. Next, navigate
    /// to the return type expression.
    /// The Decl is determined contextually.
    node_offset_asm_ret_ty: i32,
    /// The source location points to the condition expression of an if
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to an if expression AST node. Next, navigate
    /// to the condition expression.
    /// The Decl is determined contextually.
    node_offset_if_cond: i32,
    /// The source location points to a binary expression, such as `a + b`, found
    /// by taking this AST node index offset from the containing Decl AST node.
    /// The Decl is determined contextually.
    node_offset_bin_op: i32,
    /// The source location points to the LHS of a binary expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a binary expression AST node. Next, nagivate to the LHS.
    /// The Decl is determined contextually.
    node_offset_bin_lhs: i32,
    /// The source location points to the RHS of a binary expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a binary expression AST node. Next, nagivate to the RHS.
    /// The Decl is determined contextually.
    node_offset_bin_rhs: i32,
    /// The source location points to the operand of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to the operand.
    /// The Decl is determined contextually.
    node_offset_switch_operand: i32,
    /// The source location points to the else/`_` prong of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to the else/`_` prong.
    /// The Decl is determined contextually.
    node_offset_switch_special_prong: i32,
    /// The source location points to all the ranges of a switch expression, found
    /// by taking this AST node index offset from the containing Decl AST node,
    /// which points to a switch expression AST node. Next, nagivate to any of the
    /// range nodes. The error applies to all of them.
    /// The Decl is determined contextually.
    node_offset_switch_range: i32,
    /// The source location points to the calling convention of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, nagivate to
    /// the calling convention node.
    /// The Decl is determined contextually.
    node_offset_fn_type_cc: i32,
    /// The source location points to the return type of a function type
    /// expression, found by taking this AST node index offset from the containing
    /// Decl AST node, which points to a function type AST node. Next, nagivate to
    /// the return type node.
    /// The Decl is determined contextually.
    node_offset_fn_type_ret_ty: i32,

    /// Upgrade to a `SrcLoc` based on the `Decl` or file in the provided scope.
    pub fn toSrcLoc(lazy: LazySrcLoc, scope: *Scope) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .entire_file,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .file_scope = scope.getFileScope(),
                .parent_decl_node = 0,
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_back2tok,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_array_access_index,
            .node_offset_slice_sentinel,
            .node_offset_call_func,
            .node_offset_field_name,
            .node_offset_deref_ptr,
            .node_offset_asm_source,
            .node_offset_asm_ret_ty,
            .node_offset_if_cond,
            .node_offset_bin_op,
            .node_offset_bin_lhs,
            .node_offset_bin_rhs,
            .node_offset_switch_operand,
            .node_offset_switch_special_prong,
            .node_offset_switch_range,
            .node_offset_fn_type_cc,
            .node_offset_fn_type_ret_ty,
            => .{
                .file_scope = scope.getFileScope(),
                .parent_decl_node = scope.srcDecl().?.src_node,
                .lazy = lazy,
            },
        };
    }

    /// Upgrade to a `SrcLoc` based on the `Decl` provided.
    pub fn toSrcLocWithDecl(lazy: LazySrcLoc, decl: *Decl) SrcLoc {
        return switch (lazy) {
            .unneeded,
            .entire_file,
            .byte_abs,
            .token_abs,
            .node_abs,
            => .{
                .file_scope = decl.getFileScope(),
                .parent_decl_node = 0,
                .lazy = lazy,
            },

            .byte_offset,
            .token_offset,
            .node_offset,
            .node_offset_back2tok,
            .node_offset_var_decl_ty,
            .node_offset_for_cond,
            .node_offset_builtin_call_arg0,
            .node_offset_builtin_call_arg1,
            .node_offset_array_access_index,
            .node_offset_slice_sentinel,
            .node_offset_call_func,
            .node_offset_field_name,
            .node_offset_deref_ptr,
            .node_offset_asm_source,
            .node_offset_asm_ret_ty,
            .node_offset_if_cond,
            .node_offset_bin_op,
            .node_offset_bin_lhs,
            .node_offset_bin_rhs,
            .node_offset_switch_operand,
            .node_offset_switch_special_prong,
            .node_offset_switch_range,
            .node_offset_fn_type_cc,
            .node_offset_fn_type_ret_ty,
            => .{
                .file_scope = decl.getFileScope(),
                .parent_decl_node = decl.src_node,
                .lazy = lazy,
            },
        };
    }
};

pub const InnerError = error{ OutOfMemory, AnalysisFail };

pub fn deinit(mod: *Module) void {
    const gpa = mod.gpa;

    // The callsite of `Compilation.create` owns the `root_pkg`, however
    // Module owns the builtin and std packages that it adds.
    if (mod.root_pkg.table.remove("builtin")) |entry| {
        gpa.free(entry.key);
        entry.value.destroy(gpa);
    }
    if (mod.root_pkg.table.remove("std")) |entry| {
        gpa.free(entry.key);
        entry.value.destroy(gpa);
    }
    if (mod.root_pkg.table.remove("root")) |entry| {
        gpa.free(entry.key);
    }

    mod.compile_log_text.deinit(gpa);

    mod.zig_cache_artifact_directory.handle.close();

    mod.deletion_set.deinit(gpa);

    for (mod.decl_table.items()) |entry| {
        entry.value.destroy(mod);
    }
    mod.decl_table.deinit(gpa);

    for (mod.failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.failed_decls.deinit(gpa);

    for (mod.emit_h_failed_decls.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.emit_h_failed_decls.deinit(gpa);

    for (mod.failed_files.items()) |entry| {
        if (entry.value) |msg| msg.destroy(gpa);
    }
    mod.failed_files.deinit(gpa);

    for (mod.failed_exports.items()) |entry| {
        entry.value.destroy(gpa);
    }
    mod.failed_exports.deinit(gpa);

    mod.compile_log_decls.deinit(gpa);

    for (mod.decl_exports.items()) |entry| {
        const export_list = entry.value;
        gpa.free(export_list);
    }
    mod.decl_exports.deinit(gpa);

    for (mod.export_owners.items()) |entry| {
        freeExportList(gpa, entry.value);
    }
    mod.export_owners.deinit(gpa);

    mod.symbol_exports.deinit(gpa);

    var it = mod.global_error_set.iterator();
    while (it.next()) |entry| {
        gpa.free(entry.key);
    }
    mod.global_error_set.deinit(gpa);

    mod.error_name_list.deinit(gpa);

    for (mod.import_table.items()) |entry| {
        gpa.free(entry.key);
        entry.value.destroy(gpa);
    }
    mod.import_table.deinit(gpa);
}

fn freeExportList(gpa: *Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        gpa.free(exp.options.name);
        gpa.destroy(exp);
    }
    gpa.free(export_list);
}

pub fn astGenFile(mod: *Module, file: *Scope.File, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = mod.comp;
    const gpa = mod.gpa;

    // In any case we need to examine the stat of the file to determine the course of action.
    var f = try file.pkg.root_src_directory.handle.openFile(file.sub_file_path, .{});
    defer f.close();

    const stat = try f.stat();

    // Determine whether we need to reload the file from disk and redo parsing and AstGen.
    switch (file.status) {
        .never_loaded, .retryable_failure => {
            log.debug("first-time AstGen: {s}", .{file.sub_file_path});
        },
        .parse_failure, .astgen_failure, .success => {
            const unchanged_metadata =
                stat.size == file.stat_size and
                stat.mtime == file.stat_mtime and
                stat.inode == file.stat_inode;

            if (unchanged_metadata) {
                log.debug("unmodified metadata of file: {s}", .{file.sub_file_path});
                return;
            }

            log.debug("metadata changed: {s}", .{file.sub_file_path});
        },
    }
    // Clear compile error for this file.
    switch (file.status) {
        .success, .retryable_failure => {},
        .never_loaded, .parse_failure, .astgen_failure => {
            const lock = comp.mutex.acquire();
            defer lock.release();
            if (mod.failed_files.swapRemove(file)) |entry| {
                if (entry.value) |msg| msg.destroy(gpa); // Delete previous error message.
            }
        },
    }
    file.unload(gpa);

    if (stat.size > std.math.maxInt(u32))
        return error.FileTooBig;

    const source = try gpa.allocSentinel(u8, stat.size, 0);
    defer if (!file.source_loaded) gpa.free(source);
    const amt = try f.readAll(source);
    if (amt != stat.size)
        return error.UnexpectedEndOfFile;

    file.stat_size = stat.size;
    file.stat_inode = stat.inode;
    file.stat_mtime = stat.mtime;
    file.source = source;
    file.source_loaded = true;

    file.tree = try std.zig.parse(gpa, source);
    defer if (!file.tree_loaded) file.tree.deinit(gpa);

    if (file.tree.errors.len != 0) {
        const parse_err = file.tree.errors[0];

        var msg = std.ArrayList(u8).init(gpa);
        defer msg.deinit();

        const token_starts = file.tree.tokens.items(.start);

        try file.tree.renderError(parse_err, msg.writer());
        const err_msg = try gpa.create(ErrorMsg);
        err_msg.* = .{
            .src_loc = .{
                .file_scope = file,
                .parent_decl_node = 0,
                .lazy = .{ .byte_abs = token_starts[parse_err.token] },
            },
            .msg = msg.toOwnedSlice(),
        };

        {
            const lock = comp.mutex.acquire();
            defer lock.release();
            try mod.failed_files.putNoClobber(gpa, file, err_msg);
        }
        file.status = .parse_failure;
        return error.AnalysisFail;
    }
    file.tree_loaded = true;

    file.zir = try AstGen.generate(gpa, file);
    file.zir_loaded = true;

    if (file.zir.hasCompileErrors()) {
        {
            const lock = comp.mutex.acquire();
            defer lock.release();
            try mod.failed_files.putNoClobber(gpa, file, null);
        }
        file.status = .astgen_failure;
        return error.AnalysisFail;
    }

    log.debug("AstGen success: {s}", .{file.sub_file_path});
    file.status = .success;
}

pub fn ensureDeclAnalyzed(mod: *Module, decl: *Decl) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const subsequent_analysis = switch (decl.analysis) {
        .in_progress => unreachable,

        .sema_failure,
        .sema_failure_retryable,
        .codegen_failure,
        .dependency_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => return,

        .outdated => blk: {
            log.debug("re-analyzing {s}", .{decl.name});

            // The exports this Decl performs will be re-discovered, so we remove them here
            // prior to re-analysis.
            mod.deleteDeclExports(decl);
            // Dependencies will be re-discovered, so we remove them here prior to re-analysis.
            for (decl.dependencies.items()) |entry| {
                const dep = entry.key;
                dep.removeDependant(decl);
                if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
                    // We don't perform a deletion here, because this Decl or another one
                    // may end up referencing it before the update is complete.
                    dep.deletion_flag = true;
                    try mod.deletion_set.put(mod.gpa, dep, {});
                }
            }
            decl.dependencies.clearRetainingCapacity();

            break :blk true;
        },

        .unreferenced => false,
    };

    const type_changed = mod.semaDecl(decl) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => return error.AnalysisFail,
        else => {
            decl.analysis = .sema_failure_retryable;
            try mod.failed_decls.ensureCapacity(mod.gpa, mod.failed_decls.items().len + 1);
            mod.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                mod.gpa,
                decl.srcLoc(),
                "unable to analyze: {s}",
                .{@errorName(err)},
            ));
            return error.AnalysisFail;
        },
    };

    if (subsequent_analysis) {
        // We may need to chase the dependants and re-analyze them.
        // However, if the decl is a function, and the type is the same, we do not need to.
        if (type_changed or decl.typed_value.most_recent.typed_value.val.tag() != .function) {
            for (decl.dependants.items()) |entry| {
                const dep = entry.key;
                switch (dep.analysis) {
                    .unreferenced => unreachable,
                    .in_progress => unreachable,
                    .outdated => continue, // already queued for update

                    .dependency_failure,
                    .sema_failure,
                    .sema_failure_retryable,
                    .codegen_failure,
                    .codegen_failure_retryable,
                    .complete,
                    => if (dep.generation != mod.generation) {
                        try mod.markOutdatedDecl(dep);
                    },
                }
            }
        }
    }
}

/// Returns `true` if the Decl type changed.
/// Returns `true` if this is the first time analyzing the Decl.
/// Returns `false` otherwise.
fn semaDecl(mod: *Module, decl: *Decl) !bool {
    const tracy = trace(@src());
    defer tracy.end();

    @panic("TODO implement semaDecl");
}

/// Returns the depender's index of the dependee.
pub fn declareDeclDependency(mod: *Module, depender: *Decl, dependee: *Decl) !void {
    try depender.dependencies.ensureCapacity(mod.gpa, depender.dependencies.count() + 1);
    try dependee.dependants.ensureCapacity(mod.gpa, dependee.dependants.count() + 1);

    if (dependee.deletion_flag) {
        dependee.deletion_flag = false;
        mod.deletion_set.removeAssertDiscard(dependee);
    }

    dependee.dependants.putAssumeCapacity(depender, {});
    depender.dependencies.putAssumeCapacity(dependee, {});
}

pub const ImportFileResult = struct {
    file: *Scope.File,
    is_new: bool,
};

pub fn importPkg(mod: *Module, cur_pkg: *Package, pkg: *Package) !ImportFileResult {
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const resolved_path = try std.fs.path.resolve(gpa, &[_][]const u8{
        pkg.root_src_directory.path orelse ".", pkg.root_src_path,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    if (gop.found_existing) return ImportFileResult{
        .file = gop.entry.value,
        .is_new = false,
    };
    keep_resolved_path = true; // It's now owned by import_table.

    const sub_file_path = try gpa.dupe(u8, pkg.root_src_path);
    errdefer gpa.free(sub_file_path);

    const new_file = try gpa.create(Scope.File);
    errdefer gpa.destroy(new_file);

    gop.entry.value = new_file;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat_size = undefined,
        .stat_inode = undefined,
        .stat_mtime = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .pkg = pkg,
        .namespace = undefined,
    };
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
    };
}

pub fn importFile(
    mod: *Module,
    cur_file: *Scope.File,
    import_string: []const u8,
) !ImportFileResult {
    if (cur_file.pkg.table.get(import_string)) |pkg| {
        return mod.importPkg(cur_file.pkg, pkg);
    }
    const gpa = mod.gpa;

    // The resolved path is used as the key in the import table, to detect if
    // an import refers to the same as another, despite different relative paths
    // or differently mapped package names.
    const cur_pkg_dir_path = cur_file.pkg.root_src_directory.path orelse ".";
    const resolved_path = try std.fs.path.resolve(gpa, &[_][]const u8{
        cur_pkg_dir_path, cur_file.sub_file_path, "..", import_string,
    });
    var keep_resolved_path = false;
    defer if (!keep_resolved_path) gpa.free(resolved_path);

    const gop = try mod.import_table.getOrPut(gpa, resolved_path);
    if (gop.found_existing) return ImportFileResult{
        .file = gop.entry.value,
        .is_new = false,
    };
    keep_resolved_path = true; // It's now owned by import_table.

    const new_file = try gpa.create(Scope.File);
    errdefer gpa.destroy(new_file);

    const resolved_root_path = try std.fs.path.resolve(gpa, &[_][]const u8{cur_pkg_dir_path});
    defer gpa.free(resolved_root_path);

    if (!mem.startsWith(u8, resolved_path, resolved_root_path)) {
        return error.ImportOutsidePkgPath;
    }
    // +1 for the directory separator here.
    const sub_file_path = try gpa.dupe(u8, resolved_path[resolved_root_path.len + 1 ..]);
    errdefer gpa.free(sub_file_path);

    log.debug("new importFile. resolved_root_path={s}, resolved_path={s}, sub_file_path={s}, import_string={s}", .{
        resolved_root_path, resolved_path, sub_file_path, import_string,
    });

    gop.entry.value = new_file;
    new_file.* = .{
        .sub_file_path = sub_file_path,
        .source = undefined,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .stat_size = undefined,
        .stat_inode = undefined,
        .stat_mtime = undefined,
        .tree = undefined,
        .zir = undefined,
        .status = .never_loaded,
        .pkg = cur_file.pkg,
        .namespace = undefined,
    };
    return ImportFileResult{
        .file = new_file,
        .is_new = true,
    };
}

pub fn analyzeNamespace(
    mod: *Module,
    namespace: *Scope.Namespace,
    decls: []const ast.Node.Index,
) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    // We may be analyzing it for the first time, or this may be
    // an incremental update. This code handles both cases.
    assert(namespace.file_scope.tree_loaded); // Caller must ensure tree loaded.
    const tree: *const ast.Tree = &namespace.file_scope.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    try mod.comp.work_queue.ensureUnusedCapacity(decls.len);
    try namespace.decls.ensureCapacity(mod.gpa, decls.len);

    // Keep track of the decls that we expect to see in this namespace so that
    // we know which ones have been deleted.
    var deleted_decls = std.AutoArrayHashMap(*Decl, void).init(mod.gpa);
    defer deleted_decls.deinit();
    try deleted_decls.ensureCapacity(namespace.decls.items().len);
    for (namespace.decls.items()) |entry| {
        deleted_decls.putAssumeCapacityNoClobber(entry.key, {});
    }

    // Keep track of decls that are invalidated from the update. Ultimately,
    // the goal is to queue up `analyze_decl` tasks in the work queue for
    // the outdated decls, but we cannot queue up the tasks until after
    // we find out which ones have been deleted, otherwise there would be
    // deleted Decl pointers in the work queue.
    var outdated_decls = std.AutoArrayHashMap(*Decl, void).init(mod.gpa);
    defer outdated_decls.deinit();

    for (decls) |decl_node| switch (node_tags[decl_node]) {
        .fn_decl => {
            const fn_proto = node_datas[decl_node].lhs;
            const body = node_datas[decl_node].rhs;
            switch (node_tags[fn_proto]) {
                .fn_proto_simple => {
                    var params: [1]ast.Node.Index = undefined;
                    try mod.semaContainerFn(
                        namespace,
                        &deleted_decls,
                        &outdated_decls,
                        decl_node,
                        tree.*,
                        body,
                        tree.fnProtoSimple(&params, fn_proto),
                    );
                },
                .fn_proto_multi => try mod.semaContainerFn(
                    namespace,
                    &deleted_decls,
                    &outdated_decls,
                    decl_node,
                    tree.*,
                    body,
                    tree.fnProtoMulti(fn_proto),
                ),
                .fn_proto_one => {
                    var params: [1]ast.Node.Index = undefined;
                    try mod.semaContainerFn(
                        namespace,
                        &deleted_decls,
                        &outdated_decls,
                        decl_node,
                        tree.*,
                        body,
                        tree.fnProtoOne(&params, fn_proto),
                    );
                },
                .fn_proto => try mod.semaContainerFn(
                    namespace,
                    &deleted_decls,
                    &outdated_decls,
                    decl_node,
                    tree.*,
                    body,
                    tree.fnProto(fn_proto),
                ),
                else => unreachable,
            }
        },
        .fn_proto_simple => {
            var params: [1]ast.Node.Index = undefined;
            try mod.semaContainerFn(
                namespace,
                &deleted_decls,
                &outdated_decls,
                decl_node,
                tree.*,
                0,
                tree.fnProtoSimple(&params, decl_node),
            );
        },
        .fn_proto_multi => try mod.semaContainerFn(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            0,
            tree.fnProtoMulti(decl_node),
        ),
        .fn_proto_one => {
            var params: [1]ast.Node.Index = undefined;
            try mod.semaContainerFn(
                namespace,
                &deleted_decls,
                &outdated_decls,
                decl_node,
                tree.*,
                0,
                tree.fnProtoOne(&params, decl_node),
            );
        },
        .fn_proto => try mod.semaContainerFn(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            0,
            tree.fnProto(decl_node),
        ),

        .global_var_decl => try mod.semaContainerVar(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.globalVarDecl(decl_node),
        ),
        .local_var_decl => try mod.semaContainerVar(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.localVarDecl(decl_node),
        ),
        .simple_var_decl => try mod.semaContainerVar(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.simpleVarDecl(decl_node),
        ),
        .aligned_var_decl => try mod.semaContainerVar(
            namespace,
            &deleted_decls,
            &outdated_decls,
            decl_node,
            tree.*,
            tree.alignedVarDecl(decl_node),
        ),

        .@"comptime" => {
            const name_index = mod.getNextAnonNameIndex();
            const name = try std.fmt.allocPrint(mod.gpa, "__comptime_{d}", .{name_index});
            defer mod.gpa.free(name);

            const name_hash = namespace.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));

            const new_decl = try mod.createNewDecl(namespace, name, decl_node, name_hash, contents_hash);
            namespace.decls.putAssumeCapacity(new_decl, {});
            mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
        },

        // Container fields are handled in AstGen.
        .container_field_init,
        .container_field_align,
        .container_field,
        => continue,

        .test_decl => {
            if (mod.comp.bin_file.options.is_test) {
                log.err("TODO: analyze test decl", .{});
            }
        },
        .@"usingnamespace" => {
            const name_index = mod.getNextAnonNameIndex();
            const name = try std.fmt.allocPrint(mod.gpa, "__usingnamespace_{d}", .{name_index});
            defer mod.gpa.free(name);

            const name_hash = namespace.fullyQualifiedNameHash(name);
            const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));

            const new_decl = try mod.createNewDecl(namespace, name, decl_node, name_hash, contents_hash);
            namespace.decls.putAssumeCapacity(new_decl, {});

            mod.ensureDeclAnalyzed(new_decl) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => continue,
            };
        },
        else => unreachable,
    };
    // Handle explicitly deleted decls from the source code. This is one of two
    // places that Decl deletions happen. The other is in `Compilation`, after
    // `performAllTheWork`, where we iterate over `Module.deletion_set` and
    // delete Decls which are no longer referenced.
    // If a Decl is explicitly deleted from source, and also no longer referenced,
    // it may be both in this `deleted_decls` set, as well as in the
    // `Module.deletion_set`. To avoid deleting it twice, we remove it from the
    // deletion set at this time.
    for (deleted_decls.items()) |entry| {
        const decl = entry.key;
        log.debug("'{s}' deleted from source", .{decl.name});
        if (decl.deletion_flag) {
            log.debug("'{s}' redundantly in deletion set; removing", .{decl.name});
            mod.deletion_set.removeAssertDiscard(decl);
        }
        try mod.deleteDecl(decl, &outdated_decls);
    }
    // Finally we can queue up re-analysis tasks after we have processed
    // the deleted decls.
    for (outdated_decls.items()) |entry| {
        try mod.markOutdatedDecl(entry.key);
    }
}

fn semaContainerFn(
    mod: *Module,
    namespace: *Scope.Namespace,
    deleted_decls: *std.AutoArrayHashMap(*Decl, void),
    outdated_decls: *std.AutoArrayHashMap(*Decl, void),
    decl_node: ast.Node.Index,
    tree: ast.Tree,
    body_node: ast.Node.Index,
    fn_proto: ast.full.FnProto,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // We will create a Decl for it regardless of analysis status.
    const name_token = fn_proto.name_token orelse {
        // This problem will go away with #1717.
        @panic("TODO missing function name");
    };
    const name = tree.tokenSlice(name_token); // TODO use identifierTokenString
    const name_hash = namespace.fullyQualifiedNameHash(name);
    const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));
    if (mod.decl_table.get(name_hash)) |decl| {
        // Update the AST node of the decl; even if its contents are unchanged, it may
        // have been re-ordered.
        const prev_src_node = decl.src_node;
        decl.src_node = decl_node;
        if (deleted_decls.swapRemove(decl) == null) {
            decl.analysis = .sema_failure;
            const msg = try ErrorMsg.create(mod.gpa, .{
                .file_scope = namespace.file_scope,
                .parent_decl_node = 0,
                .lazy = .{ .token_abs = name_token },
            }, "redeclaration of '{s}'", .{decl.name});
            errdefer msg.destroy(mod.gpa);
            const other_src_loc: SrcLoc = .{
                .file_scope = namespace.file_scope,
                .parent_decl_node = 0,
                .lazy = .{ .node_abs = prev_src_node },
            };
            try mod.errNoteNonLazy(other_src_loc, msg, "previously declared here", .{});
            try mod.failed_decls.putNoClobber(mod.gpa, decl, msg);
        } else {
            if (!srcHashEql(decl.contents_hash, contents_hash)) {
                try outdated_decls.put(decl, {});
                decl.contents_hash = contents_hash;
            } else switch (mod.comp.bin_file.tag) {
                .coff => {
                    // TODO Implement for COFF
                },
                .elf => if (decl.fn_link.elf.len != 0) {
                    // TODO Look into detecting when this would be unnecessary by storing enough state
                    // in `Decl` to notice that the line number did not change.
                    mod.comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                },
                .macho => if (decl.fn_link.macho.len != 0) {
                    // TODO Look into detecting when this would be unnecessary by storing enough state
                    // in `Decl` to notice that the line number did not change.
                    mod.comp.work_queue.writeItemAssumeCapacity(.{ .update_line_number = decl });
                },
                .c, .wasm, .spirv => {},
            }
        }
    } else {
        const new_decl = try mod.createNewDecl(namespace, name, decl_node, name_hash, contents_hash);
        namespace.decls.putAssumeCapacity(new_decl, {});
        if (fn_proto.extern_export_token) |maybe_export_token| {
            const token_tags = tree.tokens.items(.tag);
            if (token_tags[maybe_export_token] == .keyword_export) {
                mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
            }
        }
        new_decl.is_pub = fn_proto.visib_token != null;
    }
}

fn semaContainerVar(
    mod: *Module,
    namespace: *Scope.Namespace,
    deleted_decls: *std.AutoArrayHashMap(*Decl, void),
    outdated_decls: *std.AutoArrayHashMap(*Decl, void),
    decl_node: ast.Node.Index,
    tree: ast.Tree,
    var_decl: ast.full.VarDecl,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const name_token = var_decl.ast.mut_token + 1;
    const name = tree.tokenSlice(name_token); // TODO identifierTokenString
    const name_hash = namespace.fullyQualifiedNameHash(name);
    const contents_hash = std.zig.hashSrc(tree.getNodeSource(decl_node));
    if (mod.decl_table.get(name_hash)) |decl| {
        // Update the AST Node index of the decl, even if its contents are unchanged, it may
        // have been re-ordered.
        const prev_src_node = decl.src_node;
        decl.src_node = decl_node;
        if (deleted_decls.swapRemove(decl) == null) {
            decl.analysis = .sema_failure;
            const msg = try ErrorMsg.create(mod.gpa, .{
                .file_scope = namespace.file_scope,
                .parent_decl_node = 0,
                .lazy = .{ .token_abs = name_token },
            }, "redeclaration of '{s}'", .{decl.name});
            errdefer msg.destroy(mod.gpa);
            const other_src_loc: SrcLoc = .{
                .file_scope = decl.namespace.file_scope,
                .parent_decl_node = 0,
                .lazy = .{ .node_abs = prev_src_node },
            };
            try mod.errNoteNonLazy(other_src_loc, msg, "previously declared here", .{});
            try mod.failed_decls.putNoClobber(mod.gpa, decl, msg);
        } else if (!srcHashEql(decl.contents_hash, contents_hash)) {
            try outdated_decls.put(decl, {});
            decl.contents_hash = contents_hash;
        }
    } else {
        const new_decl = try mod.createNewDecl(namespace, name, decl_node, name_hash, contents_hash);
        namespace.decls.putAssumeCapacity(new_decl, {});
        if (var_decl.extern_export_token) |maybe_export_token| {
            const token_tags = tree.tokens.items(.tag);
            if (token_tags[maybe_export_token] == .keyword_export) {
                mod.comp.work_queue.writeItemAssumeCapacity(.{ .analyze_decl = new_decl });
            }
        }
        new_decl.is_pub = var_decl.visib_token != null;
    }
}

pub fn deleteDecl(
    mod: *Module,
    decl: *Decl,
    outdated_decls: ?*std.AutoArrayHashMap(*Decl, void),
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    log.debug("deleting decl '{s}'", .{decl.name});

    if (outdated_decls) |map| {
        _ = map.swapRemove(decl);
        try map.ensureCapacity(map.count() + decl.dependants.count());
    }
    try mod.deletion_set.ensureCapacity(mod.gpa, mod.deletion_set.count() +
        decl.dependencies.count());

    // Remove from the namespace it resides in. In the case of an anonymous Decl it will
    // not be present in the set, and this does nothing.
    decl.namespace.removeDecl(decl);

    const name_hash = decl.fullyQualifiedNameHash();
    mod.decl_table.removeAssertDiscard(name_hash);
    // Remove itself from its dependencies, because we are about to destroy the decl pointer.
    for (decl.dependencies.items()) |entry| {
        const dep = entry.key;
        dep.removeDependant(decl);
        if (dep.dependants.items().len == 0 and !dep.deletion_flag) {
            // We don't recursively perform a deletion here, because during the update,
            // another reference to it may turn up.
            dep.deletion_flag = true;
            mod.deletion_set.putAssumeCapacity(dep, {});
        }
    }
    // Anything that depends on this deleted decl needs to be re-analyzed.
    for (decl.dependants.items()) |entry| {
        const dep = entry.key;
        dep.removeDependency(decl);
        if (outdated_decls) |map| {
            map.putAssumeCapacity(dep, {});
        } else if (std.debug.runtime_safety) {
            // If `outdated_decls` is `null`, it means we're being called from
            // `Compilation` after `performAllTheWork` and we cannot queue up any
            // more work. `dep` must necessarily be another Decl that is no longer
            // being referenced, and will be in the `deletion_set`. Otherwise,
            // something has gone wrong.
            assert(mod.deletion_set.contains(dep));
        }
    }
    if (mod.failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    if (mod.emit_h_failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    _ = mod.compile_log_decls.swapRemove(decl);
    mod.deleteDeclExports(decl);
    mod.comp.bin_file.freeDecl(decl);

    decl.destroy(mod);
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(mod: *Module, decl: *Decl) void {
    const kv = mod.export_owners.swapRemove(decl) orelse return;

    for (kv.value) |exp| {
        if (mod.decl_exports.getEntry(exp.exported_decl)) |decl_exports_kv| {
            // Remove exports with owner_decl matching the regenerating decl.
            const list = decl_exports_kv.value;
            var i: usize = 0;
            var new_len = list.len;
            while (i < new_len) {
                if (list[i].owner_decl == decl) {
                    mem.copyBackwards(*Export, list[i..], list[i + 1 .. new_len]);
                    new_len -= 1;
                } else {
                    i += 1;
                }
            }
            decl_exports_kv.value = mod.gpa.shrink(list, new_len);
            if (new_len == 0) {
                mod.decl_exports.removeAssertDiscard(exp.exported_decl);
            }
        }
        if (mod.comp.bin_file.cast(link.File.Elf)) |elf| {
            elf.deleteExport(exp.link.elf);
        }
        if (mod.comp.bin_file.cast(link.File.MachO)) |macho| {
            macho.deleteExport(exp.link.macho);
        }
        if (mod.failed_exports.swapRemove(exp)) |entry| {
            entry.value.destroy(mod.gpa);
        }
        _ = mod.symbol_exports.swapRemove(exp.options.name);
        mod.gpa.free(exp.options.name);
        mod.gpa.destroy(exp);
    }
    mod.gpa.free(kv.value);
}

pub fn analyzeFnBody(mod: *Module, decl: *Decl, func: *Fn) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // Use the Decl's arena for function memory.
    var arena = decl.typed_value.most_recent.arena.?.promote(mod.gpa);
    defer decl.typed_value.most_recent.arena.?.* = arena.state;

    const fn_ty = decl.typed_value.most_recent.typed_value.ty;
    const param_inst_list = try mod.gpa.alloc(*ir.Inst, fn_ty.fnParamLen());
    defer mod.gpa.free(param_inst_list);

    for (param_inst_list) |*param_inst, param_index| {
        const param_type = fn_ty.fnParamType(param_index);
        const name = func.zir.nullTerminatedString(func.zir.extra[param_index]);
        const arg_inst = try arena.allocator.create(ir.Inst.Arg);
        arg_inst.* = .{
            .base = .{
                .tag = .arg,
                .ty = param_type,
                .src = .unneeded,
            },
            .name = name,
        };
        param_inst.* = &arg_inst.base;
    }

    var sema: Sema = .{
        .mod = mod,
        .gpa = mod.gpa,
        .arena = &arena.allocator,
        .code = func.zir,
        .inst_map = try mod.gpa.alloc(*ir.Inst, func.zir.instructions.len),
        .owner_decl = decl,
        .namespace = decl.namespace,
        .func = func,
        .owner_func = func,
        .param_inst_list = param_inst_list,
    };
    defer mod.gpa.free(sema.inst_map);

    var inner_block: Scope.Block = .{
        .parent = null,
        .sema = &sema,
        .src_decl = decl,
        .instructions = .{},
        .inlining = null,
        .is_comptime = false,
    };
    defer inner_block.instructions.deinit(mod.gpa);

    // TZIR currently requires the arg parameters to be the first N instructions
    try inner_block.instructions.appendSlice(mod.gpa, param_inst_list);

    func.state = .in_progress;
    log.debug("set {s} to in_progress", .{decl.name});

    _ = try sema.root(&inner_block);

    const instructions = try arena.allocator.dupe(*ir.Inst, inner_block.instructions.items);
    func.state = .success;
    func.body = .{ .instructions = instructions };
    log.debug("set {s} to success", .{decl.name});
}

fn markOutdatedDecl(mod: *Module, decl: *Decl) !void {
    log.debug("mark {s} outdated", .{decl.name});
    try mod.comp.work_queue.writeItem(.{ .analyze_decl = decl });
    if (mod.failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    if (mod.emit_h_failed_decls.swapRemove(decl)) |entry| {
        entry.value.destroy(mod.gpa);
    }
    _ = mod.compile_log_decls.swapRemove(decl);
    decl.analysis = .outdated;
}

fn allocateNewDecl(
    mod: *Module,
    namespace: *Scope.Namespace,
    src_node: ast.Node.Index,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    // If we have emit-h then we must allocate a bigger structure to store the emit-h state.
    const new_decl: *Decl = if (mod.emit_h != null) blk: {
        const parent_struct = try mod.gpa.create(DeclPlusEmitH);
        parent_struct.* = .{
            .emit_h = .{},
            .decl = undefined,
        };
        break :blk &parent_struct.decl;
    } else try mod.gpa.create(Decl);

    new_decl.* = .{
        .name = "",
        .namespace = namespace,
        .src_node = src_node,
        .typed_value = .{ .never_succeeded = {} },
        .analysis = .unreferenced,
        .deletion_flag = false,
        .contents_hash = contents_hash,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = link.File.Coff.TextBlock.empty },
            .elf => .{ .elf = link.File.Elf.TextBlock.empty },
            .macho => .{ .macho = link.File.MachO.TextBlock.empty },
            .c => .{ .c = link.File.C.DeclBlock.empty },
            .wasm => .{ .wasm = link.File.Wasm.DeclBlock.empty },
            .spirv => .{ .spirv = {} },
        },
        .fn_link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Elf.SrcFn.empty },
            .macho => .{ .macho = link.File.MachO.SrcFn.empty },
            .c => .{ .c = link.File.C.FnBlock.empty },
            .wasm => .{ .wasm = link.File.Wasm.FnData.empty },
            .spirv => .{ .spirv = .{} },
        },
        .generation = 0,
        .is_pub = false,
    };
    return new_decl;
}

fn createNewDecl(
    mod: *Module,
    namespace: *Scope.Namespace,
    decl_name: []const u8,
    src_node: ast.Node.Index,
    name_hash: Scope.NameHash,
    contents_hash: std.zig.SrcHash,
) !*Decl {
    try mod.decl_table.ensureCapacity(mod.gpa, mod.decl_table.items().len + 1);
    const new_decl = try mod.allocateNewDecl(namespace, src_node, contents_hash);
    errdefer mod.gpa.destroy(new_decl);
    new_decl.name = try mem.dupeZ(mod.gpa, u8, decl_name);
    log.debug("insert Decl {s} with hash {}", .{
        new_decl.name,
        std.fmt.fmtSliceHexLower(&name_hash),
    });
    mod.decl_table.putAssumeCapacityNoClobber(name_hash, new_decl);
    return new_decl;
}

/// Get error value for error tag `name`.
pub fn getErrorValue(mod: *Module, name: []const u8) !std.StringHashMapUnmanaged(ErrorInt).Entry {
    const gop = try mod.global_error_set.getOrPut(mod.gpa, name);
    if (gop.found_existing)
        return gop.entry.*;

    errdefer mod.global_error_set.removeAssertDiscard(name);
    try mod.error_name_list.ensureCapacity(mod.gpa, mod.error_name_list.items.len + 1);
    gop.entry.key = try mod.gpa.dupe(u8, name);
    gop.entry.value = @intCast(ErrorInt, mod.error_name_list.items.len);
    mod.error_name_list.appendAssumeCapacity(gop.entry.key);
    return gop.entry.*;
}

pub fn analyzeExport(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    borrowed_symbol_name: []const u8,
    exported_decl: *Decl,
) !void {
    try mod.ensureDeclAnalyzed(exported_decl);
    const typed_value = exported_decl.typed_value.most_recent.typed_value;
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {},
        else => return mod.fail(scope, src, "unable to export type '{}'", .{typed_value.ty}),
    }

    try mod.decl_exports.ensureCapacity(mod.gpa, mod.decl_exports.items().len + 1);
    try mod.export_owners.ensureCapacity(mod.gpa, mod.export_owners.items().len + 1);

    const new_export = try mod.gpa.create(Export);
    errdefer mod.gpa.destroy(new_export);

    const symbol_name = try mod.gpa.dupe(u8, borrowed_symbol_name);
    errdefer mod.gpa.free(symbol_name);

    const owner_decl = scope.ownerDecl().?;

    new_export.* = .{
        .options = .{ .name = symbol_name },
        .src = src,
        .link = switch (mod.comp.bin_file.tag) {
            .coff => .{ .coff = {} },
            .elf => .{ .elf = link.File.Elf.Export{} },
            .macho => .{ .macho = link.File.MachO.Export{} },
            .c => .{ .c = {} },
            .wasm => .{ .wasm = {} },
            .spirv => .{ .spirv = {} },
        },
        .owner_decl = owner_decl,
        .exported_decl = exported_decl,
        .status = .in_progress,
    };

    // Add to export_owners table.
    const eo_gop = mod.export_owners.getOrPutAssumeCapacity(owner_decl);
    if (!eo_gop.found_existing) {
        eo_gop.entry.value = &[0]*Export{};
    }
    eo_gop.entry.value = try mod.gpa.realloc(eo_gop.entry.value, eo_gop.entry.value.len + 1);
    eo_gop.entry.value[eo_gop.entry.value.len - 1] = new_export;
    errdefer eo_gop.entry.value = mod.gpa.shrink(eo_gop.entry.value, eo_gop.entry.value.len - 1);

    // Add to exported_decl table.
    const de_gop = mod.decl_exports.getOrPutAssumeCapacity(exported_decl);
    if (!de_gop.found_existing) {
        de_gop.entry.value = &[0]*Export{};
    }
    de_gop.entry.value = try mod.gpa.realloc(de_gop.entry.value, de_gop.entry.value.len + 1);
    de_gop.entry.value[de_gop.entry.value.len - 1] = new_export;
    errdefer de_gop.entry.value = mod.gpa.shrink(de_gop.entry.value, de_gop.entry.value.len - 1);

    if (mod.symbol_exports.get(symbol_name)) |other_export| {
        new_export.status = .failed_retryable;
        try mod.failed_exports.ensureCapacity(mod.gpa, mod.failed_exports.items().len + 1);
        const msg = try mod.errMsg(
            scope,
            src,
            "exported symbol collision: {s}",
            .{symbol_name},
        );
        errdefer msg.destroy(mod.gpa);
        try mod.errNote(
            &other_export.owner_decl.namespace.base,
            other_export.src,
            msg,
            "other symbol here",
            .{},
        );
        mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        new_export.status = .failed;
        return;
    }

    try mod.symbol_exports.putNoClobber(mod.gpa, symbol_name, new_export);
    mod.comp.bin_file.updateDeclExports(mod, exported_decl, de_gop.entry.value) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            new_export.status = .failed_retryable;
            try mod.failed_exports.ensureCapacity(mod.gpa, mod.failed_exports.items().len + 1);
            const msg = try mod.errMsg(scope, src, "unable to export: {s}", .{@errorName(err)});
            mod.failed_exports.putAssumeCapacityNoClobber(new_export, msg);
        },
    };
}
pub fn constInst(mod: *Module, arena: *Allocator, src: LazySrcLoc, typed_value: TypedValue) !*ir.Inst {
    const const_inst = try arena.create(ir.Inst.Constant);
    const_inst.* = .{
        .base = .{
            .tag = ir.Inst.Constant.base_tag,
            .ty = typed_value.ty,
            .src = src,
        },
        .val = typed_value.val,
    };
    return &const_inst.base;
}

pub fn constType(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.type),
        .val = try ty.toValue(arena),
    });
}

pub fn constVoid(mod: *Module, arena: *Allocator, src: LazySrcLoc) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    });
}

pub fn constNoReturn(mod: *Module, arena: *Allocator, src: LazySrcLoc) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.noreturn),
        .val = Value.initTag(.unreachable_value),
    });
}

pub fn constUndef(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = Value.initTag(.undef),
    });
}

pub fn constBool(mod: *Module, arena: *Allocator, src: LazySrcLoc, v: bool) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = Type.initTag(.bool),
        .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
    });
}

pub fn constIntUnsigned(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, int: u64) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = try Value.Tag.int_u64.create(arena, int),
    });
}

pub fn constIntSigned(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, int: i64) !*ir.Inst {
    return mod.constInst(arena, src, .{
        .ty = ty,
        .val = try Value.Tag.int_i64.create(arena, int),
    });
}

pub fn constIntBig(mod: *Module, arena: *Allocator, src: LazySrcLoc, ty: Type, big_int: BigIntConst) !*ir.Inst {
    if (big_int.positive) {
        if (big_int.to(u64)) |x| {
            return mod.constIntUnsigned(arena, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        return mod.constInst(arena, src, .{
            .ty = ty,
            .val = try Value.Tag.int_big_positive.create(arena, big_int.limbs),
        });
    } else {
        if (big_int.to(i64)) |x| {
            return mod.constIntSigned(arena, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        return mod.constInst(arena, src, .{
            .ty = ty,
            .val = try Value.Tag.int_big_negative.create(arena, big_int.limbs),
        });
    }
}

pub fn createAnonymousDecl(
    mod: *Module,
    scope: *Scope,
    decl_arena: *std.heap.ArenaAllocator,
    typed_value: TypedValue,
) !*Decl {
    const name_index = mod.getNextAnonNameIndex();
    const scope_decl = scope.ownerDecl().?;
    const name = try std.fmt.allocPrint(mod.gpa, "{s}__anon_{d}", .{ scope_decl.name, name_index });
    defer mod.gpa.free(name);
    const namespace = scope_decl.namespace;
    const name_hash = namespace.fullyQualifiedNameHash(name);
    const src_hash: std.zig.SrcHash = undefined;
    const new_decl = try mod.createNewDecl(namespace, name, scope_decl.src_node, name_hash, src_hash);
    const decl_arena_state = try decl_arena.allocator.create(std.heap.ArenaAllocator.State);

    decl_arena_state.* = decl_arena.state;
    new_decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = decl_arena_state,
        },
    };
    new_decl.analysis = .complete;
    new_decl.generation = mod.generation;

    // TODO: This generates the Decl into the machine code file if it is of a
    // type that is non-zero size. We should be able to further improve the
    // compiler to omit Decls which are only referenced at compile-time and not runtime.
    if (typed_value.ty.hasCodeGenBits()) {
        try mod.comp.bin_file.allocateDeclIndexes(new_decl);
        try mod.comp.work_queue.writeItem(.{ .codegen_decl = new_decl });
    }

    return new_decl;
}

fn getNextAnonNameIndex(mod: *Module) usize {
    return @atomicRmw(usize, &mod.next_anon_name_index, .Add, 1, .Monotonic);
}

/// This looks up a bare identifier in the given scope. This will walk up the tree of namespaces
/// in scope and check each one for the identifier.
pub fn lookupIdentifier(mod: *Module, scope: *Scope, ident_name: []const u8) ?*Decl {
    var namespace = scope.namespace();
    while (true) {
        if (mod.lookupInNamespace(namespace, ident_name, false)) |decl| {
            return decl;
        }
        namespace = namespace.parent orelse break;
    }
    return null;
}

/// This looks up a member of a specific namespace. It is affected by `usingnamespace` but
/// only for ones in the specified namespace.
pub fn lookupInNamespace(
    mod: *Module,
    namespace: *Scope.Namespace,
    ident_name: []const u8,
    only_pub_usingnamespaces: bool,
) ?*Decl {
    const name_hash = namespace.fullyQualifiedNameHash(ident_name);
    log.debug("lookup Decl {s} with hash {}", .{
        ident_name,
        std.fmt.fmtSliceHexLower(&name_hash),
    });
    // TODO handle decl collision with usingnamespace
    // TODO the decl doing the looking up needs to create a decl dependency
    // on each usingnamespace decl here.
    if (mod.decl_table.get(name_hash)) |decl| {
        return decl;
    }
    {
        var it = namespace.usingnamespace_set.iterator();
        while (it.next()) |entry| {
            const other_ns = entry.key;
            const other_is_pub = entry.value;
            if (only_pub_usingnamespaces and !other_is_pub) continue;
            // TODO handle cycles
            if (mod.lookupInNamespace(other_ns, ident_name, true)) |decl| {
                return decl;
            }
        }
    }
    return null;
}

pub fn makeIntType(arena: *Allocator, signedness: std.builtin.Signedness, bits: u16) !Type {
    const int_payload = try arena.create(Type.Payload.Bits);
    int_payload.* = .{
        .base = .{
            .tag = switch (signedness) {
                .signed => .int_signed,
                .unsigned => .int_unsigned,
            },
        },
        .data = bits,
    };
    return Type.initPayload(&int_payload.base);
}

/// We don't return a pointer to the new error note because the pointer
/// becomes invalid when you add another one.
pub fn errNote(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    return mod.errNoteNonLazy(src.toSrcLoc(scope), parent, format, args);
}

pub fn errNoteNonLazy(
    mod: *Module,
    src_loc: SrcLoc,
    parent: *ErrorMsg,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const msg = try std.fmt.allocPrint(mod.gpa, format, args);
    errdefer mod.gpa.free(msg);

    parent.notes = try mod.gpa.realloc(parent.notes, parent.notes.len + 1);
    parent.notes[parent.notes.len - 1] = .{
        .src_loc = src_loc,
        .msg = msg,
    };
}

pub fn errMsg(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!*ErrorMsg {
    return ErrorMsg.create(mod.gpa, src.toSrcLoc(scope), format, args);
}

pub fn fail(
    mod: *Module,
    scope: *Scope,
    src: LazySrcLoc,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const err_msg = try mod.errMsg(scope, src, format, args);
    return mod.failWithOwnedErrorMsg(scope, err_msg);
}

/// Same as `fail`, except given a token index, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failTok(
    mod: *Module,
    scope: *Scope,
    token_index: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const src = scope.srcDecl().?.tokSrcLoc(token_index);
    return mod.fail(scope, src, format, args);
}

/// Same as `fail`, except given an AST node index, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failNode(
    mod: *Module,
    scope: *Scope,
    node_index: ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    const src = scope.srcDecl().?.nodeSrcLoc(node_index);
    return mod.fail(scope, src, format, args);
}

pub fn failWithOwnedErrorMsg(mod: *Module, scope: *Scope, err_msg: *ErrorMsg) InnerError {
    @setCold(true);

    {
        errdefer err_msg.destroy(mod.gpa);
        try mod.failed_decls.ensureCapacity(mod.gpa, mod.failed_decls.items().len + 1);
        try mod.failed_files.ensureCapacity(mod.gpa, mod.failed_files.items().len + 1);
    }
    switch (scope.tag) {
        .block => {
            const block = scope.cast(Scope.Block).?;
            if (block.sema.owner_func) |func| {
                func.state = .sema_failure;
            } else {
                block.sema.owner_decl.analysis = .sema_failure;
                block.sema.owner_decl.generation = mod.generation;
            }
            mod.failed_decls.putAssumeCapacityNoClobber(block.sema.owner_decl, err_msg);
        },
        .gen_zir, .local_val, .local_ptr, .defer_normal, .defer_error => unreachable,
        .file => unreachable,
        .namespace => unreachable,
        .decl_ref => {
            const decl_ref = scope.cast(Scope.DeclRef).?;
            decl_ref.decl.analysis = .sema_failure;
            decl_ref.decl.generation = mod.generation;
            mod.failed_decls.putAssumeCapacityNoClobber(decl_ref.decl, err_msg);
        },
    }
    return error.AnalysisFail;
}

fn srcHashEql(a: std.zig.SrcHash, b: std.zig.SrcHash) bool {
    return @bitCast(u128, a) == @bitCast(u128, b);
}

pub fn intAdd(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.add(lhs_bigint, rhs_bigint);
    const result_limbs = result_bigint.limbs[0..result_bigint.len];

    if (result_bigint.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
}

pub fn intSub(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs = try allocator.alloc(
        std.math.big.Limb,
        std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
    );
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.sub(lhs_bigint, rhs_bigint);
    const result_limbs = result_bigint.limbs[0..result_bigint.len];

    if (result_bigint.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
}

pub fn intDiv(allocator: *Allocator, lhs: Value, rhs: Value) !Value {
    // TODO is this a performance issue? maybe we should try the operation without
    // resorting to BigInt first.
    var lhs_space: Value.BigIntSpace = undefined;
    var rhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space);
    const rhs_bigint = rhs.toBigInt(&rhs_space);
    const limbs_q = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + rhs_bigint.limbs.len + 1,
    );
    const limbs_r = try allocator.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    const limbs_buffer = try allocator.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
    var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buffer, null);
    const result_limbs = result_q.limbs[0..result_q.len];

    if (result_q.positive) {
        return Value.Tag.int_big_positive.create(allocator, result_limbs);
    } else {
        return Value.Tag.int_big_negative.create(allocator, result_limbs);
    }
}

pub fn floatAdd(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val + rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val + rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val + rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val + rhs_val);
        },
        else => unreachable,
    }
}

pub fn floatSub(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val - rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val - rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val - rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val - rhs_val);
        },
        else => unreachable,
    }
}

pub fn floatDiv(
    arena: *Allocator,
    float_type: Type,
    src: LazySrcLoc,
    lhs: Value,
    rhs: Value,
) !Value {
    switch (float_type.tag()) {
        .f16 => {
            @panic("TODO add __trunctfhf2 to compiler-rt");
            //const lhs_val = lhs.toFloat(f16);
            //const rhs_val = rhs.toFloat(f16);
            //return Value.Tag.float_16.create(arena, lhs_val / rhs_val);
        },
        .f32 => {
            const lhs_val = lhs.toFloat(f32);
            const rhs_val = rhs.toFloat(f32);
            return Value.Tag.float_32.create(arena, lhs_val / rhs_val);
        },
        .f64 => {
            const lhs_val = lhs.toFloat(f64);
            const rhs_val = rhs.toFloat(f64);
            return Value.Tag.float_64.create(arena, lhs_val / rhs_val);
        },
        .f128, .comptime_float, .c_longdouble => {
            const lhs_val = lhs.toFloat(f128);
            const rhs_val = rhs.toFloat(f128);
            return Value.Tag.float_128.create(arena, lhs_val / rhs_val);
        },
        else => unreachable,
    }
}

pub fn simplePtrType(
    mod: *Module,
    arena: *Allocator,
    elem_ty: Type,
    mutable: bool,
    size: std.builtin.TypeInfo.Pointer.Size,
) Allocator.Error!Type {
    if (!mutable and size == .Slice and elem_ty.eql(Type.initTag(.u8))) {
        return Type.initTag(.const_slice_u8);
    }
    // TODO stage1 type inference bug
    const T = Type.Tag;

    const type_payload = try arena.create(Type.Payload.ElemType);
    type_payload.* = .{
        .base = .{
            .tag = switch (size) {
                .One => if (mutable) T.single_mut_pointer else T.single_const_pointer,
                .Many => if (mutable) T.many_mut_pointer else T.many_const_pointer,
                .C => if (mutable) T.c_mut_pointer else T.c_const_pointer,
                .Slice => if (mutable) T.mut_slice else T.const_slice,
            },
        },
        .data = elem_ty,
    };
    return Type.initPayload(&type_payload.base);
}

pub fn ptrType(
    mod: *Module,
    arena: *Allocator,
    elem_ty: Type,
    sentinel: ?Value,
    @"align": u32,
    bit_offset: u16,
    host_size: u16,
    mutable: bool,
    @"allowzero": bool,
    @"volatile": bool,
    size: std.builtin.TypeInfo.Pointer.Size,
) Allocator.Error!Type {
    assert(host_size == 0 or bit_offset < host_size * 8);

    // TODO check if type can be represented by simplePtrType
    return Type.Tag.pointer.create(arena, .{
        .pointee_type = elem_ty,
        .sentinel = sentinel,
        .@"align" = @"align",
        .bit_offset = bit_offset,
        .host_size = host_size,
        .@"allowzero" = @"allowzero",
        .mutable = mutable,
        .@"volatile" = @"volatile",
        .size = size,
    });
}

pub fn optionalType(mod: *Module, arena: *Allocator, child_type: Type) Allocator.Error!Type {
    switch (child_type.tag()) {
        .single_const_pointer => return Type.Tag.optional_single_const_pointer.create(
            arena,
            child_type.elemType(),
        ),
        .single_mut_pointer => return Type.Tag.optional_single_mut_pointer.create(
            arena,
            child_type.elemType(),
        ),
        else => return Type.Tag.optional.create(arena, child_type),
    }
}

pub fn arrayType(
    mod: *Module,
    arena: *Allocator,
    len: u64,
    sentinel: ?Value,
    elem_type: Type,
) Allocator.Error!Type {
    if (elem_type.eql(Type.initTag(.u8))) {
        if (sentinel) |some| {
            if (some.eql(Value.initTag(.zero))) {
                return Type.Tag.array_u8_sentinel_0.create(arena, len);
            }
        } else {
            return Type.Tag.array_u8.create(arena, len);
        }
    }

    if (sentinel) |some| {
        return Type.Tag.array_sentinel.create(arena, .{
            .len = len,
            .sentinel = some,
            .elem_type = elem_type,
        });
    }

    return Type.Tag.array.create(arena, .{
        .len = len,
        .elem_type = elem_type,
    });
}

pub fn errorUnionType(
    mod: *Module,
    arena: *Allocator,
    error_set: Type,
    payload: Type,
) Allocator.Error!Type {
    assert(error_set.zigTypeTag() == .ErrorSet);
    if (error_set.eql(Type.initTag(.anyerror)) and payload.eql(Type.initTag(.void))) {
        return Type.initTag(.anyerror_void_error_union);
    }

    return Type.Tag.error_union.create(arena, .{
        .error_set = error_set,
        .payload = payload,
    });
}

pub fn dumpInst(mod: *Module, scope: *Scope, inst: *ir.Inst) void {
    const zir_module = scope.namespace();
    const source = zir_module.getSource(mod) catch @panic("dumpInst failed to get source");
    const loc = std.zig.findLineColumn(source, inst.src);
    if (inst.tag == .constant) {
        std.debug.print("constant ty={} val={} src={s}:{d}:{d}\n", .{
            inst.ty,
            inst.castTag(.constant).?.val,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else if (inst.deaths == 0) {
        std.debug.print("{s} ty={} src={s}:{d}:{d}\n", .{
            @tagName(inst.tag),
            inst.ty,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    } else {
        std.debug.print("{s} ty={} deaths={b} src={s}:{d}:{d}\n", .{
            @tagName(inst.tag),
            inst.ty,
            inst.deaths,
            zir_module.subFilePath(),
            loc.line + 1,
            loc.column + 1,
        });
    }
}

pub fn getTarget(mod: Module) Target {
    return mod.comp.bin_file.options.target;
}

pub fn optimizeMode(mod: Module) std.builtin.Mode {
    return mod.comp.bin_file.options.optimize_mode;
}
